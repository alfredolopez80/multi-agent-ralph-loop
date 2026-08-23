#!/bin/bash
# validate-all-hooks.sh - Diagnóstico exhaustivo de hooks de Claude Code
# Fecha: 2026-02-14
# Uso: ./validate-all-hooks.sh [--test]

set -e
# NOTE: use `VAR=$((VAR+1))`, never `VAR=$((VAR+1))`. Under set -e, a post-increment
# on a counter holding 0 evaluates to 0 -> exit status 1 -> the script aborts silently,
# leaving zero counters and an apparent early success.

SETTINGS="$HOME/.claude/settings.json"
REPO_HOOKS="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks"
PLUGIN_ROOT="/Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/10.0.6"
RUN_TESTS="${1:-}"

echo "=========================================="
echo "  VALIDACIÓN EXHAUSTIVA DE HOOKS"
echo "  Fecha: $(date)"
echo "=========================================="
echo ""

# Colores
# Shared colors, counters and the zero-checks verdict guard.
_VC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_VC_DIR}/lib/validation-common.sh"

pass=0
fail=0
warn=0

# ==========================================
# 1. VERIFICAR ESTRUCTURA JSON
# ==========================================
echo "📁 1. VERIFICANDO settings.json"
echo "-------------------------------------------"

if [ -f "$SETTINGS" ]; then
    echo -e "   ${GREEN}✅${NC} Archivo existe: $SETTINGS"
else
    echo -e "   ${RED}❌${NC} Archivo NO existe: $SETTINGS"
    fail=$((fail+1))
fi

if jq empty "$SETTINGS" 2>/dev/null; then
    echo -e "   ${GREEN}✅${NC} JSON válido"
    pass=$((pass+1))
else
    echo -e "   ${RED}❌${NC} JSON inválido"
    fail=$((fail+1))
fi

echo ""

# ==========================================
# 2. VERIFICAR SYMLINKS
# ==========================================
echo "📁 2. VERIFICANDO SYMLINKS"
echo "-------------------------------------------"

for dir in agents commands skills hooks rules; do
    if [ -L "$HOME/.claude/$dir" ]; then
        target=$(readlink "$HOME/.claude/$dir")
        if [ -d "$HOME/.claude/$dir" ]; then
            count=$(ls -1 "$HOME/.claude/$dir" 2>/dev/null | wc -l | tr -d ' ')
            echo -e "   ${GREEN}✅${NC} $dir → $target ($count elementos)"
            pass=$((pass+1))
        else
            echo -e "   ${RED}❌${NC} $dir → $target (ROTO)"
            fail=$((fail+1))
        fi
    else
        echo -e "   ${YELLOW}⚠️${NC}  $dir no es symlink"
        warn=$((warn+1))
    fi
done

echo ""

# ==========================================
# 3. VERIFICAR CLAUDE_PLUGIN_ROOT
# ==========================================
echo "📁 3. VERIFICANDO CLAUDE-MEM PLUGIN"
echo "-------------------------------------------"

# Verificar variable en env de settings.json
if jq -e '.env.CLAUDE_PLUGIN_ROOT' "$SETTINGS" > /dev/null 2>&1; then
    env_plugin=$(jq -r '.env.CLAUDE_PLUGIN_ROOT' "$SETTINGS")
    echo -e "   ${GREEN}✅${NC} CLAUDE_PLUGIN_ROOT en env: $env_plugin"
    pass=$((pass+1))
else
    echo -e "   ${YELLOW}⚠️${NC}  CLAUDE_PLUGIN_ROOT NO está en env de settings.json"
    warn=$((warn+1))
fi

# claude-mem fue eliminado del proyecto (Wave 0, retirada forense completa). Verificar
# su presencia hacía fallar el validador por la ausencia de algo retirado a propósito.
# Se comprueba lo contrario: que no haya vuelto.
if [ -d "$PLUGIN_ROOT" ]; then
    echo -e "   ${RED}❌${NC} claude-mem reapareció en $PLUGIN_ROOT (fue retirado en Wave 0)"
    fail=$((fail+1))
else
    echo -e "   ${GREEN}✅${NC} claude-mem ausente (retirado en Wave 0)"
    pass=$((pass+1))
fi

# worker-service.cjs pertenecía al mismo plugin retirado.
if [ -f "$PLUGIN_ROOT/scripts/worker-service.cjs" ]; then
    echo -e "   ${RED}❌${NC} worker-service.cjs de claude-mem reapareció"
    fail=$((fail+1))
else
    echo -e "   ${GREEN}✅${NC} worker-service.cjs ausente (plugin retirado)"
    pass=$((pass+1))
fi

echo ""

# ==========================================
# 4. CONTAR HOOKS POR EVENTO
# ==========================================
echo "📁 4. HOOKS REGISTRADOS POR EVENTO"
echo "-------------------------------------------"

for event in SessionStart PreToolUse PostToolUse Stop PreCompact UserPromptSubmit SubagentStop; do
    count=$(jq ".hooks.$event | length" "$SETTINGS" 2>/dev/null || echo "0")
    echo "   $event: $count configuraciones"
done

echo ""

# ==========================================
# 5. VERIFICAR ARCHIVOS DE HOOKS
# ==========================================
echo "📁 5. VERIFICANDO ARCHIVOS DE HOOKS"
echo "-------------------------------------------"

total_hooks=0
valid_hooks=0
invalid_hooks=0

# Hooks del proyecto
echo "   Hooks del proyecto:"
jq -r '.hooks[][]?.hooks[]?.command // empty' "$SETTINGS" 2>/dev/null | grep "^/" | grep -v "worker-service" | sort -u | while read -r cmd; do
    script_path=$(echo "$cmd" | awk '{print $1}')

    if [ -f "$script_path" ]; then
        if [ -x "$script_path" ]; then
            echo -e "      ${GREEN}✅${NC} $(basename "$script_path")"
        else
            echo -e "      ${YELLOW}⚠️${NC}  $(basename "$script_path") (NO ejecutable)"
        fi
    else
        echo -e "      ${RED}❌${NC} $(basename "$script_path") (NO existe)"
    fi
done

echo ""
echo "   Hooks de claude-mem:"
if grep -q "worker-service.cjs" "$SETTINGS"; then
    echo -e "      ${GREEN}✅${NC} worker-service.cjs configurado"
else
    echo -e "      ${RED}❌${NC} worker-service.cjs NO configurado"
fi

echo ""

# ==========================================
# 6. PROBAR EJECUCIÓN DE HOOKS (si --test)
# ==========================================
if [ "$RUN_TESTS" = "--test" ]; then
    echo "📁 6. PROBANDO EJECUCIÓN DE HOOKS"
    echo "-------------------------------------------"

    echo "   Probando session-start-restore-context.sh..."
    if timeout 10 "$REPO_HOOKS/session-start-restore-context.sh" 2>&1 | jq -e '.hookSpecificOutput' > /dev/null 2>&1; then
        echo -e "      ${GREEN}✅${NC} Output JSON válido"
    else
        echo -e "      ${RED}❌${NC} Output JSON inválido"
    fi

    echo "   Probando context-warning.sh..."
    if echo '{"prompt": "test"}' | timeout 10 "$REPO_HOOKS/context-warning.sh" 2>&1 | jq -e '.message' > /dev/null 2>&1; then
        echo -e "      ${GREEN}✅${NC} Output JSON válido"
    else
        echo -e "      ${RED}❌${NC} Output JSON inválido"
    fi

    echo "   Probando claude-mem worker start..."
    if timeout 10 bun "$PLUGIN_ROOT/scripts/worker-service.cjs" start 2>&1 | jq -e '.continue' > /dev/null 2>&1; then
        echo -e "      ${GREEN}✅${NC} Worker responde correctamente"
    else
        echo -e "      ${RED}❌${NC} Worker no responde"
    fi

    echo "   Probando claude-mem context hook..."
    if timeout 15 bun "$PLUGIN_ROOT/scripts/worker-service.cjs" hook claude-code context 2>&1 | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1; then
        echo -e "      ${GREEN}✅${NC} Context hook genera contexto"
    else
        echo -e "      ${RED}❌${NC} Context hook falla"
    fi

    echo ""
fi

# ==========================================
# 7. VERIFICAR RUTAS ABSOLUTAS VS VARIABLES
# ==========================================
echo "📁 7. VERIFICANDO RUTAS EN settings.json"
echo "-------------------------------------------"

if grep -q '\${CLAUDE_PLUGIN_ROOT}' "$SETTINGS"; then
    echo -e "   ${YELLOW}⚠️${NC}  Se encontraron referencias a \${CLAUDE_PLUGIN_ROOT}"
    echo "      Estas pueden no expandirse correctamente en hooks."
    echo "      Considera usar rutas absolutas."
    warn=$((warn+1))
else
    echo -e "   ${GREEN}✅${NC} No hay referencias a \${CLAUDE_PLUGIN_ROOT}"
    echo "      (usando rutas absolutas)"
    pass=$((pass+1))
fi

echo ""

# ==========================================
# RESUMEN
# ==========================================
echo "=========================================="
echo "  RESUMEN"
echo "=========================================="
echo ""
echo -e "   ${GREEN}Pasaron:${NC} $pass"
echo -e "   ${RED}Fallaron:${NC} $fail"
echo -e "   ${YELLOW}Advertencias:${NC} $warn"
echo ""

if [ $((pass + fail)) -eq 0 ]; then
    echo -e "${RED}❌ Cero comprobaciones ejecutadas — no se puede declarar éxito${NC}"
    exit 1
elif [ $fail -eq 0 ]; then
    echo -e "${GREEN}✅ Todos los hooks están configurados correctamente${NC}"
else
    # Antes imprimía este error y salía 0: el exit code contradecía el veredicto,
    # así que ningún CI podía detectar el fallo.
    echo -e "${RED}❌ Hay $fail problemas que necesitan atención${NC}"
    exit 1
fi

echo ""
echo "Para probar ejecución de hooks, ejecuta:"
echo "  $0 --test"
echo ""
