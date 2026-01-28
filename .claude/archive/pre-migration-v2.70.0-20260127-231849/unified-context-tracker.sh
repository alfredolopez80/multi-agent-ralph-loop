#!/bin/bash
# unified-context-tracker.sh - Unified context tracking for Claude and GLM-4.7
# VERSION: 2.0.0
# Part of FIX-CRIT-007 - Project-specific context tracking
#
# This script provides a single interface for tracking context usage
# across both Claude and GLM-4.7 models, with project-specific isolation.
#
# Usage:
#   ./unified-context-tracker.sh get-percentage    # Get current context %
#   ./unified-context-tracker.sh get-info         # Get full context info
#   ./unified-context-tracker.sh get-model        # Detect current model
# v2.0.0: FIX-CRIT-007 - Project-specific state tracking using git root
# v1.2.0: FIX-CRIT-006 - Add fallback estimation for GLM when tracker returns 0
# v1.1.0: FIX-CRIT-004 - Improved model detection using environment detection

set -euo pipefail

# Configuration
HOOKS_DIR="${HOME}/.claude/hooks"
PROJECT_STATE="${HOOKS_DIR}/project-state.sh"
GLM_TRACKER="${HOOKS_DIR}/glm-context-tracker.sh"

# Get project-specific state directory
# Falls back to global state if project-state.sh is not available
if [[ -f "$PROJECT_STATE" ]]; then
    STATE_DIR=$("$PROJECT_STATE" get-dir 2>/dev/null || echo "${RALPH_DIR:-${HOME}/.ralph}/state")
else
    STATE_DIR="${RALPH_DIR:-${HOME}/.ralph}/state"
fi

# Ensure state directory exists
mkdir -p "$STATE_DIR"

GLM_MARKER="${STATE_DIR}/glm-active"

# Error trap for guaranteed output
trap 'echo "{\"error\": \"Command failed\"}"' ERR EXIT

# Detect which model is currently active
# FIX-CRIT-004: Improved detection using environment detection and settings
# FIX-CRIT-006: Parse JSON output instead of sourcing to avoid stdout pollution
detect_model() {
    # Method 1: Check environment detection (call script, don't source)
    if [[ -f "${HOOKS_DIR}/detect-environment.sh" ]]; then
        local env_json
        env_json=$("${HOOKS_DIR}/detect-environment.sh" 2>/dev/null || echo '{}')
        local caps
        caps=$(echo "$env_json" | jq -r '.capabilities // ""' 2>/dev/null || echo "")

        if [[ "$caps" == "api" ]]; then
            echo "glm"
            return 0
        fi
    fi

    # Method 2: Check GLM marker (fallback)
    # NOTE: This marker should be managed by session-start-glm-init.sh
    if [[ -f "$GLM_MARKER" ]]; then
        echo "glm"
    else
        echo "claude"
    fi
}

# Get context percentage (unified interface)
# FIX-CRIT-006: Add fallback estimation for GLM when tracker returns 0
get_percentage() {
    local model
    model=$(detect_model)

    case "$model" in
        glm)
            # Use GLM tracker with fallback estimation
            if [[ -x "$GLM_TRACKER" ]]; then
                local pct
                pct=$("$GLM_TRACKER" get-percentage 2>/dev/null || echo "0")

                # FIX-CRIT-006: If GLM tracker returns 0, use estimation
                if [[ "$pct" == "0" ]] || [[ -z "$pct" ]]; then
                    # Estimate from message_count and operation_counter
                    local ops
                    ops=$(cat "${STATE_DIR}/operation-counter" 2>/dev/null || echo "0")
                    local msgs
                    msgs=$(cat "${STATE_DIR}/message_count" 2>/dev/null || echo "0")

                    # Validate numeric values
                    [[ ! "$ops" =~ ^[0-9]+$ ]] && ops=0
                    [[ ! "$msgs" =~ ^[0-9]+$ ]] && msgs=0

                    # Hybrid estimation: ops * 0.25 + messages * 2
                    # Each message is ~2% of GLM-4.7's 128K context
                    # Each operation is ~0.25%
                    local estimated=$(( (ops / 4) + (msgs * 2) ))
                    [[ $estimated -gt 100 ]] && estimated=100
                    echo "$estimated"
                else
                    echo "$pct"
                fi
            else
                # Fallback to estimation if tracker not available
                local ops
                ops=$(cat "${STATE_DIR}/operation-counter" 2>/dev/null || echo "0")
                local msgs
                msgs=$(cat "${STATE_DIR}/message_count" 2>/dev/null || echo "0")
                local estimated=$(( (ops / 4) + (msgs * 2) ))
                [[ $estimated -gt 100 ]] && estimated=100
                echo "$estimated"
            fi
            ;;
        claude)
            # Try native Claude context command
            local pct
            pct=$(timeout 3 claude --print "/context" 2>/dev/null | grep -o '[0-9]*%' | tr -d '%' || echo "")

            if [[ -z "$pct" ]] || [[ "$pct" == "0" ]]; then
                # Fallback to operation counter estimation
                local ops
                ops=$(cat "${STATE_DIR}/operation-counter" 2>/dev/null || echo "0")
                local msgs
                msgs=$(cat "${STATE_DIR}/message_count" 2>/dev/null || echo "0")
                local estimated=$(( (ops / 4) + (msgs * 2) ))
                [[ $estimated -gt 100 ]] && estimated=100
                echo "$estimated"
            else
                echo "$pct"
            fi
            ;;
        *)
            echo "0"
            ;;
    esac
}

# Get full context info
get_info() {
    local model
    model=$(detect_model)

    case "$model" in
        glm)
            if [[ -x "$GLM_TRACKER" ]]; then
                "$GLM_TRACKER" get-info 2>/dev/null || echo '{"model":"glm","error":"tracker unavailable"}'
            else
                echo '{"model":"glm","error":"tracker not found"}'
            fi
            ;;
        claude)
            local pct
            pct=$(get_percentage)
            echo "{\"model\":\"claude\",\"percentage\":$pct,\"context_window\":200000}"
            ;;
        *)
            echo '{"model":"unknown","percentage":0}'
            ;;
    esac
}

# Main command dispatcher
case "${1:-}" in
    get-percentage|--percent|-p)
        trap - ERR EXIT
        get_percentage
        ;;
    get-info|--info|-i)
        trap - ERR EXIT
        get_info
        ;;
    get-model|--model|-m)
        trap - ERR EXIT
        detect_model
        ;;
    *)
        trap - ERR EXIT
        echo "Usage: $0 {get-percentage|get-info|get-model}"
        exit 1
        ;;
esac

exit 0
