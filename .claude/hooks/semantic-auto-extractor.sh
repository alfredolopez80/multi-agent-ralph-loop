#!/bin/bash
# Semantic Auto-Extractor (v2.55.0)
# Hook: Stop
# Purpose: Extract semantic facts from session's code changes
#
# Analyzes git diff from the session and extracts:
# - New functions/classes added
# - Dependencies introduced
# - Configuration changes
# - Architectural decisions
#
# VERSION: 2.68.2
# SECURITY: SEC-006 compliant with ERR trap for guaranteed JSON output

set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
# Stop hooks use {"decision": "approve|block"}
output_json() {
    echo '{"decision": "approve", "suppressOutput": true}'
}
trap 'output_json' ERR

# Parse input
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Config check
CONFIG_FILE="${HOME}/.ralph/config/memory-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"decision": "approve", "suppressOutput": true}'
    exit 0
fi

# Check if semantic auto-extraction is enabled
AUTO_EXTRACT=$(jq -r '.semantic.auto_extract // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
if [[ "$AUTO_EXTRACT" != "true" ]]; then
    echo '{"decision": "approve", "suppressOutput": true}'
    exit 0
fi

# Paths
SEMANTIC_FILE="${HOME}/.ralph/memory/semantic.json"
LOG_DIR="${HOME}/.ralph/logs"
mkdir -p "$LOG_DIR" "${HOME}/.ralph/memory"

# Initialize semantic.json if missing
if [[ ! -f "$SEMANTIC_FILE" ]]; then
    echo '{"facts": [], "version": "2.55.0"}' > "$SEMANTIC_FILE"
fi

# Run extraction in background (non-blocking)
{
    echo "[$(date -Iseconds)] Semantic extraction started for session: $SESSION_ID"

    # Get git diff from session (staged + unstaged changes)
    GIT_DIFF=""
    if git rev-parse --git-dir > /dev/null 2>&1; then
        GIT_DIFF=$(git diff HEAD 2>/dev/null || git diff 2>/dev/null || echo "")
    fi

    # Skip if no changes
    if [[ -z "$GIT_DIFF" ]]; then
        echo "[$(date -Iseconds)] No git changes to analyze"
        exit 0
    fi

    # Extract facts from diff
    FACTS_ADDED=0

    # 1. Extract new functions (Python)
    while IFS= read -r func; do
        [[ -z "$func" ]] && continue
        FUNC_NAME=$(echo "$func" | sed 's/^+def //; s/(.*//; s/ *$//')
        [[ -z "$FUNC_NAME" ]] && continue

        # Check if fact already exists
        EXISTS=$(jq -r --arg f "Added function: $FUNC_NAME" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")
        if [[ -z "$EXISTS" ]]; then
            FACT_ID="sem-$(date +%s)-$RANDOM"
            jq --arg id "$FACT_ID" \
               --arg content "Added function: $FUNC_NAME" \
               --arg cat "code_structure" \
               --arg ts "$(date -Iseconds)" \
               '.facts += [{"id": $id, "content": $content, "category": $cat, "timestamp": $ts, "source": "auto-extract"}]' \
               "$SEMANTIC_FILE" > "${SEMANTIC_FILE}.tmp" && mv "${SEMANTIC_FILE}.tmp" "$SEMANTIC_FILE"
            FACTS_ADDED=$((FACTS_ADDED + 1))
        fi
    done < <(echo "$GIT_DIFF" | grep -E '^\+def [a-zA-Z_]' 2>/dev/null || true)

    # 2. Extract new classes (Python)
    while IFS= read -r cls; do
        [[ -z "$cls" ]] && continue
        CLASS_NAME=$(echo "$cls" | sed 's/^+class //; s/(.*//; s/:.*//; s/ *$//')
        [[ -z "$CLASS_NAME" ]] && continue

        EXISTS=$(jq -r --arg f "Added class: $CLASS_NAME" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")
        if [[ -z "$EXISTS" ]]; then
            FACT_ID="sem-$(date +%s)-$RANDOM"
            jq --arg id "$FACT_ID" \
               --arg content "Added class: $CLASS_NAME" \
               --arg cat "code_structure" \
               --arg ts "$(date -Iseconds)" \
               '.facts += [{"id": $id, "content": $content, "category": $cat, "timestamp": $ts, "source": "auto-extract"}]' \
               "$SEMANTIC_FILE" > "${SEMANTIC_FILE}.tmp" && mv "${SEMANTIC_FILE}.tmp" "$SEMANTIC_FILE"
            FACTS_ADDED=$((FACTS_ADDED + 1))
        fi
    done < <(echo "$GIT_DIFF" | grep -E '^\+class [a-zA-Z_]' 2>/dev/null || true)

    # 3. Extract new TypeScript/JavaScript functions
    while IFS= read -r func; do
        [[ -z "$func" ]] && continue
        # Extract function name from various patterns
        FUNC_NAME=$(echo "$func" | sed -E 's/^\+(export )?(async )?function //; s/\(.*//; s/ *$//')
        [[ -z "$FUNC_NAME" ]] && continue

        EXISTS=$(jq -r --arg f "Added function: $FUNC_NAME" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")
        if [[ -z "$EXISTS" ]]; then
            FACT_ID="sem-$(date +%s)-$RANDOM"
            jq --arg id "$FACT_ID" \
               --arg content "Added function: $FUNC_NAME" \
               --arg cat "code_structure" \
               --arg ts "$(date -Iseconds)" \
               '.facts += [{"id": $id, "content": $content, "category": $cat, "timestamp": $ts, "source": "auto-extract"}]' \
               "$SEMANTIC_FILE" > "${SEMANTIC_FILE}.tmp" && mv "${SEMANTIC_FILE}.tmp" "$SEMANTIC_FILE"
            FACTS_ADDED=$((FACTS_ADDED + 1))
        fi
    done < <(echo "$GIT_DIFF" | grep -E '^\+(export )?(async )?function [a-zA-Z_]' 2>/dev/null || true)

    # 4. Extract new dependencies (package.json)
    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        DEP_NAME=$(echo "$dep" | sed 's/^+.*"//; s/".*//; s/: *".*//; s/[",:]//g; s/ *$//')
        [[ -z "$DEP_NAME" ]] || [[ "$DEP_NAME" == "dependencies" ]] || [[ "$DEP_NAME" == "devDependencies" ]] && continue

        EXISTS=$(jq -r --arg f "Added dependency: $DEP_NAME" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")
        if [[ -z "$EXISTS" ]]; then
            FACT_ID="sem-$(date +%s)-$RANDOM"
            jq --arg id "$FACT_ID" \
               --arg content "Added dependency: $DEP_NAME" \
               --arg cat "dependencies" \
               --arg ts "$(date -Iseconds)" \
               '.facts += [{"id": $id, "content": $content, "category": $cat, "timestamp": $ts, "source": "auto-extract"}]' \
               "$SEMANTIC_FILE" > "${SEMANTIC_FILE}.tmp" && mv "${SEMANTIC_FILE}.tmp" "$SEMANTIC_FILE"
            FACTS_ADDED=$((FACTS_ADDED + 1))
        fi
    done < <(echo "$GIT_DIFF" | grep -A100 '"dependencies"' 2>/dev/null | grep -E '^\+"' | head -20 || true)

    # 5. Extract new shell functions (bash)
    while IFS= read -r func; do
        [[ -z "$func" ]] && continue
        FUNC_NAME=$(echo "$func" | sed 's/^+//; s/().*//; s/ *$//')
        [[ -z "$FUNC_NAME" ]] && continue

        EXISTS=$(jq -r --arg f "Added bash function: $FUNC_NAME" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")
        if [[ -z "$EXISTS" ]]; then
            FACT_ID="sem-$(date +%s)-$RANDOM"
            jq --arg id "$FACT_ID" \
               --arg content "Added bash function: $FUNC_NAME" \
               --arg cat "code_structure" \
               --arg ts "$(date -Iseconds)" \
               '.facts += [{"id": $id, "content": $content, "category": $cat, "timestamp": $ts, "source": "auto-extract"}]' \
               "$SEMANTIC_FILE" > "${SEMANTIC_FILE}.tmp" && mv "${SEMANTIC_FILE}.tmp" "$SEMANTIC_FILE"
            FACTS_ADDED=$((FACTS_ADDED + 1))
        fi
    done < <(echo "$GIT_DIFF" | grep -E '^\+[a-zA-Z_][a-zA-Z0-9_]*\(\)' 2>/dev/null || true)

    echo "[$(date -Iseconds)] Semantic extraction complete: $FACTS_ADDED facts added"

} >> "${LOG_DIR}/semantic-extract-$(date +%Y%m%d).log" 2>&1 &

# Return immediately (don't block session exit)
echo '{"decision": "approve", "suppressOutput": true}'
