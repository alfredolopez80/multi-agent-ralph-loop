#!/usr/bin/env bash
# finish.sh <task-id> [test-summary] — verify clean tree and print DONE message.
set -euo pipefail

TASK="${1:?usage: finish.sh <task-id> [test-summary]}"
TESTS="${2:-not run}"

TOP="$(git rev-parse --show-toplevel)"
case "$TOP" in
  */.claude/worktrees/*) ;;
  *) echo "ERROR: not inside a Claude Code worktree"; exit 1 ;;
esac

if [[ -n "$(git status --porcelain)" ]]; then
  echo "ERROR: uncommitted changes. Commit or discard first."
  git status --short; exit 1
fi

NAME="$(basename "$TOP")"
BRANCH="$(git branch --show-current)"
MAIN="${QTEAM_MAIN_BRANCH:-main}"
SHA="$(git rev-parse --short HEAD)"
BASE="$(git merge-base "$MAIN" HEAD)"
FILES="$(git diff --name-only "$BASE" HEAD | tr '\n' ' ')"
AHEAD="$(git rev-list --count "$MAIN"..HEAD)"
BEHIND="$(git rev-list --count HEAD.."$MAIN")"

[[ "$BEHIND" -gt 0 ]] && echo "WARNING: branch is $BEHIND commit(s) behind $MAIN. Consider 'git rebase $MAIN'." >&2

cat << MSG
DONE $TASK
branch: $BRANCH   hash: $SHA   (+$AHEAD commits vs $MAIN)
files: ${FILES:-<none>}
tests: $TESTS
notes:
MSG
