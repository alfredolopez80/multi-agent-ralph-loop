#!/bin/bash
# plan-state-lifecycle.sh - Manage plan-state lifecycle
# VERSION: 2.68.11
# v2.68.11: SEC-111 FIX - Input length validation to prevent DoS
# v2.68.2: FIX CRIT-008 - Clear EXIT trap before explicit JSON output
#
# Purpose: Auto-archive stale plans and start fresh for new tasks
#
# Trigger: UserPromptSubmit
#
# Logic:
# 1. Check if plan-state.json exists and is older than MAX_AGE_HOURS
# 2. Check if user prompt looks like a new task (not a follow-up)
# 3. If stale plan detected AND new task, AUTO-ARCHIVE old plan and start fresh
# 4. Notify user of the auto-archive via system message
# 5. (v2.57.0) Handle adaptive plan-states with different staleness thresholds
#
# v2.57.0 Changes:
# - Support for adaptive_mode (FAST_PATH, SIMPLE, COMPLEX)
# - Different staleness thresholds per adaptive mode
# - FAST_PATH: 30 minutes, SIMPLE: 1 hour, COMPLEX: 2 hours
#
# v2.56.0 Changes:
# - AUTO-ARCHIVE instead of just notifying
# - Archive location: ~/.ralph/archive/plans/
# - Fresh start for new tasks without manual intervention
#
# Output (JSON via stdout for UserPromptSubmit):
#   - {}: Allow without modification
#   - {"userPromptContent": "..."}: Modify prompt
#   - To stderr for blocking: {"blockReason": "..."}

set -euo pipefail

# Error trap for guaranteed JSON output (v2.62.3)
trap 'echo "{}"' ERR EXIT


PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/plan-state-lifecycle.log"
ARCHIVE_DIR="${HOME}/.ralph/archive/plans"
AUTO_ARCHIVE="${PLAN_STATE_AUTO_ARCHIVE:-true}"  # Enable auto-archive by default

# v2.57.0: Get staleness threshold for adaptive mode (bash 3 compatible)
# FAST_PATH tasks are quick, so short staleness
# COMPLEX tasks take longer, so longer staleness
get_staleness_threshold() {
    local adaptive_mode="${1:-DEFAULT}"
    case "$adaptive_mode" in
        FAST_PATH)    echo 30 ;;      # 30 minutes
        SIMPLE)       echo 60 ;;      # 1 hour
        COMPLEX)      echo 120 ;;     # 2 hours
        ORCHESTRATOR) echo 180 ;;     # 3 hours (full orchestration)
        *)            echo 120 ;;     # 2 hours fallback
    esac
}

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$ARCHIVE_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Archive a stale plan
archive_plan() {
    local plan_file="$1"
    local reason="$2"

    if [[ ! -f "$plan_file" ]]; then
        return 1
    fi

    # Get plan info for archive naming
    local plan_id task timestamp
    plan_id=$(jq -r '.plan_id // "unknown"' "$plan_file" 2>/dev/null | head -c 20)
    task=$(jq -r '.task // "unknown"' "$plan_file" 2>/dev/null | head -c 50 | tr ' /' '_-')
    timestamp=$(date '+%Y%m%d-%H%M%S')

    # Create archive filename
    local archive_file="${ARCHIVE_DIR}/plan-${timestamp}-${plan_id}.json"

    # Add archive metadata
    jq --arg reason "$reason" \
       --arg archived_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '. + {archived: {reason: $reason, archived_at: $archived_at}}' \
       "$plan_file" > "$archive_file" 2>/dev/null

    if [[ -f "$archive_file" ]]; then
        log "Archived plan to: $archive_file (reason: $reason)"
        # Remove original
        rm -f "$plan_file"
        return 0
    else
        log "ERROR: Failed to archive plan"
        return 1
    fi
}

# Read input from stdin
INPUT=$(cat)

# Get user prompt
USER_PROMPT=$(echo "$INPUT" | jq -r '.userPromptContent // ""' 2>/dev/null || echo "")

# SEC-111: Input length validation to prevent DoS from large prompts
MAX_INPUT_LEN=100000
if [[ ${#USER_PROMPT} -gt $MAX_INPUT_LEN ]]; then
    log "WARNING: User prompt exceeds maximum length (${#USER_PROMPT} > $MAX_INPUT_LEN chars). Truncating."
    USER_PROMPT="${USER_PROMPT:0:$MAX_INPUT_LEN}"
fi

# Check if plan-state exists
if [[ ! -f "$PLAN_STATE" ]]; then
    # No plan-state, nothing to check
    trap - EXIT  # CRIT-008: Clear trap before explicit output
    echo '{}'
    exit 0
fi

# Get plan-state age in minutes
if [[ -f "$PLAN_STATE" ]]; then
    # macOS stat syntax
    PLAN_AGE_SECONDS=$(($(date +%s) - $(stat -f %m "$PLAN_STATE" 2>/dev/null || echo "0")))
    PLAN_AGE_MINUTES=$((PLAN_AGE_SECONDS / 60))
    PLAN_AGE_HOURS=$((PLAN_AGE_SECONDS / 3600))
else
    trap - EXIT  # CRIT-008: Clear trap before explicit output
    echo '{}'
    exit 0
fi

# Get current plan task
CURRENT_TASK=$(jq -r '.task // "Unknown"' "$PLAN_STATE" 2>/dev/null | head -c 100)

# v2.57.0: Get adaptive mode and determine staleness threshold
ADAPTIVE_MODE=$(jq -r '.classification.adaptive_mode // .classification.workflow_route // .classification.route // "DEFAULT"' "$PLAN_STATE" 2>/dev/null || echo "DEFAULT")
STALENESS_MINUTES=$(get_staleness_threshold "$ADAPTIVE_MODE")
log "Plan adaptive mode: $ADAPTIVE_MODE, staleness threshold: ${STALENESS_MINUTES}m, current age: ${PLAN_AGE_MINUTES}m"

# Check if prompt indicates new task (heuristic)
# Indicators of NEW task:
# - Contains words like "implement", "create", "build", "add", "new"
# - Is longer than 50 characters (detailed request)
# - Does NOT contain words like "continue", "fix", "complete"
IS_NEW_TASK="false"

# Convert to lowercase for matching
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Check for new task indicators
if [[ "$PROMPT_LOWER" =~ (implement|create|build|add\ new|new\ feature|develop|design|architect) ]]; then
    # Check it's not a continuation
    if [[ ! "$PROMPT_LOWER" =~ (continue|fix|complete|finish|resume|ongoing) ]]; then
        # Check prompt is substantial
        if [[ ${#USER_PROMPT} -gt 50 ]]; then
            IS_NEW_TASK="true"
        fi
    fi
fi

# v2.57.0: If plan is stale (based on adaptive threshold) and prompt looks like new task
if [[ "$PLAN_AGE_MINUTES" -ge "$STALENESS_MINUTES" ]] && [[ "$IS_NEW_TASK" == "true" ]]; then
    log "Stale plan detected: $PLAN_AGE_MINUTES minutes old (threshold: ${STALENESS_MINUTES}m), mode: $ADAPTIVE_MODE, task: $CURRENT_TASK"
    log "New task detected: ${USER_PROMPT:0:100}..."

    # Get plan progress for logging
    TOTAL_STEPS=$(jq '[.steps | to_entries[] | .key] | length' "$PLAN_STATE" 2>/dev/null || echo 0)
    COMPLETED_STEPS=$(jq '[.steps | to_entries[] | select(.value.status == "completed" or .value.status == "verified")] | length' "$PLAN_STATE" 2>/dev/null || echo 0)

    # v2.56.0: AUTO-ARCHIVE if enabled
    if [[ "$AUTO_ARCHIVE" == "true" ]]; then
        log "Auto-archiving stale plan (${COMPLETED_STEPS}/${TOTAL_STEPS} completed)"

        if archive_plan "$PLAN_STATE" "stale_new_task"; then
            # Notify user of auto-archive (v2.57.0: include adaptive mode info)
            MODIFIED_PROMPT="[PLAN-STATE AUTO-ARCHIVED: Previous ${ADAPTIVE_MODE} plan \"${CURRENT_TASK}\" (${PLAN_AGE_MINUTES}m old, threshold: ${STALENESS_MINUTES}m, ${COMPLETED_STEPS}/${TOTAL_STEPS} steps) has been archived to ~/.ralph/archive/plans/. Starting fresh for new task. Disable with PLAN_STATE_AUTO_ARCHIVE=false]

$USER_PROMPT"
            trap - EXIT  # CRIT-008: Clear trap before explicit output
            printf '%s' "$MODIFIED_PROMPT" | jq -Rs '{userPromptContent: .}'
            exit 0
        else
            log "ERROR: Auto-archive failed, falling back to warning"
        fi
    fi

    # Fallback: Just warn (if auto-archive disabled or failed)
    # v2.57.0: Include adaptive mode information
    MODIFIED_PROMPT="[PLAN-STATE NOTICE: Current ${ADAPTIVE_MODE} plan is ${PLAN_AGE_MINUTES}m old (threshold: ${STALENESS_MINUTES}m, ${COMPLETED_STEPS}/${TOTAL_STEPS} steps). Task: \"${CURRENT_TASK}\". If this is a NEW task, run: ralph checkpoint save \"before-new-task\" && rm .claude/plan-state.json]

$USER_PROMPT"

    trap - EXIT  # CRIT-008: Clear trap before explicit output
    printf '%s' "$MODIFIED_PROMPT" | jq -Rs '{userPromptContent: .}'
    exit 0
fi

# Check for /orchestrator command which ALWAYS starts a new plan
if [[ "$PROMPT_LOWER" =~ ^/orchestrator ]] || [[ "$PROMPT_LOWER" =~ ^ralph\ orch ]]; then
    # Orchestrator always starts fresh - archive any existing plan
    if [[ -f "$PLAN_STATE" ]] && [[ "$AUTO_ARCHIVE" == "true" ]]; then
        log "Orchestrator command detected - archiving existing plan"
        archive_plan "$PLAN_STATE" "orchestrator_restart"
    fi
fi

# No modification needed
trap - EXIT  # CRIT-008: Clear trap before explicit output
echo '{}'
