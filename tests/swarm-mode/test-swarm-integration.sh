#!/usr/bin/env bash
# test-swarm-integration.sh
# Validates that swarm mode is properly configured and functional
# Part of Multi-Agent Ralph Loop v2.81.1

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

test_skip() {
  local msg="$1"
  echo -e "${YELLOW}⊘ SKIP${NC}: $msg"
  ((TESTS_RUN++))
}

echo "=========================================="
echo "Swarm Mode Integration Test v2.81.1"
echo "=========================================="
echo ""

# Check 1: Verify settings.json exists
echo "Test 1: Check settings.json exists"
if [[ -f ~/.claude-sneakpeek/zai/config/settings.json ]]; then
  test_pass "settings.json exists"
else
  test_fail "settings.json not found"
  echo "  Expected: ~/.claude-sneakpeek/zai/config/settings.json"
  exit 1
fi
echo ""

# Check 2: Verify defaultMode is delegate (in permissions, not root)
echo "Test 2: Check defaultMode configuration"
DEFAULT_MODE=$(jq -r '.permissions.defaultMode // "none"' ~/.claude-sneakpeek/zai/config/settings.json 2>/dev/null || echo "none")
if [[ "$DEFAULT_MODE" == "delegate" ]]; then
  test_pass "permissions.defaultMode is 'delegate'"
else
  test_fail "permissions.defaultMode is '$DEFAULT_MODE' (expected 'delegate')"
fi
echo ""

# Check 3: Verify teammate environment variables exist
echo "Test 3: Check swarm environment variables"
AGENT_ID=$(jq -r '.env.CLAUDE_CODE_AGENT_ID // "null"' ~/.claude-sneakpeek/zai/config/settings.json 2>/dev/null || echo "null")
AGENT_NAME=$(jq -r '.env.CLAUDE_CODE_AGENT_NAME // "null"' ~/.claude-sneakpeek/zai/config/settings.json 2>/dev/null || echo "null")
TEAM_NAME=$(jq -r '.env.CLAUDE_CODE_TEAM_NAME // "null"' ~/.claude-sneakpeek/zai/config/settings.json 2>/dev/null || echo "null")

if [[ "$AGENT_ID" != "null" ]] && [[ "$AGENT_NAME" != "null" ]] && [[ "$TEAM_NAME" != "null" ]]; then
  test_pass "Swarm environment variables configured"
  echo "  - CLAUDE_CODE_AGENT_ID: $AGENT_ID"
  echo "  - CLAUDE_CODE_AGENT_NAME: $AGENT_NAME"
  echo "  - CLAUDE_CODE_TEAM_NAME: $TEAM_NAME"
else
  test_fail "Swarm environment variables missing"
  echo "  - CLAUDE_CODE_AGENT_ID: $AGENT_ID (required)"
  echo "  - CLAUDE_CODE_AGENT_NAME: $AGENT_NAME (required)"
  echo "  - CLAUDE_CODE_TEAM_NAME: $TEAM_NAME (required)"
fi
echo ""

# Check 4: Verify PLAN_MODE_REQUIRED is set
echo "Test 4: Check CLAUDE_CODE_PLAN_MODE_REQUIRED"
PLAN_MODE=$(jq -r '.env.CLAUDE_CODE_PLAN_MODE_REQUIRED // "null"' ~/.claude-sneakpeek/zai/config/settings.json 2>/dev/null || echo "null")
if [[ "$PLAN_MODE" != "null" ]]; then
  test_pass "CLAUDE_CODE_PLAN_MODE_REQUIRED is set to '$PLAN_MODE'"
else
  test_fail "CLAUDE_CODE_PLAN_MODE_REQUIRED is not configured (optional)"
fi
echo ""

# Note: teammateCount and swarmTimeoutMinutes are CLI parameters, NOT settings.json fields
echo "Test 5: teammateCount and swarmTimeoutMinutes (INFO)"
echo "⊘ SKIP: teammateCount and swarmTimeoutMinutes are CLI parameters"
echo "  These are passed to /orchestrator or /loop commands, NOT in settings.json"
echo "  Example: /orchestrator 'task' --teammateCount 3 --swarmTimeoutMinutes 30"
echo ""

# Check 6: Verify orchestrator.md documents swarm mode
echo "Test 6: Check orchestrator.md documentation"
ORCHESTRATOR_MD=".claude/commands/orchestrator.md"
if [[ -f "$ORCHESTRATOR_MD" ]]; then
  if grep -q "swarm mode\|team_name\|launchSwarm" "$ORCHESTRATOR_MD" 2>/dev/null; then
    test_pass "orchestrator.md documents swarm mode"
  else
    test_fail "orchestrator.md missing swarm mode documentation"
  fi
else
  test_fail "orchestrator.md not found"
fi
echo ""

# Check 7: Verify spawn mode parameters in ExitPlanMode
echo "Test 7: Check ExitPlanMode launchSwarm documentation"
if grep -q "launchSwarm.*true" "$ORCHESTRATOR_MD" 2>/dev/null; then
  test_pass "ExitPlanMode documents launchSwarm: true"
else
  test_fail "ExitPlanMode launchSwarm not properly documented"
fi
echo ""

# Check 8: Verify agent definitions support swarm mode
echo "Test 8: Check agent definitions"
AGENT_COUNT=$(ls -1 .claude/agents/*.md 2>/dev/null | wc -l)
if [[ "$AGENT_COUNT" -ge 10 ]]; then
  test_pass "Found $AGENT_COUNT agent definitions (>= 10)"
else
  test_fail "Found only $AGENT_COUNT agent definitions (expected >= 10)"
fi
echo ""

# Summary
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo "Tests Run:    $TESTS_RUN"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
  echo -e "${GREEN}✓ All configuration tests passed!${NC}"
  echo ""
  echo "Next Steps:"
  echo "1. Test actual swarm execution with: /orchestrator 'simple test task'"
  echo "2. Verify teammates are spawned in Claude Code UI"
  echo "3. Confirm inter-agent messaging works"
  echo "4. Validate shared task list functionality"
  exit 0
else
  echo -e "${RED}✗ Some tests failed. Fix configuration issues before using swarm mode.${NC}"
  exit 1
fi
