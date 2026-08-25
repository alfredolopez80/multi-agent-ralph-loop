#!/usr/bin/env bash
# integrate.sh <branch> [sha ...] — merge a worker branch into main (or cherry-pick given shas).
set -euo pipefail

BRANCH="${1:?usage: integrate.sh <branch> [sha ...]}"; shift || true
MAIN="${QTEAM_MAIN_BRANCH:-main}"

TOP="$(git rev-parse --show-toplevel)"
case "$TOP" in
  */.claude/worktrees/*) echo "ERROR: run this from the main checkout, not a worktree"; exit 1 ;;
esac

CUR="$(git branch --show-current)"
[[ "$CUR" == "$MAIN" ]] || { echo "ERROR: on $CUR, expected $MAIN"; exit 1; }
[[ -z "$(git status --porcelain)" ]] || { echo "ERROR: $MAIN is dirty. Commit or stash first."; git status --short; exit 1; }
git rev-parse --verify -q "$BRANCH" >/dev/null || { echo "ERROR: branch $BRANCH not found"; exit 1; }

if [[ $# -gt 0 ]]; then
  echo "cherry-picking $* from $BRANCH into $MAIN ..."
  if ! git cherry-pick "$@"; then
    echo "CONFLICT. Aborting cherry-pick."; git diff --name-only --diff-filter=U
    git cherry-pick --abort; exit 2
  fi
else
  echo "merging $BRANCH into $MAIN (--no-ff) ..."
  if ! git merge --no-ff --no-edit "$BRANCH"; then
    echo "CONFLICT in:"; git diff --name-only --diff-filter=U
    git merge --abort
    echo "Aborted. Send REBASE to the worker, then re-review."; exit 2
  fi
fi

if [[ -n "${QTEAM_TEST_CMD:-}" ]]; then
  echo "running tests: $QTEAM_TEST_CMD"
  if ! bash -c "$QTEAM_TEST_CMD"; then
    echo "TESTS FAILED after integration. main now at $(git rev-parse --short HEAD)."
    echo "Fix forward or 'git reset --hard HEAD~1' (merge) / 'git reset --hard HEAD~N' (cherry-picks)."
    exit 3
  fi
fi

echo "OK: $MAIN at $(git rev-parse --short HEAD)"
echo "Reply to worker:  MERGED <task-id> into $MAIN at $(git rev-parse --short HEAD)"
