#!/bin/bash
# Fast-Path Check Hook v2.46
# Hook: PreToolUse (Task)
# Purpose: Detect trivial tasks and route to fast-path
# VERSION: 2.69.0
# v2.69.0: FIX CRIT-003 - Added EXIT to trap for guaranteed JSON output
# v2.68.25: FIX CRIT-001 - Removed duplicate stdin read (SEC-111 already reads at top)
# v2.57.3: Fixed JSON output to single line format

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)

set -euo pipefail

# Guaranteed valid JSON on error
output_json() {
    echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
}
trap 'output_json' ERR EXIT
umask 077

# Parse JSON input (already read above via SEC-111)
# CRIT-001 FIX: Removed duplicate `INPUT=$(cat)` - stdin already consumed
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only process Task tool calls
if [[ "$TOOL_NAME" != "Task" ]]; then
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
    exit 0
fi

# Extract task details
TASK_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
TASK_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty')

# Skip if already in orchestrator context
if [[ "$TASK_TYPE" == "orchestrator" ]]; then
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
    exit 0
fi

# Fast-path detection keywords
TRIVIAL_KEYWORDS="fix typo|fix typos|simple fix|quick fix|minor change|add comment|remove comment|rename|update version|bump version|single line|one line"
COMPLEX_KEYWORDS="implement|design|migrate|refactor|architecture|security|auth|payment|integrate|multi-file|cross-module"

# Check for trivial task indicators
IS_TRIVIAL=false
if echo "$TASK_PROMPT" | grep -qiE "$TRIVIAL_KEYWORDS"; then
    IS_TRIVIAL=true
fi

# Check for complex task indicators (override trivial)
if echo "$TASK_PROMPT" | grep -qiE "$COMPLEX_KEYWORDS"; then
    IS_TRIVIAL=false
fi

# Count files mentioned (heuristic)
# Note: grep -o exits 1 when no matches, handle gracefully
FILE_MATCHES=$(echo "$TASK_PROMPT" | grep -oE '\b[A-Za-z0-9_/-]+\.(ts|js|py|go|rs|java|tsx|jsx|md|json|yaml|yml)\b' 2>/dev/null || true)
if [[ -n "$FILE_MATCHES" ]]; then
    FILE_COUNT=$(echo "$FILE_MATCHES" | wc -l | tr -d '[:space:]')
else
    FILE_COUNT=0
fi

# If many files mentioned, not trivial
if [[ "$FILE_COUNT" -gt 3 ]]; then
    IS_TRIVIAL=false
fi

# Log the decision
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/fast-path-$(date +%Y%m%d).log"

{
    echo "[$(date -Iseconds)] Session: $SESSION_ID"
    echo "  Task type: $TASK_TYPE"
    echo "  File count: $FILE_COUNT"
    echo "  Is trivial: $IS_TRIVIAL"
    echo "  Prompt preview: ${TASK_PROMPT:0:100}..."
} >> "$LOG_FILE"

# Return decision with classification hint (single-line JSON)
# v2.70.0: PreToolUse hooks use {"hookSpecificOutput": {"permissionDecision": "allow"}}, NOT {"continue": true}
trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
if [[ "$IS_TRIVIAL" == "true" ]]; then
    echo '{"decision": "allow", "additionalContext": "FAST_PATH_ELIGIBLE: This task appears trivial (complexity <= 3). Consider fast-path: DIRECT_EXECUTE -> MICRO_VALIDATE -> DONE."}'
else
    echo '{"decision": "allow", "additionalContext": "STANDARD_PATH: This task requires full orchestration workflow."}'
fi
