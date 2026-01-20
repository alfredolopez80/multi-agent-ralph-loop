#!/bin/bash
# ~/.claude/hooks/context-warning.sh
# Context Monitoring Hook - v2.44
# Executed on every user-prompt-submit to monitor context usage
#
# v2.44 IMPROVEMENTS:
#   - Environment detection for CLI vs VSCode/Cursor
#   - Improved fallback estimation for extensions (GitHub #15021)
#   - Operation counter for extensions where /context command fails

# Note: Not using set -e because this is a non-blocking hook
# Errors should not interrupt the main workflow
# VERSION: 2.57.0
# v2.47: Adjusted thresholds for proactive compaction (75%/85%)
#        Fixed message_count path to STATE_DIR
set -uo pipefail

# Configuration
THRESHOLD=75
CRITICAL_THRESHOLD=85
LOG_FILE="${HOME}/.ralph/context-monitor.log"
RALPH_DIR="${HOME}/.ralph"
HOOKS_DIR="${HOME}/.claude/hooks"
FEATURES_FILE="${HOME}/.ralph/config/features.json"

# Ensure directories exist (ignore errors)
mkdir -p "$RALPH_DIR" "$(dirname "$LOG_FILE" 2>/dev/null)" || true

# Source environment detection (v2.44)
ENV_TYPE="unknown"
CAPABILITIES="limited"
if [[ -f "${HOOKS_DIR}/detect-environment.sh" ]]; then
    # shellcheck source=/dev/null
    source "${HOOKS_DIR}/detect-environment.sh"
    ENV_TYPE=$(get_env_type 2>/dev/null || echo "unknown")
    CAPABILITIES=$(get_capabilities 2>/dev/null || echo "limited")
fi

# Get timestamp
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Log function (ignore errors to prevent blocking)
log_context() {
    local level="$1"
    local message="$2"
    echo "[$(timestamp)] Context: ${message}" >> "$LOG_FILE" 2>/dev/null || true
}

# Safe numeric validation
is_numeric() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]]
}

# Get context usage percentage
# Returns integer percentage (0-100)
# v2.44: Uses environment detection for better fallback in extensions
get_context_percentage() {
    local pct=""

    # Method 1: Try native CLI command (works in full CLI mode)
    if [[ "$CAPABILITIES" == "full" ]]; then
        local context_output
        context_output=$(claude --print "/context" 2>/dev/null || echo "unknown")

        # Parse percentage from output - support decimals: NN% or N.N%
        if [[ "$context_output" =~ ([0-9]+\.?[0-9]*)% ]]; then
            pct="${BASH_REMATCH[1]}"
        fi
    fi

    # Method 2: Fallback for extensions (VSCode/Cursor) - operation counter
    if [[ -z "$pct" ]]; then
        # Use operation counter for estimation
        local ops
        ops=$(cat "${RALPH_DIR}/state/operation-counter" 2>/dev/null || echo "0")
        if ! is_numeric "$ops"; then
            ops=0
        fi

        # v2.44: Improved estimation based on tool operations
        # Each tool call ~0.25%, each message ~2%
        local message_count
        message_count=$(cat "${RALPH_DIR}/state/message_count" 2>/dev/null || echo "0")
        if ! is_numeric "$message_count"; then
            message_count=0
        fi

        # Hybrid estimation: ops * 0.25 + messages * 2
        # Capped at 100%
        local estimated=$(( (ops / 4) + (message_count * 2) ))
        [[ $estimated -gt 100 ]] && estimated=100
        pct="$estimated"

        log_context "DEBUG" "Fallback estimation: ops=$ops, msgs=$message_count, est=$pct%"
    fi

    # Method 3: Final fallback - simple message count
    if [[ -z "$pct" ]] || [[ "$pct" == "0" ]]; then
        local message_count
        message_count=$(cat "${RALPH_DIR}/state/message_count" 2>/dev/null || echo "0")
        if ! is_numeric "$message_count"; then
            message_count=0
        fi
        # Rough estimate: ~3% per message
        pct=$(( message_count * 3 < 100 ? message_count * 3 : 100 ))
    fi

    # Round to integer and clamp to 0-100
    echo "$pct" | awk '{printf "%.0f\n", ($1 > 100 ? 100 : ($1 < 0 ? 0 : $1))}'
}

# Increment operation counter (called by other hooks)
increment_operation_counter() {
    local counter_file="${RALPH_DIR}/state/operation-counter"
    mkdir -p "${RALPH_DIR}/state" 2>/dev/null || true
    local current
    current=$(cat "$counter_file" 2>/dev/null || echo "0")
    if ! is_numeric "$current"; then
        current=0
    fi
    echo $((current + 1)) > "$counter_file"
}

# Get current objective (from task file if available)
get_current_objective() {
    local objective_file="${RALPH_DIR}/current_objective"
    if [[ -f "$objective_file" ]]; then
        cat "$objective_file"
    else
        echo "current task"
    fi
}

# Show warning to user
show_warning() {
    local percentage="$1"
    local objective
    objective=$(get_current_objective)

    echo ""
    echo "⚠️  Context at ${percentage}%"
    echo ""
    echo "Your context is approaching the ${THRESHOLD}% effective threshold."
    echo "This may lead to context degradation and reduced AI performance."
    echo ""
    echo "🎯 Current objective: ${objective}"
    echo ""
    echo "Consider:"
    echo "  • @fresh-explorer \"Analyze patterns\" for fresh context"
    echo "  • @checkpoint save \"Pre-compaction state\""
    echo "  • Use @context-compression if available"

    # v2.44: Environment-specific recommendations
    if [[ "$CAPABILITIES" == "limited" ]]; then
        echo ""
        echo "📌 Extension mode detected ($ENV_TYPE):"
        echo "  • Use /compact skill to manually save context"
        echo "  • Or run: ralph compact"
    fi
    echo ""

    # Log the warning
    log_context "WARNING" "${percentage}% | Objective: ${objective} | Env: ${ENV_TYPE}"
}

# Show critical warning
show_critical() {
    local percentage="$1"
    local objective
    objective=$(get_current_objective)

    echo ""
    echo "🔴 Context CRITICAL: ${percentage}%"
    echo ""
    echo "Your context has exceeded the ${THRESHOLD}% effective threshold."
    echo "Performance degradation is likely."
    echo ""
    echo "🎯 Current objective: ${objective}"
    echo ""
    echo "IMMEDIATE ACTIONS:"
    echo "  1. @checkpoint save \"Urgent save\""
    echo "  2. @fresh-explorer \"Fresh task analysis\""
    echo "  3. Consider starting a new session"

    # v2.44: Environment-specific urgent recommendations
    if [[ "$CAPABILITIES" == "limited" ]]; then
        echo ""
        echo "🚨 Extension mode ($ENV_TYPE) - URGENT:"
        echo "  • Auto-compact may NOT trigger! Run: /compact"
        echo "  • Or use terminal: ralph compact"
        echo "  • Then start fresh: /clear or new conversation"
    fi
    echo ""

    # Log the critical warning
    log_context "CRITICAL" "${percentage}% | Objective: ${objective} | Env: ${ENV_TYPE}"
}

# Show info message
show_info() {
    local percentage="$1"

    echo ""
    echo "ℹ️  Context at ${percentage}%"
    echo "Consider compaction if you plan to continue this session."
    echo ""

    # Log the info
    log_context "INFO" "${percentage}%"
}

# Main execution
main() {
    local context_pct
    context_pct=$(get_context_percentage)

    # Update message count (v2.47: use STATE_DIR for consistency with reset)
    local msg_count
    mkdir -p "${RALPH_DIR}/state" 2>/dev/null || true
    msg_count=$(cat "${RALPH_DIR}/state/message_count" 2>/dev/null || echo "0")
    if ! is_numeric "$msg_count"; then
        msg_count=0
    fi
    echo $((msg_count + 1)) > "${RALPH_DIR}/state/message_count"

    # Determine action based on context level
    if [[ "$context_pct" -ge "$CRITICAL_THRESHOLD" ]]; then
        show_critical "$context_pct"
    elif [[ "$context_pct" -ge "$THRESHOLD" ]]; then
        show_warning "$context_pct"
    elif [[ "$context_pct" -ge 50 ]]; then
        show_info "$context_pct"
    fi

    # Exit successfully (hook should not block execution)
    exit 0
}

# Run main
main "$@"
