#!/bin/bash
# status-auto-check.sh - Auto-show status periodically
# VERSION: 2.57.3
# v2.57.3: Fixed LAST remaining wrong format on line 119 (SEC-036)
# v2.57.2: Fixed JSON output format (SEC-035) - use {"continue": true}
#
# Purpose: Automatically show orchestration status every N operations
# and when plan steps complete.
#
# Trigger: PostToolUse (Edit|Write|Bash)
#
# Features:
# - Shows status every 5 Edit/Write/Bash operations
# - Detects step completion and shows status immediately
# - Session-aware counter (resets per session)
# - Non-blocking via systemMessage

set -euo pipefail

# SEC-035: Guaranteed valid JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

PLAN_STATE=".claude/plan-state.json"
COUNTER_FILE="${HOME}/.ralph/cache/status-check-counter"
LOG_FILE="${HOME}/.ralph/logs/status-auto-check.log"
OPERATIONS_THRESHOLD=5

# Check if disabled
if [[ "${RALPH_STATUS_AUTO_CHECK:-true}" == "false" ]]; then
    echo '{"continue": true}'
    exit 0
fi

mkdir -p "$(dirname "$COUNTER_FILE")"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

case "$TOOL_NAME" in
    Edit|Write|Bash) ;;
    *)
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Get or initialize counter
CURRENT_COUNT=0
if [[ -f "$COUNTER_FILE" ]]; then
    CURRENT_COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
fi
CURRENT_COUNT=$((CURRENT_COUNT + 1))
echo "$CURRENT_COUNT" > "$COUNTER_FILE"

log "Operation $CURRENT_COUNT ($TOOL_NAME)"

if [[ ! -f "$PLAN_STATE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

PLAN_DATA=$(cat "$PLAN_STATE" 2>/dev/null || echo "{}")
TOTAL_STEPS=$(echo "$PLAN_DATA" | jq '[.steps | to_entries[] | select(.key != "null")] | length' 2>/dev/null || echo "0")
COMPLETED_STEPS=$(echo "$PLAN_DATA" | jq '[.steps | to_entries[] | select(.value.status == "completed" or .value.status == "verified")] | length' 2>/dev/null || echo "0")
IN_PROGRESS=$(echo "$PLAN_DATA" | jq '[.steps | to_entries[] | select(.value.status == "in_progress")] | length' 2>/dev/null || echo "0")
PLAN_STATUS=$(echo "$PLAN_DATA" | jq -r '.phases[0].status // "unknown"' 2>/dev/null || echo "unknown")

PERCENTAGE=0
if [[ "$TOTAL_STEPS" -gt 0 ]]; then
    PERCENTAGE=$((COMPLETED_STEPS * 100 / TOTAL_STEPS))
fi

ROUTE="STANDARD"
COMPLEXITY=$(echo "$PLAN_DATA" | jq -r '.classification.complexity // 5' 2>/dev/null || echo "5")
if [[ "$COMPLEXITY" -le 3 ]]; then
    ROUTE="FAST"
fi

# Track step completion
PREV_COMPLETED_FILE="${HOME}/.ralph/cache/prev-completed-steps"
PREV_COMPLETED=0
if [[ -f "$PREV_COMPLETED_FILE" ]]; then
    PREV_COMPLETED=$(cat "$PREV_COMPLETED_FILE" 2>/dev/null || echo "0")
fi
echo "$COMPLETED_STEPS" > "$PREV_COMPLETED_FILE"

STEP_JUST_COMPLETED="false"
if [[ "$COMPLETED_STEPS" -gt "$PREV_COMPLETED" ]]; then
    STEP_JUST_COMPLETED="true"
    log "Step completed! ($PREV_COMPLETED -> $COMPLETED_STEPS)"
fi

SHOW_STATUS="false"
if [[ $((CURRENT_COUNT % OPERATIONS_THRESHOLD)) -eq 0 ]]; then
    SHOW_STATUS="true"
    log "Periodic status check"
fi
if [[ "$STEP_JUST_COMPLETED" == "true" ]]; then
    SHOW_STATUS="true"
fi

if [[ "$SHOW_STATUS" == "true" ]]; then
    if [[ "$PLAN_STATUS" == "completed" ]]; then
        STATUS_MSG="✅ $ROUTE Complete: $COMPLETED_STEPS/$TOTAL_STEPS (100%)"
    elif [[ "$IN_PROGRESS" -gt 0 ]]; then
        STATUS_MSG="🔄 $ROUTE Step $COMPLETED_STEPS/$TOTAL_STEPS ($PERCENTAGE%) - in_progress"
    else
        STATUS_MSG="📊 $ROUTE Step $COMPLETED_STEPS/$TOTAL_STEPS ($PERCENTAGE%)"
    fi
    log "Showing status: $STATUS_MSG"
    STATUS_MSG_ESCAPED=$(echo "$STATUS_MSG" | jq -Rs '.')
    echo "{\"continue\": true, \"systemMessage\": $STATUS_MSG_ESCAPED}"
else
    echo '{"continue": true}'
fi
