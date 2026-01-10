#!/usr/bin/env bash
# run_tests.sh - Execute all tests for Multi-Agent Ralph Loop v2.37
#
# Usage:
#   ./tests/run_tests.sh           # Run all tests
#   ./tests/run_tests.sh python    # Run only Python tests
#   ./tests/run_tests.sh bash      # Run only Bash tests
#   ./tests/run_tests.sh security  # Run only security tests
#   ./tests/run_tests.sh v218      # Run only v2.19 security fix tests
#   ./tests/run_tests.sh v236      # Run only v2.36 skills unification tests
#   ./tests/run_tests.sh v237      # Run only v2.37 tldr integration tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check dependencies
check_deps() {
    local MISSING=()

    command -v pytest &>/dev/null || MISSING+=("pytest")
    command -v bats &>/dev/null || MISSING+=("bats")

    if [ ${#MISSING[@]} -gt 0 ]; then
        log_warn "Some test runners not found: ${MISSING[*]}"
        echo ""
        echo "Install with:"
        echo "  pip install pytest pytest-cov"
        echo "  brew install bats-core"
        echo ""
    fi
}

# Run Python tests
run_python_tests() {
    log_info "Running Python tests..."

    if ! command -v pytest &>/dev/null; then
        log_warn "pytest not installed, skipping Python tests"
        return 0
    fi

    cd "$PROJECT_DIR"

    # Run with coverage if available
    if python -c "import pytest_cov" 2>/dev/null; then
        pytest tests/ -v --cov=.claude/hooks --cov-report=term-missing "$@"
    else
        pytest tests/ -v "$@"
    fi
}

# Run Bash tests
run_bash_tests() {
    log_info "Running Bash tests..."

    if ! command -v bats &>/dev/null; then
        log_warn "bats not installed, skipping Bash tests"
        echo "  Install with: brew install bats-core"
        return 0
    fi

    cd "$PROJECT_DIR"

    # Run all .bats files
    bats tests/*.bats
}

# Run security-focused tests only
run_security_tests() {
    log_info "Running security tests..."

    cd "$PROJECT_DIR"

    # Python security tests
    if command -v pytest &>/dev/null; then
        pytest tests/ -v -m security --tb=short 2>/dev/null || \
        pytest tests/test_git_safety_guard.py -v --tb=short
    fi

    # Bash security tests
    if command -v bats &>/dev/null; then
        bats tests/test_ralph_security.bats
        bats tests/test_mmc_security.bats
        bats tests/test_install_security.bats
        bats tests/test_uninstall_security.bats
    fi
}

# Run v2.19 specific security fix tests
run_v218_tests() {
    log_info "Running v2.19 security fix tests..."

    cd "$PROJECT_DIR"

    if ! command -v bats &>/dev/null; then
        log_warn "bats not installed, cannot run v2.19 tests"
        echo "  Install with: brew install bats-core"
        return 1
    fi

    # Run only v2.19 security fix tests using filter
    echo ""
    log_info "Testing VULN-001: escape_for_shell() fixes..."
    bats tests/test_ralph_security.bats --filter "VULN-001"

    echo ""
    log_info "Testing VULN-004: validate_path() fixes..."
    bats tests/test_ralph_security.bats --filter "VULN-004"

    echo ""
    log_info "Testing VULN-005: Log file permissions..."
    bats tests/test_mmc_security.bats --filter "VULN-005"

    echo ""
    log_info "Testing VULN-008: umask 077 fixes..."
    bats tests/test_ralph_security.bats --filter "VULN-008"
    bats tests/test_mmc_security.bats --filter "VULN-008"
    bats tests/test_install_security.bats --filter "VULN-008"

    echo ""
    log_info "Testing git-safety-guard.py (VULN-003)..."
    if command -v pytest &>/dev/null; then
        pytest tests/test_git_safety_guard.py -v --tb=short
    fi
}

# Run v2.36 skills unification tests
run_v236_tests() {
    log_info "Running v2.36 Skills Unification tests..."

    cd "$PROJECT_DIR"

    # Run the comprehensive v2.36 test script
    if [[ -x "$SCRIPT_DIR/test_v2.36_skills_unification.sh" ]]; then
        "$SCRIPT_DIR/test_v2.36_skills_unification.sh" "$@"
    else
        log_error "v2.36 test script not found or not executable"
        return 1
    fi
}

# Run context engine tests (Python)
run_context_tests() {
    log_info "Running context engine tests..."

    cd "$PROJECT_DIR"

    if command -v pytest &>/dev/null; then
        pytest tests/test_context_engine.py -v --tb=short "$@"
    else
        log_warn "pytest not installed, skipping context tests"
    fi
}

# Run global sync tests (Python)
run_sync_tests() {
    log_info "Running global sync tests..."

    cd "$PROJECT_DIR"

    if command -v pytest &>/dev/null; then
        pytest tests/test_global_sync.py -v --tb=short "$@"
    else
        log_warn "pytest not installed, skipping sync tests"
    fi
}

# Run v2.37 tldr integration tests
run_v237_tests() {
    log_info "Running v2.37 LLM-TLDR Integration tests..."

    cd "$PROJECT_DIR"

    # Run the comprehensive v2.37 test script
    if [[ -x "$SCRIPT_DIR/test_v2.37_tldr_integration.sh" ]]; then
        "$SCRIPT_DIR/test_v2.37_tldr_integration.sh" "$@"
    else
        log_error "v2.37 test script not found or not executable"
        return 1
    fi
}

# Main
main() {
    echo ""
    echo "================================================================"
    echo "  Multi-Agent Ralph Loop - Test Suite"
    echo "================================================================"
    echo ""

    check_deps

    local MODE="${1:-all}"
    shift || true

    case "$MODE" in
        python|py)
            run_python_tests "$@"
            ;;
        bash|bats|shell)
            run_bash_tests "$@"
            ;;
        security|sec)
            run_security_tests "$@"
            ;;
        v218|v2.19|vuln)
            run_v218_tests "$@"
            ;;
        v236|v2.36|skills)
            run_v236_tests "$@"
            ;;
        v237|v2.37|tldr)
            run_v237_tests "$@"
            ;;
        context)
            run_context_tests "$@"
            ;;
        sync|global)
            run_sync_tests "$@"
            ;;
        all|"")
            run_python_tests "$@" || true
            echo ""
            run_bash_tests "$@" || true
            echo ""
            run_v236_tests "$@" || true
            echo ""
            run_v237_tests "$@" || true
            ;;
        *)
            log_error "Unknown mode: $MODE"
            echo "Usage: $0 [python|bash|security|v218|v236|v237|context|sync|all]"
            exit 1
            ;;
    esac

    echo ""
    echo "================================================================"
    log_success "Test run complete"
    echo "================================================================"
}

main "$@"
