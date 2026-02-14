#!/bin/bash
# pre-commit-batch-skills-test.sh - Pre-commit hook to validate batch skills
# Version: 2.88.0
# Triggers: PreCommit (when .claude/skills/* or tests/skills/* changed)
# Exit 1: Block commit if tests fail

set -e

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
TESTS_DIR="$PROJECT_ROOT/tests/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "  PRE-COMMIT: BATCH SKILLS VALIDATION"
echo "=========================================="
echo ""

# Check if batch skills were modified
BATCH_SKILLS_CHANGED=$(git diff --cached --name-only 2>/dev/null | grep -E "\.claude/skills/(task-batch|create-task-batch)" | wc -l | tr -d ' ')
TESTS_CHANGED=$(git diff --cached --name-only 2>/dev/null | grep -E "tests/skills" | wc -l | tr -d ' ')

if [[ "$BATCH_SKILLS_CHANGED" -eq 0 && "$TESTS_CHANGED" -eq 0 ]]; then
    echo -e "${YELLOW}No batch skills changes detected. Skipping tests.${NC}"
    exit 0
fi

echo -e "${YELLOW}Batch skills changes detected. Running tests...${NC}"
echo ""

FAILURES=0

# Run task-batch tests
echo "--- Running task-batch tests ---"
if [[ -x "$TESTS_DIR/test-task-batch.sh" ]]; then
    if "$TESTS_DIR/test-task-batch.sh"; then
        echo -e "${GREEN}✓ task-batch tests passed${NC}"
    else
        echo -e "${RED}✗ task-batch tests FAILED${NC}"
        ((FAILURES++))
    fi
else
    echo -e "${YELLOW}⚠ test-task-batch.sh not found or not executable${NC}"
fi

echo ""

# Run create-task-batch tests
echo "--- Running create-task-batch tests ---"
if [[ -x "$TESTS_DIR/test-create-task-batch.sh" ]]; then
    if "$TESTS_DIR/test-create-task-batch.sh"; then
        echo -e "${GREEN}✓ create-task-batch tests passed${NC}"
    else
        echo -e "${RED}✗ create-task-batch tests FAILED${NC}"
        ((FAILURES++))
    fi
else
    echo -e "${YELLOW}⚠ test-create-task-batch.sh not found or not executable${NC}"
fi

echo ""

# Run integration tests
echo "--- Running integration tests ---"
if [[ -x "$TESTS_DIR/test-batch-skills-integration.sh" ]]; then
    if "$TESTS_DIR/test-batch-skills-integration.sh"; then
        echo -e "${GREEN}✓ integration tests passed${NC}"
    else
        echo -e "${RED}✗ integration tests FAILED${NC}"
        ((FAILURES++))
    fi
else
    echo -e "${YELLOW}⚠ test-batch-skills-integration.sh not found or not executable${NC}"
fi

echo ""
echo "=========================================="

if [[ $FAILURES -gt 0 ]]; then
    echo -e "${RED}COMMIT BLOCKED: $FAILURES test suite(s) failed${NC}"
    echo ""
    echo "Please fix the failing tests before committing."
    echo "Run tests manually: ./tests/skills/test-*.sh"
    exit 1
else
    echo -e "${GREEN}All batch skills tests passed!${NC}"
    exit 0
fi
