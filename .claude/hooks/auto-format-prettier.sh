#!/bin/bash
# auto-format-prettier.sh - Auto-format JS/TS files with Prettier after edits
# VERSION: 2.68.6
# HOOK: PostToolUse (Edit|Write)
# Part of Multi-Agent Ralph Loop v2.66.0

set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Read stdin
INPUT=$(cat)

# Only process JS/TS files
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if it's a JS/TS/JSON file
if [[ ! "$FILE_PATH" =~ \.(js|jsx|ts|tsx|json)$ ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if prettier is available
if ! command -v npx &> /dev/null; then
    echo '{"continue": true}'
    exit 0
fi

# Run prettier silently
if npx prettier --write "$FILE_PATH" &>/dev/null; then
    # Formatted successfully (silent)
    :
fi

echo '{"continue": true}'
