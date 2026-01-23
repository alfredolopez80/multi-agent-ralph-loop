#!/bin/bash
# global-task-sync.sh - Sync plan-state with Claude Code global tasks
# VERSION: 2.62.0
#
# Purpose: Bidirectional sync between local plan-state.json and
#          Claude Code's global task storage at ~/.claude/tasks/<session>/
#
# This implements the Task primitive integration from Claude Code Cowork Mode.
#
# Trigger: PostToolUse (TodoWrite, TaskUpdate, TaskCreate)
#
# Logic:
# 1. Detect current session ID
# 2. Read local plan-state.json
# 3. Sync to ~/.claude/tasks/<session>/tasks.json
# 4. Check for external changes and sync back
#
# Output (JSON via stdout for PostToolUse):
#   - {"continue": true}: Allow execution to continue
#   - {"continue": true, "systemMessage": "..."}: Continue with feedback

set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Configuration
PLAN_STATE=".claude/plan-state.json"
CLAUDE_TASKS_DIR="${HOME}/.claude/tasks"
LOG_FILE="${HOME}/.ralph/logs/global-task-sync.log"
LOCK_TIMEOUT=5

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [global-task-sync] $*" >> "$LOG_FILE"
}

# Get session ID from environment or generate one
get_session_id() {
    # Try common session ID sources
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
        echo "$CLAUDE_SESSION_ID"
    elif [[ -n "${SESSION_ID:-}" ]]; then
        echo "$SESSION_ID"
    elif [[ -f ".claude/session-id" ]]; then
        cat ".claude/session-id"
    else
        # Generate from plan_id if available
        if [[ -f "$PLAN_STATE" ]]; then
            local plan_id
            plan_id=$(jq -r '.plan_id // empty' "$PLAN_STATE" 2>/dev/null || echo "")
            if [[ -n "$plan_id" ]]; then
                echo "$plan_id"
                return
            fi
        fi
        # Fallback: generate based on timestamp and PID
        echo "ralph-$(date +%Y%m%d)-$$"
    fi
}

# Read input from stdin
INPUT=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only process relevant tools
case "$TOOL_NAME" in
    TodoWrite|TaskUpdate|TaskCreate)
        log "Processing $TOOL_NAME for global sync"
        ;;
    *)
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Check if plan-state exists
if [[ ! -f "$PLAN_STATE" ]]; then
    log "No plan-state.json found, skipping global sync"
    echo '{"continue": true}'
    exit 0
fi

# Get session ID
SESSION_ID=$(get_session_id)
log "Session ID: $SESSION_ID"

# Create global tasks directory for this session
SESSION_TASKS_DIR="${CLAUDE_TASKS_DIR}/${SESSION_ID}"
mkdir -p "$SESSION_TASKS_DIR"

# Lock file for atomic operations
LOCK_FILE="${SESSION_TASKS_DIR}/.lock"

# Acquire lock with timeout
acquire_lock() {
    local lock_fd
    exec {lock_fd}>"$LOCK_FILE"
    if ! flock -w "$LOCK_TIMEOUT" "$lock_fd"; then
        log "Failed to acquire lock after ${LOCK_TIMEOUT}s"
        return 1
    fi
    echo "$lock_fd"
}

# Release lock
release_lock() {
    local lock_fd="$1"
    flock -u "$lock_fd" 2>/dev/null || true
}

# Convert plan-state to Claude Code tasks format
convert_to_tasks_format() {
    local plan_state="$1"

    jq '{
        session_id: .plan_id,
        task: .task,
        created_at: .metadata.created_at,
        updated_at: .updated_at,
        classification: .classification,
        tasks: [
            .steps | to_entries[] | {
                id: .key,
                subject: .value.name,
                status: (
                    if .value.status == "completed" or .value.status == "verified" then "completed"
                    elif .value.status == "in_progress" then "in_progress"
                    else "pending"
                    end
                ),
                agent: .value.agent,
                verification: .value.verification,
                started_at: .value.started_at,
                completed_at: .value.completed_at
            }
        ],
        phases: .phases,
        barriers: .barriers,
        loop_state: .loop_state,
        source: "ralph-v2.62"
    }' <<< "$plan_state"
}

# Convert Claude Code tasks format back to plan-state updates
sync_from_global() {
    local global_tasks="$1"
    local local_plan="$2"

    # Check if global has newer updates
    local global_updated local_updated
    global_updated=$(jq -r '.updated_at // "1970-01-01T00:00:00Z"' <<< "$global_tasks" 2>/dev/null || echo "1970-01-01T00:00:00Z")
    local_updated=$(jq -r '.updated_at // "1970-01-01T00:00:00Z"' <<< "$local_plan" 2>/dev/null || echo "1970-01-01T00:00:00Z")

    # Compare timestamps (basic string comparison works for ISO8601)
    if [[ "$global_updated" > "$local_updated" ]]; then
        log "Global tasks are newer, syncing back to local"

        # Update step statuses from global
        local updated_plan="$local_plan"

        while IFS= read -r task_json; do
            local task_id status
            task_id=$(jq -r '.id' <<< "$task_json")
            status=$(jq -r '.status' <<< "$task_json")

            # Map status back to plan-state format
            local plan_status="$status"

            updated_plan=$(jq \
                --arg key "$task_id" \
                --arg status "$plan_status" \
                'if .steps[$key] then .steps[$key].status = $status else . end' \
                <<< "$updated_plan")
        done < <(jq -c '.tasks[]' <<< "$global_tasks" 2>/dev/null || echo "")

        echo "$updated_plan"
    else
        echo "$local_plan"
    fi
}

# Main sync logic
LOCK_FD=""
{
    # Try to acquire lock
    LOCK_FD=$(acquire_lock) || {
        log "Could not acquire lock, skipping sync"
        echo '{"continue": true}'
        exit 0
    }

    # Read current plan-state
    PLAN_STATE_CONTENT=$(cat "$PLAN_STATE")

    # Check for existing global tasks
    GLOBAL_TASKS_FILE="${SESSION_TASKS_DIR}/tasks.json"

    if [[ -f "$GLOBAL_TASKS_FILE" ]]; then
        # Bidirectional sync
        GLOBAL_TASKS=$(cat "$GLOBAL_TASKS_FILE")

        # Sync any external changes back to local
        UPDATED_PLAN=$(sync_from_global "$GLOBAL_TASKS" "$PLAN_STATE_CONTENT")

        # If plan was updated, write it back
        if [[ "$UPDATED_PLAN" != "$PLAN_STATE_CONTENT" ]]; then
            log "Writing synced changes back to plan-state.json"
            TEMP_FILE=$(mktemp)
            echo "$UPDATED_PLAN" | jq '.' > "$TEMP_FILE"
            mv "$TEMP_FILE" "$PLAN_STATE"
            chmod 600 "$PLAN_STATE"
            PLAN_STATE_CONTENT="$UPDATED_PLAN"
        fi
    fi

    # Convert and write to global
    TASKS_JSON=$(convert_to_tasks_format "$PLAN_STATE_CONTENT")

    # Write atomically
    TEMP_FILE=$(mktemp)
    echo "$TASKS_JSON" | jq '.' > "$TEMP_FILE"
    mv "$TEMP_FILE" "$GLOBAL_TASKS_FILE"
    chmod 600 "$GLOBAL_TASKS_FILE"

    # Also save session ID for future reference
    echo "$SESSION_ID" > ".claude/session-id"

    # Count tasks
    TOTAL_TASKS=$(echo "$TASKS_JSON" | jq '.tasks | length')
    COMPLETED_TASKS=$(echo "$TASKS_JSON" | jq '[.tasks[] | select(.status == "completed")] | length')

    log "Synced to global: $COMPLETED_TASKS/$TOTAL_TASKS tasks"

    # Release lock
    release_lock "$LOCK_FD"

    echo "{\"continue\": true, \"systemMessage\": \"🔄 Global sync: $COMPLETED_TASKS/$TOTAL_TASKS tasks → ~/.claude/tasks/$SESSION_ID/\"}"
}
