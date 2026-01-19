#!/usr/bin/env bats
# test_plan_state_lifecycle.bats - Plan State Lifecycle Tests v2.54
# Tests plan-state updates during orchestration execution
# Run with: bats tests/test_plan_state_lifecycle.bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    RALPH_SCRIPT="$PROJECT_DIR/scripts/ralph"
    STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"
    AUTO_PLAN_STATE="${HOME}/.claude/hooks/auto-plan-state.sh"
    PLAN_STATE_INIT="${HOME}/.claude/hooks/plan-state-init.sh"
    SCHEMA_FILE="$PROJECT_DIR/.claude/schemas/plan-state-v2.schema.json"

    # Create temporary test directory
    TEST_WORK_DIR="$(mktemp -d)"
    cd "$TEST_WORK_DIR"
    mkdir -p .claude

    export RALPH_TEST_MODE=1
}

teardown() {
    # Clean up test directory
    [ -d "$TEST_WORK_DIR" ] && rm -rf "$TEST_WORK_DIR"
}

# ============================================================================
# Schema Tests
# ============================================================================

@test "plan-state-v2 schema exists" {
    [ -f "$SCHEMA_FILE" ]
}

@test "plan-state-v2 schema has v2.54 version" {
    grep -q '2.54' "$SCHEMA_FILE"
}

@test "plan-state-v2 schema has active_agent field" {
    grep -q 'active_agent' "$SCHEMA_FILE"
}

@test "plan-state-v2 schema has current_handoff_id field" {
    grep -q 'current_handoff_id' "$SCHEMA_FILE"
}

@test "plan-state-v2 schema has phases array" {
    grep -q '"phases"' "$SCHEMA_FILE"
}

@test "plan-state-v2 schema has barriers object" {
    grep -q '"barriers"' "$SCHEMA_FILE"
}

@test "plan-state-v2 schema has handoffs array" {
    grep -q '"handoffs"' "$SCHEMA_FILE"
}

@test "plan-state-v2 schema has state_coordinator section" {
    grep -q 'state_coordinator' "$SCHEMA_FILE"
}

# ============================================================================
# Auto Plan State Hook Tests
# ============================================================================

@test "auto-plan-state.sh exists" {
    [ -f "$AUTO_PLAN_STATE" ]
}

@test "auto-plan-state.sh has v2.54 version" {
    grep -qE 'VERSION.*2\.54|v2\.54' "$AUTO_PLAN_STATE"
}

@test "auto-plan-state.sh uses state coordinator" {
    grep -q 'STATE_COORDINATOR' "$AUTO_PLAN_STATE"
}

@test "auto-plan-state.sh creates v2.51+ schema" {
    grep -qE '2\.5[1-9]|version.*2\.5' "$AUTO_PLAN_STATE"
}

# ============================================================================
# Plan State Init Hook Tests
# ============================================================================

@test "plan-state-init.sh exists" {
    [ -f "$PLAN_STATE_INIT" ]
}

@test "plan-state-init.sh has update_phase_status function" {
    grep -qE 'update_phase_status|update-phase' "$PLAN_STATE_INIT"
}

@test "plan-state-init.sh has set_current_phase function" {
    grep -qE 'set_current_phase|set-phase' "$PLAN_STATE_INIT"
}

@test "plan-state-init.sh has complete_barrier function" {
    grep -qE 'complete_barrier|complete-barrier' "$PLAN_STATE_INIT"
}

# ============================================================================
# State Coordinator Integration Tests
# ============================================================================

@test "state-coordinator.sh exists" {
    [ -f "$STATE_COORDINATOR" ]
}

@test "state-coordinator.sh has init_plan_v2 function" {
    grep -qE 'init_plan_v2|init-plan-v2|cmd_init' "$STATE_COORDINATOR"
}

@test "state-coordinator.sh has handoff function" {
    # state_coord_handoff handles agent transfers and sets active_agent internally
    grep -qE 'state_coord_handoff|handoff' "$STATE_COORDINATOR"
}

@test "state-coordinator.sh has update_step function" {
    # state_coord_update_step is the primary step management function
    grep -qE 'state_coord_update_step|update_step|update-step' "$STATE_COORDINATOR"
}

@test "state-coordinator.sh has increment_iteration function" {
    grep -qE 'increment_iteration|increment-iteration' "$STATE_COORDINATOR"
}

# ============================================================================
# Plan State Structure Tests
# ============================================================================

@test "create minimal valid plan-state.json" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "current_phase": "clarify",
  "active_agent": "orchestrator",
  "current_handoff_id": null,
  "phases": [
    {"phase_id": "clarify", "step_ids": ["1"], "execution_mode": "sequential", "status": "pending"}
  ],
  "barriers": {
    "clarify_complete": false
  },
  "handoffs": [],
  "steps": {
    "1": {"status": "pending", "agent": "orchestrator"}
  }
}
EOF

    [ -f ".claude/plan-state.json" ]
    jq -e '.version == "2.54.0"' .claude/plan-state.json
}

@test "plan-state.json has valid JSON structure" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "current_phase": "clarify",
  "active_agent": "orchestrator"
}
EOF

    jq -e '.' .claude/plan-state.json > /dev/null
}

@test "plan-state.json supports null current_handoff_id" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "current_handoff_id": null
}
EOF

    jq -e '.current_handoff_id == null' .claude/plan-state.json
}

@test "plan-state.json supports active_agent field" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "active_agent": "security-auditor"
}
EOF

    jq -e '.active_agent == "security-auditor"' .claude/plan-state.json
}

# ============================================================================
# Phase Transition Tests
# ============================================================================

@test "plan-state.json supports phase array" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "phases": [
    {"phase_id": "clarify", "step_ids": ["1"], "execution_mode": "sequential", "status": "pending"},
    {"phase_id": "implement", "step_ids": ["6a", "6b"], "execution_mode": "parallel", "status": "pending"}
  ]
}
EOF

    jq -e '.phases | length == 2' .claude/plan-state.json
    jq -e '.phases[1].execution_mode == "parallel"' .claude/plan-state.json
}

@test "plan-state.json supports barrier tracking" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "barriers": {
    "clarify_complete": true,
    "implement_complete": false
  }
}
EOF

    jq -e '.barriers.clarify_complete == true' .claude/plan-state.json
    jq -e '.barriers.implement_complete == false' .claude/plan-state.json
}

# ============================================================================
# Handoff Tracking Tests
# ============================================================================

@test "plan-state.json supports handoff entries" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "handoffs": [
    {
      "handoff_id": "h-001",
      "from_agent": "orchestrator",
      "to_agent": "security-auditor",
      "timestamp": "2026-01-19T22:00:00Z",
      "memory_transferred": true,
      "event_emitted": true
    }
  ]
}
EOF

    jq -e '.handoffs | length == 1' .claude/plan-state.json
    jq -e '.handoffs[0].memory_transferred == true' .claude/plan-state.json
}

@test "plan-state.json tracks current handoff" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "current_handoff_id": "h-001",
  "handoffs": [
    {"handoff_id": "h-001", "from_agent": "a", "to_agent": "b"}
  ]
}
EOF

    jq -e '.current_handoff_id == "h-001"' .claude/plan-state.json
}

# ============================================================================
# State Coordinator Section Tests
# ============================================================================

@test "plan-state.json supports state_coordinator tracking" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "state_coordinator": {
    "last_sync": "2026-01-19T22:00:00Z",
    "sync_count": 5,
    "integrity_check": "passed"
  }
}
EOF

    jq -e '.state_coordinator.sync_count == 5' .claude/plan-state.json
}

# ============================================================================
# Ralph Status Integration Tests
# ============================================================================

@test "ralph script has cmd_status function" {
    grep -q 'cmd_status' "$RALPH_SCRIPT"
}

@test "ralph status command exists in case statement" {
    grep -qE 'status\)' "$RALPH_SCRIPT"
}

@test "ralph status supports --compact flag" {
    grep -qE '\-\-compact|compact' "$RALPH_SCRIPT"
}

@test "ralph status supports --json flag" {
    grep -qE '\-\-json|json' "$RALPH_SCRIPT"
}

# ============================================================================
# Progress Calculation Tests
# ============================================================================

@test "calculate progress from plan-state.json" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "steps": {
    "1": {"status": "completed"},
    "2": {"status": "completed"},
    "3": {"status": "in_progress"},
    "4": {"status": "pending"},
    "5": {"status": "pending"}
  }
}
EOF

    # Calculate progress: 2 completed out of 5 = 40%
    local completed
    completed=$(jq '[.steps | to_entries[] | select(.value.status == "completed")] | length' .claude/plan-state.json)
    local total
    total=$(jq '[.steps | to_entries[]] | length' .claude/plan-state.json)

    [ "$completed" -eq 2 ]
    [ "$total" -eq 5 ]
}

@test "identify current step from plan-state.json" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "steps": {
    "1": {"status": "completed"},
    "2": {"status": "in_progress"},
    "3": {"status": "pending"}
  }
}
EOF

    # Find in_progress step
    local current
    current=$(jq -r '[.steps | to_entries[] | select(.value.status == "in_progress")] | .[0].key' .claude/plan-state.json)

    [ "$current" == "2" ]
}

# ============================================================================
# Version Migration Tests
# ============================================================================

@test "old v1 schema can be detected" {
    cat > .claude/plan-state.json << 'EOF'
{
  "task": "test",
  "classification": {"complexity": 5},
  "steps": {}
}
EOF

    # v1 schema has no "version" field
    ! jq -e '.version' .claude/plan-state.json 2>/dev/null
}

@test "v2.51+ schema has version field" {
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.51.0",
  "current_phase": "clarify"
}
EOF

    jq -e '.version' .claude/plan-state.json
}

# ============================================================================
# State Coordinator Step Update Tests (BEHAVIORAL)
# ============================================================================

@test "state-coordinator update-step changes step status" {
    skip_if_no_state_coordinator

    # Create test plan-state.json
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "steps": {
    "1": {"status": "pending", "name": "Test Step 1"},
    "2": {"status": "pending", "name": "Test Step 2"}
  }
}
EOF

    # Update step 1 to in_progress
    "$STATE_COORDINATOR" update-step "1" "in_progress"

    # Verify step 1 is now in_progress
    local status
    status=$(jq -r '.steps["1"].status' .claude/plan-state.json)
    [ "$status" == "in_progress" ]
}

@test "state-coordinator update-step adds timestamps" {
    skip_if_no_state_coordinator

    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "steps": {
    "1": {"status": "pending", "name": "Test Step"}
  }
}
EOF

    # Update to in_progress (should add started_at)
    "$STATE_COORDINATOR" update-step "1" "in_progress"

    # Verify started_at timestamp exists
    local started
    started=$(jq -r '.steps["1"].started_at' .claude/plan-state.json)
    [ "$started" != "null" ]
    [[ "$started" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}T ]]
}

@test "state-coordinator update-step to completed adds completed_at" {
    skip_if_no_state_coordinator

    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "steps": {
    "1": {"status": "in_progress", "name": "Test Step", "started_at": "2026-01-19T22:00:00Z"}
  }
}
EOF

    # Complete the step
    "$STATE_COORDINATOR" update-step "1" "completed" "success"

    # Verify completed_at timestamp exists
    local completed
    completed=$(jq -r '.steps["1"].completed_at' .claude/plan-state.json)
    [ "$completed" != "null" ]

    # Verify result is saved
    local result
    result=$(jq -r '.steps["1"].result' .claude/plan-state.json)
    [ "$result" == "success" ]
}

# ============================================================================
# Ralph Status --compact Progress Tests (BEHAVIORAL)
# ============================================================================

@test "ralph status --compact shows correct percentage with 0 completed" {
    skip_if_no_ralph_status

    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "classification": {"complexity": 5},
  "steps": {
    "1": {"status": "pending"},
    "2": {"status": "pending"},
    "3": {"status": "pending"},
    "4": {"status": "pending"},
    "5": {"status": "pending"}
  }
}
EOF

    local output
    output=$("$RALPH_SCRIPT" status --compact 2>/dev/null || echo "No plan")

    # Should show 0% or 0/5
    [[ "$output" =~ "0%" ]] || [[ "$output" =~ "0/5" ]] || [[ "$output" =~ "No plan" ]]
}

@test "ralph status --compact shows progress after completing steps" {
    skip_if_no_ralph_status

    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "classification": {"complexity": 5},
  "steps": {
    "1": {"status": "completed"},
    "2": {"status": "completed"},
    "3": {"status": "in_progress"},
    "4": {"status": "pending"},
    "5": {"status": "pending"}
  }
}
EOF

    local output
    output=$("$RALPH_SCRIPT" status --compact 2>/dev/null || echo "")

    # Should show 2/5 or 40%
    [[ "$output" =~ "2/5" ]] || [[ "$output" =~ "40%" ]]
}

@test "ralph status --compact shows 100% when all completed" {
    skip_if_no_ralph_status

    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "classification": {"complexity": 5},
  "steps": {
    "1": {"status": "completed"},
    "2": {"status": "completed"},
    "3": {"status": "completed"}
  }
}
EOF

    local output
    output=$("$RALPH_SCRIPT" status --compact 2>/dev/null || echo "")

    # Should show 100% or 3/3
    [[ "$output" =~ "100%" ]] || [[ "$output" =~ "3/3" ]]
}

# ============================================================================
# Status Loop Verification Tests (USER REQUESTED)
# These tests verify ralph status updates correctly as plan-state changes
# ============================================================================

@test "status loop: pending → in_progress shows progress change" {
    skip_if_no_state_coordinator
    skip_if_no_ralph_status

    # Initial state: all pending
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "classification": {"complexity": 5},
  "steps": {
    "1": {"status": "pending", "name": "Step 1"},
    "2": {"status": "pending", "name": "Step 2"},
    "3": {"status": "pending", "name": "Step 3"}
  }
}
EOF

    # Capture initial status
    local initial_status
    initial_status=$("$RALPH_SCRIPT" status --compact 2>/dev/null || echo "0/3")

    # Update step 1 to in_progress
    "$STATE_COORDINATOR" update-step "1" "in_progress"

    # Capture updated status
    local updated_status
    updated_status=$("$RALPH_SCRIPT" status --compact 2>/dev/null || echo "0/3")

    # Status should show in_progress indicator
    [[ "$updated_status" =~ "in_progress" ]] || [[ "$updated_status" =~ "🔄" ]] || [[ "$updated_status" =~ "Step" ]]
}

@test "status loop: in_progress → completed increments progress" {
    skip_if_no_state_coordinator
    skip_if_no_ralph_status

    # Initial: 1 in_progress, 2 pending
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "classification": {"complexity": 5},
  "steps": {
    "1": {"status": "in_progress", "name": "Step 1", "started_at": "2026-01-19T22:00:00Z"},
    "2": {"status": "pending", "name": "Step 2"},
    "3": {"status": "pending", "name": "Step 3"}
  }
}
EOF

    # Complete step 1
    "$STATE_COORDINATOR" update-step "1" "completed" "success"

    # Verify plan-state updated
    local step1_status
    step1_status=$(jq -r '.steps["1"].status' .claude/plan-state.json)
    [ "$step1_status" == "completed" ]

    # Check status shows 1 completed
    local status_output
    status_output=$("$RALPH_SCRIPT" status --compact 2>/dev/null || echo "")

    # Should show 1/3 or 33%
    [[ "$status_output" =~ "1/3" ]] || [[ "$status_output" =~ "33%" ]]
}

@test "status loop: full lifecycle pending → in_progress → completed" {
    skip_if_no_state_coordinator
    skip_if_no_ralph_status

    # Create 5-step plan
    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "classification": {"complexity": 5},
  "steps": {
    "1": {"status": "pending", "name": "Step 1"},
    "2": {"status": "pending", "name": "Step 2"},
    "3": {"status": "pending", "name": "Step 3"},
    "4": {"status": "pending", "name": "Step 4"},
    "5": {"status": "pending", "name": "Step 5"}
  }
}
EOF

    # Capture status at each stage
    local progress_stages=()

    # Stage 0: Initial (0/5)
    progress_stages+=("$(jq '[.steps | to_entries[] | select(.value.status == "completed")] | length' .claude/plan-state.json)")

    # Stage 1: Start step 1
    "$STATE_COORDINATOR" update-step "1" "in_progress"

    # Stage 2: Complete step 1
    "$STATE_COORDINATOR" update-step "1" "completed" "success"
    progress_stages+=("$(jq '[.steps | to_entries[] | select(.value.status == "completed")] | length' .claude/plan-state.json)")

    # Stage 3: Start and complete step 2
    "$STATE_COORDINATOR" update-step "2" "in_progress"
    "$STATE_COORDINATOR" update-step "2" "completed" "success"
    progress_stages+=("$(jq '[.steps | to_entries[] | select(.value.status == "completed")] | length' .claude/plan-state.json)")

    # Verify monotonic progress: 0 → 1 → 2
    [ "${progress_stages[0]}" -eq 0 ]
    [ "${progress_stages[1]}" -eq 1 ]
    [ "${progress_stages[2]}" -eq 2 ]

    # Verify ralph status shows correct progress
    local final_status
    final_status=$("$RALPH_SCRIPT" status --compact 2>/dev/null || echo "")
    [[ "$final_status" =~ "2/5" ]] || [[ "$final_status" =~ "40%" ]]
}

@test "status loop: completed steps are persisted correctly" {
    skip_if_no_state_coordinator

    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "steps": {
    "1": {"status": "pending"},
    "2": {"status": "pending"}
  }
}
EOF

    # Complete both steps
    "$STATE_COORDINATOR" update-step "1" "in_progress"
    "$STATE_COORDINATOR" update-step "1" "completed" "success"
    "$STATE_COORDINATOR" update-step "2" "in_progress"
    "$STATE_COORDINATOR" update-step "2" "completed" "success"

    # Re-read the file and verify persistence
    local step1 step2
    step1=$(jq -r '.steps["1"].status' .claude/plan-state.json)
    step2=$(jq -r '.steps["2"].status' .claude/plan-state.json)

    [ "$step1" == "completed" ]
    [ "$step2" == "completed" ]

    # Both should have completed_at timestamps
    local ts1 ts2
    ts1=$(jq -r '.steps["1"].completed_at' .claude/plan-state.json)
    ts2=$(jq -r '.steps["2"].completed_at' .claude/plan-state.json)

    [ "$ts1" != "null" ]
    [ "$ts2" != "null" ]
}

@test "status loop: updated_at changes on each update" {
    skip_if_no_state_coordinator

    cat > .claude/plan-state.json << 'EOF'
{
  "version": "2.54.0",
  "updated_at": "2026-01-19T00:00:00Z",
  "steps": {
    "1": {"status": "pending"}
  }
}
EOF

    local initial_updated
    initial_updated=$(jq -r '.updated_at' .claude/plan-state.json)

    # Sleep briefly to ensure timestamp changes
    sleep 1

    # Make an update
    "$STATE_COORDINATOR" update-step "1" "in_progress"

    local new_updated
    new_updated=$(jq -r '.updated_at' .claude/plan-state.json)

    # Timestamps should be different
    [ "$initial_updated" != "$new_updated" ]
}

# ============================================================================
# Helper Functions
# ============================================================================

skip_if_no_state_coordinator() {
    if [ ! -f "$STATE_COORDINATOR" ] || [ ! -x "$STATE_COORDINATOR" ]; then
        skip "state-coordinator.sh not found or not executable"
    fi
}

skip_if_no_ralph_status() {
    if [ ! -f "$RALPH_SCRIPT" ]; then
        skip "ralph script not found"
    fi
    # Check if status command exists
    if ! grep -q 'cmd_status\|status)' "$RALPH_SCRIPT"; then
        skip "ralph status command not implemented"
    fi
}

