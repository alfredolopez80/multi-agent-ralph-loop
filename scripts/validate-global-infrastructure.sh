#!/usr/bin/env bash
# validate-global-infrastructure.sh — Validates that all Ralph infrastructure
# is correctly distributed globally for use in any project.
# VERSION: 3.1.0
# Usage: bash scripts/validate-global-infrastructure.sh [--fix]
set -euo pipefail

REPO="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
FIX_MODE="${1:-}"
PASS=0
FAIL=0
FIXED=0

pass() { PASS=$((PASS + 1)); echo "  [OK]    $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  [FAIL]  $1"; }
fixed() { FIXED=$((FIXED + 1)); echo "  [FIXED] $1"; }

echo "=========================================="
echo "  Ralph Global Infrastructure Validator"
echo "  v3.1.0 — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=========================================="

# === 1. RULES (must be symlinks to repo) ===
echo ""
echo "=== Rules (symlinks to repo) ==="
RULES=(aristotle-methodology.md ast-grep-usage.md browser-automation.md parallel-first.md plan-immutability.md zai-mcp-usage.md)
for rule in "${RULES[@]}"; do
  if [[ -L ~/.claude/rules/"$rule" ]]; then
    target=$(readlink ~/.claude/rules/"$rule")
    if [[ "$target" == *"multi-agent-ralph-loop"* ]]; then
      pass "$rule → symlink to repo"
    else
      fail "$rule → symlink but wrong target: $target"
    fi
  elif [[ -f ~/.claude/rules/"$rule" ]]; then
    if [[ "$FIX_MODE" == "--fix" ]]; then
      ln -sfn "$REPO/.claude/rules/$rule" ~/.claude/rules/"$rule"
      fixed "$rule → converted copy to symlink"
    else
      fail "$rule is a copy (not symlink). Run with --fix"
    fi
  else
    if [[ "$FIX_MODE" == "--fix" ]]; then
      ln -sfn "$REPO/.claude/rules/$rule" ~/.claude/rules/"$rule"
      fixed "$rule → created symlink"
    else
      fail "$rule missing from ~/.claude/rules/"
    fi
  fi
done

# === 2. KEY SKILLS (must be symlinked in 6 directories) ===
echo ""
echo "=== Key Skills (global symlinks) ==="
SKILLS=(orchestrator iterate clarify adversarial autoresearch plan gates security parallel)
SKILL_DIRS=(~/.claude/skills ~/.codex/skills ~/.ralph/skills ~/.config/agents/skills)
for skill in "${SKILLS[@]}"; do
  if [[ -L ~/.claude/skills/"$skill" ]]; then
    pass "$skill → ~/.claude/skills/"
  elif [[ "$FIX_MODE" == "--fix" ]]; then
    for dir in "${SKILL_DIRS[@]}"; do
      mkdir -p "$dir"
      ln -sfn "$REPO/.claude/skills/$skill" "$dir/$skill"
    done
    fixed "$skill → symlinked to all directories"
  else
    fail "$skill missing from ~/.claude/skills/"
  fi
done

# === 3. KEY AGENTS (must be symlinks) ===
echo ""
echo "=== Key Agents (global symlinks) ==="
AGENTS=(orchestrator ralph-coder ralph-reviewer ralph-tester ralph-researcher ralph-frontend ralph-security autoresearch)
for agent in "${AGENTS[@]}"; do
  if [[ -L ~/.claude/agents/"$agent".md ]]; then
    pass "$agent.md → symlink"
  elif [[ -f ~/.claude/agents/"$agent".md ]]; then
    if [[ "$FIX_MODE" == "--fix" ]]; then
      ln -sfn "$REPO/.claude/agents/$agent.md" ~/.claude/agents/"$agent.md"
      fixed "$agent.md → converted copy to symlink"
    else
      fail "$agent.md is a copy (not symlink). Run with --fix"
    fi
  else
    if [[ "$FIX_MODE" == "--fix" ]]; then
      ln -sfn "$REPO/.claude/agents/$agent.md" ~/.claude/agents/"$agent.md"
      fixed "$agent.md → created symlink"
    else
      fail "$agent.md missing from ~/.claude/agents/"
    fi
  fi
done

# === 4. INFRASTRUCTURE DIRECTORIES ===
echo ""
echo "=== Infrastructure Directories ==="
DIRS=(~/.ralph/plans ~/.ralph/handoffs ~/.ralph/ledgers ~/.ralph/logs)
for dir in "${DIRS[@]}"; do
  if [[ -d "$dir" ]]; then
    pass "$dir exists"
  elif [[ "$FIX_MODE" == "--fix" ]]; then
    mkdir -p "$dir"
    fixed "$dir created"
  else
    fail "$dir missing"
  fi
done

# === 5. SETTINGS.JSON ===
echo ""
echo "=== Settings Configuration ==="
SETTINGS=~/.claude/settings.json
if [[ -f "$SETTINGS" ]]; then
  grep -q "plansDirectory" "$SETTINGS" && pass "plansDirectory in settings.json" || fail "plansDirectory missing from settings.json"
  grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$SETTINGS" && pass "Agent Teams env var in settings" || fail "Agent Teams env var missing"
else
  fail "~/.claude/settings.json not found"
fi

# === 6. CLAUDE.md GLOBAL ===
echo ""
echo "=== Global CLAUDE.md ==="
GLOBAL_MD=~/.claude/CLAUDE.md
if [[ -f "$GLOBAL_MD" ]]; then
  grep -q "Plan Mode" "$GLOBAL_MD" && pass "Plan Mode instructions in CLAUDE.md" || fail "Plan Mode instructions missing from CLAUDE.md"
  grep -q "Aristotle" "$GLOBAL_MD" && pass "Aristotle methodology referenced" || fail "Aristotle methodology missing from CLAUDE.md"
  grep -q "Parallel-First" "$GLOBAL_MD" && pass "Parallel-First rule referenced" || fail "Parallel-First rule missing from CLAUDE.md"
  grep -q "plan-immutability" "$GLOBAL_MD" && pass "Plan immutability referenced" || fail "Plan immutability missing from CLAUDE.md"
else
  fail "~/.claude/CLAUDE.md not found"
fi

# === RESULTS ===
echo ""
echo "=========================================="
TOTAL=$((PASS + FAIL))
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed, $FIXED fixed"
if [[ "$FAIL" -gt 0 && "$FIX_MODE" != "--fix" ]]; then
  echo "  Run with --fix to auto-repair: bash scripts/validate-global-infrastructure.sh --fix"
fi
echo "=========================================="

[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
