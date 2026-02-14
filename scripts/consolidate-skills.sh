#!/bin/bash
#
# Consolidate Skills v2.87.0
# Migrates external skill symlinks to real directories in ~/.claude/skills
# Creates backup and sets up ~/.agents/skills symlinks
#
# Architecture:
#   ~/.claude/skills/
#     ├── ralph-skill-* -> /repo/.claude/skills/*  (symlinks, kept)
#     └── external-skill-*/                        (real dirs, converted from symlinks)
#
#   ~/.agents/skills/
#     └── * -> ~/.claude/skills/*                  (symlinks to all skills)
#
#   ~/backup/claude-skills/
#     └── external-skill-*/                       (backup of originals)
#
# Usage: ./scripts/consolidate-skills.sh [--dry-run] [--backup-only]
#

set -e

DRY_RUN=false
BACKUP_ONLY=false

for arg in "$@"; do
    case $arg in
        --dry-run|-n) DRY_RUN=true ;;
        --backup-only) BACKUP_ONLY=true ;;
    esac
done

GLOBAL_SKILLS="$HOME/.claude/skills"
AGENTS_SKILLS="$HOME/.agents/skills"
BACKUP_DIR="$HOME/backup/claude-skills"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_SKILLS="$REPO_ROOT/.claude/skills"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     Skills Consolidation v2.87.0                             ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Global Skills: $GLOBAL_SKILLS"
echo "Agents Skills: $AGENTS_SKILLS"
echo "Backup Dir: $BACKUP_DIR"
echo "Dry Run: $DRY_RUN"
echo ""

# Counters
COPIED=0
SKIPPED=0
BROKEN=0
RALPH_PRESERVED=0

#######################################
# Step 1: Create backup directory
#######################################
echo -e "${BLUE}[Step 1] Creating backup directory${NC}"

if $DRY_RUN; then
    echo "  Would create: $BACKUP_DIR"
else
    mkdir -p "$BACKUP_DIR"
    echo "  ✓ Created: $BACKUP_DIR"
fi

#######################################
# Step 2: Backup and convert external symlinks
#######################################
echo ""
echo -e "${BLUE}[Step 2] Processing external skill symlinks${NC}"

for link in "$GLOBAL_SKILLS"/*; do
    [[ ! -L "$link" ]] && continue

    skill_name=$(basename "$link")
    target=$(readlink "$link")

    # Skip Ralph skills (keep as symlinks)
    if [[ "$target" == *"multi-agent-ralph-loop"* ]]; then
        ((RALPH_PRESERVED++))
        continue
    fi

    # Check if target exists
    if [[ ! -d "$target" ]]; then
        echo "  ⚠ Broken: $skill_name (target not found)"
        ((BROKEN++))

        # Remove broken symlink
        if ! $DRY_RUN; then
            rm -f "$link"
        fi
        continue
    fi

    # Backup original
    if [[ ! -d "$BACKUP_DIR/$skill_name" ]]; then
        if $DRY_RUN; then
            echo "  Would backup: $skill_name"
        else
            cp -r "$target" "$BACKUP_DIR/$skill_name"
            echo "  ✓ Backed up: $skill_name"
        fi
    fi

    if $BACKUP_ONLY; then
        ((SKIPPED++))
        continue
    fi

    # Convert symlink to real directory
    if $DRY_RUN; then
        echo "  Would convert: $skill_name"
    else
        # Remove symlink
        rm -f "$link"
        # Copy real files
        cp -r "$target" "$link"
        echo "  ✓ Converted: $skill_name"
    fi
    ((COPIED++))
done

#######################################
# Step 3: Setup ~/.agents/skills symlinks
#######################################
if ! $BACKUP_ONLY; then
    echo ""
    echo -e "${BLUE}[Step 3] Setting up ~/.agents/skills symlinks${NC}"

    if $DRY_RUN; then
        echo "  Would create: $AGENTS_SKILLS"
    else
        mkdir -p "$AGENTS_SKILLS"
        echo "  ✓ Created: $AGENTS_SKILLS"
    fi

    AGENTS_CREATED=0
    for skill_dir in "$GLOBAL_SKILLS"/*; do
        [[ ! -e "$skill_dir" ]] && continue

        skill_name=$(basename "$skill_dir")
        agents_link="$AGENTS_SKILLS/$skill_name"

        # Skip if already correct
        if [[ -L "$agents_link" ]]; then
            current=$(readlink "$agents_link")
            if [[ "$current" == "$GLOBAL_SKILLS/$skill_name" ]]; then
                continue
            fi
        fi

        if $DRY_RUN; then
            echo "  Would link: $skill_name"
        else
            rm -f "$agents_link" 2>/dev/null
            ln -s "$GLOBAL_SKILLS/$skill_name" "$agents_link"
            ((AGENTS_CREATED++))
        fi
    done

    echo "  ✓ Created $AGENTS_CREATED symlinks in ~/.agents/skills/"
fi

#######################################
# Summary
#######################################
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo "Summary:"
echo "  Ralph skills preserved: $RALPH_PRESERVED"
echo "  External skills converted: $COPIED"
echo "  Broken symlinks removed: $BROKEN"
echo "  Backup location: $BACKUP_DIR"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

if $DRY_RUN; then
    echo ""
    echo "This was a dry run. Run without --dry-run to apply changes."
fi
