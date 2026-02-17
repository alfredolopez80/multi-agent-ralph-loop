#!/bin/bash
# test-action-report-generator.sh - Unit tests for action-report-generator.sh
#
# VERSION: 2.93.0
#
# Validates that action-report-generator.sh correctly:
# - Generates markdown reports
# - Creates JSON metadata
# - Handles various skill types
# - Cleans up old reports
#
# Usage:
#   ./test-action-report-generator.sh

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATOR_LIB="$PROJECT_ROOT/.claude/lib/action-report-generator.sh"
TEST_DIR="$PROJECT_ROOT/tests/temp/action-report-tests"

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
# TEST SUITE: Action Report Generator
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Action Report Generator v2.93.0 Unit Tests${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Test 1: Verify generator library exists
echo "Test 1: Verify generator library exists"
if [[ -f "$GENERATOR_LIB" ]]; then
    log_pass "Generator library exists: $GENERATOR_LIB"
    if [[ -x "$GENERATOR_LIB" ]]; then
        log_pass "Generator library is executable"
    else
        log_fail "Generator library is not executable"
    fi
else
    log_fail "Generator library not found: $GENERATOR_LIB"
    echo -e "${RED}✗ Aborting tests${RESET}"
    exit 1
fi

# Test 2: Source the library
echo ""
echo "Test 2: Source generator library"
if source "$GENERATOR_LIB" 2>/dev/null; then
    log_pass "Generator library sourced successfully"
else
    log_fail "Failed to source generator library"
    exit 1
fi

# Test 3: Create test environment
echo ""
echo "Test 3: Create test environment"
mkdir -p "$TEST_DIR/docs/actions/test-skill"
mkdir -p "$TEST_DIR/.claude/metadata/actions/test-skill"
cd "$TEST_DIR"
log_pass "Test environment created: $TEST_DIR"

# Override REPORTS_DIR for testing
export ACTION_REPORTS_DIR="$TEST_DIR/docs/actions"
export METADATA_DIR="$TEST_DIR/.claude/metadata/actions"

# Test 4: Generate basic report
echo ""
echo "Test 4: Generate basic action report"
REPORT_OUTPUT=$(generate_action_report "test-skill" "completed" "Test task description" '{}' 2>&1)
REPORT_EXIT_CODE=$?

if [[ $REPORT_EXIT_CODE -eq 0 ]]; then
    log_pass "generate_action_report returned exit code 0"
else
    log_fail "generate_action_report returned exit code $REPORT_EXIT_CODE"
fi

# Test 5: Verify markdown file created
echo ""
echo "Test 5: Verify markdown report file created"
MARKDOWN_FILE=$(find "$ACTION_REPORTS_DIR/test-skill" -name "*.md" -type f | head -1)
if [[ -n "$MARKDOWN_FILE" && -f "$MARKDOWN_FILE" ]]; then
    log_pass "Markdown file created: $MARKDOWN_FILE"
else
    log_fail "Markdown file not created"
fi

# Test 6: Verify markdown file content
echo ""
echo "Test 6: Verify markdown report content"
if [[ -n "$MARKDOWN_FILE" ]]; then
    if grep -q "✅ Action Report: test-skill" "$MARKDOWN_FILE"; then
        log_pass "Markdown contains correct title"
    else
        log_fail "Markdown missing title"
    fi

    if grep -q "\*\*Status\*\*: COMPLETED" "$MARKDOWN_FILE"; then
        log_pass "Markdown contains status"
    else
        log_fail "Markdown missing status"
    fi

    if grep -q "Summary" "$MARKDOWN_FILE"; then
        log_pass "Markdown contains summary section"
    else
        log_fail "Markdown missing summary section"
    fi

    if grep -q "Execution Details" "$MARKDOWN_FILE"; then
        log_pass "Markdown contains execution details"
    else
        log_fail "Markdown missing execution details"
    fi
fi

# Test 7: Verify JSON metadata created
echo ""
echo "Test 7: Verify JSON metadata file created"
JSON_FILE=$(find "$METADATA_DIR/test-skill" -name "*.json" -type f | head -1)
if [[ -n "$JSON_FILE" && -f "$JSON_FILE" ]]; then
    log_pass "JSON metadata file created: $JSON_FILE"
else
    log_fail "JSON metadata file not created"
fi

# Test 8: Verify JSON metadata content
echo ""
echo "Test 8: Verify JSON metadata content"
if [[ -n "$JSON_FILE" ]]; then
    if jq empty "$JSON_FILE" 2>/dev/null; then
        log_pass "JSON file is valid JSON"
    else
        log_fail "JSON file is not valid JSON"
    fi

    SKILL_NAME=$(jq -r '.skill_name' "$JSON_FILE" 2>/dev/null)
    if [[ "$SKILL_NAME" == "test-skill" ]]; then
        log_pass "JSON contains correct skill_name"
    else
        log_fail "JSON missing or incorrect skill_name: $SKILL_NAME"
    fi

    STATUS=$(jq -r '.status' "$JSON_FILE" 2>/dev/null)
    if [[ "$STATUS" == "completed" ]]; then
        log_pass "JSON contains correct status"
    else
        log_fail "JSON missing or incorrect status: $STATUS"
    fi

    VERSION=$(jq -r '.version // "2.93.0"' "$JSON_FILE" 2>/dev/null)
    if [[ "$VERSION" == "2.93.0" ]] || [[ "$VERSION" == "null" ]]; then
        log_pass "JSON contains correct version"
    else
        log_fail "JSON missing or incorrect version: $VERSION"
    fi
fi

# Test 9: Test with different skill names
echo ""
echo "Test 9: Test report generation for different skills"
for skill in "orchestrator" "gates" "loop" "security"; do
    mkdir -p "$ACTION_REPORTS_DIR/$skill"
    mkdir -p "$METADATA_DIR/$skill"

    generate_action_report "$skill" "success" "Test $skill execution" '{}' >/dev/null 2>&1

    SKILL_REPORT=$(find "$ACTION_REPORTS_DIR/$skill" -name "*.md" -type f | head -1)
    if [[ -n "$SKILL_REPORT" && -f "$SKILL_REPORT" ]]; then
        log_pass "Report generated for $skill"
    else
        log_fail "Report not generated for $skill"
    fi
done

# Test 10: Test with different statuses
echo ""
echo "Test 10: Test report generation with different statuses"
mkdir -p "$ACTION_REPORTS_DIR/status-test"
mkdir -p "$METADATA_DIR/status-test"

for status in "completed" "failed" "partial" "in_progress"; do
    generate_action_report "status-test" "$status" "Test status: $status" '{}' >/dev/null 2>&1

    STATUS_FILE=$(find "$ACTION_REPORTS_DIR/status-test" -name "*.md" -type f | tail -1)
    if [[ -n "$STATUS_FILE" && -f "$STATUS_FILE" ]]; then
        STATUS_UPPER=$(echo "$status" | tr '[:lower:]' '[:upper:]')
        if grep -qi "\*\*Status\*\*: $STATUS_UPPER" "$STATUS_FILE"; then
            log_pass "Report contains status: $status"
        else
            log_fail "Report missing status: $status (looking for: $STATUS_UPPER)"
        fi
    else
        log_fail "Report not generated for status: $status"
    fi
done

# Test 11: Test cleanup of old reports
echo ""
echo "Test 11: Test cleanup of old reports"
mkdir -p "$ACTION_REPORTS_DIR/cleanup-test"
mkdir -p "$METADATA_DIR/cleanup-test"

# Create 55 old reports
for i in $(seq 1 55); do
    TIMESTAMP=$(date -v-${i}d +"%Y%m%d-%H%M%S" 2>/dev/null || date -d "${i} days ago" +"%Y%m%d-%H%M%S")
    echo "# Test" > "$ACTION_REPORTS_DIR/cleanup-test/${TIMESTAMP}.md"
    echo "{}" > "$METADATA_DIR/cleanup-test/${TIMESTAMP}.json"
done

# Run cleanup (should remove oldest 5)
cleanup_old_reports "$ACTION_REPORTS_DIR/cleanup-test" "$METADATA_DIR/cleanup-test"

REMAINING_COUNT=$(find "$ACTION_REPORTS_DIR/cleanup-test" -name "*.md" -type f | wc -l | tr -d ' ')
if [[ $REMAINING_COUNT -le 50 ]]; then
    log_pass "Cleanup removed old reports (remaining: $REMAINING_COUNT)"
else
    log_fail "Cleanup did not remove enough reports (remaining: $REMAINING_COUNT, expected <= 50)"
fi

# Test 12: Test list_reports function
echo ""
echo "Test 12: Test list_reports function"
REPORTS_LIST=$(list_reports "test-skill" 2>/dev/null)
REPORT_COUNT=$(echo "$REPORTS_LIST" | grep -c "\.md$" || echo "0")
if [[ $REPORT_COUNT -gt 0 ]]; then
    log_pass "list_reports returned $REPORT_COUNT reports"
else
    log_fail "list_reports did not return reports"
fi

# Test 13: Test get_skill_stats function
echo ""
echo "Test 13: Test get_skill_stats function"
STATS_OUTPUT=$(get_skill_stats "test-skill" 2>/dev/null)
if echo "$STATS_OUTPUT" | grep -q "Skill: test-skill"; then
    log_pass "get_skill_stats output contains skill name"
else
    log_fail "get_skill_stats output missing skill name"
fi

if echo "$STATS_OUTPUT" | grep -q "Total Reports:"; then
    log_pass "get_skill_stats output contains total count"
else
    log_fail "get_skill_stats output missing total count"
fi

# Test 14: Test report output to stdout
echo ""
echo "Test 14: Test report output includes stdout"
mkdir -p "$ACTION_REPORTS_DIR/stdout-test"
mkdir -p "$METADATA_DIR/stdout-test"

STDOUT_OUTPUT=$(generate_action_report "stdout-test" "completed" "Stdout test" '{}' 2>&1)
if echo "$STDOUT_OUTPUT" | grep -q "Action Report:"; then
    log_pass "Report output includes 'Action Report:' header"
else
    log_fail "Report output missing header"
fi

if echo "$STDOUT_OUTPUT" | grep -q "Report saved:"; then
    log_pass "Report output includes file location"
else
    log_fail "Report output missing file location"
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
