#!/usr/bin/env bash
umask 077
# project-state.sh - Unified project state: skills sync validation + context tracking
# VERSION: 1.0.0 (Consolidated from skills-sync-validator.sh + unified-context-tracker.sh)
# Hook: SessionStart (matcher: *)
# Purpose: On session start, validate skills sync across directories AND
#          provide a context-tracking interface. Provider-agnostic: it never
#          detects, prefers, or reports a specific model or provider.
#
# CLI Usage:
#   ./project-state.sh                          # Run as SessionStart hook (validates + tracks)
#   ./project-state.sh get-dir                  # Get project-specific state directory
#   ./project-state.sh get-percentage            # Get current context %
#   ./project-state.sh get-info                 # Get full context info JSON
#   ./project-state.sh validate-skills          # Run skills sync validation only
#
# Output (hook mode): JSON with hookSpecificOutput for SessionStart

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  get_main_repo() { get_project_root; }
}

HOOKS_DIR="${HOME}/.claude/hooks"
STATE_DIR="${RALPH_DIR:-${HOME}/.ralph}/state"

# Skills directories
GLOBAL_SKILLS="$HOME/.claude/skills"
BACKUP_SKILLS="$HOME/backup/claude-skills"
AGENTS_SKILLS="$HOME/.agents/skills"

LOG_FILE="$HOME/.ralph/logs/project-state.log"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
mkdir -p "$STATE_DIR" 2>/dev/null

# =============================================================================
# LOGGING
# =============================================================================

log() {
    echo "[$(date -Iseconds)] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# STATE DIRECTORY (project-specific)
# =============================================================================

# Get project-specific state directory based on git root
get_state_dir() {
    local git_root
    git_root=$(get_main_repo 2>/dev/null || echo "")
    if [[ -n "$git_root" && "$git_root" != "." ]]; then
        local project_hash
        project_hash=$(echo "$git_root" | shasum -a 256 2>/dev/null | cut -c1-12 || echo "default")
        local project_state_dir="${STATE_DIR}/projects/${project_hash}"
        mkdir -p "$project_state_dir" 2>/dev/null
        echo "$project_state_dir"
    else
        echo "$STATE_DIR"
    fi
}

# =============================================================================
# SKILLS SYNC VALIDATION (from skills-sync-validator.sh)
# =============================================================================

validate_skills() {
    # Count items
    local global_count backup_count agents_count
    global_count=$(ls "$GLOBAL_SKILLS" 2>/dev/null | wc -l | tr -d ' ')
    backup_count=$(ls "$BACKUP_SKILLS" 2>/dev/null | wc -l | tr -d ' ')
    agents_count=$(ls "$AGENTS_SKILLS" 2>/dev/null | wc -l | tr -d ' ')

    # Check for broken symlinks in global
    local broken_global broken_agents
    # PERF v3.1.1: `find -L ... -type l` lists ONLY broken symlinks (those -L cannot
    # resolve) without spawning a `test` process per symlink — same result, far faster.
    broken_global=$(find -L "$GLOBAL_SKILLS" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')
    broken_agents=$(find -L "$AGENTS_SKILLS" -maxdepth 1 -type l 2>/dev/null | wc -l | tr -d ' ')

    # Determine issues
    local issues=()
    [[ $broken_global -gt 0 ]] && issues+=("$broken_global broken symlinks in global")
    [[ $broken_agents -gt 0 ]] && issues+=("$broken_agents broken symlinks in agents")
    [[ ! -d "$BACKUP_SKILLS" ]] && issues+=("Backup directory missing")
    [[ ! -d "$AGENTS_SKILLS" ]] && issues+=("Agents directory missing")

    # Log status
    log "Skills: Global=$global_count, Backup=$backup_count, Agents=$agents_count"
    log "Broken: global=$broken_global, agents=$broken_agents"

    # Return status as JSON fragment
    if [[ ${#issues[@]} -eq 0 ]]; then
        log "Skills sync: OK"
        echo "{\"status\":\"sync_valid\",\"global\":$global_count,\"backup\":$backup_count,\"agents\":$agents_count}"
    else
        log "Skills sync: ISSUES - ${issues[*]}"
        local issues_json
        issues_json=$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
        echo "{\"status\":\"sync_issues\",\"issues\":$issues_json,\"global\":$global_count,\"backup\":$backup_count,\"agents\":$agents_count}"
    fi
}

# =============================================================================
# CONTEXT TRACKING (from unified-context-tracker.sh)
# =============================================================================

# Get context percentage.
#
# The estimate is the same regardless of which model the session runs, so there
# is nothing to branch on: operations and messages are counted locally. The
# per-provider branches that used to live here (and the external tracker they
# called) were provider routing over an identical computation.
get_percentage() {
    local proj_state_dir
    proj_state_dir=$(get_state_dir)

    local ops msgs
    ops=$(cat "${proj_state_dir}/operation-counter" 2>/dev/null || echo "0")
    msgs=$(cat "${proj_state_dir}/message_count" 2>/dev/null || echo "0")
    [[ ! "$ops" =~ ^[0-9]+$ ]] && ops=0
    [[ ! "$msgs" =~ ^[0-9]+$ ]] && msgs=0
    # Hybrid estimation: ops * 0.25 + messages * 2
    local estimated=$(( (ops / 4) + (msgs * 2) ))
    [[ $estimated -gt 100 ]] && estimated=100
    echo "$estimated"
}

# Get full context info

get_info() {
    local pct
    pct=$(get_percentage)
    echo "{\"percentage\":$pct,\"state_dir\":\"$(get_state_dir)\"}"
}

# =============================================================================
# HOOK MODE (SessionStart handler)
# =============================================================================

run_hook_mode() {
    log "SessionStart: Running project-state hook"

    # --- Skills Sync Validation ---
    local skills_result
    skills_result=$(validate_skills 2>/dev/null || echo '{"status":"error"}')

    # --- Context State Initialization ---
    local proj_state_dir
    proj_state_dir=$(get_state_dir)
    log "Project state dir: $proj_state_dir"

    # Initialize operation counter if missing
    if [[ ! -f "${proj_state_dir}/operation-counter" ]]; then
        echo "0" > "${proj_state_dir}/operation-counter"
    fi
    if [[ ! -f "${proj_state_dir}/message_count" ]]; then
        echo "0" > "${proj_state_dir}/message_count"
    fi

    # Build combined SessionStart JSON output
    local skills_status
    skills_status=$(echo "$skills_result" | jq -r '.status // "unknown"' 2>/dev/null || echo "unknown")

    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "skills_sync": $skills_result,
    "context": {
      "state_dir": "$proj_state_dir"
    },
    "additionalContext": "project-state: skills=$skills_status"
  }
}
EOF

    log "SessionStart complete: skills=$skills_status"
}

# =============================================================================
# MAIN DISPATCH
# =============================================================================

case "${1:-__hook__}" in
    __hook__)
        # Default: run as SessionStart hook
        run_hook_mode
        ;;
    get-dir)
        get_state_dir
        ;;
    get-percentage|--percent|-p)
        get_percentage
        ;;
    get-info|--info|-i)
        get_info
        ;;
    validate-skills)
        validate_skills
        ;;
    *)
        echo "Usage: $0 {get-dir|get-percentage|get-info|validate-skills}" >&2
        echo "  (no args = SessionStart hook mode)" >&2
        exit 1
        ;;
esac

exit 0
