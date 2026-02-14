#!/bin/bash
# centralize-skills.sh - Centralize all skills and agents to ~/.claude/
# VERSION: 2.85.0
#
# This script consolidates skills and agents from multiple locations into ~/.claude/
# Locations:
#   - /Users/alfredolopez/.claude-code-old/.claude-old/skills
#   - /Users/alfredolopez/.claude-sneakpeek-old/zai/skills
#   - /Users/alfredolopez/.config/agents/skills (kimi-cli shared)
#   - Repository: multi-agent-ralph-loop/.claude/skills

set -euo pipefail

DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

# Source locations
OLD_CLAUDE_SKILLS="/Users/alfredolopez/.claude-code-old/.claude-old/skills"
OLD_ZAI_SKILLS="/Users/alfredolopez/.claude-sneakpeek-old/zai/skills"
KIMI_SKILLS="/Users/alfredolopez/.config/agents/skills"
REPO_SKILLS="$REPO_ROOT/.claude/skills"
REPO_AGENTS="$REPO_ROOT/.claude/agents"

echo "========================================"
echo " Skills & Agents Centralization Script"
echo " Version: 2.85.0"
echo "========================================"
echo ""
echo "Mode: $([ "$DRY_RUN" = true ] && echo "DRY RUN (no changes)" || echo "EXECUTE")"
echo ""

# Function to safely create symlink
make_symlink() {
    local src="$1"
    local dst="$2"

    if [[ "$DRY_RUN" = true ]]; then
        echo "  [DRY] ln -sf $src $dst"
        return
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$dst")"

    # Remove existing file/symlink
    rm -rf "$dst" 2>/dev/null || true

    # Create symlink
    ln -sf "$src" "$dst"
}

# Phase 1: Backup current configuration
if [[ "$DRY_RUN" = false ]]; then
    echo "📁 Phase 1: Backing up current configuration..."
    mkdir -p "$BACKUP_DIR"

    if [[ -e "$CLAUDE_DIR/skills" ]]; then
        cp -R "$CLAUDE_DIR/skills" "$BACKUP_DIR/skills" 2>/dev/null || true
        echo "   ✓ Skills backed up"
    fi

    if [[ -e "$CLAUDE_DIR/agents" ]]; then
        cp -R "$CLAUDE_DIR/agents" "$BACKUP_DIR/agents" 2>/dev/null || true
        echo "   ✓ Agents backed up"
    fi
fi

# Phase 2: Create merged skills directory
echo ""
echo "📁 Phase 2: Creating merged skills directory..."

SKILLS_DIR="$CLAUDE_DIR/skills"

if [[ "$DRY_RUN" = false ]]; then
    # Remove existing symlink and create directory
    rm -rf "$SKILLS_DIR" 2>/dev/null || true
    mkdir -p "$SKILLS_DIR"
fi

# Phase 3: Copy/symlink skills from all sources
echo ""
echo "📁 Phase 3: Consolidating skills from all sources..."

# Counter for stats
total_skills=0

# Function to add skills from a directory
add_skills_from_dir() {
    local source_dir="$1"
    local source_name="$2"

    if [[ ! -d "$source_dir" ]]; then
        echo "   ⚠ $source_name not found: $source_dir"
        return
    fi

    local count=0
    echo "   Processing $source_name..."

    for skill in "$source_dir"/*; do
        [[ -e "$skill" ]] || continue  # Skip if no matches
        [[ -d "$skill" ]] || continue  # Only directories

        skill_name=$(basename "$skill")
        dst="$SKILLS_DIR/$skill_name"

        # Skip if already exists (first source wins)
        if [[ -e "$dst" ]]; then
            continue
        fi

        if [[ -L "$skill" ]]; then
            # It's a symlink - copy the target or recreate symlink
            target=$(readlink "$skill")
            if [[ -d "$target" ]]; then
                make_symlink "$target" "$dst"
            fi
        else
            # It's a directory - create symlink
            make_symlink "$skill" "$dst"
        fi

        ((count++))
        ((total_skills++))
    done

    echo "     Added $count skills from $source_name"
}

# Add skills from all sources (order matters - first wins)
add_skills_from_dir "$REPO_SKILLS" "Repository"
add_skills_from_dir "$OLD_CLAUDE_SKILLS" "Old Claude Code"
add_skills_from_dir "$OLD_ZAI_SKILLS" "Old Zai"
add_skills_from_dir "$KIMI_SKILLS" "Kimi-cli Shared"

echo ""
echo "   Total skills consolidated: $total_skills"

# Phase 4: Symlink agents from repo
echo ""
echo "📁 Phase 4: Symlinking agents from repository..."

AGENTS_DIR="$CLAUDE_DIR/agents"

if [[ "$DRY_RUN" = false ]]; then
    mkdir -p "$AGENTS_DIR"
fi

agent_count=0
for agent in "$REPO_AGENTS"/*.md; do
    [[ -f "$agent" ]] || continue

    agent_name=$(basename "$agent")
    dst="$AGENTS_DIR/$agent_name"

    make_symlink "$agent" "$dst"
    ((agent_count++))
done

echo "   Symlinked $agent_count agents from repository"

# Phase 5: Verify ralph-* agents are now available
echo ""
echo "📁 Phase 5: Verifying ralph-* agents..."

ralph_agents=("ralph-coder" "ralph-reviewer" "ralph-tester" "ralph-researcher")
for agent in "${ralph_agents[@]}"; do
    if [[ -f "$AGENTS_DIR/${agent}.md" ]] || [[ -L "$AGENTS_DIR/${agent}.md" ]]; then
        echo "   ✓ $agent available"
    else
        echo "   ✗ $agent NOT found"
    fi
done

# Summary
echo ""
echo "========================================"
echo " Summary"
echo "========================================"
if [[ "$DRY_RUN" = false ]]; then
    echo "  Skills consolidated: $total_skills"
    echo "  Agents symlinked: $agent_count"
    echo "  Backup location: $BACKUP_DIR"
    echo ""
    echo "✅ Centralization complete!"
    echo ""
    echo "IMPORTANT: Restart Claude Code for changes to take effect."
else
    echo "  (Dry run - no changes made)"
fi
