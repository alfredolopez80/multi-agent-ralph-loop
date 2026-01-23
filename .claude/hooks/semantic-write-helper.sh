#!/bin/bash
# Semantic Memory Write Helper (v2.57.4)
# Hook: Shared library for atomic writes to semantic.json
# Purpose: Prevent race conditions when multiple hooks write to semantic.json
#
# Usage: semantic-write-helper.sh --add '{"content": "...", "category": "...", "file": "..."}'
#
# VERSION: 2.57.5
# SECURITY: SEC-006 compliant

set -euo pipefail
umask 077

SEMANTIC_FILE="${HOME}/.ralph/memory/semantic.json"
LOCK_FILE="${HOME}/.ralph/memory/.semantic.lock"
LOG_DIR="${HOME}/.ralph/logs"

mkdir -p "$(dirname "$SEMANTIC_FILE")" "$LOG_DIR"

# Initialize semantic.json if missing
if [[ ! -f "$SEMANTIC_FILE" ]]; then
    echo '{"facts": [], "version": "2.57.4"}' > "$SEMANTIC_FILE"
fi

# Function to add fact atomically
add_fact() {
    local content="$1"
    local category="$2"
    local source="$3"
    local file="$4"

    # Use flock for atomic write (BSD/macOS compatible)
    (
        flock -x 200 || { echo "[$(date -Iseconds)] ERROR: Could not acquire lock" >> "${LOG_DIR}/semantic-write.log"; exit 1; }

        # Check if fact already exists (deduplication)
        local EXISTS
        EXISTS=$(jq -r --arg f "$content" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")

        if [[ -z "$EXISTS" ]]; then
            local FACT_ID="sem-$(date +%s)-$RANDOM"
            local TIMESTAMP=$(date -Iseconds)

            # Atomic write using temp file
            jq --arg id "$FACT_ID" \
               --arg content "$content" \
               --arg cat "$category" \
               --arg ts "$TIMESTAMP" \
               --arg src "$source" \
               --arg fl "$file" \
               '.facts += [{"id": $id, "content": $content, "category": $cat, "timestamp": $ts, "source": $src, "file": $fl}]' \
               "$SEMANTIC_FILE" > "${SEMANTIC_FILE}.tmp" && mv "${SEMANTIC_FILE}.tmp" "$SEMANTIC_FILE"

            echo "[$TIMESTAMP] ADDED: $content (category: $category, source: $source)" >> "${LOG_DIR}/semantic-write.log"
            echo "ADDED:$content"
            exit 0
        else
            echo "[$(date -Iseconds)] SKIP (exists): $content" >> "${LOG_DIR}/semantic-write.log"
            echo "SKIP:$content"
            exit 0
        fi
    ) 200>"$LOCK_FILE"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --add)
            FACT_JSON="$2"
            content=$(echo "$FACT_JSON" | jq -r '.content')
            category=$(echo "$FACT_JSON" | jq -r '.category')
            source=$(echo "$FACT_JSON" | jq -r '.source // "manual"')
            file=$(echo "$FACT_JSON" | jq -r '.file')
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 --add '{\"content\": \"...\", \"category\": \"...\", \"file\": \"...\"}'"
            echo ""
            echo "Atomic writer for semantic.json"
            echo "Uses flock for cross-platform locking"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run add_fact if data provided
if [[ -n "${content:-}" ]]; then
    add_fact "$content" "$category" "$source" "$file"
fi
