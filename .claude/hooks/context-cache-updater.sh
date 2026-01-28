#!/bin/bash
# context-cache-updater.sh v1.0.0
# Updates ~/.ralph/cache/context-usage.json from stdin JSON context
# Events: SessionStart, UserPromptSubmit, PostCompact
#
# Output format (UserPromptSubmit only):
# {"continue": true}

set -euo pipefail

CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/context-usage.json"
DEBUG_LOG="${CACHE_DIR}/context-cache-debug.log"
SETTINGS_FILE="${HOME}/.claude-sneakpeek/zai/config/settings.json"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Read stdin JSON (may be empty for some events)
STDIN_JSON=$(cat -)

# Debug: log what we received
echo "=== $(date) - ${CLAUDE_HOOK_EVENT:-unknown} ===" >> "$DEBUG_LOG"
echo "$STDIN_JSON" | jq '.' >> "$DEBUG_LOG" 2>&1 || echo "Empty or invalid JSON" >> "$DEBUG_LOG"
echo "" >> "$DEBUG_LOG"

# If no stdin, exit gracefully
if [[ -z "$STDIN_JSON" ]]; then
    if [[ "${CLAUDE_HOOK_EVENT:-}" == "UserPromptSubmit" ]]; then
        echo '{"continue": true}'
    fi
    exit 0
fi

# Extract context values
context_size=$(echo "$STDIN_JSON" | jq -r '.context_window.context_window.size // .context_window_size // empty')
used_pct=$(echo "$STDIN_JSON" | jq -r '.context_window.context_window.used_percentage // .used_percentage // empty')

# Default to 200k if not found
if [[ -z "$context_size" ]] || [[ "$context_size" == "null" ]]; then
    context_size=200000
fi

# Calculate used tokens from percentage (even if 0% or 100%)
# We'll calculate it anyway and let statusline v2.78.10 validate
used_tokens=$((context_size * used_pct / 100))
free_tokens=$((context_size - used_tokens))
remaining_pct=$((100 - used_pct))

# Write cache file with whatever value we received
cat > "$CACHE_FILE" <<EOF
{
  "timestamp": $(date +%s),
  "context_size": $context_size,
  "used_tokens": $used_tokens,
  "free_tokens": $free_tokens,
  "used_percentage": $used_pct,
  "remaining_percentage": $remaining_pct
}
EOF

# UserPromptSubmit requires JSON response
if [[ "${CLAUDE_HOOK_EVENT:-}" == "UserPromptSubmit" ]]; then
    echo '{"continue": true}'
fi
