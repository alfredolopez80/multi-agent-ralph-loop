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

# Test 5: is_worktree returns 1 in normal repo
echo ""
echo "--- Test 5: is_worktree in normal repo ---"
if is_worktree; then
  fail "is_worktree returned 0 (worktree) in normal repo"
else
  pass "is_worktree correctly returns 1 in normal repo"
fi

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
HOOKS_TO_CHECK=(
  "session-start-repo-summary.sh"
  "ralph-subagent-start.sh"
  "pre-commit-batch-skills-test.sh"
  "task-completed-quality-gate.sh"
  "teammate-idle-quality-gate.sh"
  "ralph-stop-quality-gate.sh"
  "subagent-stop-universal.sh"
  "quality-parallel-async.sh"
  "glm-visual-validation.sh"
  "repo-boundary-guard.sh"
  "session-end-handoff.sh"
  "plan-state-init.sh"
  "auto-plan-state.sh"
  "stop-verification.sh"
  "auto-save-context.sh"
  "agent-teams-coordinator.sh"
  "global-task-sync.sh"
)

for hook in "${HOOKS_TO_CHECK[@]}"; do
  hook_path=".claude/hooks/$hook"
  if [[ -f "$hook_path" ]] && grep -q "worktree-utils.sh" "$hook_path"; then
    pass "$hook sources worktree-utils.sh"
  else
    fail "$hook does NOT source worktree-utils.sh"
  fi
done

# Test 8: No hardcoded user paths in agent-teams-coordinator
echo ""
echo "--- Test 8: No hardcoded paths ---"
if grep -q "/Users/alfredolopez" .claude/hooks/agent-teams-coordinator.sh; then
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
