#!/bin/bash
# migrate-zai-to-claude.sh - Migrar datos de zai config a ~/.claude/
# Propósito: Mantener historial de sesiones y proyectos
# Fecha: 2026-02-13
# Uso: ./migrate-zai-to-claude.sh [--dry-run]

set -e

DRY_RUN=false
[ "$1" = "--dry-run" ] && DRY_RUN=true

ZAI_CONFIG="$HOME/.claude-sneakpeek/zai/config"
STD_CLAUDE="$HOME/.claude"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "  Migración Zai → Claude Code"
echo "=========================================="
echo ""
echo "Origen:  $ZAI_CONFIG"
echo "Destino: $STD_CLAUDE"
echo "Mode:    $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "EXECUTE")"
echo ""

# Función para copiar directorio con fusión
merge_dir() {
    local src="$1"
    local dst="$2"
    local name="$3"

    if [ ! -d "$src" ]; then
        echo "   ⚠️  $name: origen no existe"
        return
    fi

    if [ "$DRY_RUN" = true ]; then
        echo "   [DRY] cp -r $src/* $dst/"
        return
    fi

    # Crear destino si no existe
    mkdir -p "$dst"

    # Contar archivos antes
    local before=$(find "$dst" -type f 2>/dev/null | wc -l | tr -d ' ')

    # Copiar con fusión (no sobrescribir existentes)
    cp -rn "$src"/* "$dst/" 2>/dev/null || true

    # Contar archivos después
    local after=$(find "$dst" -type f 2>/dev/null | wc -l | tr -d ' ')

    echo "   ✓ $name: $before → $after archivos (+$((after - before)))"
}

# 1. Migrar projects
echo "📁 1. Migrando projects..."
merge_dir "$ZAI_CONFIG/projects" "$STD_CLAUDE/projects" "projects"

# 2. Migrar session-env
echo "📁 2. Migrando session-env..."
if [ -d "$STD_CLAUDE/session-env" ]; then
    # Backup si ya existe
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$STD_CLAUDE/session-env" "$BACKUP_DIR/" 2>/dev/null || true
    fi
fi
merge_dir "$ZAI_CONFIG/session-env" "$STD_CLAUDE/session-env" "session-env"

# 3. Migrar todos
echo "📁 3. Migrando todos..."
if [ -d "$STD_CLAUDE/todos" ]; then
    if [ "$DRY_RUN" = false ]; then
        mkdir -p "$BACKUP_DIR"
        cp -r "$STD_CLAUDE/todos" "$BACKUP_DIR/" 2>/dev/null || true
    fi
fi
merge_dir "$ZAI_CONFIG/todos" "$STD_CLAUDE/todos" "todos"

# 4. Migrar paste-cache
echo "📁 4. Migrando paste-cache..."
merge_dir "$ZAI_CONFIG/paste-cache" "$STD_CLAUDE/paste-cache" "paste-cache"

# 5. Migrar debug (opcional, muchos archivos)
echo "📁 5. Migrando debug (últimos 7 días)..."
if [ "$DRY_RUN" = true ]; then
    echo "   [DRY] find $ZAI_CONFIG/debug -mtime -7 -exec cp {} $STD_CLAUDE/debug/ \\;"
else
    mkdir -p "$STD_CLAUDE/debug"
    find "$ZAI_CONFIG/debug" -type f -mtime -7 -exec cp {} "$STD_CLAUDE/debug/" \; 2>/dev/null || true
    local debug_count=$(ls -1 "$STD_CLAUDE/debug" 2>/dev/null | wc -l | tr -d ' ')
    echo "   ✓ debug: $debug_count archivos (últimos 7 días)"
fi

# 6. Migrar file-history
echo "📁 6. Migrando file-history..."
merge_dir "$ZAI_CONFIG/file-history" "$STD_CLAUDE/file-history" "file-history"

# Resumen
echo ""
echo "=========================================="
echo "  Resumen de Migración"
echo "=========================================="

if [ "$DRY_RUN" = false ]; then
    echo "  Projects:     $(ls -1 "$STD_CLAUDE/projects" 2>/dev/null | wc -l | tr -d ' ') directorios"
    echo "  Session-env:  $(ls -1 "$STD_CLAUDE/session-env" 2>/dev/null | wc -l | tr -d ' ') sesiones"
    echo "  Todos:        $(ls -1 "$STD_CLAUDE/todos" 2>/dev/null | wc -l | tr -d ' ') archivos"
    echo "  Debug:        $(ls -1 "$STD_CLAUDE/debug" 2>/dev/null | wc -l | tr -d ' ') archivos"
    [ -d "$BACKUP_DIR" ] && echo ""
    [ -d "$BACKUP_DIR" ] && echo "  Backup:       $BACKUP_DIR"
else
    echo "  (Modo DRY RUN - no se hicieron cambios)"
fi

echo ""
[ "$DRY_RUN" = false ] && echo "✅ Migración completada"
