#!/bin/bash
# continuous-learning.sh - Extract reusable patterns from session at end
# VERSION: 3.1.0
# Hook: Stop
# Part of Multi-Agent Ralph Loop v3.1.0
#
# v3.1.0: Redirected output to vault pipeline (was ~/.claude/skills/learned/)
#         Now writes to $VAULT_DIR/projects/{project}/lessons/ for vault graduation
# v2.69.0: Inspired by everything-claude-code's continuous learning skill
# v2.68.2: FIX CRIT-011 - Updated hook type declaration and trap pattern

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

# SEC-033: Guaranteed JSON output on any error
# Stop hooks use {"decision": "approve"} format
output_json() {
    echo '{"decision": "approve"}'
}
trap 'output_json' ERR EXIT

# Read stdin
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top

# v3.1.0: Write to vault instead of ~/.claude/skills/learned/
VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
PROJECT_NAME=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || echo 'unknown')")
LEARNED_DIR="$VAULT_DIR/projects/$PROJECT_NAME/lessons"
mkdir -p "$LEARNED_DIR" 2>/dev/null || true

# Get session transcript path if available
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
# SEC-029: Sanitize session_id to prevent path traversal
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"
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

# Look for patterns to extract — write to vault lessons directory
PATTERNS_FILE="${LEARNED_DIR}/learning-${SESSION_ID}-$(date +%Y-%m-%d).md"

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

    # v2.69.0: Write to log file instead of stderr (fixes hook error warnings)
    LOG_FILE="${HOME}/.ralph/logs/continuous-learning.log"
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Learning opportunity detected - Review: ${PATTERNS_FILE}" >> "$LOG_FILE" 2>/dev/null || true
fi

trap - EXIT
echo '{"decision": "approve"}'
