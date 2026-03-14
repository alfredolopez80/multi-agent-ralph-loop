#!/bin/bash
# session-start-context-visible.sh - SessionStart Hook con contexto VISIBLE
# Hook: SessionStart
# Purpose: Inject claude-mem context AND display it visually in chat
#
# VERSION: 1.0.0

set -euo pipefail

# Configuration
LOG_FILE="${HOME}/.ralph/logs/session-start-context-visible.log"
WORKER_SERVICE="${HOME}/.claude/plugins/cache/thedotmack/claude-mem/10.0.7/scripts/worker-service.cjs"
BUN_BIN="${HOME}/.bun/bin/bun"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# Logging function
log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true
}

log "=== SessionStart Context Visible Hook ==="

# Execute the original claude-mem context hook
OUTPUT=$("$BUN_BIN" "$WORKER_SERVICE" hook claude-code context 2>&1)
EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
    log "ERROR: Worker service failed with exit code $EXIT_CODE"
    log "ERROR: $OUTPUT"
    # Still return success to not block session start
    exit 0
fi

# Extract the additionalContext for visual display
ADDITIONAL_CONTEXT=$(echo "$OUTPUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)

if [[ -n "$ADDITIONAL_CONTEXT" ]]; then
    # Display context visually in chat (this will be shown to user)
    echo ""
    echo "## 📚 Contexto de Sesiones Anteriores"
    echo ""
    echo "$ADDITIONAL_CONTEXT"
    echo ""
    echo "---"
    echo ""
    echo "💡 El contexto de arriba está disponible para Claude en esta sesión."
    echo ""

    log "Context displayed visually (${#ADDITIONAL_CONTEXT} bytes)"
else
    log "WARNING: No additionalContext found in output"
fi

# Return the original JSON for Claude to inject silently
# This ensures Claude still gets the context via additionalContext
echo "$OUTPUT"

log "=== Context Visible Hook Complete ==="
