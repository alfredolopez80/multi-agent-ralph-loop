#!/bin/bash
# glm-context-tracker.sh - Track GLM-4.7 API context usage
# VERSION: 2.0.0 (FIX-CRIT-007: Project-specific state tracking)
# Compatible with jq 1.6+ (removed --argfile)

set -euo pipefail

# Configuration
HOOKS_DIR="${HOME}/.claude/hooks"
PROJECT_STATE="${HOOKS_DIR}/project-state.sh"

# Get project-specific state directory
# Falls back to global state if project-state.sh is not available
if [[ -f "$PROJECT_STATE" ]]; then
    STATE_DIR=$("$PROJECT_STATE" get-dir 2>/dev/null || echo "${RALPH_DIR:-$HOME/.ralph}/state")
else
    STATE_DIR="${RALPH_DIR:-$HOME/.ralph}/state"
fi

# Constants
GLM_CONTEXT_WINDOW=128000  # GLM-4.7 context window
CONTEXT_FILE="${STATE_DIR}/glm-context.json"
LOCK_FILE="${STATE_DIR}/glm-context.lock"
PERCENTAGE_UTILS="${HOME}/.ralph/lib/percentage-utils.sh"

# Source shared percentage utilities if available
if [[ -f "$PERCENTAGE_UTILS" ]]; then
    # shellcheck source=/dev/null
    source "$PERCENTAGE_UTILS"
fi

# Ensure state directory exists
mkdir -p "$STATE_DIR"

# Acquire lock for thread safety
# HIGH PRIORITY FIX #5: Stale lock cleanup + improved lock mechanism
acquire_lock() {
    local timeout=5
    local count=0

    # Check for stale lock (older than 10 seconds)
    if [[ -f "$LOCK_FILE" ]]; then
        local current_time=$(date +%s)
        local lock_time=0
        # macOS stat format vs Linux
        if [[ "$(uname)" == "Darwin" ]]; then
            lock_time=$(stat -f%m "$LOCK_FILE" 2>/dev/null || echo 0)
        else
            lock_time=$(stat -c%Y "$LOCK_FILE" 2>/dev/null || echo 0)
        fi
        local lock_age=$((current_time - lock_time))

        if [[ $lock_age -gt 10 ]]; then
            echo "WARN: Removing stale lock (${lock_age}s old)" >&2
            rm -f "$LOCK_FILE" 2>/dev/null || true
        fi
    fi

    # Try to acquire lock using mkdir for atomicity
    while [[ $count -lt $timeout ]]; do
        if mkdir "$LOCK_FILE.dir" 2>/dev/null; then
            # Successfully acquired lock
            echo $$ > "$LOCK_FILE"
            return 0
        fi
        sleep 0.2
        count=$((count + 1))
    done

    echo "ERROR: Could not acquire lock for GLM context tracking after ${timeout}s" >&2
    return 1
}

release_lock() {
    rm -f "$LOCK_FILE" "$LOCK_FILE.dir" 2>/dev/null || true
}

# Initialize context file
init_context() {
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        jq -n \
            --argjson window "$GLM_CONTEXT_WINDOW" \
            '{
                total_tokens: 0,
                context_window: $window,
                percentage: 0,
                last_updated: null,
                session_start: (now | todate),
                message_count: 0
            }' > "$CONTEXT_FILE"
    fi
}

# Add tokens from API call
add_tokens() {
    local input_tokens="$1"
    local output_tokens="${2:-0}"

    # CRITICAL FIX #2: Input validation (HIGH PRIORITY #6)
    # Validate input tokens are numeric
    if ! [[ "$input_tokens" =~ ^[0-9]+$ ]] || ! [[ "$output_tokens" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid token values: input=${input_tokens}, output=${output_tokens}" >&2
        return 1
    fi

    acquire_lock || return 1

    # CRITICAL FIX #2: Ensure lock is released on error or exit
    trap 'release_lock' ERR EXIT

    init_context

    # Read current context and update
    local new_total=$(jq --arg input "$input_tokens" --arg output "$output_tokens" \
        '(.total_tokens + ($input | tonumber) + ($output | tonumber))' \
        "$CONTEXT_FILE")

    # HIGH PRIORITY FIX #8: Use shared percentage calculation
    local new_pct_int
    if declare -f calculate_token_percentage >/dev/null 2>&1; then
        new_pct_int=$(calculate_token_percentage "$new_total" "$GLM_CONTEXT_WINDOW")
    else
        # Fallback to local calculation
        local new_pct=$(echo "scale=2; $new_total * 100 / $GLM_CONTEXT_WINDOW" | bc)
        new_pct_int=${new_pct%.*}
    fi

    # Read current values for update
    local current_msg_count=$(jq -r '.message_count // 0' "$CONTEXT_FILE")
    local new_msg_count=$((current_msg_count + 1))

    # Update context file
    jq \
        --argjson total "$new_total" \
        --argjson percentage "$new_pct_int" \
        --argjson msg_count "$new_msg_count" \
        '{
            total_tokens: $total,
            context_window: .context_window,
            percentage: $percentage,
            last_updated: (now | todate),
            session_start: .session_start,
            message_count: $msg_count
        }' "$CONTEXT_FILE" > "${CONTEXT_FILE}.tmp"

    mv "${CONTEXT_FILE}.tmp" "$CONTEXT_FILE"

    # CRITICAL FIX #2: Clear trap and release lock on success
    trap - ERR EXIT
    release_lock

    echo "$new_pct_int"
    return 0
}

# Get current context percentage
get_percentage() {
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        echo "0"
        return 0
    fi

    jq -r '.percentage // 0' "$CONTEXT_FILE"
}

# Get full context info
get_context_info() {
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        jq -n '{percentage: 0, total_tokens: 0, context_window: 128000}'
        return 0
    fi

    cat "$CONTEXT_FILE"
}

# Reset context (for new session)
reset_context() {
    acquire_lock || return 1

    jq -n \
        --argjson window "$GLM_CONTEXT_WINDOW" \
        '{
            total_tokens: 0,
            context_window: $window,
            percentage: 0,
            last_updated: null,
            session_start: (now | todate),
            message_count: 0
        }' > "$CONTEXT_FILE"

    release_lock
    return 0
}

# Estimate from response (when exact token count not available)
estimate_from_response() {
    local response_length="$1"  # Length in characters

    # Rough estimate: ~4 characters per token
    local estimated_tokens=$((response_length / 4))

    add_tokens "$estimated_tokens" 0
}

# Main command dispatcher
case "${1:-}" in
    init)
        init_context
        ;;
    add)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 add <input_tokens> [output_tokens]" >&2
            exit 1
        fi
        add_tokens "$2" "${3:-0}"
        ;;
    estimate)
        if [[ $# -lt 2 ]]; then
            echo "Usage: $0 estimate <response_length>" >&2
            exit 1
        fi
        estimate_from_response "$2"
        ;;
    get-percentage|--percent|-p)
        get_percentage
        ;;
    get-info|--info|-i)
        get_context_info
        ;;
    reset|--reset|-r)
        reset_context
        ;;
    *)
        echo "Usage: $0 {init|add|estimate|get-percentage|get-info|reset}" >&2
        exit 1
        ;;
esac

exit 0
