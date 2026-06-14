#!/bin/bash
umask 077
# Auto-sync global commands/agents/hooks to current project
# Runs on SessionStart to ensure all projects have global configs

# VERSION: 2.85.0
set -euo pipefail

# PERF v3.1.1: SessionStart symlink sync — run detached so startup never blocks.
# Cost was ~600ms synchronously; now returns in ~5ms and the sync runs in the
# background. A project that needs first-time sync self-heals within this session.
if [[ "${RALPH_HOOK_BG:-0}" != "1" ]]; then
    mkdir -p "${HOME}/.ralph/logs" 2>/dev/null || true
    RALPH_HOOK_BG=1 nohup bash "$0" </dev/null >>"${HOME}/.ralph/logs/auto-sync-global.bg.log" 2>&1 &
    disown 2>/dev/null || true
    # Breadcrumb (codex review): keep a SessionStart context line; real sync status now
    # goes to the bg log instead of being injected synchronously.
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"auto-sync-global: maintenance running in background"}}'
    exit 0
fi

GLOBAL_DIR="${HOME}/.claude"

# Resolve project root via worktree-utils to avoid syncing agents/commands
# into a skill subdirectory when CWD is .claude/skills/<name>/.
HOOK_DIR="$(dirname "${BASH_SOURCE[0]}")"
if [[ -f "${HOOK_DIR}/lib/worktree-utils.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HOOK_DIR}/lib/worktree-utils.sh"
    PROJECT_DIR="$(get_safe_project_root 2>/dev/null || pwd)"
else
    PROJECT_DIR="$(pwd)"
fi
PROJECT_CLAUDE_DIR="${PROJECT_DIR}/.claude"

# Only sync if project already has a .claude directory. Never auto-create it —
# that is what previously caused .claude/ contamination inside skill dirs.
if [ ! -d "$PROJECT_CLAUDE_DIR" ]; then
    exit 0
fi

# Refuse to sync into a path that is itself nested inside another .claude/ tree
# (e.g., .claude/skills/<name>/.claude/). Defense-in-depth on top of
# get_safe_project_root.
case "$PROJECT_CLAUDE_DIR" in
    */.claude/*/.claude*) exit 0 ;;
esac

# Quick check: does project have orchestrator command?
if [ -f "$PROJECT_CLAUDE_DIR/commands/orchestrator.md" ]; then
    # Already synced, exit silently
    exit 0
fi

# Sync commands silently
if [ -d "$GLOBAL_DIR/commands" ]; then
    mkdir -p "$PROJECT_CLAUDE_DIR/commands"
    for cmd in "$GLOBAL_DIR/commands"/*.md; do
        [ -f "$cmd" ] || continue  # Skip if glob didn't match
        basename=$(basename "$cmd")
        target="$PROJECT_CLAUDE_DIR/commands/$basename"
        if [ ! -f "$target" ]; then
            cp "$cmd" "$target" 2>/dev/null || true
        fi
    done
fi

# Sync agents silently
if [ -d "$GLOBAL_DIR/agents" ]; then
    mkdir -p "$PROJECT_CLAUDE_DIR/agents"
    for agent in "$GLOBAL_DIR/agents"/*.md; do
        [ -f "$agent" ] || continue  # Skip if glob didn't match
        basename=$(basename "$agent")
        target="$PROJECT_CLAUDE_DIR/agents/$basename"
        if [ ! -f "$target" ]; then
            cp "$agent" "$target" 2>/dev/null || true
        fi
    done
fi

# SEC-2.3: Whitelist of approved hook names for sync
# Only hooks in this list will be copied from global to project.
# v3.0.1: Removed stale entries that no longer exist on disk
# (sanitize-secrets.js, cleanup-secrets-db.js, procedural-forget.sh,
# detect-environment.sh, handoff-integrity.sh). handoff-integrity.sh
# lives in .claude/lib/ and is sourced directly, not synced via hooks.
APPROVED_HOOKS=(
    "git-safety-guard.py"
    "repo-boundary-guard.sh"
)

# Sync hooks silently (SEC-2.3: with whitelist validation)
if [ -d "$GLOBAL_DIR/hooks" ]; then
    mkdir -p "$PROJECT_CLAUDE_DIR/hooks"
    LOG_FILE="${HOME}/.ralph/logs/auto-sync-global.log"
    mkdir -p "$(dirname "$LOG_FILE")"
    for hook in "$GLOBAL_DIR/hooks"/*; do
        [ -f "$hook" ] || continue  # Skip if glob didn't match
        basename=$(basename "$hook")

        # SEC-2.3: Check if hook is in whitelist
        HOOK_APPROVED=false
        for approved in "${APPROVED_HOOKS[@]}"; do
            if [ "$basename" = "$approved" ]; then
                HOOK_APPROVED=true
                break
            fi
        done

        if [ "$HOOK_APPROVED" = "false" ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SKIPPED: $basename (not in whitelist)" >> "$LOG_FILE" 2>/dev/null || true
            continue
        fi

        target="$PROJECT_CLAUDE_DIR/hooks/$basename"
        if [ ! -f "$target" ]; then
            cp "$hook" "$target" 2>/dev/null || true
            chmod +x "$target" 2>/dev/null || true
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SYNCED: $basename" >> "$LOG_FILE" 2>/dev/null || true
        fi
    done
fi

# v2.85: SessionStart hooks must output JSON with hookSpecificOutput wrapper
echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
