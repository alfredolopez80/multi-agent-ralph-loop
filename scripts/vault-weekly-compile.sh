#!/usr/bin/env bash
# vault-weekly-compile.sh — Weekly vault compilation and backup
# VERSION: 3.0.0
#
# Runs automatically via cron every Friday at 6PM.
# If Friday was missed, Saturday/Sunday runs catch up.
#
# What it does:
# 1. Check if vault exists
# 2. Count new lessons since last compile
# 3. Update vault indices
# 4. Git commit + push to private repo
# 5. Log results
#
# Cron schedule (installed by this script):
#   Friday 6PM:   0 18 * * 5
#   Saturday 9AM: 0 9 * * 6 (catch-up if Friday missed)
#   Sunday 9AM:   0 9 * * 0 (catch-up if Saturday missed)

set -euo pipefail

VAULT_DIR="${VAULT_DIR:-$HOME/Documents/Obsidian/MiVault}"
LOG_DIR="$HOME/.ralph/logs"
LOG_FILE="$LOG_DIR/vault-compile.log"
LOCK_FILE="/tmp/vault-weekly-compile.lock"
LAST_RUN_FILE="$VAULT_DIR/.last-compile"

mkdir -p "$LOG_DIR" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Prevent concurrent runs
if [ -f "$LOCK_FILE" ]; then
    pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if kill -0 "$pid" 2>/dev/null; then
        log "SKIP: Another compile is running (PID $pid)"
        exit 0
    fi
    rm -f "$LOCK_FILE"
fi
echo $$ > "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Check if vault exists
if [ ! -d "$VAULT_DIR" ]; then
    log "ERROR: Vault not found at $VAULT_DIR"
    exit 1
fi

# Check if already compiled this week
if [ -f "$LAST_RUN_FILE" ]; then
    last_run=$(cat "$LAST_RUN_FILE")
    current_week=$(date +%Y-W%V)
    if [ "$last_run" = "$current_week" ]; then
        log "SKIP: Already compiled this week ($current_week)"
        exit 0
    fi
fi

log "=== Weekly Vault Compile ==="

# Count new lessons
cd "$VAULT_DIR"
new_lessons=0
for project_dir in projects/*/lessons/; do
    if [ -d "$project_dir" ]; then
        count=$(find "$project_dir" -name "*.md" -newer "$LAST_RUN_FILE" 2>/dev/null | wc -l || echo 0)
        new_lessons=$((new_lessons + count))
    fi
done
log "New lessons since last compile: $new_lessons"

# Update indices
log "Updating vault indices..."

# Update global wiki index
{
    echo "# Global Wiki Index"
    echo ""
    echo "Auto-updated: $(date '+%Y-%m-%d %H:%M')"
    echo ""
    for category_dir in global/wiki/*/; do
        if [ -d "$category_dir" ]; then
            category=$(basename "$category_dir")
            count=$(find "$category_dir" -name "*.md" | wc -l)
            if [ "$count" -gt 0 ]; then
                echo "## $category ($count articles)"
                find "$category_dir" -name "*.md" -exec basename {} .md \; | sort | while read article; do
                    echo "- [[$category/$article]]"
                done
                echo ""
            fi
        fi
    done
} > global/wiki/_index.md

# Update project index
{
    echo "# Project Index"
    echo ""
    echo "Auto-updated: $(date '+%Y-%m-%d %H:%M')"
    echo ""
    for project_dir in projects/*/; do
        if [ -d "$project_dir" ] && [ "$(basename "$project_dir")" != "_project-index.md" ]; then
            project=$(basename "$project_dir")
            lesson_count=$(find "$project_dir/lessons" -name "*.md" 2>/dev/null | wc -l || echo 0)
            wiki_count=$(find "$project_dir/wiki" -name "*.md" 2>/dev/null | wc -l || echo 0)
            echo "## $project"
            echo "- Lessons: $lesson_count"
            echo "- Wiki articles: $wiki_count"
            echo ""
        fi
    done
} > projects/_project-index.md

# Update vault master index
{
    echo "# Vault Index"
    echo ""
    echo "Auto-updated: $(date '+%Y-%m-%d %H:%M')"
    echo ""
    echo "## Statistics"
    total_lessons=$(find projects -name "*.md" -path "*/lessons/*" 2>/dev/null | wc -l || echo 0)
    total_wiki=$(find global/wiki -name "*.md" ! -name "_index.md" 2>/dev/null | wc -l || echo 0)
    total_decisions=$(find . -name "*.md" -path "*/decisions/*" 2>/dev/null | wc -l || echo 0)
    echo "- Total lessons: $total_lessons"
    echo "- Wiki articles: $total_wiki"
    echo "- Decisions: $total_decisions"
    echo ""
    echo "## Global Knowledge"
    echo "- [Global Wiki](global/wiki/_index.md)"
    echo "- [Raw Sources](global/raw/)"
    echo "- [Decisions](global/decisions/)"
    echo ""
    echo "## Projects"
    echo "- [Project Index](projects/_project-index.md)"
} > _vault-index.md

log "Indices updated"

# ──────────────────────────────────────────────
# Sync learned rules to global (MemPalace v3.2)
# Ensures Friday cron propagates local learnings to ~/.claude/rules/learned/
# ──────────────────────────────────────────────
REPO_ROOT="~/Documents/GitHub/multi-agent-ralph-loop"
if [[ -f "${REPO_ROOT}/.claude/scripts/sync-rules-from-source.sh" ]]; then
    log "Syncing learned rules to global..."
    bash "${REPO_ROOT}/.claude/scripts/sync-rules-from-source.sh" 2>/dev/null || true
    log "Rules sync complete"
fi

# Git commit + push
if [ -d ".git" ]; then
    git add -A
    if ! git diff --cached --quiet; then
        git commit -m "vault: weekly compile $(date '+%Y-%m-%d') ($new_lessons new lessons)"
        git push origin main 2>/dev/null && log "Pushed to GitHub" || log "Push failed (offline?)"
    else
        log "No changes to commit"
    fi
fi

# Record this week's compile
date +%Y-W%V > "$LAST_RUN_FILE"
log "=== Compile Complete ==="
