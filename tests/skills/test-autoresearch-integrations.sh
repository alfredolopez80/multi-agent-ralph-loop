#!/usr/bin/env bash
# test-autoresearch-integrations.sh - Integration tests for autoresearch v2.95 cross-system integrations
# VERSION: 2.95.0
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Agent paths
ORCHESTRATOR="$REPO_ROOT/.claude/agents/orchestrator.md"
PATTERN_REC="$REPO_ROOT/.claude/agents/pattern-recognition-specialist.md"
QUALITY_AUD="$REPO_ROOT/.claude/agents/quality-auditor.md"
PROMPT_OPT="$REPO_ROOT/.claude/agents/prompt-optimizer.md"
AUTORESEARCH_AGENT="$REPO_ROOT/.claude/agents/autoresearch.md"

# Skill paths
AUTORESEARCH_SKILL="$REPO_ROOT/.claude/skills/autoresearch/SKILL.md"
ITERATE_SKILL="$REPO_ROOT/.claude/skills/iterate/SKILL.md"
GATES_SKILL="$REPO_ROOT/.claude/skills/gates/SKILL.md"

PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=========================================="
echo "  TEST: autoresearch integrations (v2.95)"
echo "=========================================="

# =============================================
# AGENT INTEGRATIONS
# =============================================

echo ""
echo "=== Agent Integrations ==="

# Test 1: Orchestrator has "Autoresearch Integration" section
echo ""
echo "--- Test 1: Orchestrator autoresearch section ---"
if grep -qi "Autoresearch Integration" "$ORCHESTRATOR" 2>/dev/null; then
  pass "Orchestrator has 'Autoresearch Integration' section"
else
  fail "Orchestrator missing 'Autoresearch Integration' section"
fi

# Test 2: Pattern-recognition-specialist has "Autoresearch Ideas Seeding" section
echo ""
echo "--- Test 2: Pattern-recognition autoresearch section ---"
if grep -qi "Autoresearch Ideas Seeding" "$PATTERN_REC" 2>/dev/null; then
  pass "Pattern-recognition-specialist has 'Autoresearch Ideas Seeding' section"
else
  fail "Pattern-recognition-specialist missing 'Autoresearch Ideas Seeding' section"
fi

# Test 3: Quality-auditor has "Autoresearch Checks Template" section
echo ""
echo "--- Test 3: Quality-auditor autoresearch section ---"
if grep -qi "Autoresearch Checks Template" "$QUALITY_AUD" 2>/dev/null; then
  pass "Quality-auditor has 'Autoresearch Checks Template' section"
else
  fail "Quality-auditor missing 'Autoresearch Checks Template' section"
fi

# Test 4: Prompt-optimizer has "Autoresearch" or "Self-Optimization" section
echo ""
echo "--- Test 4: Prompt-optimizer autoresearch section ---"
if grep -qi -E "Autoresearch|Self-Optimization" "$PROMPT_OPT" 2>/dev/null; then
  pass "Prompt-optimizer has autoresearch or self-optimization section"
else
  fail "Prompt-optimizer missing autoresearch/self-optimization section"
fi

# Test 5: All 4 agents reference version 2.95
echo ""
echo "--- Test 5: All 4 agents version >= 2.95 ---"
AGENTS_295=0
for agent_file in "$ORCHESTRATOR" "$PATTERN_REC" "$QUALITY_AUD" "$PROMPT_OPT"; do
  agent_name="$(basename "$agent_file")"
  if grep -q "2\.95" "$agent_file" 2>/dev/null; then
    AGENTS_295=$((AGENTS_295 + 1))
  else
    echo "    (missing 2.95 in $agent_name)"
  fi
done
if [[ $AGENTS_295 -eq 4 ]]; then
  pass "All 4 agents reference version 2.95"
else
  fail "Only $AGENTS_295/4 agents reference version 2.95"
fi

# =============================================
# SKILL INTEGRATIONS
# =============================================

echo ""
echo "=== Skill Integrations ==="

# Test 6: /iterate SKILL.md has "Autoresearch Delegation" section
echo ""
echo "--- Test 6: Iterate autoresearch delegation ---"
if grep -qi "Autoresearch Delegation" "$ITERATE_SKILL" 2>/dev/null; then
  pass "/iterate SKILL.md has 'Autoresearch Delegation' section"
else
  fail "/iterate SKILL.md missing 'Autoresearch Delegation' section"
fi

# Test 7: /gates skill has autoresearch integration section
echo ""
echo "--- Test 7: Gates autoresearch integration ---"
if [[ -f "$GATES_SKILL" ]]; then
  if grep -qi -E "autoresearch" "$GATES_SKILL" 2>/dev/null; then
    pass "/gates SKILL.md has autoresearch integration"
  else
    fail "/gates SKILL.md missing autoresearch integration"
  fi
else
  fail "/gates SKILL.md not found"
fi

# Test 8: Autoresearch SKILL.md references /iterate and /gates in Related Skills
echo ""
echo "--- Test 8: Autoresearch cross-references ---"
HAS_ITERATE=false
HAS_GATES=false
if grep -q "/iterate" "$AUTORESEARCH_SKILL" 2>/dev/null; then
  HAS_ITERATE=true
fi
if grep -q "/gates" "$AUTORESEARCH_SKILL" 2>/dev/null; then
  HAS_GATES=true
fi
if $HAS_ITERATE && $HAS_GATES; then
  pass "Autoresearch SKILL.md references both /iterate and /gates"
else
  fail "Autoresearch SKILL.md missing cross-references (iterate=$HAS_ITERATE, gates=$HAS_GATES)"
fi

# =============================================
# CROSS-REFERENCES
# =============================================

echo ""
echo "=== Cross-references ==="

# Test 9: Orchestrator mentions "/autoresearch" command
echo ""
echo "--- Test 9: Orchestrator /autoresearch command ---"
if grep -q "/autoresearch" "$ORCHESTRATOR" 2>/dev/null; then
  pass "Orchestrator mentions /autoresearch command"
else
  fail "Orchestrator does not mention /autoresearch command"
fi

# Test 10: Pattern-recognition mentions "autoresearch.ideas.md"
echo ""
echo "--- Test 10: Pattern-recognition ideas backlog ---"
if grep -q "autoresearch.ideas.md" "$PATTERN_REC" 2>/dev/null; then
  pass "Pattern-recognition mentions autoresearch.ideas.md"
else
  fail "Pattern-recognition does not mention autoresearch.ideas.md"
fi

# Test 11: Quality-auditor mentions "autoresearch.checks.sh"
echo ""
echo "--- Test 11: Quality-auditor checks script ---"
if grep -q "autoresearch.checks.sh" "$QUALITY_AUD" 2>/dev/null; then
  pass "Quality-auditor mentions autoresearch.checks.sh"
else
  fail "Quality-auditor does not mention autoresearch.checks.sh"
fi

# Test 12: Prompt-optimizer mentions "eval_prompt" or "autoresearch"
echo ""
echo "--- Test 12: Prompt-optimizer eval/autoresearch ---"
if grep -qi -E "eval_prompt|autoresearch" "$PROMPT_OPT" 2>/dev/null; then
  pass "Prompt-optimizer mentions eval_prompt or autoresearch"
else
  fail "Prompt-optimizer does not mention eval_prompt or autoresearch"
fi

# =============================================
# CONSISTENCY
# =============================================

echo ""
echo "=== Consistency ==="

# Test 13: All modified agents have version >= 2.95
echo ""
echo "--- Test 13: Modified agents version check ---"
MODIFIED_OK=0
MODIFIED_TOTAL=0
for agent_file in "$ORCHESTRATOR" "$PATTERN_REC" "$QUALITY_AUD" "$PROMPT_OPT"; do
  if [[ -f "$agent_file" ]]; then
    version_line="$(grep -m1 'VERSION:' "$agent_file" 2>/dev/null || true)"
    if [[ -n "$version_line" ]]; then
      version_num="$(echo "$version_line" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
      if [[ -n "$version_num" ]]; then
        major="${version_num%%.*}"
        minor="${version_num#*.}"
        MODIFIED_TOTAL=$((MODIFIED_TOTAL + 1))
        # version >= 2.95 means major > 2 OR (major == 2 AND minor >= 95)
        if [[ "$major" -gt 2 ]] || { [[ "$major" -eq 2 ]] && [[ "$minor" -ge 95 ]]; }; then
          MODIFIED_OK=$((MODIFIED_OK + 1))
        else
          echo "    ($(basename "$agent_file"): version $version_num < 2.95)"
        fi
      fi
    fi
  fi
done
if [[ $MODIFIED_OK -eq 4 ]]; then
  pass "All 4 agents have version >= 2.95"
else
  fail "Only $MODIFIED_OK/$MODIFIED_TOTAL agents have version >= 2.95"
fi

# Test 14: Autoresearch SKILL.md has all 4 statuses
echo ""
echo "--- Test 14: All 4 statuses ---"
ALL_STATUSES=true
for status in "keep" "discard" "crash" "checks_failed"; do
  if ! grep -q "$status" "$AUTORESEARCH_SKILL" 2>/dev/null; then
    ALL_STATUSES=false
    echo "    (missing status: $status)"
  fi
done
if $ALL_STATUSES; then
  pass "Autoresearch SKILL.md has all 4 statuses (keep, discard, crash, checks_failed)"
else
  fail "Autoresearch SKILL.md missing one or more statuses"
fi

# Test 15: Autoresearch SKILL.md has dual metric modes
echo ""
echo "--- Test 15: Dual metric modes ---"
HAS_PS=false
HAS_PARETO=false
HAS_WEIGHTED=false
grep -qi "primary_secondary" "$AUTORESEARCH_SKILL" 2>/dev/null && HAS_PS=true
grep -qi "pareto" "$AUTORESEARCH_SKILL" 2>/dev/null && HAS_PARETO=true
grep -qi "weighted" "$AUTORESEARCH_SKILL" 2>/dev/null && HAS_WEIGHTED=true
if $HAS_PS && $HAS_PARETO && $HAS_WEIGHTED; then
  pass "Dual metric modes: primary_secondary, pareto, weighted"
else
  fail "Missing metric modes (primary_secondary=$HAS_PS, pareto=$HAS_PARETO, weighted=$HAS_WEIGHTED)"
fi

# Test 16: Autoresearch agent has NEVER STOP philosophy
echo ""
echo "--- Test 16: NEVER STOP philosophy ---"
if grep -qi "never stop" "$AUTORESEARCH_AGENT" 2>/dev/null; then
  pass "Autoresearch agent has NEVER STOP philosophy"
else
  fail "Autoresearch agent missing NEVER STOP philosophy"
fi

# Test 17: Autoresearch SKILL.md has Setup Contract section
echo ""
echo "--- Test 17: Setup Contract ---"
if grep -qi "Setup Contract" "$AUTORESEARCH_SKILL" 2>/dev/null; then
  pass "Autoresearch SKILL.md has Setup Contract section"
else
  fail "Autoresearch SKILL.md missing Setup Contract section"
fi

# =============================================
# SYMLINKS
# =============================================

echo ""
echo "=== Symlinks ==="

# Test 18: All 6 platform symlinks exist for autoresearch skill
echo ""
echo "--- Test 18: Platform symlinks ---"
SYMLINK_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
  "$HOME/.ralph/skills"
  "$HOME/.cc-mirror/zai/config/skills"
  "$HOME/.cc-mirror/minimax/config/skills"
  "$HOME/.config/agents/skills"
)

SYMLINKS_OK=0
SYMLINKS_TOTAL=${#SYMLINK_DIRS[@]}
for dir in "${SYMLINK_DIRS[@]}"; do
  link="$dir/autoresearch"
  if [[ -L "$link" ]] || [[ -d "$link" ]]; then
    SYMLINKS_OK=$((SYMLINKS_OK + 1))
  else
    echo "    (missing symlink: $link)"
  fi
done
if [[ $SYMLINKS_OK -eq $SYMLINKS_TOTAL ]]; then
  pass "All $SYMLINKS_TOTAL platform symlinks exist for autoresearch"
else
  fail "Only $SYMLINKS_OK/$SYMLINKS_TOTAL symlinks present"
fi

# =============================================
# SUMMARY
# =============================================

echo ""
echo "=========================================="
echo "  RESULTS: $PASS passed, $FAIL failed"
echo "=========================================="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1
