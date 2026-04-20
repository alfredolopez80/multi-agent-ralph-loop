#!/usr/bin/env bash
# worktree-utils.sh v2.95.0 - Worktree-safe path resolution
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
#   getOrCreateWorktree <slug> - Create or reuse a git worktree
#   setupWorktreeEnv <slug> - Symlink deps + copy config into worktree
#   removeWorktree <slug> - Force-remove a worktree and its branch

get_project_root() {
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -d "${CLAUDE_PROJECT_DIR}" ]]; then echo "$CLAUDE_PROJECT_DIR"
  elif [[ -d "${PWD:-}" ]]; then git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"
  else echo "${CLAUDE_PROJECT_DIR:-.}"
  fi
}

get_main_repo() {
  # Fast path: CLAUDE_PROJECT_DIR is always the main repo root (set by Claude Code)
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -d "${CLAUDE_PROJECT_DIR}" ]]; then echo "$CLAUDE_PROJECT_DIR"; return; fi
  # Guard: if CWD doesn't exist (deleted worktree), git commands will fail
  if [[ ! -d "${PWD:-}" ]]; then echo "${CLAUDE_PROJECT_DIR:-.}"; return; fi
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

# get_safe_project_root — like get_project_root, but refuses paths that
# live *inside* a .claude/ tree (e.g., CWD=.claude/skills/X). Prevents
# hooks from materializing nested .claude/{progress.md,plan-state.json,
# agents/,hooks/} inside skill or subcomponent directories.
get_safe_project_root() {
  local root
  root="$(get_project_root)"
  # Strip at the first /.claude/ segment so a CWD like
  # /repo/.claude/skills/foo returns /repo.
  if [[ "$root" == *"/.claude/"* ]]; then
    root="${root%%/.claude/*}"
  fi
  echo "$root"
}

is_worktree() {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
  [[ -f "$toplevel/.git" ]]
}

resolve_claude_path() {
  echo "$(get_claude_dir)/$1"
}

# getOrCreateWorktree <slug> — Create or reuse a git worktree.
#
# Slug validation: ^[a-zA-Z0-9_-]{1,64}$
# Creates branch: worktree-<slug>
# Worktree location: <main-repo>/.claude/worktrees/<slug>
#
# Returns JSON on stdout: {"path": "...", "branch": "...", "headCommit": "..."}
# Returns JSON with "error" field on failure.
#
# SECURITY: umask 077 before calling. Uses git fetch (no-prompt).
getOrCreateWorktree() {
  local slug="$1"

  # --- Validate slug ---
  if [[ ! "$slug" =~ ^[a-zA-Z0-9_-]{1,64}$ ]]; then
    echo "{\"error\": \"invalid slug: '$slug'. Must match ^[a-zA-Z0-9_-]{1,64}$\"}"
    return 1
  fi

  local main_repo
  main_repo="$(get_main_repo)"
  if [[ -z "$main_repo" || "$main_repo" == "." ]]; then
    echo "{\"error\": \"cannot determine main repo\"}"
    return 1
  fi

  local wt_dir="$main_repo/.claude/worktrees/$slug"
  local branch="worktree-$slug"

  # --- Reuse existing worktree ---
  if [[ -d "$wt_dir" ]]; then
    local head
    head="$(cd "$wt_dir" && git rev-parse HEAD 2>/dev/null || echo "unknown")"
    echo "{\"path\": \"$wt_dir\", \"branch\": \"$branch\", \"headCommit\": \"$head\", \"reused\": true}"
    return 0
  fi

  # --- Create new worktree ---
  # Fetch latest (no interactive prompts)
  (cd "$main_repo" && git fetch --quiet --no-tags 2>/dev/null || true)

  # Ensure worktrees directory exists
  mkdir -p "$main_repo/.claude/worktrees"

  # Create worktree with new branch from HEAD
  local head
  head="$(cd "$main_repo" && git rev-parse HEAD 2>/dev/null || echo "unknown")"

  if (cd "$main_repo" && git worktree add -b "$branch" "$wt_dir" HEAD >/dev/null 2>&1); then
    echo "{\"path\": \"$wt_dir\", \"branch\": \"$branch\", \"headCommit\": \"$head\", \"reused\": false}"
    return 0
  else
    # Branch might already exist — try with existing branch
    if (cd "$main_repo" && git worktree add "$wt_dir" "$branch" >/dev/null 2>&1); then
      echo "{\"path\": \"$wt_dir\", \"branch\": \"$branch\", \"headCommit\": \"$head\", \"reused\": false, \"existing_branch\": true}"
      return 0
    fi
    echo "{\"error\": \"failed to create worktree for '$slug'\", \"path\": \"$wt_dir\", \"branch\": \"$branch\"}"
    return 1
  fi
}

# setupWorktreeEnv <slug> — Set up worktree environment for agent work.
#
# Symlinks heavy directories (node_modules, .cache, .venv) from main repo
# and copies config files (CLAUDE.md, .env.local) into the worktree.
#
# Returns JSON: {"path": "...", "symlinks": [...], "copies": [...], "errors": [...]}
setupWorktreeEnv() {
  local slug="$1"
  local main_repo
  main_repo="$(get_main_repo)"
  local wt_dir="$main_repo/.claude/worktrees/$slug"

  if [[ ! -d "$wt_dir" ]]; then
    echo "{\"error\": \"worktree '$slug' does not exist\", \"path\": \"$wt_dir\"}"
    return 1
  fi

  local symlinks=()
  local copies=()
  local errors=()

  # Directories to symlink (heavy, read-only from agent perspective)
  local link_dirs=("node_modules" ".cache" ".venv" "__pycache__")
  for dir in "${link_dirs[@]}"; do
    if [[ -d "$main_repo/$dir" && ! -e "$wt_dir/$dir" ]]; then
      if ln -s "$main_repo/$dir" "$wt_dir/$dir" 2>/dev/null; then
        symlinks+=("\"$dir\"")
      else
        errors+=("\"$dir: symlink failed\"")
      fi
    fi
  done

  # Config files to copy (agent may modify these)
  local copy_files=("CLAUDE.md" ".env.local" "tsconfig.json" "pyproject.toml")
  for file in "${copy_files[@]}"; do
    if [[ -f "$main_repo/$file" && ! -e "$wt_dir/$file" ]]; then
      if cp -p "$main_repo/$file" "$wt_dir/$file" 2>/dev/null; then
        copies+=("\"$file\"")
      else
        errors+=("\"$file: copy failed\"")
      fi
    fi
  done

  # Build JSON arrays
  local symlinks_json copies_json errors_json
  symlinks_json=$(IFS=,; echo "[${symlinks[*]}]")
  copies_json=$(IFS=,; echo "[${copies[*]}]")
  errors_json=$(IFS=,; echo "[${errors[*]}]")

  echo "{\"path\": \"$wt_dir\", \"symlinks\": $symlinks_json, \"copies\": $copies_json, \"errors\": $errors_json}"
  return 0
}

# checkWorktreeTTL <slug> [ttl_minutes] — Check if worktree exceeded TTL.
#
# Default TTL: 30 minutes.
# Returns JSON: {"slug": "...", "ttl_minutes": N, "elapsed_minutes": N, "expired": bool}
# If worktree not found, returns error JSON.
checkWorktreeTTL() {
  local slug="$1"
  local ttl_minutes="${2:-30}"
  local main_repo
  main_repo="$(get_main_repo)"
  local wt_dir="$main_repo/.claude/worktrees/$slug"

  if [[ ! -d "$wt_dir" ]]; then
    echo "{\"error\": \"worktree not found\", \"slug\": \"$slug\"}"
    return 1
  fi

  # Get creation time from worktree directory metadata
  local created_epoch
  created_epoch=$(stat -f "%B" "$wt_dir" 2>/dev/null || stat -c "%W" "$wt_dir" 2>/dev/null || echo "0")
  local now_epoch
  now_epoch=$(date +%s)
  local elapsed_minutes=$(( (now_epoch - created_epoch) / 60 ))
  local expired="false"

  if [[ "$elapsed_minutes" -ge "$ttl_minutes" ]]; then
    expired="true"
  fi

  echo "{\"slug\": \"$slug\", \"ttl_minutes\": $ttl_minutes, \"elapsed_minutes\": $elapsed_minutes, \"expired\": $expired}"
}

# retrySpawn <command...> — Retry a spawn command up to 3x with exponential backoff.
#
# Usage: retrySpawn <command> [args...]
# Backoff: 2s, 4s, 8s
# Returns the exit code of the last attempt.
# Logs each attempt to stderr.
retrySpawn() {
  local max_retries=3
  local attempt=1
  local last_exit=0

  while [[ $attempt -le $max_retries ]]; do
    # Run the command
    "$@" && return 0
    last_exit=$?

    if [[ $attempt -lt $max_retries ]]; then
      local backoff=$(( 2 ** attempt ))
      echo "[retrySpawn] Attempt $attempt/$max_retries failed (exit=$last_exit). Retrying in ${backoff}s..." >&2
      sleep "$backoff"
    else
      echo "[retrySpawn] All $max_retries attempts failed. Escalating." >&2
    fi
    ((attempt++)) || true
  done

  return $last_exit
}

# removeWorktree <slug> — Force-remove a worktree and its branch.
#
# Returns 0 on success, 1 on failure.
removeWorktree() {
  local slug="$1"
  local main_repo
  main_repo="$(get_main_repo)"
  local wt_dir="$main_repo/.claude/worktrees/$slug"
  local branch="worktree-$slug"

  # Remove worktree
  if [[ -d "$wt_dir" ]]; then
    (cd "$main_repo" && git worktree remove --force "$wt_dir" 2>/dev/null) || {
      # Fallback: manual cleanup
      rm -rf "$wt_dir" 2>/dev/null || true
      (cd "$main_repo" && git worktree prune 2>/dev/null || true)
    }
  fi

  # Delete branch
  (cd "$main_repo" && git branch -D "$branch" 2>/dev/null || true)

  return 0
}
