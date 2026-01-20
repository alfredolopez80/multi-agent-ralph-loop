#!/bin/bash
# Stop Hook Verification - Verifica completitud antes de terminar sesión
# Origen: planning-with-files pattern
# v2.45.4 - Added JSON return for Claude Code hook protocol

# VERSION: 2.57.4
# v2.57.3: Fixed JSON format - Stop hooks use {"decision": "approve|block"} (SEC-038)
set -euo pipefail

# Configuración
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
LOG_FILE="${HOME}/.ralph/logs/stop-verification.log"

# Asegurar directorio de logs existe
mkdir -p "$(dirname "$LOG_FILE")"

# Function to return JSON response (Stop hook protocol - uses "decision" not "continue")
# Stop hooks: {"decision": "approve"} to allow stop, {"decision": "block"} to prevent
return_json() {
    local decision="${1:-approve}"
    local reason="${2:-}"
    if [ -n "$reason" ]; then
        echo "{\"decision\": \"$decision\", \"reason\": \"$reason\"}"
    else
        echo "{\"decision\": \"$decision\"}"
    fi
}

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
    PENDING_TODOS=$(grep -c "^\- \[ \]" "${PROJECT_DIR}/.claude/progress.md" 2>/dev/null | tr -d ' \n') || PENDING_TODOS=0
    PENDING_TODOS=${PENDING_TODOS:-0}
    # Ensure it's a valid integer
    if ! [[ "$PENDING_TODOS" =~ ^[0-9]+$ ]]; then
        PENDING_TODOS=0
    fi
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
    LINT_ERRORS=$(grep "$TODAY" "$LINT_LOG" 2>/dev/null | grep -c "ERROR\|FAILED" | tr -d ' \n') || LINT_ERRORS=0
    LINT_ERRORS=${LINT_ERRORS:-0}
    # Ensure it's a valid integer
    if ! [[ "$LINT_ERRORS" =~ ^[0-9]+$ ]]; then
        LINT_ERRORS=0
    fi
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
    TEST_FAILURES=$(grep "$TODAY" "$TEST_LOG" 2>/dev/null | grep -c "FAILED\|ERROR" | tr -d ' \n') || TEST_FAILURES=0
    TEST_FAILURES=${TEST_FAILURES:-0}
    # Ensure it's a valid integer
    if ! [[ "$TEST_FAILURES" =~ ^[0-9]+$ ]]; then
        TEST_FAILURES=0
    fi
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

    # Build warning message for JSON
    WARNING_MSG="Stop Verification: ${CHECKS_PASSED}/${TOTAL_CHECKS} passed. Issues: "
    for warning in "${WARNINGS[@]}"; do
        WARNING_MSG+="$warning; "
    done

    # Return JSON with warnings (Stop hook - approve with reason)
    return_json "approve" "$WARNING_MSG"
else
    log "All checks passed"
    return_json "approve" "Stop Verification: All ${TOTAL_CHECKS} checks passed"
fi

exit 0
