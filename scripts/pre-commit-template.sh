#!/bin/bash
# pre-commit hook for multi-agent-ralph-loop
# VERSION: 2.87.1
# Purpose: Validate hooks, skills, and architecture before commit
#
# v2.87.1 — Fix silent empty-commit bug
#   - Phases 6/7/8 now run with env -u GIT_INDEX_FILE -u GIT_DIR to prevent
#     invoked hooks from writing to the commit's temporary index.
#   - Added tree-integrity guard: aborts with clear error if the staged index
#     mutated during validation (replaces silent failure with loud failure).
#
# CRITICAL FORMAT RULES (per official Claude Code docs):
# - PostToolUse/PreToolUse/UserPromptSubmit: {"continue": true/false}
# - Stop hooks ONLY: {"decision": "approve"/"block"}
# - The string "continue" is NEVER valid for the "decision" field
#
# VALIDATION PHASES:
# 1. Hook JSON format validation
# 2. Skills unification validation (if skills changed)
# 3. Architecture documentation validation

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_ROOT="$(git rev-parse --show-toplevel)"
ERRORS=0

# Index integrity guard: capture the tree hash BEFORE validation phases run.
# If anything the hook invokes mutates the index (e.g., child hooks from Phase
# 6/7/8 with inherited GIT_INDEX_FILE), we compare at the end and abort loudly
# instead of producing a silently-empty commit.
# Root cause: docs/architecture bug where commits landed with 0 files despite
# correct staging (observed in 0b805de, 13e0f9c, acaf115 — v2.87.0 bug).
PRE_HOOK_TREE="$(git write-tree 2>/dev/null || echo UNKNOWN)"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Pre-commit Validation v2.87.1${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

#######################################
# Phase 1: Hook JSON Format Validation
#######################################
STAGED_HOOKS=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.claude/hooks/.*\.(sh|py)$' || true)

if [[ -n "$STAGED_HOOKS" ]]; then
    echo -e "${YELLOW}[Phase 1] Validating Claude Code hook JSON formats${NC}"

    for hook_file in $STAGED_HOOKS; do
        [[ ! -f "$hook_file" ]] && continue

        hook_name=$(basename "$hook_file")

        # CRITICAL: "decision": "continue" is NEVER valid
        # v3.1.1: skip comment lines — a hook documenting the invalid form in a comment is
        # not a violation; only active code matters.
        if grep -vE '^[[:space:]]*#' "$hook_file" | grep -qE '"decision":\s*"continue"'; then
            echo -e "  ${RED}✗ $hook_name: Uses invalid {\"decision\": \"continue\"}${NC}"
            ((ERRORS++))
            continue
        fi

        echo -e "  ${GREEN}✓ $hook_name${NC}"
    done
else
    echo -e "${YELLOW}[Phase 1] Skipped (no hooks changed)${NC}"
fi

#######################################
# Phase 1b: PreToolUse permissionDecision enum guard
#######################################
# Regression guard for the "Hook JSON output validation failed — (root):
# Invalid input" error: PreToolUse hooks must emit permissionDecision values of
# allow|deny|ask, NEVER "block" ("block" belongs to the Stop `decision` field).
# Logic lives in one place (the external checker) so it is also pytest-testable.
if [[ -n "$STAGED_HOOKS" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 1b] Validating PreToolUse permissionDecision enum${NC}"
    PD_CHECK="$REPO_ROOT/scripts/check-pretooluse-permission-decision.sh"
    if [[ -x "$PD_CHECK" ]]; then
        if "$PD_CHECK" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ permissionDecision values are allow|deny|ask${NC}"
        else
            echo -e "  ${RED}✗ Invalid permissionDecision (use \"deny\", not \"block\")${NC}"
            echo -e "  ${YELLOW}  Run: $PD_CHECK${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "  ${YELLOW}⚠ Checker not found: $PD_CHECK${NC}"
    fi
fi

#######################################
# Phase 2: Skills Unification Validation
#######################################
STAGED_SKILLS=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.claude/skills/.*SKILL\.md$' || true)

if [[ -n "$STAGED_SKILLS" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 2] Validating skills unification${NC}"

    SKILLS_TEST="$REPO_ROOT/tests/unit/test-skills-unification-v2.87.sh"

    if [[ -x "$SKILLS_TEST" ]]; then
        # Run quick validation (not verbose, just check pass/fail)
        if "$SKILLS_TEST" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ Skills unification validated${NC}"
        else
            echo -e "  ${RED}✗ Skills unification test failed${NC}"
            echo -e "  ${YELLOW}  Run for details: $SKILLS_TEST --verbose${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "  ${YELLOW}⚠ Skills test script not found or not executable${NC}"
    fi
else
    echo -e "${YELLOW}[Phase 2] Skipped (no skills changed)${NC}"
fi

#######################################
# Phase 3: Architecture Documentation Check
#######################################
STAGED_DOCS=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^docs/architecture/.*\.md$' || true)

if [[ -n "$STAGED_DOCS" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 3] Validating architecture documentation${NC}"

    for doc in $STAGED_DOCS; do
        if [[ -f "$doc" ]]; then
            # Check for required metadata
            if grep -qE "^\*\*Date\*\*:|^\*\*Version\*\*:" "$doc" 2>/dev/null; then
                echo -e "  ${GREEN}✓ $(basename "$doc")${NC}"
            else
                echo -e "  ${YELLOW}⚠ $(basename "$doc"): Missing metadata header${NC}"
            fi
        fi
    done
else
    echo -e "${YELLOW}[Phase 3] Skipped (no architecture docs changed)${NC}"
fi

#######################################
# Phase 4: CLAUDE.md Version Check
#######################################
STAGED_CLAUDE_MD=$(git diff --cached --name-only --diff-filter=ACM | grep -E '^CLAUDE\.md$' || true)

if [[ -n "$STAGED_CLAUDE_MD" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 4] Validating CLAUDE.md version${NC}"

    CURRENT_VERSION=$(grep -E "^# Multi-Agent Ralph v" "$REPO_ROOT/CLAUDE.md" 2>/dev/null | head -1 | sed 's/^# Multi-Agent Ralph v//' | tr -d ' ')

    if [[ -n "$CURRENT_VERSION" ]]; then
        echo -e "  ${GREEN}✓ CLAUDE.md version: $CURRENT_VERSION${NC}"
    else
        echo -e "  ${YELLOW}⚠ Could not detect version in CLAUDE.md${NC}"
    fi
fi

#######################################
# Phase 5: Skills Symlink Validation
#######################################
STAGED_SKILL_DIRS=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.claude/skills/[^/]+/' | head -1 || true)

if [[ -n "$STAGED_SKILL_DIRS" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 5] Validating skills symlinks${NC}"

    SYMLINK_TEST="$REPO_ROOT/tests/unit/test-skills-symlinks-v2.87.sh"

    if [[ -x "$SYMLINK_TEST" ]]; then
        # Run quick validation
        if "$SYMLINK_TEST" > /dev/null 2>&1; then
            echo -e "  ${GREEN}✓ Skills symlinks validated${NC}"
        else
            echo -e "  ${YELLOW}⚠ Skills symlink test has warnings (run -v for details)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ Symlink test script not found${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}[Phase 5] Skipped (no skills changed)${NC}"
fi

#######################################
# Phase 6: Skills Sync Validation
#######################################
SYNC_TEST="$REPO_ROOT/tests/unit/test-skills-sync-v2.87.sh"

if [[ -x "$SYNC_TEST" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 6] Validating skills sync${NC}"

    # Isolate: unset GIT_INDEX_FILE/GIT_DIR so any child git commands in the
    # test don't write to the commit's temporary index (v2.87.1 fix).
    if env -u GIT_INDEX_FILE -u GIT_DIR -u GIT_WORK_TREE "$SYNC_TEST" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Skills sync validated${NC}"
    else
        echo -e "  ${YELLOW}⚠ Skills sync test has warnings${NC}"
        echo -e "  ${YELLOW}  Run: $SYNC_TEST -v${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}[Phase 6] Skipped (sync test not found)${NC}"
fi

#######################################
# Phase 7: Model-Agnostic Validation
#######################################
MODEL_AGNOSTIC_TEST="$REPO_ROOT/tests/unit/test-model-agnostic-v2.88.sh"

if [[ -x "$MODEL_AGNOSTIC_TEST" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 7] Validating model-agnostic architecture${NC}"

    if env -u GIT_INDEX_FILE -u GIT_DIR -u GIT_WORK_TREE "$MODEL_AGNOSTIC_TEST" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Model-agnostic validated${NC}"
    else
        echo -e "  ${RED}✗ Model-agnostic validation failed${NC}"
        echo -e "  ${YELLOW}  Run: $MODEL_AGNOSTIC_TEST -v${NC}"
        ((ERRORS++))
    fi
else
    echo ""
    echo -e "${YELLOW}[Phase 7] Skipped (model-agnostic test not found)${NC}"
fi

#######################################
# Phase 8: Hook Integration Validation
#######################################
HOOK_INTEGRATION_TEST="$REPO_ROOT/tests/hook-integration/test-hook-integration-v2.88.sh"

if [[ -x "$HOOK_INTEGRATION_TEST" ]]; then
    echo ""
    echo -e "${YELLOW}[Phase 8] Validating hook integration (5 findings)${NC}"

    # Phase 8 invokes real hooks (ralph-subagent-{start,stop}.sh etc.) which
    # inherit GIT_INDEX_FILE during `git commit` and can corrupt the commit's
    # temporary index. Strip those env vars so child git calls use the real
    # repo index (v2.87.1 fix for silent empty-commit bug).
    if env -u GIT_INDEX_FILE -u GIT_DIR -u GIT_WORK_TREE "$HOOK_INTEGRATION_TEST" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ Hook integration validated${NC}"
    else
        echo -e "  ${RED}✗ Hook integration validation failed${NC}"
        echo -e "  ${YELLOW}  Run: $HOOK_INTEGRATION_TEST -v${NC}"
        ((ERRORS++))
    fi
else
    echo ""
    echo -e "${YELLOW}[Phase 8] Skipped (hook integration test not found)${NC}"
fi

#######################################
# Summary
#######################################
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}COMMIT BLOCKED: $ERRORS validation error(s)${NC}"
    echo ""
    echo "Fix the issues above and try again."
    echo "For detailed skills validation: tests/unit/test-skills-unification-v2.87.sh --verbose"
    exit 1
fi

# Index integrity guard (v2.87.1):
# Detect if any validation phase mutated the staged index. This catches the
# silent empty-commit bug where child hooks inherited GIT_INDEX_FILE and
# overwrote the commit's temporary tree.
POST_HOOK_TREE="$(git write-tree 2>/dev/null || echo UNKNOWN)"
if [[ "$PRE_HOOK_TREE" != "UNKNOWN" && "$POST_HOOK_TREE" != "UNKNOWN" && "$PRE_HOOK_TREE" != "$POST_HOOK_TREE" ]]; then
    echo ""
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  COMMIT BLOCKED: Pre-commit mutated the index${NC}"
    echo -e "${RED}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  Tree before: $PRE_HOOK_TREE${NC}"
    echo -e "${YELLOW}  Tree after:  $POST_HOOK_TREE${NC}"
    echo ""
    echo "A validation phase changed the staged files. This would have created"
    echo "a commit that doesn't match what you staged. Re-stage and try again."
    echo "(If this repeats, check env isolation in Phases 6/7/8.)"
    exit 1
fi

echo -e "${GREEN}✓ All validations passed${NC}"
exit 0
