#!/bin/bash
# test-ralph-subagent-stop.sh - Unit tests for SubagentStop hook
# VERSION: 2.88.0
# REPO: multi-agent-ralph-loop
#
# Usage: ./test-ralph-subagent-stop.sh
#
# Tests all scenarios for the SubagentStop hook:
# 1. No state file (should allow stop)
# 2. Completed subagent (should allow stop)
# 3. Failed subagent (should allow stop - error handling)
# 4. Subagent with incomplete task (should block)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOK_PATH="$REPO_ROOT/.claude/hooks/ralph-subagent-stop.sh"
STATE_DIR="$HOME/.ralph/state"
TEST_SUBAGENT="test-subagent-stop-$$"
TEST_PARENT="test-parent-$$"
TEST_SESSION="test-subagent-session-$$"
TEST_TEAM="test-team-$$"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up test state..."
    # State files are session-scoped and suffixed .json — the old globs matched
    # neither and leaked fixtures into $HOME between runs.
    rm -rf "$STATE_DIR/${TEST_SESSION}" 2>/dev/null || true
    rm -rf "$STATE_DIR/${TEST_PARENT}" 2>/dev/null || true
    rm -f "$STATE_DIR/subagents/${TEST_SUBAGENT}.json" 2>/dev/null || true
    rm -rf "$HOME/.claude/teams/${TEST_TEAM}" 2>/dev/null || true
    rm -rf "$HOME/.claude/tasks/${TEST_TEAM}" 2>/dev/null || true
}
trap cleanup EXIT

# Test helper functions
pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}❌ FAIL${NC}: $1"
    if [ -n "$2" ]; then
        echo "   Expected: $2"
        echo "   Got: $3"
    fi
}

run_test() {
    local test_name="$1"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    echo ""
    echo -e "${YELLOW}Test $TESTS_TOTAL: $test_name${NC}"
    echo "----------------------------------------"
}

# Make hook executable
chmod +x "$HOOK_PATH"

echo "========================================"
echo "  Ralph SubagentStop Hook Unit Tests"
echo "========================================"
echo "Hook: $HOOK_PATH"
echo "Subagent: $TEST_SUBAGENT"
echo "========================================"

# ============================================
# TEST 1: No state file (should allow stop)
# ============================================
run_test "No state file (should allow stop)"

INPUT=$(cat <<EOF
{
    "subagentId": "$TEST_SUBAGENT-no-state",
    "subagentType": "ralph-coder",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if [ -z "${RESULT//[[:space:]]/}" ]; then
        pass "Exit code 0 and silent stdout when no state exists"
    else
        fail "Allow must be a silent exit 0" "no stdout" "$RESULT"
    fi
else
    fail "Should exit 0 when no state exists" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 2: Completed subagent (should allow)
# ============================================
run_test "Completed subagent (should allow)"

# Create subagent state.
# The state file is SESSION-SCOPED: ralph-subagent-start.sh registers it at
# $STATE_DIR/<session>/subagents/<id>.json, and this hook reads the same path.
# The payload therefore has to carry the session id too.
mkdir -p "$STATE_DIR/$TEST_SESSION/subagents"
cat > "$STATE_DIR/$TEST_SESSION/subagents/${TEST_SUBAGENT}.json" <<EOF
{
    "id": "$TEST_SUBAGENT",
    "type": "ralph-coder",
    "parent": "$TEST_PARENT",
    "status": "active",
    "started_at": "$(date -Iseconds)"
}
EOF

INPUT=$(cat <<EOF
{
    "agent_id": "$TEST_SUBAGENT",
    "agent_type": "ralph-coder",
    "sessionId": "$TEST_SESSION",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if [ -z "${RESULT//[[:space:]]/}" ]; then
        # Terminal status is "completed" — the value both this hook and
        # subagent-stop-universal.sh write. ("stopped" is written by nothing.)
        UPDATED_STATUS=$(jq -r '.status' "$STATE_DIR/$TEST_SESSION/subagents/${TEST_SUBAGENT}.json")
        if [ "$UPDATED_STATUS" = "completed" ]; then
            pass "Exit code 0, silent stdout, and state updated to completed"
        else
            fail "State should be updated to completed" "completed" "$UPDATED_STATUS"
        fi
    else
        fail "Allow must be a silent exit 0" "no stdout" "$RESULT"
    fi
else
    fail "Should exit 0 for completed subagent" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 3: Failed subagent (should allow)
# ============================================
run_test "Failed subagent (should allow - error handling)"

INPUT=$(cat <<EOF
{
    "subagentId": "$TEST_SUBAGENT",
    "subagentType": "ralph-coder",
    "parentId": "$TEST_PARENT",
    "status": "failed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if [ -z "${RESULT//[[:space:]]/}" ]; then
        pass "Exit code 0 and silent stdout for failed subagent"
    else
        fail "Allow must be a silent exit 0" "no stdout" "$RESULT"
    fi
else
    fail "Should exit 0 for failed subagent" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 4: Subagent with incomplete task (should block)
# ============================================
run_test "Subagent with incomplete task (should block)"

# The hook resolves an assigned task through the Agent Teams layout, not through
# an "assigned_task" field on the subagent state: it walks
# ~/.claude/teams/*/config.json for a team name, then reads
# ~/.claude/tasks/<team>/<taskId>.json. The task id comes from stdin.
mkdir -p "$HOME/.claude/teams/${TEST_TEAM}" "$HOME/.claude/tasks/${TEST_TEAM}"
cat > "$HOME/.claude/teams/${TEST_TEAM}/config.json" <<EOF
{
    "name": "$TEST_TEAM"
}
EOF
cat > "$HOME/.claude/tasks/${TEST_TEAM}/test-task.json" <<EOF
{
    "id": "test-task",
    "status": "in_progress",
    "description": "Test task"
}
EOF

cat > "$STATE_DIR/$TEST_SESSION/subagents/${TEST_SUBAGENT}.json" <<EOF
{
    "id": "$TEST_SUBAGENT",
    "type": "ralph-coder",
    "parent": "$TEST_PARENT",
    "status": "active",
    "started_at": "$(date -Iseconds)"
}
EOF

INPUT=$(cat <<EOF
{
    "agent_id": "$TEST_SUBAGENT",
    "agent_type": "ralph-coder",
    "sessionId": "$TEST_SESSION",
    "taskId": "test-task",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 2 ]; then
    if echo "$RESULT" | grep -q '"decision".*"block"'; then
        pass "Exit code 2 and decision block when task incomplete"
    else
        fail "Decision should be block" '"decision": "block"' "$RESULT"
    fi
else
    fail "Should exit 2 when task incomplete" "exit 2" "exit $EXIT_CODE"
fi

# ============================================
# TEST 5: Subagent with completed task (should allow)
# ============================================
run_test "Subagent with completed task (should allow)"

# Update task to completed (same team/task layout the hook walks)
cat > "$HOME/.claude/tasks/${TEST_TEAM}/test-task.json" <<EOF
{
    "id": "test-task",
    "status": "completed",
    "description": "Test task"
}
EOF

INPUT=$(cat <<EOF
{
    "agent_id": "$TEST_SUBAGENT",
    "agent_type": "ralph-coder",
    "sessionId": "$TEST_SESSION",
    "taskId": "test-task",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if [ -z "${RESULT//[[:space:]]/}" ]; then
        pass "Exit code 0 and silent stdout when task completed"
    else
        fail "Allow must be a silent exit 0" "no stdout" "$RESULT"
    fi
else
    fail "Should exit 0 when task completed" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 6: Different subagent types
# ============================================
run_test "Different subagent types (reviewer, tester, researcher)"

# Test reviewer
INPUT=$(cat <<EOF
{
    "agent_id": "$TEST_SUBAGENT-reviewer",
    "agent_type": "ralph-reviewer",
    "sessionId": "$TEST_SESSION",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass "Reviewer subagent allowed to stop"
else
    fail "Reviewer should be allowed to stop" "exit 0" "exit $EXIT_CODE"
fi

# Test tester
INPUT=$(cat <<EOF
{
    "agent_id": "$TEST_SUBAGENT-tester",
    "agent_type": "ralph-tester",
    "sessionId": "$TEST_SESSION",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass "Tester subagent allowed to stop"
else
    fail "Tester should be allowed to stop" "exit 0" "exit $EXIT_CODE"
fi

# Test researcher
INPUT=$(cat <<EOF
{
    "agent_id": "$TEST_SUBAGENT-researcher",
    "agent_type": "ralph-researcher",
    "sessionId": "$TEST_SESSION",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass "Researcher subagent allowed to stop"
else
    fail "Researcher should be allowed to stop" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo -e "Total:  ${TESTS_TOTAL}"
echo -e "Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Failed: ${RED}${TESTS_FAILED}${NC}"
echo "========================================"

if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
