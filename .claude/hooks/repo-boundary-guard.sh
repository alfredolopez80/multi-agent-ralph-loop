#!/usr/bin/env bash
umask 077
# repo-boundary-guard.sh — Repository Isolation Enforcement
# Hook: PreToolUse (Edit|Write|Bash)
# VERSION: 2.98.0
# v2.97.0: Review fixes — is_same_repo param, single-fire trap, sed trim, dedup canonicalize.
# v2.98.0: Security fixes — canonicalize ancestor-walk, worktree-list validation, fail-closed trap, redirect detection.

# SEC-111: stdin with 100KB limit
INPUT=$(head -c 100000)


set -euo pipefail

_emit_deny_on_crash() {
    trap - ERR EXIT
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "[repo-boundary-guard] Guard crashed — failing closed. Check ~/.ralph/logs/repo-boundary.log"}}'
}
trap '_emit_deny_on_crash' ERR EXIT

# Configuration
LOG_FILE="${HOME}/.ralph/logs/repo-boundary.log"
CURRENT_REPO=""
PROJECT_ROOT=""
GITHUB_DIR="${HOME}/Documents/GitHub"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get current repository root
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  # Resolve the MAIN repository via --git-common-dir (works in both plain
  # checkouts and linked worktrees).
  get_main_repo() {
    local common_dir
    common_dir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [[ -n "$common_dir" ]]; then
      dirname "$common_dir"
    else
      get_project_root
    fi
  }
}

get_current_repo() {
    get_main_repo 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null || echo ""
}

# canonicalize <path> — expand ~ and resolve via realpath.
# For non-existent paths (Write's primary case), walks up to the nearest
# existing ancestor and resolves THAT, then appends the remaining basename.
# This collapses ".." sequences that realpath alone cannot resolve on macOS BSD
# when the full path doesn't exist yet.
canonicalize() {
    local p="${1/#\~/$HOME}"
    local out
    if out="$(realpath "$p" 2>/dev/null)"; then echo "$out"; return; fi
    if out="$(realpath -m "$p" 2>/dev/null)"; then echo "$out"; return; fi
    local dir base
    dir="$(dirname "$p")"
    base="$(basename "$p")"
    local rdir
    if rdir="$(realpath "$dir" 2>/dev/null)"; then
        echo "$rdir/$base"
    elif rdir="$(realpath -m "$dir" 2>/dev/null)"; then
        echo "$rdir/$base"
    else
        log "WARN: canonicalize failed for $p — denying as precaution"
        echo "__CANONICALIZE_FAILED__"
    fi
}

# is_same_repo <path> <repo> — true if <path> belongs to the SAME repository
# as <repo>. Validates that the target directory is a REGISTERED worktree
# (listed in `git worktree list`) of <repo>, not just a directory with a
# hand-crafted .git file pointing at <repo>'s .git.
is_same_repo() {
    local dir="$1"
    local repo="$2"
    [[ -n "$repo" ]] || return 1
    while [[ -n "$dir" && "$dir" != "/" && ! -d "$dir" ]]; do
        dir="$(dirname "$dir")"
    done
    [[ -d "$dir" ]] || return 1

    local common_dir
    common_dir="$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    [[ -n "$common_dir" ]] || return 1

    local owner_repo
    owner_repo="$(canonicalize "$(dirname "$common_dir")")"
    [[ "$owner_repo" == "$repo" ]] || return 1

    local candidate_wt
    candidate_wt="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
    [[ -n "$candidate_wt" ]] || return 1
    candidate_wt="$(canonicalize "$candidate_wt")"

    if [[ "$candidate_wt" == "$repo" ]]; then
        return 0
    fi

    local registered
    registered="$(git -C "$repo" worktree list --porcelain 2>/dev/null | grep '^worktree ' | sed 's/^worktree //')"
    local wt
    while IFS= read -r wt; do
        [[ -n "$wt" ]] || continue
        wt="$(canonicalize "$wt")"
        if [[ "$candidate_wt" == "$wt" ]]; then
            return 0
        fi
    done <<< "$registered"

    log "BLOCKED: $dir claims repo $repo but is not a registered worktree"
    return 1
}

# v2.69.0 FIX: Check if command is read-only (safe to run on external repos)
# This prevents false positives blocking legitimate ls, cat, grep commands
is_readonly_command() {
    local command="$1"

    # A "read-only" command with a redirect is a write operation
    if echo "$command" | grep -qE '>\s|>>' || echo "$command" | grep -qE '\|\s*tee\b'; then
        return 1
    fi

    # Extract base command (first word)
    local base_cmd
    base_cmd=$(echo "$command" | awk '{print $1}')

    # Safe read-only commands
    case "$base_cmd" in
        ls|ll|la|tree|find|fd)
            return 0 ;;
        cat|less|more|head|tail)
            return 0 ;;
        grep|egrep|fgrep|rg|ag)
            return 0 ;;
        diff|sdiff|cmp)
            return 0 ;;
        wc|sort|uniq)
            return 0 ;;
        file|stat|du)
            return 0 ;;
        jq|yq)
            return 0 ;;
        pwd|which|whereis)
            return 0 ;;
        md5sum|sha256sum|shasum)
            return 0 ;;
        echo|printf)
            return 0 ;;
        *)
            # Check git read-only commands
            if [[ "$command" =~ ^git\ (show|log|diff|status|branch) ]]; then
                return 0
            fi
            return 1 ;;
    esac
}

# Check if a path is within the current repo or allowed locations
is_allowed_path() {
    local path="$1"
    local current_repo="$2"

    # SEC-051: Canonicalize path using realpath (handles ~, .., symlinks).
    # current_repo arrives pre-canonicalized from main().
    path="$(canonicalize "$path")"

    # Allow global config directories (boundary-safe: .claude but not .claude-evil)
    if [[ "$path" == "${HOME}/.claude" || "$path" == "${HOME}/.claude/"* ]] || \
       [[ "$path" == "${HOME}/.ralph" || "$path" == "${HOME}/.ralph/"* ]] || \
       [[ "$path" == "${HOME}/.config" || "$path" == "${HOME}/.config/"* ]] || \
       [[ "$path" == "/tmp" || "$path" == "/tmp/"* ]] || \
       [[ "$path" == "/private/tmp" || "$path" == "/private/tmp/"* ]] || \
       [[ "$path" == "/var/tmp" || "$path" == "/var/tmp/"* ]]; then
        return 0  # Allowed
    fi

    # If no current repo detected, allow
    if [[ -z "$current_repo" ]]; then
        return 0
    fi

    # Within the current MAIN repo (boundary-safe: repo/ but not repo-evil/).
    # Worktrees under <main>/.claude/worktrees/ are covered by this prefix.
    if [[ "$path" == "$current_repo" || "$path" == "$current_repo"/* ]]; then
        return 0  # Allowed - within current repo
    fi

    # Within the CURRENT working tree (may live outside the main repo dir).
    if [[ -n "$PROJECT_ROOT" ]] && \
       [[ "$path" == "$PROJECT_ROOT" || "$path" == "$PROJECT_ROOT"/* ]]; then
        return 0  # Allowed - within current working tree
    fi

    # Check if path is in another GitHub repo
    if [[ "$path" == "$GITHUB_DIR"/* ]]; then
        if is_same_repo "$path" "$current_repo"; then
            return 0  # Allowed - same repository (worktree or main checkout)
        fi
        return 1  # BLOCKED - another repo
    fi

    # Allow other paths (system, etc.)
    return 0
}

# Extract paths from tool input
extract_paths() {
    local input="$1"

    # Extract file_path, path, or command paths
    echo "$input" | jq -r '
        .tool_input // . |
        if type == "object" then
            (.file_path // .path // .command // "")
        else
            ""
        end
    ' 2>/dev/null || echo ""
}

# Main logic
main() {
    # v2.69: Use $INPUT from SEC-111 read instead of second cat (fixes double-read bug)
    local input="$INPUT"

    if [[ -z "$input" ]]; then
        log "DEBUG: Empty input, allowing"
        trap - ERR EXIT
        echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
        exit 0
    fi

    # Get current repo (the MAIN repo — identical for main checkout and all its
    # worktrees) and the current working tree root, both canonicalized so every
    # later comparison is canonical-vs-canonical.
    CURRENT_REPO=$(get_current_repo)
    [[ "$CURRENT_REPO" == "." ]] && CURRENT_REPO=""
    if [[ -n "$CURRENT_REPO" ]]; then
        CURRENT_REPO="$(canonicalize "$CURRENT_REPO")"
    fi
    PROJECT_ROOT=$(get_project_root 2>/dev/null || echo "")
    [[ "$PROJECT_ROOT" == "." ]] && PROJECT_ROOT=""
    if [[ -n "$PROJECT_ROOT" ]]; then
        PROJECT_ROOT="$(canonicalize "$PROJECT_ROOT")"
    fi

    if [[ -z "$CURRENT_REPO" ]]; then
        log "DEBUG: Not in a git repo, allowing"
        trap - ERR EXIT
        echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
        exit 0
    fi

    # Extract tool name
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

    # Only check Edit, Write, Bash
    case "$tool_name" in
        Edit|Write|Bash)
            ;;
        *)
            log "DEBUG: Tool $tool_name not checked, allowing"
            trap - ERR EXIT
            echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
            exit 0
            ;;
    esac

    # Extract paths from input
    local paths
    paths=$(extract_paths "$input")

    # For Bash, also check command content
    if [[ "$tool_name" == "Bash" ]]; then
        local command
        command=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

        # BUG-010 FIX: Check ALL pipeline segments for write commands, not just first
        # Prevents bypass via: cat safe_file | bash -c "rm -rf /external"
        if echo "$command" | grep -qE '\|'; then
            local pipe_cmds
            pipe_cmds=$(echo "$command" | tr '|' '\n')
            local has_write=false
            while IFS= read -r pipe_cmd; do
                pipe_cmd=$(echo "$pipe_cmd" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                if [[ -n "$pipe_cmd" ]] && ! is_readonly_command "$pipe_cmd"; then
                    has_write=true
                    break
                fi
            done <<< "$pipe_cmds"
            if [[ "$has_write" == "false" ]]; then
                log "ALLOWED: All pipeline segments are read-only: $command"
                trap - ERR EXIT
                echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
                exit 0
            fi
        fi

        # v2.69.0 FIX: Check if command is read-only FIRST
        # Read-only commands (ls, cat, grep, etc.) are safe to run on external repos
        if is_readonly_command "$command"; then
            log "ALLOWED: Read-only command (safe for cross-repo): $command"
            trap - ERR EXIT
            echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
            exit 0
        fi

        # Only check repo boundaries for non-readonly (potentially destructive) commands
        # Look for patterns like /Users/.../GitHub/OtherRepo
        if echo "$command" | grep -qE "${GITHUB_DIR}/[^/]+/" 2>/dev/null; then
            local mentioned_paths mentioned_path
            mentioned_paths=$(echo "$command" | grep -oE "${GITHUB_DIR}/[^[:space:]\"'\`;)&|]+" || true)
            while IFS= read -r mentioned_path; do
                [[ -z "$mentioned_path" ]] && continue
                if ! is_allowed_path "$mentioned_path" "$CURRENT_REPO"; then
                    log "BLOCKED: Bash command references external repo: $mentioned_path"
                    trap - ERR EXIT
                    # jq -n, not a heredoc: $mentioned_path comes from the payload, and a
                    # quote in it produced invalid JSON — a deny the harness cannot parse
                    # denies nothing.
                    jq -n --arg p "$mentioned_path" '{
                      hookSpecificOutput: {
                        hookEventName: "PreToolUse",
                        permissionDecision: "deny",
                        permissionDecisionReason: ("[repo-boundary-guard] REPO BOUNDARY: Command references external repository (" + $p + "). Use /repo-learn to learn from it instead, or explicitly switch repos.")
                      }
                    }'
                    exit 0
                fi
            done <<< "$mentioned_paths"
        fi
    fi

    # Check extracted paths
    for path in "$paths"; do
        if [[ -n "$path" ]] && ! is_allowed_path "$path" "$CURRENT_REPO"; then
            log "BLOCKED: Access to external repo path: $path (current: $CURRENT_REPO)"
            trap - ERR EXIT
            # Build with jq, never string interpolation: a path containing a double quote
            # produced malformed JSON, the harness could not parse the deny, and an
            # unparseable deny denies nothing — a fail-open. The sibling mentioned-path deny
            # already uses jq -n for exactly this reason; this block was the one left behind.
            jq -n --arg p "$path" --arg repo "$CURRENT_REPO" '{
              hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: ("[repo-boundary-guard] REPO BOUNDARY: Path " + $p + " is outside current repo (" + $repo + "). Use /repo-learn to learn from external repos, or explicitly switch.")
              }
            }'
            exit 0
        fi
    done

    log "ALLOWED: All paths within boundary"
    trap - ERR EXIT
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
}

main "$@"
