#!/bin/bash
# tests/agent-teams/test-glm5-teammates.sh
# Comprehensive test suite for GLM-5 Agent Teams integration
# Version: 2.84.0 - Complete 5-Phase Validation

# Don't exit on first error - we want to see all test results
# set -e removed for comprehensive testing

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"
TOTAL_TESTS=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test functions
pass() {
    echo -e "${GREEN}✅ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}❌ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠️  WARN${NC}: $1"
}

# === Test 1: GLM-5 API Connectivity ===
test_glm5_api_connectivity() {
    echo ""
    echo "=== Test 1: GLM-5 API Connectivity ==="

    if [ -z "$Z_AI_API_KEY" ]; then
        warn "Z_AI_API_KEY not set - skipping API test"
        return
    fi

    RESULT=$(curl -s -X POST "https://api.z.ai/api/coding/paas/v4/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $Z_AI_API_KEY" \
      --data-raw '{"model":"glm-5","messages":[{"role":"user","content":"Say hello"}],"max_tokens":50}' \
      2>/dev/null)

    if echo "$RESULT" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        pass "GLM-5 API is accessible"
    else
        fail "GLM-5 API not accessible: $(echo "$RESULT" | jq -r '.error.message // .error' 2>/dev/null)"
    fi
}

# === Test 2: Teammate Script Execution ===
test_teammate_script_execution() {
    echo ""
    echo "=== Test 2: Teammate Script Execution ==="

    SCRIPT="${PROJECT_ROOT}/.claude/scripts/glm5-teammate.sh"

    if [ ! -f "$SCRIPT" ]; then
        fail "Teammate script not found: $SCRIPT"
        return
    fi

    if [ ! -x "$SCRIPT" ]; then
        fail "Teammate script not executable: $SCRIPT"
        return
    fi

    pass "Teammate script exists and is executable"
}

# === Test 3: Hooks Exist ===
test_hooks_exist() {
    echo ""
    echo "=== Test 3: Native Hooks Exist ==="

    IDLE_HOOK="${PROJECT_ROOT}/.claude/hooks/glm5-teammate-idle.sh"
    COMPLETED_HOOK="${PROJECT_ROOT}/.claude/hooks/glm5-task-completed.sh"

    if [ -f "$IDLE_HOOK" ] && [ -x "$IDLE_HOOK" ]; then
        pass "TeammateIdle hook exists and is executable"
    else
        fail "TeammateIdle hook not found or not executable"
    fi

    if [ -f "$COMPLETED_HOOK" ] && [ -x "$COMPLETED_HOOK" ]; then
        pass "TaskCompleted hook exists and is executable"
    else
        fail "TaskCompleted hook not found or not executable"
    fi
}

# === Test 4: Directory Structure ===
test_directory_structure() {
    echo ""
    echo "=== Test 4: Directory Structure ==="

    RALPH_DIR="${PROJECT_ROOT}/.ralph"

    for dir in teammates reasoning agent-memory logs; do
        if [ -d "${RALPH_DIR}/${dir}" ]; then
            pass "Directory exists: .ralph/${dir}"
        else
            fail "Directory missing: .ralph/${dir}"
        fi
    done
}

# === Test 5: Team Status File ===
test_team_status_file() {
    echo ""
    echo "=== Test 5: Team Status File ==="

    TEAM_STATUS="${PROJECT_ROOT}/.ralph/team-status.json"

    if [ -f "$TEAM_STATUS" ]; then
        if jq -e '.team_name' "$TEAM_STATUS" > /dev/null 2>&1; then
            pass "Team status file is valid JSON"
            TEAM_NAME=$(jq -r '.team_name' "$TEAM_STATUS")
            echo "   Team name: ${TEAM_NAME}"
        else
            fail "Team status file is not valid JSON"
        fi
    else
        fail "Team status file not found: $TEAM_STATUS"
    fi
}

# === Test 6: Agent Definitions ===
test_agent_definitions() {
    echo ""
    echo "=== Test 6: Agent Definitions ==="

    AGENTS_DIR="${PROJECT_ROOT}/.claude/agents"

    for agent in glm5-coder glm5-reviewer glm5-tester; do
        AGENT_FILE="${AGENTS_DIR}/${agent}.md"
        if [ -f "$AGENT_FILE" ]; then
            pass "Agent definition exists: ${agent}.md"
        else
            fail "Agent definition missing: ${agent}.md"
        fi
    done
}

# === Test 7: Hooks Registered in settings.json ===
test_hooks_registered() {
    echo ""
    echo "=== Test 7: Hooks Registered ==="

    SETTINGS="${HOME}/.claude-sneakpeek/zai/config/settings.json"

    if [ -f "$SETTINGS" ]; then
        if jq -e '.hooks.TeammateIdle' "$SETTINGS" > /dev/null 2>&1; then
            pass "TeammateIdle hook registered in settings.json"
        else
            fail "TeammateIdle hook NOT registered in settings.json"
        fi

        if jq -e '.hooks.TaskCompleted' "$SETTINGS" > /dev/null 2>&1; then
            pass "TaskCompleted hook registered in settings.json"
        else
            fail "TaskCompleted hook NOT registered in settings.json"
        fi
    else
        warn "settings.json not found at expected location"
    fi
}

# === Test 8: Phase 3 - Orchestrator Integration ===
test_orchestrator_integration() {
    echo ""
    echo "=== Test 8: Phase 3 - Orchestrator Integration ==="

    # Check orchestrator agent
    ORCHESTRATOR="${PROJECT_ROOT}/.claude/agents/glm5-orchestrator.md"
    if [ -f "$ORCHESTRATOR" ]; then
        pass "glm5-orchestrator.md exists"
    else
        fail "glm5-orchestrator.md missing"
    fi

    # Check team coordinator script
    COORDINATOR="${PROJECT_ROOT}/.claude/scripts/glm5-team-coordinator.sh"
    if [ -f "$COORDINATOR" ] && [ -x "$COORDINATOR" ]; then
        pass "glm5-team-coordinator.sh exists and executable"
    else
        fail "glm5-team-coordinator.sh missing or not executable"
    fi
}

# === Test 9: Phase 4 - Memory Integration ===
test_memory_integration() {
    echo ""
    echo "=== Test 9: Phase 4 - Memory Integration ==="

    # Check agent memory script
    MEMORY_SCRIPT="${PROJECT_ROOT}/.claude/scripts/glm5-agent-memory.sh"
    if [ -f "$MEMORY_SCRIPT" ] && [ -x "$MEMORY_SCRIPT" ]; then
        pass "glm5-agent-memory.sh exists and executable"
    else
        fail "glm5-agent-memory.sh missing or not executable"
    fi

    # Check reasoning to memory script
    REASONING_SCRIPT="${PROJECT_ROOT}/.claude/scripts/reasoning_to_memory.py"
    if [ -f "$REASONING_SCRIPT" ] && [ -x "$REASONING_SCRIPT" ]; then
        pass "reasoning_to_memory.py exists and executable"
    else
        fail "reasoning_to_memory.py missing or not executable"
    fi

    # Test memory initialization
    TEST_AGENT="test-agent-$$"
    RESULT=$("${MEMORY_SCRIPT}" "$TEST_AGENT" project init 2>&1)
    if echo "$RESULT" | grep -q "initialized"; then
        pass "Agent memory initialization works"
        # Cleanup
        rm -rf "${PROJECT_ROOT}/.ralph/agent-memory/${TEST_AGENT}"
    else
        fail "Agent memory initialization failed"
    fi
}

# === Test 10: Team Coordinator Functional Test ===
test_team_coordinator() {
    echo ""
    echo "=== Test 10: Team Coordinator Functional Test ==="

    COORDINATOR="${PROJECT_ROOT}/.claude/scripts/glm5-team-coordinator.sh"

    if [ -x "$COORDINATOR" ]; then
        # Test status command
        RESULT=$("$COORDINATOR" "test-team-$$" "" status 2>&1)
        if echo "$RESULT" | grep -q "Team:" || echo "$RESULT" | grep -q "status"; then
            pass "Team coordinator status command works"
        else
            fail "Team coordinator status command failed"
        fi
    else
        fail "Team coordinator not executable"
    fi
}

# === Run All Tests ===
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         GLM-5 Agent Teams Integration Tests                  ║"
    echo "║         Version: 2.84.0                                      ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Project root: ${PROJECT_ROOT}"

    test_glm5_api_connectivity
    test_teammate_script_execution
    test_hooks_exist
    test_directory_structure
    test_team_status_file
    test_agent_definitions
    test_hooks_registered
    test_orchestrator_integration
    test_memory_integration
    test_team_coordinator

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      TEST SUMMARY                            ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    echo -e "║  ${GREEN}PASSED${NC}: ${TESTS_PASSED}                                              ║"
    echo -e "║  ${RED}FAILED${NC}: ${TESTS_FAILED}                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"

    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    fi
}

main "$@"
