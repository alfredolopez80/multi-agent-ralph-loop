#!/bin/bash
# console-log-detector.sh - Warn about console.log statements after JS/TS edits
# VERSION: 2.69.1
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
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

# Check if it's a JS/TS file
if [[ ! "$FILE_PATH" =~ \.(js|jsx|ts|tsx)$ ]]; then
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

# Search for console.log statements
MATCHES=$(grep -n 'console\.log' "$FILE_PATH" 2>/dev/null | head -5 || true)

if [[ -n "$MATCHES" ]]; then
    # v2.69.0: Use systemMessage instead of stderr (fixes hook error warnings)
    # Count lines for summary
    LINE_COUNT=$(echo "$MATCHES" | wc -l | tr -d ' ')
    MSG="⚠️ console.log found in ${FILE_PATH##*/} (${LINE_COUNT} occurrences) - remove before committing"
    trap - ERR EXIT
    echo "{\"continue\": true, \"systemMessage\": \"${MSG}\"}"
    exit 0
fi

trap - ERR EXIT
echo '{"continue": true}'
