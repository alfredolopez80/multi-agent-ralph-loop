#!/bin/bash
# validate-skills-unification.sh - Validate the unified skills model
# Version: 2.87.0
# Date: 2026-02-14

set -e

REPO_PATH="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
GLOBAL_SKILLS="$HOME/.claude/skills"
GLOBAL_COMMANDS="$HOME/.claude/commands"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PASS=0
FAIL=0
WARN=0

echo "=== Skills Unification Validation (v2.87.0) ==="
echo ""

# Test 1: Check symlinks exist and point to correct location
echo "Test 1: Verifying skill symlinks..."
RALPH_SKILLS=("orchestrator" "loop" "gates" "adversarial" "parallel" "retrospective" "clarify" "security" "bugs" "smart-fork" "task-classifier" "glm5" "glm5-parallel")

for skill in "${RALPH_SKILLS[@]}"; do
    GLOBAL_SKILL="$GLOBAL_SKILLS/$skill"
    REPO_SKILL="$REPO_PATH/.claude/skills/$skill"

    if [[ -L "$GLOBAL_SKILL" ]]; then
        TARGET=$(readlink "$GLOBAL_SKILL")
        if [[ "$TARGET" == "$REPO_SKILL" ]]; then
            echo -e "  ${GREEN}PASS${NC}: $skill -> repo"
            ((PASS++))
        else
            echo -e "  ${RED}FAIL${NC}: $skill -> wrong target: $TARGET"
            ((FAIL++))
        fi
    else
        echo -e "  ${RED}FAIL${NC}: $skill not a symlink"
        ((FAIL++))
    fi
done
echo ""

# Test 2: Check no duplicate commands exist
echo "Test 2: Checking for duplicate commands..."
DUPLICATE_FOUND=0
for skill in "${RALPH_SKILLS[@]}"; do
    CMD="$GLOBAL_COMMANDS/$skill.md"
    if [[ -f "$CMD" ]] && [[ ! -L "$CMD" ]]; then
        echo -e "  ${RED}FAIL${NC}: Duplicate command exists: $skill.md"
        ((FAIL++))
        ((DUPLICATE_FOUND++))
    fi
done
if [[ $DUPLICATE_FOUND -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC}: No duplicate commands found"
    ((PASS++))
fi
echo ""

# Test 3: Check skill versions are correct
echo "Test 3: Checking skill versions..."
for skill in orchestrator loop; do
    VERSION=$(head -3 "$REPO_PATH/.claude/skills/$skill/SKILL.md" 2>/dev/null | grep "# VERSION:" | cut -d: -f2 | tr -d ' ')
    if [[ "$VERSION" == "2.87.0" ]]; then
        echo -e "  ${GREEN}PASS${NC}: $skill version is $VERSION"
        ((PASS++))
    else
        echo -e "  ${YELLOW}WARN${NC}: $skill version is $VERSION (expected 2.87.0)"
        ((WARN++))
    fi
done
echo ""

# Test 4: Check no backup.* folders
echo "Test 4: Checking for obsolete backup folders..."
BACKUP_COUNT=$(ls "$GLOBAL_SKILLS" 2>/dev/null | grep -c "\.backup\." || true)
if [[ $BACKUP_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC}: No obsolete backup folders"
    ((PASS++))
else
    echo -e "  ${YELLOW}WARN${NC}: Found $BACKUP_COUNT backup.* folders"
    ((WARN++))
fi
echo ""

# Test 5: Check SKILL.md files exist
echo "Test 5: Checking SKILL.md files exist..."
for skill in orchestrator loop gates adversarial; do
    if [[ -f "$REPO_PATH/.claude/skills/$skill/SKILL.md" ]]; then
        echo -e "  ${GREEN}PASS${NC}: $skill/SKILL.md exists"
        ((PASS++))
    else
        echo -e "  ${RED}FAIL${NC}: $skill/SKILL.md missing"
        ((FAIL++))
    fi
done
echo ""

# Summary
echo "=== Validation Summary ==="
echo -e "  ${GREEN}Passed${NC}: $PASS"
echo -e "  ${RED}Failed${NC}: $FAIL"
echo -e "  ${YELLOW}Warnings${NC}: $WARN"
echo ""

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${NC}: Skills unification validated successfully!"
    exit 0
else
    echo -e "${RED}FAILURE${NC}: Skills unification has $FAIL issues that need attention."
    exit 1
fi
