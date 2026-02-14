#!/bin/bash
# test_agent_teams_integration.sh - Comprehensive Agent Teams Integration Tests
# Version: 2.86.0
# Date: 2026-02-14
#
# Tests Agent Teams hooks and custom subagents integration:
#   - TeammateIdle, TaskCompleted, SubagentStart, SubagentStop hooks
#   - ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher agents
#   - GLM-5 model configuration
#   - Processing parallel capabilities

set -e

# Configuration
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
SETTINGS_FILE="$HOME/.claude/settings.json"
AGENTS_DIR="$HOME/.claude/agents"
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
echo " Agent Teams Integration Test Suite"
echo " Version: 2.86.0"
echo "========================================"
echo ""
echo "Repository: $REPO_ROOT"
echo "Settings: $SETTINGS_FILE"
echo "Agents Dir: $AGENTS_DIR"
echo ""

# =============================================================================
# TEST 1: Agent Teams Feature Enabled
# =============================================================================
section "TEST 1: Agent Teams Feature Enabled"

if jq -e '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS == "1"' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS enabled"
else
    fail "Agent Teams NOT enabled in settings"
fi

# =============================================================================
# TEST 2: TeammateIdle Hook
# =============================================================================
section "TEST 2: TeammateIdle Hook"

# Check hook file exists
if [ -f "$HOOKS_DIR/teammate-idle-quality-gate.sh" ]; then
    pass "teammate-idle-quality-gate.sh exists"
else
    fail "teammate-idle-quality-gate.sh missing"
fi

# Check hook is executable
if [ -x "$HOOKS_DIR/teammate-idle-quality-gate.sh" ]; then
    pass "teammate-idle-quality-gate.sh is executable"
else
    fail "teammate-idle-quality-gate.sh not executable"
fi

# Check hook is registered
if jq -e '.hooks.TeammateIdle' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "TeammateIdle hook registered in settings.json"
else
    fail "TeammateIdle hook NOT registered"
fi

# =============================================================================
# TEST 3: TaskCompleted Hook
# =============================================================================
section "TEST 3: TaskCompleted Hook"

# Check hook file exists
if [ -f "$HOOKS_DIR/task-completed-quality-gate.sh" ]; then
    pass "task-completed-quality-gate.sh exists"
else
    fail "task-completed-quality-gate.sh missing"
fi

# Check hook is executable
if [ -x "$HOOKS_DIR/task-completed-quality-gate.sh" ]; then
    pass "task-completed-quality-gate.sh is executable"
else
    fail "task-completed-quality-gate.sh not executable"
fi

# Check hook is registered
if jq -e '.hooks.TaskCompleted' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "TaskCompleted hook registered in settings.json"
else
    fail "TaskCompleted hook NOT registered"
fi

# =============================================================================
# TEST 4: SubagentStart Hook for ralph-*
# =============================================================================
section "TEST 4: SubagentStart Hook for ralph-*"

# Check hook file exists
if [ -f "$HOOKS_DIR/ralph-subagent-start.sh" ]; then
    pass "ralph-subagent-start.sh exists"
else
    fail "ralph-subagent-start.sh missing"
fi

# Check hook is executable
if [ -x "$HOOKS_DIR/ralph-subagent-start.sh" ]; then
    pass "ralph-subagent-start.sh is executable"
else
    fail "ralph-subagent-start.sh not executable"
fi

# Check hook is registered with ralph-* matcher
if jq -e '.hooks.SubagentStart[] | select(.matcher == "ralph-*")' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "SubagentStart with ralph-* matcher registered"
else
    fail "SubagentStart with ralph-* matcher NOT registered"
fi

# =============================================================================
# TEST 5: SubagentStop Hooks
# =============================================================================
section "TEST 5: SubagentStop Hooks"

# Check SubagentStop for ralph-*
if jq -e '.hooks.SubagentStop[] | select(.matcher == "ralph-*")' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "SubagentStop with ralph-* matcher registered"
else
    fail "SubagentStop with ralph-* matcher NOT registered"
fi

# Check SubagentStop for glm5-*
if jq -e '.hooks.SubagentStop[] | select(.matcher == "glm5-*")' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "SubagentStop with glm5-* matcher registered"
else
    fail "SubagentStop with glm5-* matcher NOT registered"
fi

# Check glm5-subagent-stop.sh exists
if [ -f "$HOOKS_DIR/glm5-subagent-stop.sh" ] && [ -x "$HOOKS_DIR/glm5-subagent-stop.sh" ]; then
    pass "glm5-subagent-stop.sh exists and executable"
else
    fail "glm5-subagent-stop.sh missing or not executable"
fi

# =============================================================================
# TEST 6: Custom Subagents - ralph-coder
# =============================================================================
section "TEST 6: Custom Subagent - ralph-coder"

RALPH_CODER="$AGENTS_DIR/ralph-coder.md"

if [ -f "$RALPH_CODER" ]; then
    pass "ralph-coder.md exists in global agents"
    
    # Check frontmatter
    if grep -q "name: ralph-coder" "$RALPH_CODER"; then
        pass "ralph-coder has correct name in frontmatter"
    else
        fail "ralph-coder missing name in frontmatter"
    fi
    
    # Check model is glm-5
    if grep -q "model: glm-5" "$RALPH_CODER"; then
        pass "ralph-coder configured with glm-5 model"
    else
        fail "ralph-coder NOT configured with glm-5 model"
    fi
    
    # Check tools
    if grep -q "tools:" "$RALPH_CODER"; then
        pass "ralph-coder has tools defined"
    else
        fail "ralph-coder missing tools definition"
    fi
else
    fail "ralph-coder.md NOT found in $AGENTS_DIR"
fi

# =============================================================================
# TEST 7: Custom Subagents - ralph-reviewer
# =============================================================================
section "TEST 7: Custom Subagent - ralph-reviewer"

RALPH_REVIEWER="$AGENTS_DIR/ralph-reviewer.md"

if [ -f "$RALPH_REVIEWER" ]; then
    pass "ralph-reviewer.md exists in global agents"
    
    if grep -q "name: ralph-reviewer" "$RALPH_REVIEWER"; then
        pass "ralph-reviewer has correct name in frontmatter"
    else
        fail "ralph-reviewer missing name in frontmatter"
    fi
    
    if grep -q "model: glm-5" "$RALPH_REVIEWER"; then
        pass "ralph-reviewer configured with glm-5 model"
    else
        fail "ralph-reviewer NOT configured with glm-5 model"
    fi
else
    fail "ralph-reviewer.md NOT found in $AGENTS_DIR"
fi

# =============================================================================
# TEST 8: Custom Subagents - ralph-tester
# =============================================================================
section "TEST 8: Custom Subagent - ralph-tester"

RALPH_TESTER="$AGENTS_DIR/ralph-tester.md"

if [ -f "$RALPH_TESTER" ]; then
    pass "ralph-tester.md exists in global agents"
    
    if grep -q "name: ralph-tester" "$RALPH_TESTER"; then
        pass "ralph-tester has correct name in frontmatter"
    else
        fail "ralph-tester missing name in frontmatter"
    fi
    
    if grep -q "model: glm-5" "$RALPH_TESTER"; then
        pass "ralph-tester configured with glm-5 model"
    else
        fail "ralph-tester NOT configured with glm-5 model"
    fi
else
    fail "ralph-tester.md NOT found in $AGENTS_DIR"
fi

# =============================================================================
# TEST 9: Custom Subagents - ralph-researcher
# =============================================================================
section "TEST 9: Custom Subagent - ralph-researcher"

RALPH_RESEARCHER="$AGENTS_DIR/ralph-researcher.md"

if [ -f "$RALPH_RESEARCHER" ]; then
    pass "ralph-researcher.md exists in global agents"
    
    if grep -q "name: ralph-researcher" "$RALPH_RESEARCHER"; then
        pass "ralph-researcher has correct name in frontmatter"
    else
        fail "ralph-researcher missing name in frontmatter"
    fi
    
    if grep -q "model: glm-5" "$RALPH_RESEARCHER"; then
        pass "ralph-researcher configured with glm-5 model"
    else
        fail "ralph-researcher NOT configured with glm-5 model"
    fi
else
    fail "ralph-researcher.md NOT found in $AGENTS_DIR"
fi

# =============================================================================
# TEST 10: GLM-5 Default Model Configuration
# =============================================================================
section "TEST 10: GLM-5 Default Model Configuration"

# Check GLM-5 is default for Haiku
if jq -e '.env.ANTHROPIC_DEFAULT_HAIKU_MODEL == "glm-5"' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "GLM-5 configured as default Haiku model"
else
    fail "GLM-5 NOT configured as default Haiku model"
fi

# Check GLM-5 is default for Sonnet
if jq -e '.env.ANTHROPIC_DEFAULT_SONNET_MODEL == "glm-5"' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "GLM-5 configured as default Sonnet model"
else
    fail "GLM-5 NOT configured as default Sonnet model"
fi

# Check GLM-5 is default for Opus
if jq -e '.env.ANTHROPIC_DEFAULT_OPUS_MODEL == "glm-5"' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "GLM-5 configured as default Opus model"
else
    fail "GLM-5 NOT configured as default Opus model"
fi

# =============================================================================
# TEST 11: Quality Gates Integration
# =============================================================================
section "TEST 11: Quality Gates Integration"

# Check quality-gates-v2.sh exists
if [ -f "$HOOKS_DIR/quality-gates-v2.sh" ]; then
    pass "quality-gates-v2.sh exists"
else
    fail "quality-gates-v2.sh missing"
fi

# Check teammate-idle-quality-gate.sh references quality standards
if grep -qE "(CORRECTNESS|QUALITY|SECURITY|CONSISTENCY)" "$HOOKS_DIR/teammate-idle-quality-gate.sh" 2>/dev/null; then
    pass "teammate-idle hook references quality standards"
else
    info "teammate-idle hook may not explicitly reference quality standards"
fi

# Check task-completed-quality-gate.sh has exit codes
if grep -q "exit 2" "$HOOKS_DIR/task-completed-quality-gate.sh" 2>/dev/null; then
    pass "task-completed hook uses exit 2 for blocking"
else
    info "task-completed hook may not use exit 2 for blocking"
fi

# =============================================================================
# TEST 12: Background Processing Capability
# =============================================================================
section "TEST 12: Background Processing Capability"

# Check for async hooks
ASYNC_COUNT=$(jq '[.hooks | .. | objects | select(.async == true)] | length' "$SETTINGS_FILE" 2>/dev/null || echo "0")
if [ "$ASYNC_COUNT" -gt 0 ]; then
    pass "$ASYNC_COUNT async hooks configured for background processing"
else
    info "No async hooks configured (background processing may be limited)"
fi

# =============================================================================
# TEST 13: Hook Timeout Configuration
# =============================================================================
section "TEST 13: Hook Timeout Configuration"

# Check TeammateIdle timeout
IDLE_TIMEOUT=$(jq -r '.hooks.TeammateIdle[0].hooks[0].timeout // "not set"' "$SETTINGS_FILE" 2>/dev/null)
if [ "$IDLE_TIMEOUT" != "not set" ] && [ "$IDLE_TIMEOUT" != "null" ]; then
    pass "TeammateIdle has timeout: ${IDLE_TIMEOUT}s"
else
    info "TeammateIdle missing timeout configuration"
fi

# Check TaskCompleted timeout
COMPLETED_TIMEOUT=$(jq -r '.hooks.TaskCompleted[0].hooks[0].timeout // "not set"' "$SETTINGS_FILE" 2>/dev/null)
if [ "$COMPLETED_TIMEOUT" != "not set" ] && [ "$COMPLETED_TIMEOUT" != "null" ]; then
    pass "TaskCompleted has timeout: ${COMPLETED_TIMEOUT}s"
else
    info "TaskCompleted missing timeout configuration"
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
    echo -e "${GREEN}All Agent Teams integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$TESTS_FAILED test(s) failed${NC}"
    exit 1
fi
