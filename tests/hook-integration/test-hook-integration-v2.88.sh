#!/bin/bash
#
# Hook Integration End-to-End Test Suite v2.88.0
# Validates all 5 findings from adversarial analysis are fixed
#
# Usage: ./tests/hook-integration/test-hook-integration-v2.88.sh [-v]
#

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"
TEAMS_DIR="$HOME/.claude/teams"
VERBOSE=false

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Parse arguments
[[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]] && VERBOSE=true

pass() { ((TESTS_PASSED++)); printf "${GREEN}.${NC}"; }
fail() { ((TESTS_FAILED++)); printf "${RED}F${NC}"; }

print_test() {
    $VERBOSE && echo -e "  Test: $1"
}

print_header() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

cleanup_test_state() {
    rm -rf "$STATE_DIR/test-session" 2>/dev/null || true
    rm -rf "$TEAMS_DIR/test-team" 2>/dev/null || true
    rm -rf "$HOME/.claude/tasks/test-team" 2>/dev/null || true
}

#######################################
# Test 1: ralph-subagent-stop.sh (Finding #1 - CRITICAL)
#######################################
test_ralph_subagent_stop() {
    print_header "Test 1: ralph-subagent-stop.sh (Finding #1)"

    cleanup_test_state

    # Test 1.1: Hook file exists and is executable
    print_test "ralph-subagent-stop.sh exists and is executable"
    if [[ -x "$REPO_ROOT/.claude/hooks/ralph-subagent-stop.sh" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ ralph-subagent-stop.sh not found or not executable${NC}"
    fi

    # Test 1.2: Subagent with incomplete task should block
    print_test "Blocks stop when subagent has incomplete task"
    mkdir -p "$STATE_DIR/test-session/subagents"
    echo '{"status": "working", "task": "implement-auth"}' > "$STATE_DIR/test-session/subagents/test-subagent.json"

    RESULT=$(echo '{"subagentId": "test-subagent", "subagentType": "ralph-coder", "sessionId": "test-session"}' | \
        "$REPO_ROOT/.claude/hooks/ralph-subagent-stop.sh" 2>/dev/null || true)

    if echo "$RESULT" | grep -q '"decision": "block"'; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Should block when subagent working${NC}"
    fi

    # Test 1.3: Subagent with completed task should allow stop
    print_test "Allows stop when subagent task completed"
    echo '{"status": "completed", "task": "implement-auth"}' > "$STATE_DIR/test-session/subagents/test-subagent.json"

    RESULT=$(echo '{"subagentId": "test-subagent", "subagentType": "ralph-coder", "sessionId": "test-session"}' | \
        "$REPO_ROOT/.claude/hooks/ralph-subagent-stop.sh" 2>/dev/null || true)

    if echo "$RESULT" | grep -q '"decision": "approve"'; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Should approve when subagent completed${NC}"
    fi

    cleanup_test_state
}

#######################################
# Test 2: Teammate State Check (Finding #2 - HIGH)
#######################################
test_teammate_state_check() {
    print_header "Test 2: Teammate State Check (Finding #2)"

    cleanup_test_state

    # Test 2.1: Stop hook checks teammate status
    print_test "Stop hook blocks when teammate still working"
    mkdir -p "$TEAMS_DIR/test-team/members"
    mkdir -p "$STATE_DIR/test-session"
    echo '{"age_seconds": 100}' > "$STATE_DIR/test-session/session.json"
    echo '{"status": "working"}' > "$TEAMS_DIR/test-team/members/coder.json"
    echo '{"team_name": "test-team", "members": ["coder"]}' > "$TEAMS_DIR/test-team/config.json"

    RESULT=$(echo '{"session_id": "test-session", "cwd": "/tmp", "stop_hook_active": false}' | \
        "$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh" 2>/dev/null || true)

    if echo "$RESULT" | grep -q "Teammate.*still working"; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Should detect teammate still working${NC}"
    fi

    # Test 2.2: Stop hook detects teammate errors
    print_test "Stop hook detects teammate errors"
    echo '{"status": "idle", "last_error": "Build failed"}' > "$TEAMS_DIR/test-team/members/coder.json"

    RESULT=$(echo '{"session_id": "test-session", "cwd": "/tmp", "stop_hook_active": false}' | \
        "$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh" 2>/dev/null || true)

    if echo "$RESULT" | grep -q "Teammate.*error"; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Should detect teammate errors${NC}"
    fi

    cleanup_test_state
}

#######################################
# Test 3: Block State Tracking (Finding #3 - HIGH)
#######################################
test_block_state_tracking() {
    print_header "Test 3: Block State Tracking (Finding #3)"

    cleanup_test_state

    # Test 3.1: Block state file is created
    print_test "Block state file created on block"
    mkdir -p "$STATE_DIR/test-session"
    mkdir -p "$TEAMS_DIR/test-team/members"
    echo '{"age_seconds": 100}' > "$STATE_DIR/test-session/session.json"
    echo '{"status": "working"}' > "$TEAMS_DIR/test-team/members/coder.json"
    echo '{"team_name": "test-team"}' > "$TEAMS_DIR/test-team/config.json"

    echo '{"session_id": "test-session", "cwd": "/tmp", "stop_hook_active": false}' | \
        "$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh" >/dev/null 2>&1 || true

    if [[ -f "$STATE_DIR/test-session/blocks.json" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Block state file not created${NC}"
    fi

    # Test 3.2: Block count increments
    print_test "Block count increments correctly"
    BLOCK_COUNT=$(jq -r '.block_count // 0' "$STATE_DIR/test-session/blocks.json" 2>/dev/null || echo "0")
    if [[ "$BLOCK_COUNT" -ge 1 ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Block count not incremented${NC}"
    fi

    # Test 3.3: Escalation after max blocks
    print_test "Escalation triggers after max blocks"
    # Create multiple blocks
    for i in {1..5}; do
        echo '{"session_id": "test-session", "cwd": "/tmp", "stop_hook_active": false}' | \
            "$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh" >/dev/null 2>&1 || true
    done

    if jq -e '.escalate == true' "$STATE_DIR/test-session/blocks.json" >/dev/null 2>&1; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Escalation not triggered${NC}"
    fi

    cleanup_test_state
}

#######################################
# Test 4: SubagentStart State Registration (Finding #4 - MEDIUM)
#######################################
test_subagent_start_state() {
    print_header "Test 4: SubagentStart State (Finding #4)"

    cleanup_test_state

    # Test 4.1: Hook file exists
    print_test "ralph-subagent-start.sh exists"
    if [[ -f "$REPO_ROOT/.claude/hooks/ralph-subagent-start.sh" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ ralph-subagent-start.sh not found${NC}"
    fi

    # Test 4.2: Subagent state registered on start
    print_test "Subagent state registered on start"
    mkdir -p "$STATE_DIR/test-session"

    echo '{"subagentId": "test-subagent", "subagentType": "ralph-coder", "sessionId": "test-session", "parentId": "parent-1"}' | \
        "$REPO_ROOT/.claude/hooks/ralph-subagent-start.sh" >/dev/null 2>&1 || true

    if [[ -f "$STATE_DIR/test-session/subagents/test-subagent.json" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Subagent state not registered${NC}"
    fi

    # Test 4.3: State has correct fields
    print_test "Subagent state has required fields"
    local state_file="$STATE_DIR/test-session/subagents/test-subagent.json"
    local id_ok=$(jq -r '.id' "$state_file" 2>/dev/null)
    local type_ok=$(jq -r '.type' "$state_file" 2>/dev/null)
    local status_ok=$(jq -r '.status' "$state_file" 2>/dev/null)

    if [[ "$id_ok" == "test-subagent" && "$type_ok" == "ralph-coder" && "$status_ok" == "active" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Subagent state missing fields (id=$id_ok, type=$type_ok, status=$status_ok)${NC}"
    fi

    cleanup_test_state
}

#######################################
# Test 5: Session Isolation (Finding #5 - MEDIUM)
#######################################
test_session_isolation() {
    print_header "Test 5: Session Isolation (Finding #5)"

    cleanup_test_state

    # Test 5.1: No session file allows stop
    print_test "No session file allows stop"
    rm -rf "$STATE_DIR/test-session" 2>/dev/null || true

    RESULT=$(echo '{"session_id": "test-session", "cwd": "/tmp", "stop_hook_active": false}' | \
        "$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh" 2>/dev/null || true)

    if echo "$RESULT" | grep -q '"decision": "approve"'; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Should allow stop without session${NC}"
    fi

    # Test 5.2: Stale session is cleaned up
    print_test "Stale session (24h+) is cleaned up"
    mkdir -p "$STATE_DIR/test-session"
    echo '{"age_seconds": 100000}' > "$STATE_DIR/test-session/session.json"

    RESULT=$(echo '{"session_id": "test-session", "cwd": "/tmp", "stop_hook_active": false}' | \
        "$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh" 2>/dev/null || true)

    if echo "$RESULT" | grep -q "Stale session"; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Stale session not cleaned up${NC}"
    fi

    # Test 5.3: Fresh session is not cleaned
    print_test "Fresh session is preserved"
    mkdir -p "$STATE_DIR/test-session"
    echo '{"age_seconds": 100}' > "$STATE_DIR/test-session/session.json"

    RESULT=$(echo '{"session_id": "test-session", "cwd": "/tmp", "stop_hook_active": false}' | \
        "$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh" 2>/dev/null || true)

    # Should not say "stale" and session dir should still exist
    if [[ -d "$STATE_DIR/test-session" ]] && ! echo "$RESULT" | grep -q "Stale"; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Fresh session incorrectly handled${NC}"
    fi

    cleanup_test_state
}

#######################################
# Test 6: Integration Flow
#######################################
test_integration_flow() {
    print_header "Test 6: Full Integration Flow"

    cleanup_test_state

    # Test 6.1: SubagentStart -> SubagentStop flow
    print_test "SubagentStart -> SubagentStop flow works"
    mkdir -p "$STATE_DIR/test-session"

    # Start subagent
    echo '{"subagentId": "flow-test", "subagentType": "ralph-coder", "sessionId": "test-session"}' | \
        "$REPO_ROOT/.claude/hooks/ralph-subagent-start.sh" >/dev/null 2>&1

    # Verify state exists
    if [[ ! -f "$STATE_DIR/test-session/subagents/flow-test.json" ]]; then
        fail
        echo -e "  ${RED}✗ SubagentStart did not create state${NC}"
    else
        # Mark as completed
        jq '.status = "completed"' "$STATE_DIR/test-session/subagents/flow-test.json" > tmp.json && mv tmp.json "$STATE_DIR/test-session/subagents/flow-test.json"

        # Stop subagent
        RESULT=$(echo '{"subagentId": "flow-test", "subagentType": "ralph-coder", "sessionId": "test-session"}' | \
            "$REPO_ROOT/.claude/hooks/ralph-subagent-stop.sh" 2>/dev/null || true)

        if echo "$RESULT" | grep -q '"decision": "approve"'; then
            pass
        else
            fail
            echo -e "  ${RED}✗ SubagentStop did not approve completed subagent${NC}"
        fi
    fi

    cleanup_test_state
}

#######################################
# Summary
#######################################
print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED))

    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  HOOK INTEGRATION TEST SUMMARY${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"

    echo -e "\n  ${GREEN}Passed:${NC}   $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $TESTS_FAILED"
    echo -e "  ${BOLD}Total:${NC}    $total"

    if [[ $total -gt 0 ]]; then
        local rate=$((TESTS_PASSED * 100 / total))
        echo -e "\n  ${BOLD}Pass Rate: ${rate}%${NC}"
    fi

    echo ""
    echo -e "${BOLD}Findings Validated:${NC}"
    echo "  #1 (CRITICAL): ralph-subagent-stop.sh created"
    echo "  #2 (HIGH): Teammate state check added"
    echo "  #3 (HIGH): Block state tracking with escalation"
    echo "  #4 (MEDIUM): SubagentStart registers state"
    echo "  #5 (MEDIUM): Session isolation and cleanup"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✓ ALL HOOK INTEGRATION TESTS PASSED${NC}"
        return 0
    else
        echo -e "\n${RED}${BOLD}✗ SOME TESTS FAILED${NC}"
        return 1
    fi
}

#######################################
# Main
#######################################
main() {
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║     Hook Integration E2E Test Suite v2.88.0                ║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"

    test_ralph_subagent_stop
    test_teammate_state_check
    test_block_state_tracking
    test_subagent_start_state
    test_session_isolation
    test_integration_flow

    print_summary
}

main "$@"
