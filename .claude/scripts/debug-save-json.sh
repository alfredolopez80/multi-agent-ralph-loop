#!/bin/bash
# Simple debug script - save JSON to file
stdin=$(cat)
DEBUG_FILE="${HOME}/debug-statusline.json"

echo "$stdin" > "$DEBUG_FILE"
echo "$stdin" | jq '.context_window' > "${DEBUG_FILE}.context"

# Also show in stderr
echo "JSON saved to $DEBUG_FILE" >&2
echo "Context window:" >&2
echo "$stdin" | jq '.context_window' >&2

# Pass through to real script
echo "$stdin" | .claude/scripts/statusline-ralph.sh
