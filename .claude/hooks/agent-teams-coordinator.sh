#!/bin/bash
# agent-teams-coordinator.sh - Shared functions for Agent Teams hooks
# VERSION: 2.85.0
# REPO: multi-agent-ralph-loop
#
# This file is sourced by other hooks to provide shared functionality.
# Not meant to be executed directly.
#
# Usage:
#   source /path/to/agent-teams-coordinator.sh
#
# Available functions:
#   - log_event: Log to agent-teams.log
#   - check_console_log: Check for console.log in files
#   - check_debugger: Check for debugger statements
#   - check_todos: Check for TODO/FIXME
#   - check_placeholder: Check for placeholder code
#   - run_quality_gates: Run all quality gates

# Configuration
AGENT_TEAMS_LOG_DIR="${AGENT_TEAMS_LOG_DIR:-$HOME/.ralph/logs}"
AGENT_TEAMS_REPO_ROOT="${AGENT_TEAMS_REPO_ROOT:-/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop}"

# Ensure log directory exists
mkdir -p "$AGENT_TEAMS_LOG_DIR"

# =============================================================================
# Logging Functions
# =============================================================================

log_event() {
    local event_type="$1"
    local message="$2"
    local log_file="$AGENT_TEAMS_LOG_DIR/agent-teams.log"

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${event_type}: ${message}" >> "$log_file"
}

log_info() {
    log_event "INFO" "$1"
}

log_warning() {
    log_event "WARN" "$1"
}

log_error() {
    log_event "ERROR" "$1"
}

# =============================================================================
# Quality Check Functions
# =============================================================================

# Check for console.log/debug in a file
# Returns 0 if found (issue), 1 if not found (clean)
check_console_log() {
    local file="$1"

    # Skip non-code files
    case "$file" in
        *.md|*.json|*.yaml|*.yml|*.txt|*.sh|*.lock) return 1 ;;
    esac

    if [[ -f "$file" ]] && grep -qE "console\.(log|debug)\(" "$file" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Check for debugger/breakpoint statements
# Returns 0 if found (issue), 1 if not found (clean)
check_debugger() {
    local file="$1"

    if [[ -f "$file" ]] && [[ "$file" =~ \.(ts|tsx|js|jsx|py)$ ]]; then
        if grep -qE "debugger;|breakpoint\(\)|import pdb|pdb\.set_trace" "$file" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check for TODO/FIXME comments
# Returns 0 if found (issue), 1 if not found (clean)
check_todos() {
    local file="$1"

    if [[ -f "$file" ]] && [[ "$file" =~ \.(ts|tsx|js|jsx|py|go|rs|java|kt)$ ]]; then
        if grep -qE "TODO:|FIXME:|XXX:|HACK:" "$file" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Check for placeholder code
# Returns 0 if found (issue), 1 if not found (clean)
check_placeholder() {
    local file="$1"

    if [[ -f "$file" ]]; then
        if grep -qE "(throw new Error\('Not implemented|throw new Error\(\"Not implemented|# TODO:|pass # placeholder|raise NotImplementedError|NotImplementedError\(\))" "$file" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# =============================================================================
# JSON Helper Functions
# =============================================================================

# Extract value from JSON with fallback
json_get() {
    local json="$1"
    local key="$2"
    local default="${3:-unknown}"

    echo "$json" | jq -r ".${key} // \"${default}\""
}

# Parse JSON array from stdin
json_array_items() {
    jq -r '.[]' 2>/dev/null
}

# =============================================================================
# Output Functions
# =============================================================================

# Output approval JSON
output_approve() {
    local reason="${1:-All quality checks passed}"
    cat <<EOF
{"decision": "approve", "reason": "${reason}"}
EOF
}

# Output rejection JSON with feedback
output_reject() {
    local reason="${1:-Quality issues found}"
    local feedback="${2:-Please fix the issues}"
    cat <<EOF
{"decision": "request_changes", "reason": "${reason}", "feedback": "${feedback}"}
EOF
}

# =============================================================================
# Main Quality Gates Runner
# =============================================================================

# Run all quality gates on a list of files
# Returns number of blocking issues found
run_quality_gates() {
    local files_json="$1"
    local blocking="${2:-true}"  # true for blocking checks, false for advisory
    local issues=""

    # Parse files
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ ! -f "$file" ]] && continue

        if check_console_log "$file"; then
            issues+="console.log found in $file\n"
        fi

        if check_debugger "$file"; then
            issues+="debugger found in $file\n"
        fi

        if [[ "$blocking" == "true" ]]; then
            if check_todos "$file"; then
                issues+="TODO/FIXME found in $file\n"
            fi

            if check_placeholder "$file"; then
                issues+="placeholder code found in $file\n"
            fi
        fi
    done <<< "$(echo "$files_json" | json_array_items)"

    echo -e "$issues"
}

# =============================================================================
# Initialization
# =============================================================================

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "This script is meant to be sourced, not executed directly."
    echo "Usage: source $0"
    exit 1
fi
