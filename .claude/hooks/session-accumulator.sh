#!/usr/bin/env bash
umask 077
# session-accumulator.sh — Captures learnings during a session
# Event: PostToolUse (Edit|Write)
# VERSION: 3.1.0
# v3.1.0: fire-and-forget — respond JSON first, do vault I/O in background
#
# Accumulates potential learnings in a session buffer file.
# The exit-review skill classifies them at session end.
# Learnings go to vault dir, NOT to stdout (security: prevents hook chain leakage).
#
# Fire-and-forget: vault append is pure logging; nothing reads it synchronously
# in the hook chain. Detaching the worker drops latency from ~51ms to <10ms.

# Parent mode: read stdin, spawn worker, respond immediately
if [[ "${SESSION_ACCUMULATOR_WORKER:-0}" != "1" ]]; then
  # SEC-111: cap stdin at 100KB in the parent
  INPUT=$(head -c 100000)
  SESSION_ACCUMULATOR_WORKER=1 nohup bash "$0" <<<"$INPUT" >/dev/null 2>&1 &
  disown 2>/dev/null || true
  echo '{"continue": true}'
  exit 0
fi

# --- Worker mode ---
INPUT=$(head -c 100000)

set -euo pipefail

# Worker is detached; no JSON response needed. Just log-and-exit on error.
trap 'exit 0' ERR INT TERM EXIT

# Extract tool and file info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.command // ""' 2>/dev/null)

# Only accumulate for significant edits (not trivial changes)
if [[ -z "$FILE_PATH" ]]; then
    exit 0
fi

# Vault and buffer configuration
VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo 'unknown')")
BUFFER_DIR="$VAULT_DIR/projects/$PROJECT_NAME/lessons"
BUFFER_FILE="$BUFFER_DIR/session-$(date +%Y-%m-%d).md"

# Only accumulate if vault exists
if [[ ! -d "$VAULT_DIR" ]]; then
    exit 0
fi

# Ensure buffer directory exists
mkdir -p "$BUFFER_DIR" 2>/dev/null || true

# Extract file extension for categorization
EXT="${FILE_PATH##*.}"
CATEGORY="general"
case "$EXT" in
    ts|tsx|js|jsx) CATEGORY="typescript" ;;
    py) CATEGORY="python" ;;
    sh|bash) CATEGORY="hooks" ;;
    md) CATEGORY="documentation" ;;
    json) CATEGORY="configuration" ;;
    rs) CATEGORY="rust" ;;
    sol) CATEGORY="solidity" ;;
esac

# Append to session buffer (NOT to stdout)
{
    echo ""
    echo "## $(date +%H:%M) — $TOOL_NAME on $FILE_PATH"
    echo "- Category: $CATEGORY"
    echo "- Tool: $TOOL_NAME"
    echo "- File: $(basename "$FILE_PATH")"
} >> "$BUFFER_FILE" 2>/dev/null || true

# Worker mode: clear trap and exit quietly (parent already responded)
trap - EXIT
exit 0
