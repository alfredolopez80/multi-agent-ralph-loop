#!/bin/bash
# verify-context-injection.sh - Verifica que el contexto se inyecte correctamente
# Uso: ./verify-context-injection.sh

set -euo pipefail

echo "🔍 Verificación de Inyección de Contexto Claude-Mem"
echo "=================================================="
echo ""

# 1. Verificar que el worker esté corriendo
echo "1️⃣ Verificando worker de claude-mem..."
if pgrep -f "worker-service.cjs.*--daemon" > /dev/null; then
    echo "   ✅ Worker corriendo (PID: $(pgrep -f 'worker-service.cjs.*--daemon'))"
else
    echo "   ❌ Worker NO corriendo"
    echo "   💡 Ejecuta: ~/.claude-mem/start-worker.sh start"
fi
echo ""

# 2. Probar el hook de contexto manualmente
echo "2️⃣ Probando hook de contexto..."
CONTEXT_OUTPUT=$(~/.bun/bin/bun ~/.claude/plugins/cache/thedotmack/claude-mem/10.0.7/scripts/worker-service.cjs hook claude-code context 2>/dev/null)

if echo "$CONTEXT_OUTPUT" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1; then
    CONTEXT_LENGTH=$(echo "$CONTEXT_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' | wc -c)
    echo "   ✅ Hook produce additionalContext (${CONTEXT_LENGTH} bytes)"
    echo "   📊 Primeras líneas del contexto:"
    echo "$CONTEXT_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' | head -20 | sed 's/^/      /'
else
    echo "   ❌ Hook NO produce additionalContext válido"
fi
echo ""

# 3. Verificar logs recientes
echo "3️⃣ Verificando logs recientes..."
if [[ -f ~/.ralph/logs/session-start-restore.log ]]; then
    RECENT_INJECTIONS=$(grep "Context restoration complete" ~/.ralph/logs/session-start-restore.log | tail -5)
    INJECTION_COUNT=$(echo "$RECENT_INJECTIONS" | wc -l | tr -d ' ')
    echo "   ✅ $INJECTION_COUNT inyecciones recientes encontradas:"
    echo "$RECENT_INJECTIONS" | sed 's/^/      /'
else
    echo "   ⚠️  Log no encontrado en ~/.ralph/logs/session-start-restore.log"
fi
echo ""

# 4. Verificar configuración de hooks
echo "4️⃣ Verificando configuración de hooks..."
if command -v jq > /dev/null; then
    HOOK_COUNT=$(jq '.hooks.SessionStart | length' ~/.claude/settings.json 2>/dev/null || echo "0")
    echo "   ✅ $HOOK_COUNT matchers de SessionStart configurados"

    # Verificar que el hook de contexto esté presente
    if grep -q "worker-service.cjs.*context" ~/.claude/settings.json 2>/dev/null; then
        echo "   ✅ Hook de claude-mem context presente"
    else
        echo "   ❌ Hook de claude-mem context NO encontrado"
    fi
else
    echo "   ⚠️  jq no instalado, no se puede verificar configuración"
fi
echo ""

# 5. Resumen
echo "📋 Resumen"
echo "---------"
if pgrep -f "worker-service.cjs.*--daemon" > /dev/null && \
   echo "$CONTEXT_OUTPUT" | jq -e '.hookSpecificOutput.additionalContext' > /dev/null 2>&1; then
    echo "✅ SISTEMA FUNCIONANDO CORRECTAMENTE"
    echo ""
    echo "El contexto de claude-mem se inyecta silenciosamente al inicio."
    echo "Aunque no lo veas en el chat, está disponible para Claude."
    echo ""
    echo "Para verificar manualmente:"
    echo "  1. Haz /clear para compactar"
    echo "  2. Haz una pregunta sobre trabajo previo del proyecto"
    echo "  3. Si Claude responde correctamente, el contexto funciona"
else
    echo "❌ HAY PROBLEMAS CON EL SISTEMA"
    echo ""
    echo "Revisa los items marcados con ❌ arriba"
fi
