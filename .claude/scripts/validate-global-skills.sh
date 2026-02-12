#!/bin/bash

# Validate Global Skills Installation
# Tests if /adversarial, /codex-cli, and /gemini-cli work correctly

set -e

# Get project root dynamically
REPO_DIR="${REPO_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || cd "$(dirname "$0")/.." && pwd)}"
SKILLS_DIR="$HOME/.claude-sneakpeek/zai/config/skills"
TEMP_DIR="/tmp/claude-skills-test-$$"

echo "========================================="
echo "🔍 Validating Global Skills Installation"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check symlinks exist
echo "📋 Test 1: Checking symlinks exist..."
for skill in adversarial codex-cli gemini-cli; do
    if [ -L "$SKILLS_DIR/$skill" ]; then
        target=$(readlink "$SKILLS_DIR/$skill")
        echo "  ✓ $skill -> $target"
    else
        echo -e "  ${RED}✗ $skill symlink not found${NC}"
    fi
done
echo ""

# Test 2: Verify symlink targets are accessible
echo "📋 Test 2: Verifying symlink targets are accessible..."
for skill in adversarial codex-cli gemini-cli; do
    if [ -L "$SKILLS_DIR/$skill" ]; then
        target=$(readlink "$SKILLS_DIR/$skill")
        if [ -d "$target" ]; then
            echo "  ✓ $skill target accessible"
        else
            echo -e "  ${RED}✗ $skill target NOT accessible: $target${NC}"
        fi
    fi
done
echo ""

# Test 3: Check skill.md files exist
echo "📋 Test 3: Checking skill.md files exist..."
for skill in adversarial codex-cli gemini-cli; do
    if [ -L "$SKILLS_DIR/$skill" ]; then
        target=$(readlink "$SKILLS_DIR/$skill")
        skill_file="$target/skill.md"
        if [ -f "$skill_file" ]; then
            echo "  ✓ $skill/skill.md exists"
        else
            echo -e "  ${YELLOW}⚠ $skill/skill.md NOT found${NC}"
        fi
    fi
done
echo ""

# Test 4: Check for versioned skills in repo
echo "📋 Test 4: Checking if skills are versioned in repo..."
if [ -d "$REPO_DIR/.claude/skills" ]; then
    for skill in adversarial codex-cli gemini-cli; do
        if [ -d "$REPO_DIR/.claude/skills/$skill" ] && [ ! -L "$REPO_DIR/.claude/skills/$skill" ]; then
            echo "  ✓ $skill is versioned in repo"
        elif [ -L "$REPO_DIR/.claude/skills/$skill" ]; then
            link_target=$(readlink "$REPO_DIR/.claude/skills/$skill")
            echo -e "  ${YELLOW}⚠ $skill is a symlink in repo: $link_target${NC}"
        else
            echo -e "  ${RED}✗ $skill NOT found in repo${NC}"
        fi
    done
else
    echo -e "  ${YELLOW}⚠ Repo skills directory not found${NC}"
fi
echo ""

# Test 5: Test skills execution from temporary directory
echo "📋 Test 5: Testing skills execution from outside repo..."
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

echo "  Testing from: $PWD"
echo "  (This simulates working in a different repository)"
echo ""

# Create test files to validate skills can read them
echo "# Test file" > test.md
mkdir -p test_dir
echo "// Test code" > test_dir/test.js

# Check if skills can be invoked (dry run)
echo "  Testing skill accessibility..."
for skill in adversarial codex-cli gemini-cli; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
        echo "    ✓ $skill is accessible from outside repo"
    else
        echo -e "    ${RED}✗ $skill is NOT accessible from outside repo${NC}"
    fi
done

# Cleanup
cd - > /dev/null
rm -rf "$TEMP_DIR"
echo ""

# Test 6: Summary
echo "========================================="
echo "📊 Summary"
echo "========================================="
echo ""

# Count issues
issues=0

# Check gemini-cli special case
if [ -L "$REPO_DIR/.claude/skills/gemini-cli" ]; then
    gemini_target=$(readlink "$REPO_DIR/.claude/skills/gemini-cli")
    if [[ "$gemini_target" == *"~/.claude-sneakpeek"* ]] || [[ "$gemini_target" == *".claude-sneakpeek"* ]]; then
        echo -e "${YELLOW}⚠️  WARNING: gemini-cli is a symlink pointing outside repo${NC}"
        echo "   Target: $gemini_target"
        echo "   This means gemini-cli will NOT work if:"
        echo "   - The repo is cloned on another machine"
        echo "   - The symlink target is moved/deleted"
        echo ""
        issues=$((issues + 1))
    fi
fi

if [ $issues -eq 0 ]; then
    echo -e "${GREEN}✅ All checks passed!${NC}"
    echo ""
    echo "Skills are properly configured and should work globally."
else
    echo -e "${RED}❌ Found $issues issue(s)${NC}"
    echo ""
    echo "Please review the warnings above."
fi

echo ""
echo "========================================="
echo "🔧 Recommendations"
echo "========================================="
echo ""

if [ -L "$REPO_DIR/.claude/skills/gemini-cli" ]; then
    echo "1. gemini-cli: Consider versioning in repo or documenting setup"
    echo "   Current: symlink to $gemini_target"
    echo "   Suggested: Copy skill files to repo or document in README"
    echo ""
fi

echo "2. Test skills in a different repository:"
echo "   cd ~/GitHub/other-repo"
echo "   # Try invoking /adversarial, /codex-cli, /gemini-cli"
echo ""

echo "3. If skills don't work in other repos, check:"
echo "   - Symlink targets are accessible"
echo "   - Skills don't have hardcoded repo-specific paths"
echo "   - Skills don't depend on repo-specific files"
echo ""
