#!/bin/bash
# Auto-sync global commands/agents/hooks to current project
# Runs on SessionStart to ensure all projects have global configs

# VERSION: 2.85.0
set -euo pipefail

GLOBAL_DIR="${HOME}/.claude"
PROJECT_DIR="$(pwd)"
PROJECT_CLAUDE_DIR="${PROJECT_DIR}/.claude"

# Only sync if project has a .claude directory
if [ ! -d "$PROJECT_CLAUDE_DIR" ]; then
    exit 0
fi

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
# Only hooks in this list will be copied from global to project
APPROVED_HOOKS=(
    "git-safety-guard.py"
    "repo-boundary-guard.sh"
    "sanitize-secrets.js"
    "cleanup-secrets-db.js"
    "procedural-forget.sh"
    "detect-environment.sh"
    "handoff-integrity.sh"
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
