#!/bin/bash
# test_agent_teams_integration.sh - Comprehensive Agent Teams Integration Tests
# Version: 2.86.0
# Date: 2026-02-14
#
# Tests Agent Teams hooks and custom subagents integration:
#   - TeammateIdle, TaskCompleted, SubagentStart, SubagentStop hooks
#   - ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher agents
#   - Model policy (inheritance, no per-tier routing)
#   - Processing parallel capabilities

set -e

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

# El matcher glm5-* y glm5-subagent-stop.sh se retiraron en Wave H1 (d066c63):
# su cometido lo cubre subagent-stop-universal.sh con el matcher "*".
if jq -e '.hooks.SubagentStop[] | select(.matcher == "*")' "$SETTINGS_FILE" > /dev/null 2>&1; then
    pass "SubagentStop with universal (*) matcher registered"
else
    fail "SubagentStop with universal (*) matcher NOT registered"
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
    
    # Politica vigente (~/.claude/CLAUDE.md -> Model Routing): sin enrutado por
    # complejidad; los agentes heredan el modelo de la sesion. Un override de
    # modelo en el frontmatter es lo que NO debe haber.
    # Cualquier pin es una violacion, no solo unos alias concretos: enumerar
    # (glm|sonnet|haiku) dejaba pasar `model: opus` y cualquier id futuro.
    if grep -qE "^model:[[:space:]]*inherit[[:space:]]*$" "$RALPH_CODER"; then
        pass "ralph-coder hereda el modelo de la sesion"
    elif grep -qE "^model:" "$RALPH_CODER"; then
        fail "ralph-coder fija un modelo en frontmatter (solo se admite 'inherit')"
    else
        pass "ralph-coder sin campo model (hereda)"
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
    
    # Cualquier pin es una violacion, no solo unos alias concretos: enumerar
    # (glm|sonnet|haiku) dejaba pasar `model: opus` y cualquier id futuro.
    if grep -qE "^model:[[:space:]]*inherit[[:space:]]*$" "$RALPH_REVIEWER"; then
        pass "ralph-reviewer hereda el modelo de la sesion"
    elif grep -qE "^model:" "$RALPH_REVIEWER"; then
        fail "ralph-reviewer fija un modelo en frontmatter (solo se admite 'inherit')"
    else
        pass "ralph-reviewer sin campo model (hereda)"
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
    
    # Cualquier pin es una violacion, no solo unos alias concretos: enumerar
    # (glm|sonnet|haiku) dejaba pasar `model: opus` y cualquier id futuro.
    if grep -qE "^model:[[:space:]]*inherit[[:space:]]*$" "$RALPH_TESTER"; then
        pass "ralph-tester hereda el modelo de la sesion"
    elif grep -qE "^model:" "$RALPH_TESTER"; then
        fail "ralph-tester fija un modelo en frontmatter (solo se admite 'inherit')"
    else
        pass "ralph-tester sin campo model (hereda)"
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
    
    # Cualquier pin es una violacion, no solo unos alias concretos: enumerar
    # (glm|sonnet|haiku) dejaba pasar `model: opus` y cualquier id futuro.
    if grep -qE "^model:[[:space:]]*inherit[[:space:]]*$" "$RALPH_RESEARCHER"; then
        pass "ralph-researcher hereda el modelo de la sesion"
    elif grep -qE "^model:" "$RALPH_RESEARCHER"; then
        fail "ralph-researcher fija un modelo en frontmatter (solo se admite 'inherit')"
    else
        pass "ralph-researcher sin campo model (hereda)"
    fi
else
    fail "ralph-researcher.md NOT found in $AGENTS_DIR"
fi

# =============================================================================
# TEST 10: Model policy (no per-complexity routing)
# =============================================================================
section "TEST 10: Model policy"

# La politica vigente (~/.claude/CLAUDE.md -> Model Routing) prohibe enrutar por
# umbrales y fija Opus como ejecutor. Los ANTHROPIC_DEFAULT_*_MODEL=glm-5 que
# este bloque exigia pertenecen a la era GLM-5, retirada.
if jq -e '.env | has("ANTHROPIC_DEFAULT_HAIKU_MODEL") or has("ANTHROPIC_DEFAULT_SONNET_MODEL")' "$SETTINGS_FILE" > /dev/null 2>&1; then
    fail "settings.json fija modelos por defecto por tier (routing retirado)"
else
    pass "sin routing de modelo por tier en settings.json"
fi

# =============================================================================
# TEST 11: Quality Gates Integration
# =============================================================================
section "TEST 11: Quality Gates Integration"

# quality-gates-v2.sh se retiro en Wave H1 (d066c63): los quality gates viven hoy
# en los hooks de evento TaskCompleted / TeammateIdle.
if [ -f "$HOOKS_DIR/task-completed-quality-gate.sh" ] && [ -f "$HOOKS_DIR/teammate-idle-quality-gate.sh" ]; then
    pass "quality gates presentes (task-completed + teammate-idle)"
else
    fail "faltan los hooks de quality gate (task-completed / teammate-idle)"
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


# T94: zero-tests guard — fail loud when no assertion ran. Without
# this check, a broken collection that increments zero counters would
# print 'All tests passed!' and exit 0. Mirrors the canonic pattern in
# tests/unit/test_validation_common.sh (lines 56-58).
if [[ $TESTS_PASSED -eq 0 && $TESTS_FAILED -eq 0 ]]; then
    echo "FATAL: zero tests executed — cannot declare success" >&2
    exit 1
fi
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All Agent Teams integration tests passed!${NC}"
    exit 0
else
    echo -e "${RED}$TESTS_FAILED test(s) failed${NC}"
    exit 1
fi
