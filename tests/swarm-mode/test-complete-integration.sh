#!/usr/bin/env bash
# test-complete-integration.sh
# Validates complete swarm mode integration across all phases
# Part of Multi-Agent Ralph Loop v2.81.1

# Don't exit on error - we want to run all tests
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Project root
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# Test functions
test_pass() {
  local msg="$1"
  echo -e "${GREEN}✓ PASS${NC}: $msg"
  ((TESTS_PASSED++))
  ((TESTS_RUN++))
}

test_fail() {
  local msg="$1"
  echo -e "${RED}✗ FAIL${NC}: $msg"
  ((TESTS_FAILED++))
  ((TESTS_RUN++))
}

test_info() {
  local msg="$1"
  echo -e "${BLUE}ℹ INFO${NC}: $msg"
  ((TESTS_RUN++))
}

echo "=========================================="
echo "Complete Swarm Mode Integration Test"
echo "=========================================="
echo "Testing all phases of swarm mode integration"
echo ""

# ============================================================================
# Phase 1: Core Commands Validation
# ============================================================================
echo -e "${BLUE}═══ Phase 1: Core Commands ═══${NC}"
echo ""

# Test /loop
echo "Test 1.1: /loop command"
if grep -q "team_name.*loop-execution-team" "${PROJECT_ROOT}/.claude/commands/loop.md"; then
  test_pass "/loop has team_name"
else
  test_fail "/loop missing team_name"
fi

if grep -q "mode.*delegate" "${PROJECT_ROOT}/.claude/commands/loop.md"; then
  test_pass "/loop has mode: delegate"
else
  test_fail "/loop missing mode: delegate"
fi

if grep -q "run_in_background.*true" "${PROJECT_ROOT}/.claude/commands/loop.md"; then
  test_pass "/loop has run_in_background: true"
else
  test_fail "/loop missing run_in_background: true"
fi
echo ""

# Test /edd
echo "Test 1.2: /edd skill"
if grep -q "team_name.*edd-evaluation-team" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md"; then
  test_pass "/edd has team_name"
else
  test_fail "/edd missing team_name"
fi

if grep -q "run_in_background.*true" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md"; then
  test_pass "/edd has run_in_background: true"
else
  test_fail "/edd missing run_in_background: true"
fi
echo ""

# Test /bug
echo "Test 1.3: /bug command"
if [[ -f "${PROJECT_ROOT}/.claude/commands/bug.md" ]]; then
  test_pass "/bug command exists"
else
  test_fail "/bug command missing"
fi

if grep -q "team_name.*bug-analysis-team" "${PROJECT_ROOT}/.claude/commands/bug.md"; then
  test_pass "/bug has team_name"
else
  test_fail "/bug missing team_name"
fi
echo ""

# ============================================================================
# Phase 2: Secondary Commands Validation
# ============================================================================
echo -e "${BLUE}═══ Phase 2: Secondary Commands ═══${NC}"
echo ""

# Test /adversarial
echo "Test 2.1: /adversarial command"
if grep -q "team_name.*adversarial-council" "${PROJECT_ROOT}/.claude/commands/adversarial.md"; then
  test_pass "/adversarial has team_name"
else
  test_fail "/adversarial missing team_name"
fi

LOOP_COUNT=$(grep -c "Teammate.*specialist" "${PROJECT_ROOT}/.claude/commands/adversarial.md")
if [[ "$LOOP_COUNT" -ge 3 ]]; then
  test_pass "/adversarial documents $LOOP_COUNT teammates"
else
  test_fail "/adversarial only documents $LOOP_COUNT teammates"
fi
echo ""

# Test /parallel
echo "Test 2.2: /parallel command"
if grep -q "team_name.*parallel-execution" "${PROJECT_ROOT}/.claude/commands/parallel.md"; then
  test_pass "/parallel has team_name"
else
  test_fail "/parallel missing team_name"
fi

# /parallel should have 6 teammates
PARALLEL_TEAM=$(grep -c "Teammate.*specialist" "${PROJECT_ROOT}/.claude/commands/parallel.md")
if [[ "$PARALLEL_TEAM" -ge 6 ]]; then
  test_pass "/parallel documents $PARALLEL_TEAM teammates (expected 6)"
else
  test_fail "/parallel only documents $PARALLEL_TEAM teammates (expected 6)"
fi
echo ""

# Test /gates
echo "Test 2.3: /gates command"
if grep -q "team_name.*quality-gates-team" "${PROJECT_ROOT}/.claude/commands/gates.md"; then
  test_pass "/gates has team_name"
else
  test_fail "/gates missing team_name"
fi

if grep -q "3.0x faster" "${PROJECT_ROOT}/.claude/commands/gates.md"; then
  test_pass "/gates documents parallel speedup"
else
  test_fail "/gates missing speedup documentation"
fi
echo ""

# ============================================================================
# Phase 3: Global Hooks Validation
# ============================================================================
echo -e "${BLUE}═══ Phase 3: Global Hooks ═══${NC}"
echo ""

echo "Test 3.1: auto-background-swarm.sh hook"
if [[ -f "${PROJECT_ROOT}/.claude/hooks/auto-background-swarm.sh" ]]; then
  test_pass "auto-background-swarm.sh exists"
else
  test_fail "auto-background-swarm.sh missing"
fi

if [[ -x "${PROJECT_ROOT}/.claude/hooks/auto-background-swarm.sh" ]]; then
  test_pass "auto-background-swarm.sh is executable"
else
  test_fail "auto-background-swarm.sh not executable"
fi

if grep -q "SUPPORTED_COMMANDS" "${PROJECT_ROOT}/.claude/hooks/auto-background-swarm.sh"; then
  test_pass "Hook defines supported commands"
else
  test_fail "Hook missing supported commands list"
fi

# Check if hook is registered in settings
if command -v jq >/dev/null 2>&1; then
  if jq -e '.hooks.PostToolUse[] | select(.hooks[].command | contains("auto-background-swarm"))' ~/.claude-sneakpeek/zai/config/settings.json >/dev/null 2>&1; then
    test_pass "Hook registered in settings.json"
  else
    test_fail "Hook not registered in settings.json"
  fi
else
  test_info "jq not available - skipping settings.json check"
fi
echo ""

# ============================================================================
# Phase 4: Documentation Validation
# ============================================================================
echo -e "${BLUE}═══ Phase 4: Documentation ═══${NC}"
echo ""

echo "Test 4.1: CLAUDE.md swarm mode section"
if grep -q "## Swarm Mode" "${PROJECT_ROOT}/CLAUDE.md"; then
  test_pass "CLAUDE.md has Swarm Mode section"
else
  test_fail "CLAUDE.md missing Swarm Mode section"
fi

if grep -q "Commands with Swarm Mode" "${PROJECT_ROOT}/CLAUDE.md"; then
  test_pass "CLAUDE.md documents commands with swarm mode"
else
  test_fail "CLAUDE.md missing command table"
fi
echo ""

echo "Test 4.2: SWARM_MODE_USAGE_GUIDE.md"
if [[ -f "${PROJECT_ROOT}/docs/swarm-mode/SWARM_MODE_USAGE_GUIDE.md" ]]; then
  test_pass "SWARM_MODE_USAGE_GUIDE.md exists"
else
  test_fail "SWARM_MODE_USAGE_GUIDE.md missing"
fi

if grep -q "## Quick Start" "${PROJECT_ROOT}/docs/swarm-mode/SWARM_MODE_USAGE_GUIDE.md"; then
  test_pass "Usage guide has Quick Start section"
else
  test_fail "Usage guide missing Quick Start"
fi

if grep -q "## Troubleshooting" "${PROJECT_ROOT}/docs/swarm-mode/SWARM_MODE_USAGE_GUIDE.md"; then
  test_pass "Usage guide has Troubleshooting section"
else
  test_fail "Usage guide missing Troubleshooting"
fi
echo ""

# ============================================================================
# Phase 5: Integration Tests
# ============================================================================
echo -e "${BLUE}═══ Phase 5: Integration Tests ═══${NC}"
echo ""

echo "Test 5.1: Phase 1 validation test"
if [[ -f "${PROJECT_ROOT}/tests/swarm-mode/test-phase-1-validation.sh" ]]; then
  test_pass "Phase 1 validation test exists"

  # Run the test
  if bash "${PROJECT_ROOT}/tests/swarm-mode/test-phase-1-validation.sh" >/dev/null 2>&1; then
    test_pass "Phase 1 validation test passes"
  else
    test_fail "Phase 1 validation test fails"
  fi
else
  test_fail "Phase 1 validation test missing"
fi
echo ""

echo "Test 5.2: All commands documented"
COMMAND_COUNT=0
for cmd in orchestrator loop edd bug adversarial parallel gates; do
  if [[ -f "${PROJECT_ROOT}/.claude/commands/${cmd}.md" ]] || [[ -f "${PROJECT_ROOT}/.claude/skills/${cmd}/SKILL.md" ]]; then
    ((COMMAND_COUNT++))
  fi
done

if [[ $COMMAND_COUNT -eq 7 ]]; then
  test_pass "All 7 commands have documentation"
else
  test_fail "Only $COMMAND_COUNT/7 commands have documentation"
fi
echo ""

echo "Test 5.3: Team composition consistency"
# All commands should document team composition
CONSISTENT_COUNT=0
for file in "${PROJECT_ROOT}/.claude/commands/loop.md" \
            "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" \
            "${PROJECT_ROOT}/.claude/commands/bug.md" \
            "${PROJECT_ROOT}/.claude/commands/adversarial.md" \
            "${PROJECT_ROOT}/.claude/commands/parallel.md" \
            "${PROJECT_ROOT}/.claude/commands/gates.md"; do
  if grep -q "### Team Composition" "$file" 2>/dev/null; then
    ((CONSISTENT_COUNT++))
  fi
done

if [[ $CONSISTENT_COUNT -eq 6 ]]; then
  test_pass "All 6 commands document team composition"
else
  test_fail "Only $CONSISTENT_COUNT/6 commands document team composition"
fi
echo ""

echo "Test 5.4: Communication patterns documented"
COMM_COUNT=0
for file in "${PROJECT_ROOT}/.claude/commands/loop.md" \
            "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" \
            "${PROJECT_ROOT}/.claude/commands/bug.md" \
            "${PROJECT_ROOT}/.claude/commands/adversarial.md" \
            "${PROJECT_ROOT}/.claude/commands/parallel.md" \
            "${PROJECT_ROOT}/.claude/commands/gates.md"; do
  if grep -q "### Communication Between Teammates" "$file" 2>/dev/null; then
    ((COMM_COUNT++))
  fi
done

if [[ $COMM_COUNT -eq 6 ]]; then
  test_pass "All 6 commands document communication patterns"
else
  test_fail "Only $COMM_COUNT/6 commands document communication patterns"
fi
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ COMPLETE INTEGRATION TEST PASSED${NC}"
  echo ""
  echo "Phase 1 (Core Commands): ✓"
  echo "Phase 2 (Secondary Commands): ✓"
  echo "Phase 3 (Global Hooks): ✓"
  echo "Phase 4 (Documentation): ✓"
  echo "Phase 5 (Integration Tests): ✓"
  echo ""
  echo "Next Steps:"
  echo "  1. Execute real swarm mode tests (Step 13)"
  echo "  2. Run /adversarial audit (Step 14)"
  echo "  3. Run /codex-cli review (Step 15)"
  echo "  4. Run /gemini-cli review (Step 16)"
  echo "  5. Fix identified issues (Step 17)"
  exit 0
else
  echo -e "${RED}✗ COMPLETE INTEGRATION TEST FAILED${NC}"
  echo ""
  echo "Please fix the following issues before proceeding:"
  exit 1
fi
