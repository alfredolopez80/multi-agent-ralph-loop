#!/bin/bash
# batch-progress-tracker.sh - Track batch execution progress
# Version: 2.88.0
# Trigger: PostToolUse (Task, TaskUpdate, TaskCreate)
# Exit 2: Continue if tasks remain

BATCH_DIR="$HOME/.ralph/batch"
PROGRESS_FILE=""

# Find active batch
find_active_batch() {
    local latest=""
    for dir in "$BATCH_DIR"/*; do
        if [[ -d "$dir" && -f "$dir/progress.json" ]]; then
            latest="$dir"
        fi
    done
    echo "$latest"
}

# Update progress
update_progress() {
    local batch_dir="$1"
    local action="$2"
    local task_id="$3"
    local status="$4"

    if [[ ! -f "$batch_dir/progress.json" ]]; then
        return 0
    fi

    local progress_file="$batch_dir/progress.json"

    case "$action" in
        "task_created")
            jq --arg id "$task_id" '.total_tasks += 1 | .tasks += [{"id": $id, "status": "pending"}]' "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
            ;;
        "task_started")
            jq --arg id "$task_id" --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ) '(.tasks[] | select(.id == $id)).status = "in_progress" | (.tasks[] | select(.id == $id)).started = $time' "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
            jq '.current_task = $id | .last_update = $time' --arg id "$task_id" --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
            ;;
        "task_completed")
            jq --arg id "$task_id" --arg status "$status" --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '(.tasks[] | select(.id == $id)).status = $status | (.tasks[] | select(.id == $id)).completed = $time | .completed += 1' "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
            jq '.last_update = $time' --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
            ;;
        "task_failed")
            jq --arg id "$task_id" --arg status "$status" --arg time "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '(.tasks[] | select(.id == $id)).status = "failed" | (.tasks[] | select(.id == $id)).failed = $time | .failed += 1' "$progress_file" > "${progress_file}.tmp" && mv "${progress_file}.tmp" "$progress_file"
            ;;
    esac
}

# Check if more tasks remain
has_remaining_tasks() {
    local batch_dir="$1"
    local progress_file="$batch_dir/progress.json"

    if [[ ! -f "$progress_file" ]]; then
        return 1
    fi

    local pending=$(jq '[.tasks[] | select(.status == "pending" or .status == "in_progress")] | length' "$progress_file" 2>/dev/null || echo "0")

    if [[ "$pending" -gt 0 ]]; then
        return 0  # More tasks remain
    else
        return 1  # All done
    fi
}

# Main logic
main() {
    local batch_dir=$(find_active_batch)

    if [[ -z "$batch_dir" ]]; then
        # No active batch, exit normally
        exit 0
    fi

    # Parse tool input if available
    if [[ -n "$CLAUDE_TOOL_INPUT" ]]; then
        local action=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.action // empty' 2>/dev/null)
        local task_id=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.taskId // .task_id // empty' 2>/dev/null)
        local status=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.status // empty' 2>/dev/null)

        if [[ -n "$action" && -n "$task_id" ]]; then
            update_progress "$batch_dir" "$action" "$task_id" "$status"
        fi
    fi

    # Check if tasks remain
    if has_remaining_tasks "$batch_dir"; then
        # Output progress info
        local completed=$(jq '.completed // 0' "$batch_dir/progress.json" 2>/dev/null)
        local total=$(jq '.total_tasks // 0' "$batch_dir/progress.json" 2>/dev/null)
        local current=$(jq -r '.current_task // "none"' "$batch_dir/progress.json" 2>/dev/null)

        echo "{\"hookSpecificOutput\": {\"progress\": \"Batch progress: $completed/$total tasks completed. Current: $current\", \"tasks_remain\": true}}"
        exit 2  # Continue execution
    else
        # All tasks complete
        echo "{\"hookSpecificOutput\": {\"progress\": \"Batch complete! All tasks finished.\", \"tasks_remain\": false}}"
        exit 0
    fi
}

main "$@"
