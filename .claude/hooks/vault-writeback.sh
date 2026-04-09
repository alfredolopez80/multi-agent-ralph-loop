#!/bin/bash
# vault-writeback.sh — Stop Hook (Wave 3.1)
# ===========================================
#
# Event: Stop
# Wave:  W3.1 (writeback-pipeline)
# Plan:  .ralph/plans/breezy-coalescing-umbrella.md
#
# Karpathy writeback: when the session resolves a question that has
# lasting value, the answer is written back to the vault as a draft
# wiki article. This is the core of the compounding knowledge cycle.
#
# Since Stop hooks can't access the full transcript, this hook checks
# for a writeback queue file created by smart-memory-search.sh during
# the session. If pending writebacks exist, processes them.
#
# Input (JSON via stdin):
#   - (standard Stop hook input)
#
# Output: {"decision": "approve"} (Stop format)
#
# VERSION: 1.0.0
# CREATED: 2026-04-09

set -euo pipefail
umask 077

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
VAULT_DIR="${HOME}/Documents/Obsidian/MiVault"
LOG_FILE="${HOME}/.ralph/logs/vault-writeback.log"
WRITEBACK_QUEUE="${HOME}/.ralph/.writeback-queue.json"
KNOWN_CATEGORIES="security hooks architecture agent-engineering memory testing database backend frontend general"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] vault-writeback: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read stdin (SEC-111)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)

# ---------------------------------------------------------------------------
# Graceful skip if vault or queue missing
# ---------------------------------------------------------------------------
if [[ ! -d "$VAULT_DIR" ]]; then
    log "WARN vault missing, skipping writeback"
    echo '{"decision": "approve"}'
    exit 0
fi

if [[ ! -f "$WRITEBACK_QUEUE" ]]; then
    log "INFO no writeback queue, nothing to process"
    echo '{"decision": "approve"}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Process writeback queue
# ---------------------------------------------------------------------------
QUEUE_CONTENT=$(cat "$WRITEBACK_QUEUE" 2>/dev/null || echo "[]")
QUEUE_LENGTH=$(echo "$QUEUE_CONTENT" | jq 'length' 2>/dev/null || echo "0")

if [[ "$QUEUE_LENGTH" == "0" || "$QUEUE_LENGTH" == "null" ]]; then
    log "INFO empty writeback queue"
    rm -f "$WRITEBACK_QUEUE"
    echo '{"decision": "approve"}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Detect project
# ---------------------------------------------------------------------------
PROJECT="unknown"
if command -v git &>/dev/null; then
    REPO_ROOT="${HOME}/Documents/GitHub/multi-agent-ralph-loop"
    PROJECT=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")" 2>/dev/null || echo "unknown")
fi
[[ -z "$PROJECT" ]] && PROJECT="unknown"

WIKI_DIR="${VAULT_DIR}/projects/${PROJECT}/wiki"
mkdir -p "$WIKI_DIR"

# ---------------------------------------------------------------------------
# Process each queued item
# ---------------------------------------------------------------------------
PROCESSED=0
SKIPPED=0
for i in $(seq 0 $((QUEUE_LENGTH - 1)) 2>/dev/null); do
    TOPIC=$(echo "$QUEUE_CONTENT" | jq -r ".[$i].topic // empty" 2>/dev/null || echo "")
    SUMMARY=$(echo "$QUEUE_CONTENT" | jq -r ".[$i].summary // empty" 2>/dev/null || echo "")
    CATEGORY=$(echo "$QUEUE_CONTENT" | jq -r ".[$i].category // \"general\"" 2>/dev/null || echo "general")

    [[ -z "$TOPIC" || -z "$SUMMARY" ]] && { SKIPPED=$((SKIPPED + 1)); continue; }

    # Sanitize topic for filename
    SLUG=$(echo "$TOPIC" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-//;s/-$//' | head -c 60)
    ARTICLE_FILE="${WIKI_DIR}/${SLUG}.md"

    # Skip if already covered in vault
    if [[ -f "$ARTICLE_FILE" ]]; then
        log "INFO already covered: ${SLUG}"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Also check global wiki
    if grep -rl "$TOPIC" "${VAULT_DIR}/global/wiki/" 2>/dev/null | head -1 | grep -q .; then
        log "INFO covered in global wiki: ${TOPIC}"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    # Validate category
    if ! echo " $KNOWN_CATEGORIES " | grep -q " $CATEGORY "; then
        CATEGORY="general"
    fi

    # Sanitize summary (no secrets, no absolute paths)
    SAFE_SUMMARY=$(echo "$SUMMARY" | sed "s|${HOME}/|~/|g" | tr -cd ' a-zA-Z0-9_.:/-()[]{}?!,;' | head -c 2000)

    # Create draft wiki article
    NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    DATE_TODAY=$(date +"%Y-%m-%d")

    cat > "$ARTICLE_FILE" << ARTICLE
---
type: learning
classification: YELLOW
source: session-writeback-${DATE_TODAY}
confidence: 0.5
sessions_confirmed: 1
category: ${CATEGORY}
status: draft
created: ${NOW}
---

# ${TOPIC}

## Context

Auto-captured from session knowledge gap resolution.

## Content

${SAFE_SUMMARY}

## Links

- [[_vault-index]]
ARTICLE

    log "INFO wrote draft wiki: ${ARTICLE_FILE} category=${CATEGORY}"
    PROCESSED=$((PROCESSED + 1))
done

# Clean up queue
rm -f "$WRITEBACK_QUEUE"

log "INFO writeback complete processed=${PROCESSED} skipped=${SKIPPED}"
echo '{"decision": "approve"}'
exit 0
