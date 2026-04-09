#!/bin/bash
# vault-log-writer.sh — SessionEnd Hook (Wave 5.2)
# =================================================
#
# Event: SessionEnd
# Wave:  W5.2 (chronological-log)
# Plan:  .ralph/plans/breezy-coalescing-umbrella.md
#
# Appends a one-line chronological entry to the vault log.md,
# following Karpathy's append-only log pattern.
#
# Input (JSON via stdin):
#   - session_id: session identifier
#   - (other fields ignored)
#
# Output: {"decision": "approve"} (SessionEnd format)
#
# VERSION: 1.0.0
# CREATED: 2026-04-09

set -euo pipefail
umask 077

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
LOG_FILE_PATH="${VAULT_DIR}/log.md"
HOOK_LOG="${HOME}/.ralph/logs/vault-log-writer.log"
MAX_LOG_LINES=10000  # Trim after this many lines

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] vault-log-writer: $*" >> "$HOOK_LOG" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read stdin (SEC-111: limit to 100KB)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

# ---------------------------------------------------------------------------
# Graceful skip if vault missing
# ---------------------------------------------------------------------------
if [[ ! -d "$VAULT_DIR" ]]; then
    log "WARN vault missing, skipping log write"
    echo '{"decision": "approve"}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Detect project name
# ---------------------------------------------------------------------------
PROJECT="unknown"
if command -v git &>/dev/null; then
    REPO_ROOT="${HOME}/Documents/GitHub/multi-agent-ralph-loop"
    PROJECT=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")" 2>/dev/null || echo "unknown")
fi
[[ -z "$PROJECT" ]] && PROJECT="unknown"

# ---------------------------------------------------------------------------
# Count vault changes (wiki, facts, decisions)
# ---------------------------------------------------------------------------
WIKI_COUNT=$(find "${VAULT_DIR}/global/wiki" "${VAULT_DIR}/projects" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
FACTS_COUNT=$(find "${VAULT_DIR}/projects" -name "facts-*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
DECISIONS_COUNT=$(find "${VAULT_DIR}/projects" -name "*.json" -path "*/decisions/*" -type f 2>/dev/null | wc -l | tr -d ' ')

# ---------------------------------------------------------------------------
# Get brief summary from handoff data if available
# ---------------------------------------------------------------------------
SUMMARY="session completed"
NEXT_CONTEXT="${HOME}/.ralph/.next-session-context"
if [[ -f "$NEXT_CONTEXT" ]]; then
    SUMMARY=$(head -1 "$NEXT_CONTEXT" | cut -c1-120 | tr -cd 'a-zA-Z0-9 ._/-:' || echo "session completed")
fi

# ---------------------------------------------------------------------------
# Write log entry (Karpathy pattern: append-only chronological)
# ---------------------------------------------------------------------------
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
LOG_ENTRY="- ${NOW} | ${SESSION_ID} | ${PROJECT} | wiki=${WIKI_COUNT} facts=${FACTS_COUNT} decisions=${DECISIONS_COUNT} | ${SUMMARY}"

# Create log.md with header if it doesn't exist
if [[ ! -f "$LOG_FILE_PATH" ]]; then
    cat > "$LOG_FILE_PATH" << HEADER
# Vault Log

Chronological record of vault activity. Karpathy LLM Wiki pattern.
Parseable: \`grep "^- " log.md | tail -5\`

---

HEADER
    log "INFO created log.md"
fi

# Append entry (mkdir-based locking)
LOCK_DIR="${VAULT_DIR}/.log-lock"
LOCK_TRIES=0
LOCK_MAX=5
while [[ -d "$LOCK_DIR" && $LOCK_TRIES -lt $LOCK_MAX ]]; do
    sleep 0.2
    LOCK_TRIES=$((LOCK_TRIES + 1))
done

if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$LOG_ENTRY" >> "$LOG_FILE_PATH"

    # Trim if too long (keep last MAX_LOG_LINES)
    LINE_COUNT=$(wc -l < "$LOG_FILE_PATH" | tr -d ' ')
    if [[ $LINE_COUNT -gt $MAX_LOG_LINES ]]; then
        # Keep header (first 5 lines) + last N lines
        HEADERS=$(head -5 "$LOG_FILE_PATH")
        BODY=$(tail -n "$MAX_LOG_LINES" "$LOG_FILE_PATH")
        echo "$HEADERS" > "$LOG_FILE_PATH"
        echo "$BODY" >> "$LOG_FILE_PATH"
        log "INFO trimmed log from ${LINE_COUNT} to ${MAX_LOG_LINES} lines"
    fi

    rmdir "$LOCK_DIR" 2>/dev/null || true
    log "INFO log entry written: ${LOG_ENTRY}"
else
    log "WARN could not acquire lock, skipping log write"
fi

# ---------------------------------------------------------------------------
# Output SessionEnd format
# ---------------------------------------------------------------------------
echo '{"decision": "approve"}'

exit 0
