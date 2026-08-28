#!/bin/bash
umask 077
# session-end-extractors.sh — Cold-path vault extraction (T95/C9, epic #47) v4
# Event: SessionEnd
#
# WHY: decision-extractor.sh + semantic-realtime-extractor.sh ran synchronously
# on every Edit/Write (measured 79 ms/edit median, N=7). C9 moves the TRIGGER
# out of the hot path: this hook discovers which files the session edited from
# the SESSION TRANSCRIPT and runs the SAME modules, UNMODIFIED in their
# extraction logic, once per unique file, in ONE nohup-detached background job.
#
# DISCOVERY (v2): from transcript_path — NOT git status. This repo's worker
# contract is a CLEAN tree at session end, so dirty-state discovery was a
# structural no-op for the standard workflow. Works without git too.
#
# VERDICT CHANNEL (v4, RETURN 3): the modules' daily logs are SHARED PER
# MACHINE — concurrent SessionEnds (a normal Q-team) stole each other's
# verdict lines, recording hashes for files that were never extracted
# (permanent false dedupe, reviewer-reproduced). v4 injects a PRIVATE
# RALPH_VERDICT_FILE per processed file into each module fork; both modules
# append "DEC …"/"SEM …" verdict lines there; the wrapper waits for ITS OWN
# file (both verdicts or a declared timeout) — no offsets, no shared-log
# races, no midnight rotation.
#
# REST OF THE CONTRACT: project identity via cd to the session root before
# forking (get_main_repo/T80(a)); canonical paths everywhere (git reports
# /private/var while sessions say /var); content capped at 30 KB raw so the
# modules' 100 KB stdin guard always sees valid JSON (jq escaping measured
# >1.66x); dedupe by SIZE:CONTENT hash recorded ONLY on a module-reported
# extraction; honest log for every file (extracted / no-op / skipped /
# NOT extracted (limit)); extensions the modules reject are never dispatched.

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${HOME}/.ralph/logs/session-end-extractors.log"
STATE_DIR="${HOME}/.ralph/state/session-end-extractors"
MAX_FILES=25
CONTENT_LIMIT=30000          # raw bytes before embedding (payload stays <100KB after jq escaping)
PAYLOAD_CEILING=90000        # safety net: rebuild smaller if the built JSON still exceeds this
VERDICT_TIMEOUT_TICKS=50     # 50 x 0.2s = 10s per file, waiting on its own verdict file

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# Background mode: self-invoked via nohup (survives terminal SIGHUP).
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--bg-run" ]]; then
    BG_ROOT="$2" BG_STATE="$3" BG_SESSION="$4"
    BG_FILES="$5"
    cd "$BG_ROOT" 2>/dev/null || { log "bg: cannot cd to session root $BG_ROOT — aborting job"; exit 1; }

    PROCESSED=0
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
        HASH=$(printf '%s:%s' "$SIZE" "$CONTENT" | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | awk '{print $1}')
        if [[ -z "$HASH" ]]; then
            log "note: no sha256 tool available — dedupe disabled for $FILE"
        elif [[ -f "$BG_STATE/$(basename "$BG_ROOT").hashes" ]] && grep -qxF "$HASH" "$BG_STATE/$(basename "$BG_ROOT").hashes"; then
            log "skipped: already extracted (hash $HASH): $FILE"
            continue
        fi

        VERDICT_FILE=$(mktemp 2>/dev/null) || { log "failed: no tmp for verdict file"; continue; }

        STDIN=$(jq -cn --arg fp "$FILE" --arg cwd "$BG_ROOT" --arg sid "$BG_SESSION" --arg content "$CONTENT" \
            '{session_id:$sid,transcript_path:"",cwd:$cwd,tool_name:"Edit",
              tool_input:{file_path:$fp,old_string:"",new_string:$content}}') \
            || { log "failed: payload build: $FILE"; rm -f "$VERDICT_FILE"; continue; }
        # Safety net: jq escaping can exceed the raw size (measured >1.66x);
        # the modules' 100KB stdin guard must never see a cut-off JSON.
        if (( ${#STDIN} > PAYLOAD_CEILING )); then
            CONTENT=$(head -c 15000 "$FILE" 2>/dev/null)
            STDIN=$(jq -cn --arg fp "$FILE" --arg cwd "$BG_ROOT" --arg sid "$BG_SESSION" --arg content "$CONTENT" \
                '{session_id:$sid,transcript_path:"",cwd:$cwd,tool_name:"Edit",
                  tool_input:{file_path:$fp,old_string:"",new_string:$content}}') \
                || { log "failed: payload rebuild: $FILE"; rm -f "$VERDICT_FILE"; continue; }
            log "truncated: $FILE (payload ceiling rebuilt at 15000 bytes)"
        fi

        printf '%s' "$STDIN" | RALPH_VERDICT_FILE="$VERDICT_FILE" /bin/bash "$HOOK_DIR/decision-extractor.sh" >/dev/null 2>&1
        printf '%s' "$STDIN" | RALPH_VERDICT_FILE="$VERDICT_FILE" /bin/bash "$HOOK_DIR/semantic-realtime-extractor.sh" >/dev/null 2>&1

        # Wait for THIS file's own verdict file: both verdicts or declared timeout.
        DEC_V=""; SEM_V=""
        for _ in $(seq 1 "$VERDICT_TIMEOUT_TICKS"); do
            sleep 0.2
            DEC_V=$(grep '^DEC ' "$VERDICT_FILE" 2>/dev/null | tail -1)
            SEM_V=$(grep '^SEM ' "$VERDICT_FILE" 2>/dev/null | tail -1)
            [[ -n "$DEC_V" && -n "$SEM_V" ]] && break
        done
        rm -f "$VERDICT_FILE"

        EXTRACTED=0
        [[ "$DEC_V" == "DEC created "* ]] && EXTRACTED=1
        if [[ "$SEM_V" == "SEM complete facts="* ]]; then
            SEM_N=$(printf '%s' "$SEM_V" | sed -E 's/^SEM complete facts=([0-9]+).*/\1/')
            (( SEM_N >= 1 )) && EXTRACTED=1
        fi

        if [[ -z "$DEC_V" && -z "$SEM_V" ]]; then
            log "no-op: module logs silent for $FILE (likely trivial content — retried next session)"
            PROCESSED=$((PROCESSED + 1))
            continue
        fi
        [[ "$DEC_V" == *"ERROR"* || "$SEM_V" == *"ERROR"* ]] \
            && log "module error for $FILE: dec=[${DEC_V:-none}] sem=[${SEM_V:-none}]"
        if (( EXTRACTED )); then
            log "extracted: $FILE (dec=[${DEC_V:-none}] sem=[${SEM_V:-none}])"
            if [[ -n "$HASH" ]]; then
                STATE_FILE="$BG_STATE/$(basename "$BG_ROOT").hashes"
                printf '%s\n' "$HASH" >> "$STATE_FILE" 2>/dev/null || true
                if [[ "$(wc -l < "$STATE_FILE" 2>/dev/null || echo 0)" -gt 5000 ]]; then
                    tail -n 4000 "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null \
                        && mv "${STATE_FILE}.tmp" "$STATE_FILE" 2>/dev/null || true
                fi
            fi
        else
            log "no-op: heuristics did not fire for $FILE (dec=[${DEC_V:-none}] sem=[${SEM_V:-none}])"
        fi
        PROCESSED=$((PROCESSED + 1))
    done <<< "$BG_FILES"
    log "job finished ($PROCESSED files processed)"
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
        # Canonicalize each transcript path too (same physical-vs-logical trap).
        f=$(realpath "$f" 2>/dev/null || printf '%s' "$f")
        case "$f" in "$PROJECT_ROOT"/*) ;; *) continue ;; esac
        # Only extensions the modules actually scan — dispatching .md/.yml/
        # .yaml/.toml bought 12s of dead polling and a lying "likely trivial".
        case "$f" in
            *.ts|*.tsx|*.js|*.jsx|*.py|*.sh|*.json) ;;
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
    OVER=$((TOTAL - MAX_FILES))
    log "NOT extracted (limit): $OVER file(s) over the $MAX_FILES cap — they stay eligible for future sessions"
    FILES=$(printf '%s' "$FILES" | head -n "$MAX_FILES")
fi

# One detached job; HUP-immune; env (incl. RALPH_VAULT_DIR for tests) inherits.
nohup bash "$0" --bg-run "$PROJECT_ROOT" "$STATE_DIR" "$SESSION_ID" "$FILES" >/dev/null 2>&1 &
log "session-end extraction dispatched: $TOTAL discovered, $(printf '%s' "$FILES" | grep -c .) dispatched (background)"
echo '{"continue": true}'
