#!/bin/bash
# Orchestrator Auto-Learn Hook (v2.60.0)
# Hook: PreToolUse (Task)
# Purpose: Proactively trigger learning when orchestrator faces complex tasks
#
# When orchestrator classifies a task as complexity >= 7 and procedural
# memory lacks relevant patterns, this hook:
# 1. Analyzes the task domain
# 2. Checks for relevant procedural rules
# 3. INJECTS learning recommendation into Task prompt
# 4. AUTO-EXECUTES learning if CRITICAL gap detected (v2.60.0)
#
# v2.60.1: FIXED - Search by domain FIRST, then category/trigger as fallback (GAP-C02 related)
# v2.60.0: ENHANCED - Auto-execute learning for CRITICAL gaps + event emission
# v2.59.2: FIXED - Single JSON output
# v2.57.0: Fixed to actually inject context
#
# VERSION: 2.69.0
# v2.68.25: FIX CRIT-001 - Removed duplicate stdin read (SEC-111 already reads at top)
# v2.68.11: Version sync with SEC-111 fixes
# v2.68.10: SEC-110 FIX - Redact sensitive data before logging (API keys, tokens)
# SECURITY: SEC-006 compliant
# v2.66.5: DUP-001 FIX - Use shared domain-classifier.sh library

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)

set -euo pipefail
umask 077

# DUP-001: Source shared domain classifier library
DOMAIN_CLASSIFIER="${HOME}/.ralph/lib/domain-classifier.sh"
if [[ -f "$DOMAIN_CLASSIFIER" ]]; then
    # shellcheck source=/dev/null
    source "$DOMAIN_CLASSIFIER"
fi

# SEC-034: Guaranteed JSON output on any error
output_json() {
    echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
}
trap 'output_json' ERR EXIT

# SEC-110: Redact sensitive data before logging
redact_sensitive() {
    local str="$1"
    # Redact common API key patterns
    str=$(echo "$str" | sed -E 's/(sk-|pk-|api_|key_|token_|secret_|password[=:_ ]*)[a-zA-Z0-9_-]{10,}/\1[REDACTED]/gi')
    # Redact long alphanumeric strings (potential tokens/keys - 32+ chars)
    str=$(echo "$str" | sed -E 's/[a-zA-Z0-9_-]{32,}/[REDACTED]/g')
    echo "$str"
}

# CRIT-001 FIX: Removed duplicate `INPUT=$(cat)` - stdin already consumed by SEC-111 read above
# Parse input (using INPUT from SEC-111 read at top)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    trap - EXIT; echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'; exit 0
fi

# Check if this is an orchestrator-related task
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || echo "")
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Check for orchestrator or planning context
if [[ "$SUBAGENT_TYPE" != "orchestrator" ]] && [[ "$SUBAGENT_TYPE" != "Plan" ]]; then
    if ! echo "$PROMPT_LOWER" | grep -qE 'implement|build|create|develop|design'; then
        trap - EXIT; echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'; exit 0
    fi
fi

# Paths
PLAN_STATE="${HOME}/.ralph/plan-state/plan-state.json"
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
CONTEXT_FILE="${HOME}/.ralph/state/auto-learn-context.md"
LOG_DIR="${HOME}/.ralph/logs"
CONFIG_DIR="${HOME}/.ralph/config"

mkdir -p "$LOG_DIR" "${HOME}/.ralph/state" "$(dirname "$PLAN_STATE")" "$CONFIG_DIR"

# v2.60.0: Create default memory-config.json if not exists
CONFIG_FILE="${CONFIG_DIR}/memory-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'CONFIGEOF'
{
  "procedural": {
    "inject_to_prompts": true,
    "min_confidence": 0.7,
    "max_rules_injection": 5
  },
  "auto_learn": {
    "enabled": true,
    "blocking": false,
    "severity_threshold": "CRITICAL",
    "domains": ["database", "security", "backend", "frontend", "devops"]
  },
  "feedback_loop": {
    "track_usage": true,
    "verify_rules": true,
    "prune_unused": true,
    "success_threshold": 0.2
  }
}
CONFIGEOF
    echo "[$(date -Iseconds)] Created default memory-config.json with auto_learn settings" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1
fi

# Check plan-state for complexity
COMPLEXITY=0
if [[ -f "$PLAN_STATE" ]]; then
    COMPLEXITY=$(jq -r '.classification.complexity // 0' "$PLAN_STATE" 2>/dev/null || echo "0")
fi

# Info-Density Detection
INFO_DENSITY="LINEAR"
PROMPT_LENGTH=${#PROMPT}
QUADRATIC_INDICATORS=0

echo "$PROMPT_LOWER" | grep -qE 'multiple|several|many|all the|every |comprehensive|exhaustive|end-to-end' && QUADRATIC_INDICATORS=$((QUADRATIC_INDICATORS + 1))
[[ $PROMPT_LENGTH -gt 2000 ]] && QUADRATIC_INDICATORS=$((QUADRATIC_INDICATORS + 1))
echo "$PROMPT_LOWER" | grep -qE 'and|also|plus|additionally' && QUADRATIC_INDICATORS=$((QUADRATIC_INDICATORS + 1))

if [[ $QUADRATIC_INDICATORS -ge 2 ]]; then
    INFO_DENSITY="QUADRATIC"
fi

# Estimate complexity from prompt if not in plan-state
if [[ "$COMPLEXITY" -eq 0 ]]; then
    INDICATORS=0
    echo "$PROMPT_LOWER" | grep -qE 'microservice|distributed|scalable|enterprise' && INDICATORS=$((INDICATORS + 2))
    echo "$PROMPT_LOWER" | grep -qE 'authentication|security|encryption' && INDICATORS=$((INDICATORS + 2))
    echo "$PROMPT_LOWER" | grep -qE 'database|migration|orm' && INDICATORS=$((INDICATORS + 1))
    echo "$PROMPT_LOWER" | grep -qE 'api|rest|graphql|grpc' && INDICATORS=$((INDICATORS + 1))
    echo "$PROMPT_LOWER" | grep -qE 'cache|redis|queue|event' && INDICATORS=$((INDICATORS + 1))
    echo "$PROMPT_LOWER" | grep -qE 'test|coverage|ci|cd' && INDICATORS=$((INDICATORS + 1))
    echo "$PROMPT_LOWER" | grep -qE 'complete|full|entire|whole' && INDICATORS=$((INDICATORS + 1))
    echo "$PROMPT_LOWER" | grep -qE 'from scratch|new project|greenfield' && INDICATORS=$((INDICATORS + 2))
    COMPLEXITY=$((5 + INDICATORS))
    [[ $COMPLEXITY -gt 10 ]] && COMPLEXITY=10
fi

# Detect task domain using shared library (DUP-001)
DOMAIN=""
DOMAIN_KEYWORDS=""

if type infer_domain_from_text &>/dev/null; then
    # Use shared library functions
    DOMAIN=$(infer_domain_from_text "$PROMPT")
    DOMAIN_KEYWORDS=$(get_domain_keywords "$DOMAIN")
else
    # Fallback if library not loaded (backward compatibility)
    if echo "$PROMPT_LOWER" | grep -qE 'backend|api|server|microservice|rest'; then
        DOMAIN="backend"
        DOMAIN_KEYWORDS="error_handling|async_patterns|api_design|validation"
    elif echo "$PROMPT_LOWER" | grep -qE 'frontend|react|vue|angular|ui|ux'; then
        DOMAIN="frontend"
        DOMAIN_KEYWORDS="component|state_management|rendering|hooks"
    elif echo "$PROMPT_LOWER" | grep -qE 'security|auth|encryption|vulnerability'; then
        DOMAIN="security"
        DOMAIN_KEYWORDS="authentication|authorization|encryption|input_validation"
    elif echo "$PROMPT_LOWER" | grep -qE 'database|sql|orm|migration|schema'; then
        DOMAIN="database"
        DOMAIN_KEYWORDS="query_optimization|migration|transaction|indexing"
    elif echo "$PROMPT_LOWER" | grep -qE 'devops|deploy|kubernetes|docker|ci'; then
        DOMAIN="devops"
        DOMAIN_KEYWORDS="containerization|orchestration|pipeline|monitoring"
    else
        DOMAIN="general"
        DOMAIN_KEYWORDS="architecture|testing|error_handling|patterns"
    fi
fi

# Check procedural memory for relevant rules
# v2.60.1: FIXED - Search by domain FIRST, then by category/trigger as fallback
RULES_COUNT=0
RELEVANT_COUNT=0
DOMAIN_MATCH_COUNT=0
KEYWORD_MATCH_COUNT=0

if [[ -f "$RULES_FILE" ]]; then
    RULES_COUNT=$(jq -r '.rules | length // 0' "$RULES_FILE" 2>/dev/null || echo "0")

    # v2.60.1: First count rules matching the detected domain
    if [[ "$DOMAIN" != "general" ]]; then
        DOMAIN_MATCH_COUNT=$(jq -r --arg domain "$DOMAIN" '[.rules[] | select(.domain == $domain)] | length' "$RULES_FILE" 2>/dev/null || echo "0")
    fi

    # Then count rules matching keywords (category or trigger) for additional context
    IFS='|' read -ra KEYWORDS <<< "$DOMAIN_KEYWORDS"
    for kw in "${KEYWORDS[@]}"; do
        COUNT=$(jq -r --arg kw "$kw" '[.rules[] | select(.category == $kw or (.trigger | ascii_downcase | contains($kw)))] | length' "$RULES_FILE" 2>/dev/null || echo "0")
        KEYWORD_MATCH_COUNT=$((KEYWORD_MATCH_COUNT + COUNT))
    done

    # v2.60.1: Use domain matches as primary, add keyword matches as secondary
    # This ensures backfilled domains are recognized
    RELEVANT_COUNT=$((DOMAIN_MATCH_COUNT + KEYWORD_MATCH_COUNT))

    # Log the breakdown
    {
        echo "  Domain matches ($DOMAIN): $DOMAIN_MATCH_COUNT"
        echo "  Keyword matches: $KEYWORD_MATCH_COUNT"
    } >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1
fi

# Minimum required rules
MIN_RULES_FOR_DOMAIN=3
MIN_RULES_FOR_QUADRATIC=5

# Determine if learning is needed
SHOULD_LEARN=false
LEARN_REASON=""

if [[ "$RELEVANT_COUNT" -eq 0 ]]; then
    SHOULD_LEARN=true
    LEARN_REASON="ZERO relevant rules (knowledge gap)"
elif [[ "$RELEVANT_COUNT" -lt "$MIN_RULES_FOR_DOMAIN" ]] && [[ "$COMPLEXITY" -ge 7 ]]; then
    SHOULD_LEARN=true
    LEARN_REASON="Insufficient rules for high-complexity task"
elif [[ "$INFO_DENSITY" == "QUADRATIC" ]] && [[ "$RELEVANT_COUNT" -lt "$MIN_RULES_FOR_QUADRATIC" ]]; then
    SHOULD_LEARN=true
    LEARN_REASON="QUADRATIC density task needs more patterns ($RELEVANT_COUNT/$MIN_RULES_FOR_QUADRATIC rules)"
fi

# Log analysis
{
    echo "[$(date -Iseconds)] Auto-learn analysis:"
    echo "  Task complexity: $COMPLEXITY/10"
    echo "  Info density: $INFO_DENSITY"
    echo "  Domain: $DOMAIN"
    echo "  Total rules: $RULES_COUNT"
    echo "  Relevant rules: $RELEVANT_COUNT"
    echo "  Required: $MIN_RULES_FOR_DOMAIN (or $MIN_RULES_FOR_QUADRATIC for QUADRATIC)"
    echo "  Should learn: $SHOULD_LEARN ($LEARN_REASON)"
} >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

# If sufficient knowledge, skip learning
if [[ "$SHOULD_LEARN" != "true" ]]; then
    trap - EXIT; echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'; exit 0
fi

# Determine learning recommendation
LANG="typescript"
echo "$PROMPT_LOWER" | grep -qE 'python|django|flask|fastapi' && LANG="python"
echo "$PROMPT_LOWER" | grep -qE 'rust|cargo' && LANG="rust"
echo "$PROMPT_LOWER" | grep -qE 'go|golang' && LANG="go"
echo "$PROMPT_LOWER" | grep -qE 'java|spring|kotlin' && LANG="java"

# Determine severity
if [[ "$RELEVANT_COUNT" -eq 0 ]]; then
    SEVERITY="CRITICAL"
    SEVERITY_LABEL="CRITICAL - No knowledge base"
    URGENCY="REQUIRED before implementation"
    IS_CRITICAL=true
else
    SEVERITY="HIGH"
    SEVERITY_LABEL="HIGH - Insufficient for complexity $COMPLEXITY"
    URGENCY="RECOMMENDED for better quality"
    IS_CRITICAL=false
fi

# v2.60.0: Auto-Learn Enforcement
AUTO_LEARN_ENABLED=false
AUTO_LEARN_BLOCKING=true

if [[ -f "$CONFIG_FILE" ]]; then
    AUTO_LEARN_ENABLED=$(jq -r '.auto_learn.enabled // false' "$CONFIG_FILE" 2>/dev/null || echo "false")
    AUTO_LEARN_BLOCKING=$(jq -r '.auto_learn.blocking // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
fi

# Event emission function
emit_learning_event() {
    local event_type="$1"
    local payload="$2"
    local event_file="${HOME}/.ralph/events/event-log.jsonl"
    mkdir -p "$(dirname "$event_file")"
    echo "{\"timestamp\":\"$(date -Iseconds)\",\"type\":\"$event_type\",\"payload\":$payload}" >> "$event_file" 2>/dev/null || true
}

# Auto-execute learning for CRITICAL gaps
LEARNING_EXECUTED=false
LEARNING_OUTPUT=""

if [[ "$IS_CRITICAL" == "true" ]] && [[ "$AUTO_LEARN_ENABLED" == "true" ]]; then
    echo "[$(date -Iseconds)] CRITICAL gap detected - auto-executing learning" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

    # Emit learning.started event
    EVENT_PAYLOAD=$(jq -n --arg domain "$DOMAIN" --arg lang "$LANG" --arg reason "$LEARN_REASON" '{
        domain: $domain, language: $lang, reason: $reason, severity: "CRITICAL", auto_executed: true
    }')
    emit_learning_event "learning.started" "$EVENT_PAYLOAD"

    # v2.60.2: FIX HIGH-002 - Sanitize inputs and use array execution to prevent command injection
    # Validate DOMAIN is one of allowed values
    case "$DOMAIN" in
        backend|frontend|security|database|devops|testing|general) ;;
        *) DOMAIN="general" ;;
    esac

    # Validate LANG is one of allowed values
    case "$LANG" in
        typescript|python|rust|go|java|javascript) ;;
        *) LANG="typescript" ;;
    esac

    echo "[$(date -Iseconds)] Executing: /curator full --type $DOMAIN --lang $LANG --tier economic" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

    # Execute learning using array (safe from injection)
    if [[ "$AUTO_LEARN_BLOCKING" == "true" ]]; then
        LEARNING_OUTPUT=$("${HOME}/.ralph/curator/curator.sh" full --type "$DOMAIN" --lang "$LANG" --tier economic 2>&1) || true
        LEARNING_EXECUTED=true
        # SEC-110: Redact sensitive data before logging
        SAFE_OUTPUT=$(redact_sensitive "${LEARNING_OUTPUT:0:500}")
        echo "[$(date -Iseconds)] Learning output: ${SAFE_OUTPUT}" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

        # SEC-110: Also redact event payload output
        SAFE_EVENT_OUTPUT=$(redact_sensitive "${LEARNING_OUTPUT:0:1000}")
        EVENT_PAYLOAD=$(jq -n --arg domain "$DOMAIN" --argjson success true --arg output "$SAFE_EVENT_OUTPUT" '{
            domain: $domain, success: $success, output: $output
        }')
        emit_learning_event "learning.completed" "$EVENT_PAYLOAD"
    else
        "${HOME}/.ralph/curator/curator.sh" full --type "$DOMAIN" --lang "$LANG" --tier economic >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1 &
        LEARNING_EXECUTED=true
        echo "[$(date -Iseconds)] Learning started in background" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

        EVENT_PAYLOAD=$(jq -n --arg domain "$DOMAIN" --arg mode "background" '{domain: $domain, mode: $mode}')
        emit_learning_event "learning.scheduled" "$EVENT_PAYLOAD"
    fi
fi

# Auto-execution info
AUTO_EXEC_NOTE=""
if [[ "$IS_CRITICAL" == "true" ]]; then
    if [[ "$AUTO_LEARN_ENABLED" == "true" ]]; then
        AUTO_EXEC_NOTE="AUTO-execution ENABLED - Learning will run automatically"
        if [[ "$AUTO_LEARN_BLOCKING" == "true" ]]; then
            AUTO_EXEC_NOTE+=" (blocking mode - task waits for completion)"
        else
            AUTO_EXEC_NOTE+=" (background mode - task continues while learning runs)"
        fi
    else
        AUTO_EXEC_NOTE="AUTO-execution DISABLED - Set auto_learn.enabled: true in memory-config.json"
    fi
fi

# Write learning context
cat > "$CONTEXT_FILE" << EOF
# Auto-Learn Recommendation (v2.60.0)
**Generated**: $(date -Iseconds)

## Analysis
- **Task Complexity**: $COMPLEXITY/10
- **Detected Domain**: $DOMAIN
- **Procedural Memory**: $RELEVANT_COUNT/$MIN_RULES_FOR_DOMAIN relevant rules
- **Trigger**: $LEARN_REASON
- **Severity**: $SEVERITY_LABEL
- **Auto-Exec**: $AUTO_LEARN_ENABLED (blocking: $AUTO_LEARN_BLOCKING)

## $AUTO_EXEC_NOTE

## Recommendation ($URGENCY)

Your procedural memory lacks patterns for this $DOMAIN task.
**Learn from quality repositories BEFORE implementing**:

\`\`\`bash
# Option 1: Full curator pipeline (recommended for first time)
/curator full --type $DOMAIN --lang $LANG

# Option 2: Quick search if you have specific repo in mind
/repo-learn https://github.com/{owner}/{repo}
\`\`\`

## Why This Matters

For complexity $COMPLEXITY tasks, having learned patterns helps:
- Avoid common pitfalls in $DOMAIN development
- Follow industry best practices
- Generate higher quality, more maintainable code

## What Will Be Learned

Domain \`$DOMAIN\` rules typically include:
$(echo "$DOMAIN_KEYWORDS" | tr '|' '\n' | sed 's/^/- /')

---
*This suggestion was auto-generated.*
EOF

echo "[$(date -Iseconds)] Learning context written to: $CONTEXT_FILE" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

# Update plan-state.json
PLAN_STATE_TEMP="${PLAN_STATE}.tmp.$$"
if [[ -f "$PLAN_STATE" ]]; then
    if jq --argjson recommended true \
       --arg reason "$LEARN_REASON" \
       --arg domain "$DOMAIN" \
       --argjson complexity "$COMPLEXITY" \
       --argjson is_critical "$IS_CRITICAL" \
       --argjson auto_executed "$LEARNING_EXECUTED" \
       --arg severity "$SEVERITY" \
       --arg ts "$(date -Iseconds)" \
       '.learning_state = {
           recommended: $recommended,
           reason: $reason,
           domain: $domain,
           complexity: $complexity,
           severity: $severity,
           is_critical: $is_critical,
           auto_executed: $auto_executed,
           auto_exec_enabled: $auto_executed,
           timestamp: $ts
       }' "$PLAN_STATE" > "$PLAN_STATE_TEMP" 2>/dev/null; then
        mv "$PLAN_STATE_TEMP" "$PLAN_STATE"
        echo "[$(date -Iseconds)] Updated learning_state in plan-state.json" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1
    fi
fi

# Build learning recommendation
LEARN_RECOMMENDATION="AUTO-LEARN RECOMMENDATION ($SEVERITY_LABEL)

Your procedural memory lacks patterns for this $DOMAIN task ($RELEVANT_COUNT/$MIN_RULES_FOR_DOMAIN relevant rules).
**$URGENCY**: Learn from quality repositories BEFORE implementing:

$AUTO_EXEC_NOTE

\`\`\`bash
/curator full --type $DOMAIN --lang $LANG
\`\`\`

Reason: $LEARN_REASON

---

"

# Inject into Task prompt
ORIGINAL_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")

if [[ -n "$ORIGINAL_PROMPT" ]]; then
    MODIFIED_PROMPT="${LEARN_RECOMMENDATION}${ORIGINAL_PROMPT}"
    NEW_TOOL_INPUT=$(echo "$INPUT" | jq --arg new_prompt "$MODIFIED_PROMPT" '.tool_input + {prompt: $new_prompt}' 2>/dev/null)

    if [[ -n "$NEW_TOOL_INPUT" ]] && [[ "$NEW_TOOL_INPUT" != "null" ]]; then
        echo "[$(date -Iseconds)] Injecting learning recommendation into Task prompt" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1
        # v2.70.0: PreToolUse hooks use {"hookSpecificOutput": {"permissionDecision": "allow"}}, NOT {"continue": true}
        jq -n --argjson tool_input "$NEW_TOOL_INPUT" '{"decision": "allow", "tool_input": $tool_input}'
        trap - EXIT; exit 0
    fi
fi

# Fallback
echo "[$(date -Iseconds)] Could not inject, recommendation in: $CONTEXT_FILE" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1
trap - EXIT; echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'; exit 0
