#!/bin/bash
# migrate-commands-to-skills.sh
# Multi-Agent Ralph v2.36 - Migration Script
# Converts commands from .claude/commands/ to skills in ~/.claude/skills/

set -euo pipefail

SOURCE_DIR="${HOME}/.claude/commands"
DEST_DIR="${HOME}/.claude/skills"
LOG_FILE="/tmp/migration-$(date +%Y%m%d-%H%M%S).log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Skills that already exist and should be skipped
ALREADY_MIGRATED=(
    "orchestrator"
    "clarify"
    "gates"
    "adversarial"
    "loop"
    "retrospective"
    "parallel"
)

# Commands to skip (blender/checkpoint are project-specific)
SKIP_COMMANDS=(
    "blender-3d"
    "blender-status"
    "checkpoint-clear"
    "checkpoint-list"
    "checkpoint-restore"
    "checkpoint-save"
    "image-to-3d"
    "skill"  # Meta command
    "commands"  # Meta command
)

should_skip() {
    local name="$1"
    for skip in "${ALREADY_MIGRATED[@]}" "${SKIP_COMMANDS[@]}"; do
        if [[ "$name" == "$skip" ]]; then
            return 0
        fi
    done
    return 1
}

skill_exists() {
    local name="$1"
    [[ -f "${DEST_DIR}/${name}/SKILL.md" ]]
}

convert_frontmatter() {
    local input_file="$1"
    local name="$2"

    # Extract description from frontmatter or first paragraph
    local desc=""
    desc=$(grep -E "^description:" "$input_file" | sed 's/^description: *//' | tr -d '"' || true)

    if [[ -z "$desc" ]]; then
        # Try to get from first paragraph after frontmatter
        desc=$(sed -n '/^---$/,/^---$/d; /^#/d; /^$/d; p' "$input_file" | head -5 | tr '\n' ' ' | cut -c1-200)
    fi

    # If still empty, create generic description
    if [[ -z "$desc" ]]; then
        desc="Skill migrated from $name command. Use when relevant to $name functionality."
    fi

    # Add "Use when:" triggers if not present
    if [[ ! "$desc" =~ "Use when" ]]; then
        desc="${desc} Use when: (1) /${name} is invoked, (2) task relates to ${name} functionality."
    fi

    echo "$desc"
}

migrate_command() {
    local cmd_file="$1"
    local name=$(basename "$cmd_file" .md)

    if should_skip "$name"; then
        info "Skipping $name (already migrated or project-specific)"
        return 0
    fi

    if skill_exists "$name"; then
        info "Skill $name already exists, checking for updates..."
        return 0
    fi

    log "Migrating command: $name"

    # Create skill directory
    mkdir -p "${DEST_DIR}/${name}"

    # Extract description
    local desc=$(convert_frontmatter "$cmd_file" "$name")

    # Determine if needs context: fork
    local context=""
    if [[ "$name" =~ (security|audit|gates|test|review) ]]; then
        context="context: fork"
    fi

    # Create SKILL.md with proper frontmatter
    cat > "${DEST_DIR}/${name}/SKILL.md" << EOF
---
name: ${name}
description: "${desc}"
user-invocable: true
${context}
---

EOF

    # Append body content (everything after frontmatter)
    sed -n '/^---$/,/^---$/!p' "$cmd_file" | tail -n +2 >> "${DEST_DIR}/${name}/SKILL.md"

    log "Created skill: ${DEST_DIR}/${name}/SKILL.md"
}

main() {
    echo ""
    echo "========================================"
    echo " Multi-Agent Ralph v2.36"
    echo " Commands -> Skills Migration"
    echo "========================================"
    echo ""

    if [[ ! -d "$SOURCE_DIR" ]]; then
        error "Source directory not found: $SOURCE_DIR"
        exit 1
    fi

    local total=0
    local migrated=0
    local skipped=0
    local existing=0

    for cmd in "$SOURCE_DIR"/*.md; do
        [[ -f "$cmd" ]] || continue
        ((total++))

        name=$(basename "$cmd" .md)

        if should_skip "$name"; then
            ((skipped++))
        elif skill_exists "$name"; then
            ((existing++))
        else
            migrate_command "$cmd"
            ((migrated++))
        fi
    done

    echo ""
    echo "========================================"
    echo " Migration Summary"
    echo "========================================"
    echo " Total commands:  $total"
    echo " Migrated:        $migrated"
    echo " Already exist:   $existing"
    echo " Skipped:         $skipped"
    echo " Log file:        $LOG_FILE"
    echo "========================================"
    echo ""

    if [[ $migrated -gt 0 ]]; then
        log "Migration complete. Skills created in: $DEST_DIR"
        log "Remember to verify the migrated skills."
    else
        info "No new migrations needed."
    fi
}

# Run with --dry-run to preview
if [[ "${1:-}" == "--dry-run" ]]; then
    echo "DRY RUN - No changes will be made"
    for cmd in "$SOURCE_DIR"/*.md; do
        [[ -f "$cmd" ]] || continue
        name=$(basename "$cmd" .md)

        if should_skip "$name"; then
            echo "  SKIP: $name"
        elif skill_exists "$name"; then
            echo "  EXISTS: $name"
        else
            echo "  MIGRATE: $name"
        fi
    done
    exit 0
fi

main "$@"
