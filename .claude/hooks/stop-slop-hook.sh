#!/usr/bin/env bash
umask 077
# Stop-Slop Hook - Detects AI writing patterns
# VERSION: 1.1.0
# Purpose: Detect filler phrases / AI writing patterns in prose (advisory only).
#
# Output contract (see tests/HOOK_FORMAT_REFERENCE.md):
#   - This hook never blocks. "Allow" == clean exit 0 with EMPTY stdout, which
#     is valid for Stop AND PostToolUse/PreToolUse events.
#   - Any advisory message goes to STDERR, never stdout (stdout must be JSON or
#     empty, otherwise CC reports "(root): Invalid input").
#
# FIX v1.1.0: removed the `trap ... ERR EXIT` double-emit bug (early-return
#   branches exited without clearing the EXIT trap, printing a 2nd JSON object →
#   "Hook JSON output validation failed — (root): Invalid input"). Success is now
#   a clean exit 0 with no stdout, so there is nothing to duplicate.

set -uo pipefail

# Read stdin (length-limited per SEC-111). Never fail the hook on read issues.
INPUT=$(head -c 100000 || true)

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

# No file to inspect (e.g. Stop event, or non-file tool) → allow.
if [[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]]; then
    exit 0
fi

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

findings=0
for phrase in "${FILLER_PHRASES[@]}"; do
    # -F fixed-string match (prevents ReDoS via regex injection — HIGH-001)
    if grep -qiF -- "$phrase" "$FILE_PATH" 2>/dev/null; then
        findings=$((findings + 1))
    fi
done

if [[ "$findings" -gt 0 ]]; then
    # Advisory only — to STDERR so stdout stays empty/valid.
    echo "⚠️  Stop-Slop: found $findings filler phrase pattern(s) in $FILE_PATH" >&2
fi

# Allow: clean exit 0, empty stdout.
exit 0
