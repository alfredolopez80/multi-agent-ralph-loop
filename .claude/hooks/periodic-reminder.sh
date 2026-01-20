#!/bin/bash
# ============================================================================
# periodic-reminder.sh - v2.30
# Hook: user-prompt-submit
# Purpose: Inject periodic goal reminders to prevent "lost in middle" syndrome
# ============================================================================

# Configuration
# VERSION: 2.57.0
RALPH_DIR="${HOME}/.ralph"
GOAL_FILE="${RALPH_DIR}/current_goal"
STATUS_FILE="${RALPH_DIR}/reminder_status"
LOG_FILE="${RALPH_DIR}/reminder.log"

# Configurable parameters (can be overridden by environment)
REMINDER_INTERVAL="${REMINDER_INTERVAL:-5}"      # Messages between reminders
CONTEXT_THRESHOLD="${CONTEXT_THRESHOLD:-40}"      # Context % to trigger reminder
ENABLE_LOGGING="${ENABLE_LOGGING:-true}"

# ============================================================================
# Logging function (only if enabled)
# ============================================================================
log_reminder() {
    if [ "$ENABLE_LOGGING" = "true" ]; then
        local level="$1"
        local message="$2"
        local timestamp
        timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        echo "${timestamp} [${level}] ${message}" >> "$LOG_FILE"
    fi
}

# ============================================================================
# Safe file operations (with error handling)
# ============================================================================
safe_read_file() {
    local file="$1"
    if [ -f "$file" ] && [ -r "$file" ]; then
        cat "$file" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

safe_write_file() {
    local file="$1"
    local content="$2"
    local dir
    dir=$(dirname "$file")
    mkdir -p "$dir" 2>/dev/null || true
    echo "$content" > "$file" 2>/dev/null || true
}

# ============================================================================
# Numeric validation
# ============================================================================
is_numeric() {
    local val="$1"
    [[ "$val" =~ ^[0-9]+$ ]]
}

# ============================================================================
# Get current context usage percentage
# ============================================================================
get_context_percentage() {
    local context_output
    context_output=$(claude --print "/context" 2>/dev/null || echo "unknown")

    # Parse percentage - support decimals: NN% or N.N%
    if [[ "$context_output" =~ ([0-9]+\.?[0-9]*)% ]]; then
        local pct="${BASH_REMATCH[1]}"
        # Clamp to 0-100 range
        awk -v val="$pct" 'BEGIN { printf "%.0f\n", (val > 100 ? 100 : (val < 0 ? 0 : val)) }'
    else
        # Fallback: estimate based on message count
        local message_count
        message_count=$(safe_read_file "${RALPH_DIR}/message_count")
        if ! is_numeric "$message_count" || [ -z "$message_count" ]; then
            message_count=0
        fi
        local estimated=$(( message_count * 5 ))
        if [ "$estimated" -gt 100 ]; then
            estimated=100
        fi
        echo "$estimated"
    fi
}

# ============================================================================
# Get current goal
# ============================================================================
get_current_goal() {
    local goal
    goal=$(safe_read_file "$GOAL_FILE")
    if [ -z "$goal" ]; then
        echo "No goal set - use: echo 'your goal' > ~/.ralph/current_goal"
    else
        echo "$goal"
    fi
}

# ============================================================================
# Increment message counter
# ============================================================================
increment_counter() {
    local count
    count=$(safe_read_file "${STATUS_FILE}/count")

    if ! is_numeric "$count" || [ -z "$count" ]; then
        count=0
    fi

    count=$((count + 1))
    safe_write_file "${STATUS_FILE}/count" "$count"
    echo "$count"
}

# ============================================================================
# Reset counter after reminder
# ============================================================================
reset_counter() {
    safe_write_file "${STATUS_FILE}/count" "1"
}

# ============================================================================
# Check if context threshold reached
# ============================================================================
check_context_threshold() {
    local context_pct
    context_pct=$(get_context_percentage)

    if ! is_numeric "$context_pct"; then
        echo "false"
        return
    fi

    if [ "$context_pct" -ge "$CONTEXT_THRESHOLD" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# ============================================================================
# Generate progress summary (placeholder - enhanced versions can track real progress)
# ============================================================================
get_progress_summary() {
    local message_count
    message_count=$(safe_read_file "${RALPH_DIR}/message_count")
    if ! is_numeric "$message_count" || [ -z "$message_count" ]; then
        message_count=0
    fi

    if [ "$message_count" -lt 5 ]; then
        echo "Task initialization phase"
    elif [ "$message_count" -lt 20 ]; then
        echo "Active implementation in progress"
    elif [ "$message_count" -lt 50 ]; then
        echo "Mid-task: progressing through main implementation"
    else
        echo "Extended task: maintaining focus on objective"
    fi
}

# ============================================================================
# Inject reminder message
# ============================================================================
inject_reminder() {
    local goal="$1"
    local message_count="$2"
    local context_pct="$3"
    local progress="$4"

    log_reminder "INFO" "Injecting reminder - messages: $message_count, context: $context_pct%"

    echo ""
    echo "🎯 **Goal Reminder**"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "**Objective**: $goal"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "**Progress**: $progress"
    echo "**Messages since last**: $message_count"
    echo "**Context usage**: ${context_pct}%"
    echo ""
    echo "💡 Stay focused on the original objective above."
    echo ""
}

# ============================================================================
# Main execution
# ============================================================================
main() {
    # Ensure directories exist
    mkdir -p "$RALPH_DIR" "${STATUS_FILE}" 2>/dev/null || true

    # Check if goal is set
    local current_goal
    current_goal=$(get_current_goal)

    if [[ "$current_goal" == "No goal set"* ]]; then
        log_reminder "DEBUG" "No goal set, skipping reminder"
        exit 0
    fi

    # Increment message counter
    local message_count
    message_count=$(increment_counter)

    log_reminder "DEBUG" "Message count: $message_count, interval: $REMINDER_INTERVAL"

    # Check if reminder should be triggered
    local trigger_reminder="false"

    # Check interval threshold
    if [ "$message_count" -ge "$REMINDER_INTERVAL" ]; then
        trigger_reminder="true"
        log_reminder "INFO" "Interval threshold reached: $message_count >= $REMINDER_INTERVAL"
    fi

    # Check context threshold
    local context_trigger
    context_trigger=$(check_context_threshold)
    if [ "$context_trigger" = "true" ]; then
        trigger_reminder="true"
        local context_pct
        context_pct=$(get_context_percentage)
        log_reminder "INFO" "Context threshold reached: ${context_pct}% >= ${CONTEXT_THRESHOLD}%"
    fi

    # Inject reminder if triggered
    if [ "$trigger_reminder" = "true" ]; then
        local context_pct
        context_pct=$(get_context_percentage)
        local progress
        progress=$(get_progress_summary)

        inject_reminder "$current_goal" "$message_count" "$context_pct" "$progress"

        # Reset counter
        reset_counter

        log_reminder "INFO" "Reminder injected and counter reset"
    fi

    exit 0
}

# ============================================================================
# Entry point
# ============================================================================
main "$@"
