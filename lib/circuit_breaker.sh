#!/usr/bin/env bash
# lib/circuit_breaker.sh - Loop execution safeguard
# Adapted from frankbria/ralph-claude-code's circuit breaker pattern
# (Michael Nygard's "Release It!" pattern)
#
# Prevents runaway loops by detecting stagnation:
# - No progress (no file changes) for N iterations → HALF_OPEN → OPEN
# - Same error repeated N times → OPEN
# - Permission denials N times → OPEN
#
# States: CLOSED (normal) → HALF_OPEN (monitoring) → OPEN (halted)
#
# Usage:
#   source lib/circuit_breaker.sh
#   cb_init
#   for i in $(seq 1 $MAX_LOOPS); do
#       cb_can_execute || break
#       # ... do work ...
#       cb_record_result "$i" "$files_changed" "$has_errors"
#   done

[[ -n "${_RALPH_LIB_CIRCUIT_BREAKER_LOADED:-}" ]] && return 0
_RALPH_LIB_CIRCUIT_BREAKER_LOADED=1

# States
CB_CLOSED="CLOSED"
CB_HALF_OPEN="HALF_OPEN"
CB_OPEN="OPEN"

# Configuration (overridable via .ralphrc or environment)
CB_NO_PROGRESS_THRESHOLD="${CB_NO_PROGRESS_THRESHOLD:-3}"
CB_SAME_ERROR_THRESHOLD="${CB_SAME_ERROR_THRESHOLD:-5}"
CB_COOLDOWN_MINUTES="${CB_COOLDOWN_MINUTES:-30}"
CB_AUTO_RESET="${CB_AUTO_RESET:-false}"

# State storage
CB_STATE_DIR="${RALPH_HOME:-${HOME}/.ralph}/state"
CB_STATE_FILE="${CB_STATE_DIR}/circuit_breaker.json"

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════
cb_init() {
    mkdir -p "$CB_STATE_DIR"

    if [[ ! -f "$CB_STATE_FILE" ]] || ! jq '.' "$CB_STATE_FILE" &>/dev/null; then
        cb_reset "Initial state"
    fi

    # Auto-recovery from OPEN state
    local state
    state=$(jq -r '.state' "$CB_STATE_FILE" 2>/dev/null || echo "$CB_CLOSED")

    if [[ "$state" == "$CB_OPEN" ]]; then
        if [[ "$CB_AUTO_RESET" == "true" ]]; then
            cb_reset "Auto-reset on startup (CB_AUTO_RESET=true)"
        else
            # Check cooldown
            local opened_at elapsed
            opened_at=$(jq -r '.opened_at // ""' "$CB_STATE_FILE" 2>/dev/null)
            if [[ -n "$opened_at" && "$opened_at" != "null" ]]; then
                local opened_epoch
                opened_epoch=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$opened_at" +%s 2>/dev/null || date -d "$opened_at" +%s 2>/dev/null || echo "0")
                elapsed=$(( ($(date +%s) - opened_epoch) / 60 ))
                if [[ $elapsed -ge $CB_COOLDOWN_MINUTES ]]; then
                    _cb_transition "$CB_OPEN" "$CB_HALF_OPEN" "Cooldown elapsed (${elapsed}m >= ${CB_COOLDOWN_MINUTES}m)"
                fi
            fi
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# QUERY STATE
# ═══════════════════════════════════════════════════════════════════════════════
cb_state() {
    jq -r '.state' "$CB_STATE_FILE" 2>/dev/null || echo "$CB_CLOSED"
}

cb_can_execute() {
    local state
    state=$(cb_state)
    [[ "$state" != "$CB_OPEN" ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# RECORD LOOP RESULT
# ═══════════════════════════════════════════════════════════════════════════════
cb_record_result() {
    local loop_number="${1:-0}"
    local files_changed="${2:-0}"
    local has_errors="${3:-false}"

    local data
    data=$(cat "$CB_STATE_FILE")
    local current_state no_progress same_error
    current_state=$(echo "$data" | jq -r '.state')
    no_progress=$(echo "$data" | jq -r '.consecutive_no_progress // 0')
    same_error=$(echo "$data" | jq -r '.consecutive_same_error // 0')

    # Detect progress
    local has_progress=false
    if [[ "$files_changed" -gt 0 ]]; then
        has_progress=true
        no_progress=0
    else
        no_progress=$((no_progress + 1))
    fi

    # Track repeated errors
    if [[ "$has_errors" == "true" ]]; then
        same_error=$((same_error + 1))
    else
        same_error=0
    fi

    # State transitions
    local new_state="$current_state"
    local reason=""

    case "$current_state" in
        "$CB_CLOSED")
            if [[ $no_progress -ge $CB_NO_PROGRESS_THRESHOLD ]]; then
                new_state="$CB_OPEN"
                reason="No progress in $no_progress consecutive loops"
            elif [[ $same_error -ge $CB_SAME_ERROR_THRESHOLD ]]; then
                new_state="$CB_OPEN"
                reason="Same error repeated $same_error times"
            elif [[ $no_progress -ge 2 ]]; then
                new_state="$CB_HALF_OPEN"
                reason="Monitoring: $no_progress loops without progress"
            fi
            ;;
        "$CB_HALF_OPEN")
            if [[ "$has_progress" == "true" ]]; then
                new_state="$CB_CLOSED"
                reason="Progress detected, recovered"
            elif [[ $no_progress -ge $CB_NO_PROGRESS_THRESHOLD ]]; then
                new_state="$CB_OPEN"
                reason="No recovery after $no_progress loops"
            fi
            ;;
        "$CB_OPEN")
            reason="Circuit open, execution halted"
            ;;
    esac

    # Compute opened_at
    local opened_at=""
    if [[ "$new_state" == "$CB_OPEN" && "$current_state" != "$CB_OPEN" ]]; then
        opened_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    elif [[ "$new_state" == "$CB_OPEN" ]]; then
        opened_at=$(echo "$data" | jq -r '.opened_at // ""')
    fi

    local total_opens
    total_opens=$(echo "$data" | jq -r '.total_opens // 0')
    [[ "$new_state" == "$CB_OPEN" && "$current_state" != "$CB_OPEN" ]] && total_opens=$((total_opens + 1))

    # Write state
    jq -n \
        --arg state "$new_state" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --argjson no_progress "$no_progress" \
        --argjson same_error "$same_error" \
        --argjson loop "$loop_number" \
        --argjson total_opens "$total_opens" \
        --arg reason "$reason" \
        --arg opened_at "$opened_at" \
        '{state: $state, last_change: $ts, consecutive_no_progress: $no_progress,
          consecutive_same_error: $same_error, current_loop: $loop,
          total_opens: $total_opens, reason: $reason, opened_at: $opened_at}' \
        > "$CB_STATE_FILE"

    # Log transition
    if [[ "$new_state" != "$current_state" ]]; then
        _cb_transition "$current_state" "$new_state" "$reason"
    fi

    [[ "$new_state" != "$CB_OPEN" ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# RESET
# ═══════════════════════════════════════════════════════════════════════════════
cb_reset() {
    local reason="${1:-Manual reset}"
    mkdir -p "$CB_STATE_DIR"
    jq -n \
        --arg state "$CB_CLOSED" \
        --arg ts "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg reason "$reason" \
        '{state: $state, last_change: $ts, consecutive_no_progress: 0,
          consecutive_same_error: 0, current_loop: 0, total_opens: 0,
          reason: $reason, opened_at: ""}' \
        > "$CB_STATE_FILE"
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATUS DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════
cb_status() {
    [[ -f "$CB_STATE_FILE" ]] || { echo "Circuit breaker not initialized"; return; }

    local data state reason no_progress loop total_opens
    data=$(cat "$CB_STATE_FILE")
    state=$(echo "$data" | jq -r '.state')
    reason=$(echo "$data" | jq -r '.reason')
    no_progress=$(echo "$data" | jq -r '.consecutive_no_progress')
    loop=$(echo "$data" | jq -r '.current_loop // "N/A"')
    total_opens=$(echo "$data" | jq -r '.total_opens')

    local color icon
    case "$state" in
        "$CB_CLOSED")    color="${GREEN:-}"; icon="OK" ;;
        "$CB_HALF_OPEN") color="${YELLOW:-}"; icon="MONITORING" ;;
        "$CB_OPEN")      color="${RED:-}"; icon="HALTED" ;;
    esac

    echo -e "${color}Circuit Breaker: ${icon} (${state})${NC:-}"
    echo "  Reason:              $reason"
    echo "  Loops since progress: $no_progress"
    echo "  Current loop:        #$loop"
    echo "  Total opens:         $total_opens"
}

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════
_cb_transition() {
    local from="$1" to="$2" reason="$3"
    case "$to" in
        "$CB_OPEN")
            echo -e "${RED:-}CIRCUIT BREAKER OPENED${NC:-}"
            echo -e "${RED:-}Reason: $reason${NC:-}" ;;
        "$CB_HALF_OPEN")
            echo -e "${YELLOW:-}CIRCUIT BREAKER: Monitoring${NC:-}"
            echo -e "${YELLOW:-}Reason: $reason${NC:-}" ;;
        "$CB_CLOSED")
            echo -e "${GREEN:-}CIRCUIT BREAKER: Normal${NC:-}"
            echo -e "${GREEN:-}Reason: $reason${NC:-}" ;;
    esac
}
