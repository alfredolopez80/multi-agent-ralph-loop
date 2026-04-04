#!/usr/bin/env bash
# glm-context-update.sh - GLM-4.7 context tracking and update (consolidated)
# VERSION: 3.0.0 (Consolidated from glm-context-update.sh + glm-context-tracker.sh)
# Hook: PostToolUse (Edit|Write|Bash)
# Purpose: Track GLM context usage with estimated tokens from operations
#          AND provide CLI interface for context queries (init/add/get/reset)
#
# This hook estimates token usage based on operation size and updates
# the glm-context.json file that claude-hud reads for display.
# It also serves as the standalone GLM context tracker (replacing glm-context-tracker.sh).
#
# CLI Usage (standalone):
#   ./glm-context-update.sh init                    # Initialize context file
#   ./glm-context-update.sh add <input> [output]    # Add token counts
#   ./glm-context-update.sh estimate <response_len> # Estimate from char length
#   ./glm-context-update.sh get-percentage           # Get current context %
#   ./glm-context-update.sh get-info                 # Get full context JSON
#   ./glm-context-update.sh reset                    # Reset for new session
#
# Hook Usage (PostToolUse):
#   Reads JSON from stdin, estimates tokens, updates context file.
#   Output: {"continue": true} (PostToolUse JSON format)

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

HOOKS_DIR="${HOME}/.claude/hooks"
PROJECT_STATE="${HOOKS_DIR}/project-state.sh"

# Get project-specific state directory
if [[ -f "$PROJECT_STATE" ]]; then
    STATE_DIR=$("$PROJECT_STATE" get-dir 2>/dev/null || echo "${RALPH_DIR:-${HOME}/.ralph}/state")
else
    STATE_DIR="${RALPH_DIR:-${HOME}/.ralph}/state"
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

# =============================================================================
# LOCKING (thread safety)
# =============================================================================

# Acquire lock for thread safety (stale lock cleanup + mkdir atomicity)
acquire_lock() {
    local timeout=5
    local count=0

    # Check for stale lock (older than 10 seconds)
    if [[ -f "$LOCK_FILE" ]]; then
        local current_time lock_time lock_age
        current_time=$(date +%s)
        if [[ "$(uname)" == "Darwin" ]]; then
            lock_time=$(stat -f%m "$LOCK_FILE" 2>/dev/null || echo 0)
        else
            lock_time=$(stat -c%Y "$LOCK_FILE" 2>/dev/null || echo 0)
        fi
        lock_age=$((current_time - lock_time))

        if [[ $lock_age -gt 10 ]]; then
            echo "WARN: Removing stale lock (${lock_age}s old)" >&2
            rm -f "$LOCK_FILE" 2>/dev/null || true
            rmdir "$LOCK_FILE.dir" 2>/dev/null || true
        fi
    fi

    # Try to acquire lock using mkdir for atomicity
    while [[ $count -lt $timeout ]]; do
        if mkdir "$LOCK_FILE.dir" 2>/dev/null; then
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

# =============================================================================
# CONTEXT TRACKING (merged from glm-context-tracker.sh)
# =============================================================================

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

    # Input validation: must be numeric
    if ! [[ "$input_tokens" =~ ^[0-9]+$ ]] || ! [[ "$output_tokens" =~ ^[0-9]+$ ]]; then
        echo "ERROR: Invalid token values: input=${input_tokens}, output=${output_tokens}" >&2
        return 1
    fi

    acquire_lock || return 1
    trap 'release_lock' ERR EXIT

    init_context

    # Read current context and update
    local new_total
    new_total=$(jq --arg input "$input_tokens" --arg output "$output_tokens" \
        '(.total_tokens + ($input | tonumber) + ($output | tonumber))' \
        "$CONTEXT_FILE")

    # Use shared percentage calculation or fallback
    local new_pct_int
    if declare -f calculate_token_percentage >/dev/null 2>&1; then
        new_pct_int=$(calculate_token_percentage "$new_total" "$GLM_CONTEXT_WINDOW")
    else
        local new_pct
        new_pct=$(echo "scale=2; $new_total * 100 / $GLM_CONTEXT_WINDOW" | bc)
        new_pct_int=${new_pct%.*}
    fi

    local current_msg_count new_msg_count
    current_msg_count=$(jq -r '.message_count // 0' "$CONTEXT_FILE")
    new_msg_count=$((current_msg_count + 1))

    # Update context file atomically
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
    local response_length="$1"
    # Rough estimate: ~4 characters per token
    local estimated_tokens=$((response_length / 4))
    add_tokens "$estimated_tokens" 0
}

# =============================================================================
# TOKEN ESTIMATION (PostToolUse operation estimation)
# =============================================================================

# Estimate tokens from operation type and content
estimate_tokens() {
    local tool_name="$1"
    local tool_input="$2"
    local tool_result="$3"
    local estimated_tokens=0

    case "$tool_name" in
        Edit|Write)
            local content=""
            if [[ "$tool_name" == "Edit" ]]; then
                content=$(echo "$tool_input" | jq -r '.new_text // ""' 2>/dev/null || echo "")
            else
                content=$(echo "$tool_input" | jq -r '.content // ""' 2>/dev/null || echo "")
            fi
            local char_count=${#content}
            estimated_tokens=$((char_count / 4))
            ;;
        Bash)
            local command
            command=$(echo "$tool_input" | jq -r '.command // ""' 2>/dev/null || echo "")
            local output_len=${#tool_result}
            estimated_tokens=$(((${#command} + output_len) / 4))
            ;;
        Task)
            local prompt
            prompt=$(echo "$tool_input" | jq -r '.prompt // ""' 2>/dev/null || echo "")
            estimated_tokens=$((${#prompt} / 2))
            ;;
        *)
            estimated_tokens=100
            ;;
    esac

    # Clamp: minimum 100, maximum 10000 tokens per operation
    if [[ $estimated_tokens -lt 100 ]]; then
        estimated_tokens=100
    elif [[ $estimated_tokens -gt 10000 ]]; then
        estimated_tokens=10000
    fi

    echo "$estimated_tokens"
}

# =============================================================================
# HOOK MODE (PostToolUse handler)
# =============================================================================

run_hook_mode() {
    # SEC-111: Read input from stdin with length limit (100KB max)
    local INPUT
    INPUT=$(head -c 100000)

    # Error trap: Always output valid JSON for PostToolUse
    trap 'echo "{\"continue\": true}"' ERR EXIT

    # Parse input
    local TOOL_NAME TOOL_INPUT TOOL_RESULT
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
    TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")
    TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // ""' 2>/dev/null || echo "")

    # Only track relevant operations
    case "$TOOL_NAME" in
        Edit|Write|Bash|Task)
            local ESTIMATED_TOKENS
            ESTIMATED_TOKENS=$(estimate_tokens "$TOOL_NAME" "$TOOL_INPUT" "$TOOL_RESULT")
            if [[ "$ESTIMATED_TOKENS" -gt 0 ]]; then
                add_tokens "$ESTIMATED_TOKENS" 0 >/dev/null 2>&1 || true
            fi
            ;;
        *)
            # Skip other tools
            ;;
    esac

    # Clear trap and output success
    trap - ERR EXIT
    echo '{"continue": true}'
}

# =============================================================================
# MAIN DISPATCH
# =============================================================================

case "${1:-__hook__}" in
    __hook__)
        # Default: run as PostToolUse hook (reads stdin)
        run_hook_mode
        ;;
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
        echo "  (no args = PostToolUse hook mode, reads JSON from stdin)" >&2
        exit 1
        ;;
esac

exit 0
