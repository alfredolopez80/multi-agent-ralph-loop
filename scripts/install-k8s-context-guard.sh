#!/usr/bin/env bash
# install-k8s-context-guard.sh — reinstall the corrected k8s context guard.
#
# The guard ships inside the sagart-devtools/k8s plugin, which registers it as a
# PreToolUse hook by itself: it is NOT listed in ~/.claude/settings.json, so there is no
# way to override it from there — an extra entry would run IN ADDITION to the plugin's
# copy, not instead of it. Updating the plugin therefore restores the original file.
#
# The corrected guard is versioned at .claude/hooks/k8s-context-guard.sh. Run this after
# any plugin update to put it back.
#
# Usage:
#   scripts/install-k8s-context-guard.sh            # install
#   scripts/install-k8s-context-guard.sh --check    # report drift, change nothing
set -uo pipefail
umask 077

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
# The canonical guard lives in the SAME tree as this script — resolving to the main repo
# would miss it while the change is still on a worktree branch.
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE="$REPO_ROOT/.claude/hooks/k8s-context-guard.sh"
TARGETS=(
  "$HOME/.claude/plugins/cache/sagart-devtools/k8s/0.1.3/scripts/context-guard.sh"
  "$HOME/.claude/plugins/marketplaces/sagart-devtools/scripts/context-guard.sh"
)

MODE="${1:---install}"
case "$MODE" in
  --install|--check) ;;
  *) echo "FATAL: unknown argument: $MODE. Usage: $(basename "$0") [--install|--check]" >&2; exit 1 ;;
esac

[[ -f "$SOURCE" ]] || { echo "FATAL: canonical guard not found: $SOURCE" >&2; exit 1; }

installed=0
drifted=0
missing=0

for target in "${TARGETS[@]}"; do
  if [[ ! -f "$target" ]]; then
    echo "  SKIP   not installed: ${target/$HOME/\~}"
    missing=$((missing + 1))
    continue
  fi
  if cmp -s "$SOURCE" "$target"; then
    echo "  OK     already current: ${target/$HOME/\~}"
    continue
  fi
  drifted=$((drifted + 1))
  if [[ "$MODE" == "--check" ]]; then
    echo "  DRIFT  differs from the versioned guard: ${target/$HOME/\~}"
    continue
  fi
  cp "$SOURCE" "$target" && chmod +x "$target"
  echo "  FIXED  reinstalled: ${target/$HOME/\~}"
  installed=$((installed + 1))
done

# Zero targets examined is not a success: it means the plugin layout changed.
if [[ "$missing" -eq "${#TARGETS[@]}" ]]; then
  echo "FATAL: none of the expected guard paths exist — the plugin layout changed." >&2
  exit 1
fi

if [[ "$MODE" == "--check" && "$drifted" -gt 0 ]]; then
  echo "FATAL: $drifted copy/copies drifted. Run without --check to reinstall." >&2
  exit 1
fi

echo "Done. ${installed} reinstalled, ${missing} absent."
