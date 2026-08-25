#!/usr/bin/env bash
# shellcheck disable=SC2317  # el allowlist al final es DATA tras exit 0, no codigo
# check-gnu-only-commands.sh — Bloquea invocaciones GNU-only que BSD / macOS
# stock no tiene, aunque el entorno del desarrollador las tape.
#
# Historia que justifica este guard (issue #54): siete commits en nueve
# semanas introdujeron GNU-isms que solo fueron visibles porque el runner
# macOS de CI era stock (bash 3.2, sin coreutils). #49 instalo bash+coreutils
# en ese runner para ponerlo verde — y con ello la pata dejo de DETECTAR la
# clase de bug para la que existia. Este guard es el detector estatico: caza
# los call sites aunque el PATH local (brew coreutils, bfs) haga que funcionen.
#
# Evidencia en vivo: .claude/lib/action-report-generator.sh usaba `find
# -printf` (GNU-only) y funcionaba localmente SOLO porque `find` en el PATH
# es bfs 4.1.1 — /usr/bin/find responde "unknown primary or operator".
#
# Catalogo (regla -> constructo no-portable):
#   stat-c        `stat -c` es GNU (en BSD, -c no existe).
#   stat-bsd      `stat -f` es BSD (en GNU, -f significa filesystem).
#                 Una variante desnuda falla en el otro lado; el patron
#                 portable es el probe de capacidad (`if stat -c ... 2>&1`)
#                 o el fallback en el orden correcto. El guard no distingue
#                 probe de bug: marca la linea y el humano decide.
#   find-printf   `-printf`/`-fprint` solo existen en find GNU/BFS.
#   date-d        `date -d` es GNU; BSD usa `date -j -f`.
#   timeout       timeout(1) es de coreutils; macOS stock no lo trae.
#                 (gtimeout, o proteger con `command -v timeout`, son salidas).
#   sed-gnu-class `\d` y `\w` dentro de un script sed son extension GNU; en
#                 BSD BRE son literales. Solo esas dos: `\+` y `\?` se quedan
#                 fuera porque en el replacement son portables y dan ruido.
#   declare-A     `declare/typeset -A` necesita bash 4; macOS /bin/bash es 3.2
#                 (ver el detalle en .claude/lib/context-windows.sh).
#   readlink-f    `readlink -f` es GNU; BSD readlink no lo garantiza.
#   realpath-m   `realpath -m` (resolve missing) es GNU; el realpath de stock
#                 macOS responde "illegal option -- m" (rc=1). Agnadido en
#                 #61 tras descubrirse muerto-en-macOS dentro de un guard de
#                 seguridad (repo-boundary-guard.sh, arreglado en v2.99.0).
#   sort-V        `sort -V` (version sort) es GNU.
#   cat-A         `cat -A` es GNU; BSD cat no lo trae (fue el commit 7d5e19e,
#                 en el paso de diagnostico del bug anterior, ironicamente).
#
# Modos (identicos a check-literal-tilde.sh):
#   (sin args)  escanea SOLO los ficheros staged  (pre-commit)
#   --all       escanea todos los ficheros trackeados (CI/manual)
#
# Escape hatch: una linea que contenga 'gnu-ok' se ignora (anota la razon).
#
# Allowlist + ratchet: los pares "path|regla" del bloque marcado abajo son la
# deuda tecnica EXISTENTE en el nacimiento del guard. Falla si (a) aparece una
# violacion no listada, o (b) una entrada listada ya no viola nada (hay que
# borrarla). El allowlist solo puede encogerse: ante una violacion NUEVA la
# respuesta es arreglarla, no anadir una entrada. El ratchet completo (a+b) se
# aplica en --all desde ESTE repo; desde un repo ajeno el allowlist no aplica
# y toda violacion falla (util para los tests).

set -euo pipefail
umask 077

MODE="staged"
if [[ "${1:-}" == "--all" ]]; then MODE="all"; fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
# El allowlist solo rige cuando el guard corre desde su propio repo; los tests
# lo invocan desde repos temporales y ahi toda violacion debe fallar.
OWNING_REPO="false"
[[ "$SCRIPT_DIR" == "$ROOT/scripts" ]] && OWNING_REPO="true"

# Exclusiones: identicas a check-literal-tilde.sh.
is_excluded() {
  case "$1" in
    docs/*|*.md)                          return 0 ;;
    tests/*/fixtures/*|tests/fixtures/*)  return 0 ;;
    */results/*|.claude/quality-results/*) return 0 ;;
    .claude/archive/*|.claude/worktrees/*|node_modules/*) return 0 ;;
    .claude/settings.local.json)          return 0 ;;
    .ralph/backups/*)                     return 0 ;;
  esac
  return 1
}

FILES=()
if [[ "$MODE" == "all" ]]; then
  while IFS= read -r -d '' f; do
    is_excluded "$f" && continue
    case "$f" in
      *.sh|*.bash|*.bats|*.zsh) FILES+=("$f") ;;
    esac
  done < <(git ls-files -z)
else
  while IFS= read -r -d '' f; do
    is_excluded "$f" && continue
    case "$f" in
      *.sh|*.bash|*.bats|*.zsh) FILES+=("$f") ;;
    esac
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
fi

# Tabla de reglas: nombre<TAB>patron ERE. Heredoc quotado: sin expansion.
# El separador es TAB porque los patrones contienen '|'.
# La palabra de comando lleva prefijo (^|[^[:alnum:]_-]) para no casar dentro
# de palabras mas largas (p.ej. "gtimeout").
_rules_table() {
  cat <<'RULES'
stat-c	(^|[^[:alnum:]_-])stat[[:space:]]+([^;|]*[[:space:]])?-c([^[:alnum:]]|$)
stat-bsd	(^|[^[:alnum:]_-])stat[[:space:]]+([^;|]*[[:space:]])?-f([^[:alnum:]]|$)
find-printf	(^|[^[:alnum:]_-])find[[:space:]][^;|]*-printf
date-d	(^|[^[:alnum:]_-])date[[:space:]]+([^;|]*[[:space:]])?-d([[:space:]]|$)
timeout	(^|[^[:alnum:]_-])timeout[[:space:]]+([0-9]+|\$)
sed-gnu-class	(^|[^[:alnum:]_-])sed[[:space:]][^;|]*['\"][^'\"]*\\[dw]
declare-A	(^|[^[:alnum:]_-])(declare|typeset)[[:space:]]+-[A-Za-z]*A([^[:alpha:]]|$)
readlink-f	(^|[^[:alnum:]_-])readlink[[:space:]]+([^;|]*[[:space:]])?-f([^[:alnum:]]|$)
realpath-m	(^|[^[:alnum:]_-])realpath[[:space:]]+([^;|]*[[:space:]])?-m([^[:alnum:]]|$)
sort-V	(^|[^[:alnum:]_-])sort[[:space:]]+([^;|]*[[:space:]])?-V([[:space:]]|$)
cat-A	(^|[^[:alnum:]_-])cat[[:space:]]+([^;|]*[[:space:]])?-A([^[:alnum:]]|$)
RULES
}

RULE_NAMES=()
RULE_PATTERNS=()
while IFS=$'\t' read -r name pattern; do
  [[ -z "$name" || "$name" == \#* ]] && continue
  RULE_NAMES+=("$name")
  RULE_PATTERNS+=("$pattern")
done < <(_rules_table)

SCANNED=0
# Pares "path|regla" con violacion (dedupados via sort al final).
VIOL_PAIRS_FILE="$(mktemp)"
REPORTS_FILE="$(mktemp)"
trap 'rm -f "$VIOL_PAIRS_FILE" "$REPORTS_FILE"' EXIT

scan_file() {
  local f="$1" i pattern matches m body
  SCANNED=$((SCANNED + 1))
  for i in "${!RULE_NAMES[@]}"; do
    pattern="${RULE_PATTERNS[$i]}"
    matches=$(grep -nE "$pattern" -- "$f" 2>/dev/null || true)
    while IFS= read -r m; do
      [[ -z "$m" ]] && continue
      body="${m#*:}"
      # Comentario entero: el patron aparece en prosa/documentacion interna.
      [[ "$body" =~ ^[[:space:]]*# ]] && continue
      # Escape hatch anotado.
      [[ "$m" == *gnu-ok* ]] && continue
      # timeout: probe de disponibilidad o variante GNU explicita no cuentan.
      if [[ "${RULE_NAMES[$i]}" == "timeout" ]]; then
        [[ "$body" == *"command -v timeout"* || "$body" == *gtimeout* ]] && continue
      fi
      echo "  [GNU:${RULE_NAMES[$i]}] $f:$m" >> "$REPORTS_FILE"
      printf '%s|%s\n' "$f" "${RULE_NAMES[$i]}" >> "$VIOL_PAIRS_FILE"
    done <<< "$matches"
  done
}

for f in "${FILES[@]:-}"; do
  [[ -z "$f" || ! -f "$f" ]] && continue
  scan_file "$f"
done

sort -u "$VIOL_PAIRS_FILE" -o "$VIOL_PAIRS_FILE" 2>/dev/null || true

# Allowlist versionado: embebido en este fichero entre marcadores. Entradas
# "path|regla", una por linea, comentarios con '#'. SOLO PUEDE ENCOGERSE.
# Los marcadores se construyen por concatenacion: si el patron del sed
# contuviera el literal, el propio patron seria la PRIMERA ocurrencia del
# rango y la extraccion se tragaria el cuerpo del guard (falla real en el
# arranque de este script: la linea '|| true' entro como entrada del
# allowlist y el ratchet la marco como obsoleta).
load_allowlist() {
  local m_start="__GNU_ONLY_" m_end="__GNU_ONLY_"
  m_start="${m_start}ALLOWLIST_START__"
  m_end="${m_end}ALLOWLIST_END__"
  sed -n "/${m_start}/,/${m_end}/p" "$SCRIPT_PATH" \
    | grep -E '^[[:space:]]*[^#[:space:]][^[:space:]]*\|' \
    | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
    || true
}

ALLOWLIST_FILE="$(mktemp)"
load_allowlist > "$ALLOWLIST_FILE"

fail() {
  echo "" >&2
  echo "check-gnu-only-commands: $1" >&2
  exit 1
}

# En --all, escanear 0 ficheros es un FALLO: el guard no comprobo nada.
if [[ "$MODE" == "all" && "$SCANNED" -eq 0 ]]; then
  fail "escaneo 0 ficheros — no llego a comprobar nada (¿cambio el arbol de paths?)"
fi

# (a) Violaciones no cubiertas por el allowlist.
UNCOVERED_FILE="$(mktemp)"
ALLOW_APPLIES="$OWNING_REPO"
if [[ "$ALLOW_APPLIES" != "true" ]]; then
  cp "$VIOL_PAIRS_FILE" "$UNCOVERED_FILE"
else
  # pares con violacion que no estan en el allowlist
  sort -u "$ALLOWLIST_FILE" -o "$ALLOWLIST_FILE" 2>/dev/null || true
  comm -23 "$VIOL_PAIRS_FILE" "$ALLOWLIST_FILE" > "$UNCOVERED_FILE" 2>/dev/null || true
fi

if [[ -s "$UNCOVERED_FILE" ]]; then
  echo "" >&2
  echo "check-gnu-only-commands: violaciones GNU-only no permitidas:" >&2
  # Reporta las lineas concretas de los pares afectados.
  while IFS='|' read -r vf vr; do
    [[ -z "$vf" ]] && continue
    grep -E "\[GNU:$vr\] $vf:" "$REPORTS_FILE" | sort -u >&2 || \
      echo "  [GNU:$vr] $vf" >&2
  done < "$UNCOVERED_FILE"
  if [[ "$ALLOW_APPLIES" == "true" ]]; then
    echo "" >&2
    echo "El allowlist solo puede encogerse: arregla la violacion" >&2
    echo "(portable: probe de capacidad, fallback, o g*-prefijo)." >&2
  fi
  fail "violaciones sin cobertura"
fi

# (b) Ratchet: entradas del allowlist que ya no violan nada -> borrarlas.
# Solo en --all desde el repo propietario (en staged o repo ajeno no hay
# informacion suficiente para juzgarlo).
if [[ "$MODE" == "all" && "$OWNING_REPO" == "true" ]]; then
  STALE_FILE="$(mktemp)"
  comm -13 "$VIOL_PAIRS_FILE" "$ALLOWLIST_FILE" > "$STALE_FILE" 2>/dev/null || true
  if [[ -s "$STALE_FILE" ]]; then
    echo "" >&2
    echo "check-gnu-only-commands: entradas de allowlist obsoletas (ratchet:" >&2
    echo "solo puede encogerse) — borralas del bloque marcado en este script:" >&2
    cat "$STALE_FILE" >&2
    rm -f "$STALE_FILE"
    fail "allowlist con entradas que ya no violan nada"
  fi
  rm -f "$STALE_FILE"
fi

rm -f "$UNCOVERED_FILE"

VIOLATIONS=$(wc -l < "$VIOL_PAIRS_FILE" | tr -d ' ')
if [[ "$MODE" == "staged" && "$SCANNED" -eq 0 ]]; then
  echo "check-gnu-only-commands: sin ficheros en alcance entre los staged (N/A)"
else
  echo "check-gnu-only-commands: OK ($SCANNED ficheros, $VIOLATIONS pares en allowlist, 0 nuevos)"
fi
exit 0

# ══════════════════════════════════════════════════════════════════════════
# ALLOWLIST — deuda tecnica existente al nacer el guard (issue #54).
# Formato: path|regla. Una entrada por linea. SOLO PUEDE ENCOGERSE: el guard
# falla si una entrada deja de corresponder a una violacion real. Anadir una
# entrada nueva para tapar una violacion nueva es usar el escape hatch por la
# puerta trasera: NO lo hagas — anota la linea con '# gnu-ok: <razon>' si hay
# una justificacion puntual, o arregla el call site.
# ══════════════════════════════════════════════════════════════════════════
__GNU_ONLY_ALLOWLIST_START__
.claude/backup/hooks/glm-context-tracker.sh|stat-bsd
.claude/backup/hooks/glm-context-tracker.sh|stat-c
.claude/backup/hooks/unified-context-tracker.sh|timeout
.claude/hooks/ai-code-audit.sh|stat-bsd
.claude/hooks/ai-code-audit.sh|stat-c
.claude/hooks/anti-rationalization-gate.sh|date-d
.claude/hooks/anti-rationalization-gate.sh|stat-bsd
.claude/hooks/anti-rationalization-gate.sh|stat-c
.claude/hooks/context-warning.sh|stat-bsd
.claude/hooks/context-warning.sh|stat-c
.claude/hooks/lib/ctx-query.sh|stat-bsd
.claude/hooks/lib/ctx-query.sh|stat-c
.claude/hooks/lib/worktree-utils.sh|stat-bsd
.claude/hooks/lib/worktree-utils.sh|stat-c
.claude/hooks/orchestrator-auto-learn.sh|timeout
.claude/hooks/parallel-explore.sh|timeout
.claude/hooks/plan-state-adaptive.sh|stat-bsd
.claude/hooks/plan-state-adaptive.sh|stat-c
.claude/hooks/plan-state-lifecycle.sh|stat-bsd
.claude/hooks/project-backup-metadata.sh|date-d
.claude/hooks/quality-parallel-async.sh|stat-bsd
.claude/hooks/quality-parallel-async.sh|stat-c
.claude/hooks/session-end-handoff.sh|date-d
.claude/hooks/session-end-handoff.sh|find-printf
.claude/hooks/smart-memory-search.sh|stat-bsd
.claude/hooks/smart-memory-search.sh|stat-c
.claude/hooks/smart-memory-search.sh|timeout
.claude/hooks/smart-skill-reminder.sh|stat-bsd
.claude/hooks/smart-skill-reminder.sh|stat-c
.claude/hooks/wake-up-layer-stack.sh|date-d
.claude/lib/detect-environment.sh|stat-bsd
.claude/lib/detect-environment.sh|stat-c
.claude/run-tests-simple.sh|timeout
.claude/scripts/agent-memory-buffer.sh|date-d
.claude/scripts/curator-ingest.sh|stat-bsd
.claude/scripts/curator-ingest.sh|stat-c
scripts/gc-stale-worktrees.sh|stat-bsd
scripts/gc-stale-worktrees.sh|stat-c
scripts/validate-agents-registration.sh|declare-A
scripts/validate-directories.sh|declare-A
scripts/validate-directories.sh|stat-bsd
scripts/validate-directories.sh|stat-c
scripts/validate-global-architecture.sh|stat-bsd
scripts/validate-global-architecture.sh|stat-c
scripts/validate-hooks-execution.sh|declare-A
scripts/validate-hooks-registration.sh|declare-A
scripts/validate-hooks-registration.sh|readlink-f
scripts/validate-hooks-syntax.sh|declare-A
scripts/validate-installation.sh|declare-A
scripts/validate-settings-structure.sh|declare-A
scripts/validate-shell-config.sh|declare-A
scripts/validate-skills-registration.sh|declare-A
scripts/validate-system-requirements.sh|declare-A
tests/benchmark/baseline_memory_retrieval.sh|timeout
tests/functional/test-functional-learning-v1.sh|timeout
tests/hooks/test_plan_state_writer.sh|date-d
tests/hooks/test_react_doctor_runner_failures.sh|timeout
tests/installer/test-bash-version-guard.bats|declare-A
tests/orchestrator-validation/test-suite.sh|timeout
tests/promptify-integration/test-security-functions.sh|timeout
tests/security/test-bug-fixes-v2.90.bats|stat-bsd
tests/security/test-bug-fixes-v2.90.bats|stat-c
tests/test_cross_platform.bats|stat-bsd
tests/test_cross_platform.bats|stat-c
tests/unit/test-action-report-generator-v2.93.sh|date-d
tests/unit/test-skills-symlinks-v2.87.sh|readlink-f
__GNU_ONLY_ALLOWLIST_END__
