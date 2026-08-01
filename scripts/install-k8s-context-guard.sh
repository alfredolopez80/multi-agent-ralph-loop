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
# Discovered by glob, never version-pinned: a hardcoded `k8s/0.1.3/...` silently stops
# matching the moment the plugin updates, and the script would report "0 reinstalled,
# 1 absent" and exit 0 while the vulnerable guard stays active under the new version.
TARGETS=()
while IFS= read -r found; do
  TARGETS+=("$found")
done < <(
  find "$HOME/.claude/plugins" -type f -path "*sagart-devtools*" -name "context-guard.sh" 2>/dev/null | sort
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
failed=0

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
  # Check the copy. Previously `cp ... && chmod ...` only guarded the chmod: on a failed
  # copy the script still printed "FIXED reinstalled", counted it, and exited 0 — leaving
  # the vulnerable guard in place while claiming to have replaced it.
  if ! cp "$SOURCE" "$target" 2>/dev/null || ! chmod +x "$target" 2>/dev/null; then
    echo "  ERROR  could not install into: ${target/$HOME/\~}" >&2
    failed=$((failed + 1))
    continue
  fi
  echo "  FIXED  reinstalled: ${target/$HOME/\~}"
  installed=$((installed + 1))
done

# Zero targets found is not a success: the plugin layout changed, or it is not installed.
if [[ "${#TARGETS[@]}" -eq 0 ]]; then
  echo "FATAL: no sagart-devtools context-guard.sh found under ~/.claude/plugins." >&2
  exit 1
fi

if [[ "$failed" -gt 0 ]]; then
  echo "FATAL: $failed cop(y/ies) could not be installed — the vulnerable guard is still active." >&2
  exit 1
fi

if [[ "$MODE" == "--check" && "$drifted" -gt 0 ]]; then
  echo "FATAL: $drifted copy/copies drifted. Run without --check to reinstall." >&2
  exit 1
fi

echo "Done. ${installed} reinstalled, ${missing} absent."
