#!/bin/bash
# validate-migration.sh - Validar migración de Zai a Claude nativo
# Version: 1.0.0
# Fecha: 2026-02-13

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   VALIDACIÓN DE MIGRACIÓN ZAI → CLAUDE NATIVO               ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

ERRORS=0
WARNINGS=0

# 1. Verificar claude-mem plugin
echo -e "${BLUE}[1/5] Verificando claude-mem plugin...${NC}"
if [ -d ~/.claude/plugins/cache/thedotmack/claude-mem ]; then
    versions=$(ls ~/.claude/plugins/cache/thedotmack/claude-mem/ | tr '\n' ' ')
    echo -e "   ${GREEN}✓${NC} Plugin instalado: versiones $versions"
else
    echo -e "   ${RED}✗${NC} Plugin NO encontrado"
    ((ERRORS++))
fi

# Verificar registro en installed_plugins.json
if grep -q "claude-mem@thedotmack" ~/.claude/plugins/installed_plugins.json 2>/dev/null; then
    echo -e "   ${GREEN}✓${NC} Registrado en installed_plugins.json"
else
    echo -e "   ${RED}✗${NC} NO registrado en installed_plugins.json"
    ((ERRORS++))
fi

# Verificar permiso en settings.json
if grep -q '"claude-mem@thedotmack"' ~/.claude/settings.json 2>/dev/null; then
    echo -e "   ${GREEN}✓${NC} Permiso configurado en settings.json"
else
    echo -e "   ${YELLOW}⚠${NC} Permiso NO configurado en settings.json"
    ((WARNINGS++))
fi

echo ""

# 2. Verificar symlinks
echo -e "${BLUE}[2/5] Verificando symlinks...${NC}"

check_symlinks() {
    local dir=$1
    local name=$2
    if [ -d "$dir" ]; then
        broken=$(find "$dir" -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
        total=$(ls -1 "$dir" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$broken" -eq 0 ]; then
            echo -e "   ${GREEN}✓${NC} $name: $total symlinks válidos"
        else
            echo -e "   ${RED}✗${NC} $name: $broken rotos de $total"
            ((ERRORS++))
        fi
    else
        echo -e "   ${RED}✗${NC} $name: directorio no existe"
        ((ERRORS++))
    fi
}

check_symlinks ~/.claude/agents "Agents"
check_symlinks ~/.claude/commands "Commands"
check_symlinks ~/.claude/skills "Skills"
check_symlinks ~/.claude/scripts "Scripts"

# Hooks es un directorio symlink
if [ -L ~/.claude/hooks ]; then
    echo -e "   ${GREEN}✓${NC} Hooks: directorio symlink"
else
    echo -e "   ${YELLOW}⚠${NC} Hooks: NO es symlink"
    ((WARNINGS++))
fi

# Rules
if [ -L ~/.claude/rules/CLAUDE.md ]; then
    echo -e "   ${GREEN}✓${NC} Rules: symlink válido"
else
    echo -e "   ${YELLOW}⚠${NC} Rules: NO es symlink"
    ((WARNINGS++))
fi

echo ""

# 3. Verificar settings.json
echo -e "${BLUE}[3/5] Verificando settings.json...${NC}"

hooks_count=$(cat ~/.claude/settings.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('hooks',{})))" 2>/dev/null || echo "0")
echo -e "   ${GREEN}✓${NC} Hooks configurados: $hooks_count eventos"

perm_allow=$(cat ~/.claude/settings.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('permissions',{}).get('allow',[])))" 2>/dev/null || echo "0")
echo -e "   ${GREEN}✓${NC} Permisos allow: $perm_allow"

perm_deny=$(cat ~/.claude/settings.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('permissions',{}).get('deny',[])))" 2>/dev/null || echo "0")
echo -e "   ${GREEN}✓${NC} Permisos deny: $perm_deny"

echo ""

# 4. Verificar alineación con repo
echo -e "${BLUE}[4/5] Verificando alineación con repo...${NC}"

REPO="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude"

repo_agents=$(ls $REPO/agents/*.md 2>/dev/null | wc -l | tr -d ' ')
link_agents=$(ls ~/.claude/agents 2>/dev/null | wc -l | tr -d ' ')
if [ "$repo_agents" = "$link_agents" ]; then
    echo -e "   ${GREEN}✓${NC} Agents alineados: $repo_agents archivos"
else
    echo -e "   ${YELLOW}⚠${NC} Agents desalineados: repo=$repo_agents, links=$link_agents"
    ((WARNINGS++))
fi

repo_commands=$(ls $REPO/commands/*.md 2>/dev/null | wc -l | tr -d ' ')
link_commands=$(ls ~/.claude/commands 2>/dev/null | wc -l | tr -d ' ')
if [ "$repo_commands" = "$link_commands" ]; then
    echo -e "   ${GREEN}✓${NC} Commands alineados: $repo_commands archivos"
else
    echo -e "   ${YELLOW}⚠${NC} Commands desalineados: repo=$repo_commands, links=$link_commands"
    ((WARNINGS++))
fi

repo_skills=$(ls -d $REPO/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
link_skills=$(ls ~/.claude/skills 2>/dev/null | wc -l | tr -d ' ')
if [ "$repo_skills" = "$link_skills" ]; then
    echo -e "   ${GREEN}✓${NC} Skills alineados: $repo_skills directorios"
else
    echo -e "   ${YELLOW}⚠${NC} Skills desalineados: repo=$repo_skills, links=$link_skills"
    ((WARNINGS++))
fi

echo ""

# 5. Verificar MCP servers
echo -e "${BLUE}[5/5] Verificando MCP servers...${NC}"

mcp_count=$(cat ~/.claude/settings.json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('mcpServers',{})))" 2>/dev/null || echo "0")
echo -e "   ${GREEN}✓${NC} MCP Servers configurados: $mcp_count"

echo ""

# Resumen
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   RESUMEN                                                    ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✅ MIGRACIÓN COMPLETADA EXITOSAMENTE${NC}"
    echo ""
    echo "   Todos los componentes están correctamente configurados."
    echo "   Reinicia Claude Code para aplicar los cambios."
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠️  MIGRACIÓN COMPLETADA CON ADVERTENCIAS${NC}"
    echo ""
    echo "   $WARNINGS advertencia(s) encontrada(s)."
    echo "   La configuración es funcional pero revisa las advertencias."
else
    echo -e "${RED}❌ MIGRACIÓN CON ERRORES${NC}"
    echo ""
    echo "   $ERRORS error(es) y $WARNINGS advertencia(s) encontrada(s)."
    echo "   Revisa los errores antes de continuar."
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

exit $ERRORS
