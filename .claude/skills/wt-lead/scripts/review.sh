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
# Deliberately NOT advising a REBASE here. Being behind main is the normal
# state after every integration, and a --no-ff merge resolves it without the
# worker touching anything. The old note sent workers into `git rebase main`,
# which git-safety-guard denied — ×16 blocks in one day and the reason two
# workers independently improvised a way around the guard.
[[ "$BEHIND" -gt 0 ]] && echo "   (behind $MAIN — normal; the merge handles it)"

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
      while [[ "$p" == */ ]]; do p="${p%/}"; done   # `strategies/` is the documented form
      [[ "$f" == "$p" || "$f" == "$p"/* ]] && ok=1 && break
    done
    if [[ $ok -eq 0 ]]; then echo "   OUTSIDE: $f"; VIOL=1; fi
    # --no-renames is load-bearing: with detection on (git's default) a rename collapses
    # to the destination alone, so moving outside/secrets.env into an allowed directory
    # deletes an out-of-scope file and this check still prints OK. Both endpoints must
    # be seen for the scope guarantee to mean anything. The --stat display above keeps
    # rename detection, where it is a readability win rather than a hole.
  done < <(git diff --no-renames --name-only "$MAIN"..."$BRANCH")
  [[ $VIOL -eq 0 ]] && echo "   OK: all changed files inside allowed paths"
fi

echo
echo "Full diff: git diff $MAIN...$BRANCH"
