#!/bin/bash
# task-orchestration-optimizer.sh - Optimize Task tool usage patterns
# VERSION: 2.69.0
# v2.69.0: FIX CRIT-003 - Added EXIT to trap for guaranteed JSON output
#
# Purpose: Implement Claude Code's Task primitive optimization
#          Auto-detect parallelization and context-hiding opportunities.
#
# Trigger: PreToolUse (Task)
#
# Logic:
# 1. Analyze pending tasks in plan-state
# 2. Detect parallelization opportunities (2+ independent tasks)
# 3. Suggest batch execution for parallel tasks
# 4. Mark high-token tasks for context-hiding
#
# Output (JSON via stdout for PreToolUse):
#   - {"decision": "allow"}: Allow the Task tool call
#   - {"decision": "allow", "systemMessage": "..."}: Allow with suggestion

set -euo pipefail

# SEC-033: Guaranteed JSON output on any error
output_json() {
    echo '{"decision": "allow"}'
}
trap 'output_json' ERR EXIT

# Configuration
PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/task-orchestration-optimizer.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [task-optimizer] $*" >> "$LOG_FILE"
}

# Read input from stdin with SEC-111 length limit
INPUT=$(head -c 100000)

# Validate JSON before processing
if ! echo "$INPUT" | jq empty 2>/dev/null; then
    log "Invalid JSON input, skipping hook"
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only process Task tool
if [[ "$TOOL_NAME" != "Task" ]]; then
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

log "Task tool invocation detected, analyzing optimization opportunities"

# Extract Task parameters
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // ""' 2>/dev/null || echo "")
RUN_IN_BACKGROUND=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false' 2>/dev/null || echo "false")
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // ""' 2>/dev/null || echo "")

# Check if plan-state exists
if [[ ! -f "$PLAN_STATE" ]]; then
    log "No plan-state.json, allowing Task without optimization"
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"decision": "allow"}'
    exit 0
fi

# Read plan-state
PLAN_STATE_CONTENT=$(cat "$PLAN_STATE")

# Get current phase and its execution mode
CURRENT_PHASE=$(echo "$PLAN_STATE_CONTENT" | jq -r '.current_phase // ""')
EXECUTION_MODE=""
PHASE_STEP_IDS="[]"

if [[ -n "$CURRENT_PHASE" ]]; then
    EXECUTION_MODE=$(echo "$PLAN_STATE_CONTENT" | jq -r --arg phase "$CURRENT_PHASE" '
        .phases[] | select(.phase_id == $phase) | .execution_mode // "sequential"
    ')
    PHASE_STEP_IDS=$(echo "$PLAN_STATE_CONTENT" | jq -r --arg phase "$CURRENT_PHASE" '
        .phases[] | select(.phase_id == $phase) | .step_ids // []
    ')
fi

# Count pending steps in current phase
PENDING_STEPS=$(echo "$PLAN_STATE_CONTENT" | jq --argjson ids "$PHASE_STEP_IDS" '
    [.steps | to_entries[] | select(.key as $k | $ids | index($k)) | select(.value.status == "pending")] | length
')

# Detect optimization opportunities
SUGGESTIONS=""
OPTIMIZATION_APPLIED=false

# 1. PARALLELIZATION DETECTION
if [[ "$EXECUTION_MODE" == "parallel" ]] && [[ "$PENDING_STEPS" -ge 2 ]]; then
    log "Parallelization opportunity: $PENDING_STEPS pending steps in parallel phase"

    # Get pending step names
    PENDING_NAMES=$(echo "$PLAN_STATE_CONTENT" | jq -r --argjson ids "$PHASE_STEP_IDS" '
        [.steps | to_entries[] | select(.key as $k | $ids | index($k)) | select(.value.status == "pending") | .value.name] | join(", ")
    ')

    SUGGESTIONS="${SUGGESTIONS}
⚡ **Parallelization Opportunity Detected**
$PENDING_STEPS independent tasks can run in parallel:
- $PENDING_NAMES

Consider launching multiple Task tools in a single message for parallel execution."
    OPTIMIZATION_APPLIED=true
fi

# 2. CONTEXT-HIDING DETECTION
# Check if prompt is large (high-token task)
PROMPT_LENGTH=${#PROMPT}
if [[ "$PROMPT_LENGTH" -gt 2000 ]] && [[ "$RUN_IN_BACKGROUND" != "true" ]]; then
    log "Context-hiding opportunity: Large prompt ($PROMPT_LENGTH chars) not running in background"

    SUGGESTIONS="${SUGGESTIONS}

🔇 **Context-Hiding Recommended**
This Task has a large prompt ($PROMPT_LENGTH chars).
Consider adding \`run_in_background: true\` to reduce context pollution."
    OPTIMIZATION_APPLIED=true
fi

# 3. VERIFICATION PATTERN CHECK
# If this is NOT a verification task but we have pending verifications
PENDING_VERIFICATIONS=$(echo "$PLAN_STATE_CONTENT" | jq '
    [.steps | to_entries[] | select(.value.verification.status == "pending" and .value.verification.required == true)] | length
')

if [[ "$PENDING_VERIFICATIONS" -gt 0 ]] && [[ "$SUBAGENT_TYPE" != *"reviewer"* ]] && [[ "$SUBAGENT_TYPE" != *"auditor"* ]] && [[ "$SUBAGENT_TYPE" != *"test"* ]]; then
    log "Pending verifications: $PENDING_VERIFICATIONS"

    SUGGESTIONS="${SUGGESTIONS}

🔍 **Pending Verifications**
$PENDING_VERIFICATIONS step(s) have pending verification.
Consider running verification subagents before proceeding."
    OPTIMIZATION_APPLIED=true
fi

# 4. MODEL OPTIMIZATION
# Check if using opus for simple tasks (could use sonnet)
TASK_MODEL=$(echo "$INPUT" | jq -r '.tool_input.model // ""' 2>/dev/null || echo "")
COMPLEXITY=$(echo "$PLAN_STATE_CONTENT" | jq -r '.classification.complexity // 5')

if [[ "$TASK_MODEL" == "opus" ]] && [[ "$COMPLEXITY" -lt 5 ]]; then
    log "Model optimization: opus used for low complexity ($COMPLEXITY) task"

    SUGGESTIONS="${SUGGESTIONS}

💡 **Model Optimization**
Task complexity is $COMPLEXITY/10 but using opus model.
Consider \`model: \"sonnet\"\` for cost efficiency."
    OPTIMIZATION_APPLIED=true
fi

# Build response
trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
if [[ "$OPTIMIZATION_APPLIED" == "true" ]]; then
    # Escape suggestions for JSON
    ESCAPED_SUGGESTIONS=$(echo "$SUGGESTIONS" | jq -Rs '.')
    echo "{\"decision\": \"allow\", \"systemMessage\": $ESCAPED_SUGGESTIONS}"
else
    log "No optimization opportunities found"
    echo '{"decision": "allow"}'
fi
