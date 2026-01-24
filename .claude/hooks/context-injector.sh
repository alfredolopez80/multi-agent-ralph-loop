#!/bin/bash
# VERSION: 2.68.9
# v2.68.9: SEC-107 FIX - Validate active context name to prevent path traversal
# context-injector.sh - Injects active context into session
# HOOK: SessionStart
# Part of Multi-Agent Ralph Loop v2.68.6
# v2.68.6: Version bump for consistency audit compliance

set -euo pipefail

# SEC-033: Graceful error handling (SessionStart outputs text as additionalContext)
trap 'echo "Context injection skipped"' ERR

CONTEXTS_DIR="${HOME}/.claude/contexts"
STATE_FILE="${HOME}/.ralph/state/active-context.txt"

# Read stdin (hook input)
INPUT=$(cat)

# Check if there's an active context
if [[ -f "$STATE_FILE" ]]; then
    ACTIVE_CONTEXT=$(cat "$STATE_FILE")

    # SEC-107 FIX: Validate context name to prevent path traversal
    # Only allow alphanumeric, underscore, and dash characters
    if [[ ! "$ACTIVE_CONTEXT" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Context injection skipped (invalid context name)"
        exit 0
    fi

    CONTEXT_FILE="${CONTEXTS_DIR}/${ACTIVE_CONTEXT}.md"

    if [[ -f "$CONTEXT_FILE" ]]; then
        # Extract key info from context
        MODE=$(grep -m1 '^\*\*Mode\*\*:' "$CONTEXT_FILE" 2>/dev/null | sed 's/.*: //' || echo "Unknown")
        FOCUS=$(grep -m1 '^\*\*Focus\*\*:' "$CONTEXT_FILE" 2>/dev/null | sed 's/.*: //' || echo "Unknown")

        # Output context reminder to stderr (shown to user)
        echo "[Context] Active: ${ACTIVE_CONTEXT}" >&2
        echo "[Context] Mode: ${MODE}" >&2
        echo "[Context] Focus: ${FOCUS}" >&2

        # Inject context into session via environment-like mechanism
        # The context file itself is in ~/.claude/contexts/ and can be read by Claude
    fi
fi

# Pass through the input unchanged
echo "$INPUT"
