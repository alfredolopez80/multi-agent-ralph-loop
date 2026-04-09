#!/usr/bin/env bash
# auto-plan-state.sh - Unified plan state management (consolidated)
# VERSION: 3.0.0 (Consolidated from auto-plan-state.sh + plan-state-init.sh)
# Hook: PostToolUse (Write) matcher: orchestrator-analysis
#        + SessionStart (plan state initialization on session start)
#        + CLI interface for plan state management
#
# Purpose: Automatically create plan-state.json when orchestrator-analysis.md
#          is written (PostToolUse), AND provide full plan state management
#          CLI (init, add-step, start, complete, verify, status).
#
# v3.0.0: Consolidated - merged plan-state-init.sh into auto-plan-state.sh
# v2.69.0: SEC-111 stdin read, CRIT-001/003 fixes
# v2.62.3: Updated to v2 schema with phases, barriers, object-based steps
#
# CLI Usage:
#   ./auto-plan-state.sh init <task> [complexity] [model]
#   ./auto-plan-state.sh add-step <id> <title> [file] [action] [desc]
#   ./auto-plan-state.sh add-exports <step_id> <export1> [export2...]
#   ./auto-plan-state.sh add-deps <step_id> <dep1> [dep2...]
#   ./auto-plan-state.sh add-sig <step_id> <func> <signature>
#   ./auto-plan-state.sh start <step_id>
#   ./auto-plan-state.sh complete <step_id>
#   ./auto-plan-state.sh verify <step_id>
#   ./auto-plan-state.sh status
#
# Hook Usage (PostToolUse):
#   Reads JSON from stdin. If file is orchestrator-analysis.md, creates plan-state.json.
#   Output: {"continue": true} (PostToolUse JSON format)

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/worktree-utils.sh" 2>/dev/null || {
  get_project_root() {
    if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then echo "$CLAUDE_PROJECT_DIR"
    else git rev-parse --show-toplevel 2>/dev/null || echo "."
    fi
  }
  get_main_repo() { get_project_root; }
  get_claude_dir() { echo "$(get_main_repo)/.claude"; }
}
ANALYSIS_FILE="$(get_claude_dir)/orchestrator-analysis.md"
PLAN_STATE_FILE="$(get_claude_dir)/plan-state.json"
# Alias for CLI commands that use PLAN_STATE
PLAN_STATE="$PLAN_STATE_FILE"
LOG_FILE="${HOME}/.ralph/logs/auto-plan-state.log"

# Ensure directories exist
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
mkdir -p "$(get_claude_dir)" 2>/dev/null

# =============================================================================
# LOGGING
# =============================================================================

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $1" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# FILE LOCKING (SEC-2.2: TOCTOU prevention with mkdir)
# =============================================================================

PLAN_STATE_LOCK="${PLAN_STATE}.lock"

plan_state_lock() {
    local max_attempts=50
    local attempt=0
    while ! mkdir "$PLAN_STATE_LOCK" 2>/dev/null; do
        attempt=$((attempt + 1))
        if [[ $attempt -ge $max_attempts ]]; then
            log "ERROR: Failed to acquire plan-state lock after $max_attempts attempts"
            return 1
        fi
        sleep 0.1
    done
    trap 'rmdir "$PLAN_STATE_LOCK" 2>/dev/null || true' EXIT
    return 0
}

plan_state_unlock() {
    rmdir "$PLAN_STATE_LOCK" 2>/dev/null || true
}

# =============================================================================
# ATOMIC JSON UPDATE HELPER (v2.45.1)
# =============================================================================

atomic_jq_update() {
    local filter="$1"
    shift
    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || {
        log "ERROR: Failed to create temp file"
        return 1
    }

    if jq "$@" "$filter" "$PLAN_STATE" > "$temp_file"; then
        mv "$temp_file" "$PLAN_STATE"
        return 0
    else
        rm -f "$temp_file"
        log "ERROR: jq update failed"
        return 1
    fi
}

# =============================================================================
# UUID GENERATION
# =============================================================================

generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [[ -r /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
    else
        printf '%s-%s-%s-%s' \
            "$(date +%s)" \
            "$$" \
            "$RANDOM$RANDOM" \
            "$(head -c 8 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo "$RANDOM")"
    fi
}

# =============================================================================
# PLAN STATE CLI COMMANDS (merged from plan-state-init.sh)
# =============================================================================

# Initialize plan state from scratch
init_plan_state() {
    local task_description="${1:-Unspecified task}"
    local complexity="${2:-5}"
    local model_routing="${3:-sonnet}"

    plan_state_lock || { log "ERROR: Cannot lock plan-state for init"; return 1; }

    local plan_id timestamp
    plan_id=$(generate_uuid)
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    cat << EOF > "$PLAN_STATE"
{
  "\$schema": "plan-state-v2",
  "version": "2.62.3",
  "plan_id": "$plan_id",
  "task": "$task_description",
  "created_at": "$timestamp",
  "updated_at": "$timestamp",
  "classification": {
    "complexity": $complexity,
    "information_density": "LINEAR",
    "context_requirement": "FITS",
    "model_routing": "$model_routing",
    "route": "STANDARD",
    "adversarial_required": $([ "$complexity" -ge 7 ] && echo "true" || echo "false"),
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
  "steps": {},
  "barriers": {},
  "current_phase": null,
  "active_agent": "orchestrator",
  "current_handoff_id": null,
  "drift_log": [],
  "loop_state": {
    "current_iteration": 0,
    "max_iterations": 25,
    "validate_attempts": 0,
    "last_gate_result": "pending"
  },
  "gap_analysis": {
    "performed": false
  },
  "handoffs": [],
  "checkpoints": [],
  "state_coordinator": {
    "last_sync": null,
    "sync_count": 0,
    "last_barrier_check": null,
    "consistency_repairs": 0,
    "active": true
  }
}
EOF

    log "Plan state initialized: $plan_id"
    echo "$plan_id"
}

# Add a step to plan state
add_step() {
    local step_id="$1"
    local title="$2"
    local file_path="${3:-}"
    local action="${4:-create}"
    local description="${5:-}"

    if [[ ! -f "$PLAN_STATE" ]]; then
        log "ERROR: Plan state not initialized"
        return 1
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || {
        log "ERROR: Failed to create temp file"
        return 1
    }

    if jq --arg id "$step_id" \
       --arg title "$title" \
       --arg file "$file_path" \
       --arg action "$action" \
       --arg desc "$description" \
       --arg ts "$timestamp" '
      .steps[$id] = {
        "name": $title,
        "status": "pending",
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
        "_v1_data": {
          "title": $title,
          "spec": {
            "file": $file,
            "action": $action,
            "description": $desc,
            "exports": [],
            "dependencies": [],
            "signatures": {},
            "return_types": {}
          },
          "actual": null,
          "drift": null,
          "lsa_verification": null,
          "quality_audit": null,
          "micro_gate": null,
          "created_at": $ts
        }
      } |
      .updated_at = $ts
    ' "$PLAN_STATE" > "$temp_file"; then
        mv "$temp_file" "$PLAN_STATE"
    else
        rm -f "$temp_file"
        log "ERROR: Failed to add step"
        return 1
    fi

    log "Step added: $step_id - $title"
}

# Update step spec with exports
add_step_exports() {
    local step_id="$1"
    shift
    local exports="$@"

    local exports_json
    exports_json=$(echo "$exports" | tr ' ' '\n' | jq -R . | jq -s .)

    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    jq --arg id "$step_id" \
       --argjson exports "$exports_json" '
      .steps |= map(
        if .id == $id then
          .spec.exports = $exports
        else . end
      )
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    log "Exports added to step $step_id: $exports"
}

# Update step spec with dependencies
add_step_dependencies() {
    local step_id="$1"
    shift
    local deps="$@"

    local deps_json
    deps_json=$(echo "$deps" | tr ' ' '\n' | jq -R . | jq -s .)

    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    jq --arg id "$step_id" \
       --argjson deps "$deps_json" '
      .steps |= map(
        if .id == $id then
          .spec.dependencies = $deps
        else . end
      )
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    log "Dependencies added to step $step_id: $deps"
}

# Add function signature to step
add_step_signature() {
    local step_id="$1"
    local func_name="$2"
    local signature="$3"

    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    jq --arg id "$step_id" \
       --arg func "$func_name" \
       --arg sig "$signature" '
      .steps |= map(
        if .id == $id then
          .spec.signatures[$func] = $sig
        else . end
      )
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    log "Signature added to step $step_id: $func_name"
}

# Mark step as in_progress
start_step() {
    local step_id="$1"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    # First, reset any current in_progress step to pending
    jq --arg ts "$timestamp" '
      .steps |= map(
        if .status == "in_progress" then
          .status = "pending"
        else . end
      )
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    # Then mark the new step as in_progress
    jq --arg id "$step_id" \
       --arg ts "$timestamp" '
      .steps |= map(
        if .id == $id then
          .status = "in_progress" |
          .started_at = $ts
        else . end
      ) |
      .updated_at = $ts
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    export RALPH_CURRENT_STEP="$step_id"
    log "Step started: $step_id"
}

# Mark step as completed
complete_step() {
    local step_id="$1"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    jq --arg id "$step_id" \
       --arg ts "$timestamp" '
      .steps |= map(
        if .id == $id then
          .status = "completed" |
          .completed_at = $ts
        else . end
      ) |
      .updated_at = $ts
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    log "Step completed: $step_id"
}

# Mark step as verified (after LSA post-check passes)
verify_step() {
    local step_id="$1"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    jq --arg id "$step_id" \
       --arg ts "$timestamp" '
      .steps |= map(
        if .id == $id then
          .status = "verified" |
          .lsa_verification.post_check.passed = true |
          .lsa_verification.post_check.timestamp = $ts
        else . end
      ) |
      .updated_at = $ts
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    log "Step verified: $step_id"
}

# Show plan status
show_status() {
    if [[ ! -f "$PLAN_STATE" ]]; then
        echo "No plan state found"
        return 1
    fi

    echo ""
    echo "================================================================="
    echo "                        PLAN STATUS"
    echo "================================================================="
    echo ""

    jq -r '
      "Plan ID: \(.plan_id)",
      "Task: \(.task)",
      "Complexity: \(.classification.complexity)/10",
      "Model: \(.classification.model_routing)",
      "",
      "Steps:",
      (.steps[] | "  [\(.status | if . == "verified" then "V" elif . == "completed" then "O" elif . == "in_progress" then ">" elif . == "failed" then "X" else "." end)] \(.id): \(.title)" +
        (if .drift.detected then " DRIFT" else "" end))
    ' "$PLAN_STATE"

    echo ""

    local total verified completed pending drift_count
    total=$(jq '.steps | length' "$PLAN_STATE")
    verified=$(jq '[.steps[] | select(.status == "verified")] | length' "$PLAN_STATE")
    completed=$(jq '[.steps[] | select(.status == "completed")] | length' "$PLAN_STATE")
    pending=$(jq '[.steps[] | select(.status == "pending")] | length' "$PLAN_STATE")
    drift_count=$(jq '[.steps[] | select(.drift.detected == true)] | length' "$PLAN_STATE")

    echo "Summary: $verified verified, $completed completed, $pending pending (of $total total)"
    if [[ "$drift_count" -gt 0 ]]; then
        echo "WARNING: $drift_count step(s) with unresolved drift"
    fi
    echo ""
}

# =============================================================================
# HOOK MODE: PostToolUse (orchestrator-analysis.md auto-creation)
# =============================================================================

run_hook_mode() {
    # SEC-111: Read input from stdin with length limit (100KB max)
    local INPUT
    INPUT=$(head -c 100000)

    # Error trap for guaranteed JSON output (SEC-042)
    trap 'echo "{\"continue\": true}"' ERR EXIT
    umask 077

    local input="$INPUT"

    # Extract tool result path from hook context
    local tool_name file_path
    tool_name=$(echo "$input" | jq -r '.tool_name // .tool // ""' 2>/dev/null || echo "")
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // .file_path // ""' 2>/dev/null || echo "")

    log "Hook triggered: tool=$tool_name, file=$file_path"

    # Only proceed if this is a Write to orchestrator-analysis.md
    if [[ "$file_path" != *"orchestrator-analysis.md" ]]; then
        log "Skipping: not orchestrator-analysis.md"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Verify analysis file exists
    if [[ ! -f "$ANALYSIS_FILE" ]]; then
        log "Analysis file not found: $ANALYSIS_FILE"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    log "Processing orchestrator analysis..."

    # Extract information from the analysis file
    local task complexity model adversarial

    task=$(grep -E "^Task:|^# .* Analysis" "$ANALYSIS_FILE" | head -1 | sed 's/^Task: *//;s/^# *//;s/ Analysis$//' || echo "Unknown task")
    complexity=$(grep -oE "Complexity[^0-9]*([0-9]+)" "$ANALYSIS_FILE" | grep -oE "[0-9]+" | head -1 || echo "5")
    model=$(grep -oE "Model Routing[^:]*: *([a-zA-Z]+)" "$ANALYSIS_FILE" | grep -oE "(opus|sonnet|minimax)" | head -1 || echo "sonnet")

    if grep -qiE "Adversarial Required[^:]*: *(Yes|true)" "$ANALYSIS_FILE"; then
        adversarial="true"
    else
        adversarial="false"
    fi

    log "Extracted: task='$task', complexity=$complexity, model=$model, adversarial=$adversarial"

    # Extract implementation phases/steps
    local steps_json="[]"
    local step_id=1

    while IFS= read -r line; do
        if [[ "$line" =~ ^###[[:space:]]*(Phase|Step)[[:space:]]*([0-9]+) ]] || \
           [[ "$line" =~ ^([0-9]+)\.[[:space:]]*\*\* ]]; then

            local title
            title=$(echo "$line" | sed 's/^### *//;s/^[0-9]*\. *//;s/\*//g;s/:.*$//' | head -c 100)

            if [[ -n "$title" ]]; then
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
    plan_id=$(generate_uuid)

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
                "version": "3.0.0"
            }
        }')

    # Ensure .claude directory exists
    mkdir -p "$(get_claude_dir)"

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

        local step_count
        step_count=$(echo "$steps_json" | jq 'length')
        log "Created plan-state with $step_count steps"

        trap - ERR EXIT
        jq -n --arg msg "plan-state-created: $PLAN_STATE_FILE with $step_count steps" \
            '{continue: true, additionalContext: $msg}'
    else
        rm -f "$temp_file"
        log "ERROR: Failed to create plan-state.json"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 1
    fi
}

# =============================================================================
# MAIN DISPATCH
# =============================================================================

case "${1:-__hook__}" in
    __hook__)
        # Default: run as PostToolUse hook (reads stdin)
        run_hook_mode
        ;;
    init)
        shift
        init_plan_state "$@"
        ;;
    add-step)
        shift
        add_step "$@"
        ;;
    add-exports)
        shift
        add_step_exports "$@"
        ;;
    add-deps)
        shift
        add_step_dependencies "$@"
        ;;
    add-sig)
        shift
        add_step_signature "$@"
        ;;
    start)
        shift
        start_step "$@"
        ;;
    complete)
        shift
        complete_step "$@"
        ;;
    verify)
        shift
        verify_step "$@"
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: auto-plan-state.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  init <task> [complexity] [model]  Initialize plan state"
        echo "  add-step <id> <title> [file] [action] [desc]  Add a step"
        echo "  add-exports <step_id> <export1> [export2...]  Add exports to step"
        echo "  add-deps <step_id> <dep1> [dep2...]  Add dependencies to step"
        echo "  add-sig <step_id> <func> <signature>  Add function signature"
        echo "  start <step_id>  Mark step as in_progress"
        echo "  complete <step_id>  Mark step as completed"
        echo "  verify <step_id>  Mark step as verified"
        echo "  status  Show plan status"
        echo ""
        echo "  (no args = PostToolUse hook mode, reads JSON from stdin)"
        ;;
esac
