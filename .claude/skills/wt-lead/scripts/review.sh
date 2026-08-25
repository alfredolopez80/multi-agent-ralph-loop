#!/usr/bin/env bash
# review.sh <branch> [allowed-paths-csv] — summarize a worker branch against main.
set -euo pipefail

BRANCH="${1:?usage: review.sh <branch> [allowed-paths-csv]}"
ALLOWED="${2:-}"
MAIN="${QTEAM_MAIN_BRANCH:-main}"

git rev-parse --verify -q "$BRANCH" >/dev/null || { echo "ERROR: branch $BRANCH not found"; exit 1; }

AHEAD="$(git rev-list --count "$MAIN".."$BRANCH")"
BEHIND="$(git rev-list --count "$BRANCH".."$MAIN")"
echo "== $BRANCH: +$AHEAD ahead / -$BEHIND behind $MAIN"
[[ "$BEHIND" -gt 0 ]] && echo "   NOTE: behind $MAIN — consider sending REBASE before integrating."

echo
echo "== commits"
git log --oneline "$MAIN".."$BRANCH"

echo
echo "== files"
git diff --stat "$MAIN"..."$BRANCH"

if [[ -n "$ALLOWED" ]]; then
  echo
  echo "== allowed-paths check"
  IFS=',' read -r -a PATHS <<< "$ALLOWED"
  VIOL=0
  while IFS= read -r f; do
    ok=0
    for p in "${PATHS[@]}"; do
      p="$(echo "$p" | xargs)"   # trim
      [[ "$f" == "$p" || "$f" == "$p"/* ]] && ok=1 && break
    done
    if [[ $ok -eq 0 ]]; then echo "   OUTSIDE: $f"; VIOL=1; fi
  done < <(git diff --name-only "$MAIN"..."$BRANCH")
  [[ $VIOL -eq 0 ]] && echo "   OK: all changed files inside allowed paths"
fi

echo
echo "Full diff: git diff $MAIN...$BRANCH"
