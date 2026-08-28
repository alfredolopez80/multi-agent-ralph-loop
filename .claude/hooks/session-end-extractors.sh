#!/bin/bash
umask 077
# session-end-extractors.sh — Cold-path vault extraction (T95/C9, epic #47) v5
# Event: SessionEnd
#
# WHY: decision-extractor.sh + semantic-realtime-extractor.sh ran synchronously
# on every Edit/Write (measured 79 ms/edit median, N=7). C9 moves the TRIGGER
# out of the hot path: this hook discovers which files the session edited from
# the SESSION TRANSCRIPT and runs the SAME modules, UNMODIFIED in their
# extraction logic, once per unique file, in ONE nohup-detached background job.
#
# DISCOVERY: from transcript_path — NOT git status (worker contract = clean
# tree at session end). Works without git.
#
# VERDICT CHANNEL (v4, contract completed in v5): a PRIVATE RALPH_VERDICT_FILE
# per processed file is injected into every module fork. v5 completes the
# contract on the module side: EVERY exit path emits a line — "DEC/SEM created
# |complete |none |SKIP <reason> |ERROR <reason>" — via verdict() from
# lib/worktree-utils.sh (single definition, no per-module drift). The wrapper
# classifies from ALL verdict lines (an ERROR is never masked by a later
# "created"), captures each fork's rc (rc!=0 with no verdict => "failed rc=N",
# fail-loud), and on timeout logs "timeout (verdict incomplete)" WITHOUT
# recording a hash and WITHOUT deleting the tmp file (preserved under
# verdict-leftovers/ for inspection). No guessing by timeout.
#
# DEDUP: per-project content-hash state under $HOME/.ralph/state/
# session-end-extractors/, keyed by the SAME project identity the modules use
# (basename of the MAIN repo — not the worktree), so sibling worktrees share
# one dedupe space instead of duplicating facts. Hash covers size+content;
# recorded ONLY on a module-reported extraction.
#
# PAYLOAD SAFETY: content is cut at 30KB on a UTF-8-safe boundary (decoding
# with errors=ignore after the raw cut; a mid-multibyte cut made jq reject
# the whole payload — permanent per-file loss) and the built JSON is checked
# against a 90KB ceiling (jq escaping measured >1.66x) with a one-step
# rebuild at 15KB.
#
# EXTENSION FILTER = intersection of what BOTH modules accept (semantic
# exits immediately on everything else): py js ts tsx jsx go rs java kt rb sh
# bash. Dispatching rejected extensions bought dead polling and lying
# verdicts. The cap logs "NOT extracted (limit)" — files stay eligible.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${HOME}/.ralph/logs/session-end-extractors.log"
STATE_DIR="${HOME}/.ralph/state/session-end-extractors"
MAX_FILES=25
CONTENT_LIMIT=30000          # raw bytes before embedding
PAYLOAD_CEILING=90000        # built-JSON ceiling; rebuild smaller once if exceeded
VERDICT_TIMEOUT_TICKS=50     # 50 x 0.2s = 10s per file, waiting on its own verdict file

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# cut_head <file> <bytes> — byte cut with a UTF-8-safe finish: decode with
# errors=ignore drops any multibyte character split by the raw cut (a split
# character made jq reject the ENTIRE payload).
cut_head() {
    local file="$1" bytes="$2"
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import sys
data = sys.stdin.buffer.read(int(sys.argv[1]))
sys.stdout.write(data.decode("utf-8", "ignore"))' "$bytes" < "$file" 2>/dev/null
    else
        # No python3: raw byte cut (may split a multibyte character — logged
        # limitation, same behaviour as the hot path had).
        head -c "$bytes" "$file" 2>/dev/null
    fi
}

# ---------------------------------------------------------------------------
# Background mode: self-invoked via nohup (survives terminal SIGHUP).
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--bg-run" ]]; then
    BG_ROOT="$2" BG_STATE="$3" BG_SESSION="$4"
    BG_FILES="$5"
    cd "$BG_ROOT" 2>/dev/null || { log "bg: cannot cd to session root $BG_ROOT — aborting job"; exit 1; }

    VAULT_DIR="${RALPH_VAULT_DIR:-${HOME}/Documents/Obsidian/MiVault}"
    COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$COMMON_DIR" ]]; then MAIN_DIR="$(dirname "$COMMON_DIR")"; else MAIN_DIR="$BG_ROOT"; fi
    # ONE identity, the modules' own: they write under basename(MAIN repo)
    # (get_main_repo/T80(a)), so the dedupe state must use the same key —
    # worktree basenames gave sibling workers separate states and duplicates.
    PROJ_KEY="$(basename "$MAIN_DIR")"
    STATE_FILE="$BG_STATE/$PROJ_KEY.hashes"
    LEFTOVERS="$BG_STATE/verdict-leftovers"
    mkdir -p "$LEFTOVERS" 2>/dev/null || true

    EXTRACTED_N=0; NOOP_N=0; SKIPPED_N=0; FAILED_N=0
    while IFS= read -r FILE; do
        [[ -n "$FILE" ]] || continue
        if [[ ! -f "$FILE" ]]; then
            log "skipped: not a file: $FILE"
            SKIPPED_N=$((SKIPPED_N + 1))
            continue
        fi
        SIZE=$(wc -c < "$FILE" 2>/dev/null || echo 0)
        SIZE=$(printf '%s' "$SIZE" | tr -d '[:space:]')   # BSD wc pads; the hash must be reproducible test-side
        [[ -z "$SIZE" ]] && SIZE=0
        CONTENT=$(cut_head "$FILE" "$CONTENT_LIMIT")
        if (( SIZE > CONTENT_LIMIT )); then
            log "truncated: $FILE ($SIZE -> $CONTENT_LIMIT bytes; header patterns still scanned)"
        fi
        HASH=$(printf '%s:%s' "$SIZE" "$CONTENT" | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | awk '{print $1}')
        if [[ -z "$HASH" ]]; then
            log "note: no sha256 tool available — dedupe disabled for $FILE"
        elif [[ -f "$STATE_FILE" ]] && grep -qxF "$HASH" "$STATE_FILE"; then
            log "skipped: already extracted (hash $HASH): $FILE"
            SKIPPED_N=$((SKIPPED_N + 1))
            continue
        fi

        VERDICT_FILE=$(mktemp 2>/dev/null) || { log "failed: no tmp for verdict file"; FAILED_N=$((FAILED_N + 1)); continue; }

        STDIN=$(jq -cn --arg fp "$FILE" --arg cwd "$BG_ROOT" --arg sid "$BG_SESSION" --arg content "$CONTENT" \
            '{session_id:$sid,transcript_path:"",cwd:$cwd,tool_name:"Edit",
              tool_input:{file_path:$fp,old_string:"",new_string:$content}}') \
            || { log "failed: payload build: $FILE"; rm -f "$VERDICT_FILE"; FAILED_N=$((FAILED_N + 1)); continue; }
        if (( ${#STDIN} > PAYLOAD_CEILING )); then
            CONTENT=$(cut_head "$FILE" 15000)
            STDIN=$(jq -cn --arg fp "$FILE" --arg cwd "$BG_ROOT" --arg sid "$BG_SESSION" --arg content "$CONTENT" \
                '{session_id:$sid,transcript_path:"",cwd:$cwd,tool_name:"Edit",
                  tool_input:{file_path:$fp,old_string:"",new_string:$content}}') \
                || { log "failed: payload rebuild: $FILE"; rm -f "$VERDICT_FILE"; FAILED_N=$((FAILED_N + 1)); continue; }
            log "truncated: $FILE (payload ceiling rebuilt at 15000 bytes)"
        fi

        printf '%s' "$STDIN" | RALPH_VERDICT_FILE="$VERDICT_FILE" /bin/bash "$HOOK_DIR/decision-extractor.sh" >/dev/null 2>&1
        DEC_RC=$?
        printf '%s' "$STDIN" | RALPH_VERDICT_FILE="$VERDICT_FILE" /bin/bash "$HOOK_DIR/semantic-realtime-extractor.sh" >/dev/null 2>&1
        SEM_RC=$?

        # Wait for THIS file's own verdict file (both verdicts or declared
        # timeout). The modules' extraction forks write the verdict lines
        # asynchronously — reading the file immediately sees it empty.
        DEC_V=""; SEM_V=""
        for _ in $(seq 1 "$VERDICT_TIMEOUT_TICKS"); do
            sleep 0.2
            DEC_V=$(grep '^DEC ' "$VERDICT_FILE" 2>/dev/null)
            SEM_V=$(grep '^SEM ' "$VERDICT_FILE" 2>/dev/null)
            [[ -n "$DEC_V" && -n "$SEM_V" ]] && break
        done

        # Read ALL verdict lines of this file (finding 2: an ERROR followed by
        # a "created" must stay visible, never masked by tail -1).
        DEC_ALL=$(grep '^DEC ' "$VERDICT_FILE" 2>/dev/null)
        SEM_ALL=$(grep '^SEM ' "$VERDICT_FILE" 2>/dev/null)
        DEC_CREATED=$(printf '%s\n' "$DEC_ALL" | grep -c '^DEC created' || true)
        SEM_FACTS=$(printf '%s\n' "$SEM_ALL" | sed -n 's/^SEM complete facts=//p' | tail -1)
        DEC_ERR=$(printf '%s\n' "$DEC_ALL" | grep '^DEC ERROR' | head -1)
        SEM_ERR=$(printf '%s\n' "$SEM_ALL" | grep '^SEM ERROR' | head -1)
        DEC_SKIP=$(printf '%s\n' "$DEC_ALL" | grep '^DEC SKIP' | head -1)
        SEM_SKIP=$(printf '%s\n' "$SEM_ALL" | grep '^SEM SKIP' | head -1)

        TIMEOUT_NOTE=""
        if [[ -z "$DEC_ALL" ]]; then
            if (( DEC_RC != 0 )); then
                log "failed: decision-extractor rc=$DEC_RC with no verdict line: $FILE"
                FAILED_N=$((FAILED_N + 1))
            else
                TIMEOUT_NOTE="missing DEC"
            fi
        fi
        if [[ -z "$SEM_ALL" ]]; then
            if (( SEM_RC != 0 )); then
                log "failed: semantic-realtime rc=$SEM_RC with no verdict line: $FILE"
                FAILED_N=$((FAILED_N + 1))
            else
                TIMEOUT_NOTE="${TIMEOUT_NOTE:+$TIMEOUT_NOTE, }missing SEM"
            fi
        fi
        if [[ -n "$TIMEOUT_NOTE" ]]; then
            # Incomplete verdicts are NOT extraction: no hash (the file stays
            # eligible), and the tmp verdict file is PRESERVED for inspection
            # — a slow fork under load may still be writing into it.
            log "timeout (verdict incomplete) [$TIMEOUT_NOTE]: $FILE"
            mv "$VERDICT_FILE" "$LEFTOVERS/$(date +%s)-$$.verdict" 2>/dev/null || true
            continue
        fi
        rm -f "$VERDICT_FILE"

        # Errors are ALWAYS visible (finding 2), extraction reported alongside.
        if [[ -n "$DEC_ERR" || -n "$SEM_ERR" ]]; then
            log "module error for $FILE: dec=[${DEC_ERR:-none}] sem=[${SEM_ERR:-none}]"
        fi

        EXTRACTED=0
        (( DEC_CREATED >= 1 )) && EXTRACTED=1
        [[ -n "$SEM_FACTS" ]] && (( SEM_FACTS >= 1 )) && EXTRACTED=1

        if (( EXTRACTED )); then
            log "extracted: $FILE (dec=[${DEC_CREATED:-0} created] sem=[${SEM_FACTS:-0} facts])"
            if [[ -n "$HASH" ]]; then
                printf '%s\n' "$HASH" >> "$STATE_FILE" 2>/dev/null || true
                if [[ "$(wc -l < "$STATE_FILE" 2>/dev/null || echo 0)" -gt 5000 ]]; then
                    tail -n 4000 "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null \
                        && mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
                fi
            fi
            EXTRACTED_N=$((EXTRACTED_N + 1))
        elif [[ -n "$DEC_SKIP" || -n "$SEM_SKIP" ]]; then
            log "skipped by module: $FILE (dec=[${DEC_SKIP:-none}] sem=[${SEM_SKIP:-none}])"
            SKIPPED_N=$((SKIPPED_N + 1))
        else
            log "no-op: heuristics did not fire for $FILE (dec=none sem=0 facts)"
            NOOP_N=$((NOOP_N + 1))
        fi
    done <<< "$BG_FILES"
    log "job finished (extracted=$EXTRACTED_N noop=$NOOP_N skipped=$SKIPPED_N failed=$FAILED_N)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Main (SessionEnd): discover, cap, detach.
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)
mkdir -p "$(dirname "$LOG_FILE")" "$STATE_DIR" 2>/dev/null || true

SESSION_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "session-end"' 2>/dev/null)
[[ -z "$SESSION_CWD" || "$SESSION_CWD" == "null" ]] && SESSION_CWD="$PWD"
PROJECT_ROOT="$(git -C "$SESSION_CWD" rev-parse --show-toplevel 2>/dev/null || echo "$SESSION_CWD")"
# Canonical form: git reports the physical path (/private/var on macOS) while
# transcript file_paths carry whatever the session used (/var...) — without
# this, the prefix match below discards every file.
PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P || echo "$PROJECT_ROOT")"

FILES=""
TOTAL=0
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    DISCOVERED=$(jq -r 'select(.type=="assistant") | .message.content[]?
        | select(.type=="tool_use")
        | select(.name=="Edit" or .name=="Write" or .name=="MultiEdit")
        | .input.file_path // empty' "$TRANSCRIPT" 2>/dev/null | sort -u)
    while IFS= read -r f; do
        [[ -n "$f" && -f "$f" ]] || continue
        f=$(realpath "$f" 2>/dev/null || printf '%s' "$f")
        case "$f" in "$PROJECT_ROOT"/*) ;; *) continue ;; esac
        # Intersection of what BOTH modules accept (semantic exits on the rest).
        case "$f" in
            *.ts|*.tsx|*.js|*.jsx|*.py|*.go|*.rs|*.java|*.kt|*.rb|*.sh|*.bash) ;;
            *) continue ;;
        esac
        TOTAL=$((TOTAL + 1))
        FILES="${FILES}${f}"$'\n'
    done <<< "$DISCOVERED"
else
    log "skipped: no transcript available for this session — nothing to discover"
fi

if [[ -z "$FILES" ]]; then
    log "nothing eligible to extract under $PROJECT_ROOT (discovered=$TOTAL)"
    log "job finished (extracted=0 noop=0 skipped=0 failed=0)"
    echo '{"continue": true}'
    exit 0
fi

if (( TOTAL > MAX_FILES )); then
    OVER=$((TOTAL - MAX_FILES))
    log "NOT extracted (limit): $OVER file(s) over the $MAX_FILES cap — they stay eligible for future sessions"
    FILES=$(printf '%s' "$FILES" | head -n "$MAX_FILES")
fi

# One detached job; HUP-immune; env (incl. RALPH_VAULT_DIR for tests) inherits.
nohup bash "$0" --bg-run "$PROJECT_ROOT" "$STATE_DIR" "$SESSION_ID" "$FILES" >/dev/null 2>&1 &
log "session-end extraction dispatched: $TOTAL discovered, $(printf '%s' "$FILES" | grep -c .) dispatched (background)"
echo '{"continue": true}'
