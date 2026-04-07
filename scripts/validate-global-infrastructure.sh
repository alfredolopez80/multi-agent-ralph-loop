#!/usr/bin/env bash
# validate-global-infrastructure.sh — Validates that all Ralph infrastructure
# is correctly distributed globally for use in any project.
# VERSION: 3.2.0
# CHANGELOG v3.2.0:
# - Rules now use COPY strategy (standalone files, not symlinks) per W5.1
# - Added content checksum validation for rule copies
# - Skills/Agents remain symlinks (repo-dependent)
# - Added universal hooks validation
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
echo "  v3.2.0 — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "=========================================="

# === 1. RULES (standalone copies — W5.1 copy strategy) ===
echo ""
echo "=== Rules (standalone copies with checksum validation) ==="
RULES=(aristotle-methodology.md ast-grep-usage.md browser-automation.md parallel-first.md plan-immutability.md zai-mcp-usage.md)
for rule in "${RULES[@]}"; do
  GLOBAL_FILE=~/.claude/rules/"$rule"
  REPO_FILE="$REPO/.claude/rules/$rule"

  if [[ ! -f "$GLOBAL_FILE" ]]; then
    if [[ "$FIX_MODE" == "--fix" ]] && [[ -f "$REPO_FILE" ]]; then
      cp "$REPO_FILE" "$GLOBAL_FILE"
      fixed "$rule → created from repo"
    else
      fail "$rule missing from ~/.claude/rules/"
    fi
    continue
  fi

  # File exists — validate content matches repo
  if [[ -f "$REPO_FILE" ]]; then
    GLOBAL_SHA=$(shasum -a 256 "$GLOBAL_FILE" | cut -d' ' -f1)
    REPO_SHA=$(shasum -a 256 "$REPO_FILE" | cut -d' ' -f1)
    if [[ "$GLOBAL_SHA" == "$REPO_SHA" ]]; then
      pass "$rule → copy in sync"
    else
      if [[ "$FIX_MODE" == "--fix" ]]; then
        cp "$REPO_FILE" "$GLOBAL_FILE"
        fixed "$rule → updated from repo (content drift)"
      else
        fail "$rule → content drift (run with --fix to sync)"
      fi
    fi
  else
    pass "$rule → standalone (no repo source to compare)"
  fi
done

# === 2. UNIVERSAL HOOKS (standalone copies — W5.2) ===
echo ""
echo "=== Universal Hooks (standalone copies, registered in settings.json) ==="
UNIVERSAL_HOOKS=(universal-prompt-classifier.sh universal-aristotle-gate.sh universal-step-tracker.sh)
for hook in "${UNIVERSAL_HOOKS[@]}"; do
  GLOBAL_HOOK=~/.claude/hooks/"$hook"
  REPO_HOOK="$REPO/.claude/hooks/$hook"

  # Check file exists in global
  if [[ ! -f "$GLOBAL_HOOK" ]]; then
    if [[ "$FIX_MODE" == "--fix" ]] && [[ -f "$REPO_HOOK" ]]; then
      cp "$REPO_HOOK" "$GLOBAL_HOOK" && chmod +x "$GLOBAL_HOOK"
      fixed "$hook → created from repo"
    else
      fail "$hook missing from ~/.claude/hooks/"
    fi
    continue
  fi

  # Check executable
  if [[ ! -x "$GLOBAL_HOOK" ]]; then
    if [[ "$FIX_MODE" == "--fix" ]]; then
      chmod +x "$GLOBAL_HOOK"
      fixed "$hook → made executable"
    else
      fail "$hook not executable"
    fi
    continue
  fi

  # Check registered in settings.json
  if grep -q "$hook" ~/.claude/settings.json 2>/dev/null; then
    # Check content matches if repo source exists
    if [[ -f "$REPO_HOOK" ]]; then
      GLOBAL_SHA=$(shasum -a 256 "$GLOBAL_HOOK" | cut -d' ' -f1)
      REPO_SHA=$(shasum -a 256 "$REPO_HOOK" | cut -d' ' -f1)
      if [[ "$GLOBAL_SHA" == "$REPO_SHA" ]]; then
        pass "$hook → copy in sync + registered"
      else
        if [[ "$FIX_MODE" == "--fix" ]]; then
          cp "$REPO_HOOK" "$GLOBAL_HOOK" && chmod +x "$GLOBAL_HOOK"
          fixed "$hook → updated from repo (content drift)"
        else
          fail "$hook → content drift (run with --fix)"
        fi
      fi
    else
      pass "$hook → standalone + registered"
    fi
  else
    fail "$hook exists but NOT registered in settings.json"
  fi
done

# === 3. KEY SKILLS (standalone copies or symlinks — W5.4 copy strategy) ===
echo ""
echo "=== Key Skills (standalone copies or symlinks) ==="
SKILLS=(orchestrator iterate clarify adversarial autoresearch plan gates security parallel)
for skill in "${SKILLS[@]}"; do
  SKILL_PATH=~/.claude/skills/"$skill"
  REPO_SKILL="$REPO/.claude/skills/$skill"
  if [[ -L "$SKILL_PATH" ]]; then
    # Symlink — verify target exists
    TARGET=$(readlink "$SKILL_PATH")
    if [[ -e "$SKILL_PATH" ]]; then
      pass "$skill → symlink (valid)"
    else
      if [[ "$FIX_MODE" == "--fix" ]] && [[ -d "$REPO_SKILL" ]]; then
        rm -f "$SKILL_PATH"
        cp -R "$REPO_SKILL" "$SKILL_PATH"
        fixed "$skill → broken symlink replaced with copy"
      else
        fail "$skill → broken symlink (target missing)"
      fi
    fi
  elif [[ -d "$SKILL_PATH" ]]; then
    # Standalone copy — verify SKILL.md exists inside
    if [[ -f "$SKILL_PATH/SKILL.md" ]]; then
      pass "$skill → standalone copy"
    else
      fail "$skill → directory exists but no SKILL.md"
    fi
  elif [[ "$FIX_MODE" == "--fix" ]] && [[ -d "$REPO_SKILL" ]]; then
    cp -R "$REPO_SKILL" "$SKILL_PATH"
    fixed "$skill → created from repo"
  else
    fail "$skill missing from ~/.claude/skills/"
  fi
done

# === 4. KEY AGENTS (must be symlinks) ===
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

# === 5. INFRASTRUCTURE DIRECTORIES ===
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

# === 6. SETTINGS.JSON ===
echo ""
echo "=== Settings Configuration ==="
SETTINGS=~/.claude/settings.json
if [[ -f "$SETTINGS" ]]; then
  grep -q "plansDirectory" "$SETTINGS" && pass "plansDirectory in settings.json" || fail "plansDirectory missing from settings.json"
  grep -q "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" "$SETTINGS" && pass "Agent Teams env var in settings" || fail "Agent Teams env var missing"
else
  fail "~/.claude/settings.json not found"
fi

# === 7. CLAUDE.md GLOBAL ===
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
