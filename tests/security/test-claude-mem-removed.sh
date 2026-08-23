#!/usr/bin/env bash
# W0.5 — global-uninstall-validation
# Verifies claude-mem is FULLY removed from all known surfaces.
# Reference: .ralph/plans/cheeky-dazzling-catmull.md (Wave 0.5)
#
# Exit codes:
#   0 — all checks passed
#   1 — any check failed (claude-mem residue detected)
#
# Run: bash tests/security/test-claude-mem-removed.sh
#      bash tests/security/test-claude-mem-removed.sh --repo-only   (para CI)
#
# Modos:
#   (sin args)   todas las comprobaciones, incluidas las de la maquina del
#                desarrollador (procesos vivos, ~/.claude-mem, backup en
#                ~/.security-archive, datos migrados al vault de Obsidian).
#   --repo-only  solo lo que depende del CONTENIDO DEL REPO. Un runner limpio de
#                CI no tiene ni el backup ni el vault: incluir esas
#                comprobaciones alli seria rojo permanente por una razon que el
#                repo no puede arreglar.

set -uo pipefail

REPO_ONLY=false
[[ "${1:-}" == "--repo-only" ]] && REPO_ONLY=true

PASS=0
FAIL=0
RESULTS=()

check() {
    local name="$1"
    local cmd="$2"
    if eval "$cmd" >/dev/null 2>&1; then
        RESULTS+=("FAIL  $name")
        FAIL=$((FAIL + 1))
    else
        RESULTS+=("PASS  $name")
        PASS=$((PASS + 1))
    fi
}

# Inverse check: passes when the condition is TRUE (file/dir absent, etc.)
check_absent() {
    local name="$1"
    local path="$2"
    if [[ ! -e "$path" ]]; then
        RESULTS+=("PASS  $name")
        PASS=$((PASS + 1))
    else
        RESULTS+=("FAIL  $name (still exists: $path)")
        FAIL=$((FAIL + 1))
    fi
}

count_eq_zero() {
    local name="$1"
    local cmd="$2"
    local count
    count=$(eval "$cmd" 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$count" == "0" ]]; then
        RESULTS+=("PASS  $name (count=0)")
        PASS=$((PASS + 1))
    else
        RESULTS+=("FAIL  $name (count=$count)")
        FAIL=$((FAIL + 1))
    fi
}

# pgrep -f matchea la linea de comandos COMPLETA, incluida la del propio pipeline
# del test: invocar `bash test-claude-mem-removed.sh | grep claude-mem-context`
# hacia que el test se detectara a si mismo como demonio superviviente. El falso
# positivo dependia de COMO se invocara la suite, no de si claude-mem seguia vivo.
#
# El truco `[c]laude-mem` no sirve: el proceso infractor lleva el literal
# 'claude-mem-context', que casa igual. Se discrimina por parentesco — el
# pipeline del test comparte process group con el test; un demonio no.
pgrep_foreign() {
    local pattern="$1" mypgid p pg
    mypgid=$(ps -o pgid= -p $$ 2>/dev/null | tr -d ' ')
    while read -r p; do
        [[ -z "$p" ]] && continue
        pg=$(ps -o pgid= -p "$p" 2>/dev/null | tr -d ' ')
        [[ -n "$mypgid" && "$pg" == "$mypgid" ]] && continue
        echo "$p"
    done < <(pgrep -f "$pattern" 2>/dev/null)
}

echo "=== W0.5 Global Uninstall Validation ==="
if [[ "$REPO_ONLY" == true ]]; then
    echo "    (modo --repo-only: se omiten las comprobaciones de la maquina local)"
fi
echo ""

if [[ "$REPO_ONLY" == false ]]; then
    # 1. No running processes
    count_eq_zero "no claude-mem processes"   "pgrep_foreign 'claude-mem'"
    count_eq_zero "no mcp-server.cjs processes" "pgrep_foreign 'mcp-server\\.cjs'"
    count_eq_zero "no worker-service.cjs processes" "pgrep_foreign 'worker-service\\.cjs'"

    # 2. No port 37777 listening
    count_eq_zero "port 37777 not listening" "lsof -i :37777 2>/dev/null | grep LISTEN"

    # 3. No primary data directories
    check_absent "~/.claude-mem data dir absent"           "$HOME/.claude-mem"
    check_absent "plugin cache (thedotmack) absent"        "$HOME/.claude/plugins/cache/thedotmack/claude-mem"

    # 4. No secondary cache locations
    check_absent "~/.cache/claude-mem absent"              "$HOME/.cache/claude-mem"
    check_absent "~/.local/share/claude-mem absent"        "$HOME/.local/share/claude-mem"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        check_absent "macOS Caches/claude-mem absent"      "$HOME/Library/Caches/claude-mem"
        check_absent "macOS App Support/claude-mem absent" "$HOME/Library/Application Support/claude-mem"
    fi
fi

# 5. No entries in active settings.json files
for cfg in "$HOME/.claude/settings.json"; do
    if [[ -f "$cfg" ]]; then
        count_eq_zero "no claude-mem in $(basename "$(dirname "$cfg")")/settings.json" "grep claude-mem '$cfg'"
    fi
done

# 6. No ACTIVE code references in hooks (excluding documentation comments and retrocompat string tags).
# Allowed (after Wave 0):
#   - Paths to ~/Documents/Obsidian/MiVault/migrated-from-claude-mem/  (post-migration data)
#   - .bak / .ARCHIVED files (historical)
#   - Comments explaining the removal: "claude-mem removed", "claude-mem was removed",
#     "pending migration to claude-mem" (stale TODO), "TODO(W4..."
#   - Retrocompat string tag in episodic-auto-convert.sh "supported_sources"
count_eq_zero "no active claude-mem code refs in hooks" \
    "find .claude/hooks -type f ! -name '*.bak' ! -name '*.ARCHIVED' -exec grep -Hn 'claude-mem' {} \\; 2>/dev/null \
        | grep -v 'migrated-from-claude-mem' \
        | grep -v 'pre-claude-mem-removal' \
        | grep -v '# .* claude-mem' \
        | grep -v 'claude-mem removed' \
        | grep -v 'claude-mem was removed' \
        | grep -v '\"claude-mem\",'"

# 7. No mcp__plugin_claude-mem_* in skills/agents
count_eq_zero "no mcp__plugin_claude-mem_ in skills" "grep -rn 'mcp__plugin_claude-mem_' .claude/skills/ 2>/dev/null"
count_eq_zero "no mcp__plugin_claude-mem_ in agents" "grep -rn 'mcp__plugin_claude-mem_' .claude/agents/ 2>/dev/null"

# 8. No <claude-mem-context> XML blocks in files Claude Code loads as instructions.
#
# El alcance importa: un bloque dentro de un CLAUDE.md/AGENTS.md se INYECTA en el
# contexto de cada sesion que trabaje en ese directorio o por debajo. Una mencion
# en prosa dentro de docs/ es historia, no coste, y no se marca.
#
# Este check decia "in repo" pero solo miraba .claude/. Los 26 stubs vivian en
# docs/, scripts/, tests/, config/, src/ y frontend/ — fuera de su alcance. Se
# escanea el arbol de trabajo (no el indice) porque .gitignore trae '**/CLAUDE.md':
# los ficheros no estaban trackeados y aun asi Claude Code los cargaba desde disco.
#
# Se excluye .claude/worktrees/: son checkouts de OTROS commits, no se pueden
# arreglar desde aqui y no se cargan trabajando en el arbol principal.
instruction_files() {
    find . \( -name 'CLAUDE.md' -o -name 'AGENTS.md' \) \
        -not -path './.git/*' \
        -not -path './node_modules/*' \
        -not -path './.claude/worktrees/*' \
        -type f 2>/dev/null
}

CM_SCANNED=$(instruction_files | wc -l | tr -d ' ')
if [[ "$CM_SCANNED" -eq 0 ]]; then
    # Cero ficheros escaneados no es "limpio", es que el check no comprobo nada.
    RESULTS+=("FAIL  <claude-mem-context> scan cubrio 0 ficheros de instrucciones")
    FAIL=$((FAIL + 1))
else
    count_eq_zero "no <claude-mem-context> in CLAUDE.md/AGENTS.md (${CM_SCANNED} scanned)" \
        "instruction_files | xargs grep -l 'claude-mem-context' 2>/dev/null"
fi

if [[ "$REPO_ONLY" == false ]]; then
    # 9. Security archive backup exists (W0.1 evidence)
    if [[ -d "$HOME/.security-archive" ]] && ls "$HOME/.security-archive"/claude-mem-data-*.tar.gz >/dev/null 2>&1; then
        RESULTS+=("PASS  W0.1 backup exists in ~/.security-archive/")
        PASS=$((PASS + 1))
    else
        RESULTS+=("FAIL  W0.1 backup MISSING from ~/.security-archive/")
        FAIL=$((FAIL + 1))
    fi

    # 10. Obsidian migration data exists (W0.2 evidence)
    if [[ -d "$HOME/Documents/Obsidian/MiVault/migrated-from-claude-mem" ]]; then
        RESULTS+=("PASS  W0.2 migration data in Obsidian vault")
        PASS=$((PASS + 1))
    else
        RESULTS+=("FAIL  W0.2 migration data MISSING from Obsidian vault")
        FAIL=$((FAIL + 1))
    fi
fi

# Print results
echo ""
for r in "${RESULTS[@]}"; do
    echo "  $r"
done
echo ""
echo "=== Summary: $PASS passed / $FAIL failed ==="

# Cero comprobaciones ejecutadas no es exito: seria que el script no llego a
# comprobar nada (un flag mal escrito, un early-exit). Ver la regla
# testing-zero-tests-is-never-success.
if [[ $((PASS + FAIL)) -eq 0 ]]; then
    echo "FAIL: 0 comprobaciones ejecutadas — la validacion no llego a correr" >&2
    exit 1
fi

if [[ "$FAIL" -gt 0 ]]; then
    echo "❌ Wave 0 NOT complete. Fix failures above before proceeding."
    exit 1
fi
echo "✅ Wave 0 validation PASSED."
exit 0
