#!/bin/bash
# Procedural Memory Injection (v2.49.0)
# Hook: PreToolUse (Task)
# Purpose: Inject relevant procedural rules into subagent context
#
# Reads ~/.ralph/procedural/rules.json and injects matching rules
# based on task description and tags.
#
# VERSION: 2.57.3
# v2.57.2: Fixed JSON newline escaping (SEC-032)
# SECURITY: Added ERR trap for guaranteed JSON output

set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Parse input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Config check
CONFIG_FILE="$HOME/.ralph/config/memory-config.json"
PROCEDURAL_FILE="$HOME/.ralph/procedural/rules.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if procedural injection is enabled
INJECT_ENABLED=$(jq -r '.procedural.inject_to_prompts // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
MIN_CONFIDENCE=$(jq -r '.procedural.min_confidence // 0.7' "$CONFIG_FILE" 2>/dev/null || echo "0.7")

if [[ "$INJECT_ENABLED" != "true" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if rules file exists
if [[ ! -f "$PROCEDURAL_FILE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Get task description from tool input
# SEC-007: Sanitize extracted JSON fields to prevent prompt injection
TASK_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null | tr -d '\000-\037' | cut -c1-500 || echo "")
TASK_DESCRIPTION=$(echo "$INPUT" | jq -r '.tool_input.description // ""' 2>/dev/null | tr -d '\000-\037' | cut -c1-200 || echo "")
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null | tr -d '\000-\037' | cut -c1-50 || echo "")

# Combine for matching (sanitized inputs only)
TASK_TEXT="$TASK_PROMPT $TASK_DESCRIPTION $SUBAGENT_TYPE"
TASK_LOWER=$(printf '%s' "$TASK_TEXT" | tr '[:upper:]' '[:lower:]')

# Skip if no task text
if [[ -z "${TASK_LOWER// }" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Load rules
RULES=$(jq -r '.rules // []' "$PROCEDURAL_FILE" 2>/dev/null || echo "[]")
RULE_COUNT=$(echo "$RULES" | jq 'length' 2>/dev/null || echo "0")

if [[ "$RULE_COUNT" -eq 0 ]]; then
    echo '{"continue": true}'
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
    echo '{"continue": true}'
    exit 0
fi

# Log the injection
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
{
    echo "[$(date -Iseconds)] Procedural injection for task: ${TASK_DESCRIPTION:0:50}..."
    echo "  Matched $MATCH_COUNT rules"
} >> "$LOG_DIR/procedural-inject-$(date +%Y%m%d).log" 2>/dev/null || true

# SEC-032: Build context string with explicit \n for JSON compatibility
# The MATCHING_RULES already contains \n sequences from the loop
CONTEXT_HEADER="[Procedural Memory - Learned Behaviors]\n\nBased on patterns from past sessions, apply these behaviors:\n\n"
CONTEXT_FOOTER="\n\nThese rules have been learned from successful (and failed) past work."

# Combine all parts (keeping \n as literal backslash-n, not newlines)
FULL_CONTEXT="${CONTEXT_HEADER}${MATCHING_RULES}${CONTEXT_FOOTER}"

# Use jq for safe JSON construction - jq will properly escape the \n sequences
# Note: Using --rawfile or direct string keeps \n as literal characters
# SEC-039: PreToolUse hooks MUST use {"continue": true}, NOT {"decision": "continue"}
jq -n --arg rules "$FULL_CONTEXT" \
    --argjson rules_matched "$MATCH_COUNT" \
    --arg ts "$(date -Iseconds)" \
    '{
        continue: true,
        additionalContext: $rules,
        procedural_injection: {
            rules_matched: $rules_matched,
            timestamp: $ts
        }
    }'
