#!/bin/bash
# action-report-lib.sh - Helper library for skill authors
# VERSION: 2.93.0
#
# Usage: Source this file in your skill scripts to easily generate reports
#
# Example:
#   source .claude/lib/action-report-lib.sh
#   start_action_report "orchestrator" "Implementing OAuth2"
#   # ... do work ...
#   complete_action_report "success" "Implementation completed"

set -euo pipefail

# Import the report generator
ACTION_REPORT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ACTION_REPORT_LIB_DIR}/action-report-generator.sh" || {
    echo "ERROR: Failed to source action-report-generator.sh" >&2
    exit 1
}

# Global state for current action
export CURRENT_ACTION_SKILL=""
export CURRENT_ACTION_START_TIME=""
export CURRENT_ACTION_DESCRIPTION=""
export CURRENT_ACTION_ITERATIONS=0
export CURRENT_ACTION_FILES_MODIFIED=0
export CURRENT_ACTION_ERRORS=()

# ============================================================================
# Lifecycle Functions
# ============================================================================

# Start a new action report
# Usage: start_action_report <skill_name> <description>
start_action_report() {
    local skill_name="$1"
    local description="$2"

    CURRENT_ACTION_SKILL="$skill_name"
    CURRENT_ACTION_START_TIME=$(date +%s)
    CURRENT_ACTION_DESCRIPTION="$description"
    CURRENT_ACTION_ITERATIONS=0
    CURRENT_ACTION_FILES_MODIFIED=0
    CURRENT_ACTION_ERRORS=()

    # Create directories
    mkdir -p "docs/actions/${skill_name}"
    mkdir -p ".claude/metadata/actions/${skill_name}"

    # Create initial report
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local filename_date=$(date +"%Y%m%d-%H%M%S")
    local report_file="docs/actions/${skill_name}/${filename_date}.md"

    cat > "$report_file" <<EOF
# 🔄 Action Report: ${skill_name}

**Started**: ${timestamp}
**Status**: IN_PROGRESS
**Session**: \`${SESSION_ID:-unknown}\`

---

## Summary

${description}

---

## Progress

*Action in progress...*

EOF

    echo "📋 Action started: $skill_name"
    echo "📄 Report: $report_file"
}

# Mark an iteration
# Usage: mark_iteration
mark_iteration() {
    ((CURRENT_ACTION_ITERATIONS++))
    append_progress "$CURRENT_ACTION_SKILL" "$(date -u +"%Y-%m-%dT%H:%M:%SZ") "Iteration $CURRENT_ACTION_ITERATIONS"
}

# Mark a file modification
# Usage: mark_file_modified <file_path>
mark_file_modified() {
    local file_path="$1"
    ((CURRENT_ACTION_FILES_MODIFIED++))
    append_progress "$CURRENT_ACTION_SKILL" "$(date -u +"%Y-%m-%dT%H:%M:%SZ") "Modified: $file_path"
}

# Record an error
# Usage: record_error <error_message>
record_error() {
    local error_msg="$1"
    CURRENT_ACTION_ERRORS+=("$error_msg")
    append_progress "$CURRENT_ACTION_SKILL" "$(date -u +"%Y-%m-%dT%H:%M:%SZ") "ERROR: $error_msg"
}

# Complete the action report
# Usage: complete_action_report <status> <summary> [recommendations]
complete_action_report() {
    local status="$1"  # success | failed | partial
    local summary="$2"
    local recommendations="${3:-None}"

    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - CURRENT_ACTION_START_TIME))
    local duration_formatted=$(format_duration "$duration")

    # Build errors string
    local errors_str="None"
    if [[ ${#CURRENT_ACTION_ERRORS[@]} -gt 0 ]]; then
        errors_str=$(
            IFS=$'\n'
            echo "${CURRENT_ACTION_ERRORS[*]}"
        )
    fi

    # Generate details JSON
    local details=$(jq -n \
        --arg duration "$duration_formatted" \
        --argjson iterations "$CURRENT_ACTION_ITERATIONS" \
        --argjson files_modified "$CURRENT_ACTION_FILES_MODIFIED" \
        --arg errors "$errors_str" \
        --arg recommendations "$recommendations" \
        '{
            duration: $duration,
            iterations: $iterations,
            files_modified: $files_modified,
            errors: $errors,
            recommendations: $recommendations
        }')

    # Generate final report (this outputs to stdout AND saves to file)
    generate_action_report \
        "$CURRENT_ACTION_SKILL" \
        "$status" \
        "$summary" \
        "$details"

    # Reset state
    CURRENT_ACTION_SKILL=""
    CURRENT_ACTION_START_TIME=""
    CURRENT_ACTION_DESCRIPTION=""
    CURRENT_ACTION_ITERATIONS=0
    CURRENT_ACTION_FILES_MODIFIED=0
    CURRENT_ACTION_ERRORS=()
}

# ============================================================================
# Utility Functions
# ============================================================================

format_duration() {
    local seconds="$1"

    if [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    elif [[ $seconds -lt 3600 ]]; then
        echo "$((seconds / 60))m $((seconds % 60))s"
    else
        echo "$((seconds / 3600))h $(( (seconds % 3600) / 60 ))m"
    fi
}

# Get current action stats
get_action_stats() {
    if [[ -n "$CURRENT_ACTION_SKILL" ]]; then
        cat <<EOF
Current Action:
  Skill: $CURRENT_ACTION_SKILL
  Description: $CURRENT_ACTION_DESCRIPTION
  Iterations: $CURRENT_ACTION_ITERATIONS
  Files Modified: $CURRENT_ACTION_FILES_MODIFIED
  Errors: ${#CURRENT_ACTION_ERRORS[@]}
EOF
    else
        echo "No active action"
    fi
}

# Export functions
export -f start_action_report
export -f mark_iteration
export -f mark_file_modified
export -f record_error
export -f complete_action_report
export -f get_action_stats
