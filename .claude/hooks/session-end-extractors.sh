#!/bin/bash
umask 077
# session-end-extractors.sh — Cold-path vault extraction (T95/C9, epic #47) v3
# Event: SessionEnd
#
# WHY: decision-extractor.sh + semantic-realtime-extractor.sh ran synchronously
# on every Edit/Write (measured 79 ms/edit median, N=7). C9 moves the TRIGGER
# out of the hot path: this hook discovers which files the session edited from
# the SESSION TRANSCRIPT and runs the SAME modules, UNMODIFIED, once per unique
# file, in ONE nohup-detached background job that survives terminal HUP.
#
# DISCOVERY (v2): from transcript_path — NOT git status. This repo's worker
# contract is a CLEAN tree at session end, so dirty-state discovery was a
# structural no-op for the standard workflow: committed work was invisible.
# Transcript parsing mirrors session-end-handoff.sh (jq streaming over JSONL;
# a truncated tail line only costs the tail). Works without git: the project
# root falls back to the session cwd.
#
# HONEST VERDICT (v3, after RETURN 2): the modules write their OWN verdict to
# their daily logs — decision-extractor emits "Created episode: … with N
# decisions" / "No architectural decisions detected" / "ERROR …"; semantic-
# realtime emits "Realtime extraction complete: N facts added" / "ERROR …".
# The wrapper tails each module's log from a pre-invocation offset and waits
# for the verdict LINE (signal-based, not a fixed sleep, not a directory
# diff): v2's before/after listing raced the modules' internal forks, logged
# false "no-op"s, and unrecorded hashes caused cross-session re-extraction.
# A hash is recorded only when at least one module reported extraction —
# content whose heuristics did not fire retries next session (retry is cheap,
# silence is not recorded as done).
#
# DEDUP: per-project content-hash state under
# $HOME/.ralph/state/session-end-extractors/. The hash covers size+content, so
# two files sharing a truncated 60 KB prefix never collide; the state file is
# capped (growth bounded).
#
# PROJECT IDENTITY: the background job cd's to the session root before
# invoking the modules — their project key comes from get_main_repo over the
# process cwd (T80(a)), exactly what the hot path produced.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${HOME}/.ralph/logs/session-end-extractors.log"
DEC_LOG="${HOME}/.ralph/logs/decision-extract-$(date +%Y%m%d).log"
SEM_LOG="${HOME}/.ralph/logs/semantic-realtime-$(date +%Y%m%d).log"
STATE_DIR="${HOME}/.ralph/state/session-end-extractors"
MAX_FILES=25
CONTENT_LIMIT=60000
VERDICT_TIMEOUT_TICKS=30   # 30 x 0.2s = 6s per module log, signal-based

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# log_offset <file> — line count BEFORE invoking a module (its forks append).
log_offset() { wc -l < "$1" 2>/dev/null || echo 0; }

# wait_verdict <file> <offset> <pattern> — first NEW line matching pattern,
# waiting for the signal itself. Empty output = module stayed silent.
wait_verdict() {
    local file="$1" off="$2" pattern="$3" i line
    for i in $(seq 1 "$VERDICT_TIMEOUT_TICKS"); do
        sleep 0.2
        line=$(tail -n +"$((off + 1))" "$file" 2>/dev/null | grep -m1 -E "$pattern" || true)
        if [[ -n "$line" ]]; then
            printf '%s' "$line"
            return 0
        fi
    done
    printf ''
}

# ---------------------------------------------------------------------------
# Background mode: self-invoked via nohup (survives terminal HUP).
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--bg-run" ]]; then
    BG_ROOT="$2" BG_TRANSCRIPT="$3" BG_STATE="$4" BG_SESSION="$5"
    BG_FILES="$6"
    cd "$BG_ROOT" 2>/dev/null || exit 0

    VAULT_DIR="${RALPH_VAULT_DIR:-${HOME}/Documents/Obsidian/MiVault}"
    COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$COMMON_DIR" ]]; then MAIN_DIR="$(dirname "$COMMON_DIR")"; else MAIN_DIR="$BG_ROOT"; fi
    STATE_FILE="$BG_STATE/$(basename "$MAIN_DIR").hashes"

    # Unquoted iteration split paths on spaces; read line-by-line instead.
    while IFS= read -r FILE; do
        [[ -n "$FILE" ]] || continue
        if [[ ! -f "$FILE" ]]; then
            log "skipped: not a file: $FILE"
            continue
        fi
        SIZE=$(wc -c < "$FILE" 2>/dev/null || echo 0)
        CONTENT=$(head -c "$CONTENT_LIMIT" "$FILE" 2>/dev/null)
        if (( SIZE > CONTENT_LIMIT )); then
            log "truncated: $FILE ($SIZE -> $CONTENT_LIMIT bytes; header patterns still scanned)"
        fi
        # Hash covers size+content: two files sharing a truncated prefix must
        # not dedupe to each other.
        HASH=$(printf '%s:%s' "$SIZE" "$CONTENT" | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | awk '{print $1}')
        if [[ -z "$HASH" ]]; then
            log "note: no sha256 tool available — dedupe disabled for $FILE"
        elif [[ -f "$STATE_FILE" ]] && grep -qxF "$HASH" "$STATE_FILE"; then
            log "skipped: already extracted (hash $HASH): $FILE"
            continue
        fi

        DEC_OFF=$(log_offset "$DEC_LOG")
        SEM_OFF=$(log_offset "$SEM_LOG")

        STDIN=$(jq -cn --arg fp "$FILE" --arg cwd "$BG_ROOT" --arg sid "$BG_SESSION" --arg content "$CONTENT" \
            '{session_id:$sid,transcript_path:"",cwd:$cwd,tool_name:"Edit",
              tool_input:{file_path:$fp,old_string:"",new_string:$content}}') \
            || { log "failed: payload build: $FILE"; continue; }
        printf '%s' "$STDIN" | /bin/bash "$HOOK_DIR/decision-extractor.sh" >/dev/null 2>&1
        printf '%s' "$STDIN" | /bin/bash "$HOOK_DIR/semantic-realtime-extractor.sh" >/dev/null 2>&1

        DEC_V=$(wait_verdict "$DEC_LOG" "$DEC_OFF" 'Created episode:|No architectural decisions detected|ERROR decision-extractor|ERROR: Could not acquire index lock')
        SEM_V=$(wait_verdict "$SEM_LOG" "$SEM_OFF" 'Realtime extraction complete:|ERROR semantic-realtime')

        EXTRACTED=0
        [[ "$DEC_V" == *"Created episode"* ]] && EXTRACTED=1
        if [[ "$SEM_V" == *"Realtime extraction complete:"* ]]; then
            SEM_N=$(printf '%s' "$SEM_V" | sed -E 's/.*complete: ([0-9]+) facts.*/\1/')
            (( SEM_N >= 1 )) && EXTRACTED=1
        fi

        if [[ -z "$DEC_V" && -z "$SEM_V" ]]; then
            log "no-op: module logs silent for $FILE (likely trivial content — retried next session)"
            continue
        fi
        [[ "$DEC_V" == *"ERROR"* || "$SEM_V" == *"ERROR"* ]] \
            && log "module error for $FILE: dec=[${DEC_V:-none}] sem=[${SEM_V:-none}]"
        if [[ "$DEC_V" == *"No architectural decisions detected"* && "$SEM_V" == *"complete: 0 facts"* ]]; then
            log "no-op: heuristics did not fire for $FILE (dec=none sem=0)"
            continue
        fi
        if (( EXTRACTED )); then
            log "extracted: $FILE (dec=[${DEC_V:-none}] sem=[${SEM_V:-none}])"
            if [[ -n "$HASH" ]]; then
                printf '%s\n' "$HASH" >> "$STATE_FILE" 2>/dev/null || true
                # Bound the state file's growth: keep the most recent hashes.
                if [[ "$(wc -l < "$STATE_FILE" 2>/dev/null || echo 0)" -gt 5000 ]]; then
                    tail -n 4000 "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null \
                        && mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
                fi
            fi
        fi
    done <<< "$BG_FILES"
    exit 0
fi

# ---------------------------------------------------------------------------
# Main (SessionEnd): discover, cap, detach.
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)

SESSION_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // "session-end"' 2>/dev/null)
[[ -z "$SESSION_CWD" || "$SESSION_CWD" == "null" ]] && SESSION_CWD="$PWD"
PROJECT_ROOT="$(git -C "$SESSION_CWD" rev-parse --show-toplevel 2>/dev/null || echo "$SESSION_CWD")"
# Canonical form: git reports the physical path (/private/var on macOS) while
# transcript file_paths carry whatever the session used (/var...) — without
# this, the prefix match below discards every file.
PROJECT_ROOT="$(cd "$PROJECT_ROOT" 2>/dev/null && pwd -P || echo "$PROJECT_ROOT")"
mkdir -p "$STATE_DIR" 2>/dev/null || true

FILES=""
TOTAL=0
if [[ -n "$TRANSCRIPT" && -f "$TRANSCRIPT" ]]; then
    DISCOVERED=$(jq -r 'select(.type=="assistant") | .message.content[]?
        | select(.type=="tool_use")
        | select(.name=="Edit" or .name=="Write" or .name=="MultiEdit")
        | .input.file_path // empty' "$TRANSCRIPT" 2>/dev/null | sort -u)
    while IFS= read -r f; do
        [[ -n "$f" && -f "$f" ]] || continue
        case "$f" in "$PROJECT_ROOT"/*) ;; *) continue ;; esac
        case "$f" in
            *.ts|*.tsx|*.js|*.jsx|*.py|*.md|*.sh|*.json|*.yaml|*.yml|*.toml) ;;
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
    echo '{"continue": true}'
    exit 0
fi

if (( TOTAL > MAX_FILES )); then
    log "capping: $TOTAL eligible files -> $MAX_FILES (rest deferred to future sessions)"
    FILES=$(printf '%s' "$FILES" | head -n "$MAX_FILES")
fi

# One detached job; HUP-immune; env (incl. RALPH_VAULT_DIR for tests) inherits.
nohup bash "$0" --bg-run "$PROJECT_ROOT" "$TRANSCRIPT" "$STATE_DIR" "$SESSION_ID" "$FILES" >/dev/null 2>&1 &
log "session-end extraction dispatched: $TOTAL discovered, $(printf '%s' "$FILES" | grep -c .) dispatched (background)"
echo '{"continue": true}'
