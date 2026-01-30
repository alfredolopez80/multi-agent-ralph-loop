#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# verify-skills-consolidation.sh
# Script de verificación post-consolidación de skills externos (Fase 1)
# Multi-Agent Ralph Wiggum v2.83.0
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SKILLS_DIR="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills"
ERRORS=0
WARNINGS=0

# Skills a verificar (los 3 que se consolidaron en Fase 1)
SKILLS=("deslop" "stop-slop" "testing-anti-patterns")

echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  VERIFICACIÓN POST-CONSOLIDACIÓN - SKILLS EXTERNOS (Fase 1)"
echo "  Multi-Agent Ralph Wiggum v2.83.0"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo "Fecha: $(date)"
echo "Directorio de skills: $SKILLS_DIR"
echo ""

# Función para verificar si es symlink
is_symlink() {
    local path="$1"
    if [[ -L "$path" ]]; then
        return 0
    else
        return 1
    fi
}

# Función para verificar SKILL.md
has_skill_md() {
    local skill_dir="$1"
    if [[ -f "$skill_dir/SKILL.md" ]]; then
        return 0
    else
        return 1
    fi
}

# Función para verificar permisos
check_permissions() {
    local file="$1"
    local expected_perm="$2"
    local actual_perm
    actual_perm=$(stat -f "%Lp" "$file" 2>/dev/null || stat -c "%a" "$file" 2>/dev/null)
    
    if [[ "$actual_perm" == "$expected_perm" ]]; then
        return 0
    else
        return 1
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. VERIFICANDO QUE LOS DIRECTORIOS YA NO SON SYMLINKS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for skill in "${SKILLS[@]}"; do
    skill_path="$SKILLS_DIR/$skill"
    
    if [[ ! -e "$skill_path" ]]; then
        echo -e "${RED}✗ ERROR${NC}: $skill - Directorio no existe"
        ((ERRORS++))
        continue
    fi
    
    if is_symlink "$skill_path"; then
        echo -e "${RED}✗ ERROR${NC}: $skill - Aún es un symlink (!)"
        ((ERRORS++))
    else
        echo -e "${GREEN}✓ OK${NC}: $skill - Es directorio regular (no symlink)"
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  2. VERIFICANDO EXISTENCIA DE SKILL.md"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for skill in "${SKILLS[@]}"; do
    skill_path="$SKILLS_DIR/$skill"
    
    if [[ ! -e "$skill_path" ]]; then
        continue
    fi
    
    if has_skill_md "$skill_path"; then
        skill_md_path="$skill_path/SKILL.md"
        echo -e "${GREEN}✓ OK${NC}: $skill/SKILL.md existe"
        
        # Verificar tamaño del archivo
        size=$(stat -f "%z" "$skill_md_path" 2>/dev/null || stat -c "%s" "$skill_md_path" 2>/dev/null)
        if [[ $size -lt 100 ]]; then
            echo -e "  ${YELLOW}⚠ ADVERTENCIA${NC}: SKILL.md parece muy pequeño ($size bytes)"
            ((WARNINGS++))
        fi
    else
        echo -e "${RED}✗ ERROR${NC}: $skill/SKILL.md NO existe"
        ((ERRORS++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  3. VERIFICANDO PERMISOS CORRECTOS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for skill in "${SKILLS[@]}"; do
    skill_path="$SKILLS_DIR/$skill"
    
    if [[ ! -e "$skill_path" ]]; then
        continue
    fi
    
    # Verificar SKILL.md
    if [[ -f "$skill_path/SKILL.md" ]]; then
        perm=$(stat -f "%Lp" "$skill_path/SKILL.md" 2>/dev/null || stat -c "%a" "$skill_path/SKILL.md" 2>/dev/null)
        if [[ "$perm" == "644" ]]; then
            echo -e "${GREEN}✓ OK${NC}: $skill/SKILL.md - Permisos 644 correctos"
        else
            echo -e "${YELLOW}⚠ ADVERTENCIA${NC}: $skill/SKILL.md - Permisos $perm (esperado: 644)"
            ((WARNINGS++))
        fi
    fi
    
    # Verificar directorio (permisos 755)
    dir_perm=$(stat -f "%Lp" "$skill_path" 2>/dev/null || stat -c "%a" "$skill_path" 2>/dev/null)
    if [[ "$dir_perm" == "755" ]]; then
        echo -e "  ${GREEN}✓${NC}: Directorio $skill - Permisos 755 correctos"
    else
        echo -e "  ${YELLOW}⚠${NC}: Directorio $skill - Permisos $dir_perm (esperado: 755)"
        ((WARNINGS++))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  4. VERIFICANDO .gitignore"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

GITIGNORE="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.gitignore"
if grep -q "\.claude/skills/\*\.bak" "$GITIGNORE" 2>/dev/null; then
    echo -e "${GREEN}✓ OK${NC}: .gitignore contiene entrada para backups (.claude/skills/*.bak)"
else
    echo -e "${RED}✗ ERROR${NC}: .gitignore NO contiene entrada para backups"
    ((ERRORS++))
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  RESUMEN DE VERIFICACIÓN"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
echo -e "Errores encontrados: ${ERRORS}"
echo -e "Advertencias: ${WARNINGS}"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓✓✓ VERIFICACIÓN EXITOSA ✓✓✓${NC}"
    echo ""
    echo "Todos los checks pasaron. La consolidación de skills está completa."
    echo ""
    echo "Skills verificados:"
    for skill in "${SKILLS[@]}"; do
        echo "  - $skill"
    done
    echo ""
    exit 0
else
    echo -e "${RED}✗✗✗ VERIFICACIÓN FALLIDA ✗✗✗${NC}"
    echo ""
    echo "Se encontraron errores que deben corregirse."
    echo "Revisa los mensajes de error arriba."
    echo ""
    exit 1
fi
