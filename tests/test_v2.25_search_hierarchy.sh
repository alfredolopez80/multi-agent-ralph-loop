#!/usr/bin/env bash
# =============================================================================
# Test Suite: v2.25 Search Hierarchy + Context7 + dev-browser Integration
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0

pass() {
    echo -e "${GREEN}PASS${NC}: $1"
    ((PASS_COUNT++))
}

fail() {
    echo -e "${RED}FAIL${NC}: $1"
    ((FAIL_COUNT++))
}

warn() {
    echo -e "${YELLOW}WARN${NC}: $1"
}

echo "=========================================="
echo "  v2.25 Integration Tests"
echo "=========================================="
echo ""

# =============================================================================
# Test 1: cmd_research no usa Gemini CLI
# =============================================================================
echo "Test 1: cmd_research() does not use Gemini CLI..."
if grep -q 'gemini.*Research' "$PROJECT_ROOT/scripts/ralph"; then
    fail "cmd_research still contains Gemini CLI references"
else
    pass "cmd_research uses WebSearch → MiniMax hierarchy"
fi

# =============================================================================
# Test 2: cmd_research usa WebSearch
# =============================================================================
echo "Test 2: cmd_research() uses WebSearch tool..."
if grep -q 'WebSearch tool' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_research references WebSearch tool"
else
    fail "cmd_research does not reference WebSearch"
fi

# =============================================================================
# Test 3: cmd_library existe
# =============================================================================
echo "Test 3: cmd_library() exists..."
if grep -q 'cmd_library()' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_library function exists"
else
    fail "cmd_library function missing"
fi

# =============================================================================
# Test 4: cmd_library usa Context7 MCP
# =============================================================================
echo "Test 4: cmd_library() uses Context7 MCP..."
if grep -q 'mcp__plugin_context7_context7' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_library references Context7 MCP"
else
    fail "cmd_library does not reference Context7 MCP"
fi

# =============================================================================
# Test 5: cmd_browse existe
# =============================================================================
echo "Test 5: cmd_browse() exists..."
if grep -q 'cmd_browse()' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_browse function exists"
else
    fail "cmd_browse function missing"
fi

# =============================================================================
# Test 6: cmd_browse usa dev-browser
# =============================================================================
echo "Test 6: cmd_browse() uses dev-browser skill..."
if grep -q 'dev-browser' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_browse references dev-browser"
else
    fail "cmd_browse does not reference dev-browser"
fi

# =============================================================================
# Test 7: /browse slash command existe
# =============================================================================
echo "Test 7: /browse slash command exists..."
if [[ -f "$PROJECT_ROOT/.claude/commands/browse.md" ]]; then
    pass "/browse command file exists"
else
    fail "/browse command file missing"
fi

# =============================================================================
# Test 8: /library-docs slash command existe
# =============================================================================
echo "Test 8: /library-docs slash command exists..."
if [[ -f "$PROJECT_ROOT/.claude/commands/library-docs.md" ]]; then
    pass "/library-docs command file exists"
else
    fail "/library-docs command file missing"
fi

# =============================================================================
# Test 9: /research actualizado (no Gemini)
# =============================================================================
echo "Test 9: /research command updated (no Gemini)..."
if grep -q 'WebSearch' "$PROJECT_ROOT/.claude/commands/research.md"; then
    pass "/research references WebSearch"
else
    fail "/research does not reference WebSearch"
fi

# =============================================================================
# Test 10: Context7 skill existe
# =============================================================================
echo "Test 10: Context7 usage skill exists..."
if [[ -f "$PROJECT_ROOT/.claude/skills/context7-usage/skill.md" ]]; then
    pass "context7-usage skill exists"
else
    fail "context7-usage skill missing"
fi

# =============================================================================
# Test 11: CLAUDE.md actualizado a v2.25
# =============================================================================
echo "Test 11: CLAUDE.md updated to v2.25..."
if grep -q 'v2.25' "$PROJECT_ROOT/CLAUDE.md"; then
    pass "CLAUDE.md references v2.25"
else
    fail "CLAUDE.md not updated to v2.25"
fi

# =============================================================================
# Test 12: Case statement tiene aliases library|lib|docs
# =============================================================================
echo "Test 12: Case statement has library aliases..."
if grep -q 'library|lib|docs|context7)' "$PROJECT_ROOT/scripts/ralph"; then
    pass "library aliases configured in case statement"
else
    fail "library aliases missing from case statement"
fi

# =============================================================================
# Test 13: Case statement tiene aliases browse|dev-browser
# =============================================================================
echo "Test 13: Case statement has browse aliases..."
if grep -q 'browse|dev-browser)' "$PROJECT_ROOT/scripts/ralph"; then
    pass "browse aliases configured in case statement"
else
    fail "browse aliases missing from case statement"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
echo -e "  ${GREEN}Passed${NC}: $PASS_COUNT"
echo -e "  ${RED}Failed${NC}: $FAIL_COUNT"
echo "=========================================="

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All v2.25 tests passed!${NC}"
    exit 0
fi
