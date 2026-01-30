#!/bin/bash
#!/usr/bin/env bash
# Stop-Slop Hook - Detects AI writing patterns
# VERSION: 1.0.2
# Purpose: Detect filler phrases and AI writing patterns in prose
#
# FIX v1.0.2: LOW-003 - Added consistent error handling with JSON output
# FIX v1.0.1: HIGH-001 - Fixed ReDoS vulnerability using -F flag for fixed string matching

set -euo pipefail

# LOW-003 FIX: Error trap ensures valid JSON output on failure
trap 'echo "{\"continue\": true}"' ERR EXIT

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
        # HIGH-001 FIX: Use -F for fixed string matching (prevents ReDoS via regex injection)
        if grep -qiF -- "$phrase" "$FILE_PATH"; then
            FINDINGS=$((FINDINGS + 1))
        fi
    done

    if [[ $FINDINGS -gt 0 ]]; then
        echo "⚠️  Stop-Slop: Found $FINDINGS filler phrases"
        # LOW-003 FIX: Clear trap before normal exit to prevent duplicate JSON
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi
fi

# LOW-003 FIX: Clear trap and output success
trap - ERR EXIT
echo '{"continue": true}'
