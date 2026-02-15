#!/bin/bash
# test-convert-rules-v2.89.sh - Unit tests for Layer 5 bridge (convert-rules-to-claude.sh)
#
# VERSION: 1.0.0
#
# Validates that the Layer 5 bridge correctly converts procedural rules
# to Claude Code native rules format.
#
# Usage:
#   ./test-convert-rules-v2.89.sh

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONVERT_SCRIPT="$PROJECT_ROOT/.claude/scripts/convert-rules-to-claude.sh"

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
echo -e "${CYAN}Layer 5 Bridge (convert-rules-to-claude.sh) Unit Tests${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Verify script exists
if [[ ! -f "$CONVERT_SCRIPT" ]]; then
    echo -e "${RED}✗ Script file not found: $CONVERT_SCRIPT${RESET}"
    exit 1
fi

echo -e "${YELLOW}Testing script structure...${RESET}"

# Test 1: Domain path mapping function exists
echo -e "${CYAN}[TEST]${RESET} Domain path mapping function exists"
if grep -q "get_paths()" "$CONVERT_SCRIPT" 2>/dev/null; then
    log_pass "get_paths() function present"
else
    log_fail "get_paths() function not found"
fi

# Test 2: Confidence filter (>= 0.7)
echo -e "${CYAN}[TEST]${RESET} Confidence filter present (>= 0.7)"
if grep -q "confidence.*0.7" "$CONVERT_SCRIPT" 2>/dev/null; then
    log_pass "Confidence filter present"
else
    log_fail "Confidence filter not found"
fi

# Test 3: Usage count filter (>= 3)
echo -e "${CYAN}[TEST]${RESET} Usage count filter present (>= 3)"
if grep -q "usage_count.*3" "$CONVERT_SCRIPT" 2>/dev/null; then
    log_pass "Usage count filter present"
else
    log_fail "Usage count filter not found"
fi

# Test 4: YAML frontmatter generation
echo -e "${CYAN}[TEST]${RESET} YAML frontmatter generation"
if grep -q "paths:" "$CONVERT_SCRIPT" 2>/dev/null; then
    log_pass "YAML frontmatter generation present"
else
    log_fail "YAML frontmatter generation not found"
fi

# Test 5: Checksum-based skip logic
echo -e "${CYAN}[TEST]${RESET} Checksum-based skip logic"
if grep -q "CHECKSUM" "$CONVERT_SCRIPT" 2>/dev/null && grep -q "shasum" "$CONVERT_SCRIPT" 2>/dev/null; then
    log_pass "Checksum skip logic present"
else
    log_fail "Checksum skip logic not found"
fi

# Test 6: Hook-compatible JSON output
echo -e "${CYAN}[TEST]${RESET} Hook-compatible JSON output"
if grep -q "continue.*true" "$CONVERT_SCRIPT" 2>/dev/null; then
    log_pass "Hook-compatible JSON output present"
else
    log_fail "Hook-compatible JSON output not found"
fi

echo ""
echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"
echo -e "${YELLOW}Results: ${GREEN}${TESTS_PASSED} passed${RESET}, ${RED}${TESTS_FAILED} failed${RESET}"
echo -e "${CYAN}───────────────────────────────────────────────────────────${RESET}"

if [[ $TESTS_FAILED -gt 0 ]]; then
    exit 1
fi

exit 0
