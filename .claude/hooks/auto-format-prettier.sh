#!/bin/bash
# auto-format-prettier.sh - Auto-format JS/TS files with Prettier after edits
# VERSION: 2.69.0
# v2.68.9: SEC-102 FIX - Validate FILE_PATH to prevent command injection
# HOOK: PostToolUse (Edit|Write)
# Part of Multi-Agent Ralph Loop v2.66.0

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Read stdin
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top

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

# SEC-102 FIX: Validate FILE_PATH to prevent command injection
# Use realpath to canonicalize and reject paths with dangerous characters
FILE_PATH_REAL=$(realpath -m "$FILE_PATH" 2>/dev/null) || {
    echo '{"continue": true}'
    exit 0
}
# Reject paths containing shell metacharacters
if [[ "$FILE_PATH_REAL" =~ [\;\|\&\`\$\(\)\{\}\[\]\<\>] ]]; then
    echo '{"continue": true}'
    exit 0
fi
# Use canonicalized path
FILE_PATH="$FILE_PATH_REAL"

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
