#!/bin/bash
# orchestrator-report.sh - Orchestrator Session Report Hook
# Hook: Stop
# Purpose: Generate comprehensive session report when user ends session
# VERSION: 2.69.0
#
# v2.66.6: Fixed duplicate VERSION (GAP-003) and consolidated version history
# v2.59.0: Added effectiveness metrics and domain-specific recommendations
# v2.57.5: Fixed JSON output format (SEC-039) - use "decision": "approve" not "continue"
# v2.57.0: Created as part of Memory System Reconstruction
#
# When: Triggered on Stop event (session ending)
# What: Analyzes session activity, learning outcomes, and recommendations
# - Generates session summary
# - Counts implemented vs pending steps
# - Reports learning outcomes
# - Provides recommendations for next steps
#
# SECURITY: SEC-006 compliant
# OUTPUT: JSON report to stdout

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap for guaranteed JSON output (v2.62.3)
trap 'echo "{\"decision\": \"approve\"}"' ERR EXIT

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
EFFECTIVENESS_METRICS="{}"
if [[ -f "$PROCEDURAL_FILE" ]]; then
    TOTAL_RULES=$(jq -r '.rules | length // 0' "$PROCEDURAL_FILE" 2>/dev/null || echo "0")
    log "Learning: $TOTAL_RULES rules in procedural memory"

    # Calculate effectiveness metrics (v2.59.0)
    TOTAL_USAGE=$(jq -r '[.rules[].usage_count // 0] | add // 0' "$PROCEDURAL_FILE" 2>/dev/null || echo "0")
    RULES_WITH_USAGE=$(jq -r '[.rules[] | select(.usage_count > 0)] | length // 0' "$PROCEDURAL_FILE" 2>/dev/null || echo "0")
    UTILIZATION_PCT=0
    if [[ "$TOTAL_RULES" -gt 0 ]]; then
        UTILIZATION_PCT=$((RULES_WITH_USAGE * 100 / TOTAL_RULES))
    fi

    EFFECTIVENESS_METRICS=$(jq -n \
        --argjson total_rules "$TOTAL_RULES" \
        --argjson rules_with_usage "$RULES_WITH_USAGE" \
        --argjson total_usage "$TOTAL_USAGE" \
        --argjson utilization "$UTILIZATION_PCT" \
        '{
            total_rules: $total_rules,
            rules_with_usage: $rules_with_usage,
            total_usage_count: $total_usage,
            utilization_percent: $utilization
        }')
    log "Effectiveness metrics: $EFFECTIVENESS_METRICS"
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

# 5. Check if learning was recommended but not done (with domain-specific recommendation)
LEARNING_DONE="false"
LEARNING_DOMAIN=""
if [[ -f "$PLAN_STATE" ]]; then
    LEARNING_DONE=$(jq -r '.learning_state.curator_invoked // false' "$PLAN_STATE" 2>/dev/null || echo "false")
    LEARNING_DOMAIN=$(jq -r '.learning_state.domain // ""' "$PLAN_STATE" 2>/dev/null || echo "")
fi
if [[ "$LEARNING_DONE" == "false" ]]; then
    if [[ -n "$LEARNING_DOMAIN" ]]; then
        # Domain-specific recommendation (v2.59.0)
        RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq --arg domain "$LEARNING_DOMAIN" '. + [{
            type: "targeted_learning",
            priority: "high",
            message: "Domain \($domain) patterns recommended - learn before implementing",
            command: "/curator full --type \($domain) --lang typescript",
            domain: $domain
        }]' 2>/dev/null || echo "$RECOMMENDATIONS")
    else
        RECOMMENDATIONS=$(echo "$RECOMMENDATIONS" | jq '. + [{
            type: "learning",
            priority: "medium",
            message: "Consider learning patterns for better quality",
            command: "/curator full"
        }]' 2>/dev/null || echo "$RECOMMENDATIONS")
    fi
fi

# 6. Save report to file (not stdout)
END_TIME=$(date -Iseconds)

# Build JSON report safely - include effectiveness metrics (v2.59.0)
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
    echo "    \"total_rules\": $TOTAL_RULES,"
    echo "    \"effectiveness\": $EFFECTIVENESS_METRICS"
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
# SEC-039: Stop hooks MUST use "decision": "approve" or "decision": "block"
# CRIT-003: Clear trap before explicit JSON output to avoid duplicates
trap - ERR EXIT
echo '{"decision": "approve"}'
