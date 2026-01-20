#!/bin/bash
# detect-environment.sh - Environment Detection for Claude Code v2.44
#
# Detects: CLI, VSCode, Cursor, Extension (unknown)
# Exports: RALPH_ENV_TYPE, RALPH_CAPABILITIES
# Saves state to: ~/.ralph/state/current-env
#
# Usage:
#   source ~/.claude/hooks/detect-environment.sh
#   detect_environment  # Returns: cli:full, vscode:limited, cursor:limited, etc.
#   get_capabilities    # Returns: full or limited
#
# Part of Ralph v2.44 Context Engineering - GitHub #15021 Workaround

# VERSION: 2.57.5
set -uo pipefail

# Configuration
RALPH_STATE_DIR="${HOME}/.ralph/state"
ENV_STATE_FILE="${RALPH_STATE_DIR}/current-env"
LOG_FILE="${HOME}/.ralph/logs/env-detection.log"

# Ensure directories exist
mkdir -p "$RALPH_STATE_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Logging function
log_env() {
    local level="$1"
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [ENV] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Detect the current environment
# Returns: environment:capability (e.g., cli:full, vscode:limited)
detect_environment() {
    local env_type="unknown"
    local capability="limited"

    # Priority 1: Check CLAUDE_CODE_ENTRYPOINT (official env var)
    if [[ "${CLAUDE_CODE_ENTRYPOINT:-}" == "cli" ]]; then
        env_type="cli"
        capability="full"
        log_env "INFO" "Detected CLI via CLAUDE_CODE_ENTRYPOINT"

    elif [[ "${CLAUDE_CODE_ENTRYPOINT:-}" == "vscode" ]]; then
        env_type="vscode"
        capability="limited"
        log_env "INFO" "Detected VSCode via CLAUDE_CODE_ENTRYPOINT"

    elif [[ "${CLAUDE_CODE_ENTRYPOINT:-}" == "cursor" ]]; then
        env_type="cursor"
        capability="limited"
        log_env "INFO" "Detected Cursor via CLAUDE_CODE_ENTRYPOINT"

    # Priority 2: Check common IDE environment variables
    elif [[ -n "${VSCODE_PID:-}" ]] || [[ -n "${VSCODE_IPC_HOOK_CLI:-}" ]]; then
        env_type="vscode"
        capability="limited"
        log_env "INFO" "Detected VSCode via VSCODE_PID/VSCODE_IPC_HOOK_CLI"

    elif [[ -n "${CURSOR_PID:-}" ]] || [[ "${TERM_PROGRAM:-}" == "cursor" ]]; then
        env_type="cursor"
        capability="limited"
        log_env "INFO" "Detected Cursor via CURSOR_PID/TERM_PROGRAM"

    # Priority 3: Check if running in a terminal
    elif [[ -t 0 ]] && [[ -t 1 ]] && [[ -z "${CLAUDE_CODE_ENTRYPOINT:-}" ]]; then
        # Interactive terminal without extension markers - likely CLI
        env_type="cli"
        capability="full"
        log_env "INFO" "Detected CLI via interactive terminal"

    # Priority 4: Check for extension-like behavior
    elif [[ -n "${CLAUDE_EXTENSION_ID:-}" ]]; then
        env_type="extension"
        capability="limited"
        log_env "INFO" "Detected generic extension via CLAUDE_EXTENSION_ID"

    else
        # Unknown environment - assume limited to be safe
        env_type="extension-unknown"
        capability="limited"
        log_env "WARN" "Unknown environment, defaulting to limited capability"
    fi

    # Save state for other scripts
    echo "${env_type}:${capability}" > "$ENV_STATE_FILE"

    # Export for current session
    export RALPH_ENV_TYPE="$env_type"
    export RALPH_CAPABILITIES="$capability"

    echo "${env_type}:${capability}"
}

# Get just the environment type
get_env_type() {
    if [[ -f "$ENV_STATE_FILE" ]]; then
        cut -d: -f1 < "$ENV_STATE_FILE"
    else
        detect_environment | cut -d: -f1
    fi
}

# Get just the capability level
get_capabilities() {
    if [[ -f "$ENV_STATE_FILE" ]]; then
        cut -d: -f2 < "$ENV_STATE_FILE"
    else
        detect_environment | cut -d: -f2
    fi
}

# Check if we have full capabilities (CLI mode)
has_full_capabilities() {
    local cap
    cap=$(get_capabilities)
    [[ "$cap" == "full" ]]
}

# Check if specific feature is available
# Usage: is_feature_available "auto_compact" "hooks"
is_feature_available() {
    local feature="$1"
    local category="${2:-general}"
    local cap
    cap=$(get_capabilities)

    case "$feature" in
        # Features available in all modes
        ledger|handoff|transcript)
            return 0
            ;;

        # Features only in full mode (CLI)
        auto_compact|native_hooks|context_percentage)
            [[ "$cap" == "full" ]]
            ;;

        # Features that need workarounds in limited mode
        hooks)
            # Hooks work but may not trigger automatically
            return 0
            ;;

        # Default: available in all modes
        *)
            return 0
            ;;
    esac
}

# Get recommended action for current environment
get_env_recommendations() {
    local env
    env=$(get_env_type)
    local cap
    cap=$(get_capabilities)

    case "$env" in
        cli)
            echo "Full functionality available. All hooks trigger automatically."
            ;;
        vscode|cursor)
            echo "Limited mode: Use /compact skill for manual context save."
            echo "Auto-compact hooks may not trigger (GitHub #15021)."
            echo "Recommendation: Use 'ralph compact' periodically."
            ;;
        extension*)
            echo "Unknown extension mode. Using conservative defaults."
            echo "Use 'ralph compact' to manually save context."
            ;;
    esac
}

# Print environment info (for debugging)
print_env_info() {
    local env
    env=$(detect_environment)
    local env_type
    env_type=$(echo "$env" | cut -d: -f1)
    local capability
    capability=$(echo "$env" | cut -d: -f2)

    echo "┌─────────────────────────────────────────────┐"
    echo "│        RALPH ENVIRONMENT DETECTION          │"
    echo "├─────────────────────────────────────────────┤"
    printf "│  Environment: %-29s│\n" "$env_type"
    printf "│  Capability:  %-29s│\n" "$capability"
    echo "├─────────────────────────────────────────────┤"
    echo "│  Recommendations:                           │"

    while IFS= read -r line; do
        printf "│  %-42s│\n" "$line"
    done < <(get_env_recommendations)

    echo "└─────────────────────────────────────────────┘"
}

# If executed directly (not sourced), print info
# Compatible with bash and zsh
if [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    print_env_info
elif [[ -n "${ZSH_EVAL_CONTEXT:-}" ]] && [[ "$ZSH_EVAL_CONTEXT" =~ :file$ ]]; then
    # Being sourced in zsh - do nothing
    :
elif [[ -z "${BASH_SOURCE[0]:-}" ]] && [[ -z "${ZSH_EVAL_CONTEXT:-}" ]]; then
    # Direct execution in unknown shell
    print_env_info
fi
