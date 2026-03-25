#!/usr/bin/env bash
# lib/common.sh - Shared utilities for Ralph CLI
# Extracted from scripts/ralph to enable modular composition
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"

# Guard against double-sourcing
[[ -n "${_RALPH_LIB_COMMON_LOADED:-}" ]] && return 0
_RALPH_LIB_COMMON_LOADED=1

# ═══════════════════════════════════════════════════════════════════════════════
# COLORS
# ═══════════════════════════════════════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ═══════════════════════════════════════════════════════════════════════════════
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $1"; }

# ═══════════════════════════════════════════════════════════════════════════════
# PATH DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

# Find the repository root from any script location
ralph_repo_root() {
    local dir="${1:-$(pwd)}"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]] && [[ -f "$dir/CLAUDE.md" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# Standard directories
RALPH_HOME="${RALPH_HOME:-${HOME}/.ralph}"
RALPH_CLAUDE_DIR="${HOME}/.claude"
RALPH_INSTALL_DIR="${HOME}/.local/bin"

# ═══════════════════════════════════════════════════════════════════════════════
# RALPHRC CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

# Load .ralphrc from current project or defaults
load_ralphrc() {
    local project_dir="${1:-.}"

    # Resolve project_dir to absolute path
    project_dir=$(cd "$project_dir" 2>/dev/null && pwd) || project_dir="$(pwd)"

    # Set defaults before sourcing .ralphrc
    export CB_NO_PROGRESS_THRESHOLD="${CB_NO_PROGRESS_THRESHOLD:-3}"
    export CB_SAME_ERROR_THRESHOLD="${CB_SAME_ERROR_THRESHOLD:-5}"
    export CB_COOLDOWN_MINUTES="${CB_COOLDOWN_MINUTES:-30}"
    export CB_AUTO_RESET="${CB_AUTO_RESET:-false}"

    # Load project .ralphrc if it exists (overrides defaults)
    if [[ -f "${project_dir}/.ralphrc" ]]; then
        # shellcheck disable=SC1091
        source "${project_dir}/.ralphrc"
    fi

    # Map .ralphrc variable names to RALPH_* exports
    # (.ralphrc uses PROJECT_NAME; lib/ uses RALPH_PROJECT_NAME)
    export RALPH_PROJECT_NAME="${PROJECT_NAME:-${RALPH_PROJECT_NAME:-$(basename "$project_dir")}}"
    export RALPH_PROJECT_TYPE="${PROJECT_TYPE:-${RALPH_PROJECT_TYPE:-unknown}}"
    export RALPH_MAX_CALLS_PER_HOUR="${MAX_CALLS_PER_HOUR:-${RALPH_MAX_CALLS_PER_HOUR:-100}}"
    export RALPH_TIMEOUT_MINUTES="${CLAUDE_TIMEOUT_MINUTES:-${RALPH_TIMEOUT_MINUTES:-15}}"
    export RALPH_MAX_ITERATIONS="${MAX_ITERATIONS:-${RALPH_MAX_ITERATIONS:-25}}"
    export RALPH_SESSION_CONTINUITY="${SESSION_CONTINUITY:-${RALPH_SESSION_CONTINUITY:-true}}"
    export RALPH_SESSION_EXPIRY_HOURS="${SESSION_EXPIRY_HOURS:-${RALPH_SESSION_EXPIRY_HOURS:-24}}"
    export RALPH_VERBOSE="${RALPH_VERBOSE:-false}"

    [[ -f "${project_dir}/.ralphrc" ]]  # return 0 if .ralphrc was found
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECKING
# ═══════════════════════════════════════════════════════════════════════════════

# Check if a command exists, return 0/1
has_cmd() { command -v "$1" &>/dev/null; }

# Require a command or exit with helpful message
require_cmd() {
    local cmd="$1"
    local purpose="${2:-}"
    if ! has_cmd "$cmd"; then
        log_error "Required tool not found: $cmd"
        [[ -n "$purpose" ]] && echo "  Needed for: $purpose"
        return 1
    fi
}

# Check multiple commands, return list of missing ones
check_cmds() {
    local missing=()
    for cmd in "$@"; do
        has_cmd "$cmd" || missing+=("$cmd")
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${missing[*]}"
        return 1
    fi
    return 0
}
