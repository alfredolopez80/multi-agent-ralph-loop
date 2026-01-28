#!/usr/bin/env bash
# Install Multi-Agent Ralph Skills Globally
# VERSION: 2.0.0
#
# This script installs all skills from the repository to the global Claude Code skills directory.
# Skills are converted to the correct format (SKILL.md with proper YAML frontmatter).
#
# USAGE:
#   ./install-global-skills.sh [--force] [--list] [--help]
#
# OPTIONS:
#   --force    - Reinstall all skills (remove existing symlinks)
#   --list     - List all skills that would be installed
#   --help     - Show this help message
#
# FORMAT REQUIREMENTS:
#   - File: SKILL.md (uppercase)
#   - Frontmatter: name, description (NO allowed-tools, NO model restrictions)
#   - Purpose: Universal skills that work with any tool and any model
#
# Part of Multi-Agent Ralph v2.74.2

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_SKILLS_DIR="${PROJECT_ROOT}/.claude/skills"
TARGET_SKILLS_DIR="${HOME}/.claude-sneakpeek/zai/config/skills"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Options
FORCE_INSTALL=false
LIST_ONLY=false

# ============================================================================
# FUNCTIONS
# ============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local color=""

    case "$level" in
        INFO)  color="$CYAN" ;;
        SUCCESS) color="$GREEN" ;;
        WARNING) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        *)     color="$RESET" ;;
    esac

    echo -e "${color}[${level}]${RESET} ${message}"
}

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${RESET}   Global Skills Installation Script v2.0.0            ${BLUE}║${RESET}"
    echo -e "${BLUE}║${RESET}   Multi-Agent Ralph v2.74.2                          ${BLUE}║${RESET}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${CYAN}▶ $1${RESET}"
}

# Get all skill directories
get_skills() {
    find "$SOURCE_SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
        basename "$dir"
    done | sort
}

# Find skill definition file
find_skill_definition() {
    local skill_dir="$1"

    # Priority: SKILL.md > skill.md > CLAUDE.md > scripts/CLAUDE.md
    if [[ -f "${skill_dir}/SKILL.md" ]]; then
        echo "SKILL.md"
        return 0
    elif [[ -f "${skill_dir}/skill.md" ]]; then
        echo "skill.md"
        return 0
    elif [[ -f "${skill_dir}/CLAUDE.md" ]]; then
        echo "CLAUDE.md"
        return 0
    elif [[ -f "${skill_dir}/scripts/CLAUDE.md" ]]; then
        echo "scripts/CLAUDE.md"
    fi

    echo "none"
    return 1
}

# Extract skill name from definition
extract_skill_name() {
    local skill_file="$1"
    local skill_dir="$1"

    # If skill_file is actually a directory, use it directly
    if [[ -d "$skill_file" ]]; then
        skill_dir="$skill_file"
    else
        # Get parent directory (skill directory)
        skill_dir="$(dirname "$skill_file")"
        # If we're in scripts/ subdirectory, go up one more level
        if [[ "$(basename "$skill_dir")" == "scripts" ]]; then
            skill_dir="$(dirname "$skill_dir")"
        fi
    fi

    # Always use directory name as the skill name
    basename "$skill_dir"
}

# Extract skill description from definition
extract_skill_description() {
    local skill_file="$1"

    # Try to get description from frontmatter
    local description
    description=$(grep -m1 "^description:" "$skill_file" 2>/dev/null | sed 's/description: *//' | tr -d '"'"'" | tr -d '"')

    # Fallback to generic description
    if [[ -z "$description" ]]; then
        # Get skill name
        local skill_name
        skill_name=$(extract_skill_name "$skill_file")
        description="Custom skill for ${skill_name}"
    fi

    echo "$description"
}

# Convert any skill definition to proper SKILL.md format
convert_to_skill_format() {
    local skill_dir="$1"
    local skill_name="$(basename "$skill_dir")"
    local output_file="${skill_dir}/SKILL.md"

    local def_file
    def_file=$(find_skill_definition "$skill_dir")

    if [[ "$def_file" == "none" ]]; then
        log WARNING "No valid definition found for: ${skill_name}"
        return 1
    fi

    local input_file="${skill_dir}/${def_file}"

    # Extract name and description
    local name
    local description
    name=$(extract_skill_name "$input_file")
    description=$(extract_skill_description "$input_file")

    log INFO "Creating SKILL.md for: ${skill_name}"

    # Create proper SKILL.md with clean frontmatter
    cat > "$output_file" <<EOF
---
name: ${name}
description: ${description}
---
EOF

    # Append content from input file (skip frontmatter and VERSION lines)
    awk '
    BEGIN { in_frontmatter = 0; content_started = 0 }
    /^---/ {
        if (!in_frontmatter) { in_frontmatter = 1; next }
        else { in_frontmatter = 0; next }
    }
    /^# VERSION:/ { next }
    {
        if (!in_frontmatter) {
            if (!content_started) {
                # Skip leading empty lines
                if (NF > 0) content_started = 1
            }
            if (content_started) print
        }
    }
    ' "$input_file" >> "$output_file"

    log SUCCESS "Created: ${output_file}"
    return 0
}

# Install a single skill
install_skill() {
    local skill_name="$1"
    local source_dir="${SOURCE_SKILLS_DIR}/${skill_name}"
    local target_link="${TARGET_SKILLS_DIR}/${skill_name}"

    # Check if source exists
    if [[ ! -d "$source_dir" ]]; then
        log WARNING "Source directory not found: ${skill_name}"
        return 1
    fi

    # Convert to SKILL.md format if needed
    if [[ ! -f "${source_dir}/SKILL.md" ]]; then
        convert_to_skill_format "$source_dir" || return 1
    fi

    # Remove existing symlink if force is enabled
    if [[ -L "$target_link" ]]; then
        if [[ "$FORCE_INSTALL" == true ]]; then
            rm "$target_link"
            log INFO "Removed existing symlink: ${skill_name}"
        else
            log INFO "Skill already installed: ${skill_name}"
            return 0
        fi
    fi

    # Create symlink
    log INFO "Installing: ${skill_name}"
    ln -s "$source_dir" "$target_link"

    if [[ -L "$target_link" ]]; then
        log SUCCESS "✓ ${skill_name}"
        return 0
    else
        log ERROR "Failed to create symlink for: ${skill_name}"
        return 1
    fi
}

# List all skills
list_skills() {
    print_step "Available Skills"

    echo ""
    printf "%-35s %-15s %s\n" "Skill Name" "Definition" "Status"
    printf "%-35s %-15s %s\n" "-----------" "-----------" "------"

    get_skills | while read -r skill_name; do
        local source_dir="${SOURCE_SKILLS_DIR}/${skill_name}"
        local def_file
        def_file=$(find_skill_definition "$source_dir")

        local status="✓ Valid"
        if [[ "$def_file" == "none" ]]; then
            status="⚠ No definition"
        fi

        printf "%-35s %-15s %s\n" "$skill_name" "$def_file" "$status"
    done
}

# ============================================================================
# MAIN
# ============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        --list)
            LIST_ONLY=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force] [--list] [--help]"
            echo ""
            echo "Options:"
            echo "  --force    - Reinstall all skills (remove existing symlinks)"
            echo "  --list     - List all available skills"
            echo "  --help     - Show this help message"
            echo ""
            echo "Format Requirements:"
            echo "  - File: SKILL.md (uppercase)"
            echo "  - Frontmatter: name, description only"
            echo "  - NO allowed-tools (works with any tool)"
            echo "  - NO model restrictions (works with any model)"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Run installation
print_header

if [[ "$LIST_ONLY" == true ]]; then
    list_skills
    exit 0
fi

print_step "Installing skills from repository to global directory"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_SKILLS_DIR"

log INFO "Source: ${SOURCE_SKILLS_DIR}"
log INFO "Target: ${TARGET_SKILLS_DIR}"

# Count stats
total=0
installed=0
failed=0

get_skills | while read -r skill_name; do
    total=$((total + 1))

    if install_skill "$skill_name"; then
        installed=$((installed + 1))
    else
        failed=$((failed + 1))
    fi
done

# Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║${RESET}   Skills Installation Complete!                          ${GREEN}║${RESET}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo "Global skills location: ${TARGET_SKILLS_DIR}"
echo ""
echo "To use a skill:"
echo "  /skill-name"
echo ""
echo "Examples:"
echo "  /orchestrator"
echo "  /codex"
echo "  /adversarial"
echo "  /compact"
echo "  /context7"
echo ""
