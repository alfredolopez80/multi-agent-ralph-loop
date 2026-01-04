#!/usr/bin/env bash
# =============================================================================
# Test Suite: v2.25 Search Hierarchy + Context7 + dev-browser Integration
# Comprehensive coverage: 25 tests
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

section() {
    echo ""
    echo -e "${BLUE}=== $1 ===${NC}"
}

echo "=========================================="
echo "  v2.25 Integration Tests (25 tests)"
echo "=========================================="

# =============================================================================
section "cmd_research() Tests"
# =============================================================================

echo "Test 1: cmd_research() exists..."
if grep -q 'cmd_research()' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_research function exists"
else
    fail "cmd_research function missing"
fi

echo "Test 2: cmd_research() does not use Gemini CLI..."
if grep -q 'gemini.*Research' "$PROJECT_ROOT/scripts/ralph"; then
    fail "cmd_research still contains Gemini CLI references"
else
    pass "cmd_research removed Gemini CLI"
fi

echo "Test 3: cmd_research() uses WebSearch tool..."
if grep -q 'WebSearch tool' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_research references WebSearch tool"
else
    fail "cmd_research does not reference WebSearch"
fi

echo "Test 4: cmd_research() has MiniMax fallback..."
if grep -q 'mcp__MiniMax__web_search' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_research has MiniMax fallback"
else
    fail "cmd_research missing MiniMax fallback"
fi

echo "Test 5: cmd_research() has help text..."
if grep -A5 'cmd_research()' "$PROJECT_ROOT/scripts/ralph" | grep -q 'v2.25'; then
    pass "cmd_research has v2.25 version comment"
else
    fail "cmd_research missing version comment"
fi

# =============================================================================
section "cmd_library() Tests"
# =============================================================================

echo "Test 6: cmd_library() exists..."
if grep -q 'cmd_library()' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_library function exists"
else
    fail "cmd_library function missing"
fi

echo "Test 7: cmd_library() uses Context7 MCP..."
if grep -q 'mcp__plugin_context7_context7' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_library references Context7 MCP"
else
    fail "cmd_library does not reference Context7 MCP"
fi

echo "Test 8: cmd_library() has resolve-library-id step..."
if grep -q 'resolve-library-id' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_library has resolve-library-id step"
else
    fail "cmd_library missing resolve-library-id step"
fi

echo "Test 9: cmd_library() has query-docs step..."
if grep -q 'query-docs' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_library has query-docs step"
else
    fail "cmd_library missing query-docs step"
fi

# =============================================================================
section "cmd_browse() Tests"
# =============================================================================

echo "Test 10: cmd_browse() exists..."
if grep -q 'cmd_browse()' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_browse function exists"
else
    fail "cmd_browse function missing"
fi

echo "Test 11: cmd_browse() uses dev-browser..."
if grep -q 'dev-browser' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_browse references dev-browser"
else
    fail "cmd_browse does not reference dev-browser"
fi

echo "Test 12: cmd_browse() has URL parameter..."
if grep -A5 'cmd_browse()' "$PROJECT_ROOT/scripts/ralph" | grep -q 'URL'; then
    pass "cmd_browse has URL parameter"
else
    fail "cmd_browse missing URL parameter"
fi

echo "Test 13: cmd_browse() has action options..."
if grep -q '\-\-snapshot\|\-\-screenshot' "$PROJECT_ROOT/scripts/ralph"; then
    pass "cmd_browse has action options"
else
    fail "cmd_browse missing action options"
fi

# =============================================================================
section "Slash Commands Tests"
# =============================================================================

echo "Test 14: /browse command exists..."
if [[ -f "$PROJECT_ROOT/.claude/commands/browse.md" ]]; then
    pass "/browse command file exists"
else
    fail "/browse command file missing"
fi

echo "Test 15: /browse has dev-browser benchmarks..."
if grep -q '17%\|39%' "$PROJECT_ROOT/.claude/commands/browse.md"; then
    pass "/browse has performance benchmarks"
else
    fail "/browse missing performance benchmarks"
fi

echo "Test 16: /library-docs command exists..."
if [[ -f "$PROJECT_ROOT/.claude/commands/library-docs.md" ]]; then
    pass "/library-docs command file exists"
else
    fail "/library-docs command file missing"
fi

echo "Test 17: /library-docs has Context7 steps..."
if grep -q 'resolve-library-id' "$PROJECT_ROOT/.claude/commands/library-docs.md"; then
    pass "/library-docs has Context7 workflow"
else
    fail "/library-docs missing Context7 workflow"
fi

echo "Test 18: /research updated to WebSearch..."
if grep -q 'WebSearch' "$PROJECT_ROOT/.claude/commands/research.md"; then
    pass "/research references WebSearch"
else
    fail "/research does not reference WebSearch"
fi

echo "Test 19: /research has MiniMax fallback..."
if grep -q 'MiniMax' "$PROJECT_ROOT/.claude/commands/research.md"; then
    pass "/research has MiniMax fallback"
else
    fail "/research missing MiniMax fallback"
fi

# =============================================================================
section "Skills & Documentation Tests"
# =============================================================================

echo "Test 20: Context7 usage skill exists..."
if [[ -f "$PROJECT_ROOT/.claude/skills/context7-usage/skill.md" ]]; then
    pass "context7-usage skill exists"
else
    fail "context7-usage skill missing"
fi

echo "Test 21: Context7 skill has decision tree..."
if grep -q 'Decision Tree\|decision tree' "$PROJECT_ROOT/.claude/skills/context7-usage/skill.md"; then
    pass "context7-usage has decision tree"
else
    fail "context7-usage missing decision tree"
fi

echo "Test 22: CLAUDE.md updated to v2.25..."
if grep -q 'v2.25' "$PROJECT_ROOT/CLAUDE.md"; then
    pass "CLAUDE.md references v2.25"
else
    fail "CLAUDE.md not updated to v2.25"
fi

echo "Test 23: README.md updated to v2.25..."
if grep -q 'v2.25' "$PROJECT_ROOT/README.md"; then
    pass "README.md references v2.25"
else
    fail "README.md not updated to v2.25"
fi

# =============================================================================
section "Case Statement Aliases Tests"
# =============================================================================

echo "Test 24: Case statement has library aliases..."
if grep -q 'library|lib|docs|context7)' "$PROJECT_ROOT/scripts/ralph"; then
    pass "library aliases configured"
else
    fail "library aliases missing"
fi

echo "Test 25: Case statement has browse aliases..."
if grep -q 'browse|dev-browser)' "$PROJECT_ROOT/scripts/ralph"; then
    pass "browse aliases configured"
else
    fail "browse aliases missing"
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
echo -e "  Total:  $((PASS_COUNT + FAIL_COUNT))"
echo "=========================================="

if [[ $FAIL_COUNT -gt 0 ]]; then
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
else
    echo -e "${GREEN}All v2.25 tests passed!${NC}"
    exit 0
fi
