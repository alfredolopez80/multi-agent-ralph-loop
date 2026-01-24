#!/bin/bash
# plan-state-adaptive.sh - Adaptive plan-state creation for ALL tasks
# VERSION: 2.68.23
# v2.68.2: FIX CRIT-007 - Clear EXIT trap before explicit JSON output
#
# PROBLEM SOLVED: Plan-state was only created for orchestrator tasks,
# leaving FAST_PATH and SIMPLE tasks without tracking.
#
# Creates plan-state appropriate to task complexity:
# - FAST_PATH (complexity 1-3): Minimal plan-state, 1 step, max 3 iterations
# - SIMPLE (complexity 4-5): Basic plan-state, direct steps, max 10 iterations
# - COMPLEX (complexity 6+): Full plan-state via orchestrator
#
# Trigger: UserPromptSubmit
#
# This hook was created as part of v2.57.0 Memory System Reconstruction
# to address Issue #1: Plan-state only creates for orchestrator-analysis.md

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap for guaranteed JSON output (v2.62.3)
trap 'echo "{}"' ERR EXIT

umask 077

# =============================================================================
# CONFIGURATION
# =============================================================================

PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/plan-state-adaptive.log"
PLAN_STALENESS_MINUTES=30  # Consider plan stale after 30 minutes

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# =============================================================================
# LOGGING
# =============================================================================

log() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [plan-state-adaptive] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# =============================================================================
# KEYWORD DETECTION
# =============================================================================

# Keywords that indicate ORCHESTRATOR-level tasks (defer to orchestrator)
ORCHESTRATOR_KEYWORDS='(/orchestrator|/orch|ralph orch|/loop)'

# Keywords that indicate COMPLEX tasks (complexity 6+)
COMPLEX_KEYWORDS='(implement|create|build|migrate|refactor|architecture|design|integration|system|feature|module|component|service|api|authentication|authorization|database|schema)'

# Keywords that indicate SIMPLE tasks (complexity 4-5)
SIMPLE_KEYWORDS='(fix|update|change|edit|modify|add|remove|rename|move|copy|delete|adjust|tweak|correct)'

# Keywords that indicate FAST_PATH tasks (complexity 1-3)
TRIVIAL_KEYWORDS='(typo|readme|comment|log|print|version|bump|format|lint|style|whitespace)'

# =============================================================================
# CLASSIFICATION FUNCTION
# =============================================================================

classify_prompt() {
    local prompt="$1"
    local prompt_lower
    prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    # Word count as secondary indicator
    local word_count
    word_count=$(echo "$prompt" | wc -w | tr -d ' ')

    # 1. Check for orchestrator commands first (defer to orchestrator)
    if echo "$prompt_lower" | grep -qE '/orchestrator|/orch|ralph orch|/loop'; then
        echo "ORCHESTRATOR"
        return
    fi

    # 2. Check for TRIVIAL keywords FIRST - very simple tasks (typo, readme, etc.)
    # These override other keywords because they indicate quick fixes
    if echo "$prompt_lower" | grep -qE 'typo|readme|comment|version|bump|format|lint|style|whitespace'; then
        if [[ "$word_count" -lt 15 ]]; then
            echo "FAST_PATH"
            return
        fi
    fi

    # 3. Check for COMPLEX keywords with multi-step indicators
    # Keywords: implement, create, build, migrate, refactor, architecture, design, integration, system, feature
    if echo "$prompt_lower" | grep -qE 'implement|create|build|migrate|refactor|architecture|design|integration|system|feature|module|component|service|api|authentication|authorization|database|schema'; then
        # Multi-step indicators make it COMPLEX
        if echo "$prompt_lower" | grep -qE '\band\b|\bthen\b|\bafter\b|\balso\b|\bplus\b|\bwith\b|\bincluding\b'; then
            echo "COMPLEX"
            return
        fi
        # Long prompts with complex keywords = COMPLEX
        if [[ "$word_count" -gt 20 ]]; then
            echo "COMPLEX"
            return
        fi
        # Short prompts with complex keywords = SIMPLE (might need orchestrator suggestion)
        echo "SIMPLE"
        return
    fi

    # 4. Check for SIMPLE keywords - fix, update, change, etc.
    if echo "$prompt_lower" | grep -qE 'fix|update|change|edit|modify|add|remove|rename|move|copy|delete|adjust|tweak|correct'; then
        echo "SIMPLE"
        return
    fi

    # 5. Default classification based on word count
    if [[ "$word_count" -lt 8 ]]; then
        echo "FAST_PATH"
    elif [[ "$word_count" -lt 25 ]]; then
        echo "SIMPLE"
    else
        echo "COMPLEX"
    fi
}

# =============================================================================
# PLAN STATE CREATION
# =============================================================================

create_plan_state() {
    local complexity_mode="$1"
    local task_summary="$2"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Generate plan ID
    local plan_id
    plan_id="adaptive-$(date +%Y%m%d-%H%M%S)-$$"

    # Set parameters based on complexity
    local complexity model max_iter step_name
    case "$complexity_mode" in
        FAST_PATH)
            complexity=2
            model="sonnet"
            max_iter=3
            step_name="Direct implementation"
            ;;
        SIMPLE)
            complexity=4
            model="sonnet"
            max_iter=10
            step_name="Execute task"
            ;;
        COMPLEX)
            complexity=7
            model="opus"
            max_iter=25
            step_name="Phase 1: Analysis"
            ;;
        *)
            complexity=4
            model="sonnet"
            max_iter=10
            step_name="Execute task"
            ;;
    esac

    # Ensure .claude directory exists
    mkdir -p "$(dirname "$PLAN_STATE")" 2>/dev/null || true

    # Create plan-state JSON
    cat > "$PLAN_STATE" << PLANEOF
{
  "\$schema": "plan-state-v2",
  "plan_id": "$plan_id",
  "task": $(echo "$task_summary" | jq -Rs '.[:200]'),
  "classification": {
    "complexity": $complexity,
    "model_routing": "$model",
    "adversarial_required": $([ "$complexity_mode" = "COMPLEX" ] && echo "true" || echo "false"),
    "adaptive_mode": "$complexity_mode",
    "route": "$complexity_mode"
  },
  "steps": {
    "1": {
      "id": "1",
      "title": "$step_name",
      "status": "pending",
      "result": null,
      "spec": {
        "file": null,
        "exports": [],
        "signatures": {}
      },
      "actual": null,
      "drift": {
        "detected": false,
        "items": [],
        "needs_sync": false
      },
      "lsa_verification": {
        "pre_check": null,
        "post_check": null
      }
    }
  },
  "loop_state": {
    "current_iteration": 0,
    "max_iterations": $max_iter,
    "validate_attempts": 0
  },
  "phases": [
    {
      "phase_id": "main",
      "phase_name": "Main Execution",
      "step_ids": ["1"],
      "depends_on": [],
      "execution_mode": "sequential",
      "status": "pending"
    }
  ],
  "current_phase": "main",
  "barriers": {},
  "metadata": {
    "created_at": "$timestamp",
    "created_by": "plan-state-adaptive",
    "version": "2.57.0",
    "source": "UserPromptSubmit"
  },
  "version": "2.57.0",
  "updated_at": "$timestamp"
}
PLANEOF

    # Validate JSON was created correctly
    if ! jq '.' "$PLAN_STATE" > /dev/null 2>&1; then
        log "ERROR: Created invalid JSON, removing"
        rm -f "$PLAN_STATE"
        return 1
    fi

    chmod 600 "$PLAN_STATE"
    log "Created plan-state: $plan_id ($complexity_mode, complexity=$complexity, max_iter=$max_iter)"
    return 0
}

# =============================================================================
# MAIN LOGIC
# =============================================================================

main() {
    # Parse hook input (JSON from stdin)
    local input
    input=$(cat)

    # Extract user prompt
    local prompt
    prompt=$(echo "$input" | jq -r '.userPrompt // ""' 2>/dev/null || echo "")

    if [[ -z "$prompt" ]] || [[ "$prompt" == "null" ]]; then
        log "No prompt provided, skipping"
        trap - EXIT  # CRIT-007: Clear trap before explicit output
        echo '{}'
        exit 0
    fi

    log "Processing prompt: ${prompt:0:100}..."

    # Check if plan-state exists and is recent
    if [[ -f "$PLAN_STATE" ]]; then
        # Get file age in minutes
        local file_age_seconds
        if [[ "$(uname)" == "Darwin" ]]; then
            file_age_seconds=$(( $(date +%s) - $(stat -f %m "$PLAN_STATE" 2>/dev/null || echo 0) ))
        else
            file_age_seconds=$(( $(date +%s) - $(stat -c %Y "$PLAN_STATE" 2>/dev/null || echo 0) ))
        fi
        local file_age_minutes=$(( file_age_seconds / 60 ))

        # Check plan status
        local plan_status
        plan_status=$(jq -r '.phases[0].status // "unknown"' "$PLAN_STATE" 2>/dev/null || echo "unknown")

        # Skip if plan is recent and still active (pending or in_progress)
        if [[ "$file_age_minutes" -lt "$PLAN_STALENESS_MINUTES" ]]; then
            if [[ "$plan_status" == "pending" ]] || [[ "$plan_status" == "in_progress" ]]; then
                log "Active plan exists (age=${file_age_minutes}m, status=$plan_status), skipping"
                trap - EXIT  # CRIT-007: Clear trap before explicit output
                echo '{}'
                exit 0
            fi
        fi

        log "Existing plan is stale or completed (age=${file_age_minutes}m, status=$plan_status)"
    fi

    # Classify the prompt
    local complexity_mode
    complexity_mode=$(classify_prompt "$prompt")

    log "Classified as: $complexity_mode"

    # For ORCHESTRATOR mode, defer to the orchestrator workflow
    if [[ "$complexity_mode" == "ORCHESTRATOR" ]]; then
        log "Orchestrator task detected, deferring plan-state creation"
        trap - EXIT  # CRIT-007: Clear trap before explicit output
        echo '{}'
        exit 0
    fi

    # Create appropriate plan-state
    local task_summary
    task_summary=$(echo "$prompt" | head -c 200 | tr '\n' ' ')

    if create_plan_state "$complexity_mode" "$task_summary"; then
        log "Successfully created adaptive plan-state"

        # For COMPLEX tasks, suggest using /orchestrator
        if [[ "$complexity_mode" == "COMPLEX" ]]; then
            local suggestion="💡 Complex task detected (complexity 7+). Consider using \`/orchestrator\` for full workflow with quality gates, LSA verification, and adversarial validation."
            # Escape for JSON
            suggestion=$(echo "$suggestion" | jq -Rs '.')
            echo "{\"userPromptContent\": $suggestion}"
        else
            # For FAST_PATH and SIMPLE, just acknowledge
            local mode_emoji
            case "$complexity_mode" in
                FAST_PATH) mode_emoji="⚡" ;;
                SIMPLE) mode_emoji="📝" ;;
                *) mode_emoji="🔄" ;;
            esac
            log "Plan ready: $mode_emoji $complexity_mode mode"
            trap - EXIT  # CRIT-007: Clear trap before explicit output
            echo '{}'
        fi
    else
        log "Failed to create plan-state"
        trap - EXIT  # CRIT-007: Clear trap before explicit output
        echo '{}'
    fi
}

# =============================================================================
# ENTRY POINT
# =============================================================================

main "$@"
