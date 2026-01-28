#!/bin/bash
# debug-stdin.sh - Debug script to see EXACTLY what JSON the statusline receives
# Usage: Set as statusLine.command in settings.json

# Read stdin JSON
stdin_data=$(cat)

# Pretty print the entire JSON to a file
echo "$stdin_data" | jq '.' > ~/.ralph/logs/statusline-stdin-debug.json 2>/dev/null || echo "$stdin_data" > ~/.ralph/logs/statusline-stdin-debug.txt

# Output key fields for quick visibility
model=$(echo "$stdin_data" | jq -r '.model.display_name // "no-model"')
version=$(echo "$stdin_data" | jq -r '.version // "no-version"')

# Check if context_window exists
has_context=$(echo "$stdin_data" | jq 'has("context_window")')

if [[ "$has_context" == "true" ]]; then
    context_remaining=$(echo "$stdin_data" | jq -r '.context_window.remaining_percentage // "null"')
    context_used=$(echo "$stdin_data" | jq -r '.context_window.used_percentage // "null"')
    echo "🔍 v${version} [${model}] ctx:${context_remaining}% (${context_used}% used)"
else
    echo "🔍 v${version} [${model}] NO-CONTEXT-WINDOW-FIELD"
fi

# Also show the JSON keys available
keys=$(echo "$stdin_data" | jq -r 'keys | join(", ")')
echo "🔑 Keys: ${keys}"

# Log full path
echo "📁 Full debug: ~/.ralph/logs/statusline-stdin-debug.json"
