#!/bin/bash
# Stop Hook Verification - Verifica completitud antes de terminar sesión
# Origen: planning-with-files pattern
# v1.0.0 - 2026-01-13

set -euo pipefail

# Configuración
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_FILE="${HOME}/.ralph/logs/stop-verification.log"

# Asegurar directorio de logs existe
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Leer input de Claude (JSON con context)
INPUT=$(cat)

# Verificaciones de completitud
WARNINGS=()
CHECKS_PASSED=0
TOTAL_CHECKS=4

# 1. Verificar TODOs pendientes en el proyecto
if [ -f "${PROJECT_DIR}/.claude/progress.md" ]; then
    PENDING_TODOS=$(grep -c "^\- \[ \]" "${PROJECT_DIR}/.claude/progress.md" 2>/dev/null || echo "0")
    if [ "$PENDING_TODOS" -gt 0 ]; then
        WARNINGS+=("TODOs pendientes: ${PENDING_TODOS} items sin completar en progress.md")
    else
        ((CHECKS_PASSED++))
    fi
else
    ((CHECKS_PASSED++))  # No hay progress.md, no es error
fi

# 2. Verificar cambios sin commit (si es repo git)
if [ -d "${PROJECT_DIR}/.git" ]; then
    UNCOMMITTED=$(git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
    if [ "$UNCOMMITTED" -gt 0 ]; then
        WARNINGS+=("Cambios sin commit: ${UNCOMMITTED} archivos modificados")
    else
        ((CHECKS_PASSED++))
    fi
else
    ((CHECKS_PASSED++))  # No es repo git, no es error
fi

# 3. Verificar errores de lint recientes (si existe log)
LINT_LOG="${HOME}/.ralph/logs/quality-gates.log"
if [ -f "$LINT_LOG" ]; then
    # Revisar últimas líneas del log de hoy
    TODAY=$(date '+%Y-%m-%d')
    LINT_ERRORS=$(grep "$TODAY" "$LINT_LOG" 2>/dev/null | grep -c "ERROR\|FAILED" || echo "0")
    if [ "$LINT_ERRORS" -gt 0 ]; then
        WARNINGS+=("Errores de lint: ${LINT_ERRORS} errores en la última sesión")
    else
        ((CHECKS_PASSED++))
    fi
else
    ((CHECKS_PASSED++))  # No hay log de lint, no es error
fi

# 4. Verificar tests fallidos recientes
TEST_LOG="${HOME}/.ralph/logs/test-results.log"
if [ -f "$TEST_LOG" ]; then
    TODAY=$(date '+%Y-%m-%d')
    TEST_FAILURES=$(grep "$TODAY" "$TEST_LOG" 2>/dev/null | grep -c "FAILED\|ERROR" || echo "0")
    if [ "$TEST_FAILURES" -gt 0 ]; then
        WARNINGS+=("Tests fallidos: ${TEST_FAILURES} tests fallaron")
    else
        ((CHECKS_PASSED++))
    fi
else
    ((CHECKS_PASSED++))  # No hay log de tests, no es error
fi

# Generar output
log "Stop verification: ${CHECKS_PASSED}/${TOTAL_CHECKS} checks passed"

if [ ${#WARNINGS[@]} -gt 0 ]; then
    log "Warnings: ${WARNINGS[*]}"

    # Output para Claude
    echo "STOP_VERIFICATION_WARNINGS:"
    for warning in "${WARNINGS[@]}"; do
        echo "  - $warning"
    done
    echo ""
    echo "Considera revisar estos items antes de terminar la sesión."
else
    log "All checks passed"
    echo "STOP_VERIFICATION: All ${TOTAL_CHECKS} checks passed"
fi

exit 0
