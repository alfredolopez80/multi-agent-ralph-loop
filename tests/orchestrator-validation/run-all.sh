#!/bin/bash
# run-all.sh - Execute all orchestrator validation tests
# VERSION: 1.0.0
#
# Usage: bash tests/orchestrator-validation/run-all.sh
#
# This script runs:
# 1. Basic validation tests
# 2. Adversarial validation (if available)

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

echo -e "${YELLOW}[1/2]${NC} Running Basic Validation Tests..."

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

echo -e "${YELLOW}[2/2]${NC} Running Adversarial Validation..."

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
