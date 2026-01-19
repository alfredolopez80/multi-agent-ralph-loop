#!/usr/bin/env bats
# test_state_coordinator.bats - State Coordinator v2.54 Tests
# Run with: bats tests/test_state_coordinator.bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"
    PLAN_STATE_FILE=".claude/plan-state.json"

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
# State Coordinator Script Existence
# ============================================================================

@test "state-coordinator.sh script exists" {
    [ -f "$STATE_COORDINATOR" ]
}

@test "state-coordinator.sh is executable" {
    [ -x "$STATE_COORDINATOR" ]
}

@test "state-coordinator.sh has correct version" {
    grep -q 'VERSION="2.54.0"' "$STATE_COORDINATOR"
}

# ============================================================================
# State Coordinator Functions
# ============================================================================

@test "state-coordinator has init_plan_v2 function" {
    grep -q 'init_plan_v2\|init-plan-v2\|cmd_init_plan' "$STATE_COORDINATOR"
}

@test "state-coordinator has set_current_phase function" {
    grep -q 'set_current_phase\|set-phase\|cmd_set_phase' "$STATE_COORDINATOR"
}

@test "state-coordinator has update_phase_status function" {
    grep -q 'update_phase_status\|update-phase\|cmd_update_phase' "$STATE_COORDINATOR"
}

@test "state-coordinator has complete_barrier function" {
    grep -q 'complete_barrier\|complete-barrier\|cmd_complete_barrier' "$STATE_COORDINATOR"
}

@test "state-coordinator has update_step function" {
    grep -q 'update_step\|update-step\|cmd_update_step' "$STATE_COORDINATOR"
}

@test "state-coordinator has set_active_agent function" {
    grep -q 'set_active_agent\|set-active-agent\|cmd_set_active_agent' "$STATE_COORDINATOR"
}

@test "state-coordinator has get_active_agent function" {
    grep -q 'get_active_agent\|get-active-agent\|cmd_get_active_agent' "$STATE_COORDINATOR"
}

@test "state-coordinator has record_handoff function" {
    grep -q 'record_handoff\|record-handoff\|cmd_record_handoff' "$STATE_COORDINATOR"
}

# ============================================================================
# Atomic Update Patterns
# ============================================================================

@test "state-coordinator uses mktemp for atomic updates" {
    grep -q 'mktemp' "$STATE_COORDINATOR"
}

@test "state-coordinator uses proper file locking" {
    grep -qE 'flock|mv.*PLAN_STATE\|atomic' "$STATE_COORDINATOR"
}

@test "state-coordinator has trap for cleanup" {
    grep -q 'trap.*EXIT\|trap.*cleanup' "$STATE_COORDINATOR"
}

# ============================================================================
# Event Integration
# ============================================================================

@test "state-coordinator integrates with event-bus" {
    grep -q 'EVENT_BUS\|event-bus' "$STATE_COORDINATOR"
}

@test "state-coordinator emits barrier.complete event" {
    grep -q 'barrier.complete' "$STATE_COORDINATOR"
}

@test "state-coordinator emits phase.complete event" {
    grep -q 'phase.complete\|phase\.complete' "$STATE_COORDINATOR"
}

# ============================================================================
# Help and Documentation
# ============================================================================

@test "state-coordinator has help command" {
    grep -qE 'help\|--help\|-h\)' "$STATE_COORDINATOR"
}

@test "state-coordinator help includes version info" {
    grep -qE 'v2\.54|Version.*2\.54' "$STATE_COORDINATOR"
}

# ============================================================================
# Error Handling
# ============================================================================

@test "state-coordinator uses strict mode" {
    grep -q 'set -[euo]*.*pipefail\|set.*-e\|set.*-u' "$STATE_COORDINATOR"
}

@test "state-coordinator logs operations" {
    grep -q 'log\|LOG_FILE' "$STATE_COORDINATOR"
}

# ============================================================================
# Plan State v2 Schema Compliance
# ============================================================================

@test "state-coordinator supports v2.51+ schema" {
    grep -qE '2\.5[1-9]\|version.*2\.5' "$STATE_COORDINATOR"
}

@test "state-coordinator handles phases array" {
    grep -q 'phases\|\.phases' "$STATE_COORDINATOR"
}

@test "state-coordinator handles barriers object" {
    grep -q 'barriers\|\.barriers' "$STATE_COORDINATOR"
}
