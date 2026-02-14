#!/bin/bash
# setup-skill-symlinks.sh - Set up symlinks from global to repo for Ralph skills
# Version: 2.87.0
# Date: 2026-02-14

set -e

REPO_PATH="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
GLOBAL_SKILLS="$HOME/.claude/skills"
GLOBAL_COMMANDS="$HOME/.claude/commands"

# Ralph core skills that should be symlinked
RALPH_SKILLS=(
    "orchestrator"
    "loop"
    "gates"
    "adversarial"
    "parallel"
    "retrospective"
    "clarify"
    "security"
    "bugs"
    "smart-fork"
    "task-classifier"
    "curator"
    "glm5"
    "glm5-parallel"
    "kaizen"
    "readme"
    "quality-gates-parallel"
    "code-reviewer"
    "task-visualizer"
    "testing-anti-patterns"
    "sec-context-depth"
    "codex-cli"
    "minimax"
    "minimax-mcp-usage"
    "openai-docs"
    "context7-usage"
    "gemini-cli"
    "worktree-pr"
    "edd"
    "deslop"
    "stop-slop"
    "audit"
)

echo "=== Ralph Skills Symlink Setup (v2.87.0) ==="
echo ""

# Step 1: Remove backup folders
echo "Step 1: Removing backup skill folders..."
for backup in "$GLOBAL_SKILLS"/*.backup.*; do
    if [[ -L "$backup" ]]; then
        echo "  Removing symlink: $backup"
        rm "$backup"
    elif [[ -d "$backup" ]]; then
        echo "  Removing directory: $backup"
        rm -rf "$backup"
    fi
done
echo "  Done."
echo ""

# Step 2: Set up skill symlinks
echo "Step 2: Setting up skill symlinks..."
for skill in "${RALPH_SKILLS[@]}"; do
    REPO_SKILL="$REPO_PATH/.claude/skills/$skill"
    GLOBAL_SKILL="$GLOBAL_SKILLS/$skill"

    if [[ -d "$REPO_SKILL" ]]; then
        # Remove existing (symlink or directory)
        if [[ -L "$GLOBAL_SKILL" ]]; then
            rm "$GLOBAL_SKILL"
        elif [[ -d "$GLOBAL_SKILL" ]]; then
            rm -rf "$GLOBAL_SKILL"
        fi

        # Create symlink
        ln -sf "$REPO_SKILL" "$GLOBAL_SKILL"
        echo "  Linked: $skill"
    else
        echo "  Skipped: $skill (not in repo)"
    fi
done
echo "  Done."
echo ""

# Step 3: Remove duplicate command files (keep only symlinks)
echo "Step 3: Cleaning up duplicate command files..."
for skill in "${RALPH_SKILLS[@]}"; do
    REPO_SKILL="$REPO_PATH/.claude/skills/$skill/SKILL.md"
    GLOBAL_COMMAND="$GLOBAL_COMMANDS/$skill.md"

    if [[ -f "$REPO_SKILL" ]]; then
        # Remove duplicate command file if it exists
        if [[ -f "$GLOBAL_COMMAND" ]] && [[ ! -L "$GLOBAL_COMMAND" ]]; then
            echo "  Removing duplicate: $skill.md"
            rm "$GLOBAL_COMMAND"
        fi

        # Optionally create symlink from command to skill (for backward compat)
        # This is optional since skills take precedence over commands
        # ln -sf "$REPO_SKILL" "$GLOBAL_COMMAND"
    fi
done
echo "  Done."
echo ""

# Step 4: Verify symlinks
echo "Step 4: Verifying symlinks..."
VERIFIED=0
BROKEN=0
for skill in "${RALPH_SKILLS[@]}"; do
    GLOBAL_SKILL="$GLOBAL_SKILLS/$skill"
    if [[ -L "$GLOBAL_SKILL" ]]; then
        TARGET=$(readlink "$GLOBAL_SKILL")
        if [[ -d "$TARGET" ]]; then
            ((VERIFIED++))
        else
            echo "  BROKEN: $skill -> $TARGET"
            ((BROKEN++))
        fi
    fi
done
echo "  Verified: $VERIFIED symlinks"
if [[ $BROKEN -gt 0 ]]; then
    echo "  WARNING: $BROKEN broken symlinks"
fi
echo ""

echo "=== Setup Complete ==="
echo ""
echo "Skills are now unified with single source of truth in repo."
echo "Changes to repo skills will automatically reflect globally."
