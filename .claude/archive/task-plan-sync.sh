#!/bin/bash
# task-plan-sync.sh - TaskCreated Hook for Plan-State Synchronization
# VERSION: 1.0.0
# REPO: multi-agent-ralph-loop
#
# Triggered by: TaskCreated hook event
# Purpose: Synchronize task creation with plan-state.json to maintain continuity
#          between ad-hoc tasks and formal plans
#
# System Gap Fix #1: Plan-State Sync
#   - Ensures tasks are tracked in plan-state even without a formal plan
#   - Creates minimal ad-hoc plan if none exists
#   - Matches task subjects to existing steps or creates new ones
#
# Input (stdin JSON):
#   {
#     "taskId": "task-xxx",
#     "subject": "task subject",
#     "status": "pending",
#     "owner": "agent-name"
#   }
#
# Output (stdout JSON):
#   {"continue": true}

set -euo pipefail

# CRITICAL: umask 077 for defense in depth
umask 077

# SEC-111: Limit stdin to 100KB to prevent memory exhaustion
INPUT=$(head -c 100000)

# Error trap: ensure we always output valid JSON
trap 'echo "{\"continue\": true}"; exit 0' ERR

# Worktree-safe path resolution
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  get_main_repo() { get_project_root; }
}

REPO_ROOT="$(get_project_root)"
PLAN_STATE_FILE="${REPO_ROOT}/.claude/plan-state.json"
LOG_DIR="${HOME}/.ralph/logs"
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [task-plan-sync] $*" >> "${LOG_DIR}/task-plan-sync.log" 2>/dev/null || true
}

# Parse input JSON
TASK_ID=$(echo "$INPUT" | jq -r '.taskId // .task_id // empty' 2>/dev/null || echo "")
SUBJECT=$(echo "$INPUT" | jq -r '.subject // ""' 2>/dev/null || echo "")
STATUS=$(echo "$INPUT" | jq -r '.status // "pending"' 2>/dev/null || echo "pending")
OWNER=$(echo "$INPUT" | jq -r '.owner // ""' 2>/dev/null || echo "")

if [[ -z "$TASK_ID" ]]; then
    log "WARN: No taskId in input, skipping"
    echo '{"continue": true}'
    exit 0
fi

log "TaskCreated: ${TASK_ID} - ${SUBJECT}"

# Step 1: Check if plan-state exists, create minimal if not
if [[ ! -f "$PLAN_STATE_FILE" ]]; then
    log "No plan-state found, creating minimal ad-hoc plan"

    mkdir -p "$(dirname "$PLAN_STATE_FILE")"

    jq -n \
        --arg version "3.1.0" \
        --arg updated "$(date -Iseconds)" \
        '{
            version: $version,
            steps: [],
            last_updated: $updated
        }' > "$PLAN_STATE_FILE"

    log "Created minimal plan-state: $PLAN_STATE_FILE"
fi

# Step 2: Try to match task subject to existing step name
MATCHED_STEP=""
if [[ -f "$PLAN_STATE_FILE" ]]; then
    # Normalize subject for matching (lowercase, hyphens for spaces)
    NORMALIZED_SUBJECT=$(echo "$SUBJECT" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9-')

    # Check if any step name contains the normalized subject or vice versa
    MATCHED_STEP=$(jq -r --arg subj "$NORMALIZED_SUBJECT" '
        .steps[]? | select(
            (.name | ascii_downcase | gsub(" "; "-")) | contains($subj) or
            ($subj | contains((.name | ascii_downcase | gsub(" "; "-"))))
        ) | .id
    ' "$PLAN_STATE_FILE" 2>/dev/null || echo "")
fi

# Step 3: Update existing step or add new one
TIMESTAMP=$(date -Iseconds)

if [[ -n "$MATCHED_STEP" ]]; then
    log "Matched task ${TASK_ID} to existing step ${MATCHED_STEP}"

    # Update existing step status
    jq -n \
        --arg step_id "$MATCHED_STEP" \
        --arg status "$STATUS" \
        --arg owner "$OWNER" \
        --arg time "$TIMESTAMP" \
        --arg version "3.1.0" \
        '
        .version |= (if . == null then $version else . end) |
        .steps |= map(
            if .id == $step_id then
                .status = $status |
                .owner = (if $owner != "" then $owner else .owner end) |
                .last_updated = $time
            else
                .
            end
        ) |
        .last_updated = $time
        ' "$PLAN_STATE_FILE" > "${PLAN_STATE_FILE}.tmp"

    mv "${PLAN_STATE_FILE}.tmp" "$PLAN_STATE_FILE"
else
    log "No match found, adding new step for task ${TASK_ID}"

    # Generate step ID from task ID
    STEP_ID="step-${TASK_ID}"

    # Add new step with phase "ad_hoc"
    jq -n \
        --arg step_id "$STEP_ID" \
        --arg phase "ad_hoc" \
        --arg name "$SUBJECT" \
        --arg status "$STATUS" \
        --arg owner "$OWNER" \
        --arg time "$TIMESTAMP" \
        --arg task_id "$TASK_ID" \
        --arg version "3.1.0" \
        '
        .version |= (if . == null then $version else . end) |
        .steps += [{
            id: $step_id,
            phase: $phase,
            name: $name,
            status: $status,
            owner: (if $owner != "" then $owner else "" end),
            task_id: $task_id,
            created_at: $time,
            last_updated: $time
        }] |
        .last_updated = $time
        ' "$PLAN_STATE_FILE" > "${PLAN_STATE_FILE}.tmp"

    mv "${PLAN_STATE_FILE}.tmp" "$PLAN_STATE_FILE"
fi

log "Plan-state synced successfully for task ${TASK_ID}"

# Output success
echo '{"continue": true}'

exit 0
