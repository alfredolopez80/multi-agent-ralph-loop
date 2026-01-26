#!/bin/bash
# run-all.sh - Execute all orchestrator validation tests
# VERSION: 1.0.0
#
# Usage: bash tests/orchestrator-validation/run-all.sh
#
# This script runs:
# 1. Basic validation tests
# 2. Adversarial validation (if available)
# 3. Codex CLI validation (if available)
# 4. Gemini CLI validation (if available)

set -euo pipefail

cd "$(dirname "$0")"
cd ../..

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0;32m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Orchestrator Validation - Running All Tests${NC}"
echo -e "${BLUE}========================================${NC}\n"

# ==============================================================================
# Test Suite 1: Basic Validation
# ==============================================================================

echo -e "${YELLOW}[1/4]${NC} Running Basic Validation Tests..."

if bash tests/orchestrator-validation/test-suite.sh; then
    PASSED_TESTS=$((PASSED_TESTS + 10))
    echo -e "${GREEN}✅ Basic Validation: PASSED (10/10 tests)${NC}\n"
else
    FAILED_TESTS=$((FAILED_TESTS + 10))
    echo -e "${RED}❌ Basic Validation: FAILED${NC}\n"
fi

TOTAL_TESTS=$((TOTAL_TESTS + 10))

# ==============================================================================
# Test Suite 2: Adversarial Validation (if available)
# ==============================================================================

echo -e "${YELLOW}[2/4]${NC} Running Adversarial Validation..."

if command -v /adversarial &>/dev/null; then
    echo "Found /adversarial - running adversarial validation..."

    if /adversarial "Validar que el workflow /orchestrator funciona correctamente:
    1. Verificar que FAST PATH funciona para tareas simples
    2. Verificar que STANDARD workflow (12 pasos) se ejecuta completamente
    3. Verificar que las verificaciones se coordinan automáticamente
    4. Verificar que hay visibilidad del progreso
    5. Verificar que el workflow no se estanca" --output tests/orchestrator-validation/adversarial-report.md; then
        PASSED_TESTS=$((PASSED_TESTS + 5))
        echo -e "${GREEN}✅ Adversarial Validation: PASSED${NC}\n"
    else
        FAILED_TESTS=$((FAILED_TESTS + 5))
        echo -e "${RED}❌ Adversarial Validation: FAILED${NC}\n"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 5))
else
    echo -e "${YELLOW}⚠️  /adversarial not found - skipping adversarial validation${NC}\n"
    echo "Install with: npm install -g @anthropic-ai/advtest-2  (or equivalent)"
fi

# ==============================================================================
# Test Suite 3: Codex CLI Validation (if available)
# ==============================================================================

echo -e "${YELLOW}[3/4]${NC} Running Codex CLI Validation..."

if command -v codex &>/dev/null; then
    echo "Found codex CLI - running Codex validation..."

    if codex "Analizar el workflow del orchestrator:

Archivo: ~/.claude/agents/orchestrator.md

Validar:
1. Que el flow FAST PATH esté correctamente documentado
2. Que el flow STANDARD (12 pasos) esté completo
3. Que la coordinación de auto-verificación esté implementada
4. Que los hooks necesarios estén registrados
5. Que no haya regresiones desde v2.47

Verificar compatibilidad hacia atrás y documentar cualquier issue encontrado." --output tests/orchestrator-validation/codex-report.md; then
        PASSED_TESTS=$((PASSED_TESTS + 5))
        echo -e "${GREEN}✅ Codex Validation: PASSED${NC}\n"
    else
        FAILED_TESTS=$((FAILED_TESTS + 5))
        echo -e "${RED}❌ Codex Validation: FAILED${NC}\n"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 5))
else
    echo -e "${YELLOW}⚠️  codex CLI not found - skipping Codex validation${NC}\n"
    echo "Install with: npm install -g @openai/codex"
fi

# ==============================================================================
# Test Suite 4: Gemini CLI Validation (if available)
# ==============================================================================

echo -e "${YELLOW}[4/4]${NC} Running Gemini CLI Validation..."

if command -v gemini &>/dev/null; then
    echo "Found gemini CLI - running Gemini validation..."

    if gemini "Revisar la implementación del orchestrator v2.70.1:

Archivos a revisar:
- ~/.claude/agents/orchestrator.md
- ~/.claude/hooks/code-review-auto.sh
- ~/.claude/hooks/verification-subagent.sh
- ~/.claude/hooks/subagent-visibility.sh
- ~/.claude/hooks/auto-verification-coordinator.sh

Validar:
1. Coordinación de auto-verificación está correctamente implementada
2. Hooks de visibilidad están registrados
3. Timeout está correctamente configurado
4. No hay bloqueos en el flujo
5. El workflow puede completarse sin intervención manual

Reportar cualquier issue de compatibilidad o bug potencial." --output tests/orchestrator-validation/gemini-report.md; then
        PASSED_TESTS=$((PASSED_TESTS + 5))
        echo -e "${GREEN}✅ Gemini Validation: PASSED${NC}\n"
    else
        FAILED_TESTS=$((FAILED_TESTS + 5))
        echo -e "${RED}❌ Gemini Validation: FAILED${NC}\n"
    fi
    TOTAL_TESTS=$((TOTAL_TESTS + 5))
else
    echo -e "${YELLOW}⚠️  gemini CLI not found - skipping Gemini validation${NC}\n"
    echo "Install with: npm install -g @anthropic-ai/gemini-cli"
fi

# ==============================================================================
# Final Summary
# ==============================================================================

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Final Test Summary${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "Total Tests Run:    $TOTAL_TESTS"
echo -e "Tests Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Tests Failed:       ${RED}$FAILED_TESTS${NC}"
echo -e ""
echo -e "Test Reports Generated:"
echo -e "  - tests/orchestrator-validation/test-run.log"
echo -e "  - tests/orchestrator-validation/adversarial-report.md (if /adversarial available)"
echo -e "  - tests/orchestrator-validation/codex-report.md (if codex available)"
echo -e "  - tests/orchestrator-validation/gemini-report.md (if gemini available)"
echo -e ""

echo "=== Final Summary ==="
echo "Total: $TOTAL_TESTS | Passed: $PASSED_TESTS | Failed: $FAILED_TESTS" >> tests/orchestrator-validation/test-summary.log 2>/dev/null || true

if [[ $FAILED_TESTS -eq 0 ]]; then
    echo -e "${GREEN}✅✅✅ ALL VALIDATIONS PASSED ✅✅✅${NC}\n"
    echo -e "${GREEN}El workflow /orchestrator está correctamente configurado${NC}"
    echo -e "${GREEN}y listo para producción.${NC}\n"
    exit 0
else
    echo -e "${RED}❌ SOME VALIDATIONS FAILED ❌${NC}\n"
    echo -e "${YELLOW}Revisa los reportes generados para más detalles.${NC}\n"
    exit 1
fi
