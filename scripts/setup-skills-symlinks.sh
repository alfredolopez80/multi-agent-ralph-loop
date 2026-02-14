#!/bin/bash
#
# Setup Skills Symlinks v2.87.0
# Creates symlinks from global ~/.claude/skills to repo skills
# Preserves external skills that already exist
#
# Usage: ./scripts/setup-skills-symlinks.sh [--dry-run] [--force]
#

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_SKILLS="$REPO_ROOT/.claude/skills"
GLOBAL_SKILLS="$HOME/.claude/skills"
DRY_RUN=false
FORCE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --dry-run|-n) DRY_RUN=true ;;
        --force|-f) FORCE=true ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Skills Symlink Setup v2.87.0                             ║"
echo "║     Repository: multi-agent-ralph-loop                       ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Repository: $REPO_ROOT"
echo "Repo Skills: $REPO_SKILLS"
echo "Global Skills: $GLOBAL_SKILLS"
echo "Dry Run: $DRY_RUN"
echo "Force: $FORCE"
echo ""

# Create global directory if needed
if [[ ! -d "$GLOBAL_SKILLS" ]]; then
    echo "Creating global skills directory..."
    $DRY_RUN || mkdir -p "$GLOBAL_SKILLS"
fi

# Counters
CREATED=0
SKIPPED=0
REPLACED=0
ERRORS=0

# Process each skill in repo
for skill_dir in "$REPO_SKILLS"/*/; do
    # Skip non-directories
    [[ ! -d "$skill_dir" ]] && continue

    skill_name=$(basename "$skill_dir")
    global_link="$GLOBAL_SKILLS/$skill_name"

    # Skip hidden directories
    [[ "$skill_name" == .* ]] && continue
    [[ "$skill_name" == "~" ]] && continue

    # Check if skill has SKILL.md
    if [[ ! -f "$skill_dir/SKILL.md" ]] && [[ ! -f "$skill_dir/skill.md" ]]; then
        echo "  ⚠ Skipping $skill_name (no SKILL.md)"
        ((SKIPPED++))
        continue
    fi

    # Check if symlink already exists
    if [[ -L "$global_link" ]]; then
        current_target=$(readlink "$global_link")
        if [[ "$current_target" == "$skill_dir" ]]; then
            # Already correct
            ((SKIPPED++))
            continue
        elif $FORCE; then
            echo "  ↻ Replacing: $skill_name"
            $DRY_RUN || rm -f "$global_link"
            $DRY_RUN || ln -s "$skill_dir" "$global_link"
            ((REPLACED++))
        else
            echo "  ⚠ Exists with different target: $skill_name"
            echo "    Current: $current_target"
            echo "    Expected: $skill_dir"
            ((SKIPPED++))
        fi
    elif [[ -e "$global_link" ]]; then
        # Exists but not a symlink
        echo "  ⚠ Blocked (not symlink): $skill_name"
        ((SKIPPED++))
    else
        # Create new symlink
        echo "  ✓ Creating: $skill_name"
        $DRY_RUN || ln -s "$skill_dir" "$global_link"
        ((CREATED++))
    fi
done

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "Summary:"
echo "  Created: $CREATED"
echo "  Replaced: $REPLACED"
echo "  Skipped: $SKIPPED"
echo "  Errors: $ERRORS"
echo "═══════════════════════════════════════════════════════════════"

# Show external skills count
EXTERNAL=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep -v "multi-agent-ralph-loop" | wc -l | tr -d ' ')
RALPH=$(find "$GLOBAL_SKILLS" -maxdepth 1 -type l -exec readlink {} \; 2>/dev/null | grep "multi-agent-ralph-loop" | wc -l | tr -d ' ')

echo ""
echo "Global Skills Status:"
echo "  Ralph skills (symlinked): $RALPH"
echo "  External skills (preserved): $EXTERNAL"
echo "  Total: $((RALPH + EXTERNAL))"
