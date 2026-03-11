#!/usr/bin/env bash
# test-autoresearch.sh - Tests for /autoresearch skill and agent
# VERSION: 2.94.0
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/.claude/skills/autoresearch/SKILL.md"
AGENT_PATH="$REPO_ROOT/.claude/agents/autoresearch.md"
TEMPLATE_PATH="$REPO_ROOT/.claude/skills/autoresearch/program-template.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=========================================="
echo "  TEST: /autoresearch skill (v2.94.0)"
echo "=========================================="

# Test 1: Skill exists
echo ""
echo "--- Test 1: Skill exists ---"
if [[ -f "$SKILL_PATH" ]]; then
  pass "Skill exists at .claude/skills/autoresearch/SKILL.md"
else
  fail "Skill not found"
fi

# Test 2: Agent exists
echo ""
echo "--- Test 2: Agent exists ---"
if [[ -f "$AGENT_PATH" ]]; then
  pass "Agent exists at .claude/agents/autoresearch.md"
else
  fail "Agent not found"
fi

# Test 3: Program template exists
echo ""
echo "--- Test 3: Program template exists ---"
if [[ -f "$TEMPLATE_PATH" ]]; then
  pass "Program template exists"
else
  fail "Program template not found"
fi

# Test 4: user-invocable: true
echo ""
echo "--- Test 4: user-invocable ---"
if grep -q "user-invocable: true" "$SKILL_PATH"; then
  pass "user-invocable: true present"
else
  fail "user-invocable: true missing"
fi

# Test 5: Skill references agent: autoresearch
echo ""
echo "--- Test 5: Agent reference ---"
if grep -q "agent: autoresearch" "$SKILL_PATH"; then
  pass "agent: autoresearch referenced in skill"
else
  fail "agent: autoresearch not found in skill"
fi

# Test 6: Agent has maxTurns: 200
echo ""
echo "--- Test 6: maxTurns ---"
if grep -q "maxTurns: 200" "$AGENT_PATH"; then
  pass "maxTurns: 200 in agent"
else
  fail "maxTurns: 200 not found in agent"
fi

# Test 7: Skill mentions results.tsv
echo ""
echo "--- Test 7: results.tsv ---"
if grep -q "results.tsv" "$SKILL_PATH"; then
  pass "results.tsv mentioned in skill"
else
  fail "results.tsv not mentioned"
fi

# Test 8: Skill mentions autoresearch/<tag> branch
echo ""
echo "--- Test 8: Branch pattern ---"
if grep -q "autoresearch/" "$SKILL_PATH"; then
  pass "autoresearch/<tag> branch pattern found"
else
  fail "autoresearch/ branch pattern not found"
fi

# Test 9: Stagnation detection (50 iterations)
echo ""
echo "--- Test 9: Stagnation detection ---"
if grep -q "50" "$SKILL_PATH" && grep -qi "stagnation" "$SKILL_PATH"; then
  pass "Stagnation detection with 50 iterations"
else
  fail "Stagnation detection missing"
fi

# Test 10: Checkpoint system
echo ""
echo "--- Test 10: Checkpoint system ---"
if grep -qi "checkpoint" "$SKILL_PATH"; then
  pass "Checkpoint system present"
else
  fail "Checkpoint system missing"
fi

# Test 11: Symlinks exist
echo ""
echo "--- Test 11: Symlinks ---"
SYMLINK_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.ralph/skills"
  "$HOME/.cc-mirror/zai/config/skills"
  "$HOME/.cc-mirror/minimax/config/skills"
  "$HOME/.config/agents/skills"
)

for dir in "${SYMLINK_DIRS[@]}"; do
  link="$dir/autoresearch"
  if [[ -L "$link" ]] || [[ -d "$link" ]]; then
    pass "Symlink exists: $link"
  else
    fail "Symlink missing: $link"
  fi
done

# Summary
echo ""
echo "=========================================="
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
