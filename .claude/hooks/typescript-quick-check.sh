#!/bin/bash
# typescript-quick-check.sh - Quick TypeScript check after editing .ts/.tsx files
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

# Only process TS files
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

# Check if it's a TS file
if [[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]]; then
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

# Find tsconfig.json
DIR=$(dirname "$FILE_PATH")
TSCONFIG=""
while [[ "$DIR" != "/" ]]; do
    if [[ -f "$DIR/tsconfig.json" ]]; then
        TSCONFIG="$DIR/tsconfig.json"
        break
    fi
    DIR=$(dirname "$DIR")
done

if [[ -z "$TSCONFIG" ]]; then
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

PROJECT_DIR=$(dirname "$TSCONFIG")

# Run quick tsc check (only show errors for this file)
TSC_OUTPUT=$(cd "$PROJECT_DIR" && npx tsc --noEmit --pretty false 2>&1 || true)

# Filter errors for the edited file only
FILE_BASENAME=$(basename "$FILE_PATH")
ERRORS=$(echo "$TSC_OUTPUT" | grep -E "^.*${FILE_BASENAME}.*error TS" | head -5 || true)

if [[ -n "$ERRORS" ]]; then
    # v2.69.0: Use systemMessage instead of stderr (fixes hook error warnings)
    # Count errors for summary
    ERROR_COUNT=$(echo "$ERRORS" | wc -l | tr -d ' ')
    MSG="⚠️ TypeScript errors in ${FILE_BASENAME}: ${ERROR_COUNT} issues found"
    trap - ERR EXIT
    echo "{\"continue\": true, \"systemMessage\": \"${MSG}\"}"
    exit 0
fi

trap - ERR EXIT
echo '{"continue": true}'
