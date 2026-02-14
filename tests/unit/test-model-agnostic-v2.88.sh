#!/bin/bash
#
# Model-Agnostic Validation Test Suite v2.88.0
# Validates that skills, agents, and commands work with any configured model
#
# Usage: ./tests/unit/test-model-agnostic-v2.88.sh [-v]
#
# Validates:
# 1. Skills do NOT have --with-glm5 or --mmc flags
# 2. Agents do NOT have hardcoded model: field (inherit from settings)
# 3. Architecture is model-agnostic
#

# Note: We don't use 'set -e' because grep returns 1 when no match found
# Error handling is done manually in each test

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
VERBOSE=false

# Counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Parse arguments
[[ "$1" == "-v" || "$1" == "--verbose" ]] && VERBOSE=true

pass() { ((TESTS_PASSED++)); printf "${GREEN}.${NC}"; }
fail() { ((TESTS_FAILED++)); printf "${RED}F${NC}"; }
warn() { ((TESTS_WARNED++)); printf "${YELLOW}W${NC}"; }

print_test() {
    if $VERBOSE; then
        echo -e "  Test: $1"
    fi
}

print_header() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

#######################################
# Test 1: Skills - No model-specific flags
#######################################
test_skills_no_flags() {
    print_header "Test 1: Skills - No Model-Specific Flags"

    # Check for --with-glm5 in argument-hint
    print_test "Skills should NOT have --with-glm5 in argument-hint"
    local glm5_flags=$(grep -r "argument-hint.*--with-glm5" "$REPO_ROOT/.claude/skills" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    if [[ "$glm5_flags" -eq 0 ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Found --with-glm5 flags in skills${NC}"
        $VERBOSE && grep -r "argument-hint.*--with-glm5" "$REPO_ROOT/.claude/skills" 2>/dev/null || true
    fi

    # Check for --mmc in argument-hint
    print_test "Skills should NOT have --mmc in argument-hint"
    local mmc_flags=$(grep -r "argument-hint.*--mmc" "$REPO_ROOT/.claude/skills" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
    if [[ "$mmc_flags" -eq 0 ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Found --mmc flags in skills${NC}"
        $VERBOSE && grep -r "argument-hint.*--mmc" "$REPO_ROOT/.claude/skills" 2>/dev/null || true
    fi

    # Exception: /glm5 and /glm5-parallel skills are allowed to reference GLM-5
    print_test "/glm5 skill exists for specific GLM-5 evaluations"
    if [[ -f "$REPO_ROOT/.claude/skills/glm5/SKILL.md" ]]; then
        pass
    else
        warn
        echo -e "  ${YELLOW}⚠ /glm5 skill not found (optional)${NC}"
    fi

    print_test "/glm5-parallel skill exists for specific GLM-5 evaluations"
    if [[ -f "$REPO_ROOT/.claude/skills/glm5-parallel/SKILL.md" ]]; then
        pass
    else
        warn
        echo -e "  ${YELLOW}⚠ /glm5-parallel skill not found (optional)${NC}"
    fi
}

#######################################
# Test 2: Agents - No hardcoded model
#######################################
test_agents_no_hardcoded_model() {
    print_header "Test 2: Agents - No Hardcoded Model Field"

    # Ralph agents should NOT have model: field (inherit from settings)
    print_test "ralph-coder should NOT have hardcoded model"
    if grep -q "^model:" "$REPO_ROOT/.claude/agents/ralph-coder.md" 2>/dev/null; then
        fail
        echo -e "  ${RED}✗ ralph-coder.md has hardcoded model field${NC}"
    else
        pass
    fi

    print_test "ralph-reviewer should NOT have hardcoded model"
    if grep -q "^model:" "$REPO_ROOT/.claude/agents/ralph-reviewer.md" 2>/dev/null; then
        fail
        echo -e "  ${RED}✗ ralph-reviewer.md has hardcoded model field${NC}"
    else
        pass
    fi

    print_test "ralph-tester should NOT have hardcoded model"
    if grep -q "^model:" "$REPO_ROOT/.claude/agents/ralph-tester.md" 2>/dev/null; then
        fail
        echo -e "  ${RED}✗ ralph-tester.md has hardcoded model field${NC}"
    else
        pass
    fi

    print_test "ralph-researcher should NOT have hardcoded model"
    if grep -q "^model:" "$REPO_ROOT/.claude/agents/ralph-researcher.md" 2>/dev/null; then
        fail
        echo -e "  ${RED}✗ ralph-researcher.md has hardcoded model field${NC}"
    else
        pass
    fi

    # Agents should have comment explaining model inheritance
    print_test "Agents should have model inheritance comment"
    local agents_with_comment=$(grep -l "inherited from.*settings.json" "$REPO_ROOT/.claude/agents/ralph-"*.md 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$agents_with_comment" -ge 4 ]]; then
        pass
        $VERBOSE && echo "    → $agents_with_comment agents have model inheritance comment"
    else
        warn
        echo -e "  ${YELLOW}⚠ Only $agents_with_comment/4 agents have model inheritance comment${NC}"
    fi
}

#######################################
# Test 3: Architecture Documentation
#######################################
test_architecture_model_agnostic() {
    print_header "Test 3: Architecture - Model-Agnostic Documentation"

    # README should mention model-agnostic
    print_test "README.md should mention model-agnostic"
    if grep -qi "model-agnostic" "$REPO_ROOT/README.md" 2>/dev/null; then
        pass
    else
        fail
        echo -e "  ${RED}✗ README.md does not mention model-agnostic${NC}"
    fi

    # README should NOT have --with-glm5 examples (but can mention removal in docs)
    print_test "README.md should NOT have --with-glm5 usage examples"
    # Check for usage examples (not documentation about removal)
    local usage_examples=$(grep -E "(orchestrator|loop|security).+\-\-with-glm5" "$REPO_ROOT/README.md" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$usage_examples" -eq 0 ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ README.md has --with-glm5 usage examples${NC}"
        $VERBOSE && grep -E "(orchestrator|loop|security).+\-\-with-glm5" "$REPO_ROOT/README.md" 2>/dev/null
    fi

    # CLAUDE.md should mention model configuration
    print_test "CLAUDE.md should mention model routing or configuration"
    if grep -qE "(model|Model)" "$REPO_ROOT/CLAUDE.md" 2>/dev/null; then
        pass
    else
        warn
        echo -e "  ${YELLOW}⚠ CLAUDE.md does not mention model configuration${NC}"
    fi
}

#######################################
# Test 4: Skills Frontmatter Format
#######################################
test_skills_frontmatter() {
    print_header "Test 4: Skills Frontmatter - Model-Agnostic Format"

    # Check orchestrator skill
    print_test "orchestrator SKILL.md has correct frontmatter"
    local orch_hint=$(grep "^argument-hint:" "$REPO_ROOT/.claude/skills/orchestrator/SKILL.md" 2>/dev/null || echo "")
    if echo "$orch_hint" | grep -qv "\-\-with-glm5"; then
        pass
    else
        fail
        echo -e "  ${RED}✗ orchestrator still has --with-glm5${NC}"
    fi

    # Check loop skill
    print_test "loop SKILL.md has correct frontmatter"
    local loop_hint=$(grep "^argument-hint:" "$REPO_ROOT/.claude/skills/loop/SKILL.md" 2>/dev/null || echo "")
    if echo "$loop_hint" | grep -qv "\-\-with-glm5"; then
        pass
    else
        fail
        echo -e "  ${RED}✗ loop still has --with-glm5${NC}"
    fi

    # Skills should have v2.88 version
    print_test "orchestrator SKILL.md has VERSION 2.88"
    if grep -q "# VERSION: 2.88" "$REPO_ROOT/.claude/skills/orchestrator/SKILL.md" 2>/dev/null; then
        pass
    else
        warn
        echo -e "  ${YELLOW}⚠ orchestrator not at v2.88${NC}"
    fi

    print_test "loop SKILL.md has VERSION 2.88"
    if grep -q "# VERSION: 2.88" "$REPO_ROOT/.claude/skills/loop/SKILL.md" 2>/dev/null; then
        pass
    else
        warn
        echo -e "  ${YELLOW}⚠ loop not at v2.88${NC}"
    fi
}

#######################################
# Test 5: Scripts Validation
#######################################
test_scripts_model_agnostic() {
    print_header "Test 5: Scripts - Model-Agnostic Validation"

    # glm5-teammate.sh is allowed to be GLM-5 specific
    print_test "glm5-teammate.sh exists (GLM-5 specific, allowed)"
    if [[ -f "$REPO_ROOT/.claude/scripts/glm5-teammate.sh" ]]; then
        pass
    else
        warn
        echo -e "  ${YELLOW}⚠ glm5-teammate.sh not found${NC}"
    fi

    # Check for any remaining --with-glm5 in shell scripts (excluding glm5-specific)
    print_test "Shell scripts should not have --with-glm5 (except glm5-specific)"
    local scripts_with_flag=$(grep -r "\-\-with-glm5" "$REPO_ROOT/scripts"/*.sh 2>/dev/null | grep -v "glm5" | wc -l | tr -d ' ')
    if [[ "$scripts_with_flag" -eq 0 ]]; then
        pass
    else
        warn
        echo -e "  ${YELLOW}⚠ Found --with-glm5 in scripts (may be documentation)${NC}"
    fi
}

#######################################
# Summary
#######################################
print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))

    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  MODEL-AGNOSTIC TEST SUMMARY${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"

    echo -e "\n  ${GREEN}Passed:${NC}   $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $TESTS_FAILED"
    echo -e "  ${YELLOW}Warnings:${NC} $TESTS_WARNED"
    echo -e "  ${BOLD}Total:${NC}    $total"

    if [[ $total -gt 0 ]]; then
        local rate=$((TESTS_PASSED * 100 / total))
        echo -e "\n  ${BOLD}Pass Rate: ${rate}%${NC}"
    fi

    echo ""
    echo -e "${BOLD}Model-Agnostic Requirements:${NC}"
    echo "  • Skills: No --with-glm5 or --mmc flags"
    echo "  • Agents: No hardcoded model: field"
    echo "  • Model configured in ~/.claude/settings.json"
    echo "  • /glm5 and /glm5-parallel allowed for specific evaluations"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✓ ALL MODEL-AGNOSTIC TESTS PASSED${NC}"
        return 0
    else
        echo -e "\n${RED}${BOLD}✗ SOME MODEL-AGNOSTIC TESTS FAILED${NC}"
        return 1
    fi
}

#######################################
# Main
#######################################
main() {
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║     Model-Agnostic Validation Test Suite v2.88.0            ║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"

    test_skills_no_flags
    test_agents_no_hardcoded_model
    test_architecture_model_agnostic
    test_skills_frontmatter
    test_scripts_model_agnostic

    print_summary
}

main "$@"
