#!/bin/bash
# VERSION: 2.69.0
# PostToolUse hook for TodoWrite - Sync todos with plan-state progress
#
# TRIGGER: PostToolUse (TodoWrite)
# PURPOSE: Synchronize todos with plan-state progress tracking
#
# This hook:
#   1. Detects changes in todos from PostToolUse TodoWrite events
#   2. Reads the current plan-state.json
#   3. Updates progress based on completed todos count
#   4. Writes updated plan-state with synchronized progress

set -euo pipefail

# Configuration
LOG_FILE="${HOME}/.ralph/logs/todo-plan-sync.log"
PLAN_STATE=".claude/plan-state.json"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Read stdin for hook context
INPUT=$(cat)

# Log entry
log_entry() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE"
}

log_entry "=== Todo-Plan Sync Started ==="

# Validate jq is available
if ! command -v jq &>/dev/null; then
    log_entry "ERROR: jq not found"
    echo '{"decision": "continue"}'
    exit 0
fi

# Parse todo operation from input
TODO_OP=$(echo "$INPUT" | jq -r '.toolInput.operation // "unknown"')
log_entry "Todo operation: $TODO_OP"

# Check if plan-state.json exists
if [[ ! -f "$PLAN_STATE" ]]; then
    log_entry "WARNING: plan-state.json not found at $PLAN_STATE"
    echo '{"decision": "continue"}'
    exit 0
fi

# Validate plan-state.json is readable
if [[ ! -r "$PLAN_STATE" ]]; then
    log_entry "ERROR: Cannot read plan-state.json"
    echo '{"decision": "continue"}'
    exit 0
fi

# Extract todos array from input
TODOS_JSON=$(echo "$INPUT" | jq -r '.toolInput.todos // []')

# Count completed and total todos
COMPLETED=$(echo "$TODOS_JSON" | jq '[.[] | select(.status == "done" or .completed == true)] | length')
TOTAL=$(echo "$TODOS_JSON" | jq 'length')

log_entry "Todos count - Completed: $COMPLETED, Total: $TOTAL"

# Calculate progress percentage
if [[ "$TOTAL" -gt 0 ]]; then
    PROGRESS=$((COMPLETED * 100 / TOTAL))
else
    PROGRESS=0
fi

log_entry "Progress calculated: $PROGRESS%"

# Update plan-state.json atomically
TMP_FILE=$(mktemp)

if jq --argjson completed "$COMPLETED" \
      --argjson total "$TOTAL" \
      --argjson progress "$PROGRESS" \
      '
      .progress.completed_steps = $completed |
      .progress.total_steps = $total |
      .progress.percentage = $progress |
      .last_updated = now | todate
      ' "$PLAN_STATE" > "$TMP_FILE" 2>>"$LOG_FILE"; then
    
    # Atomic move
    if mv "$TMP_FILE" "$PLAN_STATE" 2>>"$LOG_FILE"; then
        log_entry "Successfully updated plan-state.json"
    else
        log_entry "ERROR: Failed to move temp file to plan-state.json"
        rm -f "$TMP_FILE"
    fi
else
    log_entry "ERROR: Failed to update plan-state.json with jq"
    rm -f "$TMP_FILE"
fi

log_entry "=== Todo-Plan Sync Completed ==="

# Always return valid JSON for hook output
echo '{"decision": "continue"}'
