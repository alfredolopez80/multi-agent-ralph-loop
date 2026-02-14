#!/bin/bash
# run-all-unit-tests.sh - Run all unit tests and report results
# Version: 2.87.0
# Date: 2026-02-14
# Purpose: CI/CD validation script for multi-agent-ralph-loop
#
# Usage:
#   ./tests/run-all-unit-tests.sh [--verbose] [--coverage]
#
# Exit codes:
#   0 - All tests passed (100%)
#   1 - Some tests failed
#   2 - Script error

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Options
VERBOSE=false
COVERAGE=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --verbose|-v) VERBOSE=true ;;
        --coverage|-c) COVERAGE=true ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--coverage]"
            echo ""
            echo "Options:"
            echo "  --verbose   Show detailed output from each test"
            echo "  --coverage  Generate coverage report (future feature)"
            exit 0
            ;;
    esac
done

echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         Multi-Agent Ralph Loop - Unit Test Runner            ║${NC}"
echo -e "${BOLD}${CYAN}║         Version 2.87.0                                        ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Repository: $REPO_ROOT"
echo "Verbose: $VERBOSE"
echo "Started: $(date)"
echo ""

# Test suites to run
TEST_SUITES=(
    "unit/test-skills-unification-v2.87.sh:Skills Unification"
)

#######################################
# Run a test suite
#######################################
run_test_suite() {
    local test_script="$1"
    local test_name="$2"
    local full_path="$SCRIPT_DIR/$test_script"

    ((TOTAL_SUITES++))

    echo -e "${BOLD}[Test Suite $TOTAL_SUITES] $test_name${NC}"
    echo -e "  Script: $test_script"

    if [[ ! -f "$full_path" ]]; then
        echo -e "  ${RED}✗ Test script not found${NC}"
        ((FAILED_SUITES++))
        return 1
    fi

    if [[ ! -x "$full_path" ]]; then
        echo -e "  ${YELLOW}⚠ Making script executable${NC}"
        chmod +x "$full_path"
    fi

    echo ""

    # Run the test
    local start_time
    start_time=$(date +%s)

    local verbose_flag=""
    $VERBOSE && verbose_flag="--verbose"

    if "$full_path" $verbose_flag; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        echo -e "  ${GREEN}✓ PASSED${NC} (${duration}s)"
        ((PASSED_SUITES++))
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        echo -e "  ${RED}✗ FAILED${NC} (${duration}s)"
        ((FAILED_SUITES++))
        return 1
    fi
}

#######################################
# Main execution
#######################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Running Test Suites${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

FAILED_TESTS=""

for suite in "${TEST_SUITES[@]}"; do
    IFS=':' read -r script name <<< "$suite"

    echo ""
    if ! run_test_suite "$script" "$name"; then
        FAILED_TESTS="$FAILED_TESTS $name"
    fi
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
done

#######################################
# Summary
#######################################
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  Test Summary${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "  ${GREEN}Passed:${NC} $PASSED_SUITES"
echo -e "  ${RED}Failed:${NC} $FAILED_SUITES"
echo -e "  ${BOLD}Total:${NC}  $TOTAL_SUITES"
echo ""

pass_rate=0
if [[ $TOTAL_SUITES -gt 0 ]]; then
    pass_rate=$((PASSED_SUITES * 100 / TOTAL_SUITES))
fi

echo -e "  ${BOLD}Pass Rate: ${pass_rate}%${NC}"
echo ""

if [[ $FAILED_SUITES -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ ALL TEST SUITES PASSED${NC}"
    echo ""
    echo "Completed: $(date)"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}✗ SOME TEST SUITES FAILED${NC}"
    echo ""
    echo "Failed suites:$FAILED_TESTS"
    echo ""
    echo "Run with --verbose for detailed output"
    echo ""
    echo "Completed: $(date)"
    echo ""
    exit 1
fi
