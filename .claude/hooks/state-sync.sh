#!/usr/bin/env bash
# VERSION: 2.57.0
# Hook: state-sync.sh
# Trigger: PostToolUse (Task completion, Bash with handoff commands)
# Purpose: Ensure state consistency across all subsystems after operations
#
# This hook bridges gaps between:
#   - Task completions and plan-state updates
#   - Handoff finalization and memory transfer
#   - Event bus state and barrier synchronization
#
# v2.54: Central hook for unified state management

set -euo pipefail
umask 077

# Configuration
PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/state-sync.log"
STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"
EVENT_BUS="${HOME}/.claude/scripts/event-bus.sh"
AGENT_MEMORY="${HOME}/.claude/scripts/agent-memory-buffer.sh"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Parse hook input
parse_hook_input() {
    local input
    input=$(cat)

    # Extract tool information
    TOOL_NAME=$(echo "$input" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")
    TOOL_INPUT=$(echo "$input" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")
    TOOL_RESULT=$(echo "$input" | jq -r '.tool_result // ""' 2>/dev/null || echo "")

    # Store for later use
    echo "$input" > /tmp/state-sync-input-$$.json
}

# Handle Task tool completion
handle_task_completion() {
    local subagent_type prompt result

    subagent_type=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // ""' 2>/dev/null || echo "")
    prompt=$(echo "$TOOL_INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")

    log "Task completion: subagent=$subagent_type"

    # Update active agent back to orchestrator after Task completion
    if [ -x "$STATE_COORDINATOR" ]; then
        "$STATE_COORDINATOR" set-active-agent "orchestrator" 2>/dev/null || true
        log "Reset active_agent to orchestrator after Task completion"
    fi

    # Emit task completion event
    if [ -x "$EVENT_BUS" ]; then
        local payload
        payload=$(jq -nc --arg agent "$subagent_type" '{"agent": $agent, "status": "completed"}')
        "$EVENT_BUS" emit "task.complete" "$payload" "state-sync" 2>/dev/null || true
    fi
}

# Handle Bash with handoff commands
handle_handoff_bash() {
    local command result

    command=$(echo "$TOOL_INPUT" | jq -r '.command // ""' 2>/dev/null || echo "")

    # Detect handoff-related commands
    if [[ "$command" == *"handoff"* ]] || [[ "$command" == *"ralph handoff"* ]]; then
        log "Handoff command detected: $command"

        # Check if this is a transfer command
        if [[ "$command" == *"transfer"* ]]; then
            # Extract target agent if possible
            local to_agent
            to_agent=$(echo "$command" | grep -oE '\-\-to[[:space:]]+([a-zA-Z0-9_-]+)' | sed 's/--to[[:space:]]*//')

            if [ -n "$to_agent" ]; then
                log "Handoff transfer to: $to_agent"

                # Ensure active_agent is updated (handoff.sh should do this, but verify)
                if [ -x "$STATE_COORDINATOR" ]; then
                    local current_agent
                    current_agent=$("$STATE_COORDINATOR" get-active-agent 2>/dev/null || echo "")

                    if [ "$current_agent" != "$to_agent" ]; then
                        "$STATE_COORDINATOR" set-active-agent "$to_agent" 2>/dev/null || true
                        log "Synchronized active_agent to: $to_agent"
                    fi
                fi
            fi
        fi
    fi
}

# Handle barrier synchronization
sync_barriers() {
    if [ ! -f "$PLAN_STATE" ]; then
        return 0
    fi

    if [ ! -x "$STATE_COORDINATOR" ]; then
        return 0
    fi

    log "Checking barrier synchronization..."

    # Get current phase
    local current_phase
    current_phase=$(jq -r '.current_phase // ""' "$PLAN_STATE" 2>/dev/null || echo "")

    if [ -z "$current_phase" ]; then
        return 0
    fi

    # Check if current phase should have its barrier completed
    local phase_complete
    phase_complete=$("$STATE_COORDINATOR" check-phase-complete "$current_phase" 2>/dev/null || echo "false")

    if [ "$phase_complete" = "true" ]; then
        local barrier_status
        barrier_status=$(jq -r --arg pid "$current_phase" '.barriers[$pid] // false' "$PLAN_STATE" 2>/dev/null || echo "false")

        if [ "$barrier_status" != "true" ]; then
            log "Barrier desync detected for phase $current_phase - synchronizing"
            "$STATE_COORDINATOR" complete-barrier "$current_phase" 2>/dev/null || true

            # Emit barrier completion event
            if [ -x "$EVENT_BUS" ]; then
                "$EVENT_BUS" emit "barrier.complete" "{\"phase_id\": \"$current_phase\"}" "state-sync" 2>/dev/null || true
            fi
        fi
    fi
}

# Check and repair state consistency
repair_state_consistency() {
    if [ ! -f "$PLAN_STATE" ]; then
        return 0
    fi

    log "Checking state consistency..."

    # Get plan-state metrics
    local version phases_count steps_count active_agent
    version=$(jq -r '.version // "unknown"' "$PLAN_STATE" 2>/dev/null || echo "unknown")
    phases_count=$(jq -r '.phases | length' "$PLAN_STATE" 2>/dev/null || echo "0")
    steps_count=$(jq -r '.steps | keys | length' "$PLAN_STATE" 2>/dev/null || echo "0")
    active_agent=$(jq -r '.active_agent // "orchestrator"' "$PLAN_STATE" 2>/dev/null || echo "orchestrator")

    log "State: version=$version, phases=$phases_count, steps=$steps_count, active_agent=$active_agent"

    # Verify v2.51+ schema
    if [[ ! "$version" =~ ^2\.5[1-9] ]]; then
        log "WARN: Legacy schema detected (v$version), some features may not work"
    fi

    # Check for orphaned in_progress steps (potential stale state)
    local in_progress_count
    in_progress_count=$(jq -r '[.steps | to_entries[] | select(.value.status == "in_progress")] | length' "$PLAN_STATE" 2>/dev/null || echo "0")

    if [ "$in_progress_count" -gt 1 ]; then
        log "WARN: Multiple in_progress steps detected ($in_progress_count) - possible stale state"
    fi
}

# Main entry point
main() {
    parse_hook_input

    log "State-sync hook triggered for tool: $TOOL_NAME"

    case "$TOOL_NAME" in
        Task)
            handle_task_completion
            ;;
        Bash)
            handle_handoff_bash
            ;;
    esac

    # Always sync barriers and check consistency
    sync_barriers
    repair_state_consistency

    # Cleanup
    rm -f /tmp/state-sync-input-$$.json

    # Return success (PostToolUse format)
    echo '{"continue": true}'
}

main "$@"
