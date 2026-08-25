#!/bin/bash
# validate-skills-unification.sh - Validate the unified skills model
# Version: 2.87.0
# Date: 2026-02-14

set -e
# NOTE: use `VAR=$((VAR+1))`, never `VAR=$((VAR+1))`. With set -e, a post-increment on a
# variable holding 0 evaluates to 0, which bash reports as exit status 1 and aborts
# the script. That silently truncated this validator after its first check.

# Derived from the script's own location. This was an absolute path into the author's
# laptop, which made the validator report on whatever happened to be at that path —
# nothing, on every other machine — while still exiting through its normal verdict.
_VC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_PATH="$(cd "${_VC_DIR}/.." && pwd)"
GLOBAL_SKILLS="$HOME/.claude/skills"
GLOBAL_COMMANDS="$HOME/.claude/commands"

# Shared colors, counters and the zero-checks verdict guard.
source "${_VC_DIR}/lib/validation-common.sh"

PASS=0
FAIL=0
WARN=0

echo "=== Skills Unification Validation (v2.87.0) ==="
echo ""

# Test 1: Check each skill is distributed the way DISTRIBUTION_POLICY.md prescribes.
#
# Per docs/architecture/DISTRIBUTION_POLICY.md, distribution is MIXED, not symlink-only:
# key skills (task-classifier, curator, orchestrator) are COPIED so they keep working
# without the repo; everything else is symlinked to the repo source. Demanding a symlink
# for all of them contradicted the policy and made this script fail on a correct setup.
#
# `loop` was renamed to `iterate` in v2.94; `glm5`/`glm5-parallel` were retired on
# 2026-07-31 with the rest of the GLM/MiniMax surface.
echo "Test 1: Verifying skill distribution..."
# All three skills DISTRIBUTION_POLICY.md names as copied. `curator` was missing here,
# so a symlinked or absent curator passed validation while violating the policy.
COPIED_SKILLS=("orchestrator" "task-classifier" "curator")
SYMLINKED_SKILLS=("iterate" "gates" "adversarial" "parallel" "retrospective" "clarify" "security" "bugs" "smart-fork")

for skill in "${COPIED_SKILLS[@]}"; do
    GLOBAL_SKILL="$GLOBAL_SKILLS/$skill"
    if [[ -L "$GLOBAL_SKILL" ]]; then
        echo -e "  ${RED}FAIL${NC}: $skill is a symlink but policy requires a standalone copy"
        FAIL=$((FAIL+1))
    elif [[ -f "$GLOBAL_SKILL/SKILL.md" ]]; then
        echo -e "  ${GREEN}PASS${NC}: $skill -> standalone copy (per policy)"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}FAIL${NC}: $skill missing from $GLOBAL_SKILLS"
        FAIL=$((FAIL+1))
    fi
done

for skill in "${SYMLINKED_SKILLS[@]}"; do
    GLOBAL_SKILL="$GLOBAL_SKILLS/$skill"
    REPO_SKILL="$REPO_PATH/.claude/skills/$skill"

    if [[ -L "$GLOBAL_SKILL" ]]; then
        TARGET=$(readlink "$GLOBAL_SKILL")
        if [[ "$TARGET" == "$REPO_SKILL" ]]; then
            echo -e "  ${GREEN}PASS${NC}: $skill -> repo"
            PASS=$((PASS+1))
        else
            echo -e "  ${RED}FAIL${NC}: $skill -> wrong target: $TARGET"
            FAIL=$((FAIL+1))
        fi
    elif [[ -f "$GLOBAL_SKILL/SKILL.md" ]]; then
        echo -e "  ${YELLOW}WARN${NC}: $skill is a copy; policy expects a symlink to the repo"
        WARN=$((WARN+1))
    else
        echo -e "  ${RED}FAIL${NC}: $skill missing from $GLOBAL_SKILLS"
        FAIL=$((FAIL+1))
    fi
done
echo ""

# Test 2: Check no duplicate commands exist
echo "Test 2: Checking for duplicate commands..."
DUPLICATE_FOUND=0
for skill in "${COPIED_SKILLS[@]}" "${SYMLINKED_SKILLS[@]}"; do
    CMD="$GLOBAL_COMMANDS/$skill.md"
    if [[ -f "$CMD" ]] && [[ ! -L "$CMD" ]]; then
        echo -e "  ${RED}FAIL${NC}: Duplicate command exists: $skill.md"
        FAIL=$((FAIL+1))
        DUPLICATE_FOUND=$((DUPLICATE_FOUND+1))
    fi
done
if [[ $DUPLICATE_FOUND -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC}: No duplicate commands found"
    PASS=$((PASS+1))
fi
echo ""

# Test 3: Check skill versions are correct
echo "Test 3: Checking skill versions..."
for skill in orchestrator iterate; do
    VERSION=$(head -3 "$REPO_PATH/.claude/skills/$skill/SKILL.md" 2>/dev/null | grep "# VERSION:" | cut -d: -f2 | tr -d ' ')
    if [[ "$VERSION" == 3.* ]]; then
        echo -e "  ${GREEN}PASS${NC}: $skill version is $VERSION"
        PASS=$((PASS+1))
    else
        echo -e "  ${YELLOW}WARN${NC}: $skill version is $VERSION (expected 3.x)"
        WARN=$((WARN+1))
    fi
done
echo ""

# Test 4: Check no backup.* folders
echo "Test 4: Checking for obsolete backup folders..."
BACKUP_COUNT=$(ls "$GLOBAL_SKILLS" 2>/dev/null | grep -c "\.backup\." || true)
if [[ $BACKUP_COUNT -eq 0 ]]; then
    echo -e "  ${GREEN}PASS${NC}: No obsolete backup folders"
    PASS=$((PASS+1))
else
    echo -e "  ${YELLOW}WARN${NC}: Found $BACKUP_COUNT backup.* folders"
    WARN=$((WARN+1))
fi
echo ""

# Test 5: Check SKILL.md files exist
echo "Test 5: Checking SKILL.md files exist..."
for skill in orchestrator iterate gates adversarial; do
    if [[ -f "$REPO_PATH/.claude/skills/$skill/SKILL.md" ]]; then
        echo -e "  ${GREEN}PASS${NC}: $skill/SKILL.md exists"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}FAIL${NC}: $skill/SKILL.md missing"
        FAIL=$((FAIL+1))
    fi
done
echo ""

# Summary
echo "=== Validation Summary ==="
echo -e "  ${GREEN}Passed${NC}: $PASS"
echo -e "  ${RED}Failed${NC}: $FAIL"
echo -e "  ${YELLOW}Warnings${NC}: $WARN"
echo ""

# "Nothing failed" is not "everything passed": a run that checked zero skills proves
# nothing, and its green verdict is indistinguishable from a healthy one.
if [[ $((PASS + FAIL + WARN)) -eq 0 ]]; then
    echo -e "${RED}FATAL${NC}: zero checks executed — no verdict can be declared" >&2
    exit 1
fi

if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}SUCCESS${NC}: Skills unification validated successfully!"
    exit 0
else
    echo -e "${RED}FAILURE${NC}: Skills unification has $FAIL issues that need attention."
    exit 1
fi
