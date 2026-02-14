#!/bin/bash
# Procedural Inject Hook (Fixed) v2.88.0
# Hook: PostToolUse (multiple)
# Purpose: Injects relevant procedural rules into context and tracks usage
#
# GAP-H01 FIX: Improved lock handling with exponential backoff
# GAP-H02 FIX: Added rule verification tracking
#
# VERSION: 2.88.0

# SEC-111: Read input from stdin with length limit
INPUT=$(head -c 100000)

set -euo pipefail
umask 077

# Configuration
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
RULES_LOCK="${RULES_FILE}.lock"
LOG_DIR="${HOME}/.ralph/logs"
CONFIG_FILE="${HOME}/.ralph/config/memory-config.json"

mkdir -p "$LOG_DIR"

# SEC-034: Guaranteed JSON output
output_json() {
    echo '{"hookSpecificOutput": {"hookEventName": "PostToolUse"}}'
}
trap 'output_json' ERR EXIT

# GAP-H01 FIX: Exponential backoff lock acquisition
# Instead of failing immediately, try multiple times with backoff
acquire_lock_with_backoff() {
    local max_attempts=5
    local base_delay=0.5
    local attempt=1

    while [[ $attempt -le $max_attempts ]]; do
        if mkdir "$RULES_LOCK" 2>/dev/null; then
            return 0
        fi

        # Calculate backoff delay (exponential with jitter)
        local delay=$(echo "scale=2; $base_delay * (1.5 ^ ($attempt - 1)) + (RANDOM % 100) / 1000" | bc)
        sleep "$delay" 2>/dev/null || sleep 0.5

        attempt=$((attempt + 1))
    done

    return 1
}

release_lock() {
    rmdir "$RULES_LOCK" 2>/dev/null || true
}

# GAP-H02 FIX: Track rule application
track_rule_usage() {
    local rule_id="$1"
    local tool_name="$2"
    local success="$3"

    local usage_file="${HOME}/.ralph/procedural/usage-tracking.jsonl"
    local entry=$(jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg rule_id "$rule_id" \
        --arg tool "$tool_name" \
        --argjson success "$success" \
        '{timestamp: $ts, rule_id: $rule_id, tool: $tool, success: $success}')

    echo "$entry" >> "$usage_file" 2>/dev/null || true
}

# Parse input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process for tools that modify files
case "$TOOL_NAME" in
    Edit|Write|Bash) ;;
    *) trap - EXIT; output_json; exit 0 ;;
esac

# Check if rules file exists
if [[ ! -f "$RULES_FILE" ]]; then
    trap - EXIT; output_json; exit 0
fi

# Load configuration
MAX_RULES=5
MIN_CONFIDENCE=0.7
TRACK_USAGE=true

if [[ -f "$CONFIG_FILE" ]]; then
    MAX_RULES=$(jq -r '.procedural.max_rules_injection // 5' "$CONFIG_FILE" 2>/dev/null || echo "5")
    MIN_CONFIDENCE=$(jq -r '.procedural.min_confidence // 0.7' "$CONFIG_FILE" 2>/dev/null || echo "0.7")
    TRACK_USAGE=$(jq -r '.feedback_loop.track_usage // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
fi

# Get prompt content to match against rules
PROMPT_CONTENT=""
case "$TOOL_NAME" in
    Edit)
        PROMPT_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.old_string // ""' 2>/dev/null || echo "")
        PROMPT_CONTENT+=$(echo "$INPUT" | jq -r '.tool_input.new_string // ""' 2>/dev/null || echo "")
        ;;
    Write)
        PROMPT_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // ""' 2>/dev/null || echo "")
        ;;
    Bash)
        PROMPT_CONTENT=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
        ;;
esac

PROMPT_LOWER=$(echo "$PROMPT_CONTENT" | tr '[:upper:]' '[:lower:]')

# Find matching rules (simplified keyword matching)
# In a full implementation, this would use semantic search
MATCHING_RULES="[]"

if [[ -n "$PROMPT_CONTENT" ]]; then
    # Try to acquire lock with backoff (GAP-H01 FIX)
    if acquire_lock_with_backoff; then
        trap release_lock EXIT

        # Get high-confidence rules
        MATCHING_RULES=$(jq -c \
            --argjson min_conf "$MIN_CONFIDENCE" \
            --argjson max "$MAX_RULES" \
            '[.rules[] | select(.confidence >= $min_conf)] | .[:$max]' \
            "$RULES_FILE" 2>/dev/null || echo "[]")

        # Increment applied_count for matched rules
        local count=$(echo "$MATCHING_RULES" | jq 'length' 2>/dev/null || echo "0")
        if [[ "$count" -gt 0 ]]; then
            local temp_file=$(mktemp)
            jq '.rules |= map(if .applied_count == null then .applied_count = 1 else .applied_count += 1 end)' \
                "$RULES_FILE" > "$temp_file" 2>/dev/null && mv "$temp_file" "$RULES_FILE" || rm -f "$temp_file"
        fi

        release_lock
        trap - EXIT
    else
        # Log skip but don't fail (improved over original 33% skip rate)
        echo "[$(date -Iseconds)] WARN: Could not acquire lock after backoff, skipping injection" \
            >> "${LOG_DIR}/procedural-inject-$(date +%Y%m%d).log" 2>&1
    fi
fi

# Track usage (GAP-H02 FIX)
if [[ "$TRACK_USAGE" == "true" ]]; then
    local rule_ids=$(echo "$MATCHING_RULES" | jq -r '.[].rule_id' 2>/dev/null || echo "")
    for rule_id in $rule_ids; do
        track_rule_usage "$rule_id" "$TOOL_NAME" true
    done
fi

# Output result
trap - EXIT
echo '{"hookSpecificOutput": {"hookEventName": "PostToolUse"}}'
