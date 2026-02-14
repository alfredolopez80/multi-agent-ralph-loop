#!/bin/bash
# setup-symlinks.sh - Configurar symlinks para Claude Code
# Repo: multi-agent-ralph-loop
# Fecha: 2026-02-14
# Version: 1.0.0
# Uso: ./setup-symlinks.sh [--dry-run]

set -e

# Configuracion
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
REPO_CLAUDE="$REPO_ROOT/.claude"
STD_CLAUDE="$HOME/.claude"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false

# Parsear argumentos
[ "$1" = "--dry-run" ] && DRY_RUN=true

echo "=========================================="
echo "  Setup Symlinks - Claude Code"
echo "=========================================="
echo ""
echo "Repo:  $REPO_ROOT"
echo "Target: $STD_CLAUDE"
echo "Mode:  $([ "$DRY_RUN" = true ] && echo "DRY RUN" || echo "EXECUTE")"
echo ""

# Funcion para crear symlink
make_symlink() {
    local src="$1"
    local dst="$2"
    local name="$3"

    # Si ya es symlink, verificar que apunta al lugar correcto
    if [ -L "$dst" ]; then
        current=$(readlink "$dst")
        if [ "$current" = "$src" ]; then
            echo "   ✓ $name ya es symlink correcto"
            return 0
        else
            if [ "$DRY_RUN" = true ]; then
                echo "  [DRY] rm $dst (symlink incorrecto)"
            else
                rm "$dst"
                echo "   ! $name era symlink incorrecto, actualizando..."
            fi
        fi
    fi

    # Si es directorio real, hacer backup
    if [ -d "$dst" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY] mv $dst $BACKUP_DIR/$name"
        else
            mkdir -p "$BACKUP_DIR"
            mv "$dst" "$BACKUP_DIR/"
            echo "   [BACKUP] $name → $BACKUP_DIR/"
        fi
    fi

    # Crear symlink
    if [ "$DRY_RUN" = true ]; then
        echo "  [DRY] ln -sf $src $dst"
    else
        ln -sf "$src" "$dst"
        echo "   ✓ $name → symlink creado"
    fi
}

# Fase 1: Agents
echo "📁 Fase 1: Agents..."
make_symlink "$REPO_CLAUDE/agents" "$STD_CLAUDE/agents" "agents"

# Fase 2: Commands
echo "📁 Fase 2: Commands..."
make_symlink "$REPO_CLAUDE/commands" "$STD_CLAUDE/commands" "commands"

# Fase 3: Skills
echo "📁 Fase 3: Skills..."
make_symlink "$REPO_CLAUDE/skills" "$STD_CLAUDE/skills" "skills"

# Fase 4: Hooks
echo "📁 Fase 4: Hooks..."
make_symlink "$REPO_CLAUDE/hooks" "$STD_CLAUDE/hooks" "hooks"

# Fase 5: Rules
echo "📁 Fase 5: Rules..."
make_symlink "$REPO_CLAUDE/rules" "$STD_CLAUDE/rules" "rules"

# Fase 6: Scripts criticos (opcional - solo symlinks a scripts usados por hooks)
echo "📁 Fase 6: Scripts criticos..."
mkdir -p "$STD_CLAUDE/scripts" 2>/dev/null || true
CRITICAL_SCRIPTS=(
    "context-usage-cache.sh"
    "force-statusline-refresh.sh"
    "parse-context-output.sh"
    "statusline-ralph.sh"
    "update-context-cache.sh"
    "checkpoint-manager.sh"
    "event-bus.sh"
    "agent-memory-buffer.sh"
)
count=0
for script in "${CRITICAL_SCRIPTS[@]}"; do
    if [ -f "$REPO_CLAUDE/scripts/$script" ]; then
        if [ "$DRY_RUN" = true ]; then
            echo "  [DRY] ln -sf $REPO_CLAUDE/scripts/$script $STD_CLAUDE/scripts/$script"
        else
            ln -sf "$REPO_CLAUDE/scripts/$script" "$STD_CLAUDE/scripts/$script"
        fi
        ((count++))
    fi
done
echo "   ✓ $count scripts criticos configurados"

# Verificar symlinks rotos
echo ""
echo "🔍 Verificando symlinks..."
if [ "$DRY_RUN" = false ]; then
    broken=$(find "$STD_CLAUDE"/{agents,commands,skills,hooks,rules,scripts} -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
    if [ "$broken" -gt 0 ]; then
        echo "   ⚠️  $broken symlinks rotos:"
        find "$STD_CLAUDE"/{agents,commands,skills,hooks,rules,scripts} -type l ! -exec test -e {} \; -print 2>/dev/null
    else
        echo "   ✓ Todos los symlinks son validos"
    fi
fi

# Resumen
echo ""
echo "=========================================="
echo "  Resumen"
echo "=========================================="
if [ "$DRY_RUN" = false ]; then
    echo "  Agents:   $(ls -1 "$STD_CLAUDE/agents" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo "  Commands: $(ls -1 "$STD_CLAUDE/commands" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo "  Skills:   $(ls -1 "$STD_CLAUDE/skills" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo "  Hooks:    $(ls -1 "$STD_CLAUDE/hooks" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo "  Rules:    $(ls -1 "$STD_CLAUDE/rules" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo "  Scripts:  $(ls -1 "$STD_CLAUDE/scripts" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    [ -d "$BACKUP_DIR" ] && echo ""
    [ -d "$BACKUP_DIR" ] && echo "  Backup: $BACKUP_DIR"
else
    echo "  (Modo DRY RUN - no se hicieron cambios)"
fi
echo ""

[ "$DRY_RUN" = false ] && echo "✅ Configuracion completada"
