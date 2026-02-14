#!/bin/bash
# session-start-repo-summary.sh - SessionStart Hook for Repo History Summary
# Hook: SessionStart
# Purpose: Display recent project history from claude-mem at session start
#
# When: Triggered at session start
# What: Queries claude-mem for recent observations about this project
#
# VERSION: 1.0.0
# CREATED: 2026-02-13
# SECURITY: SEC-006 compliant

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

set -euo pipefail

# Error trap for SessionStart hooks
trap 'echo "SessionStart repo-summary recovery"' ERR EXIT

umask 077

# Configuration
RALPH_DIR="${HOME}/.ralph"
LOG_DIR="${RALPH_DIR}/logs"
PROJECT_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || echo ".")}"
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

# Check if claude-mem MCP is available
# We'll try to read from the MCP via cached data or direct query
CACHE_FILE="${RALPH_DIR}/cache/claude-mem-recent-${PROJECT_NAME}.json"

# Try to get recent observations from cache or generate summary
if command -v jq &>/dev/null; then
    # Check for Ralph's semantic memory as fallback
    SEMANTIC_FILE="${RALPH_DIR}/memory/semantic.json"
    MEMVID_FILE="${RALPH_DIR}/memory/memvid.json"

    # Build summary from available sources
    SUMMARY_PARTS=()

    # 1. Check semantic memory
    if [[ -f "$SEMANTIC_FILE" ]]; then
        FACT_COUNT=$(jq '.facts | length // 0' "$SEMANTIC_FILE" 2>/dev/null || echo "0")
        if [[ "$FACT_COUNT" -gt 0 ]]; then
            # Get last 3 facts
            RECENT_FACTS=$(jq -r '.facts[-3:][] | "- \(.content[:80])..."' "$SEMANTIC_FILE" 2>/dev/null | head -3 || true)
            if [[ -n "$RECENT_FACTS" ]]; then
                SUMMARY_PARTS+=("## Recent Semantic Memory ($FACT_COUNT facts)\n$RECENT_FACTS")
            fi
        fi
    fi

    # 2. Check memvid
    if [[ -f "$MEMVID_FILE" ]]; then
        ENTRY_COUNT=$(jq '.entries | length // 0' "$MEMVID_FILE" 2>/dev/null || echo "0")
        if [[ "$ENTRY_COUNT" -gt 0 ]]; then
            RECENT_ENTRIES=$(jq -r '.entries[-3:][] | "- \(.title // .content[:60])"' "$MEMVID_FILE" 2>/dev/null | head -3 || true)
            if [[ -n "$RECENT_ENTRIES" ]]; then
                SUMMARY_PARTS+=("## Recent Memvid Entries ($ENTRY_COUNT total)\n$RECENT_ENTRIES")
            fi
        fi
    fi

    # 3. Check ledgers
    LEDGER_DIR="${RALPH_DIR}/ledgers"
    if [[ -d "$LEDGER_DIR" ]]; then
        LEDGER_COUNT=$(find "$LEDGER_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$LEDGER_COUNT" -gt 0 ]]; then
            LATEST_LEDGER=$(find "$LEDGER_DIR" -name "*.json" -type f -mtime -7 2>/dev/null | head -1)
            if [[ -n "$LATEST_LEDGER" ]]; then
                LEDGER_GOAL=$(jq -r '.goal // "No goal recorded"' "$LATEST_LEDGER" 2>/dev/null | head -1 || echo "No goal")
                SUMMARY_PARTS+=("## Latest Session Ledger\nGoal: ${LEDGER_GOAL[:100]}")
            fi
        fi
    fi

    # Combine all parts
    if [[ ${#SUMMARY_PARTS[@]} -gt 0 ]]; then
        SUMMARY="## 📊 Project History Summary: $PROJECT_NAME\n\n"
        for part in "${SUMMARY_PARTS[@]}"; do
            SUMMARY="${SUMMARY}${part}\n\n"
        done
        SUMMARY="${SUMMARY}💡 Use \`mcp__plugin_claude-mem_mcp-search__search\` to search full history"
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
