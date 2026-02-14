#!/bin/bash
# test-task-batch.sh - Unit tests for /task-batch skill
# Version: 2.88.0
# Run: ./tests/skills/test-task-batch.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_FILE="$PROJECT_ROOT/.claude/skills/task-batch/SKILL.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

echo "=========================================="
echo "  TASK-BATCH SKILL - UNIT TESTS"
echo "=========================================="
echo ""

# Test 1: Skill file exists
echo -n "Test 1: Skill file exists... "
if [[ -f "$SKILL_FILE" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC} - File not found"
    ((FAIL++))
fi

# Test 2: Skill name is correct
echo -n "Test 2: Skill name is 'task-batch'... "
if grep -q "^name: task-batch$" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 3: Has MULTIPLE tasks handling
echo -n "Test 3: Handles MULTIPLE tasks... "
if grep -qi "MULTIPLE TASKS\|TASK QUEUE\|FOR EACH task" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 4: Has VERIFIED_DONE pattern
echo -n "Test 4: Has VERIFIED_DONE completion pattern... "
if grep -q "VERIFIED_DONE" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 5: Has PRD parsing
echo -n "Test 5: Has PRD parsing support... "
if grep -qi "\.prq\|PRD" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 6: Has priority handling
echo -n "Test 6: Has priority handling... "
if grep -qi "P1\|priority" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 7: Has dependency resolution
echo -n "Test 7: Has dependency resolution... "
if grep -qi "dependenc" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 8: Has Agent Teams integration
echo -n "Test 8: Has Agent Teams integration... "
if grep -qi "ralph-coder\|TeamCreate" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 9: Has stop conditions
echo -n "Test 9: Has stop conditions... "
if grep -qi "stop.*condition\|STOP.*FAIL" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 10: Symlink exists
echo -n "Test 10: Global symlink exists... "
if [[ -L "$HOME/.claude/skills/task-batch" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 11: Symlink is valid
echo -n "Test 11: Symlink target valid... "
SYMLINK_TARGET=$(readlink "$HOME/.claude/skills/task-batch" 2>/dev/null)
if [[ "$SYMLINK_TARGET" == *".claude/skills/task-batch" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC} - Target: $SYMLINK_TARGET"
    ((FAIL++))
fi

# Test 12: Has completion criteria per task
echo -n "Test 12: Has completion criteria per task... "
if grep -qi "completion.*criteria\|acceptance.*criteria" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Summary
echo ""
echo "=========================================="
echo "  RESULTS: ${GREEN}${PASS} PASSED${NC} / ${RED}${FAIL} FAILED${NC}"
echo "=========================================="

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
