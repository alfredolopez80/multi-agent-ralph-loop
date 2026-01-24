#!/bin/bash
# task-primitive-sync.sh - Sync Claude Code Task primitives with plan-state.json
# VERSION: 1.2.1
# HOOK: PostToolUse (TaskCreate|TaskUpdate|TaskList)
# Part of Multi-Agent Ralph Loop v2.65.1
#
# Purpose: When Claude uses TaskCreate/TaskUpdate/TaskList, sync those tasks
#          back to plan-state.json so the statusline shows correct progress.
#
# This bridges the gap between Claude Code's native Task primitive
# and Ralph's plan-state based orchestration tracking.
#
# Supports both:
#   - v1 schema (steps as array): [{id: "1", ...}, {id: "2", ...}]
#   - v2 schema (steps as object): {"1": {...}, "2": {...}}

set -euo pipefail

# SEC-005: Restrictive umask for secure temp file creation
umask 077

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Configuration
PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/task-primitive-sync.log"

mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [task-primitive-sync] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Read input from stdin
INPUT=$(cat)

# Extract session_id from INPUT FIRST (canonical source from Claude Code)
SESSION_ID_FROM_INPUT=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

# Extract tool info
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // {}' 2>/dev/null || echo "{}")

log "Processing $TOOL_NAME"

# Skip if not a relevant tool
case "$TOOL_NAME" in
    TaskCreate|TaskUpdate|TaskList)
        ;;
    *)
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Ensure plan-state.json exists, create if needed (use v2 object format for new files)
if [[ ! -f "$PLAN_STATE" ]]; then
    mkdir -p "$(dirname "$PLAN_STATE")" 2>/dev/null || true

    # Initialize minimal plan-state (v2 object format)
    cat > "$PLAN_STATE" << 'EOF'
{
  "version": "2.65.1",
  "plan_id": "claude-tasks",
  "task": "Task tracking",
  "status": "in_progress",
  "steps": {},
  "updated_at": ""
}
EOF
    log "Created new plan-state.json (v2 format)"
fi

# Update timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Detect schema version: v1 (array) or v2 (object)
STEPS_TYPE=$(jq -r '.steps | type' "$PLAN_STATE" 2>/dev/null || echo "null")
log "Detected steps type: $STEPS_TYPE"

# Handle each tool type with format-aware logic
case "$TOOL_NAME" in
    TaskCreate)
        # Extract task info from tool output
        TASK_ID=$(echo "$TOOL_OUTPUT" | jq -r '.id // ""' 2>/dev/null || echo "")
        TASK_SUBJECT=$(echo "$INPUT" | jq -r '.tool_input.subject // ""' 2>/dev/null || echo "")

        if [[ -n "$TASK_ID" ]] && [[ -n "$TASK_SUBJECT" ]]; then
            TEMP_FILE=$(mktemp)

            if [[ "$STEPS_TYPE" == "array" ]]; then
                # v1 format: append to array
                jq --arg id "$TASK_ID" \
                   --arg name "$TASK_SUBJECT" \
                   --arg ts "$TIMESTAMP" \
                   '.steps += [{
                       "id": $id,
                       "title": $name,
                       "status": "pending",
                       "created_at": $ts
                   }] | .updated_at = $ts' "$PLAN_STATE" > "$TEMP_FILE"
            else
                # v2 format: use object key
                jq --arg id "$TASK_ID" \
                   --arg name "$TASK_SUBJECT" \
                   --arg ts "$TIMESTAMP" \
                   '.steps[$id] = {
                       "name": $name,
                       "status": "pending",
                       "created_at": $ts
                   } | .updated_at = $ts' "$PLAN_STATE" > "$TEMP_FILE"
            fi

            mv "$TEMP_FILE" "$PLAN_STATE"
            chmod 600 "$PLAN_STATE"
            log "Added task $TASK_ID: $TASK_SUBJECT (format: $STEPS_TYPE)"
        fi
        ;;

    TaskUpdate)
        # Extract task update info
        TASK_ID=$(echo "$INPUT" | jq -r '.tool_input.taskId // ""' 2>/dev/null || echo "")
        NEW_STATUS=$(echo "$INPUT" | jq -r '.tool_input.status // ""' 2>/dev/null || echo "")

        if [[ -n "$TASK_ID" ]] && [[ -n "$NEW_STATUS" ]]; then
            TEMP_FILE=$(mktemp)

            if [[ "$STEPS_TYPE" == "array" ]]; then
                # v1 format: find by id in array and update
                jq --arg id "$TASK_ID" \
                   --arg status "$NEW_STATUS" \
                   --arg ts "$TIMESTAMP" \
                   '(.steps[] | select(.id == $id)) |= (
                       .status = $status |
                       .updated_at = $ts
                   ) | .updated_at = $ts' "$PLAN_STATE" > "$TEMP_FILE"
            else
                # v2 format: use object key
                jq --arg id "$TASK_ID" \
                   --arg status "$NEW_STATUS" \
                   --arg ts "$TIMESTAMP" \
                   'if .steps[$id] then
                       .steps[$id].status = $status |
                       .steps[$id].updated_at = $ts
                   else
                       .steps[$id] = {"name": "Task " + $id, "status": $status}
                   end | .updated_at = $ts' "$PLAN_STATE" > "$TEMP_FILE"
            fi

            mv "$TEMP_FILE" "$PLAN_STATE"
            chmod 600 "$PLAN_STATE"
            log "Updated task $TASK_ID to $NEW_STATUS (format: $STEPS_TYPE)"
        fi
        ;;

    TaskList)
        # Parse all tasks from output and sync state
        TASKS=$(echo "$TOOL_OUTPUT" | jq -r '.tasks // []' 2>/dev/null || echo "[]")

        if [[ "$TASKS" != "[]" ]] && [[ "$TASKS" != "null" ]]; then
            TEMP_FILE=$(mktemp)

            if [[ "$STEPS_TYPE" == "array" ]]; then
                # v1 format: rebuild as array (preserve existing structure)
                echo "$TASKS" | jq --arg ts "$TIMESTAMP" '
                    [.[] | {
                        "id": (.id | tostring),
                        "title": .subject,
                        "status": .status,
                        "updated_at": $ts
                    }]
                ' > "${TEMP_FILE}.steps"

                # Merge with existing plan-state, keeping array format
                jq --slurpfile steps "${TEMP_FILE}.steps" \
                   --arg ts "$TIMESTAMP" \
                   '.steps = ($steps[0] // []) | .updated_at = $ts' "$PLAN_STATE" > "$TEMP_FILE"
            else
                # v2 format: rebuild as object
                echo "$TASKS" | jq --arg ts "$TIMESTAMP" '
                    reduce .[] as $task ({};
                        .[$task.id | tostring] = {
                            "name": $task.subject,
                            "status": $task.status,
                            "updated_at": $ts
                        }
                    )
                ' > "${TEMP_FILE}.steps"

                # Merge with existing plan-state
                jq --slurpfile steps "${TEMP_FILE}.steps" \
                   --arg ts "$TIMESTAMP" \
                   '.steps = ($steps[0] // {}) | .updated_at = $ts' "$PLAN_STATE" > "$TEMP_FILE"
            fi

            mv "$TEMP_FILE" "$PLAN_STATE"
            rm -f "${TEMP_FILE}.steps"
            chmod 600 "$PLAN_STATE"

            TASK_COUNT=$(echo "$TASKS" | jq 'length')
            log "Synced $TASK_COUNT tasks from TaskList (format: $STEPS_TYPE)"
        fi
        ;;
esac

# Calculate and log current progress (format-aware)
if [[ -f "$PLAN_STATE" ]]; then
    if [[ "$STEPS_TYPE" == "array" ]]; then
        # v1: count array elements
        TOTAL=$(jq '.steps | length' "$PLAN_STATE" 2>/dev/null || echo "0")
        COMPLETED=$(jq '[.steps[] | select(.status == "completed")] | length' "$PLAN_STATE" 2>/dev/null || echo "0")
    else
        # v2: count object keys
        TOTAL=$(jq '.steps | keys | length' "$PLAN_STATE" 2>/dev/null || echo "0")
        COMPLETED=$(jq '[.steps | to_entries[] | select(.value.status == "completed")] | length' "$PLAN_STATE" 2>/dev/null || echo "0")
    fi
    log "Progress: $COMPLETED/$TOTAL"
fi

echo '{"continue": true}'
