#!/usr/bin/env bash
# test-phase-1-validation.sh
# Validates Phase 1 of swarm mode integration
# Tests: /loop, /edd, /bug commands

# Don't exit on error - we want to run all tests
set +e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
  echo -e "${YELLOW}ℹ INFO${NC}: $msg"
  ((TESTS_RUN++))
}

echo "=========================================="
echo "Phase 1 Validation - Swarm Mode v2.81.1"
echo "=========================================="
echo ""

# Test 1: Verify /loop has swarm mode
echo "Test 1: Check /loop command has swarm mode"
if grep -q "team_name.*loop-execution-team" "${PROJECT_ROOT}/.claude/commands/loop.md" 2>/dev/null; then
  test_pass "/loop has team_name configuration"
else
  test_fail "/loop missing team_name"
fi

if grep -q "mode.*delegate" "${PROJECT_ROOT}/.claude/commands/loop.md" 2>/dev/null; then
  test_pass "/loop has mode: delegate"
else
  test_fail "/loop missing mode: delegate"
fi

if grep -q "run_in_background.*true" "${PROJECT_ROOT}/.claude/commands/loop.md" 2>/dev/null; then
  test_pass "/loop has run_in_background: true"
else
  test_fail "/loop missing run_in_background: true"
fi
echo ""

# Test 2: Verify /edd has swarm mode
echo "Test 2: Check /edd skill has swarm mode"
if grep -q "team_name.*edd-evaluation-team" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" 2>/dev/null; then
  test_pass "/edd has team_name configuration"
else
  test_fail "/edd missing team_name"
fi

if grep -q "mode.*delegate" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" 2>/dev/null; then
  test_pass "/edd has mode: delegate"
else
  test_fail "/edd missing mode: delegate"
fi

if grep -q "run_in_background.*true" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" 2>/dev/null; then
  test_pass "/edd has run_in_background: true"
else
  test_fail "/edd missing run_in_background: true"
fi
echo ""

# Test 3: Verify /bug has swarm mode
echo "Test 3: Check /bug command has swarm mode"
if grep -q "team_name.*bug-analysis-team" "${PROJECT_ROOT}/.claude/commands/bug.md" 2>/dev/null; then
  test_pass "/bug has team_name configuration"
else
  test_fail "/bug missing team_name"
fi

if grep -q "mode.*delegate" "${PROJECT_ROOT}/.claude/commands/bug.md" 2>/dev/null; then
  test_pass "/bug has mode: delegate"
else
  test_fail "/bug missing mode: delegate"
fi

if grep -q "run_in_background.*true" "${PROJECT_ROOT}/.claude/commands/bug.md" 2>/dev/null; then
  test_pass "/bug has run_in_background: true"
else
  test_fail "/bug missing run_in_background: true"
fi
echo ""

# Test 4: Verify team composition documented
echo "Test 4: Check team composition is documented"
LOOP_TEAM=$(grep -c "Teammate.*specialist" "${PROJECT_ROOT}/.claude/commands/loop.md" 2>/dev/null || echo "0")
if [[ "$LOOP_TEAM" -ge 3 ]]; then
  test_pass "/loop documents $LOOP_TEAM teammates"
else
  test_fail "/loop only documents $LOOP_TEAM teammates (expected >= 3)"
fi

EDD_TEAM=$(grep -c "Teammate.*specialist" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" 2>/dev/null || echo "0")
if [[ "$EDD_TEAM" -ge 3 ]]; then
  test_pass "/edd documents $EDD_TEAM teammates"
else
  test_fail "/edd only documents $EDD_TEAM teammates (expected >= 3)"
fi

BUG_TEAM=$(grep -c "Teammate.*specialist" "${PROJECT_ROOT}/.claude/commands/bug.md" 2>/dev/null || echo "0")
if [[ "$BUG_TEAM" -ge 3 ]]; then
  test_pass "/bug documents $BUG_TEAM teammates"
else
  test_fail "/bug only documents $BUG_TEAM teammates (expected >= 3)"
fi
echo ""

# Test 5: Verify communication patterns documented
echo "Test 5: Check communication patterns are documented"
COMM_PATTERN_COUNT=0
for file in "${PROJECT_ROOT}/.claude/commands/loop.md" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" "${PROJECT_ROOT}/.claude/commands/bug.md"; do
  if grep -q "SendMessage" "$file" 2>/dev/null; then
    ((COMM_PATTERN_COUNT++))
  fi
done
if [[ "$COMM_PATTERN_COUNT" -eq 3 ]]; then
  test_pass "All 3 commands document SendMessage communication"
else
  test_fail "Only $COMM_PATTERN_COUNT/3 commands document SendMessage"
fi
echo ""

# Test 6: Verify task list coordination mentioned
echo "Test 6: Check task list coordination is documented"
TASK_COUNT=0
for file in "${PROJECT_ROOT}/.claude/commands/loop.md" "${PROJECT_ROOT}/.claude/skills/edd/SKILL.md" "${PROJECT_ROOT}/.claude/commands/bug.md"; do
  if grep -q "TaskList\|task list\|~/.claude/tasks/" "$file" 2>/dev/null; then
    ((TASK_COUNT++))
  fi
done
if [[ "$TASK_COUNT" -eq 3 ]]; then
  test_pass "All 3 commands document task list coordination"
else
  test_fail "Only $TASK_COUNT/3 commands document task list coordination"
fi
echo ""

# Summary
echo "=========================================="
echo "Phase 1 Validation Summary"
echo "=========================================="
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ Phase 1 VALIDATION PASSED${NC}"
  echo ""
  echo "Core Commands Status:"
  echo "  • /loop: Swarm mode enabled ✓"
  echo "  • /edd: Swarm mode enabled ✓"
  echo "  • /bug: Swarm mode enabled ✓"
  echo ""
  echo "Next Steps:"
  echo "  • Proceed to Phase 2: Secondary Commands"
  echo "  • Update /adversarial, /parallel, /gates"
  exit 0
else
  echo -e "${RED}✗ Phase 1 VALIDATION FAILED${NC}"
  echo ""
  echo "Please fix the following issues before proceeding:"
  exit 1
fi
