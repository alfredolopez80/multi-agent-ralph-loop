#!/usr/bin/env bash
# test-learning-integration-v1.sh - Quick integration test for Learning System v2.81.2
# Version 1.0.0
# Part of Ralph Multi-Agent System Testing Suite
#
# Purpose: Validate that Fases 1-2 (Curator fixes + Learning integration) work together
#
# Tests:
#  1. Curator scripts have valid syntax
#  2. Learning hooks have valid syntax
#  3. Learning state directory exists
#  4. Hooks are registered in settings.json
#  5. Procedural rules file is accessible
#
# This is a QUICK test (< 1 minute) to validate basic integration
# For comprehensive testing, see test-learning-comprehensive-v1.sh

set -euo pipefail

SCRIPT_VERSION="1.0.0"
TEST_DATE=$(date +%Y%m%d)
TEST_LOG="tests/integration/test-results-${TEST_DATE}.log"

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

# Logging functions
log_test() { echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$TEST_LOG"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_LOG"; }

# Assert functions
assert_file_exists() {
    local file="$1"
    local description="${2:-File exists: $file}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ -f "$file" ]; then
        log_pass "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "$description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_dir_exists() {
    local dir="$1"
    local description="${2:-Directory exists: $dir}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if [ -d "$dir" ]; then
        log_pass "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "$description"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_syntax_valid() {
    local file="$1"
    local description="${2:-Syntax valid: $file}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if bash -n "$file" 2>/dev/null; then
        log_pass "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "$description - Syntax errors detected"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

assert_hook_registered() {
    local hook_file="$1"
    local settings_file="$2"
    local description="${3:-Hook registered: $hook_file}"

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if grep -q "$hook_file" "$settings_file" 2>/dev/null; then
        log_pass "$description"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        log_fail "$description - Not found in settings.json"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test Suite
main() {
    log_test "Starting Learning System Integration Test v1.0.0"
    log_info "Test date: $(date)"
    log_info "Log file: $TEST_LOG"
    echo ""

    # Test 1: Curator Scripts (Fase 1)
    log_test "=== FASE 1: Curator Scripts ==="
    assert_syntax_valid "$HOME/.ralph/curator/scripts/curator-scoring.sh" "curator-scoring.sh v2.0.0 syntax"
    assert_syntax_valid "$HOME/.ralph/curator/scripts/curator-discovery.sh" "curator-discovery.sh v2.0.0 syntax"
    assert_syntax_valid "$HOME/.ralph/curator/scripts/curator-rank.sh" "curator-rank.sh v2.0.0 syntax"
    echo ""

    # Test 2: Learning Hooks (Fase 2)
    log_test "=== FASE 2: Learning Hooks ==="
    assert_syntax_valid "$HOME/.claude/hooks/learning-gate.sh" "learning-gate.sh v1.0.0 syntax"
    assert_syntax_valid "$HOME/.claude/hooks/rule-verification.sh" "rule-verification.sh v1.0.0 syntax"
    echo ""

    # Test 3: Learning State Directory
    log_test "=== Learning Infrastructure ==="
    assert_dir_exists "$HOME/.ralph/learning" "Learning state directory exists"
    assert_file_exists "$HOME/.ralph/learning/state.json" "Learning state file exists"
    assert_file_exists "$HOME/.ralph/procedural/rules.json" "Procedural rules file exists"
    echo ""

    # Test 4: Hooks Registration
    log_test "=== Hooks Registration ==="
    local settings_file="$HOME/.claude-sneakpeek/zai/config/settings.json"
    assert_hook_registered "learning-gate.sh" "$settings_file" "learning-gate.sh registered in settings.json"
    assert_hook_registered "rule-verification.sh" "$settings_file" "rule-verification.sh registered in settings.json"
    echo ""

    # Test 5: Procedural Rules Content
    log_test "=== Procedural Rules ==="
    if [ -f "$HOME/.ralph/procedural/rules.json" ]; then
        local total_rules
        total_rules=$(jq '.rules | length' "$HOME/.ralph/procedural/rules.json" 2>/dev/null || echo "0")

        if [ "$total_rules" -gt 0 ]; then
            log_pass "Procedural rules file contains $total_rules rules"
            TESTS_PASSED=$((TESTS_PASSED + 1))
        else
            log_fail "Procedural rules file is empty"
            TESTS_FAILED=$((TESTS_FAILED + 1))
        fi
        TESTS_TOTAL=$((TESTS_TOTAL + 1))
    fi
    echo ""

    # Test 6: Documentation
    log_test "=== Documentation ==="
    assert_file_exists "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/docs/implementation/FASE_1_COMPLETADA_v2.81.1.md" "Fase 1 documentation exists"
    assert_file_exists "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/docs/implementation/FASE_2_COMPLETADA_v2.81.2.md" "Fase 2 documentation exists"
    echo ""

    # Summary
    log_test "=== TEST SUMMARY ==="
    log_info "Total tests: $TESTS_TOTAL"
    log_pass "Passed: $TESTS_PASSED"

    if [ $TESTS_FAILED -gt 0 ]; then
        log_fail "Failed: $TESTS_FAILED"
        echo ""
        log_warning "Some tests failed. Review the log for details."
        return 1
    else
        log_pass "All tests passed! ✅"
        echo ""
        log_info "Learning System integration validated successfully."
        log_info "System is ready for comprehensive testing (Opción B)."
        return 0
    fi
}

# Run tests
main "$@"
