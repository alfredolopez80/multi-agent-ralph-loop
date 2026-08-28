#!/bin/bash
umask 077
# session-end-extractors.sh — Cold-path vault extraction (T95/C9, epic #47) v2
# Event: SessionEnd
#
# WHY: decision-extractor.sh + semantic-realtime-extractor.sh ran synchronously
# on every Edit/Write (measured 79 ms/edit median, N=7). C9 moves the TRIGGER
# out of the hot path: this hook discovers which files the session edited and
# runs the SAME modules, UNMODIFIED, once per unique file, in ONE nohup-
# detached background job that survives terminal HUP.
#
# DISCOVERY (v2, after lead RETURN on v1): from transcript_path — NOT git
# status. This repo's worker contract is a CLEAN tree at session end, so
# dirty-state discovery was a structural no-op for the standard workflow:
# committed work was invisible. Transcript parsing mirrors
# session-end-handoff.sh (jq streaming over JSONL; a truncated tail line from
# an abrupt kill only costs the tail, jq keeps prior output). Works without
# git: the project root falls back to the session cwd and the transcript is
# git-independent.
#
# PROJECT IDENTITY: the background job cd's to the session root before
# invoking the modules — their project key comes from get_main_repo over the
# process cwd (T80(a)), exactly what the hot path produced.
#
# DEDUP (v2): per-project content-hash state under
# $HOME/.ralph/state/session-end-extractors/. The hot path extracted per edit;
# a batch must not re-extract identical content session after session (facts
# files are appends — they would grow without bound). Hashes are recorded only
# when extraction actually produced vault entries; no-ops retry next session.
#
# HONEST LOG (v2): "extracted" only when new vault entries appeared for that
# file (before/after listing of the project's decisions+facts dirs); otherwise
# "no-op (heuristics did not fire)" / "skipped: <reason>" / "truncated: ...".
# Content is capped at 60 KB before embedding so the extractors' own 100 KB
# stdin guard still receives valid JSON (finding 2: >100KB payloads were
# silently truncated mid-JSON and the extraction was lost).

set -uo pipefail

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${HOME}/.ralph/logs/session-end-extractors.log"
STATE_DIR="${HOME}/.ralph/state/session-end-extractors"
MAX_FILES=25
CONTENT_LIMIT=60000

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# ---------------------------------------------------------------------------
# Background mode: self-invoked via nohup (finding 4 — plain "&" died with the
# terminal's SIGHUP mid-extraction).
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--bg-run" ]]; then
    BG_ROOT="$2" BG_TRANSCRIPT="$3" BG_STATE="$4" BG_FILES="$5"
    cd "$BG_ROOT" 2>/dev/null || exit 0

    VAULT_DIR="${RALPH_VAULT_DIR:-${HOME}/Documents/Obsidian/MiVault}"
    COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$COMMON_DIR" ]]; then MAIN_DIR="$(dirname "$COMMON_DIR")"; else MAIN_DIR="$BG_ROOT"; fi
    PROJ_DIR="$VAULT_DIR/projects/$(basename "$MAIN_DIR")"
    STATE_FILE="$BG_STATE/$(basename "$MAIN_DIR").hashes"

    for FILE in $BG_FILES; do
        if [[ ! -f "$FILE" ]]; then
            log "skipped: not a file: $FILE"
            continue
        fi
        SIZE=$(wc -c < "$FILE" 2>/dev/null || echo 0)
        CONTENT=$(head -c "$CONTENT_LIMIT" "$FILE" 2>/dev/null)
        if (( SIZE > CONTENT_LIMIT )); then
            log "truncated: $FILE ($SIZE -> $CONTENT_LIMIT bytes; header patterns still scanned)"
        fi
        HASH=$(printf '%s' "$CONTENT" | (shasum -a 256 2>/dev/null || sha256sum 2>/dev/null) | awk '{print $1}')
        if [[ -z "$HASH" ]]; then
            log "note: no sha256 tool available — dedupe disabled for $FILE"
        elif [[ -f "$STATE_FILE" ]] && grep -qxF "$HASH" "$STATE_FILE"; then
            log "skipped: already extracted (hash $HASH): $FILE"
            continue
        fi

        PROJ_DEC="$PROJ_DIR/decisions"; PROJ_FAC="$PROJ_DIR/facts"
        BEFORE=$( { ls "$PROJ_DEC" 2>/dev/null; ls "$PROJ_FAC" 2>/dev/null; } | sort)

        STDIN=$(jq -cn --arg fp "$FILE" --arg cwd "$BG_ROOT" --arg content "$CONTENT" \
            '{session_id:"session-end",transcript_path:"",cwd:$cwd,tool_name:"Edit",
              tool_input:{file_path:$fp,old_string:"",new_string:$content}}') \
            || { log "failed: payload build: $FILE"; continue; }
        printf '%s' "$STDIN" | /bin/bash "$HOOK_DIR/decision-extractor.sh" >/dev/null 2>&1
        printf '%s' "$STDIN" | /bin/bash "$HOOK_DIR/semantic-realtime-extractor.sh" >/dev/null 2>&1

        # The modules fork internally (semantic writes from its own background
        # job), so the vault listing settles LATE. Measuring immediately read
        # a pre-write snapshot, logged a false "no-op", never recorded the
        # hash, and the next session re-extracted identical content — the
        # duplicate-facts bug. Measure only once the listing is stable.
        wait_stable() {
            local prev=-1 cur="" stable=0 i
            for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
                sleep 0.3
                cur=$( { ls "$PROJ_DEC" 2>/dev/null; ls "$PROJ_FAC" 2>/dev/null; } | sort)
                if [[ "$cur" == "$prev" ]]; then
                    stable=$((stable + 1))
                else
                    stable=0
                    prev=$cur
                fi
                if (( stable >= 3 )); then printf '%s\n' "$cur"; return 0; fi
            done
            printf '%s\n' "$cur"
        }
        AFTER=$(wait_stable)
        NEW=$(comm -13 <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER") | grep -c . || true)
        if [[ "${NEW:-0}" -ge 1 ]]; then
            log "extracted: $FILE (+$NEW vault entries)"
            if [[ -n "$HASH" ]]; then
                printf '%s\n' "$HASH" >> "$STATE_FILE" 2>/dev/null || true
            fi
        else
            log "no-op: heuristics did not fire for $FILE"
        fi
    done
    exit 0
fi

# ---------------------------------------------------------------------------
# Main (SessionEnd): discover, cap, detach.
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)

SESSION_CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
TRANSCRIPT=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null)
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
nohup bash "$0" --bg-run "$PROJECT_ROOT" "$TRANSCRIPT" "$STATE_DIR" "$FILES" >/dev/null 2>&1 &
log "session-end extraction dispatched: $TOTAL discovered, $(printf '%s' "$FILES" | grep -c .) dispatched (background)"
echo '{"continue": true}'
