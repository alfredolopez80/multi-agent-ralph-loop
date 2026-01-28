#!/usr/bin/env bash
# VERSION: 2.69.0
# Hook: auto-plan-state.sh
# Trigger: PostToolUse (Write) matcher: orchestrator-analysis
# Purpose: Automatically create plan-state.json when orchestrator-analysis.md is written
#
# This hook bridges the gap between orchestrator documentation and automation.
# When the orchestrator writes its analysis file, this hook extracts the structure
# and creates the plan-state.json for LSA verification and Plan-Sync.
#
# v2.62.3: Updated to v2 schema with phases, barriers, and object-based steps

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap for guaranteed JSON output (v2.66.6 SEC-042 fix)
trap 'echo "{\"continue\": true}"' ERR EXIT
umask 077

# =============================================================================
# CONFIGURATION
# =============================================================================

ANALYSIS_FILE=".claude/orchestrator-analysis.md"
PLAN_STATE_FILE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/auto-plan-state.log"
PLAN_STATE_INIT="${HOME}/.claude/hooks/plan-state-init.sh"

# =============================================================================
# LOGGING
# =============================================================================

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# MAIN LOGIC
# =============================================================================

main() {
    # v2.69: Use $INPUT from SEC-111 read instead of second cat (fixes CRIT-001 double-read bug)
    local input="$INPUT"

    # Extract tool result path from hook context
    local tool_name file_path
    tool_name=$(echo "$input" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // .file_path // ""' 2>/dev/null || echo "")

    log "Hook triggered: tool=$tool_name, file=$file_path"

    # Only proceed if this is a Write to orchestrator-analysis.md
    if [[ "$file_path" != *"orchestrator-analysis.md" ]]; then
        log "Skipping: not orchestrator-analysis.md"
        # CRIT-003: Clear trap before explicit JSON output to avoid duplicates
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Verify analysis file exists
    if [[ ! -f "$ANALYSIS_FILE" ]]; then
        log "Analysis file not found: $ANALYSIS_FILE"
        # CRIT-003: Clear trap before explicit JSON output to avoid duplicates
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    log "Processing orchestrator analysis..."

    # Extract information from the analysis file
    local task complexity model adversarial

    # Extract task description (first line after "Task:" or from header)
    task=$(grep -E "^Task:|^# .* Analysis" "$ANALYSIS_FILE" | head -1 | sed 's/^Task: *//;s/^# *//;s/ Analysis$//' || echo "Unknown task")

    # Extract complexity (look for "Complexity: X/10" or "**Complexity**: X")
    complexity=$(grep -oE "Complexity[^0-9]*([0-9]+)" "$ANALYSIS_FILE" | grep -oE "[0-9]+" | head -1 || echo "5")

    # Extract model routing
    model=$(grep -oE "Model Routing[^:]*: *([a-zA-Z]+)" "$ANALYSIS_FILE" | grep -oE "(opus|sonnet|minimax)" | head -1 || echo "sonnet")

    # Extract adversarial required
    if grep -qiE "Adversarial Required[^:]*: *(Yes|true)" "$ANALYSIS_FILE"; then
        adversarial="true"
    else
        adversarial="false"
    fi

    log "Extracted: task='$task', complexity=$complexity, model=$model, adversarial=$adversarial"

    # Extract implementation phases/steps
    local steps_json="[]"
    local step_id=1

    # Look for Phase headers or numbered steps
    while IFS= read -r line; do
        # Match "### Phase N:" or "### Step N:" or "N. **"
        if [[ "$line" =~ ^###[[:space:]]*(Phase|Step)[[:space:]]*([0-9]+) ]] || \
           [[ "$line" =~ ^([0-9]+)\.[[:space:]]*\*\* ]]; then

            local title
            title=$(echo "$line" | sed 's/^### *//;s/^[0-9]*\. *//;s/\*//g;s/:.*$//' | head -c 100)

            if [[ -n "$title" ]]; then
                # Create step JSON
                local step_json
                step_json=$(jq -n \
                    --arg id "$step_id" \
                    --arg title "$title" \
                    '{
                        id: $id,
                        title: $title,
                        status: "pending",
                        spec: { file: null, exports: [], signatures: {} },
                        actual: null,
                        drift: { detected: false, items: [], needs_sync: false },
                        lsa_verification: { pre_check: null, post_check: null }
                    }')

                steps_json=$(echo "$steps_json" | jq --argjson step "$step_json" '. + [$step]')
                ((step_id++))
            fi
        fi
    done < "$ANALYSIS_FILE"

    # If no steps found, create a default step
    if [[ $(echo "$steps_json" | jq 'length') -eq 0 ]]; then
        log "No steps found in analysis, creating default step"
        steps_json='[{"id": "1", "title": "Implementation", "status": "pending", "spec": {"file": null, "exports": [], "signatures": {}}, "actual": null, "drift": {"detected": false, "items": [], "needs_sync": false}, "lsa_verification": {"pre_check": null, "post_check": null}}]'
    fi

    # Generate UUID
    local plan_id
    if command -v uuidgen &> /dev/null; then
        plan_id=$(uuidgen | tr '[:upper:]' '[:lower:]')
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        plan_id=$(cat /proc/sys/kernel/random/uuid)
    else
        plan_id="plan-$(date +%s)-$$"
    fi

    # v2.62.3: Convert steps array to object format
    local steps_object
    steps_object=$(echo "$steps_json" | jq '
        reduce .[] as $step ({};
            . + { ($step.id // ("step-" + (length | tostring))): {
                "name": ($step.title // "Unnamed step"),
                "status": ($step.status // "pending"),
                "result": null,
                "error": null,
                "agent": null,
                "handoff_id": null,
                "checkpoint_id": null,
                "started_at": null,
                "completed_at": null,
                "verification": {
                    "required": false,
                    "method": "skip",
                    "agent": null,
                    "status": "pending",
                    "result": null,
                    "started_at": null,
                    "completed_at": null,
                    "task_id": null
                },
                "_v1_data": $step
            }}
        )
    ')

    # Create plan-state.json (v2.62.3: schema v2 with object-based steps)
    local plan_state
    plan_state=$(jq -n \
        --arg schema "plan-state-v2" \
        --arg version "2.62.3" \
        --arg plan_id "$plan_id" \
        --arg task "$task" \
        --argjson complexity "$complexity" \
        --arg model "$model" \
        --argjson adversarial "$adversarial" \
        --argjson steps "$steps_object" \
        --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            "$schema": $schema,
            "version": $version,
            "plan_id": $plan_id,
            "task": $task,
            "created_at": $created,
            "updated_at": $created,
            "classification": {
                "complexity": $complexity,
                "information_density": "LINEAR",
                "context_requirement": "FITS",
                "model_routing": $model,
                "route": "STANDARD",
                "adversarial_required": $adversarial,
                "worktree": {
                    "enabled": false,
                    "path": null,
                    "branch": null
                }
            },
            "clarification": {
                "must_have": [],
                "nice_to_have": []
            },
            "phases": [],
            "steps": $steps,
            "barriers": {},
            "current_phase": null,
            "active_agent": "orchestrator",
            "current_handoff_id": null,
            "loop_state": {
                "current_iteration": 0,
                "max_iterations": 25,
                "validate_attempts": 0,
                "last_gate_result": "pending"
            },
            "handoffs": [],
            "checkpoints": [],
            "state_coordinator": {
                "last_sync": null,
                "sync_count": 0,
                "last_barrier_check": null,
                "consistency_repairs": 0,
                "active": true
            },
            "metadata": {
                "created_at": $created,
                "created_by": "auto-plan-state-hook",
                "version": "2.62.3"
            }
        }')

    # Ensure .claude directory exists
    mkdir -p .claude

    # Write plan-state.json atomically
    local temp_file
    temp_file=$(mktemp "${PLAN_STATE_FILE}.XXXXXX") || {
        log "ERROR: Failed to create temp file"
        exit 1
    }

    if echo "$plan_state" | jq '.' > "$temp_file"; then
        mv "$temp_file" "$PLAN_STATE_FILE"
        chmod 600 "$PLAN_STATE_FILE"
        log "SUCCESS: Created $PLAN_STATE_FILE with ${step_id} steps"

        # Output for Claude to see (in additionalContext)
        local step_count
        step_count=$(echo "$steps_json" | jq 'length')
        log "Created plan-state with $step_count steps"

        # PostToolUse JSON response with context
        # CRIT-003: Clear trap before explicit JSON output to avoid duplicates
        trap - ERR EXIT
        jq -n --arg msg "plan-state-created: $PLAN_STATE_FILE with $step_count steps" \
            '{continue: true, additionalContext: $msg}'
    else
        rm -f "$temp_file"
        log "ERROR: Failed to create plan-state.json"
        # CRIT-003: Clear trap before explicit JSON output to avoid duplicates
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 1
    fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

main "$@"
