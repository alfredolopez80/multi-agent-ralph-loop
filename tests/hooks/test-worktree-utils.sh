#!/usr/bin/env bash
# test-worktree-utils.sh - Tests for worktree-safe utility library
# VERSION: 2.94.0
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
UTILS_PATH="$REPO_ROOT/.claude/hooks/lib/worktree-utils.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=========================================="
echo "  TEST: worktree-utils.sh (v2.94.0)"
echo "=========================================="

# Test 1: File exists and is sourceable
echo ""
echo "--- Test 1: File exists and is sourceable ---"
if [[ -f "$UTILS_PATH" ]]; then
  pass "worktree-utils.sh exists"
else
  fail "worktree-utils.sh not found at $UTILS_PATH"
fi

if bash -n "$UTILS_PATH" 2>/dev/null; then
  pass "worktree-utils.sh has valid syntax"
else
  fail "worktree-utils.sh has syntax errors"
fi

# Source the library for remaining tests
source "$UTILS_PATH"

# Test 2: get_project_root returns valid directory
echo ""
echo "--- Test 2: get_project_root ---"
result="$(get_project_root)"
if [[ -d "$result" ]]; then
  pass "get_project_root returns valid directory: $result"
else
  fail "get_project_root returned invalid directory: $result"
fi

# Test 3: get_main_repo returns valid directory
echo ""
echo "--- Test 3: get_main_repo ---"
result="$(get_main_repo)"
if [[ -d "$result" ]]; then
  pass "get_main_repo returns valid directory: $result"
else
  fail "get_main_repo returned invalid directory: $result"
fi

# Test 4: get_claude_dir returns path with .claude
echo ""
echo "--- Test 4: get_claude_dir ---"
result="$(get_claude_dir)"
if [[ "$result" == *".claude" ]]; then
  pass "get_claude_dir ends with .claude: $result"
else
  fail "get_claude_dir does not end with .claude: $result"
fi

# Test 5: is_worktree returns 1 in a normal repo
echo ""
echo "--- Test 5: is_worktree in normal repo ---"
# Asserted against a purpose-built fixture rather than the ambient checkout: this
# project is routinely developed from git worktrees (.claude/worktrees/), where
# the ambient answer is legitimately "yes" and the old assertion always failed.
NON_WT_DIR="$(mktemp -d)"
git init "$NON_WT_DIR/plain-repo" --quiet 2>/dev/null
if (cd "$NON_WT_DIR/plain-repo" && is_worktree); then
  fail "is_worktree returned 0 (worktree) for a plain, non-worktree repo"
else
  pass "is_worktree correctly returns 1 in a plain repo"
fi
rm -rf "$NON_WT_DIR"

# Test 6: Simulated worktree test
echo ""
echo "--- Test 6: Worktree simulation ---"
TEMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TEMP_DIR"; }
trap cleanup EXIT

# Create a temporary git repo
git init "$TEMP_DIR/main-repo" --quiet 2>/dev/null
cd "$TEMP_DIR/main-repo"
git commit --allow-empty -m "init" --quiet 2>/dev/null

# Create a worktree
git worktree add "$TEMP_DIR/test-worktree" HEAD --quiet 2>/dev/null

# Verify .git is a file in worktree
if [[ -f "$TEMP_DIR/test-worktree/.git" ]]; then
  pass "Worktree .git is a file (expected)"
else
  fail "Worktree .git is not a file"
fi

# Source utils in worktree context and test get_main_repo
cd "$TEMP_DIR/test-worktree"
source "$UTILS_PATH"

wt_main="$(get_main_repo)"
# macOS: /var is a symlink to /private/var, normalize both paths
expected_main="$(cd "$TEMP_DIR/main-repo" && pwd -P)"
actual_main="$(cd "$wt_main" && pwd -P)"
if [[ "$actual_main" == "$expected_main" ]]; then
  pass "get_main_repo correctly returns main repo from worktree"
else
  fail "get_main_repo returned '$actual_main' instead of '$expected_main'"
fi

if is_worktree; then
  pass "is_worktree correctly returns 0 in worktree"
else
  fail "is_worktree returned 1 in actual worktree"
fi

# Cleanup worktree
cd "$TEMP_DIR/main-repo"
git worktree remove "$TEMP_DIR/test-worktree" --force 2>/dev/null || true

# Test 7: All hooks source worktree-utils.sh
echo ""
echo "--- Test 7: Hooks source worktree-utils.sh ---"
cd "$REPO_ROOT"
# Paths are relative to the repo root. Entries dropped because the file is no
# longer part of the active hook set: glm-visual-validation.sh (.claude/archive/)
# and plan-state-init.sh, stop-verification.sh, auto-save-context.sh,
# global-task-sync.sh (.claude/archive/pre-migration-v2.70.0-*/), plus
# pre-commit-batch-skills-test.sh, which is not present anywhere. Listing them
# only produced permanent failures blamed on a missing `source` line.
# agent-teams-coordinator.sh lives in .claude/lib/, not .claude/hooks/.
HOOKS_TO_CHECK=(
  ".claude/hooks/session-start-repo-summary.sh"
  ".claude/hooks/ralph-subagent-start.sh"
  ".claude/hooks/task-completed-quality-gate.sh"
  ".claude/hooks/teammate-idle-quality-gate.sh"
  ".claude/hooks/ralph-stop-quality-gate.sh"
  ".claude/hooks/subagent-stop-universal.sh"
  ".claude/hooks/quality-parallel-async.sh"
  ".claude/hooks/repo-boundary-guard.sh"
  ".claude/hooks/session-end-handoff.sh"
  ".claude/hooks/auto-plan-state.sh"
)

for hook_path in "${HOOKS_TO_CHECK[@]}"; do
  hook="$(basename "$hook_path")"
  # A missing file and a file that simply lacks the source line are different
  # defects; reporting both as "does NOT source" hid five relocated hooks.
  if [[ ! -f "$hook_path" ]]; then
    fail "$hook not found at $hook_path"
  elif grep -q "worktree-utils.sh" "$hook_path"; then
    pass "$hook sources worktree-utils.sh"
  else
    fail "$hook does NOT source worktree-utils.sh"
  fi
done

# Test 8: No hardcoded user paths in agent-teams-coordinator
echo ""
echo "--- Test 8: No hardcoded paths ---"
# The file lives in .claude/lib/, not .claude/hooks/. Grepping the wrong path
# made this check vacuous: grep failed on the missing file and the else branch
# reported a pass regardless of the file's contents.
COORDINATOR=".claude/lib/agent-teams-coordinator.sh"
if [[ ! -f "$COORDINATOR" ]]; then
  fail "$COORDINATOR not found — this check cannot validate anything"
elif grep -q "/Users/alfredolopez" "$COORDINATOR"; then
  fail "agent-teams-coordinator.sh still contains hardcoded /Users/alfredolopez"
else
  pass "agent-teams-coordinator.sh has no hardcoded user paths"
fi

# Summary
echo ""
echo "=========================================="
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
