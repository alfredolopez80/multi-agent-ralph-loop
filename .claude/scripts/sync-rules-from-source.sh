#!/usr/bin/env bash
# sync-rules-from-source.sh — Update standalone rule copies from repo source
# VERSION: 3.2.0
# Created: 2026-04-07 (W5.1 MemPalace)

umask 077

set -euo pipefail

REPO="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
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

if [ ! -d "$REPO/.claude/rules" ]; then
  echo "SKIP: Repo rules directory not found at $REPO/.claude/rules"
  echo "Standalone copies remain in place (no update needed)."
  exit 0
fi

RULE_FILES=(
  "aristotle-methodology.md"
  "ast-grep-usage.md"
  "browser-automation.md"
  "parallel-first.md"
  "plan-immutability.md"
  "zai-mcp-usage.md"
)

echo "Syncing rules from repo to standalone copies..."
if [ "$DRY_RUN" = true ]; then
  echo "(DRY RUN — no changes will be made)"
fi
echo ""

for rule_file in "${RULE_FILES[@]}"; do
  SOURCE="$REPO/.claude/rules/$rule_file"
  TARGET="$RULES_DIR/$rule_file"

  if [ ! -f "$SOURCE" ] || [ -L "$SOURCE" ]; then
    echo "SKIP: $rule_file (source is missing or is a symlink)"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  if [ ! -f "$TARGET" ]; then
    echo "SKIP: $rule_file (target does not exist)"
    SKIPPED=$((SKIPPED + 1))
    continue
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
        echo "<!-- SOURCE: multi-agent-ralph-loop/.claude/rules/$rule_file"
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
echo "Summary: $UPDATED updated, $SKIPPED skipped"
if [ "$DRY_RUN" = true ]; then
  echo "(dry run — no changes applied)"
fi
