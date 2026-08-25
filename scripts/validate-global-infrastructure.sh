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

# La tilde entre comillas NO se expande: `[[ -f "~/..." ]]` siempre era falso y
# los 19 checks de drift caian a la rama "standalone (no repo source to compare)".
# Fail-open en un validador. Derivar de BASH_SOURCE es ademas robusto a renombres.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Emite el contenido de un fichero sin el header de sincronizacion que
# sync-rules-from-source.sh anade a las copias globales. Sin header, emite el
# fichero tal cual.
strip_sync_header() {
  awk '
    NR==1 && /^<!-- SOURCE:/ { in_hdr=1 }
    in_hdr && /-->/          { in_hdr=0; skip_blank=1; next }
    in_hdr                   { next }
    skip_blank && NF==0      { skip_blank=0; next }
    { skip_blank=0; print }
  ' "$1"
}
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
RULES=(aristotle-methodology.md ast-grep-usage.md browser-automation.md native-tools-first.md parallel-first.md plan-immutability.md zai-mcp-usage.md)
for rule in "${RULES[@]}"; do
  GLOBAL_FILE=~/.claude/rules/"$rule"
  # T40: source moved to .claude/rules-src/ (no longer auto-loaded by Claude
  # Code from the repo path — only the sync-script-generated header-stamped
  # copy in ~/.claude/rules/ is loaded). The validator still compares the
  # repo source against the global copy to detect drift.
  REPO_FILE="$REPO/.claude/rules-src/$rule"

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
    # La copia global lleva un header de sincronizacion que el fuente NO tiene
    # por diseno (<!-- SOURCE: ... SYNCED: ... -->). Comparar el fichero entero
    # marcaba las seis reglas como "content drift" para siempre. Se compara el
    # contenido, descartando ese header.
    GLOBAL_SHA=$(strip_sync_header "$GLOBAL_FILE" | shasum -a 256 | cut -d' ' -f1)
    REPO_SHA=$(strip_sync_header "$REPO_FILE" | shasum -a 256 | cut -d' ' -f1)
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
UNIVERSAL_HOOKS=(universal-prompt-classifier.sh universal-aristotle-gate.sh)
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

# === 3b. SKILLS DRIFT vs repo source (T57) ===
# T57: detect when a STANDALONE COPY in ~/.claude/skills/ has drifted
# from the repo source. Symlinks cannot drift (they ARE the source)
# and count as pass; independent copies are diff-compared.
# A symlink that points well is NOT drift — counting it as such would
# be permanent noise.
# T55/T56 finding: 11 of 61 skills had been frozen at 4 distinct
# dates across April-June 2026; zero was content-only-in-global.
# Fail-loud: a zero-scan run reports failure (zero-tests-is-never-success).
# Escape hatch: list names in $REPO/.claude/.skill-drift-ignore
# (one per line, optionally ' | reason'); ignored skills print
# as PASS (ignored) and are excluded from the drift count.
echo ""
echo "=== Skills Drift (repo vs ~/.claude/skills) ==="
DRIFT_SCANNED=0
DRIFT_IGNORE_FILE="$REPO/.claude/.skill-drift-ignore"
DRIFT_IGNORE_NAMES=""
if [[ -f "$DRIFT_IGNORE_FILE" ]]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    DRIFT_IGNORE_NAMES+=" ${line%%|*}"
  done < "$DRIFT_IGNORE_FILE"
fi

for skill_dir in "$REPO/.claude/skills/"*/; do
  [[ ! -d "$skill_dir" ]] && continue
  skill_name=$(basename "$skill_dir")
  [[ "$skill_name" == .* ]] && continue
  [[ ! -f "$skill_dir/SKILL.md" ]] && continue
  if [[ " ${DRIFT_IGNORE_NAMES} " == *" ${skill_name} "* ]]; then
    pass "$skill_name → ignored (escape hatch)"
    continue
  fi
  DRIFT_SCANNED=$((DRIFT_SCANNED + 1))
  global_path="$HOME/.claude/skills/$skill_name"
  global_skill_md="$global_path/SKILL.md"
  if [[ -L "$global_path" ]]; then
    # Symlink at the directory level — cannot drift
    if [[ -e "$global_path" ]]; then
      pass "$skill_name → symlinked (cannot drift)"
    else
      fail "$skill_name → broken symlink"
    fi
  elif [[ -d "$global_path" && -f "$global_skill_md" ]]; then
    # Standalone copy — diff against repo
    if diff -q "$skill_dir/SKILL.md" "$global_skill_md" > /dev/null 2>&1; then
      pass "$skill_name → in sync"
    else
      fail "$skill_name → DRIFT (repo and ~/.claude copy differ)"
    fi
  elif [[ -d "$global_path" ]]; then
    fail "$skill_name → directory exists but no SKILL.md inside"
  else
    fail "$skill_name → missing from ~/.claude/skills/ (repo has it)"
  fi
done

# Fail-loud on zero-scan: if the repo has no skills, the check is meaningless.
# Same principle as testing-zero-tests-is-never-success.
if [[ "$DRIFT_SCANNED" -eq 0 ]]; then
  fail "skills drift scan found 0 skills — validator cannot honestly report success"
fi

# === 4. KEY AGENTS (must be symlinks) ===
# NOTE: the Codex->Claude review/bug agents (orchestrator, ralph-security, and the rest of
# the set) are distributed as COPIES, not symlinks — validated separately in section 4b.
echo ""
echo "=== Key Agents (global symlinks) ==="
AGENTS=(ralph-coder ralph-reviewer ralph-tester ralph-researcher ralph-frontend autoresearch)
for agent in "${AGENTS[@]}"; do
  target=~/.claude/agents/"$agent".md
  if [[ -L "$target" && -f "$target" ]]; then
    pass "$agent.md → symlink (resolves)"
  elif [[ -L "$target" && ! -f "$target" ]]; then
    if [[ "$FIX_MODE" == "--fix" ]]; then
      rm "$target"
      ln -sfn "$REPO/.claude/agents/$agent.md" "$target"
      fixed "$agent.md → replaced broken symlink"
    else
      fail "$agent.md is a BROKEN symlink (target missing). Run with --fix"
    fi
  elif [[ -f "$target" ]]; then
    if [[ "$FIX_MODE" == "--fix" ]]; then
      ln -sfn "$REPO/.claude/agents/$agent.md" "$target"
      fixed "$agent.md → converted copy to symlink"
    else
      fail "$agent.md is a copy (not symlink). Run with --fix"
    fi
  else
    if [[ "$FIX_MODE" == "--fix" ]]; then
      ln -sfn "$REPO/.claude/agents/$agent.md" "$target"
      fixed "$agent.md → created symlink"
    else
      fail "$agent.md missing from ~/.claude/agents/"
    fi
  fi
done

# === 4b. CLAUDE-NATIVE COPY AGENTS/SKILLS (Codex->Claude set, COPY not symlink) ===
# Per docs/architecture/DISTRIBUTION_POLICY.md, the Codex->Claude review/bug agents and the
# bugs/security skills are COPIES so a stale or moved repo checkout can never resurrect their
# old Codex-dependent version. Parity (and --fix re-sync) is delegated to their installer, so
# --fix re-syncs the copies from the repo rather than reverting them to symlinks.
echo ""
echo "=== Claude-native COPY agents/skills (parity) ==="
# Locate the installer relative to THIS script (its sibling in scripts/), not via $REPO —
# $REPO is a quoted "~/..." literal that does not tilde-expand in this context.
_cn_installer="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install-claude-native-agents.sh"
if [[ ! -x "$_cn_installer" && ! -f "$_cn_installer" ]]; then
  fail "missing $_cn_installer — cannot verify the Claude-native copy set"
elif bash "$_cn_installer" --check >/dev/null 2>&1; then
  pass "Claude-native copies match the repo (install-claude-native-agents.sh --check)"
elif [[ "$FIX_MODE" == "--fix" ]]; then
  bash "$_cn_installer" >/dev/null 2>&1
  fixed "Claude-native copies re-synced from repo"
else
  fail "Claude-native copies drifted. Fix: bash scripts/install-claude-native-agents.sh"
fi

# Sweep for ANY broken symlink in ~/.claude/agents (beyond hardcoded list)
echo ""
echo "=== Broken symlink sweep (all of ~/.claude/agents/) ==="
broken_count=0
while IFS= read -r -d '' link; do
  if [[ ! -f "$link" ]]; then
    broken_count=$((broken_count+1))
    if [[ "$FIX_MODE" == "--fix" ]]; then
      rm "$link"
      fixed "removed broken symlink: $(basename "$link")"
    else
      fail "broken symlink: $(basename "$link") -> $(readlink "$link")"
    fi
  fi
done < <(find ~/.claude/agents -maxdepth 1 -type l -print0 2>/dev/null)
[[ $broken_count -eq 0 ]] && pass "no broken symlinks in ~/.claude/agents/"

# === 5. INFRASTRUCTURE DIRECTORIES ===
echo ""
echo "=== Infrastructure Directories ==="
DIRS=(~/.ralph/handoffs ~/.ralph/ledgers ~/.ralph/logs)
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

# Plans are PER-PROJECT, never global. A global ~/.ralph/plans would let one
# project's plans leak into another's context (cross-contamination).
if [[ -d ~/.ralph/plans ]]; then
  fail "~/.ralph/plans exists — plans must be per-project. Move its contents into each project's .ralph/plans/ and remove the global directory."
else
  pass "~/.ralph/plans absent (plans are per-project)"
fi

# === 6. SETTINGS.JSON ===
echo ""
echo "=== Settings Configuration ==="
SETTINGS=~/.claude/settings.json
if [[ -f "$SETTINGS" ]]; then
  # plansDirectory MUST be a relative path so each project resolves its own
  # .ralph/plans/. An absolute path (or ~) points every project at one shared
  # directory and cross-contaminates plans between them.
  PLANS_DIR=$(jq -r '.plansDirectory // empty' "$SETTINGS")
  if [[ -z "$PLANS_DIR" ]]; then
    fail "plansDirectory missing from settings.json"
  elif [[ "$PLANS_DIR" == /* || "$PLANS_DIR" == "~"* ]]; then
    fail "plansDirectory is absolute ('$PLANS_DIR') — must be relative (e.g. '.ralph/plans/') so plans stay per-project"
  else
    pass "plansDirectory is relative ('$PLANS_DIR') — per-project"
  fi
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
