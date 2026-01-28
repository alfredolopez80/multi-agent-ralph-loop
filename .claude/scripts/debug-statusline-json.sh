#!/bin/bash
# debug-statusline-json.sh - Capture actual JSON from Claude Code
# VERSION: 1.0.0

DEBUG_FILE="${HOME}/ralph-statusline-debug.json"

# Read stdin
stdin=$(cat)

# Save to file
echo "$stdin" | jq '.' > "$DEBUG_FILE"

# Extract and log context_window
echo "$stdin" | jq '.context_window' > "${DEBUG_FILE}.context"

# Log to stderr (won't affect statusline)
echo "=== STATUSLINE DEBUG ===" >&2
echo "JSON saved to: $DEBUG_FILE" >&2
echo "Context window data:" >&2
echo "$stdin" | jq '.context_window' >&2
echo "=====================" >&2

# Show what we're trying to extract
echo "Extraction test:" >&2
USED=$(echo "$stdin" | jq -r '.context_window.used_percentage // "NULL"')
CURR_USAGE=$(echo "$stdin" | jq -r '.context_window.current_usage // "NULL"')
TOTAL_IN=$(echo "$stdin" | jq -r '.context_window.total_input_tokens // "NULL"')
echo "  used_percentage: $USED" >&2
echo "  current_usage: $CURR_USAGE" >&2
echo "  total_input_tokens: $TOTAL_IN" >&2
echo "=====================" >&2

# Continue to real script
exec .claude/scripts/statusline-ralph.sh
