#!/bin/bash
# Decision Extractor Hook (v2.57.0)
# Hook: PostToolUse (Edit|Write)
# Purpose: Extract architectural decisions from code changes
#
# Monitors code changes and extracts:
# - Architectural decisions (new patterns, structures)
# - Dependency choices
# - Configuration decisions
# - Design patterns used
#
# v2.57.0: Also writes to SEMANTIC memory (not just episodic)
# Fixes Issue #7 - ensures patterns are persisted for future reference
#
# VERSION: 2.57.5
# SECURITY: SEC-006 compliant

set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
# PostToolUse hooks use {"continue": true, ...}
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Parse input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Edit and Write tools
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Extract file path
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo "")

# Skip if no file path
if [[ -z "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Get file extension and name
FILE_NAME=$(basename "$FILE_PATH")
FILE_EXT="${FILE_NAME##*.}"

# Only process source code files
case "$FILE_EXT" in
    py|js|ts|tsx|jsx|go|rs|java|kt|rb|sh|bash|yaml|yml|json|toml)
        ;;
    *)
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Config check
CONFIG_FILE="${HOME}/.ralph/config/memory-config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    EXTRACT_ENABLED=$(jq -r '.episodic.extract_decisions // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
    if [[ "$EXTRACT_ENABLED" != "true" ]]; then
        echo '{"continue": true}'
        exit 0
    fi
fi

# Paths
EPISODES_DIR="${HOME}/.ralph/episodes"
SEMANTIC_FILE="${HOME}/.ralph/memory/semantic.json"
LOG_DIR="${HOME}/.ralph/logs"
mkdir -p "$EPISODES_DIR" "$LOG_DIR" "${HOME}/.ralph/memory"

# Initialize semantic.json if missing (v2.57.0)
if [[ ! -f "$SEMANTIC_FILE" ]]; then
    echo '{"facts": [], "version": "2.57.0"}' > "$SEMANTIC_FILE"
fi

# Get the content that was written/edited
CONTENT=""
if [[ "$TOOL_NAME" == "Write" ]]; then
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null || echo "")
else
    # For Edit, get the new_string
    CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")
fi

# Skip if no content
if [[ -z "$CONTENT" ]] || [[ ${#CONTENT} -lt 50 ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Run extraction in background (non-blocking)
{
    echo "[$(date -Iseconds)] Decision extraction for: $FILE_PATH"

    DECISIONS_FOUND=0
    EPISODE_CONTENT=""

    # Detect architectural patterns
    CONTENT_LOWER=$(echo "$CONTENT" | tr '[:upper:]' '[:lower:]')

    # 1. Design Patterns
    PATTERNS=()
    echo "$CONTENT_LOWER" | grep -qE 'singleton|instance.*=.*null|_instance' && PATTERNS+=("Singleton pattern detected")
    echo "$CONTENT_LOWER" | grep -qE 'factory|create.*instance|build.*object' && PATTERNS+=("Factory pattern detected")
    echo "$CONTENT_LOWER" | grep -qE 'observer|subscribe|publish|emit|event.*listener' && PATTERNS+=("Observer pattern detected")
    echo "$CONTENT_LOWER" | grep -qE 'strategy|interface.*execute|algorithm' && PATTERNS+=("Strategy pattern detected")
    echo "$CONTENT_LOWER" | grep -qE 'decorator|@.*\(|wrapper' && PATTERNS+=("Decorator pattern detected")
    echo "$CONTENT_LOWER" | grep -qE 'adapter|convert|transform|map.*to' && PATTERNS+=("Adapter pattern detected")
    echo "$CONTENT_LOWER" | grep -qE 'repository|.*repository|data.*access' && PATTERNS+=("Repository pattern detected")
    echo "$CONTENT_LOWER" | grep -qE 'middleware|next\(\)|chain' && PATTERNS+=("Middleware pattern detected")

    # 2. Architectural Decisions
    ARCH_DECISIONS=()
    echo "$CONTENT_LOWER" | grep -qE 'async|await|promise|future' && ARCH_DECISIONS+=("Uses async/await for asynchronous operations")
    echo "$CONTENT_LOWER" | grep -qE 'try.*catch|except|error.*handling' && ARCH_DECISIONS+=("Implements error handling")
    echo "$CONTENT_LOWER" | grep -qE 'cache|redis|memcache|lru' && ARCH_DECISIONS+=("Implements caching strategy")
    echo "$CONTENT_LOWER" | grep -qE 'rate.*limit|throttle|debounce' && ARCH_DECISIONS+=("Implements rate limiting")
    echo "$CONTENT_LOWER" | grep -qE 'retry|backoff|resilience' && ARCH_DECISIONS+=("Implements retry/resilience pattern")
    echo "$CONTENT_LOWER" | grep -qE 'validate|schema|zod|joi|pydantic' && ARCH_DECISIONS+=("Uses schema validation")
    echo "$CONTENT_LOWER" | grep -qE 'log|logger|logging|winston|pino' && ARCH_DECISIONS+=("Implements structured logging")
    echo "$CONTENT_LOWER" | grep -qE 'metric|prometheus|statsd|telemetry' && ARCH_DECISIONS+=("Implements metrics/observability")

    # 3. Configuration Files
    if [[ "$FILE_NAME" == "package.json" ]] || [[ "$FILE_NAME" == "pyproject.toml" ]] || [[ "$FILE_NAME" == "Cargo.toml" ]]; then
        ARCH_DECISIONS+=("Project configuration updated: $FILE_NAME")
    fi

    if [[ "$FILE_NAME" == "docker-compose.yml" ]] || [[ "$FILE_NAME" == "Dockerfile" ]]; then
        ARCH_DECISIONS+=("Container configuration updated: $FILE_NAME")
    fi

    if [[ "$FILE_NAME" == ".env" ]] || [[ "$FILE_NAME" == "config.yaml" ]] || [[ "$FILE_NAME" == "settings.py" ]]; then
        ARCH_DECISIONS+=("Application configuration updated: $FILE_NAME")
    fi

    # Build episode if decisions found
    TOTAL_DECISIONS=$((${#PATTERNS[@]} + ${#ARCH_DECISIONS[@]}))

    if [[ $TOTAL_DECISIONS -gt 0 ]]; then
        EPISODE_ID="ep-$(date +%s)-$RANDOM"
        TIMESTAMP=$(date -Iseconds)

        # Create episode file
        EPISODE_FILE="${EPISODES_DIR}/${EPISODE_ID}.json"

        cat > "$EPISODE_FILE" << EPISODEJSON
{
  "id": "$EPISODE_ID",
  "timestamp": "$TIMESTAMP",
  "type": "decision",
  "source": "auto-extract",
  "file": "$FILE_PATH",
  "patterns": $(printf '%s\n' "${PATTERNS[@]:-}" | jq -R . | jq -s .),
  "architectural_decisions": $(printf '%s\n' "${ARCH_DECISIONS[@]:-}" | jq -R . | jq -s .),
  "ttl_days": 30
}
EPISODEJSON

        # Update index
        INDEX_FILE="${EPISODES_DIR}/index.json"
        if [[ ! -f "$INDEX_FILE" ]]; then
            echo '{}' > "$INDEX_FILE"
        fi

        jq --arg id "$EPISODE_ID" \
           --arg ts "$TIMESTAMP" \
           --arg file "$FILE_PATH" \
           '. + {($id): {"timestamp": $ts, "file": $file, "type": "decision"}}' \
           "$INDEX_FILE" > "${INDEX_FILE}.tmp" && mv "${INDEX_FILE}.tmp" "$INDEX_FILE"

        echo "[$(date -Iseconds)] Created episode: $EPISODE_ID with $TOTAL_DECISIONS decisions"

        # v2.57.0: Also write patterns and decisions to semantic memory
        SEMANTIC_ADDED=0

        # Helper function to add semantic fact
        add_semantic_fact() {
            local content="$1"
            local category="$2"

            # Check if fact already exists
            local EXISTS
            EXISTS=$(jq -r --arg f "$content" '.facts[] | select(.content == $f) | .id' "$SEMANTIC_FILE" 2>/dev/null || echo "")
            if [[ -z "$EXISTS" ]]; then
                local FACT_ID="sem-$(date +%s)-$RANDOM"
                jq --arg id "$FACT_ID" \
                   --arg content "$content" \
                   --arg cat "$category" \
                   --arg ts "$TIMESTAMP" \
                   --arg file "$FILE_PATH" \
                   '.facts += [{"id": $id, "content": $content, "category": $cat, "timestamp": $ts, "source": "decision-extract", "file": $file}]' \
                   "$SEMANTIC_FILE" > "${SEMANTIC_FILE}.tmp" && mv "${SEMANTIC_FILE}.tmp" "$SEMANTIC_FILE"
                SEMANTIC_ADDED=$((SEMANTIC_ADDED + 1))
            fi
        }

        # Add design patterns to semantic memory
        for pattern in "${PATTERNS[@]:-}"; do
            [[ -z "$pattern" ]] && continue
            add_semantic_fact "$pattern" "design_patterns"
        done

        # Add architectural decisions to semantic memory
        for decision in "${ARCH_DECISIONS[@]:-}"; do
            [[ -z "$decision" ]] && continue
            add_semantic_fact "$decision" "architectural_decisions"
        done

        echo "[$(date -Iseconds)] Also added $SEMANTIC_ADDED facts to semantic memory"
    else
        echo "[$(date -Iseconds)] No architectural decisions detected"
    fi

} >> "${LOG_DIR}/decision-extract-$(date +%Y%m%d).log" 2>&1 &

# Continue tool execution
echo '{"continue": true}'
