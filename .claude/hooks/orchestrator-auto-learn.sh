#!/bin/bash
# Orchestrator Auto-Learn Hook (v2.57.0)
# Hook: PreToolUse (Task)
# Purpose: Proactively trigger learning when orchestrator faces complex tasks
#
# When orchestrator classifies a task as complexity >= 7 and procedural
# memory lacks relevant patterns, this hook:
# 1. Analyzes the task domain
# 2. Checks for relevant procedural rules
# 3. If insufficient, INJECTS learning recommendation into Task prompt
#
# v2.57.0: Fixed to actually inject context (Issue #5 from Memory System Reconstruction)
# Previously wrote auto-learn-context.md but never used it - now injects directly
#
# The goal is autonomous self-improvement through proactive learning.
#
# VERSION: 2.57.2
# v2.57.2: Fixed JSON output (SEC-034) - must output JSON, not silent exit
# SECURITY: SEC-006 compliant

set -euo pipefail
umask 077

# SEC-034: Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Parse input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    trap - EXIT; echo '{"continue": true}'; exit 0
fi

# Check if this is an orchestrator-related task
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || echo "")
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

# Check for orchestrator or planning context
if [[ "$SUBAGENT_TYPE" != "orchestrator" ]] && [[ "$SUBAGENT_TYPE" != "Plan" ]]; then
    # Also check if it's a complex implementation task
    if ! echo "$PROMPT_LOWER" | grep -qE 'implement|build|create|develop|design'; then
        trap - EXIT; echo '{"continue": true}'; exit 0
    fi
fi

# Paths
PLAN_STATE="${HOME}/.claude/.plan-state.json"
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
CONTEXT_FILE="${HOME}/.ralph/state/auto-learn-context.md"
LOG_DIR="${HOME}/.ralph/logs"

mkdir -p "$LOG_DIR" "${HOME}/.ralph/state"

# Check plan-state for complexity (if exists)
COMPLEXITY=0
if [[ -f "$PLAN_STATE" ]]; then
    COMPLEXITY=$(jq -r '.classification.complexity // 0' "$PLAN_STATE" 2>/dev/null || echo "0")
fi

# If no plan-state yet, estimate complexity from prompt keywords
if [[ "$COMPLEXITY" -eq 0 ]]; then
    # Count complexity indicators
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

# Note: We DON'T exit here based on complexity alone.
# Auto-learning triggers when:
# 1. ZERO relevant rules (any complexity) - knowledge gap
# 2. Less than MIN_RULES AND complexity >= 7 - insufficient for complex task
# The check happens AFTER counting rules below.

# Detect task domain
DOMAIN=""
DOMAIN_KEYWORDS=""

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

# Check procedural memory for relevant rules
RULES_COUNT=0
RELEVANT_COUNT=0

if [[ -f "$RULES_FILE" ]]; then
    RULES_COUNT=$(jq -r '.rules | length // 0' "$RULES_FILE" 2>/dev/null || echo "0")

    # Check for domain-relevant rules
    IFS='|' read -ra KEYWORDS <<< "$DOMAIN_KEYWORDS"
    for kw in "${KEYWORDS[@]}"; do
        COUNT=$(jq -r --arg kw "$kw" '[.rules[] | select(.category == $kw or (.trigger | ascii_downcase | contains($kw)))] | length' "$RULES_FILE" 2>/dev/null || echo "0")
        RELEVANT_COUNT=$((RELEVANT_COUNT + COUNT))
    done
fi

# Minimum required rules for confident implementation
MIN_RULES_FOR_DOMAIN=3

# Determine if learning is needed:
# 1. ZERO relevant rules = ALWAYS learn (knowledge gap for any task)
# 2. Less than MIN_RULES AND complexity >= 7 = learn (insufficient for complex task)
SHOULD_LEARN=false
LEARN_REASON=""

if [[ "$RELEVANT_COUNT" -eq 0 ]]; then
    SHOULD_LEARN=true
    LEARN_REASON="ZERO relevant rules (knowledge gap)"
elif [[ "$RELEVANT_COUNT" -lt "$MIN_RULES_FOR_DOMAIN" ]] && [[ "$COMPLEXITY" -ge 7 ]]; then
    SHOULD_LEARN=true
    LEARN_REASON="Insufficient rules for high-complexity task"
fi

# Log analysis
{
    echo "[$(date -Iseconds)] Auto-learn analysis:"
    echo "  Task complexity: $COMPLEXITY/10"
    echo "  Domain: $DOMAIN"
    echo "  Total rules: $RULES_COUNT"
    echo "  Relevant rules: $RELEVANT_COUNT"
    echo "  Required: $MIN_RULES_FOR_DOMAIN"
    echo "  Should learn: $SHOULD_LEARN ($LEARN_REASON)"
} >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

# If insufficient knowledge, write context for learning
if [[ "$SHOULD_LEARN" == "true" ]]; then
    # Determine learning recommendation
    LANG="typescript"  # Default
    echo "$PROMPT_LOWER" | grep -qE 'python|django|flask|fastapi' && LANG="python"
    echo "$PROMPT_LOWER" | grep -qE 'rust|cargo' && LANG="rust"
    echo "$PROMPT_LOWER" | grep -qE 'go|golang' && LANG="go"
    echo "$PROMPT_LOWER" | grep -qE 'java|spring|kotlin' && LANG="java"

    # Determine severity label based on condition
    if [[ "$RELEVANT_COUNT" -eq 0 ]]; then
        SEVERITY="CRITICAL - No knowledge base"
        URGENCY="REQUIRED before implementation"
    else
        SEVERITY="HIGH - Insufficient for complexity $COMPLEXITY"
        URGENCY="RECOMMENDED for better quality"
    fi

    cat > "$CONTEXT_FILE" << EOF
# 🎓 Auto-Learn Recommendation (v2.55.0)
**Generated**: $(date -Iseconds)

## Analysis
- **Task Complexity**: $COMPLEXITY/10
- **Detected Domain**: $DOMAIN
- **Procedural Memory**: $RELEVANT_COUNT/$MIN_RULES_FOR_DOMAIN relevant rules
- **Trigger**: $LEARN_REASON
- **Severity**: $SEVERITY

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
*This suggestion was auto-generated. Skip with /orchestrator --skip-learn*
EOF

    echo "[$(date -Iseconds)] Learning context written to: $CONTEXT_FILE" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1

    # v2.57.0: INJECT the learning recommendation into the Task prompt
    # Build the learning recommendation text (simplified for prompt injection)
    LEARN_RECOMMENDATION="🎓 **AUTO-LEARN RECOMMENDATION** ($SEVERITY)

Your procedural memory lacks patterns for this $DOMAIN task ($RELEVANT_COUNT/$MIN_RULES_FOR_DOMAIN relevant rules).
**$URGENCY**: Learn from quality repositories BEFORE implementing:

\`\`\`bash
/curator full --type $DOMAIN --lang $LANG
\`\`\`

Reason: $LEARN_REASON

---

"

    # Get original prompt and inject the recommendation at the beginning
    ORIGINAL_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")

    if [[ -n "$ORIGINAL_PROMPT" ]]; then
        MODIFIED_PROMPT="${LEARN_RECOMMENDATION}${ORIGINAL_PROMPT}"

        # Build modified tool_input
        NEW_TOOL_INPUT=$(echo "$INPUT" | jq --arg new_prompt "$MODIFIED_PROMPT" '.tool_input + {prompt: $new_prompt}' 2>/dev/null)

        if [[ -n "$NEW_TOOL_INPUT" ]] && [[ "$NEW_TOOL_INPUT" != "null" ]]; then
            echo "[$(date -Iseconds)] Injecting learning recommendation into Task prompt" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1
            echo "{\"tool_input\": $NEW_TOOL_INPUT}"
            trap - EXIT; echo '{"continue": true}'; exit 0
        fi
    fi

    # Fallback: output empty to allow but log the recommendation was written
    echo "[$(date -Iseconds)] Could not inject, recommendation in: $CONTEXT_FILE" >> "${LOG_DIR}/auto-learn-$(date +%Y%m%d).log" 2>&1
fi

# Allow task to proceed unchanged
echo '{}'
exit 0
