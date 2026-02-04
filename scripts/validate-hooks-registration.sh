#!/usr/bin/env bash
#===============================================================================
# validate-hooks-registration.sh
# Validates that critical hooks are registered in settings.json
#
# VERSION: 1.0.0
# DATE: 2026-02-04
# PURPOSE: Prevent regression of missing security hooks
#
# Usage:
#   ./validate-hooks-registration.sh [--verbose]
#
# Exit codes:
#   0: All critical hooks registered
#   1: Missing critical hooks
#   2: Invalid settings.json
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Settings path
SETTINGS_PATH="${HOME}/.claude-sneakpeek/zai/config/settings.json"
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"

# Verbose flag
VERBOSE="${VERBOSE:-0}"
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

#===============================================================================
# CRITICAL HOOKS THAT MUST BE REGISTERED
#===============================================================================

declare -A CRITICAL_HOOKS=(
    # Security hooks (MUST HAVE)
    ["git-safety-guard.py"]="PreToolUse:Bash"
    ["repo-boundary-guard.sh"]="PreToolUse:Bash"

    # Quality hooks (SHOULD HAVE)
    ["status-auto-check.sh"]="PostToolUse:Edit|Write|Bash"
    ["console-log-detector.sh"]="PostToolUse:Edit|Write|Bash"
    ["adversarial-auto-trigger.sh"]="PostToolUse:Task"
)

#===============================================================================
# FUNCTIONS
#===============================================================================

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_verbose() {
    [[ $VERBOSE -eq 1 ]] && echo "  $1"
}

# Check if hook file exists
hook_file_exists() {
    local hook="$1"
    [[ -f "${HOOKS_DIR}/${hook}" ]]
}

# Check if hook is registered in settings.json
hook_is_registered() {
    local hook="$1"
    local expected_event="$2"
    local expected_matcher="$3"

    local hook_path="${PROJECT_ROOT}/.claude/hooks/${hook}"

    # Search for the hook in settings.json
    local found
    found=$(jq -r --arg hook "$hook_path" \
        '.hooks // {} | to_entries[] |
         select(.key == ($expected_event // "null")) |
         .value[] |
         select(.matcher == ($expected_matcher // "null")) |
         .hooks[] |
         select(.command == $hook) |
         .command' \
        "$SETTINGS_PATH" 2>/dev/null || echo "")

    [[ -n "$found" ]]
}

# Validate a single hook
validate_hook() {
    local hook="$1"
    local event_matcher="$2"
    local event="${event_matcher%%:*}"
    local matcher="${event_matcher##*:}"

    local status="PASS"
    local issues=()

    # Check if file exists
    if ! hook_file_exists "$hook"; then
        status="FAIL"
        issues+=("File not found: ${HOOKS_DIR}/${hook}")
    fi

    # Check if registered
    if ! hook_is_registered "$hook" "$event" "$matcher"; then
        status="FAIL"
        issues+=("Not registered in ${SETTINGS_PATH}")
        issues+=("  Expected: Event=${event}, Matcher=${matcher}")
    fi

    case "$status" in
        PASS)
            log_info "$hook"
            log_verbose "Event: $event | Matcher: $matcher"
            return 0
            ;;
        FAIL)
            log_error "$hook"
            for issue in "${issues[@]}"; do
                echo "    $issue"
            done
            return 1
            ;;
    esac
}

#===============================================================================
# MAIN VALIDATION
#===============================================================================

main() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Hook Registration Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Check if settings.json exists
    if [[ ! -f "$SETTINGS_PATH" ]]; then
        log_error "Settings file not found: $SETTINGS_PATH"
        exit 2
    fi

    # Check if jq is available
    if ! command -v jq &>/dev/null; then
        log_error "jq is required but not installed"
        exit 2
    fi

    local total=0
    local passed=0
    local failed=0

    # Validate each critical hook
    for hook in "${!CRITICAL_HOOKS[@]}"; do
        ((total++))
        event_matcher="${CRITICAL_HOOKS[$hook]}"

        if validate_hook "$hook" "$event_matcher"; then
            ((passed++))
        else
            ((failed++))
        fi
    done

    echo ""
    echo "───────────────────────────────────────────────────────────────"
    echo "Results:"
    echo "  Total:   $total"
    echo "  Passed:  $passed"
    echo "  Failed:  $failed"
    echo "───────────────────────────────────────────────────────────────"

    # Exit with appropriate code
    if [[ $failed -eq 0 ]]; then
        log_info "All critical hooks registered correctly!"
        echo ""
        return 0
    else
        log_error "Some critical hooks are missing!"
        echo ""
        echo "To fix missing hooks, see: docs/bugs/HOOK_REGISTRATION_FIX_v2.83.1.md"
        return 1
    fi
}

#===============================================================================
# ENTRY POINT
#===============================================================================

main "$@"
