#!/bin/bash
# Auto-Save Context Hook - 2-Action Rule
# Guarda contexto cada N operaciones para prevenir pérdida
# Origen: planning-with-files "Context Engineering" pattern
# v1.0.0 - 2026-01-13

set -euo pipefail

# Configuración
SAVE_INTERVAL=${RALPH_AUTO_SAVE_INTERVAL:-5}  # Cada 5 operaciones por defecto
COUNTER_FILE="${HOME}/.ralph/state/operation-counter"
STATE_DIR="${HOME}/.ralph/state"
LOG_FILE="${HOME}/.ralph/logs/auto-save-context.log"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

# Asegurar directorios existen
mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Leer input de Claude
INPUT=$(cat)

# Obtener contador actual
if [ -f "$COUNTER_FILE" ]; then
    CURRENT_COUNT=$(cat "$COUNTER_FILE")
else
    CURRENT_COUNT=0
fi

# Incrementar contador
CURRENT_COUNT=$((CURRENT_COUNT + 1))
echo "$CURRENT_COUNT" > "$COUNTER_FILE"

# Verificar si es momento de guardar
if [ $((CURRENT_COUNT % SAVE_INTERVAL)) -eq 0 ]; then
    log "Auto-save triggered at operation #${CURRENT_COUNT}"

    # Guardar estado actual
    TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
    STATE_FILE="${STATE_DIR}/context-snapshot-${TIMESTAMP}.md"

    # Crear snapshot del contexto
    {
        echo "# Context Snapshot"
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Operation: #${CURRENT_COUNT}"
        echo "Project: ${PROJECT_DIR}"
        echo ""

        # Incluir progress.md si existe
        if [ -f "${PROJECT_DIR}/.claude/progress.md" ]; then
            echo "## Progress"
            cat "${PROJECT_DIR}/.claude/progress.md"
            echo ""
        fi

        # Incluir últimos archivos modificados
        echo "## Recent Changes"
        if [ -d "${PROJECT_DIR}/.git" ]; then
            git -C "$PROJECT_DIR" status --porcelain 2>/dev/null | head -20 || echo "No git changes"
        else
            echo "Not a git repository"
        fi
        echo ""

        # Timestamp de último save
        echo "## Auto-Save Info"
        echo "- Interval: Every ${SAVE_INTERVAL} operations"
        echo "- Next save: Operation #$((CURRENT_COUNT + SAVE_INTERVAL))"
    } > "$STATE_FILE"

    # Mantener solo los últimos 10 snapshots
    ls -t "${STATE_DIR}"/context-snapshot-*.md 2>/dev/null | tail -n +11 | xargs rm -f 2>/dev/null || true

    log "Context saved to ${STATE_FILE}"

    # Output para Claude (informativo, no blocking)
    echo "AUTO_SAVE: Context snapshot #${CURRENT_COUNT} saved"
    echo "  Next auto-save: Operation #$((CURRENT_COUNT + SAVE_INTERVAL))"
else
    # No output si no es momento de guardar (reducir ruido)
    :
fi

exit 0
