#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# verify-skills-consolidation.sh
# Script de verificación post-consolidación de skills externos (Fase 1)
# Multi-Agent Ralph Wiggum v2.83.0
# ═══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# Shared colors, counters and the zero-checks verdict guard.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/validation-common.sh"

SKILLS_DIR="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/skills"
vc_init

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
        vc_fail
        continue
    fi
    
    if is_symlink "$skill_path"; then
        echo -e "${RED}✗ ERROR${NC}: $skill - Aún es un symlink (!)"
        vc_fail
    else
        echo -e "${GREEN}✓ OK${NC}: $skill - Es directorio regular (no symlink)"
        vc_pass
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
        vc_pass
        
        # Verificar tamaño del archivo
        size=$(stat -f "%z" "$skill_md_path" 2>/dev/null || stat -c "%s" "$skill_md_path" 2>/dev/null)
        if [[ $size -lt 100 ]]; then
            echo -e "  ${YELLOW}⚠ ADVERTENCIA${NC}: SKILL.md parece muy pequeño ($size bytes)"
            vc_warn
        fi
    else
        echo -e "${RED}✗ ERROR${NC}: $skill/SKILL.md NO existe"
        vc_fail
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
            vc_pass
        else
            echo -e "${YELLOW}⚠ ADVERTENCIA${NC}: $skill/SKILL.md - Permisos $perm (esperado: 644)"
            vc_warn
        fi
    fi
    
    # Verificar directorio (permisos 755)
    dir_perm=$(stat -f "%Lp" "$skill_path" 2>/dev/null || stat -c "%a" "$skill_path" 2>/dev/null)
    if [[ "$dir_perm" == "755" ]]; then
        echo -e "  ${GREEN}✓${NC}: Directorio $skill - Permisos 755 correctos"
        vc_pass
    else
        echo -e "  ${YELLOW}⚠${NC}: Directorio $skill - Permisos $dir_perm (esperado: 755)"
        vc_warn
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
    vc_pass
else
    echo -e "${RED}✗ ERROR${NC}: .gitignore NO contiene entrada para backups"
    vc_fail
fi

echo ""
echo "═══════════════════════════════════════════════════════════════════════════════"
echo "  RESUMEN DE VERIFICACIÓN"
echo "═══════════════════════════════════════════════════════════════════════════════"
echo ""
# Shared summary + the zero-checks guard. Previously this declared success on
# `ERRORS -eq 0` alone and never counted the passing checks, so a fully-healthy run
# would report success without vc_verdict being able to tell it ran anything at all.
if vc_verdict "Skills Consolidation"; then
    echo "Skills verificados:"
    for skill in "${SKILLS[@]}"; do
        echo "  - $skill"
    done
    echo ""
    exit 0
fi
exit 1
