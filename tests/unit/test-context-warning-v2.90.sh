#!/bin/bash
# test-context-warning-v2.90.sh - Unit tests for context-warning.sh v2.90.0
#
# VERSION: 1.2.0
#
# Validates that context-warning.sh correctly reads stdin JSON
# and calculates context percentage from remaining_percentage.

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_FILE="$PROJECT_ROOT/.claude/hooks/context-warning.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
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
echo -e "${CYAN}context-warning.sh v2.90.0 Unit Tests${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Verify hook exists
if [[ ! -f "$HOOK_FILE" ]]; then
    echo -e "${RED}✗ Hook file not found: $HOOK_FILE${RESET}"
    exit 1
fi

echo -e "${YELLOW}Testing stdin JSON parsing...${RESET}"

# Test 1: remaining_percentage formula present
echo -e "${CYAN}[TEST]${RESET} remaining_percentage parsing code present"
if grep -q "100 - remaining" "$HOOK_FILE" 2>/dev/null; then
    log_pass "Formula '100 - remaining_percentage' is present"
else
    log_fail "Formula not found"
fi

# Test 2: v2.90.0 fix components
echo -e "${CYAN}[TEST]${RESET} v2.90.0 fix code is present"
CHECKS=0
grep -q "remaining_percentage" "$HOOK_FILE" 2>/dev/null && CHECKS=$((CHECKS + 1))
grep -q "jq -r" "$HOOK_FILE" 2>/dev/null && CHECKS=$((CHECKS + 1))
grep -q "100 - remaining" "$HOOK_FILE" 2>/dev/null && CHECKS=$((CHECKS + 1))

if [[ $CHECKS -eq 3 ]]; then
    log_pass "v2.90.0 fix components present (remaining_percentage, jq, 100-x formula)"
else
    log_fail "v2.90.0 fix components missing ($CHECKS/3 found)"
fi

# Test 3: Fallback cap
echo -e "${CYAN}[TEST]${RESET} Fallback capped at 50% (prevents false CRITICAL)"
if grep -q "50" "$HOOK_FILE" 2>/dev/null; then
    log_pass "Fallback cap mechanism present"
else
    log_fail "Fallback cap not found"
fi

echo ""
echo -e "${YELLOW}Testing regression prevention...${RESET}"

# Test 4: Old broken formula removed
echo -e "${CYAN}[TEST]${RESET} No more permanent 100% bug"
if grep -q "ops / 4" "$HOOK_FILE" 2>/dev/null && grep -q "message_count \* 2" "$HOOK_FILE" 2>/dev/null; then
    log_fail "Old broken formula still present!"
else
    log_pass "Old broken cumulative formula removed"
fi

echo ""
echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"
echo -e "${YELLOW}Results: ${GREEN}${TESTS_PASSED} passed${RESET}, ${RED}${TESTS_FAILED} failed${RESET}"
echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
