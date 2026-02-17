#!/bin/bash
# test-action-report-lib.sh - Unit tests for action-report-lib.sh
#
# VERSION: 2.93.0
#
# Validates that action-report-lib.sh correctly:
# - Manages action lifecycle
# - Tracks iterations and file modifications
# - Records errors
# - Generates final reports
#
# Usage:
#   ./test-action-report-lib.sh

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPORT_LIB="$PROJECT_ROOT/.claude/lib/action-report-lib.sh"
TEST_DIR="$PROJECT_ROOT/tests/temp/action-lib-tests"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

log_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓ PASS${RESET} $1"
}

log_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗ FAIL${RESET} $1"
}

log_info() {
    echo -e "  ${CYAN}ℹ INFO${RESET} $1"
}

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# ============================================
# TEST SUITE: Action Report Library
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Action Report Library v2.93.0 Unit Tests${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Test 1: Verify library exists
echo "Test 1: Verify action report library exists"
if [[ -f "$REPORT_LIB" ]]; then
    log_pass "Action report library exists: $REPORT_LIB"
    if [[ -x "$REPORT_LIB" ]]; then
        log_pass "Action report library is executable"
    else
        log_fail "Action report library is not executable"
    fi
else
    log_fail "Action report library not found: $REPORT_LIB"
    echo -e "${RED}✗ Aborting tests${RESET}"
    exit 1
fi

# Test 2: Create test environment
echo ""
echo "Test 2: Create test environment"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"
log_pass "Test environment created: $TEST_DIR"

# Test 3: Source the library
echo ""
echo "Test 3: Source action report library"
if source "$REPORT_LIB" 2>/dev/null; then
    log_pass "Action report library sourced successfully"
else
    log_fail "Failed to source action report library"
    exit 1
fi

# Test 4: Test start_action_report
echo ""
echo "Test 4: Test start_action_report function"
start_action_report "test-skill" "Test action description" 2>&1 >/dev/null
REPORT_FILE=$(find "$TEST_DIR/docs/actions/test-skill" -name "*.md" -type f 2>/dev/null | head -1)

if [[ -n "$REPORT_FILE" && -f "$REPORT_FILE" ]]; then
    log_pass "start_action_report created report file"
else
    log_fail "start_action_report did not create report file"
fi

# Test 5: Verify initial report content
echo ""
echo "Test 5: Verify initial report content"
if [[ -n "$REPORT_FILE" ]]; then
    if grep -q "IN_PROGRESS" "$REPORT_FILE"; then
        log_pass "Initial report marked as IN_PROGRESS"
    else
        log_fail "Initial report not marked as IN_PROGRESS"
    fi

    if grep -q "Test action description" "$REPORT_FILE"; then
        log_pass "Report contains description"
    else
        log_fail "Report missing description"
    fi
fi

# Test 6: Test mark_iteration
echo ""
echo "Test 6: Test mark_iteration function"
INITIAL_ITERATIONS=$CURRENT_ACTION_ITERATIONS
mark_iteration
if [[ $CURRENT_ACTION_ITERATIONS -eq $((INITIAL_ITERATIONS + 1)) ]]; then
    log_pass "mark_iteration incremented iteration count"
else
    log_fail "mark_iteration did not increment correctly"
fi

# Verify progress update
PROGRESS_FILE=$(find "$TEST_DIR/docs/actions/test-skill" -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$PROGRESS_FILE" ]] && grep -q "Progress Update" "$PROGRESS_FILE"; then
    log_pass "mark_iteration added progress update to report"
else
    log_fail "mark_iteration did not add progress update"
fi

# Test 7: Test mark_file_modified
echo ""
echo "Test 7: Test mark_file_modified function"
INITIAL_FILES=$CURRENT_ACTION_FILES_MODIFIED
mark_file_modified "test/file.txt"
if [[ $CURRENT_ACTION_FILES_MODIFIED -eq $((INITIAL_FILES + 1)) ]]; then
    log_pass "mark_file_modified incremented file count"
else
    log_fail "mark_file_modified did not increment correctly"
fi

# Test 8: Test record_error
echo ""
echo "Test 8: Test record_error function"
INITIAL_ERRORS=${#CURRENT_ACTION_ERRORS[@]}
record_error "Test error message"
if [[ ${#CURRENT_ACTION_ERRORS[@]} -eq $((INITIAL_ERRORS + 1)) ]]; then
    log_pass "record_error added error to array"
else
    log_fail "record_error did not add error correctly"
fi

# Verify error in report
ERROR_FILE=$(find "$TEST_DIR/docs/actions/test-skill" -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$ERROR_FILE" ]] && grep -q "ERROR: Test error message" "$ERROR_FILE"; then
    log_pass "record_error added error to report"
else
    log_fail "record_error did not add error to report"
fi

# Test 9: Test get_action_stats
echo ""
echo "Test 9: Test get_action_stats function"
STATS=$(get_action_stats 2>&1)
if echo "$STATS" | grep -q "test-skill"; then
    log_pass "get_action_stats shows skill name"
else
    log_fail "get_action_stats does not show skill name"
fi

if echo "$STATS" | grep -q "Iterations:"; then
    log_pass "get_action_stats shows iterations"
else
    log_fail "get_action_stats does not show iterations"
fi

if echo "$STATS" | grep -q "Files Modified:"; then
    log_pass "get_action_stats shows files modified"
else
    log_fail "get_action_stats does not show files modified"
fi

# Test 10: Test complete_action_report with success
echo ""
echo "Test 10: Test complete_action_report (success status)"
mkdir -p "$TEST_DIR/docs/actions/complete-test"
mkdir -p "$TEST_DIR/.claude/metadata/actions/complete-test"

COMPLETE_OUTPUT=$(complete_action_report "success" "Action completed successfully" "Run tests" 2>&1)
COMPLETE_EXIT=$?

if [[ $COMPLETE_EXIT -eq 0 ]]; then
    log_pass "complete_action_report returned exit code 0"
else
    log_fail "complete_action_report returned exit code $COMPLETE_EXIT"
fi

# Verify final report
FINAL_REPORT=$(find "$TEST_DIR/docs/actions/complete-test" -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$FINAL_REPORT" && -f "$FINAL_REPORT" ]]; then
    if grep -q "Status: COMPLETED" "$FINAL_REPORT"; then
        log_pass "Final report shows COMPLETED status"
    else
        log_fail "Final report does not show COMPLETED status"
    fi

    if grep -q "Action completed successfully" "$FINAL_REPORT"; then
        log_pass "Final report contains summary"
    else
        log_fail "Final report missing summary"
    fi
fi

# Test 11: Test complete_action_report with failure
echo ""
echo "Test 11: Test complete_action_report (failed status)"
mkdir -p "$TEST_DIR/docs/actions/failed-test"
mkdir -p "$TEST_DIR/.claude/metadata/actions/failed-test"

start_action_report "failed-test" "Test failure" >/dev/null 2>&1
record_error "Critical error occurred"
complete_action_report "failed" "Action failed" "Fix errors" >/dev/null 2>&1

FAILED_REPORT=$(find "$TEST_DIR/docs/actions/failed-test" -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$FAILED_REPORT" && -f "$FAILED_REPORT" ]]; then
    if grep -q "Status: FAILED" "$FAILED_REPORT"; then
        log_pass "Failed report shows FAILED status"
    else
        log_fail "Failed report does not show FAILED status"
    fi

    if grep -q "Critical error occurred" "$FAILED_REPORT"; then
        log_pass "Failed report includes error"
    else
        log_fail "Failed report missing error"
    fi
fi

# Test 12: Test multiple iterations
echo ""
echo "Test 12: Test multiple iteration tracking"
mkdir -p "$TEST_DIR/docs/actions/multi-test"
mkdir -p "$TEST_DIR/.claude/metadata/actions/multi-test"

start_action_report "multi-test" "Multiple iterations test" >/dev/null 2>&1
mark_iteration
mark_iteration
mark_iteration
complete_action_report "success" "Completed after 3 iterations" "" >/dev/null 2>&1

MULTI_REPORT=$(find "$TEST_DIR/docs/actions/multi-test" -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$MULTI_REPORT" ]]; then
    ITERATIONS=$(grep -o "Iteration [0-9]" "$MULTI_REPORT" | wc -l | tr -d ' ')
    if [[ $ITERATIONS -ge 3 ]]; then
        log_pass "Multiple iterations tracked (found $ITERATIONS)"
    else
        log_fail "Multiple iterations not tracked correctly (found $ITERATIONS, expected >= 3)"
    fi
fi

# Test 13: Test format_duration helper
echo ""
echo "Test 13: Test format_duration helper function"
DURATION_45S=$(format_duration 45)
if [[ "$DURATION_45S" == "45s" ]]; then
    log_pass "format_duration(45) = '45s'"
else
    log_fail "format_duration(45) = '$DURATION_45S', expected '45s'"
fi

DURATION_65S=$(format_duration 65)
if [[ "$DURATION_65S" == "1m 5s" ]]; then
    log_pass "format_duration(65) = '1m 5s'"
else
    log_fail "format_duration(65) = '$DURATION_65S', expected '1m 5s'"
fi

DURATION_3665S=$(format_duration 3665)
if [[ "$DURATION_3665S" == "1h 1m 5s" ]]; then
    log_pass "format_duration(3665) = '1h 1m 5s'"
else
    log_fail "format_duration(3665) = '$DURATION_3665S', expected '1h 1m 5s'"
fi

# Test 14: Test state reset after completion
echo ""
echo "Test 14: Test state reset after complete_action_report"
complete_action_report "success" "Final test" "" >/dev/null 2>&1

if [[ -z "$CURRENT_ACTION_SKILL" ]]; then
    log_pass "CURRENT_ACTION_SKILL reset after completion"
else
    log_fail "CURRENT_ACTION_SKILL not reset: $CURRENT_ACTION_SKILL"
fi

if [[ $CURRENT_ACTION_ITERATIONS -eq 0 ]]; then
    log_pass "CURRENT_ACTION_ITERATIONS reset after completion"
else
    log_fail "CURRENT_ACTION_ITERATIONS not reset: $CURRENT_ACTION_ITERATIONS"
fi

if [[ ${#CURRENT_ACTION_ERRORS[@]} -eq 0 ]]; then
    log_pass "CURRENT_ACTION_ERRORS reset after completion"
else
    log_fail "CURRENT_ACTION_ERRORS not reset: ${CURRENT_ACTION_ERRORS[@]}"
fi

# ============================================
# TEST SUMMARY
# ============================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Test Summary${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}Passed:${RESET} $TESTS_PASSED"
echo -e "  ${RED}Failed:${RESET} $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All tests passed!${RESET}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${RESET}"
    exit 1
fi
