#!/usr/bin/env bash
#===============================================================================
# validate-hooks-registration.sh
# Validates that ALL hooks are properly registered in settings.json
#
# VERSION: 2.0.0
# DATE: 2026-02-15
# PURPOSE: Comprehensive hook registration validation
#
# Usage:
#   ./scripts/validate-hooks-registration.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All required hooks registered
#   1: Missing required hooks
#   2: Cannot run checks
#===============================================================================

set -euo pipefail

# Shared colors, counters and the zero-checks verdict guard.
_VC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Requires bash 4+: the result tables below are associative arrays. Declared here so
# the library can enforce it; bash-3-clean callers of the same library are unaffected.
VC_REQUIRE_BASH4=1
source "${_VC_DIR}/lib/validation-common.sh"

# Output format
FORMAT="${FORMAT:-text}"
VERBOSE="${VERBOSE:-0}"

# Settings path - use primary location
SETTINGS_PATH="${HOME}/.claude/settings.json"

# Hooks are registered in settings.json with absolute paths into the MAIN repo, so the
# comparison must resolve there. `--show-toplevel` returns the worktree when run from
# one, which made every path mismatch and reported 0/49 passing. `--git-common-dir`
# points at the main repo's .git in both cases.
GIT_COMMON_DIR="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [[ -n "$GIT_COMMON_DIR" ]]; then
    PROJECT_ROOT="$(dirname "$GIT_COMMON_DIR")"
else
    # Fallback a la ubicacion del propio script, no al cwd: invocado desde fuera
    # de un repo (o desde un tarball sin .git) `pwd` apuntaba a un directorio
    # cualquiera y el validador no encontraba ni un hook.
    PROJECT_ROOT="$(cd "${_VC_DIR}/.." && pwd)"
fi
HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: validate-hooks-registration.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - All hooks registered in settings.json
  - All hook scripts exist at specified paths
  - All hook scripts are executable
  - No orphan hooks (scripts without registration)
  - No missing hooks (registration without script)

Exit codes:
  0  All hooks registered correctly
  1  Some hooks missing or misconfigured
  2  Cannot run checks
EOF
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

#===============================================================================
# HOOK DEFINITIONS (from PRD)
#===============================================================================

# Format: "event:matcher||script||description" (using double pipe as delimiter)
# Using array instead of associative for order preservation
# Format: "event:matcher||script||description" (double pipe separates FIELDS).
#
# The matcher uses a SINGLE pipe, exactly as Claude Code writes it: `Edit|Write|Bash`.
# Earlier revisions wrote `Edit||Write||Bash`, which collided with the field separator:
# the parser cut at the first `||`, read `Edit` as the matcher and `Write` as the script
# name, and reported 13 bogus "Script not found: .../hooks/Write" failures.
#
# This list is deliberately limited to hooks that are CRITICAL and verified as
# registered. It used to enumerate 49 entries, most pointing at scripts long since
# archived, so every run reported failures that meant nothing. Exhaustive
# "is every registered hook present?" coverage lives in
# tests/test_registered_hooks_exist.py, which needs no maintenance.
HOOK_DEFINITIONS=(
    # Security guards (PreToolUse on Bash)
    "PreToolUse:Bash||git-safety-guard.py||Blocks destructive git/fs commands"
    "PreToolUse:Bash||repo-boundary-guard.sh||Prevents work outside the repo"

    # Session lifecycle
    "SessionStart:*||wake-up-layer-stack.sh||Loads L0+L1 memory layers"

    # Quality gates
    "TaskCompleted:*||task-completed-quality-gate.sh||Quality gate before completion"

    # Task and state tracking
    "TaskCompleted:*||task-list-projection.sh||Event-sourced task projection"
)

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A RESULTS
declare -A MESSAGES
PASSED=0
FAILED=0
WARNINGS=0
TOTAL=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Check if hook script exists
hook_file_exists() {
    local script="$1"
    [[ -f "${HOOKS_DIR}/${script}" ]]
}

# Check if hook script is executable
hook_is_executable() {
    local script="$1"
    [[ -x "${HOOKS_DIR}/${script}" ]]
}

# Check if hook is registered in settings.json
#
# Compara por FICHERO FISICO (readlink -f), no por string: ~/.claude/hooks es un
# symlink al repo, asi que el mismo hook puede registrarse por dos rutas distintas
# (la comparacion literal daba falsos "not registered"). E itera TODOS los objetos
# del matcher: `.[0].hooks` ignoraba bloques adicionales con el mismo matcher.
hook_is_registered() {
    local event="$1"
    local matcher="$2"
    local script="$3"

    local want cmd resolved
    want="$(readlink -f "${HOOKS_DIR}/${script}" 2>/dev/null)" || return 1

    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] || continue
        resolved="$(readlink -f "$cmd" 2>/dev/null)" || continue
        [[ "$resolved" == "$want" ]] && return 0
    done < <(jq -r --arg event "$event" --arg matcher "$matcher" '
        .hooks[$event] // [] |
        map(select(.matcher == $matcher)) |
        .[].hooks[].command
    ' "$SETTINGS_PATH" 2>/dev/null)

    return 1
}

# Sweep EVERY registration in settings.json, not just HOOK_DEFINITIONS.
#
# HOOK_DEFINITIONS above covers the 9 hooks that must exist; settings.json holds
# ~79 registrations. Nothing asserted that the other ~70 resolve to a real file.
# A registration pointing at a deleted script does not error loudly — the hook
# simply never fires, and the capability disappears without a signal.
#
# Zero registrations is a FAILURE, not a pass: it means the query found nothing,
# which is indistinguishable from "settings.json has no hooks at all".
validate_all_registrations() {
    local cmd tok path total=0 dead=0 dead_list=""

    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] || continue
        total=$((total + 1))
        path=""
        for tok in $cmd; do
            case "$tok" in
                -*) continue ;;
                */*.sh|*/*.py|*/*.mjs|*/*.js) path="$tok"; break ;;
            esac
        done
        [[ -n "$path" ]] || continue
        path="${path//\$CLAUDE_PROJECT_DIR/$PROJECT_ROOT}"
        path="${path//\$\{CLAUDE_PROJECT_DIR\}/$PROJECT_ROOT}"
        path="${path//\$HOME/$HOME}"
        path="${path//\"/}"
        if [[ ! -f "$path" ]]; then
            dead=$((dead + 1))
            dead_list="${dead_list}${dead_list:+, }${path}"
        fi
    done < <(jq -r '.hooks // {} | to_entries[] | .value[]? | .hooks[]? | .command // empty' \
                "$SETTINGS_PATH" 2>/dev/null)

    local status message
    if [[ "$total" -eq 0 ]]; then
        status="FAIL"
        message="0 registrations found — the sweep checked nothing (settings.json shape changed?)"
    elif [[ "$dead" -gt 0 ]]; then
        status="FAIL"
        message="${dead}/${total} registrations point at a missing file: ${dead_list}"
    else
        status="PASS"
        message="all ${total} registrations resolve to an existing file"
    fi

    RESULTS["_all_registrations"]="$status"
    MESSAGES["_all_registrations"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
    esac
    TOTAL=$((TOTAL + 1))
}

# Validate a single hook
validate_hook() {
    local def="$1"

    # Parse using || delimiter
    # Format: "event:matcher||script||description"
    # Example: "SessionStart:*||auto-migrate-plan-state.sh||Plan state migration"
    # Example: "PostToolUse:*||audit-secrets.js||Secret-pattern audit"

    local event_matcher="${def%%||*}"
    local rest="${def#*||}"
    local script="${rest%%||*}"
    local description="${rest#*||}"

    # Extract event (before colon) and matcher (after colon)
    local event="${event_matcher%%:*}"
    local matcher="${event_matcher#*:}"

    local status=""
    local message=""

    # Check if file exists
    if ! hook_file_exists "$script"; then
        status="FAIL"
        message="Script not found: ${HOOKS_DIR}/${script}"
    # Check if executable
    elif ! hook_is_executable "$script"; then
        status="WARN"
        message="Script not executable: ${script}"
    # Check if registered
    elif ! hook_is_registered "$event" "$matcher" "$script"; then
        status="FAIL"
        message="Not registered in settings.json (Event: $event, Matcher: $matcher)"
    else
        status="PASS"
        message="$description"
    fi

    RESULTS["$script"]="$status"
    MESSAGES["$script"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac
    TOTAL=$((TOTAL + 1))
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Hooks Registration Validation - v2.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Settings: $SETTINGS_PATH"
    echo "Hooks Dir: $HOOKS_DIR"
    echo ""

    # Group by event type
    local current_event=""

    for def in "${HOOK_DEFINITIONS[@]}"; do
        local event_matcher="${def%%||*}"
        local event="${event_matcher%%:*}"
        local rest="${def#*||}"
        local script="${rest%%||*}"
        local status="${RESULTS[$script]}"
        local message="${MESSAGES[$script]}"

        if [[ "$event" != "$current_event" ]]; then
            current_event="$event"
            echo -e "${BLUE}$event${NC}"
            echo "───────────────────────────────────────────────────────────────"
        fi

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $script: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $script: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $script: $message" ;;
        esac
    done

    # Sweep over every registration, beyond the required set above
    if [[ -n "${RESULTS[_all_registrations]:-}" ]]; then
        echo ""
        echo -e "${BLUE}All registrations${NC}"
        echo "───────────────────────────────────────────────────────────────"
        case "${RESULTS[_all_registrations]}" in
            PASS) echo -e "${GREEN}✓${NC} settings.json: ${MESSAGES[_all_registrations]}" ;;
            FAIL) echo -e "${RED}✗${NC} settings.json: ${MESSAGES[_all_registrations]}" ;;
        esac
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "   SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Total:   $TOTAL"
    echo "  Passed:  $PASSED"
    echo "  Failed:  $FAILED"
    echo "  Warnings: $WARNINGS"
    echo ""

    # "Nothing failed" is not "everything passed": a run that checked zero hooks proves
    # nothing, and its green verdict is indistinguishable from a healthy one.
    if [[ $((PASSED + FAILED + WARNINGS)) -eq 0 ]]; then
        echo -e "${RED}✗ FATAL: zero checks executed — no verdict can be declared${NC}" >&2
        return 1
    fi

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All required hooks registered correctly${NC}"
        return 0
    else
        echo -e "${RED}✗ Some hooks are missing or misconfigured${NC}"
        return 1
    fi
}

# Print JSON output
print_json_output() {
    local overall_status="pass"
    [[ $FAILED -gt 0 ]] && overall_status="fail"

    cat << EOF
{
  "status": "$overall_status",
  "settings_path": "$SETTINGS_PATH",
  "hooks_dir": "$HOOKS_DIR",
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED,
    "warnings": $WARNINGS
  },
  "hooks": {
EOF

    local first=true
    for def in "${HOOK_DEFINITIONS[@]}"; do
        local event_matcher="${def%%||*}"
        local rest="${def#*||}"
        local script="${rest%%||*}"
        local event="${event_matcher%%:*}"
        local matcher="${event_matcher#*:}"

        $first || echo ","
        first=false
        cat << EOF
    "$script": {
      "event": "$event",
      "matcher": "$matcher",
      "status": "${RESULTS[$script]}",
      "message": "${MESSAGES[$script]}"
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check if settings.json exists
if [[ ! -f "$SETTINGS_PATH" ]]; then
    echo "Settings file not found: $SETTINGS_PATH" >&2
    exit 2
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
    echo "jq is required but not installed" >&2
    exit 2
fi

# Validate all hooks
for def in "${HOOK_DEFINITIONS[@]}"; do
    validate_hook "$def"
done

# Sweep every registration, not only the required ones
validate_all_registrations

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac
