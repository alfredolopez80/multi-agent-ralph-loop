#!/usr/bin/env bash
# test_skills_centralization.sh - Contrato vigente de distribucion de skills
#
# La version anterior codificaba la politica v2.86: "centralizacion" significaba
# tener >100 skills COPIADOS en ~/.claude/skills, y fallaba si ese directorio era
# un symlink. Esa premisa quedo invertida: la politica actual poda duplicados y
# distribuye por plugin/symlink (docs/architecture/DISTRIBUTION_POLICY.md), asi
# que el test fallaba justamente cuando el sistema estaba SANO. Ademas contaba
# skills en instalaciones retiradas (.claude-code-old, .claude-sneakpeek-old).
#
# Este test valida lo que hoy importa:
#   1. ~/.claude/skills es accesible
#   2. los skills nucleo de ralph resuelven a un SKILL.md legible
#   3. no reaparecen copias byte-identicas a las que ya sirve un plugin
#   4. los agentes ralph-* estan disponibles globalmente

set -uo pipefail

readonly GREEN='\033[0;32m'
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_RUN=0

pass() { echo -e "  ${GREEN}✓${NC} $1"; TESTS_PASSED=$((TESTS_PASSED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
fail() { echo -e "  ${RED}✗${NC} $1"; TESTS_FAILED=$((TESTS_FAILED+1)); TESTS_RUN=$((TESTS_RUN+1)); }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
section() { echo ""; echo "=== $1 ==="; }

SKILLS_DIR="${HOME}/.claude/skills"
AGENTS_DIR="${HOME}/.claude/agents"
MARKETING_PLUGIN="${HOME}/.claude/plugins/marketplaces/marketingskills/skills"

# --- 1. Directorio de skills accesible -------------------------------------
section "Skills directory"

if [[ -d "$SKILLS_DIR" ]]; then
    n=$(find "$SKILLS_DIR" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    pass "~/.claude/skills accesible con $n skills cargables"
else
    fail "~/.claude/skills no existe o no es accesible"
fi

# --- 2. Skills nucleo de ralph resuelven -----------------------------------
# Symlink o directorio real dan igual: lo que importa es que SKILL.md se lea.
section "Core ralph skills"

for skill in orchestrator iterate gates adversarial security plan parallel autoresearch; do
    if [[ -r "$SKILLS_DIR/$skill/SKILL.md" ]]; then
        pass "skill '$skill' resuelve a un SKILL.md legible"
    else
        fail "skill '$skill' no resuelve (falta $SKILLS_DIR/$skill/SKILL.md)"
    fi
done

# --- 3. Anti-regresion de la poda ------------------------------------------
# Una copia byte-identica a la que ya sirve un plugin habilitado se paga dos
# veces en el contexto de cada sesion y no aporta nada.
section "No duplicate copies of plugin skills"

if [[ -d "$MARKETING_PLUGIN" ]]; then
    dupes=0
    while IFS= read -r plugin_skill; do
        name="$(basename "$(dirname "$plugin_skill")")"
        local_skill="$SKILLS_DIR/$name/SKILL.md"
        if [[ -f "$local_skill" ]] && cmp -s "$plugin_skill" "$local_skill"; then
            warn "copia byte-identica al plugin: $name"
            dupes=$((dupes+1))
        fi
    done < <(find "$MARKETING_PLUGIN" -mindepth 2 -maxdepth 2 -name SKILL.md 2>/dev/null)

    if [[ $dupes -eq 0 ]]; then
        pass "sin copias byte-identicas a skills del plugin marketingskills"
    else
        fail "$dupes skills duplicados del plugin (el plugin ya los sirve)"
    fi
else
    warn "plugin marketingskills no instalado; comprobacion omitida"
fi

# --- 4. Agentes ralph globales ---------------------------------------------
section "Global ralph agents"

for agent in ralph-coder ralph-reviewer ralph-tester ralph-researcher; do
    if [[ -r "$AGENTS_DIR/$agent.md" ]]; then
        pass "agente '$agent' disponible globalmente"
    else
        fail "agente '$agent' no encontrado en $AGENTS_DIR"
    fi
done

# --- Resumen ---------------------------------------------------------------
echo ""
echo "=========================================="
echo "  Total:  $TESTS_RUN"
echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
echo "=========================================="

# Un run con cero comprobaciones nunca es exito.
if [[ $TESTS_RUN -eq 0 ]]; then
    echo -e "${RED}✗ FAIL: no se ejecuto ninguna comprobacion${NC}"
    exit 1
fi

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ Distribucion de skills conforme al contrato vigente${NC}"
    exit 0
fi

exit 1
