#!/bin/bash
# Show all keys in statusline JSON
stdin=$(cat)

echo "=== ALL KEYS IN STATUSLINE JSON ===" >&2
echo "$stdin" | jq 'keys' >&2
echo "" >&2
echo "=== context_window KEYS ===" >&2
echo "$stdin" | jq '.context_window | keys' >&2
echo "" >&2
echo "=== FULL context_window OBJECT ===" >&2
echo "$stdin" | jq '.context_window' >&2
echo "" >&2
echo "=== FULL JSON (pretty) ===" >&2
echo "$stdin" | jq '.' >&2
echo "=================================" >&2

# Pass through
echo "$stdin" | .claude/scripts/statusline-ralph.sh
