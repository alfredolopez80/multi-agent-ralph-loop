#!/usr/bin/env bash
#===============================================================================
# Adversarial Auto-Trigger Hook v2.68.0
# PostToolUse hook - AUTO-INVOKE /adversarial for high complexity tasks
#===============================================================================
#
# VERSION: 2.68.0
# TRIGGER: PostToolUse (Task - when orchestrator step completes)
# PURPOSE: Automatically invoke /adversarial for complexity >= 7
#
# CHANGE FROM v2.67: Now uses IMPERATIVE instructions, not suggestions
# The systemMessage tells Claude to EXECUTE the skill, not just consider it

set -euo pipefail
umask 077

readonly VERSION="2.68.0"
readonly HOOK_NAME="adversarial-auto-trigger"

# Configuration
readonly PLAN_STATE=".claude/plan-state.json"
readonly MARKERS_DIR="${HOME}/.ralph/markers"
readonly LOG_FILE="${HOME}/.ralph/logs/adversarial-trigger.log"
readonly COMPLEXITY_THRESHOLD=7

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

# Check if adversarial already invoked this session
adversarial_already_invoked() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/adversarial-invoked-${session_id}"
    [[ -f "$marker" ]]
}

# Mark adversarial as invoked
mark_adversarial_invoked() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/adversarial-invoked-${session_id}"
    touch "$marker" 2>/dev/null || true
}

# Get complexity from plan-state
get_complexity() {
    if [[ ! -f "$PLAN_STATE" ]]; then
        echo "0"
        return
    fi

    jq -r '.classification.complexity // .complexity // 0' "$PLAN_STATE" 2>/dev/null || echo "0"
}

# Check if in validation phase
in_validation_phase() {
    if [[ ! -f "$PLAN_STATE" ]]; then
        return 1
    fi

    local current_phase
    current_phase=$(jq -r '.loop_state.current_phase // .current_step // ""' "$PLAN_STATE" 2>/dev/null || echo "")

    [[ "$current_phase" == "validate" ]] || [[ "$current_phase" == "7" ]] || [[ "$current_phase" =~ ^validate ]]
}

# Main logic
main() {
    # Read input from stdin
    local input
    input=$(cat 2>/dev/null || echo '{}')

    # Extract tool name
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

    # Only process Task completions
    if [[ "$tool_name" != "Task" ]]; then
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Skip if already invoked this session
    if adversarial_already_invoked; then
        log "Adversarial already invoked this session"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Get complexity
    local complexity
    complexity=$(get_complexity)
    log "Complexity: $complexity (threshold: $COMPLEXITY_THRESHOLD)"

    # Check if complexity meets threshold
    if [[ "$complexity" -lt "$COMPLEXITY_THRESHOLD" ]]; then
        log "Complexity $complexity < $COMPLEXITY_THRESHOLD, skipping"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Check if in validation phase
    if ! in_validation_phase; then
        log "Not in validation phase, skipping"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Mark as invoked
    mark_adversarial_invoked

    log "AUTO-INVOKING: /adversarial (complexity=$complexity >= $COMPLEXITY_THRESHOLD)"

    # Build IMPERATIVE instruction (not suggestion)
    local instruction
    instruction=$(cat << 'EOF'
**AUTO-INVOKE REQUIRED: /adversarial**

This task has complexity >= 7. Per orchestrator quality policy, adversarial validation is MANDATORY.

**YOU MUST NOW EXECUTE:**
```
/adversarial
```

This is an automatic quality gate. Do not skip this step.
After /adversarial completes, continue with the validation phase.
EOF
)

    # Output with system message (imperative instruction)
    local escaped_instruction
    escaped_instruction=$(echo "$instruction" | jq -Rs '.')

    trap - ERR EXIT
    echo "{\"continue\": true, \"systemMessage\": $escaped_instruction}"
}

main "$@"
