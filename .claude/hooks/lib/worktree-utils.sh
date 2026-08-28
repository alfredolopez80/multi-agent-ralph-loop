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

# WHY GIT COMES FIRST, AND CLAUDE_PROJECT_DIR LAST (v2.96.0)
#
# CLAUDE_PROJECT_DIR is captured once, when the session starts, and never moves again.
# Inside a worktree it points at THAT WORKTREE — not at the main repo, despite what the
# old `get_main_repo` fast-path comment claimed. Both functions used to return it before
# consulting git, so once the CWD moved they answered about a directory nobody was in.
#
# The concrete failure: repo-boundary-guard.sh resolves "the current repo" through
# get_main_repo. With the frozen variable, every sibling worktree of the SAME repository
# — and the parent repository itself — looked external, and legitimate access was denied.
#
# Now each function asks git for exactly what its name promises, which stays correct when
# the CWD changes, and falls back to the frozen variable only when there is no git context
# at all (deleted CWD, or not a repository).

# — Project resolution (T99 r4 consolidation) ---------------------------------
# THE single definition of "which project owns this session". Both gates and
# all writers consume this; a reader/writer split-brain (gate seeing the
# nested plan while a writer mutates the container's) is impossible by
# construction. Resolution, walking UP from the session cwd:
#   1. a real project mark wins: .git itself, or real .claude content
#      (plan-state.json, settings.json, settings.local.json, hooks/, rules/,
#      CLAUDE.md). A BARE .claude/ directory is NOT a mark — this repo
#      carries tests/.claude/, which used to adopt tests/ as root and
#      silently switch the anti-rationalization gate off under it;
#   2. the git toplevel (when git is healthy) is the fallback root;
#   3. broken git (rc != 0 with a .git present on the walk) does NOT skip
#      the walk: the walk is filesystem-only, so a nested project's plan
#      stays visible regardless of the ANCESTOR repo's health;
#   4. no mark and no healthy git anywhere -> canonical cwd. The value is
#      ALWAYS absolute (canonized here), so consumers never see ".".
get_project_root() {
  local cwd="${1:-${PWD:-.}}"
  local canon
  canon="$(cd "$cwd" 2>/dev/null && pwd -P || echo "$cwd")"
  # (a) stdout only, rc kept: healthy git hands us the declared toplevel.
  local rc=0 root=""
  root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || rc=$?
  [[ "$rc" -ne 0 ]] && root=""
  # (c) broken-vs-absent git, decided by FILESYSTEM presence of a .git on the
  #     walk up (the error text cannot distinguish them). With one present,
  #     the content-marker walk runs with THAT directory as its ceiling — so
  #     a nested project's plan survives an ANCESTOR repo's broken git.
  #     With NO .git on the walk at all, there is no declared container:
  #     per the v2.0.1 invariant the scope is cwd itself — a marker-less walk
  #     up an unbounded tree would adopt strangers (e.g. a shared temp dir
  #     that accumulated a .claude/ from an earlier fixture).
  local dir="$canon" git_ceiling="" next
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -e "$dir/.git" ]]; then git_ceiling="$dir"; break; fi
    next="${dir%/*}"
    [[ "$next" == "$dir" ]] && break
    dir="$next"
  done
  if [[ "$rc" -eq 0 ]]; then
    # (b) healthy git: content-marker walk, ceiling = git toplevel.
    dir="$canon"
    while [[ -n "$dir" && "$dir" != "/" && "$dir" != "$root" ]]; do
      if _is_project_dir_marker "$dir"; then
        echo "$dir"
        return 0
      fi
      next="${dir%/*}"
      [[ "$next" == "$dir" ]] && break
      dir="$next"
    done
    echo "$root"
    return 0
  fi
  if [[ -n "$git_ceiling" ]]; then
    dir="$canon"
    while [[ -n "$dir" && "$dir" != "/" && "$dir" != "$git_ceiling" ]]; do
      if _is_project_dir_marker "$dir"; then
        echo "$dir"
        return 0
      fi
      next="${dir%/*}"
      [[ "$next" == "$dir" ]] && break
      dir="$next"
    done
  fi
  # (4) No git context at all: the frozen session variable is the project
  # identity when the process cwd cannot declare one (v2.96 contract).
  # ALWAYS canonized: identity comparisons (ledger identity, validate_file_path)
  # are meaningless across logical/physical forms — a session entering via
  # /var and a writer resolving via realpath must agree on ONE identity.
  # Consumers that need the raw form must say so explicitly.
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -d "${CLAUDE_PROJECT_DIR}" ]]; then
    local fallback
    fallback="$(cd "${CLAUDE_PROJECT_DIR}" 2>/dev/null && pwd -P || true)"
    [[ -n "$fallback" ]] && { echo "$fallback"; return 0; }
  fi
  echo "$canon"
}

_is_project_dir_marker() {
  local d="$1"
  [[ -e "$d/.git" \
     || -e "$d/.claude/plan-state.json" || -e "$d/.claude/settings.json" \
     || -e "$d/.claude/settings.local.json" || -d "$d/.claude/hooks" \
     || -d "$d/.claude/rules" || -e "$d/.claude/CLAUDE.md" ]]
}

# Single stat dialect per process (T99 r3 finding 6): the GNU/BSD probe used
# to fork `stat` once per call; cache the answer instead.
_STAT_DIALECT_GNU=""
_stat_dialect_is_gnu() {
  if [[ -z "$_STAT_DIALECT_GNU" ]]; then
    if stat -c '%Y' / >/dev/null 2>&1; then
      _STAT_DIALECT_GNU=yes
    else
      _STAT_DIALECT_GNU=no
    fi
  fi
  [[ "$_STAT_DIALECT_GNU" == "yes" ]]
}

get_main_repo() {
  # The MAIN repository, from any worktree.
  #
  # `--git-common-dir` names the main repo's .git in both a plain checkout and a linked
  # worktree, so a single call replaces the previous manual parsing of the worktree's
  # `.git` file (which only worked when the CWD was already the worktree root).
  if [[ -d "${PWD:-}" ]]; then
    local common_dir
    common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$common_dir" ]]; then dirname "$common_dir"; return; fi
  fi
  if [[ -n "${CLAUDE_PROJECT_DIR:-}" && -d "${CLAUDE_PROJECT_DIR}" ]]; then
    echo "$CLAUDE_PROJECT_DIR"; return
  fi
  echo "."
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
  # ...and also when the root IS a .claude directory, with nothing after it. That case
  # was uncovered: a root of ~/.claude yielded PROJECT_CLAUDE_DIR=~/.claude/.claude,
  # which is how the stray ~/.claude/.claude/ tree (39 stale agent copies, plus hooks and
  # rules from May) came to exist. Callers append /.claude to this value, so returning a
  # path that already ends in .claude nests it a second time.
  elif [[ "$root" == *"/.claude" ]]; then
    root="${root%/.claude}"
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

  # Ghost registration recovery: un dir borrado a mano deja el worktree registrado
  # y TODO `git worktree add` falla con "missing but already registered". prune es
  # idempotente y solo toca registros stale, asi que no hace falta comprobar antes
  # (el guard previo interpolaba la ruta como regex y fallaba con rutas que
  # contuvieran `.` o `[`). No oculta nada: si algo sigue mal, el add falla ruidoso.
  git -C "$main_repo" worktree prune 2>/dev/null || true

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

# stat_mtime <path> — numeric mtime on stdout, rc 1 if not determinable.
# stat_birthtime <path> — numeric birth time, same contract (0 means the fs
#   does not report birth time; callers must treat 0 as "unknown").
#
# T99 r3 (review finding 2): this library is the ONLY place a stat dialect is
# chosen. Both hooks and checkWorktreeTTL consume these helpers; three
# hand-rolled dialect strategies had already diverged and broken twice (the
# GNU `-f` trap: `stat -f %m file` SUCCEEDS on Linux, printing multi-line
# non-numeric filesystem info — so any `|| fallback` after it is unreachable
# and the garbage reaches arithmetic). The numeric gate here is load-bearing.
stat_mtime() {
  local f="$1" out=""
  if _stat_dialect_is_gnu; then
    out="$(stat -c '%Y' "$f" 2>/dev/null || true)"
  else
    out="$(stat -f '%m' "$f" 2>/dev/null || true)"
  fi
  [[ "$out" =~ ^[0-9]+$ ]] || return 1
  echo "$out"
}

stat_birthtime() {
  local f="$1" out=""
  if _stat_dialect_is_gnu; then
    out="$(stat -c '%W' "$f" 2>/dev/null || true)"
  else
    out="$(stat -f '%B' "$f" 2>/dev/null || true)"
  fi
  [[ "$out" =~ ^[0-9]+$ ]] || return 1
  echo "$out"
}

# stat_size <path> — numeric byte size, same contract (T99 r4: migrate the
# last hand-rolled `stat -f%z || stat -c%s` to the shared strategy).
stat_size() {
  local f="$1" out=""
  if _stat_dialect_is_gnu; then
    out="$(stat -c '%s' "$f" 2>/dev/null || true)"
  else
    out="$(stat -f '%z' "$f" 2>/dev/null || true)"
  fi
  [[ "$out" =~ ^[0-9]+$ ]] || return 1
  echo "$out"
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

  # Get creation time from worktree directory metadata.
  #
  # T99 r3: dialect choice + numeric gate live in stat_birthtime/stat_mtime
  # (top of this library) — the GNU `-f` trap aborted this function under
  # `set -uo pipefail` when hand-rolled here (multi-line fs info from
  # `stat -f` on Linux), and birth time 0 on ext4/overlayfs made fresh
  # worktrees look ~29M minutes old. Same semantics: birth time when the fs
  # reports it, mtime otherwise.
  local created_epoch=""
  created_epoch=$(stat_birthtime "$wt_dir" 2>/dev/null || true)
  if [[ -z "$created_epoch" || "$created_epoch" -eq 0 ]]; then
    created_epoch=$(stat_mtime "$wt_dir" 2>/dev/null || true)
  fi
  # Final guard: never let a non-numeric value reach the arithmetic below
  # (a non-numeric $(( )) aborts the function under set -e and yields empty stdout).
  [[ "$created_epoch" =~ ^[0-9]+$ ]] || created_epoch=$(date +%s)

  local now_epoch
  now_epoch=$(date +%s)
  local elapsed_minutes=$(( (now_epoch - created_epoch) / 60 ))
  # Clamp negative drift (clock skew between birth time and now) to 0.
  (( elapsed_minutes < 0 )) && elapsed_minutes=0
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
