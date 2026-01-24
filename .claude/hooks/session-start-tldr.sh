#!/bin/bash
#
# session-start-tldr.sh - Auto-warm llm-tldr index on session start
# Multi-Agent Ralph v2.40
#
# Este hook se ejecuta automáticamente al iniciar una sesión de Claude Code.
# Detecta si el proyecto tiene código y calienta el índice TLDR en background.
#
# Requisitos:
#   - llm-tldr instalado: pip install llm-tldr
#   - Proyecto con código fuente (.py, .ts, .js, .go, .rs, .java, etc.)
#
# El índice TLDR proporciona:
#   - 95% ahorro de tokens en análisis de código
#   - Búsqueda semántica de funcionalidad
#   - Análisis de impacto de cambios
#   - Contexto optimizado para LLMs
#

# No usar set -e para evitar que errores de tldr detengan la sesión
# VERSION: 2.68.2
# v2.52: Fixed JSON output format for SessionStart hooks
set +e

# Obtener directorio del proyecto desde variable de entorno o usar directorio actual
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TLDR_DIR="$PROJECT_DIR/.tldr"
LOG_FILE="/tmp/tldr-warm-$$.log"

# Función para verificar si hay código en el proyecto
has_source_code() {
    # Buscar archivos de código comunes (max depth 3 para evitar node_modules profundos)
    local code_files
    code_files=$(find "$PROJECT_DIR" -maxdepth 3 \
        \( -name "*.py" -o -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \
           -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.kt" \
           -o -name "*.rb" -o -name "*.php" -o -name "*.swift" -o -name "*.c" \
           -o -name "*.cpp" -o -name "*.h" -o -name "*.cs" -o -name "*.sol" \) \
        -not -path "*/node_modules/*" \
        -not -path "*/.git/*" \
        -not -path "*/venv/*" \
        -not -path "*/__pycache__/*" \
        -print -quit 2>/dev/null)

    [ -n "$code_files" ]
}

# Función principal
main() {
    # Verificar si tldr está instalado
    if ! command -v tldr &>/dev/null; then
        # tldr no instalado, salir silenciosamente
        exit 0
    fi

    # Verificar si ya existe un índice TLDR
    if [ -d "$TLDR_DIR" ]; then
        # Índice ya existe, verificar si necesita actualización
        local index_age_hours=0
        if [ -f "$TLDR_DIR/index.json" ]; then
            local index_mtime
            index_mtime=$(stat -f %m "$TLDR_DIR/index.json" 2>/dev/null || stat -c %Y "$TLDR_DIR/index.json" 2>/dev/null)
            local now
            now=$(date +%s)
            index_age_hours=$(( (now - index_mtime) / 3600 ))
        fi

        # Si el índice tiene menos de 24 horas, no reconstruir
        if [ "$index_age_hours" -lt 24 ]; then
            exit 0
        fi
    fi

    # Verificar si hay código en el proyecto
    if ! has_source_code; then
        # No hay código fuente, salir silenciosamente
        exit 0
    fi

    # Ejecutar tldr warm en background para no bloquear la sesión
    {
        echo "[$(date)] Starting tldr warm for $PROJECT_DIR"
        tldr warm "$PROJECT_DIR" 2>&1
        echo "[$(date)] Completed tldr warm"
    } > "$LOG_FILE" 2>&1 &

    # Mensaje informativo a stderr (v2.52: stdout debe ser JSON)
    echo "llm-tldr warming index in background (95% token savings)..." >&2

    # Return JSON for SessionStart (v2.52 fix)
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "llm-tldr warming index in background (95% token savings)..."}}'
}

# Función para salida silenciosa con JSON válido
silent_exit() {
    echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
    exit 0
}

# Ejecutar main, si no hay output, dar JSON vacío
output=$(main "$@")
if [[ -z "$output" ]]; then
    silent_exit
else
    echo "$output"
fi
