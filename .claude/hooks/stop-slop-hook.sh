#!/usr/bin/env bash
# Stop-Slop Hook - Detects AI writing patterns
# VERSION: 1.0.0
# Purpose: Detect filler phrases and AI writing patterns in prose

set -euo pipefail

readonly VERSION="1.0.0"

# Read stdin
INPUT=$(head -c 100000)

# Parse input
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check for common AI filler phrases
if [[ -f "$FILE_PATH" ]]; then
    FILLER_PHRASES=(
        "Certainly!"
        "It is important to note"
        "It's worth noting"
        "It's important to remember"
        "Please note"
        "Keep in mind"
        "It should be noted"
        "It's worth mentioning"
    )

    FINDINGS=0
    for phrase in "${FILLER_PHRASES[@]}"; do
        if grep -qi "$phrase" "$FILE_PATH"; then
            FINDINGS=$((FINDINGS + 1))
        fi
    done

    if [[ $FINDINGS -gt 0 ]]; then
        echo "⚠️  Stop-Slop: Found $FINDINGS filler phrases"
        exit 0
    fi
fi

echo '{"continue": true}'
