#!/bin/bash
# Auto-sync global commands/agents/hooks to current project
# Runs on SessionStart to ensure all projects have global configs

# VERSION: 2.69.0
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

# Sync hooks silently
if [ -d "$GLOBAL_DIR/hooks" ]; then
    mkdir -p "$PROJECT_CLAUDE_DIR/hooks"
    for hook in "$GLOBAL_DIR/hooks"/*; do
        [ -f "$hook" ] || continue  # Skip if glob didn't match
        basename=$(basename "$hook")
        target="$PROJECT_CLAUDE_DIR/hooks/$basename"
        if [ ! -f "$target" ]; then
            cp "$hook" "$target" 2>/dev/null || true
            chmod +x "$target" 2>/dev/null || true
        fi
    done
fi

exit 0
