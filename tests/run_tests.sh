#!/usr/bin/env bash
# run_tests.sh - Execute all tests for Multi-Agent Ralph Loop v2.84.1
#
# Usage:
#   ./tests/run_tests.sh           # Run all tests
#   ./tests/run_tests.sh python    # Run only Python tests
#   ./tests/run_tests.sh bash      # Run only Bash tests
#   ./tests/run_tests.sh security  # Run only security tests
#   ./tests/run_tests.sh v218      # Run only v2.19 security fix tests
#   ./tests/run_tests.sh v236      # Run only v2.36 skills unification tests
#   ./tests/run_tests.sh v237      # Run only v2.37 tldr integration tests
#   ./tests/run_tests.sh v256      # Run only v2.56+ task primitive tests
#   ./tests/run_tests.sh hooks     # Run only hook validation tests
#   ./tests/run_tests.sh swarm     # Run swarm mode tests
#   ./tests/run_tests.sh unit      # Run unit tests
#   ./tests/run_tests.sh integration # Run integration tests
#   ./tests/run_tests.sh e2e       # Run end-to-end tests
#   ./tests/run_tests.sh quality   # Run quality parallel tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() { echo -e "${CYAN}[SECTION]${NC} $1"; }

# --- phase accounting (issue #42) ---------------------------------------------
# Modes `all` and `quick` wrapped EVERY phase in `|| true`, so the runner printed
# "Test run complete" and exited 0 no matter what happened. The two gates the issue
# names (the pytest phases) were only the inner layer: fixing them without touching
# this one would have changed nothing observable, because the dispatcher swallowed
# the exit code anyway.
#
# The `|| true` had a legitimate reason -- an early failure should not stop the
# remaining phases from running -- and that reason is preserved. What is not
# preserved is lying at the end: every phase runs, failures are recorded, and the
# runner exits non-zero if there were any.
#
# CAUTION for anyone extending this: calling a shell FUNCTION through run_phase puts
# that function on the left of `||`, which switches `errexit` OFF for its entire body.
# A phase function therefore cannot rely on `set -e` to stop at its first failing
# command -- it will run to the end and return the status of its LAST statement. Every
# phase function below accumulates its own `rc` and returns it explicitly for that
# reason. A phase that ends on something like `|| log_warn ...` returns 0 and reports
# success no matter what happened earlier inside it.
FAILED_PHASES=()

run_phase() {
    local name="$1"
    shift
    local rc=0
    "$@" || rc=$?
    if [[ $rc -ne 0 ]]; then
        FAILED_PHASES+=("$name")
    fi
    return 0
}

# Runs a suite only if its file is present, and says so when it is not.
# `bats <missing file>` exits non-zero, so wiring a suite that does not exist would
# turn the runner permanently red for a reason that has nothing to do with the code
# under test -- while a silent skip would be the fail-open this file is fixing.
run_bats_suite() {
    local name="$1"
    local file="$2"
    shift 2
    if [[ ! -f "$file" ]]; then
        log_warn "suite not present, skipping: $file"
        return 0
    fi
    run_phase "$name" bats "$file" "$@"
}

# Check dependencies
check_deps() {
    local MISSING=()

    command -v pytest &>/dev/null || MISSING+=("pytest")
    command -v bats &>/dev/null || MISSING+=("bats")
    command -v jq &>/dev/null || MISSING+=("jq")

    if [ ${#MISSING[@]} -gt 0 ]; then
        log_warn "Some test runners not found: ${MISSING[*]}"
        echo ""
        echo "Install with:"
        echo "  pip install pytest pytest-cov"
        echo "  brew install bats-core jq"
        echo ""
    fi
}

# Run Python tests
run_python_tests() {
    log_section "Running Python tests..."

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

# Runs a pytest phase without failing open, and without confusing "nothing to run"
# with "all good" (issue #42).
#
# These two phases carried `|| true` since 5dbe635: pytest could fail outright and the
# runner would still announce success. #38 removed the equivalents in ci.yml and that
# exposed dead code hidden for months; this is the same fix, here.
#
# The subtlety is pytest's exit code 5, which means "no tests were collected", not
# "the tests passed". Today tests/unit/ and tests/integration/ contain no .py files at
# all (the 55 pytest modules live at the root of tests/, where run_python_tests picks
# them up), so a bare `set -e` on code 5 would take the runner down for a phase that
# never had Python content. It is reported out loud instead of being taken as a pass:
# an empty directory is information, not an approval.
run_pytest_phase() {
    local target="$1"
    shift

    local rc=0
    pytest "$target" -v --tb=short "$@" || rc=$?

    case "$rc" in
        0) return 0 ;;
        5) log_warn "pytest collected 0 tests in $target (phase has no Python content)"; return 0 ;;
        *) log_error "pytest failed in $target (exit $rc)"; return "$rc" ;;
    esac
}

# Run unit tests
run_unit_tests() {
    log_section "Running unit tests..."

    cd "$PROJECT_DIR"

    # `rc` is explicit because errexit is off inside a run_phase callee (see run_phase).
    # Without it this function would return the status of the statusline block below,
    # which is 0 by construction, and a failing pytest run would be reported as a pass.
    local rc=0

    # Python unit tests
    if command -v pytest &>/dev/null; then
        run_pytest_phase tests/unit/ "$@" || rc=$?
    fi

    # Shell unit tests
    if [[ -x "$SCRIPT_DIR/unit/test-statusline-context.sh" ]]; then
        log_info "Running statusline context tests..."
        "$SCRIPT_DIR/unit/test-statusline-context.sh" || log_warn "Statusline tests require active session"
    fi

    return $rc
}

# Run integration tests
run_integration_tests() {
    log_section "Running integration tests..."

    cd "$PROJECT_DIR"

    # Same explicit rc as run_unit_tests, for the same reason.
    local rc=0

    # Python integration tests
    if command -v pytest &>/dev/null; then
        run_pytest_phase tests/integration/ "$@" || rc=$?
    fi

    # Shell integration tests
    if [[ -x "$SCRIPT_DIR/integration/test-learning-integration-v1.sh" ]]; then
        log_info "Running learning integration tests..."
        "$SCRIPT_DIR/integration/test-learning-integration-v1.sh" || log_warn "Learning integration tests skipped"
    fi

    return $rc
}

# Run end-to-end tests
run_e2e_tests() {
    log_section "Running end-to-end tests..."

    cd "$PROJECT_DIR"

    if [[ -x "$SCRIPT_DIR/end-to-end/test-e2e-learning-complete-v1.sh" ]]; then
        log_info "Running E2E learning tests..."
        "$SCRIPT_DIR/end-to-end/test-e2e-learning-complete-v1.sh" || log_warn "E2E tests require specific environment"
    fi
}

# Run quality parallel tests
run_quality_tests() {
    log_section "Running quality parallel tests..."

    cd "$PROJECT_DIR"

    if [[ -x "$SCRIPT_DIR/quality-parallel/test-quality-parallel-v3-robust.sh" ]]; then
        "$SCRIPT_DIR/quality-parallel/test-quality-parallel-v3-robust.sh" || log_warn "Quality tests skipped"
    fi
}

# Run swarm mode tests
run_swarm_tests() {
    log_section "Running swarm mode tests..."

    cd "$PROJECT_DIR"

    if [[ -x "$SCRIPT_DIR/swarm-mode/test-swarm-mode-config.sh" ]]; then
        "$SCRIPT_DIR/swarm-mode/test-swarm-mode-config.sh" || log_warn "Swarm mode tests require specific config"
    fi
}

# Run agent teams tests
run_agent_teams_tests() {
    log_section "Running agent teams tests..."

    cd "$PROJECT_DIR"

}

# Run Bash tests
run_bash_tests() {
    log_section "Running Bash tests..."

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
    log_section "Running security tests..."

    cd "$PROJECT_DIR"

    # Explicit rc: errexit is off inside a run_phase callee, and the bats block below
    # ends on a conditional that returns 0.
    local rc=0

    # Python security tests. The fallback is a narrower rerun, not a get-out: if BOTH
    # the marker-selected run and the explicit-file run fail, the phase fails.
    if command -v pytest &>/dev/null; then
        pytest tests/ -v -m security --tb=short 2>/dev/null || \
        pytest tests/test_git_safety_guard.py tests/test_security_scan.py -v --tb=short || rc=1
    fi

    # Bash security tests
    # All four still run even if one fails, but the failure is no longer discarded:
    # it is recorded and the runner exits non-zero. A security suite whose result
    # cannot turn anything red is not a security suite.
    if command -v bats &>/dev/null; then
        run_bats_suite security:ralph     tests/test_ralph_security.bats
        run_bats_suite security:mmc       tests/test_mmc_security.bats
        run_bats_suite security:install   tests/test_install_security.bats
        run_bats_suite security:uninstall tests/test_uninstall_security.bats
    fi

    return $rc
}

# Run hook validation tests
run_hooks_tests() {
    log_section "Running hook validation tests..."

    cd "$PROJECT_DIR"

    if command -v pytest &>/dev/null; then
        pytest tests/test_hooks_*.py tests/test_hook_*.py -v --tb=short "$@"
    fi
}

# Run v2.19 specific security fix tests
run_v218_tests() {
    log_section "Running v2.19 security fix tests..."

    cd "$PROJECT_DIR"

    if ! command -v bats &>/dev/null; then
        log_warn "bats not installed, cannot run v2.19 tests"
        echo "  Install with: brew install bats-core"
        return 1
    fi

    # Run only v2.19 security fix tests using filter
    # Same rule as in run_security_tests: every VULN is exercised even if one fails,
    # but a failure counts. Before, this function could not return non-zero for any
    # test at all -- only for bats being absent.
    echo ""
    log_info "Testing VULN-001: escape_for_shell() fixes..."
    run_phase VULN-001 bats tests/test_ralph_security.bats --filter "VULN-001"

    echo ""
    log_info "Testing VULN-004: validate_path() fixes..."
    run_phase VULN-004 bats tests/test_ralph_security.bats --filter "VULN-004"

    echo ""
    log_info "Testing VULN-005: Log file permissions..."
    run_phase VULN-005 bats tests/test_mmc_security.bats --filter "VULN-005"

    echo ""
    log_info "Testing VULN-008: umask 077 fixes..."
    run_phase VULN-008:ralph   bats tests/test_ralph_security.bats --filter "VULN-008"
    run_phase VULN-008:mmc     bats tests/test_mmc_security.bats --filter "VULN-008"
    run_phase VULN-008:install bats tests/test_install_security.bats --filter "VULN-008"

    echo ""
    log_info "Testing git-safety-guard.py (VULN-003)..."
    if command -v pytest &>/dev/null; then
        run_phase VULN-003 pytest tests/test_git_safety_guard.py -v --tb=short
    fi
}

# Run v2.36 skills unification tests
run_v236_tests() {
    log_section "Running v2.36 Skills Unification tests..."

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
    log_section "Running context engine tests..."

    cd "$PROJECT_DIR"

    if command -v pytest &>/dev/null; then
        pytest tests/test_context_engine.py tests/test_context_*.py -v --tb=short "$@"
    else
        log_warn "pytest not installed, skipping context tests"
    fi
}

# Run global sync tests (Python)
run_sync_tests() {
    log_section "Running global sync tests..."

    cd "$PROJECT_DIR"

    if command -v pytest &>/dev/null; then
        pytest tests/test_global_sync.py tests/test_command_sync.py -v --tb=short "$@"
    else
        log_warn "pytest not installed, skipping sync tests"
    fi
}

# Run v2.37 tldr integration tests
run_v237_tests() {
    log_section "Running v2.37 LLM-TLDR Integration tests..."

    cd "$PROJECT_DIR"

    # Run the comprehensive v2.37 test script
    if [[ -x "$SCRIPT_DIR/test_v2.37_tldr_integration.sh" ]]; then
        "$SCRIPT_DIR/test_v2.37_tldr_integration.sh" "$@"
    else
        log_error "v2.37 test script not found or not executable"
        return 1
    fi
}

# Run memory tests
run_memory_tests() {
    log_section "Running memory system tests..."

    cd "$PROJECT_DIR"

    if command -v pytest &>/dev/null; then
        pytest tests/test_memory_*.py tests/test_semantic_*.py -v --tb=short "$@"
    else
        log_warn "pytest not installed, skipping memory tests"
    fi
}

# Print summary
print_summary() {
    local passed=$1
    local failed=$2
    local skipped=$3

    echo ""
    echo "================================================================"
    echo "                      TEST SUMMARY"
    echo "================================================================"
    echo ""
    echo -e "  ${GREEN}Passed:${NC}   $passed"
    echo -e "  ${RED}Failed:${NC}   $failed"
    echo -e "  ${YELLOW}Skipped:${NC}  $skipped"
    echo ""

    if [[ $failed -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_warn "Some tests failed. Review output above."
    fi
}

# Main
main() {
    echo ""
    echo "================================================================"
    echo "  Multi-Agent Ralph Loop v2.84.1 - Test Suite"
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
        hooks)
            run_hooks_tests "$@"
            ;;
        swarm)
            run_swarm_tests "$@"
            ;;
        unit)
            run_unit_tests "$@"
            ;;
        integration)
            run_integration_tests "$@"
            ;;
        e2e|end-to-end)
            run_e2e_tests "$@"
            ;;
        quality)
            run_quality_tests "$@"
            ;;
        memory)
            run_memory_tests "$@"
            ;;
        agent-teams)
            run_agent_teams_tests "$@"
            ;;
        quick)
            # Quick test run - core tests only
            run_phase hooks    run_hooks_tests "$@"
            run_phase security run_security_tests "$@"
            ;;
        all|"")
            run_phase python      run_python_tests "$@"
            echo ""
            run_phase bash        run_bash_tests "$@"
            echo ""
            run_phase unit        run_unit_tests "$@"
            echo ""
            run_phase integration run_integration_tests "$@"
            echo ""
            run_phase swarm       run_swarm_tests "$@"
            ;;
        *)
            log_error "Unknown mode: $MODE"
            echo ""
            echo "Usage: $0 [MODE]"
            echo ""
            echo "Modes:"
            echo "  all          - Run all tests (default)"
            echo "  python       - Run Python tests"
            echo "  bash         - Run Bash tests"
            echo "  security     - Run security tests"
            echo "  hooks        - Run hook validation tests"
            echo "  unit         - Run unit tests"
            echo "  integration  - Run integration tests"
            echo "  e2e          - Run end-to-end tests"
            echo "  swarm        - Run swarm mode tests"
            echo "  quality      - Run quality parallel tests"
            echo "  memory       - Run memory system tests"
            echo "  context      - Run context engine tests"
            echo "  sync         - Run global sync tests"
            echo "  quick        - Run quick core tests"
            echo ""
            echo "Version-specific:"
            echo "  v218         - v2.19 security fix tests"
            echo "  v236         - v2.36 skills unification"
            echo "  v237         - v2.37 tldr integration"
            exit 1
            ;;
    esac

    echo ""
    echo "================================================================"
    if [[ ${#FAILED_PHASES[@]} -gt 0 ]]; then
        log_error "Test run FAILED in: ${FAILED_PHASES[*]}"
        echo "================================================================"
        return 1
    fi
    log_success "Test run complete"
    echo "================================================================"
}

# k8s context guard (26 casos: invocacion vs mencion, contexto efectivo, allowlist).
# Se ejecuta ANTES de main y propaga su codigo de salida: colgado detras de main, el
# FAILED=1 no lo leia nadie y un fallo del hook seguia dando exit 0 tras imprimir el
# banner de exito.
K8S_GUARD_RC=0
if [[ -x "$SCRIPT_DIR/hooks/test-k8s-context-guard.sh" ]]; then
    "$SCRIPT_DIR/hooks/test-k8s-context-guard.sh" || K8S_GUARD_RC=1
fi

# `main "$@"` on its own would abort here under `set -e` the moment main returns
# non-zero, so MAIN_RC and the k8s verdict below were unreachable in exactly the case
# they exist to report: the exit code was right by accident, but the diagnostic never
# printed. `|| MAIN_RC=$?` keeps main's status without letting errexit cut the script.
MAIN_RC=0
main "$@" || MAIN_RC=$?

if [[ $K8S_GUARD_RC -ne 0 ]]; then
    echo "FAIL: the k8s context guard suite failed" >&2
    exit 1
fi
exit $MAIN_RC
