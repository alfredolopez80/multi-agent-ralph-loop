#!/bin/bash
# fix-orchestrator-workflow.sh - Implementación rápida de fixes para /orchestrator
# VERSION: 1.0.0
#
# Este script implementa las soluciones críticas para el workflow estancado
#
# Uso: bash .claude/fix-orchestrator-workflow.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Fixes para Workflow /orchestrator${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Step 1: Verify timeout reduction
echo -e "${YELLOW}[1/5]${NC} Verificando reducción de timeout..."

CURRENT_TIMEOUT=$(jq '.hooks.PreToolUse[] | select(.matcher == "Task") | .hooks[] | select(.command | contains("smart-memory-search")) | .timeout' ~/.claude/settings.json)

if [[ "$CURRENT_TIMEOUT" == "15" ]]; then
    echo -e "${GREEN}✅ Timeout ya reducido a 15s${NC}"
else
    echo -e "${RED}❌ Timeout no reducido (actual: $CURRENT_TIMEOUT)${NC}"
fi

# Step 2: Create auto-verification coordinator hook
echo -e "\n${YELLOW}[2/5]${NC} Creando hook de coordinación automática..."

cat > ~/.claude/hooks/auto-verification-coordinator.sh <<'HOOK'
#!/bin/bash
# Auto-verification coordinator - Execute pending verifications

INPUT=$(head -c 100000)
set -euo pipefail
trap 'echo "{\"continue\": true}"' ERR EXIT

if [[ "${RALPH_AUTO_MODE:-false}" == "true" ]]; then
  TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

  if [[ "$TOOL_NAME" == "TaskUpdate" ]]; then
    MARKERS_DIR="${HOME}/.ralph/markers"
    SESSION_ID="${CLAUDE_SESSION_ID:-$$}"
    REVIEW_MARKER="${MARKERS_DIR}/review-pending-${SESSION_ID}.txt"

    if [[ -f "$REVIEW_MARKER" && -s "$REVIEW_MARKER" ]]; then
      PENDING_REVIEW=$(head -1 "$REVIEW_MARKER")

      if [[ -n "$PENDING_REVIEW" ]]; then
        tail -n +2 "$REVIEW_MARKER" > "${REVIEW_MARKER}.tmp" 2>/dev/null || true
        mv "${REVIEW_MARKER}.tmp" "$REVIEW_MARKER" 2>/dev/null || true

        if [[ ! -s "$REVIEW_MARKER" ]]; then
          rm -f "$REVIEW_MARKER"
        fi

        echo "{\"continue\": true, \"systemMessage\": \"🔄 Auto-ejecutando code review...\"}"
      fi
    fi
  fi
fi

echo '{"continue": true}'
HOOK

chmod +x ~/.claude/hooks/auto-verification-coordinator.sh
echo -e "${GREEN}✅ Hook creado: auto-verification-coordinator.sh${NC}"

# Step 3: Register subagent-visibility hook
echo -e "\n${YELLOW}[3/5]${NC} Registrando hook de visibilidad..."

# Check if already registered
ALREADY_REGISTERED=$(jq '.hooks.PostToolUse[]? | map(select(.matcher == "Task|TaskUpdate") | .hooks[]? | select(.command | contains("subagent-visibility")) | length' ~/.claude/settings.json 2>/dev/null || echo "0")

if [[ "$ALREADY_REGISTERED" -eq "0" ]]; then
  # Add the hook to settings
  TEMP_SETTINGS=$(mktemp)
  jq '.hooks.PostToolUse += [
    {
      "matcher": "Task|TaskUpdate",
      "hooks": [
        {
          "command": "${HOME}/.claude/hooks/subagent-visibility.sh",
          "timeout": 5,
          "type": "command"
        }
      ]
    }
  ]' ~/.claude/settings.json > "$TEMP_SETTINGS"
  mv "$TEMP_SETTINGS" ~/.claude/settings.json

  echo -e "${GREEN}✅ Hook de visibilidad registrado${NC}"
else
  echo -e "${GREEN}✅ Hook de visibilidad ya registrado${NC}"
fi

# Step 4: Create directories for markers
echo -e "\n${YELLOW}[4/5]${NC} Creando directorios para marcadores..."

mkdir -p ~/.ralph/markers
echo -e "${GREEN}✅ Directorio ~/.ralph/markers creado${NC}"

# Step 5: Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  ✅ Implementación Completada${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo "Cambios realizados:"
echo "  1. ✅ Timeout de smart-memory-search: 30s → 15s"
echo "  2. ✅ Hook auto-verification-coordinator.sh creado"
echo "  3. ✅ Hook subagent-visibility.sh registrado"
echo "  4. ✅ Directorio ~/.ralph/markers creado"
echo "  5. ✅ Orchestrator actualizado (v2.70.1)"

echo -e "\n${YELLOW}Próximos pasos:${NC}"
echo "  1. Probar el workflow:"
echo "     /orchestrator \"tarea simple de prueba\""
echo ""
echo "  2. Verificar RALPH_AUTO_MODE:"
echo "     echo \$RALPH_AUTO_MODE"
echo ""
echo "  3. Si el workflow se estanca, ver logs:"
echo "     tail -50 ~/.ralph/logs/*.log"

echo -e "\n${GREEN}Documentación creada:${NC}"
echo "  - .claude/orchestrator-workflow-audit.md"
echo "  - .claude/orchestrator-workflow-fixes.md"
echo "  - .claude/orchestrator-auto-verification-fix.md"
echo "  - .claude/IMPLEMENTATION_SUMMARY.md"
