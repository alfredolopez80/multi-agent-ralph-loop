#!/bin/bash
# setup-symlinks.sh - Configurar symlinks para Claude Code
# Repo: multi-agent-ralph-loop
# Fecha: 2026-02-13
# Version: 1.0.0
# Uso: ./setup-symlinks.sh [--dry-run]

set -e

# Configuración
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
REPO_CLAUDE="$REPO_ROOT/.claude"
STD_CLAUDE="$HOME/.claude"
BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d-%H%M%S)"
DRY_RUN=false

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parsear argumentos
[ "$1" = "--dry-run" ] && DRY_RUN=true

echo "=========================================="
echo "  Setup Symlinks - Claude Code"
echo "=========================================="
echo ""
echo -e "Repo:  ${BLUE}$REPO_ROOT${NC}"
echo -e "Target: ${BLUE}$STD_CLAUDE${NC}"
echo -e "Mode:  $([ "$DRY_RUN" = true ] && echo "${YELLOW}DRY RUN${NC}" || echo "${GREEN}EXECUTE${NC}")"
echo ""

# Función para crear symlink
make_symlink() {
    local src="$1"
    local dst="$2"
    local desc="$3"

    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY]${NC} ln -sf $src $dst"
        return 0
    fi

    # Crear directorio padre si no existe
    mkdir -p "$(dirname "$dst")"

    # Backup si existe archivo real (no symlink)
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/$(basename "$(dirname "$dst")")-$(basename "$dst")"
        mv "$dst" "$backup_path"
        echo -e "  ${YELLOW}[BACKUP]${NC} $dst → $backup_path"
    fi

    # Crear symlink
    ln -sf "$src" "$dst"
    echo -e "  ${GREEN}✓${NC} $desc"
}

# Fase 1: Agents
echo -e "${BLUE}📁 Fase 1: Agents...${NC}"
mkdir -p "$STD_CLAUDE/agents"
count=0
for agent in "$REPO_CLAUDE/agents"/*.md; do
    [ -f "$agent" ] || continue
    filename=$(basename "$agent")
    make_symlink "$agent" "$STD_CLAUDE/agents/$filename" "$filename"
    ((count++))
done
echo -e "   ${GREEN}✓ $count agents configurados${NC}"

# Fase 2: Commands
echo ""
echo -e "${BLUE}📁 Fase 2: Commands...${NC}"
mkdir -p "$STD_CLAUDE/commands"
count=0
for cmd in "$REPO_CLAUDE/commands"/*.md; do
    [ -f "$cmd" ] || continue
    filename=$(basename "$cmd")
    make_symlink "$cmd" "$STD_CLAUDE/commands/$filename" "$filename"
    ((count++))
done
echo -e "   ${GREEN}✓ $count commands configurados${NC}"

# Fase 3: Skills
echo ""
echo -e "${BLUE}📁 Fase 3: Skills...${NC}"
mkdir -p "$STD_CLAUDE/skills"
count=0
for skill in "$REPO_CLAUDE/skills"/*/; do
    [ -d "$skill" ] || continue
    skill_name=$(basename "$skill")
    make_symlink "$skill" "$STD_CLAUDE/skills/$skill_name" "$skill_name/"
    ((count++))
done
echo -e "   ${GREEN}✓ $count skills configurados${NC}"

# Fase 4: Hooks (directorio completo)
echo ""
echo -e "${BLUE}📁 Fase 4: Hooks...${NC}"
if [ -d "$STD_CLAUDE/hooks" ] && [ ! -L "$STD_CLAUDE/hooks" ]; then
    if [ "$DRY_RUN" = true ]; then
        echo -e "  ${YELLOW}[DRY]${NC} mv $STD_CLAUDE/hooks $BACKUP_DIR/hooks"
    else
        mkdir -p "$BACKUP_DIR"
        mv "$STD_CLAUDE/hooks" "$BACKUP_DIR/hooks"
        echo -e "  ${YELLOW}[BACKUP]${NC} hooks → $BACKUP_DIR/hooks/"
    fi
fi
make_symlink "$REPO_CLAUDE/hooks" "$STD_CLAUDE/hooks" "hooks/ (directorio completo)"
hook_count=$(ls -1 "$REPO_CLAUDE/hooks" 2>/dev/null | wc -l | tr -d ' ')
echo -e "   ${GREEN}✓ $hook_count hooks configurados${NC}"

# Fase 5: Rules
echo ""
echo -e "${BLUE}📁 Fase 5: Rules...${NC}"
mkdir -p "$STD_CLAUDE/rules"
if [ -f "$REPO_CLAUDE/rules/CLAUDE.md" ]; then
    make_symlink "$REPO_CLAUDE/rules/CLAUDE.md" "$STD_CLAUDE/rules/CLAUDE.md" "CLAUDE.md"
    echo -e "   ${GREEN}✓ rules configurados${NC}"
else
    echo -e "   ${YELLOW}⚠ No hay rules en el repo${NC}"
fi

# Fase 6: Scripts críticos
echo ""
echo -e "${BLUE}📁 Fase 6: Scripts críticos...${NC}"
mkdir -p "$STD_CLAUDE/scripts"
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
        make_symlink "$REPO_CLAUDE/scripts/$script" "$STD_CLAUDE/scripts/$script" "$script"
        ((count++))
    fi
done
echo -e "   ${GREEN}✓ $count scripts críticos configurados${NC}"

# Verificar symlinks rotos
echo ""
echo -e "${BLUE}🔍 Verificando symlinks...${NC}"
if [ "$DRY_RUN" = false ]; then
    broken=$(find "$STD_CLAUDE"/{agents,commands,skills,hooks,rules,scripts} -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
    if [ "$broken" -gt 0 ]; then
        echo -e "   ${RED}⚠️  $broken symlinks rotos:${NC}"
        find "$STD_CLAUDE"/{agents,commands,skills,hooks,rules,scripts} -type l ! -exec test -e {} \; -print 2>/dev/null
    else
        echo -e "   ${GREEN}✓ Todos los symlinks son válidos${NC}"
    fi
fi

# Resumen
echo ""
echo "=========================================="
echo "  Resumen"
echo "=========================================="
if [ "$DRY_RUN" = false ]; then
    echo -e "  ${BLUE}Agents:${NC}   $(ls -1 "$STD_CLAUDE/agents" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo -e "  ${BLUE}Commands:${NC} $(ls -1 "$STD_CLAUDE/commands" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo -e "  ${BLUE}Skills:${NC}   $(ls -1 "$STD_CLAUDE/skills" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    echo -e "  ${BLUE}Hooks:${NC}    $(ls -1 "$STD_CLAUDE/hooks" 2>/dev/null | wc -l | tr -d ' ') archivos"
    echo -e "  ${BLUE}Rules:${NC}    $([ -L "$STD_CLAUDE/rules/CLAUDE.md" ] && echo "1 symlink" || echo "0")"
    echo -e "  ${BLUE}Scripts:${NC}  $(ls -1 "$STD_CLAUDE/scripts" 2>/dev/null | wc -l | tr -d ' ') symlinks"
    [ -d "$BACKUP_DIR" ] && echo ""
    [ -d "$BACKUP_DIR" ] && echo -e "  ${YELLOW}Backup:${NC} $BACKUP_DIR"
else
    echo -e "  ${YELLOW}(Modo DRY RUN - no se hicieron cambios)${NC}"
fi
echo ""

[ "$DRY_RUN" = false ] && echo -e "${GREEN}✅ Configuración completada${NC}"
