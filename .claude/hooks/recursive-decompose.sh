#!/bin/bash
# Recursive Decomposition Hook v2.46
# Hook: PostToolUse (Task - orchestrator classification)
# Purpose: Trigger recursive decomposition for complex tasks
# VERSION: 2.57.5
#
# Based on RLM Paper: "Recursive sub-calling provides strong benefits
# on information-dense inputs"

set -euo pipefail
umask 077

# Parse JSON input
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Only process Task completions
if [[ "$TOOL_NAME" != "Task" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if this is a classification task
TASK_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')
TASK_PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty')

# Only trigger for orchestrator classification results
if [[ "$TASK_TYPE" != "orchestrator" ]] && ! echo "$TASK_PROMPT" | grep -qi "classify\|classification\|complexity"; then
    echo '{"continue": true}'
    exit 0
fi

# Setup
PROJECT_DIR=$(pwd)
PLAN_STATE_FILE="$PROJECT_DIR/.claude/plan-state.json"
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/recursive-decompose-$(date +%Y%m%d).log"

{
    echo ""
    echo "[$(date -Iseconds)] Recursive Decomposition Check"
    echo "  Session: $SESSION_ID"
    echo "  Project: $PROJECT_DIR"

    # Read current plan state if exists
    if [[ -f "$PLAN_STATE_FILE" ]]; then
        WORKFLOW_ROUTE=$(jq -r '.classification.workflow_route // "STANDARD"' "$PLAN_STATE_FILE")
        COMPLEXITY=$(jq -r '.classification.complexity // 5' "$PLAN_STATE_FILE")
        INFO_DENSITY=$(jq -r '.classification.information_density // "LINEAR"' "$PLAN_STATE_FILE")
        CONTEXT_REQ=$(jq -r '.classification.context_requirement // "FITS"' "$PLAN_STATE_FILE")
        CURRENT_DEPTH=$(jq -r '.recursion.depth // 0' "$PLAN_STATE_FILE")
        MAX_DEPTH=$(jq -r '.recursion.max_depth // 3' "$PLAN_STATE_FILE")
        MAX_CHILDREN=${MAX_CHILDREN:-5}  # Default: max 5 sub-orchestrators per level

        echo "  Classification:"
        echo "    Workflow: $WORKFLOW_ROUTE"
        echo "    Complexity: $COMPLEXITY"
        echo "    Info Density: $INFO_DENSITY"
        echo "    Context Req: $CONTEXT_REQ"
        echo "    Current Depth: $CURRENT_DEPTH / $MAX_DEPTH"
    else
        echo "  No plan-state.json found"
        WORKFLOW_ROUTE="STANDARD"
        CURRENT_DEPTH=0
        MAX_DEPTH=3
        MAX_CHILDREN=5
    fi

    # Check if recursive decomposition is needed
    NEEDS_DECOMPOSITION=false
    DECOMPOSITION_REASON=""

    if [[ "$WORKFLOW_ROUTE" == "RECURSIVE_DECOMPOSE" ]]; then
        NEEDS_DECOMPOSITION=true
        DECOMPOSITION_REASON="Workflow route is RECURSIVE_DECOMPOSE"
    elif [[ "$INFO_DENSITY" == "QUADRATIC" ]]; then
        NEEDS_DECOMPOSITION=true
        DECOMPOSITION_REASON="Information density is QUADRATIC"
    elif [[ "$CONTEXT_REQ" == "RECURSIVE" ]]; then
        NEEDS_DECOMPOSITION=true
        DECOMPOSITION_REASON="Context requirement is RECURSIVE"
    fi

    # Check depth limit
    if [[ "$CURRENT_DEPTH" -ge "$MAX_DEPTH" ]]; then
        NEEDS_DECOMPOSITION=false
        DECOMPOSITION_REASON="Max recursion depth reached ($CURRENT_DEPTH >= $MAX_DEPTH)"
    fi

    echo ""
    echo "  Decision: NEEDS_DECOMPOSITION=$NEEDS_DECOMPOSITION"
    echo "  Reason: $DECOMPOSITION_REASON"
    echo ""

} >> "$LOG_FILE" 2>&1

# Generate response with decomposition guidance
# Generate response with decomposition guidance (PostToolUse schema: "continue" not "decision")
# v2.57.0 FIX: Use jq for proper JSON encoding to avoid invalid newlines
if [[ "$NEEDS_DECOMPOSITION" == "true" ]]; then
    # Update plan-state with recursion info (using --arg for safe escaping)
    if [[ -f "$PLAN_STATE_FILE" ]]; then
        TMP_FILE=$(mktemp)
        trap 'rm -f "$TMP_FILE"' ERR
        jq --arg reason "$DECOMPOSITION_REASON" \
            '.recursion.needs_decomposition = true |
            .recursion.decomposition_triggered = true |
            .recursion.triggered_at = now |
            .recursion.reason = $reason' \
            "$PLAN_STATE_FILE" > "$TMP_FILE" && mv "$TMP_FILE" "$PLAN_STATE_FILE"
    fi

    # Build additionalContext with proper newline escaping
    CONTEXT_MSG="RECURSIVE_DECOMPOSITION_REQUIRED: Task requires recursive decomposition (reason: ${DECOMPOSITION_REASON}). DECOMPOSITION PROTOCOL (RLM-inspired): 1. IDENTIFY CHUNKS: Break task into logical units (by module, feature, or file group). 2. CREATE SUB-PLANS: Each chunk gets its own verifiable spec. 3. SPAWN SUB-ORCHESTRATORS: Use Task tool with subagent_type=orchestrator for each chunk (depth=$((CURRENT_DEPTH + 1)), max_depth=$MAX_DEPTH). 4. AGGREGATE RESULTS: Collect sub-results, reconcile conflicts, merge outputs. IMPORTANT: Sub-orchestrators run STANDARD flow (not recursive). Each sub has isolated context. Max $MAX_CHILDREN children per level."

    jq -n --argjson cont true --arg ctx "$CONTEXT_MSG" '{continue: $cont, additionalContext: $ctx}'
else
    jq -n --argjson cont true --arg ctx "STANDARD_PATH: No recursive decomposition needed. Proceeding with standard orchestration flow." '{continue: $cont, additionalContext: $ctx}'
fi
