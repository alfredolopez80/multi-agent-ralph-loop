#!/usr/bin/env bash
# sync-rules-from-source.sh — Update standalone rule copies from repo source
# VERSION: 3.2.0
# Created: 2026-04-07 (W5.1 MemPalace)

umask 077

set -euo pipefail

# La tilde entre comillas NO se expande: `REPO="~/..."` dejaba la ruta literal,
# el directorio nunca existia y el script salia con exit 0 sin hacer nada.
# Este fichero se instala como symlink en ~/.claude/scripts/, asi que hay que
# resolver el symlink antes de derivar la raiz del repo desde su ubicacion real.
SELF="${BASH_SOURCE[0]}"
while [ -L "$SELF" ]; do
  LINK_TARGET="$(readlink "$SELF")"
  case "$LINK_TARGET" in
    /*) SELF="$LINK_TARGET" ;;
    *)  SELF="$(dirname "$SELF")/$LINK_TARGET" ;;
  esac
done
REPO="$(cd "$(dirname "$SELF")/../.." && pwd)"
RULES_DIR="$HOME/.claude/rules"
DRY_RUN=false
UPDATED=0
SKIPPED=0

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      echo "Usage: sync-rules-from-source.sh [--dry-run]"
      echo "  Updates standalone rule copies in ~/.claude/rules/ from repo source."
      echo "  Skips gracefully if repo directory does not exist."
      exit 0
      ;;
  esac
done

if [ ! -d "$REPO/.claude/rules-src" ]; then
  # Con REPO derivado del propio fichero, que falte esto es una anomalia real,
  # no un caso tolerable: salir 0 aqui oculto 4,5 meses sin sincronizar.
  # T40: source moved out of .claude/rules/ to .claude/rules-src/ so the repo
  # stops auto-loading the 7 rules twice (once from the repo path, once from
  # ~/.claude/rules/ — Claude Code deduplicates by REALPATH and both have
  # different realpaths, so both were paid).
  echo "FAIL: rules source not found at $REPO/.claude/rules-src — sync did NOT run" >&2
  exit 1
fi

RULE_FILES=(
  "aristotle-methodology.md"
  "ast-grep-usage.md"
  "browser-automation.md"
  "native-tools-first.md"
  "plan-immutability.md"
  "zai-mcp-usage.md"
)

echo "Syncing rules from repo to standalone copies..."
if [ "$DRY_RUN" = true ]; then
  echo "(DRY RUN — no changes will be made)"
fi
echo ""

for rule_file in "${RULE_FILES[@]}"; do
  SOURCE="$REPO/.claude/rules-src/$rule_file"
  TARGET="$RULES_DIR/$rule_file"

  if [ ! -f "$SOURCE" ] || [ -L "$SOURCE" ]; then
    echo "SKIP: $rule_file (source is missing or is a symlink)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Un target ausente NO es motivo para saltar: una regla recien anadida a
  # RULE_FILES nunca llegaba a instalarse, el sync reportaba "skipped" y
  # validate-global-infrastructure.sh la marcaba como missing para siempre.
  # Se crea la copia y se sigue al bloque normal, que le pone la cabecera.
  if [ ! -f "$TARGET" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "WOULD: $rule_file (nueva — se crearia la copia)"
      SKIPPED=$((SKIPPED + 1))
      continue
    fi
    mkdir -p "$RULES_DIR"
    : > "$TARGET"
    echo "NEW:   $rule_file (copia creada)"
  fi

  SOURCE_CONTENT=$(cat "$SOURCE" 2>/dev/null || true)
  TARGET_CONTENT=$(tail -n +6 "$TARGET" 2>/dev/null || true)

  if [ "$SOURCE_CONTENT" = "$TARGET_CONTENT" ]; then
    echo "OK:    $rule_file (up to date)"
  else
    if [ "$DRY_RUN" = true ]; then
      echo "WOULD: $rule_file (source has changes)"
    else
      TODAY=$(date +%Y-%m-%d)
      TEMP=$(mktemp)
      {
        echo "<!-- SOURCE: multi-agent-ralph-loop/.claude/rules-src/$rule_file"
        echo "     VERSION: 3.2.0"
        echo "     SYNCED: $TODAY"
        echo "     UPDATE: bash ~/.claude/scripts/sync-rules-from-source.sh -->"
        echo ""
        cat "$SOURCE"
      } > "$TEMP"
      mv "$TEMP" "$TARGET"
      echo "SYNCED: $rule_file"
    fi
    UPDATED=$((UPDATED + 1))
  fi
done

echo ""

# ──────────────────────────────────────────────
# Sync learned/ taxonomy (24 files in halls/rooms/wings)
# MemPalace v3.2: Propagates local learned rules to global scope
# Security: taxonomy was filtered in W3.1 (46% noise excluded, no secrets)
# ──────────────────────────────────────────────
# T40: learned/ source moved from .claude/rules/learned to .claude/learned-src/learned
# so the repo stops auto-loading it twice. Claude Code only auto-loads
# .claude/rules/** — moving the source to .claude/learned-src/ takes it out
# of the auto-load path while keeping it versioned.
LEARNED_SOURCE="${REPO}/.claude/learned-src/learned"
LEARNED_TARGET="${HOME}/.claude/rules/learned"

if [[ -d "$LEARNED_SOURCE" ]]; then
  if [ "$DRY_RUN" = true ]; then
    echo "WOULD: Sync learned/ taxonomy (halls/rooms/wings) to global"
  else
    mkdir -p "$LEARNED_TARGET"
    rsync -a --delete "$LEARNED_SOURCE/" "$LEARNED_TARGET/" 2>/dev/null
    echo "SYNCED: learned/ taxonomy to global (halls/rooms/wings)"
  fi
else
  echo "SKIP: No learned/ taxonomy found at $LEARNED_SOURCE"
fi

echo ""
echo "Summary: $UPDATED updated, $SKIPPED skipped"
if [ "$DRY_RUN" = true ]; then
  echo "(dry run — no changes applied)"
fi
