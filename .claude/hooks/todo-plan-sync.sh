#!/bin/bash
# todo-plan-sync.sh - Sync TodoWrite with plan-state.json
# VERSION: 2.57.0
#
# Purpose: Synchronize TodoWrite tool usage with plan-state.json
# This enables real-time progress tracking in the statusline.
#
# Trigger: PostToolUse (TodoWrite)
#
# Logic:
# 1. Extract todos from TodoWrite tool input
# 2. If plan-state.json doesn't exist, create a dynamic plan from todos
# 3. If plan-state.json exists, map todos to steps and update progress
# 4. Update timestamps and recalculate completion percentage
#
# Output (JSON via stdout for PostToolUse):
#   - {"decision": "continue"}: Allow execution to continue
#   - {"decision": "continue", "systemMessage": "..."}: Continue with feedback
#
# VERSION: 2.57.2
# v2.57.2: Fixed JSON format (SEC-033) - use "decision" not "continue"

set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"decision": "continue"}'
}
trap 'output_json' ERR

PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/todo-plan-sync.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Read input from stdin
INPUT=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only process TodoWrite
if [[ "$TOOL_NAME" != "TodoWrite" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

log "TodoWrite detected, syncing with plan-state..."

# Extract todos from tool input
TODOS=$(echo "$INPUT" | jq -r '.tool_input.todos // []' 2>/dev/null || echo "[]")

# Validate todos
if [[ "$TODOS" == "[]" ]] || [[ -z "$TODOS" ]]; then
    log "No todos found in input"
    echo '{"decision": "continue"}'
    exit 0
fi

# Count todo statuses
TOTAL_TODOS=$(echo "$TODOS" | jq 'length' 2>/dev/null || echo "0")
COMPLETED_TODOS=$(echo "$TODOS" | jq '[.[] | select(.status == "completed")] | length' 2>/dev/null || echo "0")
IN_PROGRESS_TODOS=$(echo "$TODOS" | jq '[.[] | select(.status == "in_progress")] | length' 2>/dev/null || echo "0")

log "Todos: $COMPLETED_TODOS completed, $IN_PROGRESS_TODOS in_progress, $TOTAL_TODOS total"

# Ensure .claude directory exists
mkdir -p .claude

# Current timestamp
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Check if plan-state exists
if [[ ! -f "$PLAN_STATE" ]]; then
    log "No plan-state.json found, creating dynamic plan from todos"

    # Create a dynamic plan from todos
    # Each todo becomes a step
    STEPS_OBJ="{}"
    STEP_NUM=1

    while IFS= read -r todo_json; do
        content=$(echo "$todo_json" | jq -r '.content // "Task"')
        status=$(echo "$todo_json" | jq -r '.status // "pending"')

        # Map todo status to plan-state status
        plan_status="pending"
        case "$status" in
            "completed") plan_status="completed" ;;
            "in_progress") plan_status="in_progress" ;;
            *) plan_status="pending" ;;
        esac

        # Create step JSON
        STEP_JSON=$(jq -n \
            --arg name "$content" \
            --arg status "$plan_status" \
            --arg now "$NOW" \
            '{
                name: $name,
                status: $status,
                result: (if $status == "completed" then "success" else null end),
                started_at: (if $status == "in_progress" or $status == "completed" then $now else null end),
                completed_at: (if $status == "completed" then $now else null end),
                error: null
            }')

        STEPS_OBJ=$(echo "$STEPS_OBJ" | jq --arg key "$STEP_NUM" --argjson step "$STEP_JSON" '.[$key] = $step')
        ((STEP_NUM++))
    done < <(echo "$TODOS" | jq -c '.[]')

    # Generate plan UUID
    if command -v uuidgen &> /dev/null; then
        PLAN_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        PLAN_ID="todo-sync-$(date +%s)-$$"
    fi

    # Get first todo as task name
    TASK_NAME=$(echo "$TODOS" | jq -r '.[0].content // "Dynamic Task"' | head -c 100)

    # Create plan-state.json
    PLAN_STATE_JSON=$(jq -n \
        --arg plan_id "$PLAN_ID" \
        --arg task "$TASK_NAME" \
        --argjson steps "$STEPS_OBJ" \
        --arg created "$NOW" \
        --arg updated "$NOW" \
        '{
            plan_id: $plan_id,
            task: $task,
            classification: {
                complexity: 5,
                model_routing: "sonnet",
                adversarial_required: false
            },
            steps: $steps,
            loop_state: {
                current_iteration: 0,
                max_iterations: 25,
                validate_attempts: 0
            },
            metadata: {
                created_at: $created,
                created_by: "todo-plan-sync",
                version: "2.56.0"
            },
            version: "2.51.0",
            phases: [{
                phase_id: "todo-phase",
                phase_name: "Todo Tasks",
                step_ids: [],
                depends_on: [],
                execution_mode: "sequential",
                status: "in_progress"
            }],
            current_phase: "todo-phase",
            barriers: {},
            updated_at: $updated
        }')

    # Add step IDs to phase
    STEP_IDS=$(echo "$STEPS_OBJ" | jq -r 'keys | .[]' | jq -R -s 'split("\n") | map(select(. != ""))')
    PLAN_STATE_JSON=$(echo "$PLAN_STATE_JSON" | jq --argjson ids "$STEP_IDS" '.phases[0].step_ids = $ids')

    # Write atomically
    TEMP_FILE=$(mktemp)
    echo "$PLAN_STATE_JSON" | jq '.' > "$TEMP_FILE"
    mv "$TEMP_FILE" "$PLAN_STATE"
    chmod 600 "$PLAN_STATE"

    log "Created dynamic plan-state.json with $TOTAL_TODOS steps"
    echo "{\"decision\": \"continue\", \"systemMessage\": \"📊 Plan created from todos: $COMPLETED_TODOS/$TOTAL_TODOS complete\"}"
    exit 0
fi

# Plan-state exists - update step statuses based on todos
log "Updating existing plan-state.json with todo progress"

# Read existing plan
EXISTING_PLAN=$(cat "$PLAN_STATE")
EXISTING_STEPS=$(echo "$EXISTING_PLAN" | jq '.steps // {}')
EXISTING_STEP_COUNT=$(echo "$EXISTING_STEPS" | jq 'keys | length')

# If todo count matches step count, do direct mapping
if [[ "$TOTAL_TODOS" -eq "$EXISTING_STEP_COUNT" ]]; then
    log "Direct mapping: $TOTAL_TODOS todos to $EXISTING_STEP_COUNT steps"

    # Update each step based on corresponding todo
    # v2.57.0 FIX: Use natural sort for step-X-Y format keys (tonumber fails on strings)
    STEP_KEYS=$(echo "$EXISTING_STEPS" | jq -r 'keys | sort | .[]')
    TODO_INDEX=0

    for STEP_KEY in $STEP_KEYS; do
        TODO_STATUS=$(echo "$TODOS" | jq -r ".[$TODO_INDEX].status // \"pending\"")

        # Map status
        PLAN_STATUS="pending"
        case "$TODO_STATUS" in
            "completed") PLAN_STATUS="completed" ;;
            "in_progress") PLAN_STATUS="in_progress" ;;
            *) PLAN_STATUS="pending" ;;
        esac

        # Update step
        EXISTING_PLAN=$(echo "$EXISTING_PLAN" | jq \
            --arg key "$STEP_KEY" \
            --arg status "$PLAN_STATUS" \
            --arg now "$NOW" \
            '.steps[$key].status = $status |
             if $status == "completed" then
               .steps[$key].result = "success" |
               .steps[$key].completed_at = $now
             elif $status == "in_progress" then
               .steps[$key].started_at = $now
             else . end')

        ((TODO_INDEX++))
    done
else
    # Different counts - update based on completion ratio
    log "Ratio mapping: $TOTAL_TODOS todos vs $EXISTING_STEP_COUNT steps"

    # Mark steps as completed based on ratio
    COMPLETION_RATIO=$(echo "scale=2; $COMPLETED_TODOS / $TOTAL_TODOS" | bc 2>/dev/null || echo "0")
    STEPS_TO_COMPLETE=$(echo "scale=0; $EXISTING_STEP_COUNT * $COMPLETION_RATIO / 1" | bc 2>/dev/null || echo "0")

    STEP_INDEX=0
    # v2.57.0 FIX: Use natural sort for step-X-Y format keys
    for STEP_KEY in $(echo "$EXISTING_STEPS" | jq -r 'keys | sort | .[]'); do
        if [[ "$STEP_INDEX" -lt "$STEPS_TO_COMPLETE" ]]; then
            STATUS="completed"
        elif [[ "$STEP_INDEX" -eq "$STEPS_TO_COMPLETE" ]] && [[ "$IN_PROGRESS_TODOS" -gt 0 ]]; then
            STATUS="in_progress"
        else
            STATUS="pending"
        fi

        EXISTING_PLAN=$(echo "$EXISTING_PLAN" | jq \
            --arg key "$STEP_KEY" \
            --arg status "$STATUS" \
            --arg now "$NOW" \
            '.steps[$key].status = $status |
             if $status == "completed" then
               .steps[$key].result = "success" |
               .steps[$key].completed_at = $now
             elif $status == "in_progress" then
               .steps[$key].started_at = $now
             else . end')

        ((STEP_INDEX++))
    done
fi

# Update timestamp
EXISTING_PLAN=$(echo "$EXISTING_PLAN" | jq --arg now "$NOW" '.updated_at = $now')

# Write updated plan atomically
TEMP_FILE=$(mktemp)
echo "$EXISTING_PLAN" | jq '.' > "$TEMP_FILE"
mv "$TEMP_FILE" "$PLAN_STATE"
chmod 600 "$PLAN_STATE"

# Calculate new progress
NEW_COMPLETED=$(echo "$EXISTING_PLAN" | jq '[.steps | to_entries[] | select(.value.status == "completed" or .value.status == "verified")] | length')
NEW_TOTAL=$(echo "$EXISTING_PLAN" | jq '.steps | keys | length')
PERCENTAGE=$((NEW_COMPLETED * 100 / NEW_TOTAL))

log "Updated plan-state: $NEW_COMPLETED/$NEW_TOTAL ($PERCENTAGE%)"

echo "{\"decision\": \"continue\", \"systemMessage\": \"📊 Progress: $NEW_COMPLETED/$NEW_TOTAL ($PERCENTAGE%)\"}"
