#!/bin/bash
# session-start-repo-summary.sh - SessionStart Hook for Repo History Summary
# Hook: SessionStart
# Purpose: Display recent project history from Obsidian vault + ralph stores
#
# When: Triggered at session start
# What: Reads from ~/.ralph/memory/, ~/.ralph/ledgers/, and Obsidian vault
#
# VERSION: 3.2.0
# CREATED: 2026-02-13
# UPDATED: 2026-04-07 (vault-first: reads from Obsidian + ralph stores)
# SECURITY: SEC-006 compliant

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

set -euo pipefail

# Error trap for SessionStart hooks - only trigger on actual errors
trap 'echo "SessionStart repo-summary error recovery"' ERR

umask 077

# Configuration
RALPH_DIR="${HOME}/.ralph"
LOG_DIR="${RALPH_DIR}/logs"
_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() { git rev-parse --show-toplevel 2>/dev/null || echo "${CLAUDE_PROJECT_DIR:-.}"; }
  get_main_repo() { get_project_root; }
  get_claude_dir() { echo "$(get_main_repo)/.claude"; }
}
PROJECT_ROOT="$(get_project_root)"
PROJECT_NAME=$(basename "$PROJECT_ROOT" 2>/dev/null || echo "unknown")

# Create log directory
mkdir -p "$LOG_DIR"

# Logging function
log() {
    echo "[repo-summary] $(date -Iseconds): $1" >> "${LOG_DIR}/repo-summary.log" 2>&1 || true
}

log "=== Session Start Repo Summary ==="
log "Project: $PROJECT_NAME"

# Initialize summary
SUMMARY=""

# v3.2.0: claude-mem removed. Sources: semantic.json + ledgers + Obsidian vault + migrated JSONs.
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
MIGRATED_DIR="${VAULT_DIR}/migrated-from-claude-mem"

if command -v jq &>/dev/null; then
    SEMANTIC_FILE="${RALPH_DIR}/memory/semantic.json"

    # Build summary from available sources
    SUMMARY_PARTS=()

    # 1. Check semantic memory
    if [[ -f "$SEMANTIC_FILE" ]]; then
        FACT_COUNT=$(jq '.facts | length // 0' "$SEMANTIC_FILE" 2>/dev/null || echo "0")
        if [[ "$FACT_COUNT" -gt 0 ]]; then
            RECENT_FACTS=$(jq -r '.facts[-3:][] | "- \(.content[:80])..."' "$SEMANTIC_FILE" 2>/dev/null | head -3 || true)
            if [[ -n "$RECENT_FACTS" ]]; then
                SUMMARY_PARTS+=("## Recent Semantic Memory ($FACT_COUNT facts)\n$RECENT_FACTS")
            fi
        fi
    fi

    # 2. Check ledgers
    LEDGER_DIR="${RALPH_DIR}/ledgers"
    if [[ -d "$LEDGER_DIR" ]]; then
        LEDGER_COUNT=$(find "$LEDGER_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$LEDGER_COUNT" -gt 0 ]]; then
            LATEST_LEDGER=$(find "$LEDGER_DIR" -name "*.json" -type f -mtime -7 2>/dev/null | head -1)
            if [[ -n "$LATEST_LEDGER" ]]; then
                LEDGER_GOAL=$(jq -r '.goal // "No goal recorded"' "$LATEST_LEDGER" 2>/dev/null | head -1 || echo "No goal")
                SUMMARY_PARTS+=("## Latest Session Ledger\nGoal: ${LEDGER_GOAL:0:100}")
            fi
        fi
    fi

    # 3. Check migrated observations for this project
    if [[ -f "${MIGRATED_DIR}/decisions.json" ]]; then
        MIGRATED_DECISIONS=$(jq -r --arg proj "$PROJECT_NAME" '[.[] | select(.project == $proj)] | length' "${MIGRATED_DIR}/decisions.json" 2>/dev/null || echo "0")
        if [[ "$MIGRATED_DECISIONS" -gt 0 ]]; then
            RECENT_DECISIONS=$(jq -r --arg proj "$PROJECT_NAME" '[.[] | select(.project == $proj)] | .[0:3][] | "- \(.title // .subtitle // "(no title)")"' "${MIGRATED_DIR}/decisions.json" 2>/dev/null | head -3 || true)
            if [[ -n "$RECENT_DECISIONS" ]]; then
                SUMMARY_PARTS+=("## Historical Decisions ($MIGRATED_DECISIONS for $PROJECT_NAME)\n$RECENT_DECISIONS")
            fi
        fi
    fi

    # 4. Check Obsidian vault wiki articles (recent)
    if [[ -d "${VAULT_DIR}/global/wiki" ]]; then
        WIKI_COUNT=$(find "${VAULT_DIR}/global/wiki" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$WIKI_COUNT" -gt 0 ]]; then
            RECENT_WIKI=$(find "${VAULT_DIR}/global/wiki" -name "*.md" -type f -mtime -14 2>/dev/null | head -3 | xargs -I{} basename {} .md 2>/dev/null | awk '{print "- "$0}' || true)
            if [[ -n "$RECENT_WIKI" ]]; then
                SUMMARY_PARTS+=("## Recent Vault Articles ($WIKI_COUNT total)\n$RECENT_WIKI")
            fi
        fi
    fi

    # Combine all parts
    if [[ ${#SUMMARY_PARTS[@]} -gt 0 ]]; then
        SUMMARY="## 📊 Project History Summary: $PROJECT_NAME\n\n"
        for part in "${SUMMARY_PARTS[@]}"; do
            SUMMARY="${SUMMARY}${part}\n\n"
        done
        SUMMARY="${SUMMARY}💡 Search Obsidian vault directly or use grep on ~/.ralph/ stores"
    else
        SUMMARY="## 📊 Project: $PROJECT_NAME\n\nNo recent history found in local memory.\n\n💡 Start working to build up project memory!"
    fi
else
    SUMMARY="## 📊 Project: $PROJECT_NAME\n\n(jq not available - skipping memory summary)"
fi

log "Summary generated (${#SUMMARY} chars)"

# Output for SessionStart hook
# v2.87.0 FIX: Use jq for proper JSON escaping instead of sed
# The additionalContext field will be shown to Claude
ESCAPED_SUMMARY=$(echo -e "$SUMMARY" | jq -Rs '.' 2>/dev/null || echo '""')
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": $ESCAPED_SUMMARY}}"

log "=== Repo Summary Complete ==="
