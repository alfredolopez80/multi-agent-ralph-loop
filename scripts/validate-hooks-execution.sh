#!/usr/bin/env bash
#===============================================================================
# validate-hooks-execution.sh - Validates hook execution with mock inputs
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Test each hook individually with timeout and capture results
#
# Usage:
#   ./scripts/validate-hooks-execution.sh [--format json|text] [--timeout SECONDS]
#
# Exit codes:
#   0: All hooks executed successfully
#   1: Some hooks failed or timed out
#   2: Cannot run validation
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
FORMAT="${FORMAT:-text}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-30}"
VERBOSE="${VERBOSE:-0}"

# Project paths
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
HOOKS_DIR="${PROJECT_ROOT}/.claude/hooks"
FIXTURES_DIR="${PROJECT_ROOT}/tests/installer/fixtures/mock-tool-inputs"
RESULTS_DIR="${PROJECT_ROOT}/tests/installer/results"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_SECONDS="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: validate-hooks-execution.sh [OPTIONS]

Options:
  --format FORMAT    Output format: text (default) or json
  --timeout SECONDS  Timeout per hook (default: 30)
  --verbose, -v      Show detailed output
  --help, -h         Show this help message

Description:
  Tests each hook with mock inputs and validates:
  - Hook executes without errors
  - Hook completes within timeout
  - Hook outputs valid JSON (where applicable)

Exit codes:
  0  All hooks executed successfully
  1  Some hooks failed or timed out
  2  Cannot run validation
EOF
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

#===============================================================================
# HOOK TO INPUT MAPPING
#===============================================================================

# Map hook scripts to their event types and input fixtures
declare -A HOOK_INPUT_MAP
HOOK_INPUT_MAP["git-safety-guard.py"]="pre-tool-use-bash.json"
HOOK_INPUT_MAP["repo-boundary-guard.sh"]="pre-tool-use-bash.json"
HOOK_INPUT_MAP["context-warning.sh"]="user-prompt-submit.json"
HOOK_INPUT_MAP["glm5-subagent-stop.sh"]="subagent-stop.json"
HOOK_INPUT_MAP["pre-compact-handoff.sh"]="pre-compact.json"
HOOK_INPUT_MAP["auto-migrate-plan-state.sh"]="session-start.json"
HOOK_INPUT_MAP["session-start-restore-context.sh"]="session-start.json"

# Hooks that may not have specific inputs and should use empty input
declare -a HOOKS_WITH_EMPTY_INPUT=(
    "adversarial-auto-trigger.sh"
    "status-auto-check.sh"
    "progress-tracker.sh"
    "decision-extractor.sh"
)

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A HOOK_RESULTS
declare -A HOOK_MESSAGES
declare -A HOOK_STDERR
declare -A HOOK_EXIT_CODES
declare -A HOOK_DURATIONS

PASSED=0
FAILED=0
TIMEOUT=0
ERRORS=0
TOTAL=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Check if a hook should use empty input
uses_empty_input() {
    local hook="$1"
    for h in "${HOOKS_WITH_EMPTY_INPUT[@]}"; do
        [[ "$h" == "$hook" ]] && return 0
    done
    return 1
}

# Get input fixture for a hook
get_input_fixture() {
    local hook="$1"
    local fixture="${HOOK_INPUT_MAP[$hook]:-}"

    if [[ -n "$fixture" ]]; then
        echo "${FIXTURES_DIR}/${fixture}"
    else
        echo ""
    fi
}

# Test a single hook
test_hook() {
    local hook="$1"
    local hook_path="${HOOKS_DIR}/${hook}"
    local start_time end_time duration
    local exit_code=0
    local stdout_output=""
    local stderr_output=""
    local fixture=""

    TOTAL=$((TOTAL + 1))

    # Check if hook exists
    if [[ ! -f "$hook_path" ]]; then
        HOOK_RESULTS["$hook"]="MISSING"
        HOOK_MESSAGES["$hook"]="Hook file not found"
        HOOK_EXIT_CODES["$hook"]="N/A"
        HOOK_DURATIONS["$hook"]="N/A"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    # Check if hook is executable
    if [[ ! -x "$hook_path" ]]; then
        HOOK_RESULTS["$hook"]="NOT_EXECUTABLE"
        HOOK_MESSAGES["$hook"]="Hook is not executable"
        HOOK_EXIT_CODES["$hook"]="N/A"
        HOOK_DURATIONS["$hook"]="N/A"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    # Get input fixture
    fixture=$(get_input_fixture "$hook")

    # Create temp file for stderr
    local stderr_file
    stderr_file=$(mktemp)

    # Execute hook with timeout
    start_time=$(date +%s%N 2>/dev/null || gdate +%s%N 2>/dev/null || echo "0")

    if [[ -n "$fixture" && -f "$fixture" ]]; then
        # Run with input fixture
        stdout_output=$(timeout "$TIMEOUT_SECONDS" "$hook_path" < "$fixture" 2>"$stderr_file") || exit_code=$?
    elif uses_empty_input "$hook"; then
        # Run with empty input
        stdout_output=$(timeout "$TIMEOUT_SECONDS" "$hook_path" < /dev/null 2>"$stderr_file") || exit_code=$?
    else
        # Run with minimal empty JSON input
        stdout_output=$(timeout "$TIMEOUT_SECONDS" echo '{}' | "$hook_path" 2>"$stderr_file") || exit_code=$?
    fi

    end_time=$(date +%s%N 2>/dev/null || gdate +%s%N 2>/dev/null || echo "0")

    # Calculate duration in milliseconds
    if [[ "$start_time" != "0" && "$end_time" != "0" ]]; then
        duration=$(( (end_time - start_time) / 1000000 ))
    else
        duration="N/A"
    fi

    # Capture stderr
    stderr_output=$(cat "$stderr_file" 2>/dev/null || echo "")
    rm -f "$stderr_file"

    # Store exit code
    HOOK_EXIT_CODES["$hook"]="$exit_code"
    HOOK_DURATIONS["$hook"]="${duration}ms"

    # Analyze result
    if [[ $exit_code -eq 124 ]]; then
        HOOK_RESULTS["$hook"]="TIMEOUT"
        HOOK_MESSAGES["$hook"]="Hook timed out after ${TIMEOUT_SECONDS}s"
        HOOK_STDERR["$hook"]="$stderr_output"
        TIMEOUT=$((TIMEOUT + 1))
        return 1
    elif [[ $exit_code -eq 126 ]]; then
        HOOK_RESULTS["$hook"]="EXEC_ERROR"
        HOOK_MESSAGES["$hook"]="Permission denied or command not executable"
        HOOK_STDERR["$hook"]="$stderr_output"
        ERRORS=$((ERRORS + 1))
        return 1
    elif [[ $exit_code -eq 127 ]]; then
        HOOK_RESULTS["$hook"]="NOT_FOUND"
        HOOK_MESSAGES["$hook"]="Command not found"
        HOOK_STDERR["$hook"]="$stderr_output"
        ERRORS=$((ERRORS + 1))
        return 1
    fi

    # Check if output is valid JSON (for hooks that should output JSON)
    if [[ -n "$stdout_output" ]]; then
        if ! echo "$stdout_output" | jq empty 2>/dev/null; then
            # Not valid JSON - but some hooks may output text
            if [[ "$VERBOSE" -eq 1 ]]; then
                HOOK_MESSAGES["$hook"]="Executed (non-JSON output)"
            else
                HOOK_MESSAGES["$hook"]="OK (text output)"
            fi
            HOOK_STDERR["$hook"]="$stderr_output"
            # Still consider it a pass if exit code is 0
            if [[ $exit_code -eq 0 ]]; then
                HOOK_RESULTS["$hook"]="PASS"
                PASSED=$((PASSED + 1))
                return 0
            else
                HOOK_RESULTS["$hook"]="FAIL"
                FAILED=$((FAILED + 1))
                return 1
            fi
        else
            # Valid JSON output
            HOOK_RESULTS["$hook"]="PASS"
            HOOK_MESSAGES["$hook"]="OK (JSON output)"
            HOOK_STDERR["$hook"]="$stderr_output"
            PASSED=$((PASSED + 1))
            return 0
        fi
    else
        # Empty output
        if [[ $exit_code -eq 0 ]]; then
            HOOK_RESULTS["$hook"]="PASS"
            HOOK_MESSAGES["$hook"]="OK (no output)"
            HOOK_STDERR["$hook"]="$stderr_output"
            PASSED=$((PASSED + 1))
            return 0
        else
            HOOK_RESULTS["$hook"]="FAIL"
            HOOK_MESSAGES["$hook"]="Failed with exit code $exit_code"
            HOOK_STDERR["$hook"]="$stderr_output"
            FAILED=$((FAILED + 1))
            return 1
        fi
    fi
}

# Get list of hooks to test
get_hooks_to_test() {
    # Core hooks that must be tested
    local core_hooks=(
        "git-safety-guard.py"
        "repo-boundary-guard.sh"
        "context-warning.sh"
        "glm5-subagent-stop.sh"
        "pre-compact-handoff.sh"
    )

    # Optional hooks (tested if they exist)
    local optional_hooks=(
        "auto-migrate-plan-state.sh"
        "session-start-restore-context.sh"
        "adversarial-auto-trigger.sh"
        "status-auto-check.sh"
        "progress-tracker.sh"
        "decision-extractor.sh"
        "auto-background-swarm.sh"
        "parallel-explore.sh"
        "recursive-decompose.sh"
        "code-review-auto.sh"
    )

    # First output core hooks
    for hook in "${core_hooks[@]}"; do
        echo "$hook"
    done

    # Then output optional hooks that exist
    for hook in "${optional_hooks[@]}"; do
        if [[ -f "${HOOKS_DIR}/${hook}" ]]; then
            echo "$hook"
        fi
    done
}

# Print text output
print_text_output() {
    echo "=============================================================================="
    echo "   Hook Execution Validation - v1.0.0"
    echo "=============================================================================="
    echo ""
    echo "Hooks Dir: $HOOKS_DIR"
    echo "Fixtures Dir: $FIXTURES_DIR"
    echo "Timeout: ${TIMEOUT_SECONDS}s"
    echo ""

    # Print results
    for hook in $(get_hooks_to_test); do
        local result="${HOOK_RESULTS[$hook]:-SKIPPED}"
        local message="${HOOK_MESSAGES[$hook]:-}"
        local exit_code="${HOOK_EXIT_CODES[$hook]:-}"
        local duration="${HOOK_DURATIONS[$hook]:-}"

        case "$result" in
            PASS)
                echo -e "${GREEN}[PASS]${NC} $hook (${duration})"
                [[ "$VERBOSE" -eq 1 ]] && echo "       $message"
                ;;
            FAIL)
                echo -e "${RED}[FAIL]${NC} $hook (${duration})"
                echo "       Exit: $exit_code - $message"
                [[ "$VERBOSE" -eq 1 && -n "${HOOK_STDERR[$hook]:-}" ]] && echo "       Stderr: ${HOOK_STDERR[$hook]}"
                ;;
            TIMEOUT)
                echo -e "${YELLOW}[TIMEOUT]${NC} $hook"
                echo "       $message"
                ;;
            MISSING|NOT_EXECUTABLE|EXEC_ERROR|NOT_FOUND)
                echo -e "${RED}[$result]${NC} $hook"
                echo "       $message"
                ;;
            SKIPPED)
                echo -e "${BLUE}[SKIPPED]${NC} $hook"
                ;;
        esac
    done

    echo ""
    echo "=============================================================================="
    echo "   SUMMARY"
    echo "=============================================================================="
    echo "  Total:     $TOTAL"
    echo -e "  ${GREEN}Passed:${NC}     $PASSED"
    echo -e "  ${RED}Failed:${NC}     $FAILED"
    echo -e "  ${YELLOW}Timeouts:${NC}   $TIMEOUT"
    echo -e "  ${RED}Errors:${NC}     $ERRORS"
    echo ""

    if [[ $((FAILED + TIMEOUT + ERRORS)) -eq 0 ]]; then
        echo -e "${GREEN}All hooks executed successfully${NC}"
        return 0
    else
        echo -e "${RED}Some hooks failed or timed out${NC}"
        return 1
    fi
}

# Print JSON output
print_json_output() {
    local overall_status="pass"
    [[ $((FAILED + TIMEOUT + ERRORS)) -gt 0 ]] && overall_status="fail"

    cat << EOF
{
  "status": "$overall_status",
  "hooks_dir": "$HOOKS_DIR",
  "fixtures_dir": "$FIXTURES_DIR",
  "timeout_seconds": $TIMEOUT_SECONDS,
  "summary": {
    "total": $TOTAL,
    "passed": $PASSED,
    "failed": $FAILED,
    "timeouts": $TIMEOUT,
    "errors": $ERRORS
  },
  "hooks": {
EOF

    local first=true
    for hook in $(get_hooks_to_test); do
        local result="${HOOK_RESULTS[$hook]:-SKIPPED}"
        local message="${HOOK_MESSAGES[$hook]:-}"
        local exit_code="${HOOK_EXIT_CODES[$hook]:-}"
        local duration="${HOOK_DURATIONS[$hook]:-}"
        local stderr="${HOOK_STDERR[$hook]:-}"

        # Escape message for JSON
        message=$(echo "$message" | jq -Rs '.' | tr -d '\n')
        stderr=$(echo "$stderr" | jq -Rs '.' | tr -d '\n')

        $first || echo ","
        first=false
        cat << EOF
    "$hook": {
      "result": "$result",
      "exit_code": "$exit_code",
      "duration": "$duration",
      "message": $message,
      "stderr": $stderr
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check if hooks directory exists
if [[ ! -d "$HOOKS_DIR" ]]; then
    echo "Hooks directory not found: $HOOKS_DIR" >&2
    exit 2
fi

# Check if timeout command exists
if ! command -v timeout &>/dev/null; then
    echo "timeout command not found (required for this script)" >&2
    exit 2
fi

# Test each hook
for hook in $(get_hooks_to_test); do
    test_hook "$hook"
done

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac
