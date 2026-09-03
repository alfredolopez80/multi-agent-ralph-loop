#!/usr/bin/env bash
# detect-environment.sh v3.0.1 - Execution environment detection
#
# Restored from .claude/backup-before-cleanup-20260127-170141/hooks/
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
#   unknown      fallback
#
# This library detects the ENTRYPOINT (which client is running), never a model
# or a provider. The model is whatever the session runs.
#
# Capability buckets
#   full     claude-cli
#   limited  vscode / cursor
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
ENV_UNKNOWN="unknown"

CAP_FULL="full"
CAP_LIMITED="limited"
CAP_NONE="none"

# --- Cache slots (set -u safe) --------------------------------------------
RALPH_ENV_TYPE="${RALPH_ENV_TYPE:-}"
RALPH_CAPABILITIES="${RALPH_CAPABILITIES:-}"
RALPH_ENTRYPOINT="${RALPH_ENTRYPOINT:-}"
_RALPH_ENV_DETECTED="${_RALPH_ENV_DETECTED:-}"

# --- Detection primitives --------------------------------------------------
# TTL for marker files (minutes). Markers older than this are treated as
# stale and ignored. Prevents a stale marker file from
# mis-classifying months-old sessions when the user is actually
# on native Claude.
_RALPH_MARKER_TTL_MIN="${_RALPH_MARKER_TTL_MIN:-60}"

_env_marker_is_fresh() {
    local path="$1"
    [[ -f "$path" ]] || return 1
    local mtime now age
    mtime=$(stat -c "%Y" "$path" 2>/dev/null || stat -f "%m" "$path" 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$(( (now - mtime) / 60 ))
    [[ "$age" -lt "$_RALPH_MARKER_TTL_MIN" ]]
}

_env_has_anthropic_base_url() {
    [[ -n "${ANTHROPIC_BASE_URL:-}" ]]
}

# --- Main classification ---------------------------------------------------
# PRIORITY ORDER (fix v3.0.2):
#   Active env var overrides > explicit Claude Code signals > editor vars
#   > fresh marker files > unknown.
# Rationale: user injects ANTHROPIC_BASE_URL + ANTHROPIC_MODEL at CLI
# launch. If those are unset and CLAUDE_CODE_ENTRYPOINT=cli, we are on
# native Claude regardless of stale marker files sitting in ~/.ralph/.
detect_environment_type() {
    # P2: Claude Code entrypoint is authoritative when no API override exists
    case "${CLAUDE_CODE_ENTRYPOINT:-}" in
        cli)    echo "$ENV_CLAUDE_CLI"; return 0 ;;
        vscode) echo "$ENV_VSCODE"; return 0 ;;
        cursor) echo "$ENV_CURSOR"; return 0 ;;
    esac

    # P3: Claude Code session markers
    if [[ -n "${CLAUDE_SESSION_ID:-}${CLAUDE_PROJECT_DIR:-}${CLAUDE_PROJECT_ID:-}" ]]; then
        echo "$ENV_CLAUDE_CLI"; return 0
    fi

    # P4: Editor env vars
    if [[ -n "${VSCODE_PID:-}${VSCODE_CWD:-}" ]]; then
        echo "$ENV_VSCODE"; return 0
    fi
    if [[ -n "${CURSOR_TRACE_ID:-}" ]]; then
        echo "$ENV_CURSOR"; return 0
    fi

    # P5: Model-only hints (no base_url, no entrypoint) + matching auth
    # P6: Fresh marker files (TTL-bounded, fallback for headless scripts
    # launched outside Claude Code)
    echo "$ENV_UNKNOWN"
}

determine_capabilities() {
    case "$1" in
        "$ENV_CLAUDE_CLI")                   echo "$CAP_FULL" ;;
        "$ENV_VSCODE"|"$ENV_CURSOR")         echo "$CAP_LIMITED" ;;
        *)                                   echo "$CAP_NONE" ;;
    esac
}

get_entrypoint() {
    case "$1" in
        "$ENV_CLAUDE_CLI")                   echo "cli" ;;
        "$ENV_VSCODE")                       echo "vscode" ;;
        "$ENV_CURSOR")                       echo "cursor" ;;
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
