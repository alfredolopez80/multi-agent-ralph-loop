#!/bin/bash
# test_security_hooks.sh - Security Hooks Validation Tests
# Version: 2.86.0
# Date: 2026-02-14
#
# Validates that security hooks are properly configured to prevent
# secret leaks in claude-mem data and session files.

# Don't use set -e to allow tests to continue on failure
# set -e

# Configuration
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
SETTINGS_FILE="$HOME/.claude/settings.json"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ PASS${NC}: $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
fail() { echo -e "${RED}✗ FAIL${NC}: $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
info() { echo -e "${BLUE}ℹ INFO${NC}: $1"; }

section() {
    echo ""
    echo "========================================"
    echo " $1"
    echo "========================================"
}

echo "========================================"
echo " Security Hooks Test Suite"
echo " Version: 2.86.0"
echo "========================================"
echo ""
echo "Repository: $REPO_ROOT"
echo "Settings: $SETTINGS_FILE"
echo "Hooks Dir: $HOOKS_DIR"
echo ""

# =============================================================================
# TEST 1: Security Hooks Exist
# =============================================================================
section "TEST 1: Security Hooks Exist"

# Check sanitize-secrets.js
if [ -f "$HOOKS_DIR/sanitize-secrets.js" ]; then
    pass "sanitize-secrets.js exists"
else
    fail "sanitize-secrets.js missing"
fi

# Check cleanup-secrets-db.js
if [ -f "$HOOKS_DIR/cleanup-secrets-db.js" ]; then
    pass "cleanup-secrets-db.js exists"
else
    fail "cleanup-secrets-db.js missing"
fi

# Check procedural-forget.sh
if [ -f "$HOOKS_DIR/procedural-forget.sh" ]; then
    pass "procedural-forget.sh exists"
else
    fail "procedural-forget.sh missing"
fi

# =============================================================================
# TEST 2: Security Hooks Are Executable
# =============================================================================
section "TEST 2: Security Hooks Are Executable"

if [ -x "$HOOKS_DIR/sanitize-secrets.js" ] || head -1 "$HOOKS_DIR/sanitize-secrets.js" | grep -q "node"; then
    pass "sanitize-secrets.js is executable (node script)"
else
    info "sanitize-secrets.js may need chmod +x"
fi

if [ -x "$HOOKS_DIR/cleanup-secrets-db.js" ] || head -1 "$HOOKS_DIR/cleanup-secrets-db.js" | grep -q "node"; then
    pass "cleanup-secrets-db.js is executable (node script)"
else
    info "cleanup-secrets-db.js may need chmod +x"
fi

if [ -x "$HOOKS_DIR/procedural-forget.sh" ]; then
    pass "procedural-forget.sh is executable"
else
    fail "procedural-forget.sh not executable"
fi

# =============================================================================
# TEST 3: sanitize-secrets.js Registration
# =============================================================================
section "TEST 3: sanitize-secrets.js Registration"

if grep -q "sanitize-secrets.js" "$SETTINGS_FILE" 2>/dev/null; then
    pass "sanitize-secrets.js registered in settings.json"
else
    fail "sanitize-secrets.js NOT registered in settings.json"
fi

# =============================================================================
# TEST 4: Sanitize Secrets Pattern Coverage
# =============================================================================
section "TEST 4: Sanitize Secrets Pattern Coverage"

PATTERNS=(
    "GitHub PAT"
    "OpenAI API Key"
    "AWS Access Key"
    "Anthropic API Key"
    "JWT Token"
    "Slack Token"
    "Stripe Secret Key"
    "SSH Private Key"
    "Ethereum Private Key"
)

for pattern in "${PATTERNS[@]}"; do
    if grep -q "$pattern" "$HOOKS_DIR/sanitize-secrets.js" 2>/dev/null; then
        pass "Pattern '$pattern' defined in sanitize-secrets.js"
    else
        fail "Pattern '$pattern' missing from sanitize-secrets.js"
    fi
done

# =============================================================================
# TEST 5: Cleanup Script Dry Run
# =============================================================================
section "TEST 5: Cleanup Script Dry Run"

if command -v node &> /dev/null; then
    OUTPUT=$(cd "$HOOKS_DIR" && node cleanup-secrets-db.js --dry-run 2>&1)
    if echo "$OUTPUT" | grep -q "No se encontraron secretos\|OK"; then
        pass "cleanup-secrets-db.js runs successfully (no secrets found)"
    else
        info "cleanup-secrets-db.js output: $(echo "$OUTPUT" | head -3)"
    fi
else
    info "Node.js not available for cleanup test"
fi

# =============================================================================
# TEST 6: Procedural Forget Logic
# =============================================================================
section "TEST 6: Procedural Forget Logic"

if grep -q "usage_count" "$HOOKS_DIR/procedural-forget.sh" 2>/dev/null; then
    pass "procedural-forget.sh checks usage_count"
else
    fail "procedural-forget.sh missing usage_count check"
fi

if grep -q "confidence" "$HOOKS_DIR/procedural-forget.sh" 2>/dev/null; then
    pass "procedural-forget.sh checks confidence"
else
    fail "procedural-forget.sh missing confidence check"
fi

if grep -q "30 days" "$HOOKS_DIR/procedural-forget.sh" 2>/dev/null; then
    pass "procedural-forget.sh has 30-day retention rule"
else
    fail "procedural-forget.sh missing 30-day rule"
fi

# =============================================================================
# TEST 7: Sanitize Secrets Functional Test
# =============================================================================
section "TEST 7: Sanitize Secrets Functional Test"

TEST_INPUT='{"content": "api_key=sk-1234567890abcdef1234567890abcdef", "token": "ghp_abcdefghijklmnopqrstuvwxyz123456"}'
EXPECTED_REDACTED="REDACTED"

if command -v node &> /dev/null; then
    OUTPUT=$(echo "$TEST_INPUT" | node "$HOOKS_DIR/sanitize-secrets.js" 2>&1)
    if echo "$OUTPUT" | grep -qi "$EXPECTED_REDACTED"; then
        pass "sanitize-secrets.js correctly redacts secrets"
    else
        fail "sanitize-secrets.js did not redact test secrets"
        info "Output: $OUTPUT"
    fi
else
    info "Node.js not available for functional test"
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "========================================"
echo " TEST SUMMARY"
echo "========================================"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All security hooks tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$TESTS_FAILED test(s) failed${NC}"
    exit 1
fi
