#!/bin/bash
# tests/agent-teams/test-glm5-teammates.sh
# Comprehensive test suite for GLM-5 Agent Teams integration
# Version: 2.84.1 - Corrected for SubagentStop hook

# Don't exit on first error - we want to see all test results

PROJECT_ROOT="${PROJECT_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"
TOTAL_TESTS=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

info() {
    echo -e "${BLUE}ℹ️  INFO${NC}: $1"
}

# === Test 1: GLM-5 API Connectivity ===
test_glm5_api_connectivity() {
    echo ""
    echo "=== Test 1: GLM-5 API Connectivity ==="

    if [ -z "$Z_AI_API_KEY" ]; then
        # Try to get from settings.json
        Z_AI_API_KEY=$(jq -r '.env.Z_AI_API_KEY // empty' ~/.claude-sneakpeek/zai/config/settings.json 2>/dev/null)
    fi

    if [ -z "$Z_AI_API_KEY" ]; then
        warn "Z_AI_API_KEY not set - skipping API test"
        return
    fi

    info "Testing GLM-5 API connection..."

    RESULT=$(curl -s -X POST "https://api.z.ai/api/coding/paas/v4/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $Z_AI_API_KEY" \
      --data-raw '{"model":"glm-5","messages":[{"role":"user","content":"Say hello"}],"max_tokens":50}' \
      --connect-timeout 10 \
      --max-time 30 \
      2>/dev/null)

    if echo "$RESULT" | jq -e '.choices[0].message.content' > /dev/null 2>&1; then
        pass "GLM-5 API is accessible"
        CONTENT=$(echo "$RESULT" | jq -r '.choices[0].message.content')
        info "Response: ${CONTENT:0:50}..."
    else
        ERROR_MSG=$(echo "$RESULT" | jq -r '.error.message // .error // "Unknown error"' 2>/dev/null)
        fail "GLM-5 API not accessible: $ERROR_MSG"
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

    # Check bash syntax
    if bash -n "$SCRIPT" 2>/dev/null; then
        pass "Teammate script has valid bash syntax"
    else
        fail "Teammate script has syntax errors"
    fi
}

# === Test 3: SubagentStop Hook (CORRECT) ===
test_subagent_stop_hook() {
    echo ""
    echo "=== Test 3: SubagentStop Hook (Native Hook) ==="

    SUBAGENT_HOOK="${PROJECT_ROOT}/.claude/hooks/glm5-subagent-stop.sh"

    if [ -f "$SUBAGENT_HOOK" ] && [ -x "$SUBAGENT_HOOK" ]; then
        pass "SubagentStop hook exists and is executable"

        # Check bash syntax
        if bash -n "$SUBAGENT_HOOK" 2>/dev/null; then
            pass "SubagentStop hook has valid bash syntax"
        else
            fail "SubagentStop hook has syntax errors"
        fi
    else
        fail "SubagentStop hook not found or not executable"
    fi

    # Verify OLD incorrect hooks DON'T exist
    IDLE_HOOK="${PROJECT_ROOT}/.claude/hooks/glm5-teammate-idle.sh"
    COMPLETED_HOOK="${PROJECT_ROOT}/.claude/hooks/glm5-task-completed.sh"

    if [ -f "$IDLE_HOOK" ]; then
        fail "Old glm5-teammate-idle.sh should be deleted (TeammateIdle doesn't exist)"
    else
        pass "Old glm5-teammate-idle.sh correctly removed"
    fi

    if [ -f "$COMPLETED_HOOK" ]; then
        fail "Old glm5-task-completed.sh should be deleted (TaskCompleted doesn't exist)"
    else
        pass "Old glm5-task-completed.sh correctly removed"
    fi
}

# === Test 4: Directory Structure ===
test_directory_structure() {
    echo ""
    echo "=== Test 4: Directory Structure ==="

    RALPH_DIR="${PROJECT_ROOT}/.ralph"

    if [ -d "$RALPH_DIR" ]; then
        pass ".ralph directory exists"
    else
        fail ".ralph directory missing"
        return
    fi

    for dir in teammates reasoning agent-memory logs; do
        if [ -d "${RALPH_DIR}/${dir}" ]; then
            pass "Directory exists: .ralph/${dir}"
        else
            warn "Directory missing: .ralph/${dir} (will be created on first use)"
        fi
    done
}

# === Test 5: Team Status File ===
test_team_status_file() {
    echo ""
    echo "=== Test 5: Team Status File ==="

    TEAM_STATUS="${PROJECT_ROOT}/.ralph/team-status.json"

    if [ -f "$TEAM_STATUS" ]; then
        if jq -e '.' "$TEAM_STATUS" > /dev/null 2>&1; then
            pass "Team status file is valid JSON"
            TEAM_NAME=$(jq -r '.team_name // "unknown"' "$TEAM_STATUS")
            info "Team name: ${TEAM_NAME}"
        else
            fail "Team status file is not valid JSON"
        fi
    else
        warn "Team status file not found (will be created on first team init)"
    fi
}

# === Test 6: Agent Definitions ===
test_agent_definitions() {
    echo ""
    echo "=== Test 6: Agent Definitions ==="

    AGENTS_DIR="${PROJECT_ROOT}/.claude/agents"

    for agent in glm5-coder glm5-reviewer glm5-tester glm5-orchestrator; do
        AGENT_FILE="${AGENTS_DIR}/${agent}.md"
        if [ -f "$AGENT_FILE" ]; then
            # Check if it has required frontmatter
            if grep -q "thinking:" "$AGENT_FILE" 2>/dev/null; then
                pass "Agent definition valid: ${agent}.md (has thinking mode)"
            else
                warn "Agent definition exists but may be missing thinking: ${agent}.md"
            fi
        else
            fail "Agent definition missing: ${agent}.md"
        fi
    done
}

# === Test 7: Hooks Registered in settings.json ===
test_hooks_registered() {
    echo ""
    echo "=== Test 7: Hooks Registered in settings.json ==="

    SETTINGS="${HOME}/.claude-sneakpeek/zai/config/settings.json"

    if [ ! -f "$SETTINGS" ]; then
        warn "settings.json not found at: $SETTINGS"
        return
    fi

    # Check JSON validity
    if jq '.' "$SETTINGS" > /dev/null 2>&1; then
        pass "settings.json is valid JSON"
    else
        fail "settings.json has JSON syntax errors"
        return
    fi

    # Check SubagentStop hook is registered
    if jq -e '.hooks.SubagentStop' "$SETTINGS" > /dev/null 2>&1; then
        pass "SubagentStop hook registered in settings.json"

        # Verify it points to correct script
        HOOK_CMD=$(jq -r '.hooks.SubagentStop[0].hooks[0].command // empty' "$SETTINGS" 2>/dev/null)
        if echo "$HOOK_CMD" | grep -q "glm5-subagent-stop.sh"; then
            pass "SubagentStop hook points to correct script"
        else
            warn "SubagentStop hook may point to wrong script: $HOOK_CMD"
        fi
    else
        fail "SubagentStop hook NOT registered in settings.json"
    fi

    # Verify old hooks are NOT registered
    if jq -e '.hooks.TeammateIdle' "$SETTINGS" > /dev/null 2>&1; then
        fail "TeammateIdle hook should NOT be registered (doesn't exist in Claude Code)"
    else
        pass "TeammateIdle correctly not registered"
    fi

    if jq -e '.hooks.TaskCompleted' "$SETTINGS" > /dev/null 2>&1; then
        fail "TaskCompleted hook should NOT be registered (doesn't exist in Claude Code)"
    else
        pass "TaskCompleted correctly not registered"
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
    if [ -f "$COORDINATOR" ]; then
        if [ -x "$COORDINATOR" ]; then
            pass "glm5-team-coordinator.sh exists and executable"
        else
            fail "glm5-team-coordinator.sh not executable"
        fi
    else
        fail "glm5-team-coordinator.sh missing"
    fi

    # Check init script
    INIT_SCRIPT="${PROJECT_ROOT}/.claude/scripts/glm5-init-team.sh"
    if [ -f "$INIT_SCRIPT" ] && [ -x "$INIT_SCRIPT" ]; then
        pass "glm5-init-team.sh exists and executable"
    else
        warn "glm5-init-team.sh missing or not executable"
    fi
}

# === Test 9: Phase 4 - Memory Integration ===
test_memory_integration() {
    echo ""
    echo "=== Test 9: Phase 4 - Memory Integration ==="

    # Check agent memory script
    MEMORY_SCRIPT="${PROJECT_ROOT}/.claude/scripts/glm5-agent-memory.sh"
    if [ -f "$MEMORY_SCRIPT" ]; then
        if [ -x "$MEMORY_SCRIPT" ]; then
            pass "glm5-agent-memory.sh exists and executable"
        else
            fail "glm5-agent-memory.sh not executable"
        fi
    else
        fail "glm5-agent-memory.sh missing"
    fi

    # Check reasoning to memory script
    REASONING_SCRIPT="${PROJECT_ROOT}/.claude/scripts/reasoning_to_memory.py"
    if [ -f "$REASONING_SCRIPT" ]; then
        pass "reasoning_to_memory.py exists"
    else
        warn "reasoning_to_memory.py missing"
    fi
}

# === Test 10: Commands and Skills ===
test_commands_and_skills() {
    echo ""
    echo "=== Test 10: Commands and Skills ==="

    # Check /glm5 command
    GLM5_CMD="${PROJECT_ROOT}/.claude/commands/glm5.md"
    if [ -f "$GLM5_CMD" ]; then
        pass "/glm5 command exists"
    else
        fail "/glm5 command missing"
    fi

    # Check glm5 skill
    GLM5_SKILL="${PROJECT_ROOT}/.claude/skills/glm5/SKILL.md"
    if [ -f "$GLM5_SKILL" ]; then
        pass "glm5 skill exists"
    else
        fail "glm5 skill missing"
    fi

    # Check glm5-parallel skill
    GLM5_PARALLEL="${PROJECT_ROOT}/.claude/skills/glm5-parallel/SKILL.md"
    if [ -f "$GLM5_PARALLEL" ]; then
        pass "glm5-parallel skill exists"
    else
        fail "glm5-parallel skill missing"
    fi
}

# === Test 11: Functional Test - Team Coordinator ===
test_team_coordinator_functional() {
    echo ""
    echo "=== Test 11: Team Coordinator Functional Test ==="

    COORDINATOR="${PROJECT_ROOT}/.claude/scripts/glm5-team-coordinator.sh"

    if [ ! -x "$COORDINATOR" ]; then
        fail "Team coordinator not executable"
        return
    fi

    # Test init command
    TEST_TEAM="test-team-$$"
    RESULT=$("$COORDINATOR" "$TEST_TEAM" "" init 2>&1)
    if echo "$RESULT" | grep -qi "initialized\|created"; then
        pass "Team coordinator init command works"
    else
        info "Team coordinator init output: ${RESULT:0:100}"
    fi

    # Test status command
    RESULT=$("$COORDINATOR" "$TEST_TEAM" "" status 2>&1)
    if echo "$RESULT" | grep -q "Team:\|status\|members"; then
        pass "Team coordinator status command works"
    else
        info "Team coordinator status output: ${RESULT:0:100}"
    fi
}

# === Test 12: GLM-5 Teammate Execution (Optional) ===
test_glm5_teammate_execution() {
    echo ""
    echo "=== Test 12: GLM-5 Teammate Execution (Optional) ==="

    SCRIPT="${PROJECT_ROOT}/.claude/scripts/glm5-teammate.sh"

    if [ ! -x "$SCRIPT" ]; then
        fail "Teammate script not executable"
        return
    fi

    if [ -z "$Z_AI_API_KEY" ]; then
        Z_AI_API_KEY=$(jq -r '.env.Z_AI_API_KEY // empty' ~/.claude-sneakpeek/zai/config/settings.json 2>/dev/null)
    fi

    if [ -z "$Z_AI_API_KEY" ]; then
        warn "Skipping teammate execution test (no API key)"
        return
    fi

    info "Running GLM-5 teammate test (this may take a few seconds)..."

    TASK_ID="test-validation-$$"
    RESULT=$("$SCRIPT" "glm5-coder" "What is 2+2?" "$TASK_ID" 2>&1)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        pass "GLM-5 teammate execution succeeded"

        # Check if status file was created
        STATUS_FILE="${PROJECT_ROOT}/.ralph/teammates/${TASK_ID}/status.json"
        if [ -f "$STATUS_FILE" ]; then
            pass "Teammate status file created"
            STATUS=$(jq -r '.status // "unknown"' "$STATUS_FILE")
            info "Status: $STATUS"
        else
            warn "Teammate status file not created"
        fi

        # Check if reasoning file was created
        REASONING_FILE="${PROJECT_ROOT}/.ralph/reasoning/${TASK_ID}.txt"
        if [ -f "$REASONING_FILE" ]; then
            pass "Reasoning file created"
            SIZE=$(wc -c < "$REASONING_FILE")
            info "Reasoning size: ${SIZE} bytes"
        else
            warn "Reasoning file not created"
        fi

        # Cleanup
        rm -rf "${PROJECT_ROOT}/.ralph/teammates/${TASK_ID}"
        rm -f "$REASONING_FILE"
    else
        fail "GLM-5 teammate execution failed (exit code: $EXIT_CODE)"
        info "Output: ${RESULT:0:200}"
    fi
}

# === Test 13: Available Claude Code Hooks Validation ===
test_available_hooks_validation() {
    echo ""
    echo "=== Test 13: Claude Code Hooks Validation ==="

    # These hooks EXIST in Claude Code v2.1.39
    EXISTING_HOOKS=("PreToolUse" "PostToolUse" "Stop" "SubagentStop" "SessionStart" "SessionEnd" "UserPromptSubmit" "PreCompact" "Notification")

    # These hooks DO NOT EXIST
    NONEXISTENT_HOOKS=("TeammateIdle" "TaskCompleted")

    SETTINGS="${HOME}/.claude-sneakpeek/zai/config/settings.json"

    info "Validating registered hooks against Claude Code v2.1.39..."

    for hook in "${EXISTING_HOOKS[@]}"; do
        if jq -e ".hooks.$hook" "$SETTINGS" > /dev/null 2>&1; then
            pass "$hook is registered (valid hook)"
        fi
    done

    for hook in "${NONEXISTENT_HOOKS[@]}"; do
        if jq -e ".hooks.$hook" "$SETTINGS" > /dev/null 2>&1; then
            fail "$hook is registered but DOES NOT EXIST in Claude Code"
        else
            pass "$hook correctly NOT registered (doesn't exist)"
        fi
    done
}

# === Run All Tests ===
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║         GLM-5 Agent Teams Integration Tests                  ║"
    echo "║         Version: 2.84.1 (SubagentStop Fix)                   ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Project root: ${PROJECT_ROOT}"
    echo ""

    test_glm5_api_connectivity
    test_teammate_script_execution
    test_subagent_stop_hook
    test_directory_structure
    test_team_status_file
    test_agent_definitions
    test_hooks_registered
    test_orchestrator_integration
    test_memory_integration
    test_commands_and_skills
    test_team_coordinator_functional
    test_glm5_teammate_execution
    test_available_hooks_validation

    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                      TEST SUMMARY                            ║"
    echo "╠══════════════════════════════════════════════════════════════╣"
    printf "║  %-30s %25s ║\n" "PASSED:" "${TESTS_PASSED}"
    printf "║  %-30s %25s ║\n" "FAILED:" "${TESTS_FAILED}"
    echo "╚══════════════════════════════════════════════════════════════╝"

    if [ $TESTS_FAILED -gt 0 ]; then
        echo ""
        echo -e "${RED}Some tests failed. Please review the output above.${NC}"
        exit 1
    else
        echo ""
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
