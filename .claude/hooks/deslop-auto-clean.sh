#!/bin/bash
#!/usr/bin/env bash
#===============================================================================
# Deslop Auto-Clean Hook v2.68.0
# PostToolUse hook - AUTO-INVOKE /deslop after implementation phase
#===============================================================================
#
# VERSION: 2.69.0
# TRIGGER: PostToolUse (Edit|Write)
# PURPOSE: Automatically invoke /deslop to clean AI-generated slop
#
# CHANGE FROM v2.67: Now uses IMPERATIVE instructions, not suggestions

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

readonly VERSION="2.68.0"
readonly HOOK_NAME="deslop-auto-clean"

# Configuration
readonly MARKERS_DIR="${HOME}/.ralph/markers"
readonly LOG_FILE="${HOME}/.ralph/logs/deslop.log"
readonly THRESHOLD_OPERATIONS=8  # Trigger after 8 edit/write operations

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

# Get operation count for this session
get_operation_count() {
    local session_id
    session_id=$(get_session_id)
    local counter="${MARKERS_DIR}/edit-count-${session_id}"
    if [[ -f "$counter" ]]; then
        cat "$counter" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Increment operation count
increment_operation_count() {
    local session_id
    session_id=$(get_session_id)
    local counter="${MARKERS_DIR}/edit-count-${session_id}"
    local current
    current=$(get_operation_count)
    echo "$((current + 1))" > "$counter"
}

# Check if deslop already invoked this session
deslop_already_invoked() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/deslop-invoked-${session_id}"
    [[ -f "$marker" ]]
}

# Mark deslop as invoked
mark_deslop_invoked() {
    local session_id
    session_id=$(get_session_id)
    local marker="${MARKERS_DIR}/deslop-invoked-${session_id}"
    touch "$marker" 2>/dev/null || true
}

# Check if implementation phase is complete
implementation_complete() {
    local plan_state=".claude/plan-state.json"

    if [[ ! -f "$plan_state" ]]; then
        return 1
    fi

    local loop_status
    loop_status=$(jq -r '.loop_state.status // ""' "$plan_state" 2>/dev/null || echo "")

    # Check if transitioning to validate phase
    [[ "$loop_status" == "validating" ]] || [[ "$loop_status" == "implemented" ]]
}

# Main logic
main() {
    # v2.69: Use $INPUT from SEC-111 read instead of second cat (fixes CRIT-001 double-read bug)
    local input="$INPUT"

    # Extract tool name
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

    # Only process Edit/Write
    if [[ "$tool_name" != "Edit" ]] && [[ "$tool_name" != "Write" ]]; then
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Increment operation count
    increment_operation_count

    local op_count
    op_count=$(get_operation_count)
    log "Operation count: $op_count"

    # Check if already invoked
    if deslop_already_invoked; then
        log "Deslop already invoked this session"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Trigger conditions:
    # 1. After threshold operations
    # 2. Implementation phase complete
    local should_trigger=false

    if [[ "$op_count" -ge "$THRESHOLD_OPERATIONS" ]]; then
        should_trigger=true
        log "Threshold reached: $op_count >= $THRESHOLD_OPERATIONS"
    fi

    if implementation_complete; then
        should_trigger=true
        log "Implementation phase complete"
    fi

    if [[ "$should_trigger" != "true" ]]; then
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Mark as invoked
    mark_deslop_invoked

    log "AUTO-INVOKING: /deslop (op_count=$op_count)"

    # Build IMPERATIVE instruction
    local instruction
    instruction=$(cat << 'EOF'
**AUTO-INVOKE REQUIRED: /deslop**

Multiple code changes detected (8+ operations). Per orchestrator quality policy, AI slop cleanup is MANDATORY.

**YOU MUST NOW EXECUTE:**
```
/deslop
```

This removes:
- Extra comments that a human wouldn't add
- Unnecessary defensive checks/try-catch blocks
- Type casts to bypass issues (e.g., `any` in TypeScript)
- Inline imports in Python (moves to top)
- Style inconsistent with the rest of the file

Do not skip this step. Continue with normal flow after /deslop completes.
EOF
)

    # Output with system message (imperative instruction)
    local escaped_instruction
    escaped_instruction=$(echo "$instruction" | jq -Rs '.')

    trap - ERR EXIT
    echo "{\"continue\": true, \"systemMessage\": $escaped_instruction}"
}

main "$@"
