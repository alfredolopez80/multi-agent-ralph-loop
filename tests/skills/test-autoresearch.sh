#!/usr/bin/env bash
# test-autoresearch.sh - Tests for /autoresearch skill and agent
# VERSION: 2.95.0
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
echo "  TEST: /autoresearch skill (v2.95.0)"
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

# Test 9: NEVER STOP philosophy (v2.95 - replaced max_stagnation default)
echo ""
echo "--- Test 9: NEVER STOP philosophy ---"
if grep -qi "never stop" "$SKILL_PATH" && grep -qi "never stop" "$AGENT_PATH"; then
  pass "NEVER STOP philosophy in both skill and agent"
else
  fail "NEVER STOP philosophy missing"
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

# === NEW v2.95 TESTS ===

# Test 12: autoresearch.md living document
echo ""
echo "--- Test 12: autoresearch.md living document ---"
if grep -q "autoresearch.md" "$SKILL_PATH" && grep -q "autoresearch.md" "$AGENT_PATH"; then
  pass "autoresearch.md session document in skill and agent"
else
  fail "autoresearch.md session document missing"
fi

# Test 13: autoresearch.jsonl structured log
echo ""
echo "--- Test 13: JSONL structured log ---"
if grep -q "autoresearch.jsonl" "$SKILL_PATH" && grep -q "autoresearch.jsonl" "$AGENT_PATH"; then
  pass "autoresearch.jsonl structured log in skill and agent"
else
  fail "autoresearch.jsonl structured log missing"
fi

# Test 14: autoresearch.checks.sh backpressure
echo ""
echo "--- Test 14: Backpressure checks ---"
if grep -q "autoresearch.checks.sh" "$SKILL_PATH" && grep -q "checks_failed" "$SKILL_PATH"; then
  pass "Backpressure checks with checks_failed status"
else
  fail "Backpressure checks missing"
fi

# Test 15: autoresearch.ideas.md backlog
echo ""
echo "--- Test 15: Ideas backlog ---"
if grep -q "autoresearch.ideas.md" "$SKILL_PATH" && grep -q "autoresearch.ideas.md" "$AGENT_PATH"; then
  pass "Ideas backlog in skill and agent"
else
  fail "Ideas backlog missing"
fi

# Test 16: Simplicity criterion
echo ""
echo "--- Test 16: Simplicity criterion ---"
if grep -qi "simplicity" "$SKILL_PATH" && grep -qi "simplicity" "$AGENT_PATH"; then
  pass "Simplicity criterion in skill and agent"
else
  fail "Simplicity criterion missing"
fi

# Test 17: Output redirect (run.log)
echo ""
echo "--- Test 17: Output redirect ---"
if grep -q "run.log" "$SKILL_PATH" && grep -q "run.log" "$AGENT_PATH"; then
  pass "Output redirect to run.log in skill and agent"
else
  fail "Output redirect missing"
fi

# Test 18: git reset --hard (not git revert)
echo ""
echo "--- Test 18: git reset --hard ---"
if grep -q "git reset --hard" "$SKILL_PATH" && grep -q "git reset --hard" "$AGENT_PATH"; then
  pass "git reset --hard in skill and agent"
else
  fail "git reset --hard missing"
fi

# Test 19: Dual metric mode
echo ""
echo "--- Test 19: Dual metric mode ---"
if grep -qi "primary_secondary" "$SKILL_PATH" && grep -qi "pareto" "$SKILL_PATH" && grep -qi "weighted" "$SKILL_PATH"; then
  pass "Dual metric modes: primary_secondary, pareto, weighted"
else
  fail "Dual metric modes missing"
fi

# Test 20: Cost awareness / budget caps
echo ""
echo "--- Test 20: Cost awareness ---"
if grep -q "budget_max_experiments" "$SKILL_PATH" && grep -q "budget_max_hours" "$SKILL_PATH"; then
  pass "Budget caps (experiments, hours) present"
else
  fail "Budget caps missing"
fi

# Test 21: Setup contract (4 required components)
echo ""
echo "--- Test 21: Setup contract ---"
if grep -q "Setup Contract" "$SKILL_PATH" && grep -q "eval_harness" "$SKILL_PATH"; then
  pass "Setup contract with eval_harness present"
else
  fail "Setup contract missing"
fi

# Test 22: Crash handling statuses
echo ""
echo "--- Test 22: Crash handling statuses ---"
STATUSES=("keep" "discard" "crash" "checks_failed")
ALL_FOUND=true
for s in "${STATUSES[@]}"; do
  if ! grep -q "$s" "$SKILL_PATH"; then
    ALL_FOUND=false
  fi
done
if $ALL_FOUND; then
  pass "All 4 statuses: keep, discard, crash, checks_failed"
else
  fail "Missing one or more statuses"
fi

# Test 23: Resumability
echo ""
echo "--- Test 23: Resumability ---"
if grep -qi "resumab" "$SKILL_PATH" && grep -qi "resumab" "$AGENT_PATH"; then
  pass "Resumability documented in skill and agent"
else
  fail "Resumability missing"
fi

# Test 24: Domain examples table
echo ""
echo "--- Test 24: Domain examples ---"
if grep -q "ML training" "$SKILL_PATH" && grep -q "Prompt engineering" "$SKILL_PATH" && grep -q "SQL queries" "$SKILL_PATH"; then
  pass "Domain examples: ML, prompts, SQL"
else
  fail "Domain examples missing"
fi

# Test 25: Version 3.1.0
echo ""
echo "--- Test 25: Version 3.1.0 ---"
if grep -q "3.1.0" "$SKILL_PATH" && grep -q "3.1.0" "$AGENT_PATH"; then
  pass "Version 3.1.0 in skill and agent"
else
  fail "Version 3.1.0 missing"
fi

# Test 26: Stagnation strategy in agent
echo ""
echo "--- Test 26: Stagnation strategy ---"
if grep -qi "stagnation" "$AGENT_PATH" && grep -q "25-50" "$AGENT_PATH"; then
  pass "Stagnation strategy with graduated approach in agent"
else
  fail "Stagnation strategy missing from agent"
fi

# Test 27: User messages during loop
echo ""
echo "--- Test 27: User messages during loop ---"
if grep -qi "user.*message" "$SKILL_PATH" || grep -qi "user sends a message" "$SKILL_PATH"; then
  pass "User messages during loop handling documented"
else
  fail "User messages during loop not documented"
fi

# Summary
echo ""
echo "=========================================="
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
