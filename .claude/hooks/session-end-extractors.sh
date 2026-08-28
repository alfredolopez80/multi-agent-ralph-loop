#!/bin/bash
umask 077
# session-end-extractors.sh — Cold-path vault extraction (T95 / C9, epic #47)
# Event: SessionEnd
#
# WHY THIS EXISTS: decision-extractor.sh and semantic-realtime-extractor.sh ran
# SYNCHRONOUSLY on every Edit/Write (measured median 47 ms + 32 ms per edit,
# N=7) — memory maintenance inside the ordinary hot path. C9 moves them out:
# this wrapper runs the SAME modules, UNMODIFIED, once per session over the
# files the session actually touched (git status), in ONE detached background
# job. The prompt/session loop never pays for extraction again; the vault gets
# the same decisions/facts it always did (verified by
# tests/hooks/test_session_end_extractors.sh).
#
# Composition, not rewrite: the two modules remain the only extraction logic
# (same as vault-fact-extractor.sh, which composes them for the hot path).
# Per-file failures are logged and skipped — extraction is best-effort by
# design; the JSON below is emitted immediately.

INPUT=$(head -c 100000)
set -uo pipefail   # no -e: best-effort job; every failure is logged

# Resolve the session's working tree from the hook payload (SessionEnd carries
# cwd), same discipline as anti-rationalization-gate.sh v2.0.1 (T87).
SESSION_CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[[ -z "$SESSION_CWD" || "$SESSION_CWD" == "null" ]] && SESSION_CWD="$PWD"
PROJECT_ROOT="$(git -C "$SESSION_CWD" rev-parse --show-toplevel 2>/dev/null || echo "$SESSION_CWD")"

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${HOME}/.ralph/logs/session-end-extractors.log"
MAX_FILES=25
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true; }

# Text files only; the modules apply their own per-type heuristics. The cap
# keeps a chaotic session from forking an unbounded loop.
DIRTY_FILES=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null \
  | awk '$1 ~ /^(M|A|\?\?)$/ {print $2}' \
  | grep -E '\.(ts|tsx|js|jsx|py|md|sh|json|yaml|yml|toml)$' \
  | head -n "$MAX_FILES")

if [[ -z "$DIRTY_FILES" ]]; then
  log "No eligible dirty files under $PROJECT_ROOT — nothing to extract"
  echo '{"continue": true}'
  exit 0
fi

(
  for rel in $DIRTY_FILES; do
    FILE="$PROJECT_ROOT/$rel"
    [[ -f "$FILE" ]] || continue
    # Same stdin contract the extractors already consume (PostToolUse Edit);
    # new_string carries the file's current content — in batch mode the whole
    # file IS the new content, which is exactly what the modules scan.
    STDIN=$(jq -n --arg fp "$FILE" --arg content "$(cat "$FILE" 2>/dev/null)" \
      '{session_id:"session-end", transcript_path:"", cwd:$fp, tool_name:"Edit",
        tool_input:{file_path:$fp, old_string:"", new_string:$content}}' 2>/dev/null) || continue
    printf '%s' "$STDIN" | /bin/bash "$_HOOK_DIR/decision-extractor.sh" >/dev/null 2>&1 \
      || log "decision-extractor failed for $rel"
    printf '%s' "$STDIN" | /bin/bash "$_HOOK_DIR/semantic-realtime-extractor.sh" >/dev/null 2>&1 \
      || log "semantic-realtime-extractor failed for $rel"
    log "Extracted (cold): $rel"
  done
) >/dev/null 2>&1 &

log "Session-end extraction dispatched for $(printf '%s\n' "$DIRTY_FILES" | wc -l | tr -d ' ') files (background)"
echo '{"continue": true}'
