#!/bin/bash
# validate-orchestrator.sh - Validación completa del workflow /orchestrator
# VERSION: 1.0.0
#
# Uso: bash .claude/validate-orchestrator.sh
#
# Ejecuta validación completa usando:
# - Tests básicos del suite
# - /adversarial (si está disponible)
# - /codex-cli (si está disponible)
# - /gemini-cli (si está disponible)
#
# Salida: Reporte completo en tests/orchestrator-validation/

set -euo pipefail

cd /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validación Completa /orchestrator${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "${YELLOW}Iniciando validación completa...${NC}\n"

# Ejecutar el test suite completo
bash tests/orchestrator-validation/run-all.sh

exit_code=$?

if [[ $exit_code -eq 0 ]]; then
    echo -e "\n${GREEN}✅ VALIDACIÓN COMPLETADA${NC}\n"
    echo -e "${GREEN}El workflow /orchestrator está listo para producción${NC}\n"
else
    echo -e "\n${YELLOW}⚠️  VALIDACIÓN COMPLETADA CON ERRORES${NC}\n"
    echo -e "${YELLOW}Revisa los reportes para más detalles:${NC}\n"
    echo -e "  - tests/orchestrator-validation/test-run.log"
    echo -e "  - tests/orchestrator-validation/adversarial-report.md"
    echo -e "  - tests/orchestrator-validation/codex-report.md"
    echo -e "  - tests/orchestrator-validation/gemini-report.md"
fi

exit $exit_code
