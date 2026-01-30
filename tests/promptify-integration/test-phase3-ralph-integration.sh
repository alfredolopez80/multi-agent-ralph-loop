#!/bin/bash
# test-phase3-ralph-integration.sh - Tests for Phase 3 Ralph Integration
# VERSION: 1.0.0
# Tests Ralph context injection, memory patterns, and quality gates

set -uo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_result() {
    local status="$1"
    local message="$2"

    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Test Ralph context injector
test_ralph_context_injector() {
    print_section "Ralph Context Injector Tests"

    local hook_file="${PROJECT_ROOT}/.claude/hooks/ralph-context-injector.sh"

    # Test 1: File exists
    if [[ -f "$hook_file" ]]; then
        print_result "PASS" "ralph-context-injector.sh exists"
    else
        print_result "FAIL" "ralph-context-injector.sh not found"
    fi

    # Test 2: File is executable
    if [[ -x "$hook_file" ]]; then
        print_result "PASS" "ralph-context-injector.sh is executable"
    else
        print_result "FAIL" "ralph-context-injector.sh is not executable"
    fi

    # Test 3: Can be sourced
    if bash -c "source '$hook_file' 2>/dev/null"; then
        print_result "PASS" "ralph-context-injector.sh can be sourced"
    else
        print_result "FAIL" "ralph-context-injector.sh cannot be sourced"
    fi

    # Test 4: is_ralph_project function exists
    if bash -c "source '$hook_file' && declare -f is_ralph_project &>/dev/null"; then
        print_result "PASS" "is_ralph_project function exists"
    else
        print_result "FAIL" "is_ralph_project function not found"
    fi

    # Test 5: get_ralph_context function exists
    if bash -c "source '$hook_file' && declare -f get_ralph_context &>/dev/null"; then
        print_result "PASS" "get_ralph_context function exists"
    else
        print_result "FAIL" "get_ralph_context function not found"
    fi
}

# Test Ralph memory integration
test_ralph_memory_integration() {
    print_section "Ralph Memory Integration Tests"

    local hook_file="${PROJECT_ROOT}/.claude/hooks/ralph-memory-integration.sh"

    # Test 1: File exists
    if [[ -f "$hook_file" ]]; then
        print_result "PASS" "ralph-memory-integration.sh exists"
    else
        print_result "FAIL" "ralph-memory-integration.sh not found"
    fi

    # Test 2: File is executable
    if [[ -x "$hook_file" ]]; then
        print_result "PASS" "ralph-memory-integration.sh is executable"
    else
        print_result "FAIL" "ralph-memory-integration.sh is not executable"
    fi

    # Test 3: Can be sourced
    if bash -c "source '$hook_file' 2>/dev/null"; then
        print_result "PASS" "ralph-memory-integration.sh can be sourced"
    else
        print_result "FAIL" "ralph-memory-integration.sh cannot be sourced"
    fi

    # Test 4: procedural_memory_exists function exists
    if bash -c "source '$hook_file' && declare -f procedural_memory_exists &>/dev/null"; then
        print_result "PASS" "procedural_memory_exists function exists"
    else
        print_result "FAIL" "procedural_memory_exists function not found"
    fi

    # Test 5: apply_procedural_patterns function exists
    if bash -c "source '$hook_file' && declare -f apply_procedural_patterns &>/dev/null"; then
        print_result "PASS" "apply_procedural_patterns function exists"
    else
        print_result "FAIL" "apply_procedural_patterns function not found"
    fi
}

# Test Ralph quality gates
test_ralph_quality_gates() {
    print_section "Ralph Quality Gates Tests"

    local hook_file="${PROJECT_ROOT}/.claude/hooks/ralph-quality-gates.sh"

    # Test 1: File exists
    if [[ -f "$hook_file" ]]; then
        print_result "PASS" "ralph-quality-gates.sh exists"
    else
        print_result "FAIL" "ralph-quality-gates.sh not found"
    fi

    # Test 2: File is executable
    if [[ -x "$hook_file" ]]; then
        print_result "PASS" "ralph-quality-gates.sh is executable"
    else
        print_result "FAIL" "ralph-quality-gates.sh is not executable"
    fi

    # Test 3: Can be sourced
    if bash -c "source '$hook_file' 2>/dev/null"; then
        print_result "PASS" "ralph-quality-gates.sh can be sourced"
    else
        print_result "FAIL" "ralph-quality-gates.sh cannot be sourced"
    fi

    # Test 4: validate_prompt_quality function exists
    if bash -c "source '$hook_file' && declare -f validate_prompt_quality &>/dev/null"; then
        print_result "PASS" "validate_prompt_quality function exists"
    else
        print_result "FAIL" "validate_prompt_quality function not found"
    fi

    # Test 5: get_quality_suggestions function exists
    if bash -c "source '$hook_file' && declare -f get_quality_suggestions &>/dev/null"; then
        print_result "PASS" "get_quality_suggestions function exists"
    else
        print_result "FAIL" "get_quality_suggestions function not found"
    fi
}

# Test Ralph integration (main script)
test_ralph_integration_main() {
    print_section "Ralph Integration Main Script Tests"

    local hook_file="${PROJECT_ROOT}/.claude/hooks/ralph-integration.sh"

    # Test 1: File exists
    if [[ -f "$hook_file" ]]; then
        print_result "PASS" "ralph-integration.sh exists"
    else
        print_result "FAIL" "ralph-integration.sh not found"
    fi

    # Test 2: File is executable
    if [[ -x "$hook_file" ]]; then
        print_result "PASS" "ralph-integration.sh is executable"
    else
        print_result "FAIL" "ralph-integration.sh is not executable"
    fi

    # Test 3: Can be sourced
    if bash -c "source '$hook_file' 2>/dev/null"; then
        print_result "PASS" "ralph-integration.sh can be sourced"
    else
        print_result "FAIL" "ralph-integration.sh cannot be sourced"
    fi

    # Test 4: enhance_prompt_with_ralph function exists
    if bash -c "source '$hook_file' && declare -f enhance_prompt_with_ralph &>/dev/null"; then
        print_result "PASS" "enhance_prompt_with_ralph function exists"
    else
        print_result "FAIL" "enhance_prompt_with_ralph function not found"
    fi

    # Test 5: enhance_and_validate function exists
    if bash -c "source '$hook_file' && declare -f enhance_and_validate &>/dev/null"; then
        print_result "PASS" "enhance_and_validate function exists"
    else
        print_result "FAIL" "enhance_and_validate function not found"
    fi

    # Test 6: Integration produces valid JSON
    if command -v jq &>/dev/null; then
        local output=$(bash "$hook_file" --quiet 2>/dev/null)
        if echo "$output" | jq '.' &>/dev/null; then
            print_result "PASS" "Integration produces valid JSON"
        else
            print_result "FAIL" "Integration does not produce valid JSON"
        fi
    else
        print_result "SKIP" "jq not available, skipping JSON validation"
    fi
}

# Test integration with promptify-auto-detect
test_promptify_integration() {
    print_section "Promptify Integration Tests"

    local promptify_hook="${PROJECT_ROOT}/.claude/hooks/promptify-auto-detect.sh"
    local ralph_hook="${PROJECT_ROOT}/.claude/hooks/ralph-integration.sh"

    # Test 1: Both hooks exist
    if [[ -f "$promptify_hook" ]] && [[ -f "$ralph_hook" ]]; then
        print_result "PASS" "Both promptify and ralph hooks exist"
    else
        print_result "FAIL" "One or both hooks missing"
    fi

    # Test 2: Both hooks are executable
    if [[ -x "$promptify_hook" ]] && [[ -x "$ralph_hook" ]]; then
        print_result "PASS" "Both hooks are executable"
    else
        print_result "FAIL" "One or both hooks not executable"
    fi

    # Test 3: Config file has Ralph integration enabled
    local config_file="$HOME/.ralph/config/promptify.json"
    if [[ -f "$config_file" ]]; then
        local inject_context=$(jq -r '.integration.inject_ralph_context // false' "$config_file" 2>/dev/null || echo "false")
        local use_memory=$(jq -r '.integration.use_ralph_memory // false' "$config_file" 2>/dev/null || echo "false")
        local use_gates=$(jq -r '.integration.validate_with_quality_gates // false' "$config_file" 2>/dev/null || echo "false")

        if [[ "$inject_context" == "true" ]] || [[ "$use_memory" == "true" ]] || [[ "$use_gates" == "true" ]]; then
            print_result "PASS" "Ralph integration enabled in config"
        else
            print_result "FAIL" "Ralph integration not enabled in config"
        fi
    else
        print_result "SKIP" "Config file not found"
    fi
}

# Print summary
print_summary() {
    print_header "Phase 3 Test Summary"

    echo -e "${BOLD}Tests Run:    ${TOTAL_TESTS}${NC}"
    echo -e "${GREEN}${BOLD}Passed:  ${PASSED_TESTS}${NC}"
    echo -e "${RED}${BOLD}Failed:  ${FAILED_TESTS}${NC}"
    echo ""

    local pass_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    echo -e "${BOLD}Pass Rate:    ${pass_rate}%${NC}"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 ALL PHASE 3 TESTS PASSED! 🎉${NC}"
        echo ""
        echo -e "${GREEN}Ralph Integration is fully functional.${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}❌ SOME TESTS FAILED ❌${NC}"
        echo ""
        echo -e "${YELLOW}Please review the failed tests above.${NC}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    print_header "Promptify Phase 3 Integration Test Suite v${VERSION}"

    echo -e "${BOLD}Test Groups:${NC}"
    echo "  1. Ralph Context Injector"
    echo "  2. Ralph Memory Integration"
    echo "  3. Ralph Quality Gates"
    echo "  4. Ralph Integration Main"
    echo "  5. Promptify Integration"
    echo ""

    local start_time=$(date +%s)

    # Run all test groups
    test_ralph_context_injector
    test_ralph_memory_integration
    test_ralph_quality_gates
    test_ralph_integration_main
    test_promptify_integration

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    echo ""
    echo -e "${BOLD}Execution Time: ${elapsed}s${NC}"

    print_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
