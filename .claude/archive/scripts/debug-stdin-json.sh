#!/bin/bash
# debug-stdin-json.sh - Logs the stdin JSON structure for debugging
#
# Add this to settings.json as a statusLine command temporarily:
# "command": "bash /path/to/debug-stdin-json.sh"
#
# Output: /tmp/ralph-stdin-debug.json

stdin_data=$(cat)

# Save full stdin for debugging
echo "$stdin_data" > /tmp/ralph-stdin-debug.json

# Extract and display context_window structure
echo "=== context_window fields ===" > /tmp/ralph-context-debug.txt
echo "$stdin_data" | jq '.context_window // {}' >> /tmp/ralph-context-debug.txt

# Show available keys
echo "" >> /tmp/ralph-context-debug.txt
echo "=== Available keys in context_window ===" >> /tmp/ralph-context-debug.txt
echo "$stdin_data" | jq '.context_window | keys' >> /tmp/ralph-context-debug.txt

# Also output a simple statusline
echo "$stdin_data" | jq -r '"\(.cwd // ".") | ctx_window: \(.context_window | @json)"'
