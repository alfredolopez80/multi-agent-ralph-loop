#!/bin/bash
# fix-skills-global.sh - Fix skill symlinks for global availability
# Version: 1.0.0
# Part of Ralph Multi-Agent System

set -euo pipefail

# Configuration
PROJECT_DIR="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
GLOBAL_SKILLS_DIR="${HOME}/.claude-sneakpeek/zai/config/skills"
PROJECT_SKILLS_DIR="${PROJECT_DIR}/.claude/skills"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Skills that should be available globally
SKILLS=(
    "orchestrator"
    "gates"
    "readme"
    "audit"
    "bugs"
    "clarify"
    "loop"
    "parallel"
    "security"
    "testing-anti-patterns"
)

echo "=================================="
echo "Fixing Skill Symlinks"
echo "for Global Availability"
echo "=================================="
echo ""

# Verify directories exist
if [ ! -d "$PROJECT_SKILLS_DIR" ]; then
    log_error "Project skills directory not found: $PROJECT_SKILLS_DIR"
    exit 1
fi

if [ ! -d "$GLOBAL_SKILLS_DIR" ]; then
    log_error "Global skills directory not found: $GLOBAL_SKILLS_DIR"
    exit 1
fi

echo "Project: $PROJECT_DIR"
echo "Global:  $GLOBAL_SKILLS_DIR"
echo ""

for skill in "${SKILLS[@]}"; do
    SYMLINK="${GLOBAL_SKILLS_DIR}/${skill}"
    TARGET="${PROJECT_SKILLS_DIR}/${skill}"

    # Check if skill exists in project
    if [ ! -d "$TARGET" ]; then
        log_warn "${skill}: Does not exist in project (skipping)"
        continue
    fi

    # Remove existing symlink if it exists
    if [ -L "$SYMLINK" ]; then
        echo -n "Removing existing symlink: ${skill}... "
        rm "$SYMLINK"
        log_info "Done"
    elif [ -e "$SYMLINK" ]; then
        log_error "${skill}: File exists but is not a symlink (skipping)"
        continue
    fi

    # Create new symlink
    echo -n "Creating symlink: ${skill}... "
    ln -s "$TARGET" "$SYMLINK"

    # Verify
    if [ -L "$SYMLINK" ]; then
        log_info "Success"
    else
        log_error "Failed"
    fi
done

echo ""
echo "=================================="
echo "Verification"
echo "=================================="
echo ""

# Show all symlinks in global directory
echo "Global skill symlinks:"
ls -la "$GLOBAL_SKILLS_DIR" | grep "^l" | grep -E "orchestrator|gates|readme|audit|bugs|clarify|loop|parallel|security|testing" || echo "No symlinks found"

echo ""
echo "=================================="
echo "Summary"
echo "=================================="
echo ""

# Count successful symlinks
SYMLINK_COUNT=$(ls -la "$GLOBAL_SKILLS_DIR" | grep "^l" | wc -l | tr -d ' ')
TOTAL_SKILLS=${#SKILLS[@]}

echo "Total skills processed: ${TOTAL_SKILLS}"
echo "Successful symlinks: ${SYMLINK_COUNT}"
echo ""

if [ "$SYMLINK_COUNT" -eq "$TOTAL_SKILLS" ]; then
    log_info "All skills are now available globally!"
    echo ""
    echo "You can now use these skills from any project:"
    echo "  /orchestrator, /gates, /readme, /audit, /bugs, etc."
else
    log_warn "Some skills could not be linked. Check output above."
fi

echo ""
echo "Done!"
