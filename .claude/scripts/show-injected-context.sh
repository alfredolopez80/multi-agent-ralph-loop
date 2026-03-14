#!/bin/bash
# show-injected-context.sh - Muestra el contexto completo que se inyectaría al iniciar
# Uso: ./show-injected-context.sh

set -euo pipefail

echo "📄 Contexto que se inyectará al iniciar sesión en este proyecto:"
echo "=============================================================="
echo ""

# Ejecutar el hook de contexto
CONTEXT_OUTPUT=$(~/.bun/bin/bun ~/.claude/plugins/cache/thedotmack/claude-mem/10.0.7/scripts/worker-service.cjs hook claude-code context 2>/dev/null)

# Extraer y mostrar el additionalContext
echo "$CONTEXT_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext'

echo ""
echo "=============================================================="
echo "📊 Estadísticas:"
CONTEXT_BYTES=$(echo "$CONTEXT_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' | wc -c | tr -d ' ')
CONTEXT_LINES=$(echo "$CONTEXT_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext' | wc -l | tr -d ' ')
echo "   - Tamaño: $CONTEXT_BYTES bytes"
echo "   - Líneas: $CONTEXT_LINES"
echo ""
echo "💡 Este contexto se inyecta SILENCIOSAMENTE al iniciar cada sesión."
echo "   No lo verás en el chat, pero Claude tiene acceso a esta información."
