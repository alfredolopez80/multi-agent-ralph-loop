#!/bin/bash
# continuous-learning.sh - Extract reusable patterns from session at end
# VERSION: 2.68.2
# Hook: Stop
# Part of Multi-Agent Ralph Loop v2.68.2
#
# Inspired by everything-claude-code's continuous learning skill
#
# v2.68.2: FIX CRIT-011 - Updated hook type declaration and trap pattern

set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
# Stop hooks use {"decision": "approve"} format
output_json() {
    echo '{"decision": "approve"}'
}
trap 'output_json' ERR EXIT

# Read stdin
INPUT=$(cat)

LEARNED_DIR="${HOME}/.claude/skills/learned"
mkdir -p "$LEARNED_DIR"

# Get session transcript path if available
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
TRANSCRIPT="${HOME}/.claude/projects/${CLAUDE_PROJECT_ID:-default}/${SESSION_ID}.jsonl"

# Skip if transcript doesn't exist or is too short
if [[ ! -f "$TRANSCRIPT" ]]; then
    trap - EXIT
    echo '{"decision": "approve"}'
    exit 0
fi

# Count messages in transcript
MSG_COUNT=$(wc -l < "$TRANSCRIPT" 2>/dev/null || echo "0")

# Only analyze sessions with 10+ messages
if [[ $MSG_COUNT -lt 10 ]]; then
    trap - EXIT
    echo '{"decision": "approve"}'
    exit 0
fi

# Look for patterns to extract
PATTERNS_FILE="${LEARNED_DIR}/session-${SESSION_ID}-patterns.md"

# Check for user corrections (indicates learning opportunity)
CORRECTIONS=$(grep -c '"role":"user".*"(no|wrong|actually|instead|should be|fix)"' "$TRANSCRIPT" 2>/dev/null || echo "0")

# Check for error resolutions
ERRORS=$(grep -c '"error"' "$TRANSCRIPT" 2>/dev/null || echo "0")

# Only create pattern file if there were learning opportunities
if [[ $CORRECTIONS -gt 0 ]] || [[ $ERRORS -gt 2 ]]; then
    cat > "$PATTERNS_FILE" << EOF
# Learned Patterns: Session ${SESSION_ID}

Extracted: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
Message Count: ${MSG_COUNT}
User Corrections: ${CORRECTIONS}
Errors Resolved: ${ERRORS}

## Review Required

This session had learning opportunities. Review the transcript to extract:

- [ ] Error resolution patterns
- [ ] User correction patterns
- [ ] Workarounds discovered
- [ ] Project-specific conventions

Transcript: ${TRANSCRIPT}

## Notes

[Add extracted patterns here after manual review]
EOF

    echo "[Hook] Learning opportunity detected in session" >&2
    echo "[Hook] Review: ${PATTERNS_FILE}" >&2
fi

trap - EXIT
echo '{"decision": "approve"}'
