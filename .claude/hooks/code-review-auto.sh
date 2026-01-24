#!/usr/bin/env bash
#===============================================================================
# Code Review Auto Hook v2.68.0
# PostToolUse hook - AUTO-INVOKE code review after step completion
#===============================================================================
#
# VERSION: 2.68.2
# TRIGGER: PostToolUse (TaskUpdate - when step completes)
# PURPOSE: Automatically invoke code review for completed steps
#
# CHANGE FROM v2.67: Now uses IMPERATIVE instructions, not suggestions

set -euo pipefail
umask 077

readonly VERSION="2.68.0"
readonly HOOK_NAME="code-review-auto"

# Configuration
readonly PLAN_STATE=".claude/plan-state.json"
readonly MARKERS_DIR="${HOME}/.ralph/markers"
readonly LOG_FILE="${HOME}/.ralph/logs/code-review.log"

# Ensure directories exist
mkdir -p "$MARKERS_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Logging
log() {
    echo "[$(date -Iseconds)] [$HOOK_NAME] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get session ID
get_session_id() {
    echo "${CLAUDE_SESSION_ID:-$$}"
}

# Check if code review already done for step
review_done_for_step() {
    local step_id="$1"
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/review-done-${session_id}-${step_id}"
    [[ -f "$marker" ]]
}

# Mark review done for step
mark_review_done() {
    local step_id="$1"
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/review-done-${session_id}-${step_id}"
    touch "$marker" 2>/dev/null || true
}

# Get changed files from git diff
get_recent_changed_files() {
    git diff --name-only HEAD~1 2>/dev/null | head -10 || echo ""
}

# Get step complexity
get_step_complexity() {
    local step_id="$1"

    if [[ ! -f "$PLAN_STATE" ]]; then
        echo "5"  # Default medium complexity
        return
    fi

    # Try to get step-specific complexity or fall back to plan complexity
    local complexity
    complexity=$(jq -r --arg id "$step_id" '
        if (.steps | type) == "array" then
            (.steps[] | select(.id == $id) | .complexity) // .classification.complexity // 5
        else
            .steps[$id].complexity // .classification.complexity // 5
        end
    ' "$PLAN_STATE" 2>/dev/null || echo "5")

    echo "$complexity"
}

# Main logic
main() {
    # Read input from stdin
    local input
    input=$(cat 2>/dev/null || echo '{}')

    # Extract tool name
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

    # Only process TaskUpdate
    if [[ "$tool_name" != "TaskUpdate" ]]; then
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Extract task update info
    local task_id
    task_id=$(echo "$input" | jq -r '.tool_input.taskId // ""' 2>/dev/null || echo "")
    local new_status
    new_status=$(echo "$input" | jq -r '.tool_input.status // ""' 2>/dev/null || echo "")

    # Only process completions
    if [[ "$new_status" != "completed" ]]; then
        log "Not a completion event (status: $new_status)"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Skip if already reviewed
    if review_done_for_step "$task_id"; then
        log "Already reviewed step: $task_id"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Get changed files
    local changed_files
    changed_files=$(get_recent_changed_files)

    if [[ -z "$changed_files" ]]; then
        log "No changed files for step $task_id"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Mark as reviewed
    mark_review_done "$task_id"

    log "AUTO-INVOKING: code review for step $task_id"

    # Build IMPERATIVE instruction
    local instruction
    instruction=$(cat << EOF
**AUTO-INVOKE REQUIRED: Code Review**

Step \`$task_id\` completed. Per orchestrator quality policy, code review is MANDATORY.

**Changed files:**
\`\`\`
$changed_files
\`\`\`

**YOU MUST NOW EXECUTE ONE OF:**

Option 1 - Use code-reviewer agent (RECOMMENDED):
\`\`\`yaml
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  prompt: |
    Review the recent changes for quality issues:
    - Runtime errors (exceptions, null checks)
    - Performance (O(n^2), N+1 queries)
    - Security (injection, XSS, auth)
    - Test coverage gaps
\`\`\`

Option 2 - Quick inline review:
Review the changes yourself focusing on correctness, security, and performance.

After review completes, continue with the next step.
EOF
)

    # Output with system message (imperative instruction)
    local escaped_instruction
    escaped_instruction=$(echo "$instruction" | jq -Rs '.')

    trap - ERR EXIT
    echo "{\"continue\": true, \"systemMessage\": $escaped_instruction}"
}

main "$@"
