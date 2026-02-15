#!/bin/bash
# ~/.claude/hooks/context-warning.sh
# Context Monitoring Hook - v2.90.0
# Executed on every user-prompt-submit to monitor context usage
#
# v2.90.0 CRITICAL FIX:
#   - FIXED: Read remaining_percentage from stdin JSON (matches /context exactly)
#   - FIXED: Removed broken cumulative counter estimation that caused permanent 100%
#   - Priority: remaining_percentage > used_percentage > /context > minimal fallback
#   - Synced with statusline-ralph.sh v2.81.2 approach
#
# v2.44 IMPROVEMENTS:
#   - Environment detection for CLI vs VSCode/Cursor
#   - Improved fallback estimation for extensions (GitHub #15021)
#   - Operation counter for extensions where /context command fails

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


# Note: Not using set -e because this is a non-blocking hook
# Errors should not interrupt the main workflow
# VERSION: 2.90.0
# v2.69.0: HIGH-003 version sync, HIGH-006 JSON format already correct for UserPromptSubmit
# v2.57.2: Restructured to output all content as JSON (SEC-029)
# v2.57.1: Added 3s timeout to claude command to prevent hook timeout
# v2.47: Adjusted thresholds for proactive compaction (75%/85%)
#        Fixed message_count path to STATE_DIR
set -uo pipefail

# SEC-029: Guaranteed JSON output on exit (even on errors)
# v2.87.0 FIX: UserPromptSubmit uses {"continue": true} format
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' EXIT

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
# v2.90.0: Read from stdin JSON first (authoritative source), then fallbacks
# Synced with statusline-ralph.sh v2.81.2 approach
get_context_percentage() {
    local pct=""

    # Method 1: Parse stdin JSON (authoritative source from Claude Code)
    # This is the SAME data source as /context command
    # Priority: remaining_percentage > used_percentage
    if [[ -n "$INPUT" ]] && command -v jq &>/dev/null; then
        # Try remaining_percentage first (most accurate - matches /context)
        local remaining_pct
        remaining_pct=$(echo "$INPUT" | jq -r '.context_window.remaining_percentage // null' 2>/dev/null)

        if [[ -n "$remaining_pct" ]] && [[ "$remaining_pct" != "null" ]] && [[ "$remaining_pct" =~ ^[0-9]+$ ]]; then
            # remaining_percentage = 7 means 7% left, so 93% used
            pct=$((100 - remaining_pct))
            log_context "DEBUG" "stdin JSON: remaining=$remaining_pct%, used=$pct%"
        else
            # Try used_percentage as fallback
            local used_pct
            used_pct=$(echo "$INPUT" | jq -r '.context_window.used_percentage // null' 2>/dev/null)

            if [[ -n "$used_pct" ]] && [[ "$used_pct" != "null" ]] && [[ "$used_pct" =~ ^[0-9]+$ ]]; then
                pct="$used_pct"
                log_context "DEBUG" "stdin JSON: used_percentage=$pct%"
            fi
        fi
    fi

    # Method 2: Try native CLI command (works in full CLI mode)
    # SEC-029: Added 3s timeout to prevent hook timeout (exit code 124)
    if [[ -z "$pct" ]] && [[ "$CAPABILITIES" == "full" ]]; then
        local context_output
        context_output=$(timeout 3 claude --print "/context" 2>/dev/null || echo "unknown")

        # Parse percentage from output - support decimals: NN% or N.N%
        if [[ "$context_output" =~ ([0-9]+\.?[0-9]*)% ]]; then
            pct="${BASH_REMATCH[1]}"
            log_context "DEBUG" "/context command: $pct%"
        fi
    fi

    # Method 3: Session-scoped message count (minimal fallback, capped at 50%)
    # This is intentionally conservative to avoid false positives
    if [[ -z "$pct" ]]; then
        local message_count
        message_count=$(cat "${RALPH_DIR}/state/message_count" 2>/dev/null || echo "0")
        if ! is_numeric "$message_count"; then
            message_count=0
        fi
        # Conservative estimate: ~1% per message, capped at 50% to prevent false CRITICAL
        local estimated=$(( message_count * 1 ))
        [[ $estimated -gt 50 ]] && estimated=50
        pct="$estimated"
        log_context "DEBUG" "Fallback estimation (capped): msgs=$message_count, est=$pct%"
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

# Build warning message (returns message string)
build_warning_message() {
    local percentage="$1"
    local objective
    objective=$(get_current_objective)

    local msg="⚠️ Context at ${percentage}%\n\n"
    msg+="Your context is approaching the ${THRESHOLD}% effective threshold.\n"
    msg+="This may lead to context degradation and reduced AI performance.\n\n"
    msg+="🎯 Current objective: ${objective}\n\n"
    msg+="Consider:\n"
    msg+="  • @fresh-explorer \"Analyze patterns\" for fresh context\n"
    msg+="  • @checkpoint save \"Pre-compaction state\"\n"
    msg+="  • Use @context-compression if available"

    # v2.44: Environment-specific recommendations
    if [[ "$CAPABILITIES" == "limited" ]]; then
        msg+="\n\n📌 Extension mode detected ($ENV_TYPE):\n"
        msg+="  • Use /compact skill to manually save context\n"
        msg+="  • Or run: ralph compact"
    fi

    # Log the warning
    log_context "WARNING" "${percentage}% | Objective: ${objective} | Env: ${ENV_TYPE}"

    echo "$msg"
}

# Build critical warning message (returns message string)
build_critical_message() {
    local percentage="$1"
    local objective
    objective=$(get_current_objective)

    local msg="🔴 Context CRITICAL: ${percentage}%\n\n"
    msg+="Your context has exceeded the ${THRESHOLD}% effective threshold.\n"
    msg+="Performance degradation is likely.\n\n"
    msg+="🎯 Current objective: ${objective}\n\n"
    msg+="IMMEDIATE ACTIONS:\n"
    msg+="  1. @checkpoint save \"Urgent save\"\n"
    msg+="  2. @fresh-explorer \"Fresh task analysis\"\n"
    msg+="  3. Consider starting a new session"

    # v2.44: Environment-specific urgent recommendations
    if [[ "$CAPABILITIES" == "limited" ]]; then
        msg+="\n\n🚨 Extension mode ($ENV_TYPE) - URGENT:\n"
        msg+="  • Auto-compact may NOT trigger! Run: /compact\n"
        msg+="  • Or use terminal: ralph compact\n"
        msg+="  • Then start fresh: /clear or new conversation"
    fi

    # Log the critical warning
    log_context "CRITICAL" "${percentage}% | Objective: ${objective} | Env: ${ENV_TYPE}"

    echo "$msg"
}

# Build info message (returns message string)
build_info_message() {
    local percentage="$1"

    local msg="ℹ️ Context at ${percentage}%\n"
    msg+="Consider compaction if you plan to continue this session."

    # Log the info
    log_context "INFO" "${percentage}%"

    echo "$msg"
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

    # Determine action based on context level and build message
    local warning_msg=""
    local level="ok"

    if [[ "$context_pct" -ge "$CRITICAL_THRESHOLD" ]]; then
        warning_msg=$(build_critical_message "$context_pct")
        level="critical"
    elif [[ "$context_pct" -ge "$THRESHOLD" ]]; then
        warning_msg=$(build_warning_message "$context_pct")
        level="warning"
    elif [[ "$context_pct" -ge 50 ]]; then
        warning_msg=$(build_info_message "$context_pct")
        level="info"
    fi

    # SEC-029: Disable trap and output JSON
    trap - EXIT

    # Output JSON with message if there's a warning
    # v2.87.0 FIX: Use {"continue": true} format with hookSpecificOutput for UserPromptSubmit
    if [[ -n "$warning_msg" ]]; then
        warning_escaped=$(echo "$warning_msg" | jq -Rs '.')
        echo "{\"continue\": true, \"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": $warning_escaped}}"
    else
        echo '{"continue": true}'
    fi

    exit 0
}

# Run main
main "$@"
