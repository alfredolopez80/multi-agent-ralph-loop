#!/bin/bash
# ============================================================================
# checkpoint-auto-save.sh - v2.66.6
# Hook: PreToolUse (Edit|Write)
# Purpose: Auto-save checkpoint before critical operations
# GLOBAL: Enabled by default for all projects
# Output: {"decision": "allow"} (PreToolUse JSON format)
# ============================================================================

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

# VERSION: 2.81.2
# v2.81.2: FIX JSON schema - use hookSpecificOutput for PreToolUse
# v2.66.6: SEC-049 - Fixed registration (was PostToolUse, now PreToolUse)

# Error trap: Always output valid JSON for PreToolUse
trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT
RALPH_DIR="${HOME}/.ralph"
CHECKPOINT_DIR="${RALPH_DIR}/checkpoints"
CONFIG_FILE="${RALPH_DIR}/checkpoint-config.json"
LOG_FILE="${RALPH_DIR}/checkpoint-auto.log"

# Load configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # Simple JSON parsing for auto_save_enabled
        if grep -q '"auto_save_enabled": true' "$CONFIG_FILE" 2>/dev/null; then
            AUTO_SAVE_ENABLED="true"
        else
            AUTO_SAVE_ENABLED="false"
        fi
    else
        # Default: enabled
        AUTO_SAVE_ENABLED="true"
    fi
}

# Log function
log_auto() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "${timestamp} [${level}] ${message}" >> "$LOG_FILE" 2>/dev/null || true
}

# Create checkpoint
create_checkpoint() {
    local trigger="$1"
    local description="$2"

    mkdir -p "$CHECKPOINT_DIR" 2>/dev/null || return 1

    local timestamp
    timestamp=$(date -u +"%Y%m%d_%H%M%S")
    local cp_file="${CHECKPOINT_DIR}/cp_${timestamp}_${trigger}.json"

    # SEC-008: Create checkpoint JSON using jq for safe construction
    jq -n \
        --arg id "cp_${timestamp}_${trigger}" \
        --arg ts "$(date -u +"%Y-%m-%d %H:%M:%S")" \
        --arg trig "$trigger" \
        --arg desc "$description" \
        --arg cwd "$(pwd)" \
        '{
            id: $id,
            timestamp: $ts,
            trigger: $trig,
            description: $desc,
            auto_saved: true,
            global: true,
            cwd: $cwd,
            version: "2.66"
        }' > "$cp_file"

    echo "$cp_file"
    log_auto "INFO" "Auto-saved checkpoint: $cp_file"
}

# Detect critical operations
detect_critical_operation() {
    local command="$1"

    # Multi-file operations (read or edit)
    local file_count
    file_count=$(echo "$command" | grep -oE '\.(py|ts|js|go|rs|swift|sol|java|cpp|hpp)[,"'\''[:space:]]' 2>/dev/null | wc -l | tr -d ' ')

    if [ "$file_count" -gt 3 ]; then
        echo "multi_file_edit:$file_count"
        return 0
    fi

    # Refactoring keywords
    if echo "$command" | grep -qiE "(refactor|rename|move|extract|inline)"; then
        echo "refactor"
        return 0
    fi

    # Security operations
    if echo "$command" | grep -qiE "(auth|permission|encryption|security|jwt|oauth)"; then
        echo "security"
        return 0
    fi

    # Database operations
    if echo "$command" | grep -qiE "(migration|schema|database|mongo|postgres|mysql)"; then
        echo "database"
        return 0
    fi

    return 1
}

# Output JSON and exit
allow_and_exit() {
    trap - ERR EXIT  # Disable trap before explicit output
    echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
    exit 0
}

# Main execution
main() {
    load_config

    if [ "$AUTO_SAVE_ENABLED" != "true" ]; then
        log_auto "DEBUG" "Auto-save disabled, skipping"
        allow_and_exit
    fi

    # v2.69: Use $INPUT from SEC-111 read instead of second cat (fixes CRIT-001 double-read bug)
    local input="$INPUT"

    # Extract tool_input from JSON if available
    local command=""
    if [ -n "$input" ]; then
        command=$(echo "$input" | jq -r '.tool_input // empty' 2>/dev/null || echo "$input")
    fi

    if [ -z "$command" ]; then
        allow_and_exit
    fi

    # Check for critical operation
    local trigger
    trigger=$(detect_critical_operation "$command") || true

    if [ -n "$trigger" ]; then
        local cp_file
        cp_file=$(create_checkpoint "$trigger" "Auto-save before $trigger operation") || true

        if [ -n "$cp_file" ] && [ -f "$cp_file" ]; then
            # v2.81.2: FIX JSON schema - use hookSpecificOutput for PreToolUse
            log_auto "INFO" "Checkpoint saved: $cp_file"
            trap - ERR EXIT
            echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
            exit 0
        fi
    fi

    allow_and_exit
}

main "$@"
