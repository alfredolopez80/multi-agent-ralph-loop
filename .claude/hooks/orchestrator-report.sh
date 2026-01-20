#!/bin/bash
# orchestrator-report.sh - Orchestrator Session Report Hook
# Hook: Stop
# Purpose: Generate comprehensive session report when user ends session
#
# When: Triggered on Stop event (session ending)
# What: Analyzes session activity, learning outcomes, and recommendations
#
# v2.57.0: Created as part of Memory System Reconstruction
# - Generates session summary
# - Counts implemented vs pending steps
# - Reports learning outcomes
# - Provides recommendations for next steps
#
# VERSION: 2.57.4
# SECURITY: SEC-006 compliant
# OUTPUT: JSON report to stdout

set -euo pipefail
umask 077

# Paths - Initialize all variables before use
RALPH_DIR="${HOME}/.ralph"
PLAN_STATE="${RALPH_DIR}/plan-state/plan-state.json"
PROCEDURAL_FILE="${RALPH_DIR}/procedural/rules.json"
LOG_DIR="${RALPH_DIR}/logs"
REPORT_DIR="${RALPH_DIR}/reports"
SESSION_DIR="${RALPH_DIR}/sessions"
SESSION_ID=""
REPORT_FILE=""
START_TIME=""
TOTAL_STEPS=0
COMPLETED_STEPS=0
IN_PROGRESS_STEPS=0
PENDING_STEPS=0
TASK="Unknown"
WORKFLOW="unknown"
ITERATIONS=0
PROGRESS_PCT=0
TOTAL_RULES=0
SESSION_DURATION="unknown"
RECOMMENDATIONS="[]"
PENDING_COUNT=0
LEARNING_DONE="false"

# Create directories FIRST (critical for set -e)
mkdir -p "$REPORT_DIR" "$SESSION_DIR" "$LOG_DIR"

# Generate sanitized session ID from timestamp
SESSION_ID="session_$(date +%Y%m%d%H%M%S)"
REPORT_FILE="${REPORT_DIR}/session-${SESSION_ID}.json"

# Logging
log() {
    echo "[orchestrator-report] $(date -Iseconds): $1" >> "${LOG_DIR}/orchestrator-report.log" 2>&1 || true
}

log "=== Generating Orchestrator Session Report ==="

# Initialize report data
START_TIME=$(date -Iseconds)

# 1. Analyze plan-state progress
TOTAL_STEPS=0
COMPLETED_STEPS=0
IN_PROGRESS_STEPS=0
PENDING_STEPS=0
TASK="Unknown"
WORKFLOW="unknown"
ITERATIONS=0

if [[ -f "$PLAN_STATE" ]]; then
    log "Analyzing plan-state: $PLAN_STATE"

    TOTAL_STEPS=$(jq -r 'if .steps then (.steps | length) else 0 end' "$PLAN_STATE" 2>/dev/null || echo "0")
    COMPLETED_STEPS=$(jq -r 'if .steps then ([.steps[] | select(.status == "completed" or .status == "verified")] | length) else 0 end' "$PLAN_STATE" 2>/dev/null || echo "0")
    IN_PROGRESS_STEPS=$(jq -r 'if .steps then ([.steps[] | select(.status == "in_progress")] | length) else 0 end' "$PLAN_STATE" 2>/dev/null || echo "0")
    PENDING_STEPS=$((TOTAL_STEPS - COMPLETED_STEPS - IN_PROGRESS_STEPS))

    TASK=$(jq -r '.task // "Unknown task"' "$PLAN_STATE" 2>/dev/null || echo "Unknown")
    WORKFLOW=$(jq -r '.classification.workflow_route // "unknown"' "$PLAN_STATE" 2>/dev/null || echo "unknown")
    ITERATIONS=$(jq -r '.loop_state.current_iteration // 0' "$PLAN_STATE" 2>/dev/null || echo "0")

    log "  Task: $TASK"
    log "  Workflow: $WORKFLOW"
    log "  Steps: $COMPLETED_STEPS/$TOTAL_STEPS completed, $IN_PROGRESS_STEPS in progress, $PENDING_STEPS pending"
    log "  Iterations: $ITERATIONS"
else
    log "No plan-state found - generating minimal report"
fi

# Calculate progress percentage
PROGRESS_PCT=0
if [[ "$TOTAL_STEPS" -gt 0 ]]; then
    PROGRESS_PCT=$((COMPLETED_STEPS * 100 / TOTAL_STEPS))
fi

# 2. Analyze learning outcomes
TOTAL_RULES=0
if [[ -f "$PROCEDURAL_FILE" ]]; then
    TOTAL_RULES=$(jq -r '.rules | length // 0' "$PROCEDURAL_FILE" 2>/dev/null || echo "0")
    log "Learning: $TOTAL_RULES rules in procedural memory"
fi

# 3. Session duration (estimate from logs)
SESSION_DURATION="unknown"
if [[ -f "${LOG_DIR}/orchestrator-init.log" ]]; then
    FIRST_ENTRY=$(head -1 "${LOG_DIR}/orchestrator-init.log" 2>/dev/null | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}' | head -1 || echo "")
    if [[ -n "$FIRST_ENTRY" ]]; then
        SESSION_DURATION="since $FIRST_ENTRY"
    fi
fi

# 4. Generate recommendations
RECOMMENDATIONS="[]"
PENDING_COUNT=$PENDING_STEPS
if [[ "$PENDING_COUNT" -gt 0 ]]; then
    RECOMMENDATIONS=$(jq -n \
        --argjson pending "$PENDING_COUNT" \
        '[{
            type: "incomplete_work",
            priority: "high",
            message: "\($pending) steps pending - consider continuing with /loop",
            command: "/loop \"continue with pending task\""
        }]')
fi

# 5. Check if learning was recommended but not done
LEARNING_DONE="false"
if [[ -f "$PLAN_STATE" ]]; then
    LEARNING_DONE=$(jq -r '.learning_state.curator_invoked // false' "$PLAN_STATE" 2>/dev/null || echo "false")
fi
if [[ "$LEARNING_DONE" == "false" ]]; then
    RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq '. + [{
        type: "learning",
        priority: "medium",
        message: "Consider learning patterns for better quality",
        command: "/curator full"
    }]' 2>/dev/null || echo "$RECOMMENDATIONS")
fi

# 6. Save report to file (not stdout)
END_TIME=$(date -Iseconds)

# Build JSON report safely
TEMP_REPORT="${REPORT_FILE}.$$"
{
    echo "{"
    echo "  \"session_id\": \"$SESSION_ID\","
    echo "  \"generated_at\": \"$END_TIME\","
    echo "  \"duration\": \"$SESSION_DURATION\","
    echo "  \"task\": \"$TASK\","
    echo "  \"workflow\": \"$WORKFLOW\","
    echo "  \"steps\": {"
    echo "    \"total\": $TOTAL_STEPS,"
    echo "    \"completed\": $COMPLETED_STEPS,"
    echo "    \"in_progress\": $IN_PROGRESS_STEPS,"
    echo "    \"pending\": $PENDING_STEPS"
    echo "  },"
    echo "  \"progress_percent\": $PROGRESS_PCT,"
    echo "  \"iterations\": $ITERATIONS,"
    echo "  \"learning\": {"
    echo "    \"total_rules\": $TOTAL_RULES"
    echo "  },"
    echo "  \"recommendations\": $RECOMMENDATIONS"
    echo "}"
} > "$TEMP_REPORT" 2>/dev/null

# Atomic move
if [[ -s "$TEMP_REPORT" ]]; then
    mv "$TEMP_REPORT" "$REPORT_FILE"
    log "Report saved: $REPORT_FILE"
else
    log "WARNING: Failed to write report file"
fi

log "=== Report Generation Complete ==="

# Stop hook output format (per CLAUDE.md conventions)
# Only output the decision JSON - report is saved to file
echo "{\"decision\": \"continue\"}"
