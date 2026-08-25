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

# --- contabilidad de fases (issue #42) ----------------------------------------
# Los modos `all` y `quick` envolvian CADA fase en `|| true`, de modo que el runner
# imprimia "Test run complete" y salia 0 pasara lo que pasara. Los dos gates que el
# issue nombra (las fases de pytest) eran solo la capa interior: arreglarlos sin
# tocar esta no habria cambiado nada observable, porque el despachador se tragaba el
# codigo igualmente.
#
# El `|| true` tenia una razon legitima -- que un fallo temprano no impida ejecutar
# el resto de fases -- y esa razon se conserva. Lo que no se conserva es mentir al
# final: se ejecutan todas, se anotan las que fallan y se sale != 0 si hay alguna.
FAILED_PHASES=()

run_phase() {
    local name="$1"
    shift
    "$@" || FAILED_PHASES+=("$name")
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

# Ejecuta una fase de pytest sin fail-open y sin confundir "nada que ejecutar" con
# "todo bien" (issue #42).
#
# Estas dos fases llevaban `|| true` desde 5dbe635: pytest podia fallar entero y el
# runner seguia anunciando exito. #38 quito los equivalentes en ci.yml y aquello
# destapo codigo muerto que llevaba meses oculto; esto es el mismo arreglo aqui.
#
# El matiz es el codigo 5 de pytest, que significa "no se recolecto ningun test" y no
# "los tests pasaron". Hoy tests/unit/ y tests/integration/ no contienen ningun .py
# (los 55 modulos de pytest viven en la raiz de tests/, y de ahi los recoge
# run_python_tests), asi que un `set -e` sobre el codigo 5 tumbaria el runner por una
# fase que nunca tuvo contenido Python. Se reporta en voz alta en vez de darse por
# buena: un directorio vacio es informacion, no un aprobado.
run_pytest_phase() {
    local target="$1"
    shift

    local rc=0
    pytest "$target" -v --tb=short "$@" || rc=$?

    case "$rc" in
        0) return 0 ;;
        5) log_warn "pytest recolecto 0 tests en $target (fase sin contenido Python)"; return 0 ;;
        *) log_error "pytest fallo en $target (exit $rc)"; return "$rc" ;;
    esac
}

# Run unit tests
run_unit_tests() {
    log_section "Running unit tests..."

    cd "$PROJECT_DIR"

    # Python unit tests
    if command -v pytest &>/dev/null; then
        run_pytest_phase tests/unit/ "$@"
    fi

    # Shell unit tests
    if [[ -x "$SCRIPT_DIR/unit/test-statusline-context.sh" ]]; then
        log_info "Running statusline context tests..."
        "$SCRIPT_DIR/unit/test-statusline-context.sh" || log_warn "Statusline tests require active session"
    fi
}

# Run integration tests
run_integration_tests() {
    log_section "Running integration tests..."

    cd "$PROJECT_DIR"

    # Python integration tests
    if command -v pytest &>/dev/null; then
        run_pytest_phase tests/integration/ "$@"
    fi

    # Shell integration tests
    if [[ -x "$SCRIPT_DIR/integration/test-learning-integration-v1.sh" ]]; then
        log_info "Running learning integration tests..."
        "$SCRIPT_DIR/integration/test-learning-integration-v1.sh" || log_warn "Learning integration tests skipped"
    fi
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

    # Python security tests
    if command -v pytest &>/dev/null; then
        pytest tests/ -v -m security --tb=short 2>/dev/null || \
        pytest tests/test_git_safety_guard.py tests/test_security_scan.py -v --tb=short
    fi

    # Bash security tests
    # Se siguen ejecutando las cuatro aunque una falle, pero el fallo ya no se
    # descarta: queda anotado y el runner sale != 0. Una suite de seguridad cuyo
    # resultado no puede poner nada en rojo no es una suite de seguridad.
    if command -v bats &>/dev/null; then
        run_phase security:ralph     bats tests/test_ralph_security.bats
        run_phase security:mmc       bats tests/test_mmc_security.bats
        run_phase security:install   bats tests/test_install_security.bats
        run_phase security:uninstall bats tests/test_uninstall_security.bats
    fi
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
    # Mismo criterio que en run_security_tests: se recorren todas las VULN aunque
    # una falle, pero un fallo cuenta. Antes, esta funcion no podia devolver != 0
    # por ningun test: solo por que faltase bats.
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

main "$@"
MAIN_RC=$?

if [[ $K8S_GUARD_RC -ne 0 ]]; then
    echo "FAIL: la suite del k8s context guard fallo" >&2
    exit 1
fi
exit $MAIN_RC
