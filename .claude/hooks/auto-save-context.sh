#!/bin/bash
# Auto-Save Context Hook - 2-Action Rule
# Guarda contexto cada N operaciones para prevenir pérdida
# Origen: planning-with-files "Context Engineering" pattern
# v1.0.0 - 2026-01-13

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


# VERSION: 2.69.0
# v2.57.3: Fixed LAST remaining legacy output format on line 89 (SEC-037)
# v2.57.2: Fixed JSON output format (SEC-036) - PostToolUse hooks MUST output JSON
set -euo pipefail

# SEC-036: Guaranteed valid JSON output on any error or exit
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

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
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top

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
    # SEC: Safe file cleanup without xargs (handles spaces in paths)
    ls -t "${STATE_DIR}"/context-snapshot-*.md 2>/dev/null | tail -n +11 | while IFS= read -r f; do rm -f "$f"; done 2>/dev/null || true

    log "Context saved to ${STATE_FILE}"

    # Output JSON válido con mensaje informativo (PostToolUse: {"continue": true})
    # CRIT-003: Clear trap before explicit JSON output to avoid duplicates
    trap - ERR EXIT
    echo "{\"continue\": true, \"systemMessage\": \"📸 Context snapshot #${CURRENT_COUNT} saved. Next: #$((CURRENT_COUNT + SAVE_INTERVAL))\"}"
else
    # Always output valid JSON
    # CRIT-003: Clear trap before explicit JSON output to avoid duplicates
    trap - ERR EXIT
    echo '{"continue": true}'
fi
