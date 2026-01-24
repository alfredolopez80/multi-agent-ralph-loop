#!/bin/bash
# VERSION: 2.69.0
# v2.68.9: SEC-107 FIX - Validate active context name to prevent path traversal
# context-injector.sh - Injects active context into session
# HOOK: SessionStart
# Part of Multi-Agent Ralph Loop v2.68.6
# v2.68.6: Version bump for consistency audit compliance

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# SEC-033: Graceful error handling (SessionStart outputs text as additionalContext)
trap 'echo "Context injection skipped"' ERR EXIT

CONTEXTS_DIR="${HOME}/.claude/contexts"
STATE_FILE="${HOME}/.ralph/state/active-context.txt"

# Read stdin (hook input)
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top

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

        # v2.69.0: Output context info to stdout (SessionStart hooks can use plain text)
        # Removed stderr which causes hook error warnings in other event types
        echo "[Context] Active: ${ACTIVE_CONTEXT}"
        echo "[Context] Mode: ${MODE}"
        echo "[Context] Focus: ${FOCUS}"

        # Inject context into session via environment-like mechanism
        # The context file itself is in ~/.claude/contexts/ and can be read by Claude
    fi
fi

# Pass through the input unchanged
echo "$INPUT"
