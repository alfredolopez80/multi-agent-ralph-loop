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
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
HOOK_PATH="$REPO_ROOT/.claude/hooks/ralph-subagent-stop.sh"
STATE_DIR="$HOME/.ralph/state"
TEST_SUBAGENT="test-subagent-stop-$$"
TEST_PARENT="test-parent-$$"

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
    rm -rf "$STATE_DIR/subagents/${TEST_SUBAGENT}" 2>/dev/null || true
    rm -rf "$STATE_DIR/${TEST_PARENT}" 2>/dev/null || true
}
trap cleanup EXIT

# Test helper functions
pass() {
    ((TESTS_PASSED++))
    echo -e "${GREEN}✅ PASS${NC}: $1"
}

fail() {
    ((TESTS_FAILED++))
    echo -e "${RED}❌ FAIL${NC}: $1"
    if [ -n "$2" ]; then
        echo "   Expected: $2"
        echo "   Got: $3"
    fi
}

run_test() {
    local test_name="$1"
    ((TESTS_TOTAL++))
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

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if echo "$RESULT" | grep -q '"decision".*"approve"'; then
        pass "Exit code 0 and decision approve when no state exists"
    else
        fail "Decision should be approve" '"decision": "approve"' "$RESULT"
    fi
else
    fail "Should exit 0 when no state exists" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 2: Completed subagent (should allow)
# ============================================
run_test "Completed subagent (should allow)"

# Create subagent state
mkdir -p "$STATE_DIR/subagents"
cat > "$STATE_DIR/subagents/${TEST_SUBAGENT}.json" <<EOF
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
    "subagentId": "$TEST_SUBAGENT",
    "subagentType": "ralph-coder",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if echo "$RESULT" | grep -q '"decision".*"approve"'; then
        # Verify state was updated
        UPDATED_STATUS=$(jq -r '.status' "$STATE_DIR/subagents/${TEST_SUBAGENT}.json")
        if [ "$UPDATED_STATUS" = "stopped" ]; then
            pass "Exit code 0, decision approve, and state updated to stopped"
        else
            fail "State should be updated to stopped" "stopped" "$UPDATED_STATUS"
        fi
    else
        fail "Decision should be approve" '"decision": "approve"' "$RESULT"
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

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if echo "$RESULT" | grep -q '"decision".*"approve"'; then
        pass "Exit code 0 and decision approve for failed subagent"
    else
        fail "Decision should be approve" '"decision": "approve"' "$RESULT"
    fi
else
    fail "Should exit 0 for failed subagent" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 4: Subagent with incomplete task (should block)
# ============================================
run_test "Subagent with incomplete task (should block)"

# Create parent task state
mkdir -p "$STATE_DIR/${TEST_PARENT}/tasks"
cat > "$STATE_DIR/${TEST_PARENT}/tasks/test-task.json" <<EOF
{
    "id": "test-task",
    "status": "in_progress",
    "description": "Test task"
}
EOF

# Update subagent state with assigned task
cat > "$STATE_DIR/subagents/${TEST_SUBAGENT}.json" <<EOF
{
    "id": "$TEST_SUBAGENT",
    "type": "ralph-coder",
    "parent": "$TEST_PARENT",
    "status": "active",
    "assigned_task": "test-task",
    "started_at": "$(date -Iseconds)"
}
EOF

INPUT=$(cat <<EOF
{
    "subagentId": "$TEST_SUBAGENT",
    "subagentType": "ralph-coder",
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

# Update task to completed
cat > "$STATE_DIR/${TEST_PARENT}/tasks/test-task.json" <<EOF
{
    "id": "test-task",
    "status": "completed",
    "description": "Test task"
}
EOF

INPUT=$(cat <<EOF
{
    "subagentId": "$TEST_SUBAGENT",
    "subagentType": "ralph-coder",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if echo "$RESULT" | grep -q '"decision".*"approve"'; then
        pass "Exit code 0 and decision approve when task completed"
    else
        fail "Decision should be approve" '"decision": "approve"' "$RESULT"
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
    "subagentId": "$TEST_SUBAGENT-reviewer",
    "subagentType": "ralph-reviewer",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass "Reviewer subagent allowed to stop"
else
    fail "Reviewer should be allowed to stop" "exit 0" "exit $EXIT_CODE"
fi

# Test tester
INPUT=$(cat <<EOF
{
    "subagentId": "$TEST_SUBAGENT-tester",
    "subagentType": "ralph-tester",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    pass "Tester subagent allowed to stop"
else
    fail "Tester should be allowed to stop" "exit 0" "exit $EXIT_CODE"
fi

# Test researcher
INPUT=$(cat <<EOF
{
    "subagentId": "$TEST_SUBAGENT-researcher",
    "subagentType": "ralph-researcher",
    "parentId": "$TEST_PARENT",
    "status": "completed"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?
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
