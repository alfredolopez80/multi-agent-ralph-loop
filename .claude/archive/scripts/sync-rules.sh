#!/usr/bin/env bash
# sync-rules.sh - One-way sync of rules from repo to global directories
# VERSION: 1.0.0
# Source: multi-agent-ralph-loop
#
# Usage:
#   ./scripts/sync-rules.sh           # Sync all rules
#   ./scripts/sync-rules.sh --dry-run # Preview changes without executing
#
# Rules are synced as SYMLINKS (not copies) to maintain single source of truth.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RULES_DIR="$REPO/.claude/rules"
GLOBAL_RULES_DIR="$HOME/.claude/rules"
CHECKSUM_FILE="$REPO/.claude/rules/.sync-checksums"

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

# Target directories for skill distribution
TARGET_DIRS=(
  "$GLOBAL_RULES_DIR"
)

sync_count=0
skip_count=0
warn_count=0

log() { echo "[$(date '+%H:%M:%S')] $1"; }

sync_rule() {
  local src="$1"
  local rel="${src#$RULES_DIR/}"
  local target="$GLOBAL_RULES_DIR/$rel"

  # Skip checksum file and non-md files
  [[ "$rel" == .sync-checksums ]] && return
  [[ "$rel" != *.md ]] && return

  if [[ -L "$target" ]]; then
    # Already a symlink - check if points to correct source
    local current_target
    current_target="$(readlink "$target" 2>/dev/null || echo "")"
    if [[ "$current_target" == "$src" ]]; then
      skip_count=$((skip_count + 1))
      return
    fi
  fi

  if [[ -f "$target" ]] && [[ ! -L "$target" ]]; then
    # Regular file exists - check if identical
    if cmp -s "$src" "$target"; then
      # Identical content - safe to replace with symlink
      if $DRY_RUN; then
        log "WOULD CONVERT: $rel (identical content, would symlink)"
      else
        ln -sfn "$src" "$target"
        log "CONVERTED: $rel (copy -> symlink)"
      fi
      sync_count=$((sync_count + 1))
      return
    else
      # Different content - warn
      log "WARN: $rel exists with different content (skipping)"
      warn_count=$((warn_count + 1))
      return
    fi
  fi

  # Target doesn't exist - create symlink
  if $DRY_RUN; then
    log "WOULD CREATE: $rel -> $src"
  else
    mkdir -p "$(dirname "$target")"
    ln -sfn "$src" "$target"
    log "CREATED: $rel"
  fi
  sync_count=$((sync_count + 1))
}

# Main
log "Syncing rules: $RULES_DIR -> $GLOBAL_RULES_DIR"
$DRY_RUN && log "(DRY RUN - no changes will be made)"

while IFS= read -r -d '' rule_file; do
  sync_rule "$rule_file"
done < <(find "$RULES_DIR" -name '*.md' -type f -print0)

echo ""
echo "Results: synced=$sync_count skipped=$skip_count warnings=$warn_count"

# Update checksums
if ! $DRY_RUN; then
  find "$RULES_DIR" -name '*.md' -type f -exec sha256sum {} \; > "$CHECKSUM_FILE" 2>/dev/null || true
fi
