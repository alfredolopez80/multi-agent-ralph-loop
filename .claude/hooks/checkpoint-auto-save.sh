#!/bin/bash
# ============================================================================
# checkpoint-auto-save.sh - v2.30
# Hook: pre-command
# Purpose: Auto-save checkpoint before critical operations
# GLOBAL: Enabled by default for all projects
# ============================================================================

# VERSION: 2.57.4
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

    # Create checkpoint JSON
    cat > "$cp_file" << EOF
{
  "id": "cp_${timestamp}_${trigger}",
  "timestamp": "$(date -u +"%Y-%m-%d %H:%M:%S")",
  "trigger": "$trigger",
  "description": "$description",
  "auto_saved": true,
  "global": true,
  "cwd": "$(pwd)",
  "version": "2.30"
}
EOF

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

# Main execution
main() {
    load_config

    if [ "$AUTO_SAVE_ENABLED" != "true" ]; then
        log_auto "DEBUG" "Auto-save disabled, skipping"
        exit 0
    fi

    # Get the command being executed
    local command="${1:-}"

    if [ -z "$command" ]; then
        exit 0
    fi

    # Check for critical operation
    local trigger
    trigger=$(detect_critical_operation "$command")

    if [ -n "$trigger" ]; then
        local cp_file
        cp_file=$(create_checkpoint "$trigger" "Auto-save before $trigger operation")

        if [ -n "$cp_file" ] && [ -f "$cp_file" ]; then
            # Notify user (non-blocking)
            echo "💾 Auto-checkpoint saved before $trigger operation" >&2
            log_auto "INFO" "Checkpoint saved: $cp_file"
        fi
    fi

    exit 0
}

main "$@"
