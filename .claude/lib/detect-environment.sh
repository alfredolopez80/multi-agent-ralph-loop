#!/usr/bin/env bash
# detect-environment.sh v3.0.1 - Execution environment detection
#
# Restored from .claude/backup-before-cleanup-20260127-170141/hooks/
# and extended to cover Minimax as a third API backend.
#
# DUAL MODE
#   Sourced  -> exports functions (no stdout, idempotent cache)
#   Executed -> prints single-line JSON
#
# JSON shape (exec mode)
#   {"type":"...","capabilities":"...","entrypoint":"..."}
#
# Detected types
#   claude-cli   Claude Code CLI (native)
#   vscode       Claude VS Code extension
#   cursor       Claude Cursor extension
#   glm-api      GLM-4.7 / Zhipu via Z.AI or BigModel endpoint
#   minimax-api  MiniMax M-series via MiniMax API endpoint
#   unknown      fallback
#
# Capability buckets
#   full     claude-cli
#   limited  vscode / cursor
#   api      glm-api / minimax-api
#   none     unknown
#
# Sourced function API (stable names used by current callers)
#   detect_environment        populate cache + export RALPH_ENV_* vars
#   get_env_type              prints RALPH_ENV_TYPE (e.g. "claude-cli")
#   get_capabilities          prints RALPH_CAPABILITIES (e.g. "full")
#   get_entrypoint_name       prints entrypoint ("cli"/"api"/"vscode"/...)

set -uo pipefail
umask 077

# --- Constants -------------------------------------------------------------
ENV_CLAUDE_CLI="claude-cli"
ENV_VSCODE="vscode"
ENV_CURSOR="cursor"
ENV_GLM_API="glm-api"
ENV_MINIMAX_API="minimax-api"
ENV_UNKNOWN="unknown"

CAP_FULL="full"
CAP_LIMITED="limited"
CAP_API="api"
CAP_NONE="none"

# --- Cache slots (set -u safe) --------------------------------------------
RALPH_ENV_TYPE="${RALPH_ENV_TYPE:-}"
RALPH_CAPABILITIES="${RALPH_CAPABILITIES:-}"
RALPH_ENTRYPOINT="${RALPH_ENTRYPOINT:-}"
_RALPH_ENV_DETECTED="${_RALPH_ENV_DETECTED:-}"

# --- Detection primitives --------------------------------------------------
_env_base_url_is_zai() {
    local url="${ANTHROPIC_BASE_URL:-}"
    [[ "$url" =~ api\.z\.ai ]] || \
    [[ "$url" =~ open\.bigmodel\.cn ]] || \
    [[ "$url" =~ dev\.bigmodel\.cn ]]
}

_env_base_url_is_minimax() {
    local url="${ANTHROPIC_BASE_URL:-}"
    [[ "$url" =~ api\.minimaxi?\.chat ]] || \
    [[ "$url" =~ api\.minimax\.io ]]
}

_env_glm_marker_present() {
    local state_dir="${RALPH_DIR:-${HOME}/.ralph}/state"
    [[ -f "${state_dir}/glm-active" ]]
}

_env_minimax_marker_present() {
    local state_dir="${RALPH_DIR:-${HOME}/.ralph}/state"
    [[ -f "${state_dir}/minimax-active" ]]
}

_env_model_is_glm() {
    [[ "${ANTHROPIC_MODEL:-}" =~ glm-[0-9] ]]
}

_env_model_is_minimax() {
    local m="${ANTHROPIC_MODEL:-}"
    [[ "$m" =~ ^[Mm]ini[Mm]ax ]] || [[ "$m" =~ ^M2 ]] || [[ "$m" =~ abab ]]
}

# --- Main classification ---------------------------------------------------
detect_environment_type() {
    # Priority 1: explicit Minimax endpoint + auth
    if _env_base_url_is_minimax; then
        if [[ -n "${MINIMAX_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
            echo "$ENV_MINIMAX_API"; return 0
        fi
    fi

    # Priority 2: explicit Minimax model
    if _env_model_is_minimax && [[ -n "${MINIMAX_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
        echo "$ENV_MINIMAX_API"; return 0
    fi

    # Priority 3: Minimax marker file
    if _env_minimax_marker_present; then
        echo "$ENV_MINIMAX_API"; return 0
    fi

    # Priority 4: GLM/Zhipu endpoint + GLM model + auth
    if _env_base_url_is_zai; then
        if [[ -n "${Z_AI_API_KEY:-}${ZAI_API_KEY:-}${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
            if _env_model_is_glm; then
                echo "$ENV_GLM_API"; return 0
            fi
        fi
    fi

    # Priority 5: GLM marker file (explicit GLM session without base_url override)
    if _env_glm_marker_present; then
        echo "$ENV_GLM_API"; return 0
    fi

    # Priority 6: Claude Code entrypoint
    case "${CLAUDE_CODE_ENTRYPOINT:-}" in
        cli)    echo "$ENV_CLAUDE_CLI"; return 0 ;;
        vscode) echo "$ENV_VSCODE"; return 0 ;;
        cursor) echo "$ENV_CURSOR"; return 0 ;;
    esac

    # Priority 7: editor-specific env vars
    if [[ -n "${VSCODE_PID:-}${VSCODE_CWD:-}" ]]; then
        echo "$ENV_VSCODE"; return 0
    fi
    if [[ -n "${CURSOR_TRACE_ID:-}" ]]; then
        echo "$ENV_CURSOR"; return 0
    fi

    # Priority 8: Claude Code session markers
    if [[ -n "${CLAUDE_SESSION_ID:-}${CLAUDE_PROJECT_DIR:-}${CLAUDE_PROJECT_ID:-}" ]]; then
        echo "$ENV_CLAUDE_CLI"; return 0
    fi

    echo "$ENV_UNKNOWN"
}

determine_capabilities() {
    case "$1" in
        "$ENV_CLAUDE_CLI")                   echo "$CAP_FULL" ;;
        "$ENV_VSCODE"|"$ENV_CURSOR")         echo "$CAP_LIMITED" ;;
        "$ENV_GLM_API"|"$ENV_MINIMAX_API")   echo "$CAP_API" ;;
        *)                                   echo "$CAP_NONE" ;;
    esac
}

get_entrypoint() {
    case "$1" in
        "$ENV_CLAUDE_CLI")                   echo "cli" ;;
        "$ENV_VSCODE")                       echo "vscode" ;;
        "$ENV_CURSOR")                       echo "cursor" ;;
        "$ENV_GLM_API"|"$ENV_MINIMAX_API")   echo "api" ;;
        *)                                   echo "unknown" ;;
    esac
}

# --- Modern API (idempotent, cached) ---------------------------------------
detect_environment() {
    [[ -n "$_RALPH_ENV_DETECTED" ]] && return 0
    RALPH_ENV_TYPE="$(detect_environment_type)"
    RALPH_CAPABILITIES="$(determine_capabilities "$RALPH_ENV_TYPE")"
    RALPH_ENTRYPOINT="$(get_entrypoint "$RALPH_ENV_TYPE")"
    _RALPH_ENV_DETECTED="1"
    export RALPH_ENV_TYPE RALPH_CAPABILITIES RALPH_ENTRYPOINT _RALPH_ENV_DETECTED
}

get_env_type()          { detect_environment; printf '%s\n' "$RALPH_ENV_TYPE"; }
get_capabilities()      { detect_environment; printf '%s\n' "$RALPH_CAPABILITIES"; }
get_entrypoint_name()   { detect_environment; printf '%s\n' "$RALPH_ENTRYPOINT"; }

# --- Exec mode: emit JSON --------------------------------------------------
if [[ "${BASH_SOURCE[0]:-}" == "${0}" ]]; then
    detect_environment
    if command -v jq >/dev/null 2>&1; then
        jq -cn \
            --arg type "$RALPH_ENV_TYPE" \
            --arg capabilities "$RALPH_CAPABILITIES" \
            --arg entrypoint "$RALPH_ENTRYPOINT" \
            '{type:$type, capabilities:$capabilities, entrypoint:$entrypoint}'
    else
        printf '{"type":"%s","capabilities":"%s","entrypoint":"%s"}\n' \
            "$RALPH_ENV_TYPE" "$RALPH_CAPABILITIES" "$RALPH_ENTRYPOINT"
    fi
fi
