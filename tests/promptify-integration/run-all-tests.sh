#!/bin/bash
# run-all-tests.sh - Test runner for Promptify integration test suite
# VERSION: 1.0.0
# Executes all unit, integration, and E2E tests

set -euo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Test suite counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Overall test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo ""
}

# Print suite header
print_suite_header() {
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}Running: $1${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Print suite result
print_suite_result() {
    local suite_name="$1"
    local status="$2"
    local passed="$3"
    local failed="$4"
    local total=$((passed + failed))

    ((TOTAL_SUITES++))
    ((TOTAL_TESTS += total))
    ((PASSED_TESTS += passed))
    ((FAILED_TESTS += failed))

    if [[ "$failed" -eq 0 ]]; then
        echo -e "${GREEN}✅ $suite_name: PASSED (${passed}/${total} tests)${NC}"
        ((PASSED_SUITES++))
    else
        echo -e "${RED}❌ $suite_name: FAILED (${passed}/${total} passed, ${failed} failed)${NC}"
        ((FAILED_SUITES++))
    fi
}

# Run test suite
run_test_suite() {
    local test_file="$1"
    local suite_name=$(basename "$test_file" .sh)

    print_suite_header "$suite_name"

    if [[ ! -f "$test_file" ]]; then
        echo -e "${RED}ERROR${NC}: Test file not found: $test_file"
        return 1
    fi

    if [[ ! -x "$test_file" ]]; then
        echo -e "${YELLOW}WARNING${NC}: Test file not executable, making executable..."
        chmod +x "$test_file"
    fi

    # Run test and capture output
    local test_output
    local test_exit_code=0

    test_output=$("$test_file" 2>&1) || test_exit_code=$?

    # Print test output
    echo "$test_output"

    # Parse results from output
    local passed=$(echo "$test_output" | grep -oP 'Tests Passed:\s*\K\d+' || echo "0")
    local failed=$(echo "$test_output" | grep -oP 'Tests Failed:\s*\K\d+' || echo "0")

    print_suite_result "$suite_name" "$test_exit_code" "$passed" "$failed"

    return $test_exit_code
}

# Main execution
main() {
    print_header "Promptify Integration Test Suite v${VERSION}"

    echo -e "${BOLD}Test Suites:${NC}"
    echo "  1. Clarity Scoring Tests"
    echo "  2. Credential Redaction Tests"
    echo "  3. Security Functions Tests"
    echo "  4. End-to-End Integration Tests"
    echo ""

    local start_time=$(date +%s)

    # Run test suites
    local test_dir="$SCRIPT_DIR"

    # Test 1: Clarity scoring
    run_test_suite "$test_dir/test-clarity-scoring.sh" || true

    # Test 2: Credential redaction
    run_test_suite "$test_dir/test-credential-redaction.sh" || true

    # Test 3: Security functions
    run_test_suite "$test_dir/test-security-functions.sh" || true

    # Test 4: E2E tests
    run_test_suite "$test_dir/test-e2e.sh" || true

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    # Print final summary
    print_header "Final Summary"

    echo -e "${BOLD}Test Suites:${NC}"
    echo -e "  Total:   ${TOTAL_SUITES}"
    echo -e "  ${GREEN}Passed:  ${PASSED_SUITES}${NC}"
    echo -e "  ${RED}Failed:  ${FAILED_SUITES}${NC}"
    echo ""

    echo -e "${BOLD}Individual Tests:${NC}"
    echo -e "  Total:   ${TOTAL_TESTS}"
    echo -e "  ${GREEN}Passed:  ${PASSED_TESTS}${NC}"
    echo -e "  ${RED}Failed:  ${FAILED_TESTS}${NC}"
    echo ""

    local pass_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    echo -e "${BOLD}Pass Rate:${NC} ${pass_rate}%"
    echo ""

    local suite_pass_rate=0
    if [[ $TOTAL_SUITES -gt 0 ]]; then
        suite_pass_rate=$((PASSED_SUITES * 100 / TOTAL_SUITES))
    fi

    echo -e "${BOLD}Suite Pass Rate:${NC} ${suite_pass_rate}%"
    echo ""

    echo -e "${BOLD}Execution Time:${NC} ${elapsed}s"
    echo ""

    # Final verdict
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 ALL TEST SUITES PASSED! 🎉${NC}"
        echo ""
        echo -e "${GREEN}Promptify integration is fully functional and ready for use.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Run adversarial validation: /adversarial docs/promptify-integration/"
        echo "  2. Run Codex CLI review: /codex-cli docs/promptify-integration/"
        echo "  3. Run Gemini CLI validation: /gemini-cli docs/promptify-integration/"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}❌ SOME TEST SUITES FAILED ❌${NC}"
        echo ""
        echo -e "${YELLOW}Please review the failed tests above and fix the issues.${NC}"
        echo ""
        echo "Common issues:"
        echo "  - Hook file not found or not executable"
        echo "  - Missing dependencies (jq, sed, grep)"
        echo "  - Configuration file not created"
        echo "  - Permission issues with log directories"
        echo ""
        return 1
    fi
}

# Run all tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
