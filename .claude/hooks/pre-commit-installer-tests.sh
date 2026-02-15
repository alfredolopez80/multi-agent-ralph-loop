#!/usr/bin/env bash
#===============================================================================
# pre-commit-installer-tests.sh - Run installer tests before commit
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate installation integrity before committing changes
#
# This hook runs as a PreToolUse hook when Bash commands contain git commit.
# It validates that all installation components are properly configured.
#
# Exit codes:
#   0: All tests pass, commit can proceed
#   1: Tests failed, commit blocked
#   2: Cannot run tests (environment issue)
#===============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TESTS_DIR="$PROJECT_ROOT/tests/installer"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

#===============================================================================
# FUNCTIONS
#===============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_bats_installed() {
    if ! command -v bats &>/dev/null; then
        log_error "bats is not installed. Install with: brew install bats-core"
        return 1
    fi
    return 0
}

run_installer_tests() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .bats)

    log_info "Running $test_name..."

    if bats "$test_file" &>/dev/null; then
        log_info "$test_name: PASSED"
        return 0
    else
        log_error "$test_name: FAILED"
        # Show detailed output on failure
        bats "$test_file" 2>&1 | tail -20
        return 1
    fi
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    echo "========================================"
    echo " Pre-Commit: Installation Tests"
    echo " Version: 1.0.0"
    echo "========================================"
    echo ""

    # Check if bats is installed
    if ! check_bats_installed; then
        # Output hook response for Claude Code
        cat << 'JSONEOF'
{
    "continue": true,
    "reason": "bats not installed, skipping installer tests. Install with: brew install bats-core",
    "suppressOutput": false
}
JSONEOF
        exit 0
    fi

    # Track results
    local passed=0
    local failed=0
    local total=0

    # Run installer tests
    for test_file in "$TESTS_DIR"/*.bats; do
        if [[ -f "$test_file" ]]; then
            ((total++)) || true
            if run_installer_tests "$test_file"; then
                ((passed++)) || true
            else
                ((failed++)) || true
            fi
        fi
    done

    echo ""
    echo "========================================"
    echo " Results: $passed/$total test suites passed"
    echo "========================================"

    if [[ $failed -eq 0 ]]; then
        # All tests passed - output approval
        cat << JSONEOF
{
    "continue": true,
    "reason": "All $total installer test suites passed",
    "suppressOutput": false
}
JSONEOF
        exit 0
    else
        # Some tests failed - output blocking response
        cat << JSONEOF
{
    "continue": false,
    "reason": "$failed/$total installer test suites failed. Fix issues before committing.",
    "suppressOutput": false
}
JSONEOF
        exit 1
    fi
}

# Run main
main "$@"
