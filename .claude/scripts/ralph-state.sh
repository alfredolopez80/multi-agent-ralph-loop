#!/bin/bash
# ralph-state.sh - State management for Ralph Loop Stop Hook integration
# VERSION: 2.87.0
# REPO: multi-agent-ralph-loop
#
# This script manages state files that the ralph-stop-quality-gate.sh hook reads
# to determine if Claude should be blocked from stopping.
#
# Usage:
#   ralph-state.sh init <session_id> <type> [task_description]
#   ralph-state.sh update <session_id> <type> <json_fields>
#   ralph-state.sh increment <session_id> <type>
#   ralph-state.sh complete <session_id> <type>
#   ralph-state.sh fail <session_id> <type> <error_message>
#   ralph-state.sh read <session_id> <type>
#   ralph-state.sh delete <session_id>
#
# Types: loop, orchestrator, quality-gate
#
# State files are stored in: ~/.ralph/state/{session_id}/{type}.json

set -euo pipefail

# Configuration
STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$STATE_DIR"
mkdir -p "$LOG_DIR"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_DIR/ralph-state.log"
}

# Usage
usage() {
    cat <<EOF
Usage: ralph-state.sh <command> [arguments]

Commands:
  init <session_id> <type> [task]     Initialize state file
  update <session_id> <type> <json>   Update with JSON fields (e.g., 'phase=implementation')
  increment <session_id> <type>       Increment iteration counter
  complete <session_id> <type>        Mark as VERIFIED_DONE
  fail <session_id> <type> <error>    Mark as failed with error message
  read <session_id> <type>            Read and output state
  delete <session_id>                 Delete all state for session

Types: loop, orchestrator, quality-gate

Examples:
  ralph-state.sh init abc123 loop "fix type errors"
  ralph-state.sh update abc123 loop 'validation_result=passed,last_error='
  ralph-state.sh increment abc123 loop
  ralph-state.sh complete abc123 loop
  ralph-state.sh fail abc123 loop "Type error in src/auth.ts:42"
EOF
    exit 1
}

# Initialize state file
init_state() {
    local session_id="$1"
    local type="$2"
    local task="${3:-}"
    local state_file="$STATE_DIR/$session_id/$type.json"

    mkdir -p "$(dirname "$state_file")"

    case "$type" in
        loop)
            jq -n \
                --arg session_id "$session_id" \
                --arg task "$task" \
                '{
                    session_id: $session_id,
                    task: $task,
                    iteration: 0,
                    max_iterations: 25,
                    validation_result: "pending",
                    last_error: "",
                    verified_done: false,
                    created_at: (now | todate),
                    last_updated: (now | todate)
                }' > "$state_file"
            ;;
        orchestrator)
            jq -n \
                --arg session_id "$session_id" \
                --arg task "$task" \
                '{
                    session_id: $session_id,
                    task: $task,
                    phase: "init",
                    verified_done: false,
                    conditions: {
                        memory_search: false,
                        task_classified: false,
                        must_have_answered: false,
                        plan_approved: false,
                        implementation_complete: false,
                        correctness_passed: null,
                        quality_passed: null,
                        adversarial_passed: null,
                        retrospective_done: false
                    },
                    iterations: 0,
                    created_at: (now | todate),
                    last_updated: (now | todate)
                }' > "$state_file"
            ;;
        quality-gate)
            jq -n \
                --arg session_id "$session_id" \
                '{
                    session_id: $session_id,
                    last_result: "pending",
                    stages: {
                        correctness: { status: "pending", details: null },
                        quality: { status: "pending", details: null },
                        security: { status: "pending", details: null }
                    },
                    last_updated: (now | todate)
                }' > "$state_file"
            ;;
        *)
            echo "Unknown type: $type" >&2
            exit 1
            ;;
    esac

    log "INIT: $session_id/$type - $task"
}

# Update state with JSON fields
update_state() {
    local session_id="$1"
    local type="$2"
    local fields="$3"
    local state_file="$STATE_DIR/$session_id/$type.json"

    if [ ! -f "$state_file" ]; then
        echo "State file not found: $state_file" >&2
        exit 1
    fi

    # Parse fields (format: key1=value1,key2=value2)
    local update_json="."
    IFS=',' read -ra pairs <<< "$fields"
    for pair in "${pairs[@]}"; do
        key="${pair%%=*}"
        value="${pair#*=}"

        # Handle nested keys (e.g., conditions.implementation_complete)
        if [[ "$key" == *.* ]]; then
            parent="${key%%.*}"
            child="${key#*.}"
            update_json="$update_json | .${parent}.${child} = \"${value}\""
        else
            update_json="$update_json | .${key} = \"${value}\""
        fi
    done

    # Add last_updated timestamp
    update_json="$update_json | .last_updated = (now | todate)"

    # Apply update
    local temp_file=$(mktemp)
    jq "$update_json" "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"

    log "UPDATE: $session_id/$type - $fields"
}

# Increment iteration counter
increment_iteration() {
    local session_id="$1"
    local type="$2"
    local state_file="$STATE_DIR/$session_id/$type.json"

    if [ ! -f "$state_file" ]; then
        echo "State file not found: $state_file" >&2
        exit 1
    fi

    local temp_file=$(mktemp)
    jq '.iteration += 1 | .last_updated = (now | todate)' "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"

    local new_iteration=$(jq -r '.iteration' "$state_file")
    log "INCREMENT: $session_id/$type - iteration $new_iteration"
}

# Mark as complete (VERIFIED_DONE)
complete_state() {
    local session_id="$1"
    local type="$2"
    local state_file="$STATE_DIR/$session_id/$type.json"

    if [ ! -f "$state_file" ]; then
        echo "State file not found: $state_file" >&2
        exit 1
    fi

    local temp_file=$(mktemp)
    jq '.verified_done = true | .last_updated = (now | todate)' "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"

    log "COMPLETE: $session_id/$type - VERIFIED_DONE"
}

# Mark as failed with error
fail_state() {
    local session_id="$1"
    local type="$2"
    local error="$3"
    local state_file="$STATE_DIR/$session_id/$type.json"

    if [ ! -f "$state_file" ]; then
        echo "State file not found: $state_file" >&2
        exit 1
    fi

    local temp_file=$(mktemp)

    case "$type" in
        loop)
            jq --arg error "$error" \
                '.validation_result = "failed" | .last_error = $error | .verified_done = false | .last_updated = (now | todate)' \
                "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
            ;;
        quality-gate)
            jq --arg error "$error" \
                '.last_result = "failed" | .last_updated = (now | todate)' \
                "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
            ;;
        *)
            jq --arg error "$error" \
                '.last_error = $error | .verified_done = false | .last_updated = (now | todate)' \
                "$state_file" > "$temp_file" && mv "$temp_file" "$state_file"
            ;;
    esac

    log "FAIL: $session_id/$type - $error"
}

# Read and output state
read_state() {
    local session_id="$1"
    local type="$2"
    local state_file="$STATE_DIR/$session_id/$type.json"

    if [ -f "$state_file" ]; then
        cat "$state_file"
    else
        echo '{"error": "State file not found"}' >&2
        exit 1
    fi
}

# Delete all state for session
delete_state() {
    local session_id="$1"
    local session_dir="$STATE_DIR/$session_id"

    if [ -d "$session_dir" ]; then
        rm -rf "$session_dir"
        log "DELETE: $session_id - all state removed"
    fi
}

# Main
case "${1:-}" in
    init)
        [ $# -lt 3 ] && usage
        init_state "$2" "$3" "${4:-}"
        ;;
    update)
        [ $# -lt 4 ] && usage
        update_state "$2" "$3" "$4"
        ;;
    increment)
        [ $# -lt 3 ] && usage
        increment_iteration "$2" "$3"
        ;;
    complete)
        [ $# -lt 3 ] && usage
        complete_state "$2" "$3"
        ;;
    fail)
        [ $# -lt 4 ] && usage
        fail_state "$2" "$3" "$4"
        ;;
    read)
        [ $# -lt 3 ] && usage
        read_state "$2" "$3"
        ;;
    delete)
        [ $# -lt 2 ] && usage
        delete_state "$2"
        ;;
    *)
        usage
        ;;
esac
