#!/bin/bash
# centralize-all.sh - Centralize all skills, agents, and plugins to ~/.claude/
# VERSION: 2.85.1
#
# This script consolidates:
#   - Skills from multiple locations
#   - Agents from repository
#   - Plugins from old installations
#
# Locations:
#   Skills:
#     - /Users/alfredolopez/.claude-code-old/.claude-old/skills
#     - /Users/alfredolopez/.claude-sneakpeek-old/zai/skills
#     - /Users/alfredolopez/.config/agents/skills (kimi-cli shared)
#     - Repository: multi-agent-ralph-loop/.claude/skills
#
#   Plugins:
#     - /Users/alfredolopez/.claude-code-old/.claude-old/plugins
#     - Repository enabledPlugins

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

# Source locations
OLD_CLAUDE_DIR="/Users/alfredolopez/.claude-code-old/.claude-old"
OLD_ZAI_DIR="/Users/alfredolopez/.claude-sneakpeek-old/zai"
KIMI_SKILLS="/Users/alfredolopez/.config/agents/skills"
REPO_SKILLS="$REPO_ROOT/.claude/skills"
REPO_AGENTS="$REPO_ROOT/.claude/agents"

echo "========================================"
echo " Full Centralization Script"
echo " Version: 2.85.1"
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
        return 0
    fi

    mkdir -p "$(dirname "$dst")"
    rm -rf "$dst" 2>/dev/null || true
    ln -sf "$src" "$dst"
}

# ============================================================================
# PHASE 1: Backup
# ============================================================================
if [[ "$DRY_RUN" = false ]]; then
    echo "📁 Phase 1: Backing up current configuration..."
    mkdir -p "$BACKUP_DIR"

    [[ -e "$CLAUDE_DIR/skills" ]] && cp -R "$CLAUDE_DIR/skills" "$BACKUP_DIR/skills" 2>/dev/null || true
    [[ -e "$CLAUDE_DIR/agents" ]] && cp -R "$CLAUDE_DIR/agents" "$BACKUP_DIR/agents" 2>/dev/null || true
    [[ -e "$CLAUDE_DIR/plugins" ]] && cp -R "$CLAUDE_DIR/plugins" "$BACKUP_DIR/plugins" 2>/dev/null || true

    echo "   ✓ Backup created at: $BACKUP_DIR"
fi

# ============================================================================
# PHASE 2: Centralize Skills
# ============================================================================
echo ""
echo "📁 Phase 2: Centralizing Skills..."

SKILLS_DIR="$CLAUDE_DIR/skills"
total_skills=0

if [[ "$DRY_RUN" = false ]]; then
    rm -rf "$SKILLS_DIR" 2>/dev/null || true
    mkdir -p "$SKILLS_DIR"
fi

add_skills_from_dir() {
    local source_dir="$1"
    local source_name="$2"

    if [[ ! -d "$source_dir" ]]; then
        echo "   ⚠ $source_name not found"
        return
    fi

    local count=0
    echo "   Processing $source_name..."

    for skill in "$source_dir"/*; do
        [[ -e "$skill" ]] || continue
        [[ -d "$skill" ]] || continue

        skill_name=$(basename "$skill")
        dst="$SKILLS_DIR/$skill_name"

        [[ -e "$dst" ]] && continue

        if [[ -L "$skill" ]]; then
            target=$(readlink "$skill")
            [[ -d "$target" ]] && make_symlink "$target" "$dst"
        else
            make_symlink "$skill" "$dst"
        fi

        ((count++))
    done

    echo "     Added $count skills"
    total_skills=$((total_skills + count))
}

add_skills_from_dir "$REPO_SKILLS" "Repository"
add_skills_from_dir "$OLD_CLAUDE_DIR/skills" "Old Claude Code"
add_skills_from_dir "$OLD_ZAI_DIR/skills" "Old Zai"
add_skills_from_dir "$KIMI_SKILLS" "Kimi-cli Shared"

echo "   Total skills: $total_skills"

# ============================================================================
# PHASE 3: Centralize Agents
# ============================================================================
echo ""
echo "📁 Phase 3: Centralizing Agents..."

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

echo "   Symlinked $agent_count agents"

# Verify ralph-* agents
echo "   Verifying ralph-* agents..."
for agent in ralph-coder ralph-reviewer ralph-tester ralph-researcher; do
    if [[ -f "$AGENTS_DIR/${agent}.md" ]] || [[ -L "$AGENTS_DIR/${agent}.md" ]]; then
        echo "     ✓ $agent"
    else
        echo "     ✗ $agent NOT found"
    fi
done

# ============================================================================
# PHASE 4: Merge Plugins
# ============================================================================
echo ""
echo "📁 Phase 4: Merging Plugins..."

PLUGINS_DIR="$CLAUDE_DIR/plugins"
OLD_PLUGINS="$OLD_CLAUDE_DIR/plugins"

if [[ "$DRY_RUN" = false ]]; then
    mkdir -p "$PLUGINS_DIR/cache"
    mkdir -p "$PLUGINS_DIR/marketplaces"
fi

# Merge installed_plugins.json
if [[ -f "$OLD_PLUGINS/installed_plugins.json" ]]; then
    echo "   Merging installed_plugins.json..."

    if [[ "$DRY_RUN" = false ]]; then
        if [[ -f "$PLUGINS_DIR/installed_plugins.json" ]] && [[ -f "$OLD_PLUGINS/installed_plugins.json" ]]; then
            # Use jq to merge the two JSON files
            jq -s '.[0] * .[1]' "$PLUGINS_DIR/installed_plugins.json" "$OLD_PLUGINS/installed_plugins.json" \
                > "$PLUGINS_DIR/installed_plugins.json.merged" 2>/dev/null || true

            if [[ -f "$PLUGINS_DIR/installed_plugins.json.merged" ]]; then
                mv "$PLUGINS_DIR/installed_plugins.json.merged" "$PLUGINS_DIR/installed_plugins.json"
                echo "     ✓ Merged installed_plugins.json"
            fi
        elif [[ -f "$OLD_PLUGINS/installed_plugins.json" ]]; then
            cp "$OLD_PLUGINS/installed_plugins.json" "$PLUGINS_DIR/"
            echo "     ✓ Copied installed_plugins.json"
        fi
    fi
fi

# Copy plugin cache if missing
if [[ -d "$OLD_PLUGINS/cache" ]]; then
    cache_count=$(find "$OLD_PLUGINS/cache" -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "   Plugin cache entries available: $cache_count"

    if [[ "$DRY_RUN" = false ]]; then
        # Copy missing cache entries
        for cached_plugin in "$OLD_PLUGINS/cache"/*; do
            [[ -d "$cached_plugin" ]] || continue
            plugin_name=$(basename "$cached_plugin")
            dst="$PLUGINS_DIR/cache/$plugin_name"

            if [[ ! -d "$dst" ]]; then
                cp -R "$cached_plugin" "$dst"
                echo "     ✓ Cached: $plugin_name"
            fi
        done
    fi
fi

# Copy marketplaces if missing
if [[ -d "$OLD_PLUGINS/marketplaces" ]]; then
    mk_count=$(find "$OLD_PLUGINS/marketplaces" -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "   Marketplaces available: $mk_count"

    if [[ "$DRY_RUN" = false ]]; then
        for marketplace in "$OLD_PLUGINS/marketplaces"/*; do
            [[ -d "$marketplace" ]] || continue
            mk_name=$(basename "$marketplace")
            dst="$PLUGINS_DIR/marketplaces/$mk_name"

            if [[ ! -d "$dst" ]]; then
                cp -R "$marketplace" "$dst"
                echo "     ✓ Marketplace: $mk_name"
            fi
        done
    fi
fi

# ============================================================================
# PHASE 5: Update settings.json
# ============================================================================
echo ""
echo "📁 Phase 5: Updating settings.json..."

SETTINGS_FILE="$CLAUDE_DIR/settings.json"

if [[ -f "$SETTINGS_FILE" ]]; then
    # Count current enabled plugins
    enabled_count=$(jq '.enabledPlugins | length' "$SETTINGS_FILE" 2>/dev/null || echo "0")
    echo "   Current enabled plugins in settings: $enabled_count"
fi

# ============================================================================
# Summary
# ============================================================================
echo ""
echo "========================================"
echo " Summary"
echo "========================================"
if [[ "$DRY_RUN" = false ]]; then
    echo "  Skills centralized: $total_skills"
    echo "  Agents symlinked: $agent_count"
    echo "  Plugins merged from old installation"
    echo "  Backup: $BACKUP_DIR"
    echo ""
    echo "✅ Centralization complete!"
    echo ""
    echo "⚠️  IMPORTANT: Restart Claude Code for changes to take effect."
    echo ""
    echo "To verify, run:"
    echo "  ls ~/.claude/skills | wc -l"
    echo "  ls ~/.claude/agents/*.md | wc -l"
else
    echo "  (Dry run - no changes made)"
    echo ""
    echo "Run without --dry-run to apply changes."
fi
