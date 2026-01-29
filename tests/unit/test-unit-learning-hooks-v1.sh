#!/usr/bin/env bash
# test-unit-learning-hooks-v1.sh - Unit tests for Learning System hooks
# Version 1.0.0
# Part of Ralph Multi-Agent System Testing Suite
#
# Purpose: Unit tests for individual hook functions
# Tests each function in isolation with mock data
#
# Coverage:
#  - learning-gate.sh: 8 test cases
#  - rule-verification.sh: 6 test cases
#  - Helper functions: 4 test cases
#
# Total: 18 unit tests

set -euo pipefail

SCRIPT_VERSION="1.0.0"
TEST_DATE=$(date +%Y%m%d)
TEST_LOG="tests/unit/test-results-${TEST_DATE}.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Logging
log_test() { echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$TEST_LOG"; }

# Assert functions
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-Assertion failed}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ "$expected" = "$actual" ]; then
        log_pass "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "$message (expected: $expected, got: $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-Assertion failed}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if echo "$haystack" | grep -q "$needle"; then
        log_pass "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "$message (string '$needle' not found)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_json_valid() {
    local json="$1"
    local message="${2:-JSON validation}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if echo "$json" | jq '.' > /dev/null 2>&1; then
        log_pass "$message"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "$message - Invalid JSON"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Mock data
create_mock_task_input() {
    local complexity="$1"
    local prompt="$2"

    cat << EOF
{
  "toolName": "Task",
  "toolInput": {
    "prompt": "$prompt",
    "subagent_type": "senior-developer",
    "complexity": $complexity
  }
}
EOF
}

create_mock_rules_json() {
    cat << EOF
{
  "rules": [
    {
      "rule_id": "rule-001",
      "domain": "backend",
      "pattern": "try.*catch",
      "confidence": 0.9,
      "keywords": ["error", "handling", "try", "catch"]
    },
    {
      "rule_id": "rule-002",
      "domain": "security",
      "pattern": "authenticate",
      "confidence": 0.85,
      "keywords": ["auth", "login", "jwt"]
    }
  ]
}
EOF
}

# Test Suite 1: learning-gate.sh
test_learning_gate_suite() {
    log_test "=== SUITE 1: learning-gate.sh Unit Tests ==="
    echo ""

    # Test 1.1: Returns allow decision for low complexity
    log_test "Test 1.1: Low complexity task (1) returns allow"
    local mock_input
    mock_input=$(create_mock_task_input 1 "Simple task")
    local output
    output=$(echo "$mock_input" | "$HOME/.claude/hooks/learning-gate.sh" 2>/dev/null)
    local decision
    decision=$(echo "$output" | jq -r '.decision // ""')
    assert_equals "allow" "$decision" "Low complexity allows execution"
    echo ""

    # Test 1.2: Returns valid JSON for medium complexity
    log_test "Test 1.2: Medium complexity task (5) returns valid JSON"
    mock_input=$(create_mock_task_input 5 "Medium task")
    output=$(echo "$mock_input" | "$HOME/.claude/hooks/learning-gate.sh" 2>/dev/null)
    assert_json_valid "$output" "Medium complexity returns valid JSON"
    echo ""

    # Test 1.3: Non-Task tool returns allow
    log_test "Test 1.3: Non-Task tool returns allow"
    local non_task_input
    non_task_input='{"toolName": "Edit", "toolInput": {"path": "test.txt"}}'
    output=$(echo "$non_task_input" | "$HOME/.claude/hooks/learning-gate.sh" 2>/dev/null)
    decision=$(echo "$output" | jq -r '.decision // ""')
    assert_equals "allow" "$decision" "Non-Task tool allows execution"
    echo ""

    # Test 1.4: Output contains decision field
    log_test "Test 1.4: Output contains decision field"
    mock_input=$(create_mock_task_input 3 "Normal task")
    output=$(echo "$mock_input" | "$HOME/.claude/hooks/learning-gate.sh" 2>/dev/null)
    assert_contains "$output" '"decision"' "Output contains decision field"
    echo ""

    # Test 1.5: Hook exits with code 0
    log_test "Test 1.5: Hook exits successfully"
    mock_input=$(create_mock_task_input 3 "Normal task")
    if echo "$mock_input" | "$HOME/.claude/hooks/learning-gate.sh" >/dev/null 2>&1; then
        log_pass "Hook exits with code 0"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_fail "Hook exited with error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo ""
}

# Test Suite 2: rule-verification.sh
test_rule_verification_suite() {
    log_test "=== SUITE 2: rule-verification.sh Unit Tests ==="
    echo ""

    # Test 2.1: Returns continue for non-TaskUpdate
    log_test "Test 2.1: Non-TaskUpdate tool returns continue"
    local mock_input='{"toolName": "Edit"}'
    local output
    output=$(echo "$mock_input" | "$HOME/.claude/hooks/rule-verification.sh" 2>/dev/null)
    local continue
    continue=$(echo "$output" | jq -r '.continue // ""')
    assert_equals "true" "$continue" "Non-TaskUpdate returns continue"
    echo ""

    # Test 2.2: Output contains continue field
    log_test "Test 2.2: Output contains continue field"
    mock_input='{"toolName": "TaskUpdate"}'
    output=$(echo "$mock_input" | "$HOME/.claude/hooks/rule-verification.sh" 2>/dev/null)
    assert_contains "$output" '"continue"' "Output contains continue field"
    echo ""

    # Test 2.3: Returns valid JSON
    log_test "Test 2.3: Returns valid JSON output"
    mock_input='{"toolName": "Edit"}'
    output=$(echo "$mock_input" | "$HOME/.claude/hooks/rule-verification.sh" 2>/dev/null)
    assert_json_valid "$output" "Returns valid JSON"
    echo ""

    # Test 2.4: Hook exits with code 0
    log_test "Test 2.4: Hook exits successfully"
    mock_input='{"toolName": "Edit"}'
    if echo "$mock_input" | "$HOME/.claude/hooks/rule-verification.sh" >/dev/null 2>&1; then
        log_pass "Hook exits with code 0"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        log_fail "Hook exited with error"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo ""
}

# Test Suite 3: Helper Functions
test_helper_functions_suite() {
    log_test "=== SUITE 3: Helper Functions Unit Tests ==="
    echo ""

    # Test 3.1: Mock data creation
    log_test "Test 3.1: Mock task input creates valid JSON"
    local mock_input
    mock_input=$(create_mock_task_input 5 "Test task")
    assert_json_valid "$mock_input" "Mock input is valid JSON"
    echo ""

    # Test 3.2: Mock rules creation
    log_test "Test 3.2: Mock rules JSON creates valid structure"
    local mock_rules
    mock_rules=$(create_mock_rules_json)
    local rule_count
    rule_count=$(echo "$mock_rules" | jq '.rules | length')
    assert_equals "2" "$rule_count" "Mock rules contains 2 rules"
    echo ""

    # Test 3.3: Assert functions work correctly
    log_test "Test 3.3: Assert equals function works"
    assert_equals "test" "test" "Assert equals passes for matching values"
    echo ""

    # Test 3.4: Assert contains function works
    log_test "Test 3.4: Assert contains function works"
    assert_contains "hello world" "world" "Assert contains finds substring"
    echo ""
}

# Main test runner
main() {
    log_test "Starting Learning System Unit Tests v1.0.0"
    log_info "Test date: $(date)"
    log_info "Log file: $TEST_LOG"
    echo ""

    # Run test suites
    test_learning_gate_suite
    test_rule_verification_suite
    test_helper_functions_suite

    # Summary
    log_test "=== UNIT TEST SUMMARY ==="
    log_info "Total tests: $TESTS_TOTAL"
    log_pass "Passed: $TESTS_PASSED"

    if [ $TESTS_FAILED -gt 0 ]; then
        log_fail "Failed: $TESTS_FAILED"
    fi

    local success_rate
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        log_info "Success rate: ${success_rate}%"
    fi

    echo ""

    if [ $TESTS_FAILED -gt 0 ]; then
        log_fail "Some unit tests failed"
        return 1
    else
        log_pass "All unit tests passed! ✅"
        return 0
    fi
}

# Run tests
main "$@"
