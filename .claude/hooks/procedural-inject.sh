#!/bin/bash
# Procedural Memory Injection (v2.49.0)
# Hook: PreToolUse (Task)
# Purpose: Inject relevant procedural rules into subagent context
#
# Reads ~/.ralph/procedural/rules.json and injects matching rules
# based on task description and tags.
#
# VERSION: 2.49.1
# SECURITY: Added ERR trap for guaranteed JSON output

set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
output_json() {
    echo '{"decision": "continue"}'
}
trap 'output_json' ERR

# Parse input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Config check
CONFIG_FILE="$HOME/.ralph/config/memory-config.json"
PROCEDURAL_FILE="$HOME/.ralph/procedural/rules.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Check if procedural injection is enabled
INJECT_ENABLED=$(jq -r '.procedural.inject_to_prompts // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
MIN_CONFIDENCE=$(jq -r '.procedural.min_confidence // 0.7' "$CONFIG_FILE" 2>/dev/null || echo "0.7")

if [[ "$INJECT_ENABLED" != "true" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Check if rules file exists
if [[ ! -f "$PROCEDURAL_FILE" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Get task description from tool input
TASK_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")
TASK_DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null || echo "")
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null || echo "")

# Combine for matching
TASK_TEXT="$TASK_PROMPT $TASK_DESCRIPTION $SUBAGENT_TYPE"
TASK_LOWER=$(echo "$TASK_TEXT" | tr '[:upper:]' '[:lower:]')

# Skip if no task text
if [[ -z "${TASK_LOWER// }" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Load rules
RULES=$(jq -r '.rules // []' "$PROCEDURAL_FILE" 2>/dev/null || echo "[]")
RULE_COUNT=$(echo "$RULES" | jq 'length' 2>/dev/null || echo "0")

if [[ "$RULE_COUNT" -eq 0 ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Find matching rules
MATCHING_RULES=""
MATCH_COUNT=0

while IFS= read -r rule; do
    [[ -z "$rule" ]] && continue

    CONFIDENCE=$(echo "$rule" | jq -r '.confidence // 0' 2>/dev/null || echo "0")
    TRIGGER=$(echo "$rule" | jq -r '.trigger // ""' 2>/dev/null || echo "")
    BEHAVIOR=$(echo "$rule" | jq -r '.behavior // ""' 2>/dev/null || echo "")

    # Check confidence threshold
    if (( $(echo "$CONFIDENCE < $MIN_CONFIDENCE" | bc -l 2>/dev/null || echo "1") )); then
        continue
    fi

    # Check trigger match (simple word matching)
    TRIGGER_LOWER=$(echo "$TRIGGER" | tr '[:upper:]' '[:lower:]')

    # Extract keywords from trigger
    TRIGGER_WORDS=$(echo "$TRIGGER_LOWER" | tr -cs '[:alpha:]' '\n' | sort -u)

    MATCHED=false
    for word in $TRIGGER_WORDS; do
        [[ ${#word} -lt 3 ]] && continue  # Skip short words
        if [[ "$TASK_LOWER" == *"$word"* ]]; then
            MATCHED=true
            break
        fi
    done

    if [[ "$MATCHED" == "true" ]]; then
        MATCH_COUNT=$((MATCH_COUNT + 1))
        if [[ -n "$MATCHING_RULES" ]]; then
            MATCHING_RULES="$MATCHING_RULES\n- $BEHAVIOR"
        else
            MATCHING_RULES="- $BEHAVIOR"
        fi
    fi

    # Limit to 5 rules max
    [[ $MATCH_COUNT -ge 5 ]] && break

done < <(echo "$RULES" | jq -c '.[]' 2>/dev/null)

# If no matches, continue without injection
if [[ -z "$MATCHING_RULES" ]]; then
    echo '{"decision": "continue"}'
    exit 0
fi

# Log the injection
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
{
    echo "[$(date -Iseconds)] Procedural injection for task: ${TASK_DESCRIPTION:0:50}..."
    echo "  Matched $MATCH_COUNT rules"
} >> "$LOG_DIR/procedural-inject-$(date +%Y%m%d).log" 2>/dev/null || true

# Prepare context injection
CONTEXT="[Procedural Memory - Learned Behaviors]

Based on patterns from past sessions, apply these behaviors:

$(echo -e "$MATCHING_RULES")

These rules have been learned from successful (and failed) past work."

# Escape for JSON
CONTEXT_ESCAPED=$(echo "$CONTEXT" | jq -R -s '.')

echo "{
    \"decision\": \"continue\",
    \"additionalContext\": $CONTEXT_ESCAPED,
    \"procedural_injection\": {
        \"rules_matched\": $MATCH_COUNT,
        \"timestamp\": \"$(date -Iseconds)\"
    }
}"
