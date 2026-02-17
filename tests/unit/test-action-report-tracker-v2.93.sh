#!/bin/bash
# test-action-report-tracker.sh - Unit tests for action-report-tracker.sh
#
# VERSION: 2.93.0
#
# Validates that action-report-tracker.sh correctly:
# - Parses Task tool completion
# - Maps subagent types to skill names
# - Generates reports for various subagent types
# - Handles background vs foreground execution
#
# Usage:
#   ./test-action-report-tracker.sh

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TRACKER_HOOK="$PROJECT_ROOT/.claude/hooks/action-report-tracker.sh"
TEST_DIR="$PROJECT_ROOT/tests/temp/action-tracker-tests"

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
# TEST SUITE: Action Report Tracker Hook
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Action Report Tracker Hook v2.93.0 Unit Tests${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Test 1: Verify hook exists
echo "Test 1: Verify action-report-tracker.sh exists"
if [[ -f "$TRACKER_HOOK" ]]; then
    log_pass "Hook file exists: $TRACKER_HOOK"
    if [[ -x "$TRACKER_HOOK" ]]; then
        log_pass "Hook file is executable"
    else
        log_fail "Hook file is not executable"
    fi
else
    log_fail "Hook file not found: $TRACKER_HOOK"
    echo -e "${RED}✗ Aborting tests${RESET}"
    exit 1
fi

# Test 2: Create test environment
echo ""
echo "Test 2: Create test environment"
mkdir -p "$TEST_DIR/docs/actions"
mkdir -p "$TEST_DIR/.claude/metadata/actions"
mkdir -p "$TEST_DIR/.claude/hooks"
mkdir -p "$TEST_DIR/.claude/lib"

# Copy files to test dir
cp "$PROJECT_ROOT/.claude/hooks/action-report-tracker.sh" "$TEST_DIR/.claude/hooks/"
cp "$PROJECT_ROOT/.claude/lib/action-report-generator.sh" "$TEST_DIR/.claude/lib/"
cp "$PROJECT_ROOT/.claude/lib/action-report-lib.sh" "$TEST_DIR/.claude/lib/"

cd "$TEST_DIR"
log_pass "Test environment created: $TEST_DIR"

# Test 3: Test hook ignores non-Task tools
echo ""
echo "Test 3: Test hook ignores non-Task tools"
NON_TASK_INPUT='{"tool_name":"Read","tool_input":{"file_path":"test.txt"},"tool_result":"content","session_id":"test123"}'

HOOK_OUTPUT=$(echo "$NON_TASK_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook returned exit code 0 for non-Task tool"
else
    log_fail "Hook returned exit code $HOOK_EXIT for non-Task tool"
fi

if echo "$HOOK_OUTPUT" | grep -q '"continue": true'; then
    log_pass "Hook outputs continue:true for non-Task tool"
else
    log_fail "Hook does not output continue:true for non-Task tool"
fi

# Test 4: Test hook processes orchestrator subagent
echo ""
echo "Test 4: Test hook processes orchestrator subagent"
ORCHESTRATOR_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","description":"Test orchestration"},"tool_result":"Success","session_id":"test123"}'

HOOK_OUTPUT=$(echo "$ORCHESTRATOR_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook processed orchestrator subagent successfully"
else
    log_fail "Hook failed processing orchestrator subagent (exit code: $HOOK_EXIT)"
fi

# Verify report created
ORCHESTRATOR_REPORT=$(find docs/actions/orchestrator -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$ORCHESTRATOR_REPORT" && -f "$ORCHESTRATOR_REPORT" ]]; then
    log_pass "Orchestrator report created"
else
    log_fail "Orchestrator report not created"
fi

# Test 5: Test hook processes ralph-coder subagent
echo ""
echo "Test 5: Test hook processes ralph-coder subagent"
CODER_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","description":"Code implementation"},"tool_result":"Code written","session_id":"test456"}'

HOOK_OUTPUT=$(echo "$CODER_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook processed ralph-coder subagent successfully"
else
    log_fail "Hook failed processing ralph-coder subagent (exit code: $HOOK_EXIT)"
fi

# Verify report mapped to orchestrator (as per SKILL_MAPPING)
CODER_REPORT=$(find docs/actions/orchestrator -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$CODER_REPORT" && -f "$CODER_REPORT" ]]; then
    log_pass "Ralph-coder mapped to orchestrator report"
else
    log_fail "Ralph-coder report not created/mapped"
fi

# Test 6: Test hook processes ralph-reviewer subagent
echo ""
echo "Test 6: Test hook processes ralph-reviewer subagent"
REVIEWER_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"ralph-reviewer","description":"Code review"},"tool_result":"Review complete","session_id":"test789"}'

HOOK_OUTPUT=$(echo "$REVIEWER_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook processed ralph-reviewer subagent successfully"
else
    log_fail "Hook failed processing ralph-reviewer subagent (exit code: $HOOK_EXIT)"
fi

# Verify report mapped to gates
REVIEWER_REPORT=$(find docs/actions/gates -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$REVIEWER_REPORT" && -f "$REVIEWER_REPORT" ]]; then
    log_pass "Ralph-reviewer mapped to gates report"
else
    log_fail "Ralph-reviewer report not created/mapped"
fi

# Test 7: Test hook processes general-purpose subagent
echo ""
echo "Test 7: Test hook processes general-purpose subagent"
GENERAL_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"general-purpose","description":"General task"},"tool_result":"Task done","session_id":"test012"}'

HOOK_OUTPUT=$(echo "$GENERAL_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook processed general-purpose subagent successfully"
else
    log_fail "Hook failed processing general-purpose subagent (exit code: $HOOK_EXIT)"
fi

# Verify report created for loop
LOOP_REPORT=$(find docs/actions/loop -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$LOOP_REPORT" && -f "$LOOP_REPORT" ]]; then
    log_pass "General-purpose mapped to loop report"
else
    log_fail "Loop report not created/mapped"
fi

# Test 8: Test hook detects errors in tool_result
echo ""
echo "Test 8: Test hook detects errors in tool_result"
ERROR_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","description":"Failed task"},"tool_result":"Error: Command failed","session_id":"test345"}'

HOOK_OUTPUT=$(echo "$ERROR_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook handled error case gracefully"
else
    log_fail "Hook failed on error case (exit code: $HOOK_EXIT)"
fi

# Verify report shows failed status
ERROR_REPORT=$(find docs/actions/orchestrator -name "*.md" -type f 2>/dev/null | tail -1)
if [[ -n "$ERROR_REPORT" && -f "$ERROR_REPORT" ]]; then
    if grep -qi "failed" "$ERROR_REPORT"; then
        log_pass "Error report shows failed status"
    else
        log_fail "Error report does not show failed status"
    fi
fi

# Test 9: Test hook tracks run_in_background
echo ""
echo "Test 9: Test hook records run_in_background flag"
BG_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","description":"Background task","run_in_background":true},"tool_result":"Background complete","session_id="test678"}'

HOOK_OUTPUT=$(echo "$BG_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook processed background task successfully"
else
    log_fail "Hook failed processing background task (exit code: $HOOK_EXIT)"
fi

# Check metadata JSON
BG_METADATA=$(find .claude/metadata/actions/orchestrator -name "*.json" -type f 2>/dev/null | tail -1)
if [[ -n "$BG_METADATA" && -f "$BG_METADATA" ]]; then
    BG_FLAG=$(jq -r '.details.run_in_background // "false"' "$BG_METADATA" 2>/dev/null)
    if [[ "$BG_FLAG" == "true" ]]; then
        log_pass "Background flag recorded in metadata"
    else
        log_fail "Background flag not recorded correctly: $BG_FLAG"
    fi
fi

# Test 10: Test hook output includes stderr for visibility
echo ""
echo "Test 10: Test hook outputs report to stderr"
VISIBLE_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","description":"Visibility test"},"tool_result":"Success","session_id":"test910"}'

HOOK_OUTPUT=$(echo "$VISIBLE_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)

# Check stderr (redirected to stdout in test)
if echo "$HOOK_OUTPUT" | grep -q "Action Report Generated"; then
    log_pass "Hook outputs report visible in stderr/stdout"
else
    log_fail "Hook does not output visible report"
fi

if echo "$HOOK_OUTPUT" | grep -q "Report saved:"; then
    log_pass "Hook outputs file location"
else
    log_fail "Hook does not output file location"
fi

# Test 11: Test unknown subagent type
echo ""
echo "Test 11: Test hook handles unknown subagent type"
UNKNOWN_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"unknown-type","description":"Unknown"},"tool_result":"Done","session_id":"test111"}'

HOOK_OUTPUT=$(echo "$UNKNOWN_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook handles unknown subagent gracefully"
else
    log_fail "Hook failed on unknown subagent type (exit code: $HOOK_EXIT)"
fi

# Unknown types should still generate report using the subagent name
UNKNOWN_REPORT=$(find docs/actions -name "*.md" -type f 2>/dev/null | grep "unknown-type" | tail -1)
if [[ -n "$UNKNOWN_REPORT" && -f "$UNKNOWN_REPORT" ]]; then
    log_pass "Unknown subagent creates report with subagent name"
else
    log_fail "Unknown subagent report not created"
fi

# Test 12: Test hook handles large input (SEC-111)
echo ""
echo "Test 12: Test hook handles large input without DoS"
LARGE_DESCRIPTION=$(printf "Test%.0s" {1..1000})
LARGE_INPUT=$(cat <<EOF
{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","description":"$LARGE_DESCRIPTION"},"tool_result":"Success","session_id":"test222"}
EOF
)

# Trim to 100KB as per SEC-111
LARGE_INPUT=$(echo "$LARGE_INPUT" | head -c 100000)

HOOK_OUTPUT=$(echo "$LARGE_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook handles large input without DoS (SEC-111)"
else
    log_fail "Hook failed on large input (exit code: $HOOK_EXIT)"
fi

# Test 13: Verify hook always outputs valid JSON
echo ""
echo "Test 13: Test hook always outputs valid JSON protocol"
VALID_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","description":"Valid JSON test"},"tool_result":"Success","session_id":"test333"}'

HOOK_OUTPUT=$(echo "$VALID_INPUT" | .claude/hooks/action-report-tracker.sh 2>&1)

# Extract JSON (last line should be the protocol JSON)
JSON_OUTPUT=$(echo "$HOOK_OUTPUT" | tail -1)
if echo "$JSON_OUTPUT" | jq empty 2>/dev/null; then
    log_pass "Hook outputs valid JSON protocol"
else
    log_fail "Hook does not output valid JSON: $JSON_OUTPUT"
fi

# Verify continue field
CONTINUE_VALUE=$(echo "$JSON_OUTPUT" | jq -r '.continue // "null"' 2>/dev/null)
if [[ "$CONTINUE_VALUE" == "true" ]]; then
    log_pass "Hook outputs continue=true"
else
    log_fail "Hook does not output continue=true: $CONTINUE_VALUE"
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
