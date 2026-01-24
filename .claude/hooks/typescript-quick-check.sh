#!/bin/bash
# typescript-quick-check.sh - Quick TypeScript check after editing .ts/.tsx files
# VERSION: 1.0.1
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

# Only process TS files
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

if [[ -z "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if it's a TS file
if [[ ! "$FILE_PATH" =~ \.(ts|tsx)$ ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
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
    echo "[Hook] ⚠️  TypeScript errors in ${FILE_BASENAME}:" >&2
    echo "$ERRORS" | while read -r line; do
        echo "  $line" >&2
    done
fi

echo '{"continue": true}'
