#!/bin/bash
# global-task-sync.sh - Sync plan-state with Claude Code global tasks
# VERSION: 2.68.15
#
# Security: SEC-001 path traversal fix, SEC-004 umask, SEC-010 portable mkdir lock
# v2.66.5: SC2168 FIX - Removed 'local' keywords outside functions (shellcheck)
#
# Purpose: UNIDIRECTIONAL sync from local plan-state.json to
#          Claude Code's global task storage at ~/.claude/tasks/<session>/
#          (plan-state.json is the single source of truth)
#
# This implements the Task primitive integration from Claude Code Cowork Mode.
#
# Trigger: PostToolUse (TaskUpdate, TaskCreate)
# Note: TodoWrite removed in v2.66.0 - it doesn't trigger hooks by design
#
# Logic (v2.66.0 - Unidirectional):
# 1. Detect session ID from INPUT.session_id (canonical) or fallbacks
# 2. Read local plan-state.json
# 3. Sync to ~/.claude/tasks/<session>/{id}.json (individual files)
# 4. NO bidirectional sync - plan-state is single source of truth
#
# Output (JSON via stdout for PostToolUse):
#   - {"continue": true}: Allow execution to continue
#   - {"continue": true, "systemMessage": "..."}: Continue with feedback

set -euo pipefail

# SEC-004: Restrictive umask for secure temp file creation
umask 077

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

# Get session ID - INPUT.session_id is CANONICAL (from Claude Code)
get_session_id() {
    # FIRST: Try INPUT.session_id (canonical source from Claude Code)
    if [[ -n "${SESSION_ID_FROM_INPUT:-}" ]]; then
        echo "$SESSION_ID_FROM_INPUT"
        return
    fi
    # Fallback 1: Environment variables
    if [[ -n "${CLAUDE_SESSION_ID:-}" ]]; then
        echo "$CLAUDE_SESSION_ID"
    elif [[ -n "${SESSION_ID:-}" ]]; then
        echo "$SESSION_ID"
    # Fallback 2: Local session file
    elif [[ -f ".claude/session-id" ]]; then
        cat ".claude/session-id"
    else
        # Fallback 3: Generate from plan_id if available
        if [[ -f "$PLAN_STATE" ]]; then
            local plan_id
            plan_id=$(jq -r '.plan_id // empty' "$PLAN_STATE" 2>/dev/null || echo "")
            if [[ -n "$plan_id" ]]; then
                echo "$plan_id"
                return
            fi
        fi
        # Fallback 4: Generate timestamp-based ID
        echo "ralph-$(date +%Y%m%d)-$$"
    fi
}

# Read input from stdin
INPUT=$(cat)

# Extract session_id from INPUT FIRST (canonical source from Claude Code)
SESSION_ID_FROM_INPUT=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only process relevant tools (TodoWrite removed - doesn't trigger hooks by design)
case "$TOOL_NAME" in
    TaskUpdate|TaskCreate)
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

# SEC-001: Sanitize session ID to prevent path traversal attacks
# Remove any path traversal characters and validate format
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')
if [[ -z "$SESSION_ID" || ${#SESSION_ID} -gt 128 ]]; then
    log "Invalid session ID (empty or too long), using fallback"
    SESSION_ID="ralph-$(date +%Y%m%d)-$$"
fi
log "Session ID: $SESSION_ID"

# Create global tasks directory for this session
SESSION_TASKS_DIR="${CLAUDE_TASKS_DIR}/${SESSION_ID}"
mkdir -p "$SESSION_TASKS_DIR"

# Lock directory for atomic operations (portable - works on macOS and Linux)
LOCK_DIR="${SESSION_TASKS_DIR}/.lock.d"

# Acquire lock with timeout using mkdir (portable)
acquire_lock() {
    local attempts=0
    local max_attempts=$((LOCK_TIMEOUT * 10))  # 100ms intervals

    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        attempts=$((attempts + 1))
        if [[ $attempts -ge $max_attempts ]]; then
            log "Failed to acquire lock after ${LOCK_TIMEOUT}s"
            return 1
        fi
        sleep 0.1
    done
    echo "locked"
}

# Release lock
release_lock() {
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

# Convert plan-state to Claude Code tasks format
convert_to_tasks_format() {
    local plan_state="$1"
    local project_json="$2"

    jq \
        --argjson project "$project_json" \
        '{
        session_id: .plan_id,
        task: .task,
        created_at: .metadata.created_at,
        updated_at: .updated_at,
        classification: .classification,
        project: $project,
        tasks: [
            .steps | to_entries[] | {
                id: .key,
                subject: (.value.name // .value.title // ("Step " + .key)),
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
        source: "ralph-v2.66.0"
    }' <<< "$plan_state"
}

# REMOVED (v2.66.6): sync_from_global() function deleted as dead code
# Previously deprecated in v2.66.0. For historical reference, see git history.
# Plan-state.json is the single source of truth - no bidirectional sync needed.

# Write individual task file (Claude Code format: 1.json, 2.json, etc.)
write_individual_task() {
    local task_json="$1"
    local task_id="$2"
    local session_dir="$3"
    local project_json="$4"

    local task_file="${session_dir}/${task_id}.json"

    # Add metadata to task
    local enriched_task
    enriched_task=$(echo "$task_json" | jq \
        --argjson project "$project_json" \
        --arg session "$SESSION_ID" \
        --arg source "ralph-v2.66.0" \
        '. + {
            project: $project,
            session_id: $session,
            source: $source,
            synced_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }')

    # Write atomically with mktemp validation (HIGH-001 fix)
    local temp_file
    temp_file=$(mktemp) || {
        log "CRITICAL: mktemp failed for task $task_id"
        return 1
    }
    echo "$enriched_task" | jq '.' > "$temp_file" || {
        rm -f "$temp_file"
        log "ERROR: jq failed for task $task_id"
        return 1
    }
    mv "$temp_file" "$task_file"
    chmod 600 "$task_file"

    log "Wrote task $task_id to $task_file"
}

# Main sync logic - UNIDIRECTIONAL: plan-state.json → Claude Code Tasks
# (Phase 4: Removed bidirectional sync - plan-state is single source of truth)
{
    # Try to acquire lock (portable mkdir-based locking)
    acquire_lock || {
        log "Could not acquire lock, skipping sync"
        echo '{"continue": true}'
        exit 0
    }

    # Read current plan-state
    PLAN_STATE_CONTENT=$(cat "$PLAN_STATE")

    # Detect project metadata for enrichment
    PROJECT_JSON="{}"
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        # SC2168 FIX: Removed 'local' - not inside a function (brace group != function)
        project_path=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
        repo_remote=$(git remote get-url origin 2>/dev/null || echo "")
        if [[ "$repo_remote" =~ github\.com[:/]([^/]+)/([^/]+)(\.git)?$ ]]; then
            repo_name="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        else
            repo_name=$(basename "$project_path" 2>/dev/null || echo "unknown")
        fi
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
        PROJECT_JSON=$(jq -n \
            --arg path "$project_path" \
            --arg repo "$repo_name" \
            --arg branch "$branch" \
            '{path: $path, repo: $repo, branch: $branch}')
    fi

    # Convert plan-state to Claude Code format
    TASKS_JSON=$(convert_to_tasks_format "$PLAN_STATE_CONTENT" "$PROJECT_JSON")

    # Phase 2: Write INDIVIDUAL task files (1.json, 2.json, etc.)
    # Claude Code expects this format, not a monolithic tasks.json
    TOTAL_TASKS=0
    COMPLETED_TASKS=0

    while IFS= read -r task_json; do
        # SC2168 FIX: Removed 'local' - not inside a function (while loop in brace group)
        task_id=$(echo "$task_json" | jq -r '.id // ""' 2>/dev/null || echo "")
        status=$(echo "$task_json" | jq -r '.status // "pending"' 2>/dev/null || echo "pending")

        if [[ -n "$task_id" ]]; then
            log "Processing task_id=$task_id status=$status"
            write_individual_task "$task_json" "$task_id" "$SESSION_TASKS_DIR" "$PROJECT_JSON" || log "Warning: write failed for task $task_id"
            TOTAL_TASKS=$((TOTAL_TASKS + 1))
            if [[ "$status" == "completed" ]]; then
                COMPLETED_TASKS=$((COMPLETED_TASKS + 1))
            fi
        fi
    done < <(echo "$TASKS_JSON" | jq -c '.tasks[]' 2>/dev/null || echo "")

    # Also save session ID for future reference
    mkdir -p ".claude" 2>/dev/null || true
    echo "$SESSION_ID" > ".claude/session-id"

    log "Synced to global: $COMPLETED_TASKS/$TOTAL_TASKS tasks (individual files)"

    # Release lock
    release_lock

    echo "{\"continue\": true, \"systemMessage\": \"🔄 Global sync: $COMPLETED_TASKS/$TOTAL_TASKS tasks → ~/.claude/tasks/$SESSION_ID/ (individual files)\"}"
}
