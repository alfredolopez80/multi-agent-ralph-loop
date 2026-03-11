#!/usr/bin/env bash
# worktree-utils.sh v2.94.0 - Worktree-safe path resolution
# Shared library for all hooks to resolve paths correctly
# whether running in the main repo or a git worktree.
#
# Usage:
#   source "${_HOOK_DIR}/lib/worktree-utils.sh"
#
# Functions:
#   get_project_root  - Current working tree root (worktree or main)
#   get_main_repo     - Always the main repository root
#   get_claude_dir    - Path to .claude/ in the main repo
#   is_worktree       - Returns 0 if in a worktree, 1 otherwise
#   resolve_claude_path <relative> - Full path to a file under .claude/

get_project_root() {
  git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"
}

get_main_repo() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
  if [[ -f "$toplevel/.git" ]]; then
    # Worktree: .git file contains "gitdir: <main>/.git/worktrees/<name>"
    local gitdir
    gitdir="$(sed 's/gitdir: //' "$toplevel/.git" | tr -d '[:space:]')"
    # Resolve to absolute path, then navigate up from .git/worktrees/<name>
    local abs_gitdir
    abs_gitdir="$(cd "$toplevel" && cd "$(dirname "$gitdir")" && pwd)/$(basename "$gitdir")"
    # .git/worktrees/<name> -> go up 3 levels to reach main repo
    dirname "$(dirname "$(dirname "$abs_gitdir")")"
  else
    echo "$toplevel"
  fi
}

get_claude_dir() {
  echo "$(get_main_repo)/.claude"
}

is_worktree() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
  [[ -f "$toplevel/.git" ]]
}

resolve_claude_path() {
  echo "$(get_claude_dir)/$1"
}
