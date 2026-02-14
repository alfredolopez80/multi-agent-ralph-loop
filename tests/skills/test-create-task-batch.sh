#!/bin/bash
# test-create-task-batch.sh - Unit tests for /create-task-batch skill
# Version: 2.88.0
# Run: ./tests/skills/test-create-task-batch.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILL_FILE="$PROJECT_ROOT/.claude/skills/create-task-batch/SKILL.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASS=0
FAIL=0

echo "=========================================="
echo "  CREATE-TASK-BATCH SKILL - UNIT TESTS"
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
echo -n "Test 2: Skill name is 'create-task-batch'... "
if grep -q "^name: create-task-batch$" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 3: Has AskUserQuestion
echo -n "Test 3: Has AskUserQuestion tool... "
if grep -q "AskUserQuestion" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 4: Has questioning phases
echo -n "Test 4: Has questioning phases... "
if grep -q "Phase 1\|Phase 2\|Phase 5" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 5: Has MANDATORY criteria requirement
echo -n "Test 5: Has MANDATORY criteria requirement... "
if grep -qi "MANDATORY\|every task MUST\|criteria.*per.*task" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 6: Has output templates
echo -n "Test 6: Has output templates... "
if grep -q "Template\|Output" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 7: Has task decomposition
echo -n "Test 7: Has task decomposition... "
if grep -qi "decompos" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 8: Has priority handling
echo -n "Test 8: Has priority handling... "
if grep -qi "priorit\|P1" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 9: Has dependency handling
echo -n "Test 9: Has dependency handling... "
if grep -qi "depend" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 10: Has validation for missing criteria
echo -n "Test 10: Has validation for missing criteria... "
if grep -qi "BLOCK\|Cannot.*without\|VALIDATION CHECK" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 11: Integrates with /task-batch
echo -n "Test 11: Integrates with /task-batch... "
if grep -q "/task-batch" "$SKILL_FILE" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 12: Symlink exists
echo -n "Test 12: Global symlink exists... "
if [[ -L "$HOME/.claude/skills/create-task-batch" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 13: Symlink is valid
echo -n "Test 13: Symlink target valid... "
SYMLINK_TARGET=$(readlink "$HOME/.claude/skills/create-task-batch" 2>/dev/null)
if [[ "$SYMLINK_TARGET" == *".claude/skills/create-task-batch" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC} - Target: $SYMLINK_TARGET"
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
