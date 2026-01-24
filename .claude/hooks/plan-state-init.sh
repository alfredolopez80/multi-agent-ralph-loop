#!/usr/bin/env bash
# VERSION: 2.68.2
# Hook: Plan State Initialization
# Purpose: Initialize plan-state.json from orchestrator analysis
# Security: v2.45.1 - Fixed race condition with atomic updates
# v2.62.3: Updated to v2 schema with phases, barriers, and object-based steps

set -euo pipefail

# Configuration
PLAN_STATE=".claude/plan-state.json"
ANALYSIS_FILE=".claude/orchestrator-analysis.md"
LOG_FILE="${HOME}/.ralph/logs/plan-state.log"

mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p ".claude"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# SECURITY: Atomic JSON update helper (v2.45.1)
# Usage: atomic_jq_update <jq_filter> [jq_args...]
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

# Generate UUID (v2.45.1: improved fallback security)
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif [ -r /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
    else
        # Fallback: use multiple entropy sources
        printf '%s-%s-%s-%s' \
            "$(date +%s)" \
            "$$" \
            "$RANDOM$RANDOM" \
            "$(head -c 8 /dev/urandom 2>/dev/null | od -An -tx1 | tr -d ' \n' || echo "$RANDOM")"
    fi
}

# Initialize plan state
init_plan_state() {
    local task_description="${1:-Unspecified task}"
    local complexity="${2:-5}"
    local model_routing="${3:-sonnet}"

    local plan_id
    local timestamp
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

    if [ ! -f "$PLAN_STATE" ]; then
        log "ERROR: Plan state not initialized"
        return 1
    fi

    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # SECURITY: Use atomic update (v2.45.1)
    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || {
        log "ERROR: Failed to create temp file"
        return 1
    }

    # v2.62.3: Use object format for steps (schema v2 compliance)
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

    # Convert to JSON array
    local exports_json
    exports_json=$(echo "$exports" | tr ' ' '\n' | jq -R . | jq -s .)

    # SECURITY: Atomic update (v2.45.1)
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

    # SECURITY: Atomic update (v2.45.1)
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

    # SECURITY: Atomic update (v2.45.1)
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

    # SECURITY: Atomic updates (v2.45.1)
    local temp_file
    temp_file=$(mktemp "${PLAN_STATE}.XXXXXX") || return 1

    # First, mark any current in_progress step as pending (only one at a time)
    jq --arg ts "$timestamp" '
      .steps |= map(
        if .status == "in_progress" then
          .status = "pending"
        else . end
      )
    ' "$PLAN_STATE" > "$temp_file" && mv "$temp_file" "$PLAN_STATE"

    # Create new temp file for second update
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

    # Export for hooks
    export RALPH_CURRENT_STEP="$step_id"

    log "Step started: $step_id"
}

# Mark step as completed
complete_step() {
    local step_id="$1"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # SECURITY: Atomic update (v2.45.1)
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

    # SECURITY: Atomic update (v2.45.1)
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
    if [ ! -f "$PLAN_STATE" ]; then
        echo "No plan state found"
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                        PLAN STATUS"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    jq -r '
      "Plan ID: \(.plan_id)",
      "Task: \(.task)",
      "Complexity: \(.classification.complexity)/10",
      "Model: \(.classification.model_routing)",
      "",
      "Steps:",
      (.steps[] | "  [\(.status | if . == "verified" then "✓" elif . == "completed" then "○" elif . == "in_progress" then "→" elif . == "failed" then "✗" else "·" end)] \(.id): \(.title)" +
        (if .drift.detected then " ⚠️ DRIFT" else "" end))
    ' "$PLAN_STATE"

    echo ""

    # Summary
    local total verified completed pending drift_count
    total=$(jq '.steps | length' "$PLAN_STATE")
    verified=$(jq '[.steps[] | select(.status == "verified")] | length' "$PLAN_STATE")
    completed=$(jq '[.steps[] | select(.status == "completed")] | length' "$PLAN_STATE")
    pending=$(jq '[.steps[] | select(.status == "pending")] | length' "$PLAN_STATE")
    drift_count=$(jq '[.steps[] | select(.drift.detected == true)] | length' "$PLAN_STATE")

    echo "Summary: $verified verified, $completed completed, $pending pending (of $total total)"
    if [ "$drift_count" -gt 0 ]; then
        echo "⚠️  $drift_count step(s) with unresolved drift"
    fi
    echo ""
}

# Main command handler
case "${1:-}" in
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
        echo "Usage: plan-state-init.sh <command> [args]"
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
        ;;
esac
