#!/bin/bash
# ~/.claude/hooks/context-warning.sh
# Context Monitoring Hook - v2.30
# Executed on every user-prompt-submit to monitor context usage

# Note: Not using set -e because this is a non-blocking hook
# Errors should not interrupt the main workflow
set -uo pipefail

# Configuration
THRESHOLD=60
CRITICAL_THRESHOLD=75
LOG_FILE="${HOME}/.ralph/context-monitor.log"
RALPH_DIR="${HOME}/.ralph"

# Ensure log directory exists (ignore errors)
mkdir -p "$(dirname "$LOG_FILE" 2>/dev/null)" || true

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
get_context_percentage() {
    # Try to get context from Claude Code CLI
    local context_output
    context_output=$(claude --print "/context" 2>/dev/null || echo "unknown")

    # Parse percentage from output - support decimals: NN% or N.N%
    if [[ "$context_output" =~ ([0-9]+\.?[0-9]*)% ]]; then
        local pct="${BASH_REMATCH[1]}"
        # Round to integer and clamp to 0-100
        echo "$pct" | awk '{printf "%.0f\n", ($1 > 100 ? 100 : ($1 < 0 ? 0 : $1))}'
    else
        # Fallback: estimate based on message count
        local message_count
        message_count=$(cat "${RALPH_DIR}/message_count" 2>/dev/null || echo "0")
        # Validate it's numeric, else use 0
        if ! is_numeric "$message_count"; then
            message_count=0
        fi
        # Rough estimate: ~5% per message in long conversations
        local estimated=$(( message_count * 5 < 100 ? message_count * 5 : 100 ))
        echo "$estimated"
    fi
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
    echo ""

    # Log the warning
    log_context "WARNING" "${percentage}% | Objective: ${objective}"
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
    echo ""

    # Log the critical warning
    log_context "CRITICAL" "${percentage}% | Objective: ${objective}"
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

    # Update message count
    local msg_count
    msg_count=$(cat "${RALPH_DIR}/message_count" 2>/dev/null || echo "0")
    echo $((msg_count + 1)) > "${RALPH_DIR}/message_count"

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
