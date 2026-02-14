#!/bin/bash
# ============================================================================
# Agent Teams Integration Validator v2.88.0
# ============================================================================
# Validates that all major skills have Agent Teams integration
# Run: ./scripts/validate-agent-teams-integration.sh
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SKILLS_DIR="$PROJECT_ROOT/.claude/skills"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Skills that MUST have Agent Teams integration
REQUIRED_SKILLS=(
    "orchestrator"
    "parallel"
    "loop"
    "bugs"
    "security"
    "gates"
    "adversarial"
    "clarify"
    "retrospective"
    "code-reviewer"
    "quality-gates-parallel"
    "glm5-parallel"
)

# Optional skills (nice to have)
OPTIONAL_SKILLS=(
    "glm5"
    "edd"
    "retrospective"
    "audit"
)

errors=0
warnings=0
passed=0

echo "========================================"
echo "Agent Teams Integration Validator v2.88.0"
echo "========================================"
echo ""

# Check custom subagents exist
echo "## Custom Subagents Check"
for agent in ralph-coder ralph-reviewer ralph-tester ralph-researcher; do
    agent_path="$PROJECT_ROOT/.claude/agents/${agent}.md"
    if [[ -f "$agent_path" ]]; then
        if grep -q "VERSION.*2.88" "$agent_path" && grep -q "Model Inheritance" "$agent_path"; then
            echo -e "  ${GREEN}✓${NC} $agent (v2.88.0 with model inheritance)"
        else
            echo -e "  ${YELLOW}!${NC} $agent (missing VERSION 2.88.0 or model inheritance)"
            ((warnings++))
        fi
    else
        echo -e "  ${RED}✗${NC} $agent (MISSING)"
        ((errors++))
    fi
done
echo ""

# Check Agent Teams hooks exist and are executable
echo "## Agent Teams Hooks Check"
for hook in teammate-idle-quality-gate.sh task-completed-quality-gate.sh ralph-subagent-start.sh ralph-subagent-stop.sh; do
    hook_path="$PROJECT_ROOT/.claude/hooks/${hook}"
    if [[ -f "$hook_path" ]]; then
        if [[ -x "$hook_path" ]]; then
            echo -e "  ${GREEN}✓${NC} $hook (executable)"
        else
            echo -e "  ${YELLOW}!${NC} $hook (not executable)"
            ((warnings++))
        fi
    else
        echo -e "  ${RED}✗${NC} $hook (MISSING)"
        ((errors++))
    fi
done
echo ""

# Check skills have Agent Teams documentation
echo "## Skills Agent Teams Integration Check"

check_skill_agent_teams() {
    local skill_name="$1"
    local required="$2"
    local skill_path=""

    # Check both SKILL.md and skill.md variations
    if [[ -f "$SKILLS_DIR/$skill_name/SKILL.md" ]]; then
        skill_path="$SKILLS_DIR/$skill_name/SKILL.md"
    elif [[ -f "$SKILLS_DIR/$skill_name/skill.md" ]]; then
        skill_path="$SKILLS_DIR/$skill_name/skill.md"
    else
        if [[ "$required" == "required" ]]; then
            echo -e "  ${RED}✗${NC} $skill_name (SKILL.md not found)"
            ((errors++))
        fi
        return 1
    fi

    # Check for Agent Teams integration
    if grep -qi "Agent Teams" "$skill_path" && grep -qi "TeamCreate\|spawn\|parallel\|subagent" "$skill_path"; then
        echo -e "  ${GREEN}✓${NC} $skill_name (has Agent Teams integration)"
        ((passed++))
    else
        if [[ "$required" == "required" ]]; then
            echo -e "  ${RED}✗${NC} $skill_name (missing Agent Teams integration)"
            ((errors++))
        else
            echo -e "  ${YELLOW}!${NC} $skill_name (optional - no Agent Teams integration)"
            ((warnings++))
        fi
    fi
}

# Check required skills
echo "Required skills:"
for skill in "${REQUIRED_SKILLS[@]}"; do
    check_skill_agent_teams "$skill" "required"
done

echo ""
echo "Optional skills:"
for skill in "${OPTIONAL_SKILLS[@]}"; do
    check_skill_agent_teams "$skill" "optional"
done

echo ""
echo "========================================"
echo "## Summary"
echo "========================================"
echo -e "Passed:   ${GREEN}$passed${NC}"
echo -e "Warnings: ${YELLOW}$warnings${NC}"
echo -e "Errors:   ${RED}$errors${NC}"
echo ""

if [[ $errors -gt 0 ]]; then
    echo -e "${RED}VALIDATION FAILED${NC}: $errors error(s) found"
    exit 1
elif [[ $warnings -gt 0 ]]; then
    echo -e "${YELLOW}VALIDATION PASSED${NC} with $warnings warning(s)"
    exit 0
else
    echo -e "${GREEN}VALIDATION PASSED${NC}: All Agent Teams integrations verified"
    exit 0
fi
