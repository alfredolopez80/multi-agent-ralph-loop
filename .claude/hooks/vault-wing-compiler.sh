#!/bin/bash
# vault-wing-compiler.sh — SessionEnd Hook (Wave 2.1)
# ====================================================
#
# Event: SessionEnd
# Wave:  W2.1 (project-wings)
# Plan:  .ralph/plans/breezy-coalescing-umbrella.md
#
# Compiles project facts into L2 wing context (Layer2.write).
# Reads today's facts file, deduplicates against existing wing,
# and writes updated wing via layers.py Layer2 class.
#
# Input (JSON via stdin):
#   - session_id: session identifier
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
L2_DIR="${HOME}/.ralph/layers/L2_wings"
LIB_DIR="${HOME}/Documents/GitHub/multi-agent-ralph-loop/.claude/lib"
LOG_FILE="${HOME}/.ralph/logs/vault-wing-compiler.log"
MAX_WING_ENTRIES=50
VALID_CATEGORIES="code_structure dependencies design_patterns api_patterns"

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------
mkdir -p "${HOME}/.ralph/logs" "${L2_DIR}"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] vault-wing-compiler: $*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Read stdin (SEC-111)
# ---------------------------------------------------------------------------
INPUT=$(head -c 100000)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null | tr -cd 'a-zA-Z0-9_-' | head -c 64)
[[ -z "$SESSION_ID" ]] && SESSION_ID="unknown"

# ---------------------------------------------------------------------------
# Detect project name
# ---------------------------------------------------------------------------
PROJECT="unknown"
if command -v git &>/dev/null; then
    REPO_ROOT="${HOME}/Documents/GitHub/multi-agent-ralph-loop"
    PROJECT=$(basename "$(git -C "$REPO_ROOT" rev-parse --show-toplevel 2>/dev/null || echo "")" 2>/dev/null || echo "unknown")
fi
[[ -z "$PROJECT" || "$PROJECT" == "unknown" ]] && { log "WARN no project detected"; echo '{"decision": "approve"}'; exit 0; }

# Sanitize project name for filesystem
SAFE_PROJECT=$(echo "$PROJECT" | tr -cd 'a-zA-Z0-9_-' | head -c 64)

# ---------------------------------------------------------------------------
# Check for today's facts file
# ---------------------------------------------------------------------------
TODAY=$(date +"%Y%m%d")
FACTS_FILE="${VAULT_DIR}/projects/${PROJECT}/facts/facts-${TODAY}.md"

if [[ ! -f "$FACTS_FILE" ]]; then
    log "INFO no facts file for today: ${FACTS_FILE}"
    echo '{"decision": "approve"}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Extract categorized facts (filter to valid categories only)
# ---------------------------------------------------------------------------
NEW_FACTS=""
while IFS= read -r line; do
    # Extract category tag: [category] pattern
    CATEGORY=$(echo "$line" | grep -oE '\[[a-z_]+\]' | tr -d '[]' | head -1)
    if [[ -n "$CATEGORY" ]] && echo " $VALID_CATEGORIES " | grep -q " $CATEGORY "; then
        # Sanitize content: strip absolute paths, keep relative
        SAFE_LINE=$(echo "$line" | sed "s|${HOME}/|~/|g" | tr -cd ' a-zA-Z0-9_.:/-()[]{}' | head -c 200)
        NEW_FACTS="${NEW_FACTS}- [${CATEGORY}] ${SAFE_LINE}
"
    fi
done < "$FACTS_FILE"

if [[ -z "$NEW_FACTS" ]]; then
    log "INFO no valid categorized facts found"
    echo '{"decision": "approve"}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Load existing wing and deduplicate
# ---------------------------------------------------------------------------
WING_FILE="${L2_DIR}/${SAFE_PROJECT}/context.md"
EXISTING=""
if [[ -f "$WING_FILE" ]]; then
    EXISTING=$(cat "$WING_FILE" 2>/dev/null || echo "")
fi

# Filter out facts that already exist in the wing
DEDUPED_FACTS=""
while IFS= read -r fact_line; do
    [[ -z "$fact_line" ]] && continue
    # Check if this exact fact (first 60 chars) already exists
    FACT_KEY=$(echo "$fact_line" | cut -c1-60)
    if [[ -n "$EXISTING" ]] && echo "$EXISTING" | grep -qF "$FACT_KEY"; then
        continue  # Skip duplicate
    fi
    DEDUPED_FACTS="${DEDUPED_FACTS}${fact_line}
"
done <<< "$NEW_FACTS"

if [[ -z "$DEDUPED_FACTS" ]]; then
    log "INFO all facts already in wing, nothing new"
    echo '{"decision": "approve"}'
    exit 0
fi

# ---------------------------------------------------------------------------
# Compile new wing content
# ---------------------------------------------------------------------------
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ -z "$EXISTING" ]]; then
    # New wing
    WING_CONTENT="# Wing: ${PROJECT}

**Project**: ${PROJECT}
**Compiled**: ${NOW}
**Source**: vault-wing-compiler.sh (auto-generated)

## Facts

${DEDUPED_FACTS}
"
else
    # Append to existing wing
    WING_CONTENT="${EXISTING}

${DEDUPED_FACTS}"
fi

# ---------------------------------------------------------------------------
# FIFO trim: keep only last MAX_WING_ENTRIES lines of facts
# ---------------------------------------------------------------------------
TOTAL_LINES=$(echo "$WING_CONTENT" | wc -l | tr -d ' ')
if [[ $TOTAL_LINES -gt $((MAX_WING_ENTRIES + 10)) ]]; then
    # Keep header (first 6 lines) + last MAX_WING_ENTRIES lines
    HEADER=$(echo "$WING_CONTENT" | head -6)
    BODY=$(echo "$WING_CONTENT" | tail -n "$MAX_WING_ENTRIES")
    WING_CONTENT="${HEADER}

${BODY}"
    log "INFO trimmed wing from ${TOTAL_LINES} to ~$((MAX_WING_ENTRIES + 6)) lines"
fi

# ---------------------------------------------------------------------------
# Write wing via mkdir-based locking
# ---------------------------------------------------------------------------
WING_DIR="${L2_DIR}/${SAFE_PROJECT}"
mkdir -p "$WING_DIR"

LOCK_DIR="${L2_DIR}/.wing-lock"
LOCK_TRIES=0
LOCK_MAX=5
while [[ -d "$LOCK_DIR" && $LOCK_TRIES -lt $LOCK_MAX ]]; do
    sleep 0.2
    LOCK_TRIES=$((LOCK_TRIES + 1))
done

if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$WING_CONTENT" > "$WING_FILE"
    rmdir "$LOCK_DIR" 2>/dev/null || true
    FACT_COUNT=$(echo "$DEDUPED_FACTS" | grep -c "^-" || echo "0")
    log "INFO wing compiled project=${PROJECT} new_facts=${FACT_COUNT}"
else
    log "WARN could not acquire lock for wing write"
fi

echo '{"decision": "approve"}'
exit 0
