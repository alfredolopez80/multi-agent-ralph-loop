#!/bin/bash
# NOTE: Ralph memory system deprecated - using claude-mem MCP only
# This hook is temporarily disabled pending migration to claude-mem
echo "{"decision": "approve", "suppressOutput": true}"
exit 0
# Semantic Memory Write Helper (v2.57.4)
# Hook: Shared library for atomic writes to semantic.json
# Purpose: Prevent race conditions when multiple hooks write to semantic.json
#
# Usage: semantic-write-helper.sh --add '{"content": "...", "category": "...", "file": "..."}'
#
# VERSION: 2.69.0
# SECURITY: SEC-006 compliant

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


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

    # Use mkdir for portable atomic locking (works on macOS and Linux)
    local LOCK_DIR="${LOCK_FILE}.d"
    local LOCK_ATTEMPTS=0

    # Acquire lock
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        LOCK_ATTEMPTS=$((LOCK_ATTEMPTS + 1))
        if [[ $LOCK_ATTEMPTS -gt 50 ]]; then
            echo "[$(date -Iseconds)] ERROR: Could not acquire lock after 5s" >> "${LOG_DIR}/semantic-write.log"
            echo "ERROR:lock_timeout"
            return 1
        fi
        sleep 0.1
    done

    # Ensure lock is released on exit
    trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' RETURN

    # Check if fact already exists (deduplication)
    local EXISTS
    EXISTS=$(jq -r --arg f "$content" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")

    if [[ -z "$EXISTS" ]]; then
        local FACT_ID TIMESTAMP
        FACT_ID="sem-$(date +%s)-$RANDOM"
        TIMESTAMP=$(date -Iseconds)

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
    else
        echo "[$(date -Iseconds)] SKIP (exists): $content" >> "${LOG_DIR}/semantic-write.log"
        echo "SKIP:$content"
    fi
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
            echo "Uses mkdir for portable cross-platform locking"
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
