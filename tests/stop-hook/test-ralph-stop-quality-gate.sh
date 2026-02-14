#!/bin/bash
# test-ralph-stop-quality-gate.sh - Unit tests for Stop hook
# VERSION: 2.87.0
# REPO: multi-agent-ralph-loop
#
# Usage: ./test-ralph-stop-quality-gate.sh
#
# Tests all scenarios for the Stop hook:
# 1. stop_hook_active = true (infinite loop prevention)
# 2. No state file (should allow stop)
# 3. Incomplete orchestrator (should block)
# 4. Complete orchestrator (should allow)
# 5. Incomplete loop (should block)
# 6. Complete loop (should allow)
# 7. Team tasks pending (should block)
# 8. Quality gate failed (should block)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
HOOK_PATH="$REPO_ROOT/.claude/hooks/ralph-stop-quality-gate.sh"
STATE_DIR="$HOME/.ralph/state"
TEST_SESSION="test-stop-hook-$$"

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
    rm -rf "$STATE_DIR/$TEST_SESSION" 2>/dev/null || true
    rm -rf "$HOME/.claude/tasks/$TEST_SESSION" 2>/dev/null || true
    rm -rf "$HOME/.claude/teams/$TEST_SESSION" 2>/dev/null || true
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
echo "  Ralph Stop Hook Unit Tests"
echo "========================================"
echo "Hook: $HOOK_PATH"
echo "Session: $TEST_SESSION"
echo "========================================"

# ============================================
# TEST 1: stop_hook_active = true
# ============================================
run_test "stop_hook_active = true (infinite loop prevention)"

INPUT=$(cat <<EOF
{
    "session_id": "$TEST_SESSION",
    "stop_hook_active": true,
    "hook_event_name": "Stop",
    "cwd": "$REPO_ROOT"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null)
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if echo "$RESULT" | grep -q '"decision".*"approve"'; then
        pass "Exit code 0 and decision approve when stop_hook_active=true"
    else
        fail "Decision should be approve" '"decision": "approve"' "$RESULT"
    fi
else
    fail "Should exit 0 when stop_hook_active=true" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 2: No state file (should allow stop)
# ============================================
run_test "No state file (should allow stop)"

INPUT=$(cat <<EOF
{
    "session_id": "$TEST_SESSION-no-state",
    "stop_hook_active": false,
    "hook_event_name": "Stop",
    "cwd": "$REPO_ROOT"
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
# TEST 3: Incomplete orchestrator (should block)
# ============================================
run_test "Incomplete orchestrator (should block)"

# Create orchestrator state
mkdir -p "$STATE_DIR/$TEST_SESSION"
cat > "$STATE_DIR/$TEST_SESSION/orchestrator.json" <<EOF
{
    "session_id": "$TEST_SESSION",
    "task": "Test task",
    "phase": "implementation",
    "verified_done": false,
    "conditions": {
        "memory_search": true,
        "task_classified": true,
        "must_have_answered": true,
        "plan_approved": true,
        "implementation_complete": false,
        "correctness_passed": false,
        "quality_passed": null,
        "adversarial_passed": null,
        "retrospective_done": false
    }
}
EOF

INPUT=$(cat <<EOF
{
    "session_id": "$TEST_SESSION",
    "stop_hook_active": false,
    "hook_event_name": "Stop",
    "cwd": "$REPO_ROOT"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 2 ]; then
    if echo "$RESULT" | grep -q '"decision".*"block"'; then
        pass "Exit code 2 and decision block when orchestrator incomplete"
    else
        fail "Decision should be block" '"decision": "block"' "$RESULT"
    fi
else
    fail "Should exit 2 when orchestrator incomplete" "exit 2" "exit $EXIT_CODE"
fi

# ============================================
# TEST 4: Complete orchestrator (should allow)
# ============================================
run_test "Complete orchestrator (should allow)"

# Update orchestrator state to complete
cat > "$STATE_DIR/$TEST_SESSION/orchestrator.json" <<EOF
{
    "session_id": "$TEST_SESSION",
    "task": "Test task",
    "phase": "complete",
    "verified_done": true,
    "conditions": {
        "memory_search": true,
        "task_classified": true,
        "must_have_answered": true,
        "plan_approved": true,
        "implementation_complete": true,
        "correctness_passed": true,
        "quality_passed": true,
        "adversarial_passed": true,
        "retrospective_done": true
    }
}
EOF

INPUT=$(cat <<EOF
{
    "session_id": "$TEST_SESSION",
    "stop_hook_active": false,
    "hook_event_name": "Stop",
    "cwd": "$REPO_ROOT"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if echo "$RESULT" | grep -q '"decision".*"approve"'; then
        pass "Exit code 0 and decision approve when orchestrator complete"
    else
        fail "Decision should be approve" '"decision": "approve"' "$RESULT"
    fi
else
    fail "Should exit 0 when orchestrator complete" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 5: Incomplete loop (should block)
# ============================================
run_test "Incomplete loop (should block)"

# Create loop state
cat > "$STATE_DIR/$TEST_SESSION/loop.json" <<EOF
{
    "session_id": "$TEST_SESSION",
    "task": "fix type errors",
    "iteration": 5,
    "max_iterations": 25,
    "validation_result": "failed",
    "last_error": "Type error in src/auth.ts:42",
    "verified_done": false
}
EOF

# Remove orchestrator state to test loop independently
rm -f "$STATE_DIR/$TEST_SESSION/orchestrator.json"

INPUT=$(cat <<EOF
{
    "session_id": "$TEST_SESSION",
    "stop_hook_active": false,
    "hook_event_name": "Stop",
    "cwd": "$REPO_ROOT"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 2 ]; then
    if echo "$RESULT" | grep -q '"decision".*"block"'; then
        pass "Exit code 2 and decision block when loop incomplete"
    else
        fail "Decision should be block" '"decision": "block"' "$RESULT"
    fi
else
    fail "Should exit 2 when loop incomplete" "exit 2" "exit $EXIT_CODE"
fi

# ============================================
# TEST 6: Complete loop (should allow)
# ============================================
run_test "Complete loop (should allow)"

# Update loop state to complete
cat > "$STATE_DIR/$TEST_SESSION/loop.json" <<EOF
{
    "session_id": "$TEST_SESSION",
    "task": "fix type errors",
    "iteration": 10,
    "max_iterations": 25,
    "validation_result": "passed",
    "last_error": "",
    "verified_done": true
}
EOF

INPUT=$(cat <<EOF
{
    "session_id": "$TEST_SESSION",
    "stop_hook_active": false,
    "hook_event_name": "Stop",
    "cwd": "$REPO_ROOT"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
    if echo "$RESULT" | grep -q '"decision".*"approve"'; then
        pass "Exit code 0 and decision approve when loop complete"
    else
        fail "Decision should be approve" '"decision": "approve"' "$RESULT"
    fi
else
    fail "Should exit 0 when loop complete" "exit 0" "exit $EXIT_CODE"
fi

# ============================================
# TEST 7: Quality gate failed (should block)
# ============================================
run_test "Quality gate failed (should block)"

# Create quality gate state
cat > "$STATE_DIR/$TEST_SESSION/quality-gate.json" <<EOF
{
    "session_id": "$TEST_SESSION",
    "last_result": "failed",
    "stages": {
        "correctness": { "status": "passed", "details": "No syntax errors" },
        "quality": { "status": "failed", "details": "3 type errors found" },
        "security": { "status": "pending", "details": null }
    }
}
EOF

# Clear other state
rm -f "$STATE_DIR/$TEST_SESSION/loop.json"
rm -f "$STATE_DIR/$TEST_SESSION/orchestrator.json"

INPUT=$(cat <<EOF
{
    "session_id": "$TEST_SESSION",
    "stop_hook_active": false,
    "hook_event_name": "Stop",
    "cwd": "$REPO_ROOT"
}
EOF
)

RESULT=$(echo "$INPUT" | "$HOOK_PATH" 2>/dev/null) && EXIT_CODE=0 || EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 2 ]; then
    if echo "$RESULT" | grep -q '"decision".*"block"'; then
        pass "Exit code 2 and decision block when quality gate failed"
    else
        fail "Decision should be block" '"decision": "block"' "$RESULT"
    fi
else
    fail "Should exit 2 when quality gate failed" "exit 2" "exit $EXIT_CODE"
fi

# ============================================
# TEST 8: ralph-state.sh script functionality
# ============================================
run_test "ralph-state.sh init/update/complete"

# Test init
"$REPO_ROOT/.claude/scripts/ralph-state.sh" init "$TEST_SESSION-rs" loop "test task" 2>/dev/null

if [ -f "$STATE_DIR/$TEST_SESSION-rs/loop.json" ]; then
    TASK=$(jq -r '.task' "$STATE_DIR/$TEST_SESSION-rs/loop.json")
    if [ "$TASK" = "test task" ]; then
        pass "ralph-state.sh init creates state file correctly"
    else
        fail "Task should be 'test task'" "test task" "$TASK"
    fi
else
    fail "State file should exist" "file exists" "file not found"
fi

# Test update
"$REPO_ROOT/.claude/scripts/ralph-state.sh" update "$TEST_SESSION-rs" loop 'validation_result=passed' 2>/dev/null
RESULT=$(jq -r '.validation_result' "$STATE_DIR/$TEST_SESSION-rs/loop.json")
if [ "$RESULT" = "passed" ]; then
    pass "ralph-state.sh update modifies state correctly"
else
    fail "validation_result should be 'passed'" "passed" "$RESULT"
fi

# Test complete
"$REPO_ROOT/.claude/scripts/ralph-state.sh" complete "$TEST_SESSION-rs" loop 2>/dev/null
VERIFIED=$(jq -r '.verified_done' "$STATE_DIR/$TEST_SESSION-rs/loop.json")
if [ "$VERIFIED" = "true" ]; then
    pass "ralph-state.sh complete sets verified_done=true"
else
    fail "verified_done should be 'true'" "true" "$VERIFIED"
fi

# Test delete
"$REPO_ROOT/.claude/scripts/ralph-state.sh" delete "$TEST_SESSION-rs" 2>/dev/null
if [ ! -d "$STATE_DIR/$TEST_SESSION-rs" ]; then
    pass "ralph-state.sh delete removes state directory"
else
    fail "State directory should not exist" "directory removed" "directory exists"
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
