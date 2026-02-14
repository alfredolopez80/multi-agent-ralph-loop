#!/bin/bash
# test-batch-skills-integration.sh - Integration tests for batch skills
# Version: 2.88.0
# Run: ./tests/skills/test-batch-skills-integration.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

echo "=========================================="
echo "  BATCH SKILLS - INTEGRATION TESTS"
echo "=========================================="
echo ""

# Test 1: Both skills exist
echo -n "Test 1: Both skills exist... "
TASK_BATCH="$PROJECT_ROOT/.claude/skills/task-batch/SKILL.md"
CREATE_TASK="$PROJECT_ROOT/.claude/skills/create-task-batch/SKILL.md"
if [[ -f "$TASK_BATCH" && -f "$CREATE_TASK" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 2: Both symlinks exist
echo -n "Test 2: Both symlinks exist... "
if [[ -L "$HOME/.claude/skills/task-batch" && -L "$HOME/.claude/skills/create-task-batch" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 3: Version alignment
echo -n "Test 3: Version alignment... "
V1=$(grep "^# VERSION:" "$TASK_BATCH" 2>/dev/null | head -1)
V2=$(grep "^# VERSION:" "$CREATE_TASK" 2>/dev/null | head -1)
if [[ "$V1" == "$V2" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 4: Cross-reference
echo -n "Test 4: Skills reference each other... "
if grep -q "task-batch" "$CREATE_TASK" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 5: Same completion pattern (VERIFIED_DONE)
echo -n "Test 5: Both use VERIFIED_DONE... "
if grep -q "VERIFIED_DONE" "$TASK_BATCH" 2>/dev/null; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 6: Example PRD exists
echo -n "Test 6: Example PRD file exists... "
if [[ -f "$PROJECT_ROOT/docs/prd/example-feature.prq.md" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 7: Hook exists
echo -n "Test 7: Progress tracking hook exists... "
if [[ -f "$PROJECT_ROOT/.claude/hooks/batch-progress-tracker.sh" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 8: Hook is executable
echo -n "Test 8: Hook is executable... "
if [[ -x "$PROJECT_ROOT/.claude/hooks/batch-progress-tracker.sh" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${RED}FAIL${NC}"
    ((FAIL++))
fi

# Test 9: Batch directory exists
echo -n "Test 9: Batch directory exists... "
if [[ -d "$HOME/.ralph/batch" ]]; then
    echo -e "${GREEN}PASS${NC}"
    ((PASS++))
else
    echo -e "${YELLOW}WARN${NC} - Creating"
    mkdir -p "$HOME/.ralph/batch"
    ((PASS++))
fi

# Test 10: Pre-commit hook exists
echo -n "Test 10: Pre-commit test hook exists... "
if [[ -f "$PROJECT_ROOT/.claude/hooks/pre-commit-batch-skills-test.sh" ]]; then
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
