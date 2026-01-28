#!/usr/bin/env bash
# VERSION: 1.0.0
# Skills Verification Script for Multi-Agent Ralph
#
# DESCRIPTION:
#   Verifies that all required skills are properly installed and accessible.
#   Checks: codex-cli, gemini-cli, glm-mcp, readme
#
# USAGE:
#   ./verify-skills.sh

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Required skills
REQUIRED_SKILLS=(
    "codex-cli"
    "gemini-cli"
    "glm-mcp"
    "readme"
)

# Directories to check
SKILL_DIRS=(
    "${PROJECT_ROOT:-$(pwd)}/.claude/skills"
    "${HOME}/.claude-sneakpeek/zai/config/skills"
    "${HOME}/.claude-sneakpeek/zai/skills"
)

echo -e "${CYAN}=== Skills Verification for Multi-Agent Ralph ===${RESET}\n"

# Check each required skill
for skill in "${REQUIRED_SKILLS[@]}"; do
    echo -n "Checking ${skill}... "

    # Check if skill exists in project
    if [[ -f "${PROJECT_ROOT:-$(pwd)}/.claude/skills/${skill}/SKILL.md" ]]; then
        echo -e "${GREEN}✓ Found in project${RESET}"

        # Show symlink info if it's a symlink
        if [[ -L "${PROJECT_ROOT:-$(pwd)}/.claude/skills/${skill}" ]]; then
            target=$(readlink "${PROJECT_ROOT:-$(pwd)}/.claude/skills/${skill}")
            echo -e "  ${YELLOW}→ Symlink to: ${target}${RESET}"
        fi
    else
        echo -e "${RED}✗ Not found in project${RESET}"
    fi

    # Check if skill exists in zai config
    if [[ -f "${HOME}/.claude-sneakpeek/zai/config/skills/${skill}/SKILL.md" ]]; then
        echo -e "  ${GREEN}✓ Available in zai config${RESET}"
    fi

    # Check if skill exists in zai skills
    if [[ -f "${HOME}/.claude-sneakpeek/zai/skills/${skill}/SKILL.md" ]]; then
        echo -e "  ${GREEN}✓ Available in zai skills${RESET}"
    fi
done

echo -e "\n${CYAN}=== Summary ===${RESET}"

# Count available skills
available_count=0
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
for skill in "${REQUIRED_SKILLS[@]}"; do
    if [[ -f "${project_root}/.claude/skills/${skill}/SKILL.md" ]]; then
        available_count=$((available_count + 1))
    fi
done

echo -e "Skills available in project: ${GREEN}${available_count}/${#REQUIRED_SKILLS[@]}${RESET}"

if [[ $available_count -eq ${#REQUIRED_SKILLS[@]} ]]; then
    echo -e "\n${GREEN}✓ All required skills are installed!${RESET}"
    exit 0
else
    echo -e "\n${RED}✗ Some skills are missing${RESET}"
    exit 1
fi
