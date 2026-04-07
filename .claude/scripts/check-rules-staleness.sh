#!/usr/bin/env bash
# check-rules-staleness.sh — Compare standalone copies vs repo source for divergence
# VERSION: 3.2.0
# Created: 2026-04-07 (W5.1 MemPalace)

umask 077

set -euo pipefail

REPO="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
RULES_DIR="$HOME/.claude/rules"
STALE=0
FRESH=0
MISSING=0
ERRORS=0

# Graceful: skip if repo does not exist
if [ ! -d "$REPO/.claude/rules" ]; then
  echo "STALENESS CHECK: Cannot check — repo not found at $REPO"
  echo "Standalone copies are the source of truth."
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

echo "Rules Staleness Check"
echo "====================="
echo "Comparing ~/.claude/rules/ against $REPO/.claude/rules/"
echo ""

for rule_file in "${RULE_FILES[@]}"; do
  SOURCE="$REPO/.claude/rules/$rule_file"
  TARGET="$RULES_DIR/$rule_file"

  # Check target exists
  if [ ! -f "$TARGET" ]; then
    echo "MISSING: $rule_file (standalone copy does not exist)"
    MISSING=$((MISSING + 1))
    continue
  fi

  # Check SOURCE header present
  HAS_HEADER=$(head -4 "$TARGET" | grep -c "SOURCE:" 2>/dev/null || true)
  if [ "$HAS_HEADER" -eq 0 ]; then
    echo "ERROR:  $rule_file (missing SOURCE header — may not be a promoted file)"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Extract SYNCED date from header
  SYNCED_DATE=$(grep "SYNCED:" "$TARGET" | head -1 | sed 's/.*SYNCED: *//' | tr -d ' ' 2>/dev/null || echo "unknown")

  # Check if source exists and is a real file
  if [ ! -f "$SOURCE" ] || [ -L "$SOURCE" ]; then
    echo "FRESH:  $rule_file (source unavailable — standalone is authoritative, synced: $SYNCED_DATE)"
    FRESH=$((FRESH + 1))
    continue
  fi

  # Compare: source has no header (starts at line 1), target has 5-line header
  # (content starts at line 6). Compare full source against target minus header.
  SOURCE_HASH=$(cat "$SOURCE" 2>/dev/null | shasum -a 256 | cut -d' ' -f1 || echo "error")
  TARGET_HASH=$(tail -n +6 "$TARGET" 2>/dev/null | shasum -a 256 | cut -d' ' -f1 || echo "error")

  if [ "$SOURCE_HASH" = "$TARGET_HASH" ]; then
    echo "FRESH:  $rule_file (synced: $SYNCED_DATE)"
    FRESH=$((FRESH + 1))
  else
    echo "STALE:  $rule_file (synced: $SYNCED_DATE, source has diverged)"
    # Show diff summary
    DIFF_LINES=$(diff <(cat "$SOURCE") <(tail -n +6 "$TARGET") 2>/dev/null | grep -c "^[<>]" || true)
    echo "        Divergence: $DIFF_LINES lines differ"
    STALE=$((STALE + 1))
  fi
done

echo ""
echo "====================="
echo "Total: $FRESH fresh, $STALE stale, $MISSING missing, $ERRORS errors"

if [ "$STALE" -gt 0 ]; then
  echo ""
  echo "To update stale rules, run:"
  echo "  bash ~/.claude/scripts/sync-rules-from-source.sh"
fi

# Exit with error if any stale or missing
if [ "$STALE" -gt 0 ] || [ "$MISSING" -gt 0 ] || [ "$ERRORS" -gt 0 ]; then
  exit 1
fi

exit 0
