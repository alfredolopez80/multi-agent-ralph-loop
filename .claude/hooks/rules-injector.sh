#!/bin/bash
# Rules Injector Hook v2.88.0
# Hook: PreToolUse (Task)
# Purpose: Converts auto-extracted rules into effective Claude Code context
#
# AUTOMATIC RULE CONVERSION:
# - Reads procedural rules by domain
# - Converts to Claude-friendly markdown format
# - Injects as context into Task prompts
#
# This replaces trigger-based matching with direct context injection
# allowing Claude to decide which rules are relevant.
#
# VERSION: 2.88.0

set -euo pipefail

# SEC-111: Read input from stdin with length limit
INPUT=$(head -c 100000)

# Configuration
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
CONTEXT_CACHE="${HOME}/.ralph/cache/rules-context"
LOG_DIR="${HOME}/.ralph/logs"

mkdir -p "$LOG_DIR" "$(dirname "$CONTEXT_CACHE")"

# Parse input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
    exit 0
fi

# Get prompt and detect domain
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Detect domain from prompt keywords
detect_domain() {
    local text="$1"
    if echo "$text" | grep -qE 'api|server|backend|rest|graphql|endpoint'; then
        echo "backend"
    elif echo "$text" | grep -qE 'react|vue|frontend|component|css|ui'; then
        echo "frontend"
    elif echo "$text" | grep -qE 'sql|database|query|migration|schema|prisma'; then
        echo "database"
    elif echo "$text" | grep -qE 'auth|security|jwt|token|encrypt|password'; then
        echo "security"
    elif echo "$text" | grep -qE 'test|spec|jest|vitest|coverage|mock'; then
        echo "testing"
    elif echo "$text" | grep -qE 'docker|deploy|kubernetes|ci|cd|pipeline'; then
        echo "devops"
    elif echo "$text" | grep -qE 'hook|lifecycle|callback|trigger|event'; then
        echo "hooks"
    else
        echo "general"
    fi
}

DOMAIN=$(detect_domain "$PROMPT_LOWER")

# Build rules context from procedural memory
build_rules_context() {
    local domain="$1"
    local context=""
    local rules_count=0
    local max_rules=10

    if [[ ! -f "$RULES_FILE" ]]; then
        echo ""
        return
    fi

    # Get rules for this domain, sorted by usage_count
    local rules=$(jq -r --arg domain "$domain" '
        [.rules[] | select(.domain == $domain or .domain == "general")] |
        sort_by(-(.usage_count // 0)) |
        .[:20] |
        .[]
    ' "$RULES_FILE" 2>/dev/null || echo "")

    if [[ -z "$rules" ]]; then
        echo ""
        return
    fi

    context+="# Learned Patterns ($domain)\n\n"
    context+="Context from procedural memory. Use these patterns as guidance:\n\n"

    while IFS= read -r rule; do
        [[ -z "$rule" ]] && continue
        [[ $rules_count -ge $max_rules ]] && break

        local behavior=$(echo "$rule" | jq -r '.behavior // ""' 2>/dev/null || echo "")
        local trigger=$(echo "$rule" | jq -r '.trigger // ""' 2>/dev/null || echo "")
        local usage=$(echo "$rule" | jq -r '.usage_count // 0' 2>/dev/null || echo "0")
        local confidence=$(echo "$rule" | jq -r '.confidence // 0' 2>/dev/null || echo "0")

        if [[ -n "$behavior" && "$behavior" != "null" ]]; then
            context+="**Pattern** (used $usage times, ${confidence} confidence):\n"
            context+="- $behavior\n"
            if [[ -n "$trigger" && "$trigger" != "null" ]]; then
                context+="  - Source: ${trigger:0:80}...\n"
            fi
            context+="\n"
            rules_count=$((rules_count + 1))
        fi
    done <<< "$rules"

    if [[ $rules_count -eq 0 ]]; then
        echo ""
        return
    fi

    context+="---\n*Auto-injected from procedural memory*\n"
    echo -e "$context"
}

# Build context
RULES_CONTEXT=$(build_rules_context "$DOMAIN")

# If no context or empty, allow without modification
if [[ -z "$RULES_CONTEXT" ]]; then
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
    exit 0
fi

# Inject context into prompt
MODIFIED_PROMPT="${RULES_CONTEXT}\n\n---\n\n${PROMPT}"

# Log injection
{
    echo "[$(date -Iseconds)] Rules injection for domain: $DOMAIN"
    echo "  Prompt length before: ${#PROMPT}"
    echo "  Prompt length after: ${#MODIFIED_PROMPT}"
} >> "${LOG_DIR}/rules-injector-$(date +%Y%m%d).log" 2>&1

# Output modified prompt
NEW_TOOL_INPUT=$(echo "$INPUT" | jq --arg new_prompt "$MODIFIED_PROMPT" '.tool_input + {prompt: $new_prompt}' 2>/dev/null)

if [[ -n "$NEW_TOOL_INPUT" ]] && [[ "$NEW_TOOL_INPUT" != "null" ]]; then
    jq -n --argjson tool_input "$NEW_TOOL_INPUT" '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": $tool_input}}'
else
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
fi
