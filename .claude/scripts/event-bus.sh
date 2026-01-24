#!/bin/bash
# VERSION: 2.54.0
# v2.54: Integrated with State Coordinator for unified state management
# Script: event-bus.sh
# Purpose: Event-driven workflow engine with phase barriers
#
# Architecture (based on LangGraph patterns):
#   - Event bus for agent-to-agent communication
#   - WAIT-ALL barriers for phase synchronization
#   - Dynamic routing based on plan state
#   - Support for loops and resumes
#
# Usage:
#   source event-bus.sh
#   event_bus emit <event_type> <payload>
#   event_bus subscribe <event_type> <handler>
#   event_bus barrier check <phase_id>
#   event_bus barrier wait <phase_id>
#   event_bus route <from_state>
#   event_bus status

set -uo pipefail
umask 077

VERSION="2.54.0"
EVENT_LOG="${HOME}/.ralph/events/event-log.jsonl"
SUBSCRIBERS_FILE="${HOME}/.ralph/events/subscribers.json"
PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/event-bus.log"

# v2.54: State Coordinator integration
STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"

mkdir -p "$(dirname "$EVENT_LOG")" "$(dirname "$LOG_FILE")" 2>/dev/null

# Initialize subscribers file if not exists
if [[ ! -f "$SUBSCRIBERS_FILE" ]]; then
    echo '{"subscribers":{}}' > "$SUBSCRIBERS_FILE"
fi

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# ============================================================================
# EVENT EMISSION
# ============================================================================

# Emit an event to the event bus
cmd_emit() {
    local event_type="${1:-}"
    local payload="${2:-{}}"
    local source="${3:-system}"

    if [[ -z "$event_type" ]]; then
        echo "Error: Event type required"
        echo "Usage: event_bus emit <event_type> [payload] [source]"
        return 1
    fi

    local timestamp event_id
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    event_id=$(date +%s%N | md5sum | cut -c1-16)

    # Validate payload is valid JSON
    if ! echo "$payload" | jq . >/dev/null 2>&1; then
        payload=$(echo "$payload" | jq -Rs '.')
    fi

    # Create event
    local event
    event=$(jq -nc \
        --arg id "$event_id" \
        --arg type "$event_type" \
        --arg ts "$timestamp" \
        --arg src "$source" \
        --argjson payload "$payload" \
        '{
            event_id: $id,
            type: $type,
            timestamp: $ts,
            source: $src,
            payload: $payload
        }')

    # Append to event log
    echo "$event" >> "$EVENT_LOG"

    log "Emitted event: $event_type ($event_id)"

    # Trigger subscribers
    trigger_subscribers "$event_type" "$event"

    echo "$event_id"
}

# ============================================================================
# EVENT SUBSCRIPTION
# ============================================================================

# Subscribe to an event type
cmd_subscribe() {
    local event_type="${1:-}"
    local handler="${2:-}"

    if [[ -z "$event_type" || -z "$handler" ]]; then
        echo "Error: Event type and handler required"
        echo "Usage: event_bus subscribe <event_type> <handler_script>"
        return 1
    fi

    # Add subscriber
    local subscribers
    subscribers=$(cat "$SUBSCRIBERS_FILE")
    echo "$subscribers" | jq \
        --arg type "$event_type" \
        --arg handler "$handler" \
        '.subscribers[$type] = (.subscribers[$type] // []) + [$handler] | .subscribers[$type] |= unique' \
        > "$SUBSCRIBERS_FILE.tmp" && mv "$SUBSCRIBERS_FILE.tmp" "$SUBSCRIBERS_FILE"

    log "Subscribed $handler to $event_type"
    echo "Subscribed: $handler -> $event_type"
}

# Unsubscribe from an event type
cmd_unsubscribe() {
    local event_type="${1:-}"
    local handler="${2:-}"

    if [[ -z "$event_type" || -z "$handler" ]]; then
        echo "Error: Event type and handler required"
        return 1
    fi

    local subscribers
    subscribers=$(cat "$SUBSCRIBERS_FILE")
    echo "$subscribers" | jq \
        --arg type "$event_type" \
        --arg handler "$handler" \
        '.subscribers[$type] = (.subscribers[$type] // [] | map(select(. != $handler)))' \
        > "$SUBSCRIBERS_FILE.tmp" && mv "$SUBSCRIBERS_FILE.tmp" "$SUBSCRIBERS_FILE"

    log "Unsubscribed $handler from $event_type"
    echo "Unsubscribed: $handler from $event_type"
}

# Trigger all subscribers for an event type
trigger_subscribers() {
    local event_type="$1"
    local event="$2"

    local handlers
    handlers=$(jq -r --arg type "$event_type" '.subscribers[$type] // [] | .[]' "$SUBSCRIBERS_FILE")

    for handler in $handlers; do
        if [[ -x "$handler" ]]; then
            log "Triggering handler: $handler"
            echo "$event" | "$handler" &
        else
            log "Handler not executable: $handler"
        fi
    done
}

# ============================================================================
# PHASE BARRIERS (WAIT-ALL Pattern)
# ============================================================================

# Check if a phase barrier is complete (all steps done)
cmd_barrier_check() {
    local phase_id="${1:-}"

    if [[ -z "$phase_id" ]]; then
        echo "Error: Phase ID required"
        echo "Usage: event_bus barrier check <phase_id>"
        return 1
    fi

    if [[ ! -f "$PLAN_STATE" ]]; then
        echo "Error: No plan-state.json found"
        return 1
    fi

    local plan_state
    plan_state=$(cat "$PLAN_STATE")

    # Check schema version
    local version
    version=$(echo "$plan_state" | jq -r '.version // "1.0"')

    if [[ ! "$version" =~ ^2\.5[1-9] ]]; then
        echo "Error: plan-state.json must be v2.51+ for barrier support"
        return 1
    fi

    # Get phase and its steps
    local phase step_ids steps_complete
    phase=$(echo "$plan_state" | jq -r --arg pid "$phase_id" '.phases[] | select(.phase_id == $pid)')

    if [[ -z "$phase" || "$phase" == "null" ]]; then
        echo "Error: Phase not found: $phase_id"
        return 1
    fi

    step_ids=$(echo "$phase" | jq -r '.step_ids[]')
    local total_steps=0
    local completed_steps=0

    for step_id in $step_ids; do
        ((total_steps++))
        local step_status
        step_status=$(echo "$plan_state" | jq -r --arg sid "$step_id" '.steps[$sid].status // "pending"')

        if [[ "$step_status" == "completed" || "$step_status" == "verified" ]]; then
            ((completed_steps++))
        fi
    done

    # Check if barrier is satisfied (WAIT-ALL)
    if [[ "$completed_steps" -eq "$total_steps" && "$total_steps" -gt 0 ]]; then
        echo '{"barrier_satisfied": true, "phase_id": "'"$phase_id"'", "completed": '"$completed_steps"', "total": '"$total_steps"'}'
        return 0
    else
        echo '{"barrier_satisfied": false, "phase_id": "'"$phase_id"'", "completed": '"$completed_steps"', "total": '"$total_steps"'}'
        return 1
    fi
}

# Wait for a phase barrier to be satisfied
cmd_barrier_wait() {
    local phase_id="${1:-}"
    local timeout="${2:-300}"  # 5 minutes default
    local poll_interval="${3:-5}"  # 5 seconds

    if [[ -z "$phase_id" ]]; then
        echo "Error: Phase ID required"
        return 1
    fi

    echo "Waiting for barrier: $phase_id (timeout: ${timeout}s)"

    local elapsed=0
    while [[ "$elapsed" -lt "$timeout" ]]; do
        local result
        result=$(cmd_barrier_check "$phase_id" 2>/dev/null)
        local satisfied
        satisfied=$(echo "$result" | jq -r '.barrier_satisfied // false')

        if [[ "$satisfied" == "true" ]]; then
            echo "Barrier satisfied: $phase_id"

            # Emit barrier completion event
            cmd_emit "barrier.complete" '{"phase_id": "'"$phase_id"'"}' "event-bus"

            # Update barriers in plan-state
            update_barrier_status "$phase_id" true

            return 0
        fi

        sleep "$poll_interval"
        elapsed=$((elapsed + poll_interval))
    done

    echo "Barrier timeout: $phase_id"
    return 1
}

# Update barrier status in plan-state.json
# v2.54: Use State Coordinator if available for unified state management
update_barrier_status() {
    local phase_id="$1"
    local status="$2"

    # v2.54: Prefer State Coordinator for atomic updates
    if [[ -x "$STATE_COORDINATOR" ]]; then
        if "$STATE_COORDINATOR" complete-barrier "$phase_id" 2>/dev/null; then
            log "Updated barrier via State Coordinator: $phase_id = $status"
            return 0
        else
            log "State Coordinator barrier update failed, falling back to direct update"
        fi
    fi

    # Fallback: Direct plan-state update
    if [[ ! -f "$PLAN_STATE" ]]; then
        return 1
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    jq --arg pid "$phase_id" \
       --argjson status "$status" \
       --arg ts "$timestamp" \
       '.barriers[$pid] = $status | .updated_at = $ts' \
       "$PLAN_STATE" > "$PLAN_STATE.tmp" && mv "$PLAN_STATE.tmp" "$PLAN_STATE"

    log "Updated barrier status (direct): $phase_id = $status"
}

# List all barriers and their status
cmd_barrier_list() {
    if [[ ! -f "$PLAN_STATE" ]]; then
        echo "Error: No plan-state.json found"
        return 1
    fi

    echo "=== Phase Barriers ==="
    echo ""

    local plan_state phases
    plan_state=$(cat "$PLAN_STATE")
    phases=$(echo "$plan_state" | jq -r '.phases[]? | @base64')

    for phase_b64 in $phases; do
        local phase phase_id phase_name status step_count completed_count
        phase=$(echo "$phase_b64" | base64 -d)
        phase_id=$(echo "$phase" | jq -r '.phase_id')
        phase_name=$(echo "$phase" | jq -r '.phase_name')
        status=$(echo "$phase" | jq -r '.status')

        # Get step completion
        local step_ids
        step_ids=$(echo "$phase" | jq -r '.step_ids[]' 2>/dev/null)
        step_count=0
        completed_count=0

        for step_id in $step_ids; do
            ((step_count++))
            local step_status
            step_status=$(echo "$plan_state" | jq -r --arg sid "$step_id" '.steps[$sid].status // "pending"')
            if [[ "$step_status" == "completed" || "$step_status" == "verified" ]]; then
                ((completed_count++))
            fi
        done

        # Get barrier status
        local barrier_status
        barrier_status=$(echo "$plan_state" | jq -r --arg pid "$phase_id" '.barriers[$pid] // false')

        # Display
        local barrier_icon="⏳"
        [[ "$barrier_status" == "true" ]] && barrier_icon="✅"

        echo "$barrier_icon $phase_name ($phase_id)"
        echo "   Status: $status"
        echo "   Steps: $completed_count/$step_count complete"
        echo "   Barrier: $barrier_status"
        echo ""
    done
}

# ============================================================================
# DYNAMIC ROUTING
# ============================================================================

# Determine next phase/agent based on current state
cmd_route() {
    local from_state="${1:-current}"

    if [[ ! -f "$PLAN_STATE" ]]; then
        echo "Error: No plan-state.json found"
        return 1
    fi

    local plan_state
    plan_state=$(cat "$PLAN_STATE")

    # Get current phase
    local current_phase
    current_phase=$(echo "$plan_state" | jq -r '.current_phase // null')

    if [[ "$current_phase" == "null" || -z "$current_phase" ]]; then
        # Start with first phase
        local first_phase
        first_phase=$(echo "$plan_state" | jq -r '.phases[0].phase_id // null')

        if [[ "$first_phase" != "null" ]]; then
            echo '{"action": "start", "phase_id": "'"$first_phase"'"}'
            return 0
        else
            echo '{"action": "error", "message": "No phases defined"}'
            return 1
        fi
    fi

    # Check if current phase is complete
    local barrier_result
    barrier_result=$(cmd_barrier_check "$current_phase" 2>/dev/null)
    local barrier_satisfied
    barrier_satisfied=$(echo "$barrier_result" | jq -r '.barrier_satisfied // false')

    if [[ "$barrier_satisfied" == "true" ]]; then
        # Find next phase
        local phases_json next_phase_id
        phases_json=$(echo "$plan_state" | jq -r '[.phases[].phase_id]')

        # Find current phase index and get next
        local current_index=-1 i=0
        for pid in $(echo "$phases_json" | jq -r '.[]'); do
            if [[ "$pid" == "$current_phase" ]]; then
                current_index=$i
                break
            fi
            ((i++))
        done

        if [[ "$current_index" -ge 0 ]]; then
            next_phase_id=$(echo "$phases_json" | jq -r ".[$((current_index + 1))] // null")

            if [[ "$next_phase_id" != "null" ]]; then
                # Check if next phase depends on other phases
                local depends_on
                depends_on=$(echo "$plan_state" | jq -r \
                    --arg pid "$next_phase_id" \
                    '.phases[] | select(.phase_id == $pid) | .depends_on // [] | .[]')

                local all_deps_satisfied=true
                for dep_phase in $depends_on; do
                    local dep_barrier
                    dep_barrier=$(echo "$plan_state" | jq -r --arg pid "$dep_phase" '.barriers[$pid] // false')
                    if [[ "$dep_barrier" != "true" ]]; then
                        all_deps_satisfied=false
                        break
                    fi
                done

                if [[ "$all_deps_satisfied" == "true" ]]; then
                    echo '{"action": "advance", "from": "'"$current_phase"'", "to": "'"$next_phase_id"'"}'
                else
                    echo '{"action": "wait", "phase_id": "'"$next_phase_id"'", "waiting_for": "dependencies"}'
                fi
            else
                echo '{"action": "complete", "message": "All phases complete"}'
            fi
        fi
    else
        # Still working on current phase
        local completed total
        completed=$(echo "$barrier_result" | jq -r '.completed')
        total=$(echo "$barrier_result" | jq -r '.total')

        echo '{"action": "continue", "phase_id": "'"$current_phase"'", "progress": "'"$completed"'/'"$total"'"}'
    fi
}

# Advance to next phase (update plan-state)
# v2.54: Use State Coordinator for unified state management
cmd_advance() {
    local next_phase="${1:-}"

    if [[ -z "$next_phase" ]]; then
        # Auto-determine next phase
        local route_result
        route_result=$(cmd_route)
        local action
        action=$(echo "$route_result" | jq -r '.action')

        if [[ "$action" == "advance" ]]; then
            next_phase=$(echo "$route_result" | jq -r '.to')
        else
            echo "Cannot advance: $route_result"
            return 1
        fi
    fi

    # v2.54: Prefer State Coordinator for atomic phase updates
    if [[ -x "$STATE_COORDINATOR" ]]; then
        if "$STATE_COORDINATOR" set-phase "$next_phase" 2>/dev/null; then
            # Emit phase start event
            cmd_emit "phase.start" '{"phase_id": "'"$next_phase"'"}' "event-bus"
            log "Advanced to phase via State Coordinator: $next_phase"
            echo "Advanced to phase: $next_phase"
            return 0
        else
            log "State Coordinator advance failed, falling back to direct update"
        fi
    fi

    # Fallback: Direct plan-state update
    if [[ ! -f "$PLAN_STATE" ]]; then
        return 1
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Update current phase and phase status
    jq --arg pid "$next_phase" \
       --arg ts "$timestamp" \
       '.current_phase = $pid |
        .updated_at = $ts |
        (.phases[] | select(.phase_id == $pid)).status = "in_progress" |
        (.phases[] | select(.phase_id == $pid)).started_at = $ts' \
       "$PLAN_STATE" > "$PLAN_STATE.tmp" && mv "$PLAN_STATE.tmp" "$PLAN_STATE"

    # Emit phase start event
    cmd_emit "phase.start" '{"phase_id": "'"$next_phase"'"}' "event-bus"

    log "Advanced to phase (direct): $next_phase"
    echo "Advanced to phase: $next_phase"
}

# ============================================================================
# STATUS AND HISTORY
# ============================================================================

# Show event bus status
cmd_status() {
    echo "=== Event Bus Status ==="
    echo ""

    # Event log stats
    if [[ -f "$EVENT_LOG" ]]; then
        local total_events recent_events
        total_events=$(wc -l < "$EVENT_LOG" | tr -d ' ')
        recent_events=$(tail -10 "$EVENT_LOG" 2>/dev/null | wc -l | tr -d ' ')

        echo "Event Log:"
        echo "  Total events: $total_events"
        echo "  Location: $EVENT_LOG"
        echo ""

        echo "Recent Events (last 10):"
        tail -10 "$EVENT_LOG" 2>/dev/null | while read -r line; do
            local type ts
            type=$(echo "$line" | jq -r '.type')
            ts=$(echo "$line" | jq -r '.timestamp')
            echo "  - $ts: $type"
        done
    else
        echo "Event Log: Not initialized"
    fi

    echo ""

    # Subscribers
    echo "Subscribers:"
    if [[ -f "$SUBSCRIBERS_FILE" ]]; then
        jq -r '.subscribers | to_entries[] | "  \(.key): \(.value | length) handlers"' "$SUBSCRIBERS_FILE"
    else
        echo "  None"
    fi

    echo ""

    # Plan state summary
    if [[ -f "$PLAN_STATE" ]]; then
        local version current_phase phases_count
        version=$(jq -r '.version // "unknown"' "$PLAN_STATE")
        current_phase=$(jq -r '.current_phase // "none"' "$PLAN_STATE")
        phases_count=$(jq -r '.phases | length' "$PLAN_STATE")

        echo "Plan State:"
        echo "  Version: $version"
        echo "  Current Phase: $current_phase"
        echo "  Total Phases: $phases_count"
    else
        echo "Plan State: Not found"
    fi
}

# Show event history
cmd_history() {
    local count="${1:-20}"
    local event_type="${2:-}"

    if [[ ! -f "$EVENT_LOG" ]]; then
        echo "No event history"
        return 0
    fi

    echo "=== Event History (last $count) ==="
    echo ""

    if [[ -n "$event_type" ]]; then
        grep "\"type\":\"$event_type\"" "$EVENT_LOG" | tail -"$count" | jq '.'
    else
        tail -"$count" "$EVENT_LOG" | jq '.'
    fi
}

# ============================================================================
# MAIN ENTRY POINT
# ============================================================================

event_bus() {
    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        emit)           cmd_emit "$@" ;;
        subscribe)      cmd_subscribe "$@" ;;
        unsubscribe)    cmd_unsubscribe "$@" ;;
        barrier)
            local subcmd="${1:-}"
            shift 2>/dev/null || true
            case "$subcmd" in
                check)  cmd_barrier_check "$@" ;;
                wait)   cmd_barrier_wait "$@" ;;
                list)   cmd_barrier_list "$@" ;;
                *)
                    echo "Usage: event_bus barrier <check|wait|list> [args]"
                    return 1
                    ;;
            esac
            ;;
        route)          cmd_route "$@" ;;
        advance)        cmd_advance "$@" ;;
        status)         cmd_status "$@" ;;
        history)        cmd_history "$@" ;;
        version)        echo "event-bus.sh v$VERSION" ;;
        help|"")
            echo "Event Bus - v$VERSION"
            echo "(v2.54: Integrated with State Coordinator for unified state management)"
            echo ""
            echo "Usage: event_bus <command> [args]"
            echo ""
            echo "Event Commands:"
            echo "  emit <type> [payload] [source]  Emit an event"
            echo "  subscribe <type> <handler>      Subscribe to event type"
            echo "  unsubscribe <type> <handler>    Unsubscribe from event type"
            echo ""
            echo "Barrier Commands:"
            echo "  barrier check <phase_id>        Check if barrier is satisfied"
            echo "  barrier wait <phase_id> [timeout] Wait for barrier (WAIT-ALL)"
            echo "  barrier list                    List all barriers and status"
            echo ""
            echo "Routing Commands:"
            echo "  route [from_state]              Determine next phase/action"
            echo "  advance [phase_id]              Advance to next/specified phase"
            echo ""
            echo "Status Commands:"
            echo "  status                          Show event bus status"
            echo "  history [count] [type]          Show event history"
            echo ""
            echo "Event Types:"
            echo "  barrier.complete                Phase barrier satisfied"
            echo "  phase.start                     Phase started"
            echo "  phase.complete                  Phase completed"
            echo "  step.complete                   Step completed"
            echo "  handoff.transfer                Agent handoff"
            echo ""
            echo "Examples:"
            echo "  event_bus emit step.complete '{\"step_id\": \"step1\"}'"
            echo "  event_bus barrier check phase-1"
            echo "  event_bus route"
            ;;
        *)
            echo "Unknown command: $cmd"
            echo "Run 'event_bus help' for usage"
            return 1
            ;;
    esac
}

# If script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    event_bus "$@"
fi
