#!/bin/bash
# verification-subagent.sh - Spawn verification subagent after step completion
# VERSION: 2.69.0
#
# Purpose: Implement Claude Code's verification pattern
#          Spawn a subagent to verify each completed step.
#
# This is the key integration from Claude Code Cowork Mode's Task primitive.
#
# Trigger: PostToolUse (TaskUpdate - when status changes to completed)
#
# Logic:
# 1. Detect step completion in plan-state
# 2. Check if verification is required for this step
# 3. Suggest spawning a verification subagent
# 4. Track verification status in plan-state
#
# Output (JSON via stdout for PostToolUse):
#   - {"continue": true}: Allow execution to continue
#   - {"continue": true, "systemMessage": "..."}: Continue with suggestion

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Configuration
PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/verification-subagent.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [verification-subagent] $*" >> "$LOG_FILE"
}

# Read input from stdin
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only process TaskUpdate
if [[ "$TOOL_NAME" != "TaskUpdate" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if plan-state exists
if [[ ! -f "$PLAN_STATE" ]]; then
    log "No plan-state.json found"
    echo '{"continue": true}'
    exit 0
fi

# Extract task update info
TASK_ID=$(echo "$INPUT" | jq -r '.tool_input.taskId // ""' 2>/dev/null || echo "")
NEW_STATUS=$(echo "$INPUT" | jq -r '.tool_input.status // ""' 2>/dev/null || echo "")

# Only process completions
if [[ "$NEW_STATUS" != "completed" ]]; then
    log "Not a completion event (status: $NEW_STATUS)"
    echo '{"continue": true}'
    exit 0
fi

log "Step $TASK_ID completed, checking verification requirements"

# Read plan-state
PLAN_STATE_CONTENT=$(cat "$PLAN_STATE")

# Check if this step exists and needs verification
STEP_EXISTS=$(echo "$PLAN_STATE_CONTENT" | jq --arg id "$TASK_ID" '.steps[$id] != null' 2>/dev/null || echo "false")

if [[ "$STEP_EXISTS" != "true" ]]; then
    # Task might be a todo item, not a plan step
    log "Step $TASK_ID not found in plan-state steps"
    echo '{"continue": true}'
    exit 0
fi

# Get step details
STEP_NAME=$(echo "$PLAN_STATE_CONTENT" | jq -r --arg id "$TASK_ID" '.steps[$id].name // "Unknown"')
VERIFICATION_REQUIRED=$(echo "$PLAN_STATE_CONTENT" | jq -r --arg id "$TASK_ID" '.steps[$id].verification.required // false')
VERIFICATION_STATUS=$(echo "$PLAN_STATE_CONTENT" | jq -r --arg id "$TASK_ID" '.steps[$id].verification.status // "pending"')
VERIFICATION_METHOD=$(echo "$PLAN_STATE_CONTENT" | jq -r --arg id "$TASK_ID" '.steps[$id].verification.method // "subagent"')

# Get complexity to decide if verification is needed
COMPLEXITY=$(echo "$PLAN_STATE_CONTENT" | jq -r '.classification.complexity // 5')

# Determine if verification should be suggested
SUGGEST_VERIFICATION=false
VERIFICATION_AGENT="code-reviewer"

# Auto-suggest verification for high complexity tasks or explicitly required
if [[ "$VERIFICATION_REQUIRED" == "true" ]]; then
    SUGGEST_VERIFICATION=true
    VERIFICATION_AGENT=$(echo "$PLAN_STATE_CONTENT" | jq -r --arg id "$TASK_ID" '.steps[$id].verification.agent // "code-reviewer"')
elif [[ "$COMPLEXITY" -ge 7 ]]; then
    SUGGEST_VERIFICATION=true
    VERIFICATION_AGENT="code-reviewer"
fi

# Check step name for security-related keywords
if echo "$STEP_NAME" | grep -iE "(auth|security|password|credential|secret|token|encrypt|permission)" > /dev/null 2>&1; then
    SUGGEST_VERIFICATION=true
    VERIFICATION_AGENT="security-auditor"
fi

# Check for test-related keywords
if echo "$STEP_NAME" | grep -iE "(test|spec|coverage)" > /dev/null 2>&1; then
    SUGGEST_VERIFICATION=true
    VERIFICATION_AGENT="test-architect"
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

if [[ "$SUGGEST_VERIFICATION" == "true" ]] && [[ "$VERIFICATION_STATUS" == "pending" ]]; then
    log "Verification suggested for step $TASK_ID with agent $VERIFICATION_AGENT"

    # Update plan-state with verification pending
    UPDATED_PLAN=$(echo "$PLAN_STATE_CONTENT" | jq \
        --arg id "$TASK_ID" \
        --arg agent "$VERIFICATION_AGENT" \
        --arg now "$NOW" \
        '
        .steps[$id].verification = {
            required: true,
            method: "subagent",
            agent: $agent,
            status: "pending",
            result: null,
            started_at: null,
            completed_at: null,
            task_id: null
        } |
        .updated_at = $now
        ')

    # Write updated plan-state
    TEMP_FILE=$(mktemp)
    echo "$UPDATED_PLAN" | jq '.' > "$TEMP_FILE"
    mv "$TEMP_FILE" "$PLAN_STATE"
    chmod 600 "$PLAN_STATE"

    # Generate verification prompt
    VERIFICATION_PROMPT="Verify the implementation of step '$STEP_NAME'. Check for:
1. Correctness - Does it meet requirements?
2. Quality - Is the code clean and maintainable?
3. Security - Are there any vulnerabilities?
4. Edge cases - Are edge cases handled?

Report findings concisely."

    # Create the suggestion message
    SUGGESTION_MSG="🔍 **Verification Required** for step '$STEP_NAME'

Consider spawning verification subagent:
\`\`\`
Task tool with:
  subagent_type: \"$VERIFICATION_AGENT\"
  model: \"sonnet\"
  run_in_background: true
  prompt: \"$VERIFICATION_PROMPT\"
\`\`\`

Or use: \`ralph verify $TASK_ID\`"

    # Return suggestion (escaped for JSON)
    ESCAPED_MSG=$(echo "$SUGGESTION_MSG" | jq -Rs '.')
    echo "{\"continue\": true, \"systemMessage\": $ESCAPED_MSG}"
else
    log "No verification needed for step $TASK_ID"
    echo '{"continue": true}'
fi
