#!/usr/bin/env bash
# install-claude-native-agents.sh
#
# Distribute the Claude-native (Codex-free) review / bug-hunting agents and skills as
# self-contained COPIES in ~/.claude, NOT symlinks.
#
# Why COPY for this specific set (an exception to the "agents are symlinked" default in
# docs/architecture/DISTRIBUTION_POLICY.md):
#   The symlinked agents resolve through the repo checkout. When that checkout is behind the
#   merged main (or moved), the symlink silently serves STALE content — which for these files
#   means the OLD Codex-dependent version could come back to life. These agents/skills are
#   correctness-critical: they must ALWAYS be the Claude-native version regardless of repo
#   state. A copy guarantees that; the --check parity mode below makes copy-drift loud instead
#   of silent (the same discipline as install-k8s-context-guard.sh).
#
# Usage:
#   bash scripts/install-claude-native-agents.sh          # install/refresh the copies
#   bash scripts/install-claude-native-agents.sh --check  # verify copies match the repo (CI/local drift gate)

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST_AGENTS="$HOME/.claude/agents"
DEST_SKILLS="$HOME/.claude/skills"

# The Codex->Claude conversion set (PR #31). The 7 fully-converted agents, the 3 Codex-optional
# agents (Claude fallback), and the 2 converted skills.
AGENTS=(debugger refactorer docs-writer test-architect frontend-reviewer security-auditor \
        ralph-security orchestrator codex-reviewer adversarial-plan-validator)
SKILLS=(bugs security)

CHECK=0
[[ "${1:-}" == "--check" ]] && CHECK=1

total=0; copied=0; drift=0; missing=0

sync_file() {  # sync_file <src> <dest>
  local src="$1" dest="$2"
  total=$((total + 1))
  if [[ ! -f "$src" ]]; then
    echo "  MISSING SOURCE  $src"; missing=$((missing + 1)); return
  fi
  if [[ -f "$dest" && ! -L "$dest" ]] && cmp -s "$src" "$dest"; then
    [[ $CHECK -eq 1 ]] && echo "  OK      $dest"
    return
  fi
  if [[ $CHECK -eq 1 ]]; then
    local why="stale copy"; [[ -L "$dest" ]] && why="still a SYMLINK"; [[ ! -e "$dest" ]] && why="absent"
    echo "  DRIFT   $dest ($why)"; drift=$((drift + 1)); return
  fi
  mkdir -p "$(dirname "$dest")"
  rm -f "$dest"                       # replace a symlink or a stale copy with a fresh one
  cp "$src" "$dest"
  echo "  COPIED  $dest"; copied=$((copied + 1))
}

for a in "${AGENTS[@]}"; do
  sync_file "$REPO_ROOT/.claude/agents/$a.md" "$DEST_AGENTS/$a.md"
done
for s in "${SKILLS[@]}"; do
  sync_file "$REPO_ROOT/.claude/skills/$s/SKILL.md" "$DEST_SKILLS/$s/SKILL.md"
done

# Zero-work guard: a run that synced/checked nothing must never report success.
if [[ $total -eq 0 ]]; then
  echo "FATAL: no files in the sync set — refusing to report success over an empty run" >&2
  exit 2
fi

if [[ $CHECK -eq 1 ]]; then
  if [[ $drift -eq 0 && $missing -eq 0 ]]; then
    echo "Parity OK — $total copies match the repo."
    exit 0
  fi
  echo "Parity FAILED — $drift drifted, $missing missing of $total. Fix: bash scripts/install-claude-native-agents.sh" >&2
  exit 1
fi

echo "Done. $copied copied, $missing missing source, of $total."
[[ $missing -gt 0 ]] && exit 1
exit 0
