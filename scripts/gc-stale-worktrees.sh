#!/usr/bin/env bash
# gc-stale-worktrees.sh — Remove worktrees older than 7 days with no recent commits.
# VERSION: 1.0.0
#
# Usage: ./scripts/gc-stale-worktrees.sh [--dry-run] [--max-age DAYS]
#
# Default: removes worktrees under .claude/worktrees/ older than 7 days
# that have no commits in the last 7 days.
#
# --dry-run   Show what would be removed without removing
# --max-age N Set threshold to N days (default: 7)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "${REPO_ROOT}/.claude/hooks/lib/worktree-utils.sh" 2>/dev/null || {
  echo "ERROR: Cannot source worktree-utils.sh" >&2
  exit 1
}

MAIN_REPO="$(get_main_repo)"
WT_BASE="$MAIN_REPO/.claude/worktrees"
DRY_RUN=false
MAX_AGE_DAYS=7

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --max-age) MAX_AGE_DAYS="${2:-7}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ ! -d "$WT_BASE" ]]; then
  echo "No worktrees directory found at $WT_BASE"
  exit 0
fi

MAX_AGE_SECONDS=$((MAX_AGE_DAYS * 86400))
NOW=$(date +%s)
REMOVED=0
PRESERVED=0
ERRORS=0

echo "=== GC Stale Worktrees ==="
echo "Threshold: ${MAX_AGE_DAYS} days (${MAX_AGE_SECONDS}s)"
echo "Base dir:  $WT_BASE"
echo ""

for wt_dir in "$WT_BASE"/*/; do
  [[ -d "$wt_dir" ]] || continue

  slug=$(basename "$wt_dir")
  branch="worktree-$slug"

  # Get last commit timestamp in the worktree
  last_commit_epoch=$(cd "$wt_dir" && git log -1 --format="%ct" 2>/dev/null || echo "0")
  last_commit_age=$(( NOW - last_commit_epoch ))

  # Get directory creation time
  dir_epoch=$(stat -f "%B" "$wt_dir" 2>/dev/null || stat -c "%W" "$wt_dir" 2>/dev/null || echo "0")
  dir_age=$(( NOW - dir_epoch ))

  # Stale if BOTH directory age > threshold AND last commit age > threshold
  if [[ "$dir_age" -gt "$MAX_AGE_SECONDS" && "$last_commit_age" -gt "$MAX_AGE_SECONDS" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      echo "[DRY-RUN] Would remove: $slug (dir_age=$(( dir_age / 86400 ))d, commit_age=$(( last_commit_age / 86400 ))d)"
    else
      if removeWorktree "$slug" 2>/dev/null; then
        echo "[REMOVED] $slug (dir_age=$(( dir_age / 86400 ))d, commit_age=$(( last_commit_age / 86400 ))d)"
        ((REMOVED++)) || true
      else
        echo "[ERROR] Failed to remove: $slug"
        ((ERRORS++)) || true
      fi
    fi
  else
    echo "[PRESERVED] $slug (dir_age=$(( dir_age / 86400 ))d, commit_age=$(( last_commit_age / 86400 ))d)"
    ((PRESERVED++)) || true
  fi
done

echo ""
echo "=== Summary ==="
echo "Removed:   $REMOVED"
echo "Preserved: $PRESERVED"
echo "Errors:    $ERRORS"
if [[ "$DRY_RUN" == "true" ]]; then
  echo "(dry-run mode — no changes made)"
fi
