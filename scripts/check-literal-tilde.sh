#!/usr/bin/env bash
# check-literal-tilde.sh — Bloquea tildes '~' que quedarian literales sin expandir.
#
# En bash, '~' SOLO se expande sin comillas y al principio de palabra:
#
#   VAR=~/x            -> expande
#   VAR="~/x"          -> LITERAL
#   "${V:-~/x}"        -> LITERAL (el default entre comillas tampoco expande)
#   ${V:-~/x}          -> expande
#
# En JSON/YAML no se expande NUNCA, y en Python hace falta expanduser().
#
# Historia que justifica este guard: un commit copio `REPO="~/Documents/..."` a
# cuatro scripts. Los cuatro consumidores eran fail-open, asi que durante 4,5
# meses la sincronizacion de reglas, su detector de deriva y un paso del cron
# semanal no hicieron nada y reportaron exito. Ademas, un `plansDirectory` con
# tilde literal creo seis directorios llamados '~' dentro del repo.
#
# Modos:
#   (sin args)  escanea SOLO los ficheros staged  (pre-commit, ~0.03s)
#   --all       escanea todos los ficheros trackeados (CI/manual, ~0.3s)
#
# Escape hatch: una linea que contenga 'tilde-ok' se ignora (anota la razon).

set -euo pipefail
umask 077

MODE="staged"
if [[ "${1:-}" == "--all" ]]; then MODE="all"; fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

# Exclusiones: documentacion (tildes legitimas en prosa), fixtures (tildes
# intencionales que el consumidor expande), artefactos y copias archivadas.
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
ALL_STAGED=()
if [[ "$MODE" == "all" ]]; then
  while IFS= read -r -d '' f; do
    is_excluded "$f" && continue
    case "$f" in
      *.sh|*.bash|*.bats|*.zsh|*.py|*.js|*.ts|*.json|*.yml|*.yaml) FILES+=("$f") ;;
    esac
  done < <(git ls-files -z)
else
  while IFS= read -r -d '' f; do
    ALL_STAGED+=("$f")
    is_excluded "$f" && continue
    case "$f" in
      *.sh|*.bash|*.bats|*.zsh|*.py|*.js|*.ts|*.json|*.yml|*.yaml) FILES+=("$f") ;;
    esac
  done < <(git diff --cached --name-only --diff-filter=ACMR -z)
fi

VIOLATIONS=0
SCANNED=0

report() {
  echo "  [TILDE] $1:$2  ($3)"
  VIOLATIONS=$((VIOLATIONS + 1))
}

emit() {  # $1=fichero  $2=lineas de grep  $3=regla  $4=prefijo de comentario
  local f="$1" matches="$2" rule="$3" cmt="$4" m body
  while IFS= read -r m; do
    [[ -z "$m" ]] && continue
    body="${m#*:}"
    [[ "$body" =~ ^[[:space:]]*(${cmt}) ]] && continue
    [[ "$m" == *tilde-ok* ]] && continue
    report "$f" "$m" "$rule"
  done <<< "$matches"
}

scan_file() {
  local f="$1" matches
  SCANNED=$((SCANNED + 1))
  case "$f" in
    *.sh|*.bash|*.bats|*.zsh)
      # Solo contextos donde la tilde ES una ruta: asignacion, comando de
      # filesystem, operador de test y default citado. Los mensajes de log con
      # "~/..." son legitimos y NO se marcan.
      matches=$(grep -nE '(^|[[:space:]])((export|local|readonly|declare)[[:space:]]+)?[A-Za-z_][A-Za-z0-9_]*=["'"'"']~/' -- "$f" || true)
      matches+=$'\n'$(grep -nE '(^|[[:space:]&|;(`])(mkdir|cp|mv|ln|rm|touch|cd|find|cat|source|stat|chmod|chown)([[:space:]]+-[^[:space:]]+)*[[:space:]]+["'"'"']~' -- "$f" || true)
      matches+=$'\n'$(grep -nE '\-[defxrwsLh][[:space:]]+["'"'"']~/' -- "$f" || true)
      matches+=$'\n'$(grep -nE '\$\{[A-Za-z_][A-Za-z0-9_]*:?-~/' -- "$f" || true)
      emit "$f" "$matches" "shell: tilde citada no expande — usa \$HOME" '#'
      ;;
    *.py)
      matches=$(grep -nE '(Path|open|os\.path\.[a-z_]+|os\.makedirs|os\.listdir|shutil\.[a-z_]+)\(["'"'"']~|=[[:space:]]*["'"'"']~/' -- "$f" | grep -v 'expanduser' || true)
      emit "$f" "$matches" "python: falta expanduser() / Path.home()" '#'
      ;;
    *.js|*.ts)
      matches=$(grep -nE '["'"'"'`]~/' -- "$f" | grep -v 'homedir' || true)
      emit "$f" "$matches" "js/ts: usa os.homedir()" '//|\*'
      ;;
    *.json|*.yml|*.yaml)
      matches=$(grep -nE '"~/' -- "$f" || true)
      emit "$f" "$matches" "config declarativa: '~' nunca se expande aqui" '#'
      ;;
  esac
}

for f in "${FILES[@]:-}"; do
  [[ -z "$f" || ! -f "$f" ]] && continue
  scan_file "$f"
done

# Anti-fantasma: ningun path puede tener un componente literal '~'.
if [[ "$MODE" == "all" ]]; then
  while IFS= read -r p; do
    [[ -n "$p" ]] && report "$p" "-" "path trackeado con componente literal '~'"
  done < <(git ls-files | grep -E '(^|/)~(/|$)' || true)
  while IFS= read -r -d '' p; do
    report "${p#./}" "-" "directorio fantasma '~' en el arbol de trabajo"
  done < <(find . -name '~' -not -path './.git/*' -not -path './node_modules/*' -not -path './.claude/worktrees/*' -print0 2>/dev/null)
else
  for p in "${ALL_STAGED[@]:-}"; do
    [[ -z "$p" ]] && continue
    if [[ "/$p/" == *"/~/"* || "$p" == "~" ]]; then
      report "$p" "-" "intento de commitear un path con componente literal '~'"
    fi
  done
fi

# Veredicto. En --all, escanear 0 ficheros es un FALLO: el guard no comprobo nada.
if [[ "$MODE" == "all" && "$SCANNED" -eq 0 ]]; then
  echo "FAIL: check-literal-tilde escaneo 0 ficheros — no llego a comprobar nada" >&2
  exit 1
fi

if [[ "$VIOLATIONS" -gt 0 ]]; then
  echo ""
  echo "check-literal-tilde: $VIOLATIONS violacion(es) en $SCANNED fichero(s)."
  echo "La tilde entre comillas NO se expande. Usa \$HOME, una raiz derivada de"
  echo "BASH_SOURCE, Path.home()/expanduser() u os.homedir()."
  echo "Excepcion consciente: anota la linea con '# tilde-ok: <razon>'."
  exit 1
fi

if [[ "$MODE" == "staged" && "$SCANNED" -eq 0 ]]; then
  echo "check-literal-tilde: sin ficheros en alcance entre los staged (N/A)"
else
  echo "check-literal-tilde: OK ($SCANNED ficheros, 0 violaciones)"
fi
exit 0
