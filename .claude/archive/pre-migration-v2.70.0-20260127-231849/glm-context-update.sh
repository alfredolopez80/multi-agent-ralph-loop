#!/bin/bash
# glm-context-update.sh - Update GLM-4.7 context usage after each operation
# VERSION: 1.0.0
# Hook: PostToolUse (Edit|Write|Bash)
# Purpose: Update GLM context tracking with estimated tokens from operation
#
# This hook estimates token usage based on operation size and updates
# the glm-context.json file that claude-hud reads for display.
#
# Output: {"continue": true} (PostToolUse JSON format)

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

set -euo pipefail

# Error trap: Always output valid JSON for PostToolUse
trap 'echo "{\"continue\": true}"' ERR EXIT

# Configuration
HOOKS_DIR="${HOME}/.claude/hooks"
PROJECT_STATE="${HOOKS_DIR}/project-state.sh"
GLM_TRACKER="${HOOKS_DIR}/glm-context-tracker.sh"

# Get project-specific state directory
if [[ -f "$PROJECT_STATE" ]]; then
    STATE_DIR=$("$PROJECT_STATE" get-dir 2>/dev/null || echo "${RALPH_DIR:-${HOME}/.ralph}/state")
else
    STATE_DIR="${RALPH_DIR:-${HOME}/.ralph}/state"
fi

# Estimate tokens from operation
estimate_tokens() {
    local tool_name="$1"
    local tool_input="$2"
    local tool_result="$3"

    local estimated_tokens=0

    # Base estimation per operation type
    case "$tool_name" in
        Edit|Write)
            # Estimate from file size (roughly: chars / 4)
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
            # Estimate from command length and output
            local command=$(echo "$tool_input" | jq -r '.command // ""' 2>/dev/null || echo "")
            local output_len=${#tool_result}
            estimated_tokens=$(((${#command} + output_len) / 4))
            ;;
        Task)
            # Task operations are more expensive
            local prompt=$(echo "$tool_input" | jq -r '.prompt // ""' 2>/dev/null || echo "")
            estimated_tokens=$((${#prompt} / 2))
            ;;
        *)
            # Default small estimation
            estimated_tokens=100
            ;;
    esac

    # Minimum 100 tokens, maximum 10000 tokens per operation
    if [[ $estimated_tokens -lt 100 ]]; then
        estimated_tokens=100
    elif [[ $estimated_tokens -gt 10000 ]]; then
        estimated_tokens=10000
    fi

    echo "$estimated_tokens"
}

# Main execution
main() {
    # Check if GLM tracker is available
    if [[ ! -x "$GLM_TRACKER" ]]; then
        exit 0
    fi

    # Parse input
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")
    TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")
    TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // ""' 2>/dev/null || echo "")

    # Only track relevant operations
    case "$TOOL_NAME" in
        Edit|Write|Bash|Task)
            # Estimate tokens
            ESTIMATED_TOKENS=$(estimate_tokens "$TOOL_NAME" "$TOOL_INPUT" "$TOOL_RESULT")

            # Update GLM context tracker
            if [[ "$ESTIMATED_TOKENS" -gt 0 ]]; then
                "$GLM_TRACKER" add "$ESTIMATED_TOKENS" 0 >/dev/null 2>&1 || true
            fi
            ;;
        *)
            # Skip other tools
            ;;
    esac
}

main "$@"

# Clear trap and output success
trap - ERR EXIT
echo '{"continue": true}'
