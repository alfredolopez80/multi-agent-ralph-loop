#!/bin/bash
# session-start-context-zai.sh - Hook específico para Zai que muestra el contexto visualmente
# A diferencia del hook estándar, este usa systemMessage para visibilidad en Zai

set -euo pipefail

# Leer stdin
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
API_KEY=$(echo "$INPUT" | jq -r '.api_key // empty')

# Log para debugging
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/session-start-context-zai.log"

{
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] INFO Zai context hook triggered - session: ${SESSION_ID:-unknown}"
} >> "$LOG_FILE"

# Ejecutar el hook original de claude-mem
CLAUDE_MEM_OUTPUT=$(~/.bun/bin/bun ~/.claude/plugins/cache/thedotmack/claude-mem/10.0.7/scripts/worker-service.cjs hook claude-code context 2>&1)

# Extraer el additionalContext
ADDITIONAL_CONTEXT=$(echo "$CLAUDE_MEM_OUTPUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null || echo "")

if [[ -z "$ADDITIONAL_CONTEXT" ]]; then
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] ERROR No additionalContext found in claude-mem output" >> "$LOG_FILE"
    # Devolver JSON válido aunque no haya contexto
    echo '{"continue":true,"suppressOutput":true}'
    exit 0
fi

# Crear el mensaje visual para Zai (limitado a no saturar)
# Usamos systemMessage para visibilidad y additionalContext para inyección silenciosa
VISUAL_MESSAGE="## 📚 Contexto de Sesiones Anteriores

El contexto histórico de tu proyecto está disponible. Incluye:
- $(echo "$ADDITIONAL_CONTEXT" | grep -o "Loading:.*observations" || echo "50 observaciones recientes")
- Economía de tokens: $(echo "$ADDITIONAL_CONTEXT" | grep -o "Your savings:.*" | sed 's/Your savings/Ahorro/' || echo "~35% de reducción")

---

💡 **Para ver el contexto completo**, ejecuta:
\`\`\`bash
./.claude/scripts/show-injected-context.sh
\`\`\`

O usa el comando de verificación rápida:
\`\`\`bash
./.claude/scripts/verify-context-injection.sh
\`\`\`"

# Escapar el mensaje para JSON (manejar saltos de línea, comillas, etc.)
ESCAPED_MESSAGE=$(echo "$VISUAL_MESSAGE" | jq -Rs .)

# Crear JSON con systemMessage (visible) Y additionalContext (inyección silenciosa)
OUTPUT_JSON=$(cat <<EOF
{
  "systemMessage": ${ESCAPED_MESSAGE},
  "continue": true,
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": $(echo "$ADDITIONAL_CONTEXT" | jq -Rs .)
  }
}
EOF
)

echo "$OUTPUT_JSON" | jq .

{
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] INFO Context delivered to Zai - message length: ${#VISUAL_MESSAGE}" >> "$LOG_FILE"
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] INFO Zai context hook completed" >> "$LOG_FILE"
} >> "$LOG_FILE"
