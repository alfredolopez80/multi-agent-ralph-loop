#!/bin/bash
# Episodic to Procedural Auto-Converter Hook (v2.57.5)
# Hook: PostToolUse (Edit/Write) - Runs after significant changes
# Purpose: Automatically convert new episodic memory entries to procedural rules
#
# This hook ensures continuous learning by:
# 1. Checking for new episodes after Edit/Write operations
# 2. Converting them to procedural rules
# 3. Updating ~/.ralph/procedural/rules.json automatically
#
# VERSION: 2.68.2
# CRITICAL: Closes GAP-001 - Automatic episodic→procedural conversion

set -euo pipefail
umask 077

# Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Configuration
EPISODES_DIR="$HOME/.ralph/episodes"
PROCEDURAL_FILE="$HOME/.ralph/procedural/rules.json"
PROCESSED_DIR="$HOME/.ralph/episodes/.processed"
SCRIPT_DIR="$HOME/.ralph/scripts"
LOG_FILE="$HOME/.ralph/logs/episodic-auto-convert.log"
BATCH_SIZE=20
MIN_CONFIDENCE=0.7

# Logging
log() {
    echo "[$(date -Iseconds)] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Process a single episode file
process_episode() {
    local episode_file="$1"
    local episode_id
    episode_id=$(basename "$episode_file" .json)

    # Skip if already processed
    if [[ -f "$PROCESSED_DIR/$episode_id" ]]; then
        return 1
    fi

    # Skip non-JSON files
    if [[ ! "$episode_file" =~ \.json$ ]]; then
        return 1
    fi

    # Read episode content
    local content
    content=$(cat "$episode_file" 2>/dev/null || echo "{}")

    # Check if it's a decision-type episode
    local episode_type
    episode_type=$(echo "$content" | jq -r '.type // ""' 2>/dev/null || echo "")

    if [[ "$episode_type" != "decision" ]]; then
        touch "$PROCESSED_DIR/$episode_id"
        return 1
    fi

    # Extract patterns and decisions
    local patterns_str
    local decisions_str
    local source
    local file_path

    patterns_str=$(echo "$content" | jq -r '.patterns // [] | join(", ")' 2>/dev/null || echo "")
    decisions_str=$(echo "$content" | jq -r '.architectural_decisions // [] | join(". ")' 2>/dev/null || echo "")
    source=$(echo "$content" | jq -r '.source // "auto-extract"' 2>/dev/null || echo "auto-extract")
    file_path=$(echo "$content" | jq -r '.file // ""' 2>/dev/null || echo "")

    if [[ -z "$patterns_str" && -z "$decisions_str" ]]; then
        touch "$PROCESSED_DIR/$episode_id"
        return 1
    fi

    # Generate rule ID
    local rule_id
    rule_id="ep-auto-$(echo "$episode_id" | cut -d'-' -f2-)"

    # Build trigger from patterns
    local trigger
    if [[ -n "$patterns_str" ]]; then
        trigger=$(echo "$patterns_str" | tr ',' '\n' | head -3 | tr '\n' ' ' | sed 's/  */ /g' | sed 's/ $//')
    else
        trigger="Pattern from $file_path"
    fi

    # Build behavior from decisions
    local behavior
    behavior=$(echo "$decisions_str" | sed 's/\. /\. /g' | head -5)
    [[ -z "$behavior" ]] && behavior="Pattern: $patterns_str"

    # Output rule JSON
    jq -n \
        --arg rule_id "$rule_id" \
        --arg trigger "$trigger" \
        --arg behavior "$behavior" \
        --arg source "$source" \
        --arg file_path "$file_path" \
        --arg episode_id "$episode_id" \
        '{
            rule_id: $rule_id,
            trigger: $trigger,
            behavior: $behavior,
            confidence: 0.75,
            source_repo: $source,
            source_episodes: [$episode_id],
            created_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
            tags: ["auto-extract", "episodic", "auto-convert"],
            severity: "medium"
        }'

    return 0
}

# Main auto-conversion logic
auto_convert() {
    local input="$1"
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

    # Only run after Edit/Write operations
    if [[ "$tool_name" != "Edit" ]] && [[ "$tool_name" != "Write" ]]; then
        echo '{"continue": true}'
        exit 0
    fi

    # Initialize directories
    mkdir -p "$PROCESSED_DIR"
    mkdir -p "$SCRIPT_DIR"

    # Check if episodes exist
    local episode_count
    episode_count=$(find "$EPISODES_DIR" -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
    local processed_count
    processed_count=$(find "$PROCESSED_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')

    if [[ $episode_count -eq 0 ]]; then
        echo '{"continue": true}'
        exit 0
    fi

    # Find unprocessed episodes
    local temp_rules_file
    temp_rules_file=$(mktemp)
    local new_rules=0

    while IFS= read -r episode_file; do
        [[ -z "$episode_file" ]] && continue

        local episode_id
        episode_id=$(basename "$episode_file" .json)
        if [[ -f "$PROCESSED_DIR/$episode_id" ]]; then
            continue
        fi

        if process_episode "$episode_file" >> "$temp_rules_file"; then
            ((new_rules++))
            touch "$PROCESSED_DIR/$episode_id"
        fi

        [[ $new_rules -ge $BATCH_SIZE ]] && break
    done < <(find "$EPISODES_DIR" -name "*.json" 2>/dev/null | sort)

    if [[ $new_rules -eq 0 ]]; then
        rm -f "$temp_rules_file"
        echo '{"continue": true}'
        exit 0
    fi

    log "Auto-converted $new_rules episodes to procedural rules"

    # Read existing rules
    local existing_rules="[]"
    if [[ -f "$PROCEDURAL_FILE" ]]; then
        existing_rules=$(jq -r '.rules // []' "$PROCEDURAL_FILE" 2>/dev/null || echo "[]")
    fi

    # Combine rules
    local new_rules_json
    new_rules_json=$(cat "$temp_rules_file" | jq -s '.' 2>/dev/null || echo "[]")

    local combined_rules
    combined_rules=$(jq -n --argjson existing "$existing_rules" --argjson new "$new_rules_json" '$existing + $new | unique_by(.rule_id) | sort_by(.confidence | tonumber) | reverse' 2>/dev/null) || \
        combined_rules="$existing_rules"

    rm -f "$temp_rules_file"

    # Update procedural file
    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.000000+00:00")

    cat > "$PROCEDURAL_FILE" << EOF
{
  "version": "2.57.5",
  "updated": "$timestamp",
  "rules": $combined_rules,
  "curator_metadata": {
    "enabled": true,
    "default_confidence_threshold": 0.7,
    "source_attribution_field": "source_repo",
    "supported_sources": ["claude-mem", "curator", "manual", "auto-extract"]
  }
}
EOF

    local total_rules
    total_rules=$(echo "$combined_rules" | jq 'length' 2>/dev/null || echo "0")

    log "Procedural rules updated: $new_rules new, $total_rules total"

    # SEC-039: PostToolUse hooks MUST use {"continue": true}, NOT {"decision": "continue"}
    jq -n \
        --argjson new_rules "$new_rules" \
        --argjson total_rules "$total_rules" \
        --arg ts "$(date -Iseconds)" \
        '{
            continue: true,
            auto_learning: {
                episodes_converted: $new_rules,
                total_rules: $total_rules,
                timestamp: $ts
            }
        }'
}

# Read input and run
INPUT=$(cat)
auto_convert "$INPUT"
