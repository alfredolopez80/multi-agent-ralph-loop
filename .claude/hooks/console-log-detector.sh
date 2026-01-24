#!/bin/bash
# console-log-detector.sh - Warn about console.log statements after JS/TS edits
# VERSION: 2.68.23
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
trap 'output_json' ERR

# Read stdin
INPUT=$(cat)

# Only process JS/TS files
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if it's a JS/TS file
if [[ ! "$FILE_PATH" =~ \.(js|jsx|ts|tsx)$ ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Search for console.log statements
MATCHES=$(grep -n 'console\.log' "$FILE_PATH" 2>/dev/null | head -5 || true)

if [[ -n "$MATCHES" ]]; then
    echo "[Hook] ⚠️  console.log found in ${FILE_PATH##*/}:" >&2
    echo "$MATCHES" | while read -r line; do
        echo "  $line" >&2
    done
    echo "[Hook] Remove console.log before committing" >&2
fi

echo '{"continue": true}'
