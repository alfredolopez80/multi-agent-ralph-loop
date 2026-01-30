#!/bin/bash
# run-all-complete-tests.sh - Complete test suite including Phase 3
# VERSION: 1.0.0
# Runs all tests for Phases 1, 2, 3, and 4

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
TOTAL_PHASES=0
PASSED_PHASES=0
FAILED_PHASES=0

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║  $1${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
}

print_phase() {
    echo ""
    echo -e "${BLUE}${BOLD}━━━ PHASE $1 ━━━${NC}"
    echo -e "${BLUE}${BOLD}$2${NC}"
    echo ""
}

run_phase() {
    local phase_num="$1"
    local phase_name="$2"
    local test_script="$3"

    print_phase "$phase_num" "$phase_name"

    if [[ -x "$test_script" ]]; then
        if bash "$test_script" "$@"; then
            echo -e "${GREEN}✅ Phase $phase_num PASSED${NC}"
            ((PASSED_PHASES++))
            return 0
        else
            echo -e "${RED}❌ Phase $phase_num FAILED${NC}"
            ((FAILED_PHASES++))
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Test script not found or not executable: $test_script${NC}"
        ((FAILED_PHASES++))
        return 1
    fi
    ((TOTAL_PHASES++))
}

# Print summary
print_summary() {
    print_header "COMPLETE TEST SUITE SUMMARY"

    echo -e "${BOLD}Total Phases: ${TOTAL_PHASES}${NC}"
    echo -e "${GREEN}${BOLD}Passed:        ${PASSED_PHASES}${NC}"
    echo -e "${RED}${BOLD}Failed:        ${FAILED_PHASES}${NC}"
    echo ""

    local pass_rate=0
    if [[ $TOTAL_PHASES -gt 0 ]]; then
        pass_rate=$((PASSED_PHASES * 100 / TOTAL_PHASES))
    fi

    echo -e "${BOLD}Overall Pass Rate:    ${pass_rate}%${NC}"
    echo ""

    if [[ $FAILED_PHASES -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}${BOLD}║                                                   ║${NC}"
        echo -e "${GREEN}${BOLD}║     🎉 ALL PHASES COMPLETE! 🎉                     ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                   ║${NC}"
        echo -e "${GREEN}${BOLD}║  Promptify integration with Ralph is fully         ║${NC}"
        echo -e "${GREEN}${BOLD}║  functional and ready for production use.         ║${NC}"
        echo -e "${GREEN}${BOLD}║                                                   ║${NC}"
        echo -e "${GREEN}${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}Implementation Status:${NC}"
        echo "  ✅ Phase 1: Hook Integration"
        echo "  ✅ Phase 2: Security Hardening"
        echo "  ✅ Phase 3: Ralph Integration"
        echo "  ✅ Phase 4: Validation & Testing"
        echo ""
        echo "Next steps:"
        echo "  1. Run adversarial validation: /adversarial docs/promptify-integration/"
        echo "  2. Run Codex CLI review: /codex-cli docs/promptify-integration/"
        echo "  3. Run Gemini CLI validation: /gemini-cli docs/promptify-integration/"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}╔═══════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}${BOLD}║                                                   ║${NC}"
        echo -e "${RED}${BOLD}║     ❌ SOME PHASES FAILED ❌                        ║${NC}"
        echo -e "${RED}${BOLD}║                                                   ║${NC}"
        echo -e "${RED}${BOLD}║     Please review the failed tests above           ║${NC}"
        echo -e "${RED}${BOLD}║                                                   ║${NC}"
        echo -e "${RED}${BOLD}╚═══════════════════════════════════════════════════════╝${NC}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    print_header "PROMPTIFY COMPLETE TEST SUITE v${VERSION}"

    echo -e "${BOLD}Testing all phases of Promptify integration:${NC}"
    echo "  Phase 1: Hook Integration (promptify-auto-detect.sh)"
    echo "  Phase 2: Security Hardening (promptify-security.sh)"
    echo "  Phase 3: Ralph Integration (context, memory, gates)"
    echo "  Phase 4: Validation & Testing (test suite)"
    echo ""

    local start_time=$(date +%s)

    # Run Phase 1, 2, 4 tests (original test suite)
    run_phase "1,2,4" "Phases 1, 2, 4: Hook, Security, Testing" \
        "${SCRIPT_DIR}/run-promptify-tests.sh"

    # Run Phase 3 tests
    run_phase "3" "Phase 3: Ralph Integration" \
        "${SCRIPT_DIR}/test-phase3-ralph-integration.sh"

    ((TOTAL_PHASES++))

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    echo ""
    echo -e "${BOLD}Total Execution Time: ${elapsed}s${NC}"

    print_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
