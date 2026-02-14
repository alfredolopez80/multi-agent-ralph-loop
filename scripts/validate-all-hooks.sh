#!/bin/bash
# validate-all-hooks.sh - Diagnóstico exhaustivo de hooks de Claude Code
# Fecha: 2026-02-14
# Uso: ./validate-all-hooks.sh [--test]

set -e

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
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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
    ((fail++))
fi

if jq empty "$SETTINGS" 2>/dev/null; then
    echo -e "   ${GREEN}✅${NC} JSON válido"
    ((pass++))
else
    echo -e "   ${RED}❌${NC} JSON inválido"
    ((fail++))
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
            ((pass++))
        else
            echo -e "   ${RED}❌${NC} $dir → $target (ROTO)"
            ((fail++))
        fi
    else
        echo -e "   ${YELLOW}⚠️${NC}  $dir no es symlink"
        ((warn++))
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
    ((pass++))
else
    echo -e "   ${YELLOW}⚠️${NC}  CLAUDE_PLUGIN_ROOT NO está en env de settings.json"
    ((warn++))
fi

# Verificar directorio del plugin
if [ -d "$PLUGIN_ROOT" ]; then
    echo -e "   ${GREEN}✅${NC} Plugin directory existe"
    ((pass++))
else
    echo -e "   ${RED}❌${NC} Plugin directory NO existe: $PLUGIN_ROOT"
    ((fail++))
fi

# Verificar worker
if [ -f "$PLUGIN_ROOT/scripts/worker-service.cjs" ]; then
    echo -e "   ${GREEN}✅${NC} worker-service.cjs existe"
    ((pass++))
else
    echo -e "   ${RED}❌${NC} worker-service.cjs NO existe"
    ((fail++))
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
    ((warn++))
else
    echo -e "   ${GREEN}✅${NC} No hay referencias a \${CLAUDE_PLUGIN_ROOT}"
    echo "      (usando rutas absolutas)"
    ((pass++))
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

if [ $fail -eq 0 ]; then
    echo -e "${GREEN}✅ Todos los hooks están configurados correctamente${NC}"
else
    echo -e "${RED}❌ Hay $fail problemas que necesitan atención${NC}"
fi

echo ""
echo "Para probar ejecución de hooks, ejecuta:"
echo "  $0 --test"
echo ""
