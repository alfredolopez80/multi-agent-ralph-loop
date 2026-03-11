#!/usr/bin/env bash
# test-iterate.sh - Tests for /iterate skill (renamed from /loop)
# VERSION: 2.94.0
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/.claude/skills/iterate/SKILL.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=========================================="
echo "  TEST: /iterate skill (v2.94.0)"
echo "=========================================="

# Test 1: Skill exists
echo ""
echo "--- Test 1: Skill exists ---"
if [[ -f "$SKILL_PATH" ]]; then
  pass "Skill exists at .claude/skills/iterate/SKILL.md"
else
  fail "Skill not found"
fi

# Test 2: name: iterate in frontmatter
echo ""
echo "--- Test 2: Frontmatter name ---"
if grep -q "^name: iterate" "$SKILL_PATH"; then
  pass "name: iterate found in frontmatter"
else
  fail "name: iterate NOT found"
fi

# Test 3: Contains VERIFIED_DONE pattern
echo ""
echo "--- Test 3: VERIFIED_DONE pattern ---"
if grep -q "VERIFIED_DONE" "$SKILL_PATH"; then
  pass "VERIFIED_DONE pattern present"
else
  fail "VERIFIED_DONE pattern missing"
fi

# Test 4: No references to old name: loop
echo ""
echo "--- Test 4: No old name: loop ---"
if grep -q "^name: loop" "$SKILL_PATH"; then
  fail "Old 'name: loop' still present"
else
  pass "No 'name: loop' found"
fi

# Test 5: Symlinks exist
echo ""
echo "--- Test 5: Symlinks ---"
SYMLINK_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.ralph/skills"
  "$HOME/.cc-mirror/zai/config/skills"
  "$HOME/.cc-mirror/minimax/config/skills"
  "$HOME/.config/agents/skills"
)

for dir in "${SYMLINK_DIRS[@]}"; do
  link="$dir/iterate"
  if [[ -L "$link" ]] || [[ -d "$link" ]]; then
    pass "Symlink exists: $link"
  else
    fail "Symlink missing: $link"
  fi
done

# Test 6: Old /loop directory removed
echo ""
echo "--- Test 6: Old loop directory removed ---"
if [[ -d "$REPO_ROOT/.claude/skills/loop" ]]; then
  fail ".claude/skills/loop still exists"
else
  pass ".claude/skills/loop removed"
fi

# Test 7: user-invocable: true
echo ""
echo "--- Test 7: user-invocable ---"
if grep -q "user-invocable: true" "$SKILL_PATH"; then
  pass "user-invocable: true present"
else
  fail "user-invocable: true missing"
fi

# Summary
echo ""
echo "=========================================="
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
