#!/bin/bash

# Validate All Multi-Agent Ralph Loop Skills
# Tests if all skills used by /orchestrator are properly configured

set -e

REPO_DIR="$PROJECT_ROOT"
SKILLS_REPO_DIR="$REPO_DIR/.claude/skills"
SKILLS_GLOBAL_DIR="$HOME/.claude-sneakpeek/zai/config/skills"
TEMP_DIR="/tmp/ralph-skills-test-$$"

echo "========================================="
echo "🔍 Multi-Agent Ralph Loop Skills Validator"
echo "========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# All skills in the repo
ALL_SKILLS=(
    "adversarial"
    "ask-questions-if-underspecified"
    "attack-mutator"
    "audit"
    "bugs"
    "clarify"
    "code-reviewer"
    "codex-cli"
    "compact"
    "context7-usage"
    "crafting-effective-readmes"
    "defense-profiler"
    "edd"
    "gates"
    "gemini-cli"
    "glm-mcp"
    "kaizen"
    "loop"
    "minimax"
    "minimax-mcp-usage"
    "openai-docs"
    "orchestrator"
    "parallel"
    "quality-gates-parallel"
    "retrospective"
    "security"
    "smart-fork"
    "tap-explorer"
    "task-classifier"
    "task-visualizer"
    "testing-anti-patterns"
    "vercel-react-best-practices"
    "worktree-pr"
)

# Core skills used by orchestrator
CORE_SKILLS=(
    "orchestrator"
    "task-classifier"
    "adversarial"
    "codex-cli"
    "gemini-cli"
    "loop"
    "parallel"
    "gates"
    "clarify"
    "retrospective"
)

echo -e "${CYAN}📊 Repository Skills: ${#ALL_SKILLS[@]} total${NC}"
echo -e "${CYAN}🎯 Core Orchestrator Skills: ${#CORE_SKILLS[@]}${NC}"
echo ""

# Test 1: Check which skills are versioned in repo
echo "========================================="
echo "📋 Test 1: Skills Versioned in Repository"
echo "========================================="
echo ""

repo_skills=0
for skill in "${ALL_SKILLS[@]}"; do
    skill_dir="$SKILLS_REPO_DIR/$skill"
    if [ -d "$skill_dir" ] && [ ! -L "$skill_dir" ]; then
        skill_file="$skill_dir/skill.md"
        if [ -f "$skill_file" ]; then
            echo -e "  ${GREEN}✓${NC} $skill (versioned)"
            repo_skills=$((repo_skills + 1))
        else
            echo -e "  ${YELLOW}⚠${NC} $skill (missing skill.md)"
        fi
    elif [ -L "$skill_dir" ]; then
        echo -e "  ${YELLOW}⚠${NC} $skill (symlink in repo: $(readlink $skill_dir))"
    else
        echo -e "  ${RED}✗${NC} $skill (not found)"
    fi
done

echo ""
echo -e "${BLUE}Summary: $repo_skills/${#ALL_SKILLS[@]} skills properly versioned${NC}"
echo ""

# Test 2: Check which skills are globally installed
echo "========================================="
echo "📋 Test 2: Skills Installed Globally"
echo "========================================="
echo ""

global_skills=0
symlink_skills=0
copy_skills=0

for skill in "${ALL_SKILLS[@]}"; do
    global_path="$SKILLS_GLOBAL_DIR/$skill"
    if [ -e "$global_path" ]; then
        if [ -L "$global_path" ]; then
            target=$(readlink "$global_path")
            if [[ "$target" == *"$REPO_DIR"* ]]; then
                echo -e "  ${GREEN}✓${NC} $skill (symlink → repo)"
                symlink_skills=$((symlink_skills + 1))
            else
                echo -e "  ${YELLOW}⚠${NC} $skill (symlink → external: $target)"
            fi
        elif [ -d "$global_path" ]; then
            echo -e "  ${CYAN}⊞${NC} $skill (copied)"
            copy_skills=$((copy_skills + 1))
        fi
        global_skills=$((global_skills + 1))
    else
        echo -e "  ${RED}✗${NC} $skill (not installed globally)"
    fi
done

echo ""
echo -e "${BLUE}Summary: $global_skills/${#ALL_SKILLS[@]} skills available globally${NC}"
echo "  - $symlink_skills symlinked to repo"
echo "  - $copy_skills copied"
echo ""

# Test 3: Validate core orchestrator skills
echo "========================================="
echo "📋 Test 3: Core Orchestrator Skills"
echo "========================================="
echo ""

core_issues=0

for skill in "${CORE_SKILLS[@]}"; do
    skill_dir="$SKILLS_REPO_DIR/$skill"
    global_path="$SKILLS_GLOBAL_DIR/$skill"

    # Check if versioned in repo
    if [ ! -d "$skill_dir" ] || [ -L "$skill_dir" ]; then
        echo -e "  ${RED}✗${NC} $skill - NOT versioned in repo"
        core_issues=$((core_issues + 1))
        continue
    fi

    # Check if available globally
    if [ ! -e "$global_path" ]; then
        echo -e "  ${RED}✗${NC} $skill - NOT available globally"
        core_issues=$((core_issues + 1))
        continue
    fi

    # Check skill.md exists
    if [ ! -f "$skill_dir/skill.md" ]; then
        echo -e "  ${YELLOW}⚠${NC} $skill - missing skill.md"
        core_issues=$((core_issues + 1))
        continue
    fi

    echo -e "  ${GREEN}✓${NC} $skill - OK"
done

echo ""
if [ $core_issues -eq 0 ]; then
    echo -e "${GREEN}✅ All core orchestrator skills are properly configured!${NC}"
else
    echo -e "${RED}❌ Found $core_issues issue(s) with core skills${NC}"
fi
echo ""

# Test 4: Test accessibility from temporary directory
echo "========================================="
echo "📋 Test 4: Accessibility from Outside Repo"
echo "========================================="
echo ""

mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

accessible=0
for skill in "${CORE_SKILLS[@]}"; do
    if [ -e "$SKILLS_GLOBAL_DIR/$skill" ]; then
        accessible=$((accessible + 1))
    fi
done

cd - > /dev/null
rm -rf "$TEMP_DIR"

echo -e "${BLUE}Core skills accessible from any directory: $accessible/${#CORE_SKILLS[@]}${NC}"
echo ""

# Test 5: Check for inconsistencies
echo "========================================="
echo "📋 Test 5: Configuration Inconsistencies"
echo "========================================="
echo ""

inconsistencies=0

# Skills versioned but not globally available
for skill in "${ALL_SKILLS[@]}"; do
    if [ -d "$SKILLS_REPO_DIR/$skill" ] && [ ! -L "$SKILLS_REPO_DIR/$skill" ]; then
        if [ ! -e "$SKILLS_GLOBAL_DIR/$skill" ]; then
            echo -e "  ${YELLOW}⚠${NC} $skill - versioned but NOT globally available"
            inconsistencies=$((inconsistencies + 1))
        fi
    fi
done

# Skills globally available but not versioned
for skill in "${ALL_SKILLS[@]}"; do
    if [ -e "$SKILLS_GLOBAL_DIR/$skill" ]; then
        if [ ! -d "$SKILLS_REPO_DIR/$skill" ] || [ -L "$SKILLS_REPO_DIR/$skill" ]; then
            if [ -L "$SKILLS_REPO_DIR/$skill" ]; then
                # Check if symlink points outside repo
                target=$(readlink "$SKILLS_REPO_DIR/$skill")
                if [[ "$target" != *"$REPO_DIR"* ]]; then
                    echo -e "  ${YELLOW}⚠${NC} $skill - globally available but NOT versioned (external symlink)"
                    inconsistencies=$((inconsistencies + 1))
                fi
            fi
        fi
    fi
done

if [ $inconsistencies -eq 0 ]; then
    echo -e "${GREEN}✅ No configuration inconsistencies found${NC}"
else
    echo -e "${YELLOW}⚠️  Found $inconsistencies inconsistency(ies)${NC}"
fi
echo ""

# Test 6: Skill naming conventions
echo "========================================="
echo "📋 Test 6: Naming Conventions"
echo "========================================="
echo ""

naming_issues=0

for skill in "${ALL_SKILLS[@]}"; do
    skill_dir="$SKILLS_REPO_DIR/$skill"
    if [ -d "$skill_dir" ] && [ ! -L "$skill_dir" ]; then
        # Check for skill.md (not SKILL.md)
        if [ -f "$skill_dir/SKILL.md" ] && [ ! -f "$skill_dir/skill.md" ]; then
            echo -e "  ${YELLOW}⚠${NC} $skill - uses SKILL.md instead of skill.md"
            naming_issues=$((naming_issues + 1))
        fi
    fi
done

if [ $naming_issues -eq 0 ]; then
    echo -e "${GREEN}✅ All skills follow naming conventions${NC}"
else
    echo -e "${YELLOW}⚠️  Found $naming_issues naming issue(s)${NC}"
fi
echo ""

# Final Summary
echo "========================================="
echo "📊 Final Summary"
echo "========================================="
echo ""

echo -e "${CYAN}Repository:${NC}"
echo "  Total skills: ${#ALL_SKILLS[@]}"
echo "  Versioned: $repo_skills"
echo "  With skill.md: $repo_skills"
echo ""

echo -e "${CYAN}Global Installation:${NC}"
echo "  Available globally: $global_skills"
echo "  Symlinked to repo: $symlink_skills"
echo "  Copied: $copy_skills"
echo ""

echo -e "${CYAN}Core Orchestrator Skills:${NC}"
echo "  Total: ${#CORE_SKILLS[@]}"
echo "  Configured: $((${#CORE_SKILLS[@]} - core_issues))"
echo "  Issues: $core_issues"
echo ""

echo -e "${CYAN}Configuration:${NC}"
echo "  Inconsistencies: $inconsistencies"
echo "  Naming issues: $naming_issues"
echo ""

# Overall assessment
total_issues=$((core_issues + inconsistencies + naming_issues))

if [ $total_issues -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✅ ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}=========================================${NC}"
    echo ""
    echo "All multi-agent-ralph-loop skills are properly:"
    echo "  ✓ Versioned in repository"
    echo "  ✓ Available globally"
    echo "  ✓ Following naming conventions"
    echo "  ✓ Accessible from any directory"
    echo ""
    echo "You can use /orchestrator and all its sub-skills anywhere!"
else
    echo -e "${RED}=========================================${NC}"
    echo -e "${RED}❌ FOUND $total_issues ISSUE(S)${NC}"
    echo -e "${RED}=========================================${NC}"
    echo ""
    echo "Please review the issues above and fix them."
fi

echo ""
echo "========================================="
echo "🔧 Recommendations"
echo "========================================="
echo ""

if [ $global_skills -lt ${#ALL_SKILLS[@]} ]; then
    missing=$((${#ALL_SKILLS[@]} - global_skills))
    echo "1. Install missing skills globally:"
    echo "   cd ~/.claude-sneakpeek/zai/config/skills"
    echo "   ln -s $REPO_DIR/.claude/skills/{skill} {skill}"
    echo ""
fi

if [ $inconsistencies -gt 0 ]; then
    echo "2. Fix configuration inconsistencies:"
    echo "   - Ensure versioned skills are globally available"
    echo "   - Version skills that are only global"
    echo ""
fi

if [ $naming_issues -gt 0 ]; then
    echo "3. Fix naming issues:"
    echo "   - Rename SKILL.md → skill.md"
    echo ""
fi

echo "4. Test skills in a different repository:"
echo "   cd ~/GitHub/other-repo"
echo "   # Try invoking skills like /adversarial, /codex-cli, etc."
echo ""

echo "5. Run validation script regularly:"
echo "   bash $REPO_DIR/.claude/scripts/validate-all-orchestrator-skills.sh"
echo ""
