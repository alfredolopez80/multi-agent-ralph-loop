#!/bin/bash
# test-quality-gates-v2.90.sh - Unit tests for quality gate hooks v2.90.0
#
# VERSION: 1.0.0
#
# Validates that task-completed-quality-gate.sh and teammate-idle-quality-gate.sh
# correctly extract files_modified from stdin JSON.
#
# Usage:
#   ./test-quality-gates-v2.90.sh

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TASK_HOOK="$PROJECT_ROOT/.claude/hooks/task-completed-quality-gate.sh"
TEAMMATE_HOOK="$PROJECT_ROOT/.claude/hooks/teammate-idle-quality-gate.sh"

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

# ============================================
# MAIN TEST RUNNER
# ============================================

echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Quality Gates v2.90.0 Unit Tests${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Verify hooks exist
if [[ ! -f "$TASK_HOOK" ]]; then
    echo -e "${RED}✗ Hook file not found: $TASK_HOOK${RESET}"
    exit 1
fi

if [[ ! -f "$TEAMMATE_HOOK" ]]; then
    echo -e "${RED}✗ Hook file not found: $TEAMMATE_HOOK${RESET}"
    exit 1
fi

echo -e "${YELLOW}Testing task-completed-quality-gate.sh...${RESET}"

# Test 1: files_modified extraction present
echo -e "${CYAN}[TEST]${RESET} files_modified extraction present in task-completed"
if grep -q "files_modified.*jq" "$TASK_HOOK" 2>/dev/null; then
    log_pass "files_modified extraction code found"
else
    log_fail "files_modified extraction code not found"
fi

# Test 2: Version updated to 2.90.0
echo -e "${CYAN}[TEST]${RESET} Version updated to 2.90.0 in task-completed"
if grep -q "VERSION: 2.90.0" "$TASK_HOOK" 2>/dev/null; then
    log_pass "Version 2.90.0 present"
else
    log_fail "Version not updated to 2.90.0"
fi

echo ""
echo -e "${YELLOW}Testing teammate-idle-quality-gate.sh...${RESET}"

# Test 3: files_modified extraction present
echo -e "${CYAN}[TEST]${RESET} files_modified extraction present in teammate-idle"
if grep -q "files_modified.*jq" "$TEAMMATE_HOOK" 2>/dev/null; then
    log_pass "files_modified extraction code found"
else
    log_fail "files_modified extraction code not found"
fi

# Test 4: Version updated to 2.90.0
echo -e "${CYAN}[TEST]${RESET} Version updated to 2.90.0 in teammate-idle"
if grep -q "VERSION: 2.90.0" "$TEAMMATE_HOOK" 2>/dev/null; then
    log_pass "Version 2.90.0 present"
else
    log_fail "Version not updated to 2.90.0"
fi

echo ""
echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"
echo -e "${YELLOW}Results: ${GREEN}${TESTS_PASSED} passed${RESET}, ${RED}${TESTS_FAILED} failed${RESET}"
echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
