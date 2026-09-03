#!/bin/bash
# ============================================================================
# writing-density.sh - v1.0.0
# Hook: UserPromptSubmit
# Purpose: Append the short "remove all mannered prose" instruction to every
#          user turn. Claude Fable 5.1 tends toward dense, mannered prose; the
#          official guidance is to put this instruction in the user message
#          (preferred) rather than only in the system prompt. The full
#          anti-pattern definition lives in ~/.claude/CLAUDE.md; this hook
#          carries only the short form to keep per-turn cost minimal.
# Source: https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5-1#writing-density
# Output: {"continue": true, "hookSpecificOutput": {"hookEventName":
#          "UserPromptSubmit", "additionalContext": "<instruction>"}}
# ============================================================================

# SEC-111: bounded stdin read (input is unused, but drain it so the harness
# never blocks on a full pipe).
INPUT=$(head -c 100000)

set -euo pipefail
umask 077

INSTRUCTION="Please remove all mannered prose."

if command -v jq &>/dev/null; then
    jq -nc --arg ctx "$INSTRUCTION" \
        '{continue: true, hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
else
    printf '{"continue": true, "hookSpecificOutput": {"hookEventName": "UserPromptSubmit", "additionalContext": "%s"}}\n' "$INSTRUCTION"
fi
exit 0
