#!/usr/bin/env bash
# start-task.sh — verify worktree and rebase on main before starting a task.
set -euo pipefail

TOP="$(git rev-parse --show-toplevel)"
case "$TOP" in
  */.claude/worktrees/*) ;;
  *) echo "ERROR: not inside a Claude Code worktree ($TOP)"; exit 1 ;;
esac

NAME="$(basename "$TOP")"
BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "worktree-$NAME" ]]; then
  echo "ERROR: expected branch worktree-$NAME, on $BRANCH"; exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: working tree not clean. Commit or discard before starting."
  git status --short; exit 1
fi

MAIN="${QTEAM_MAIN_BRANCH:-main}"
echo "worker: $NAME   branch: $BRANCH   base: $MAIN"
echo "rebasing on $MAIN ..."
if git rebase "$MAIN"; then
  echo "OK: up to date with $MAIN at $(git rev-parse --short "$MAIN")"
else
  echo "CONFLICT during rebase. Conflicting files:"
  git diff --name-only --diff-filter=U
  echo "If all are inside your allowed paths: resolve, then 'git rebase --continue'."
  echo "Otherwise: 'git rebase --abort' and send BLOCKED to lead."
  exit 2
fi
