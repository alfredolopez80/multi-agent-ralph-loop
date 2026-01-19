#!/usr/bin/env bats
# test_orchestration_workflow_v254.bats - v2.54 Orchestration Workflow Tests
# Run with: bats tests/test_orchestration_workflow_v254.bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    RALPH_SCRIPT="$PROJECT_DIR/scripts/ralph"
    STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"
    EVENT_BUS="${HOME}/.claude/scripts/event-bus.sh"
    LSA_PRE_STEP="${HOME}/.claude/hooks/lsa-pre-step.sh"
    PLAN_SYNC_POST="${HOME}/.claude/hooks/plan-sync-post-step.sh"
    STATE_SYNC="${HOME}/.claude/hooks/state-sync.sh"

    [ -f "$RALPH_SCRIPT" ] || skip "ralph script not found"
    export RALPH_TEST_MODE=1
}

# ============================================================================
# LSA Pre-Step Hook v2.54 Integration
# ============================================================================

@test "lsa-pre-step.sh has v2.54 version" {
    [ -f "$LSA_PRE_STEP" ] || skip "lsa-pre-step.sh not found"
    grep -q 'VERSION.*2.54.0\|2\.54\.0' "$LSA_PRE_STEP"
}

@test "lsa-pre-step.sh integrates with state coordinator" {
    [ -f "$LSA_PRE_STEP" ] || skip "lsa-pre-step.sh not found"
    grep -q 'STATE_COORDINATOR' "$LSA_PRE_STEP"
}

@test "lsa-pre-step.sh marks step as in_progress" {
    [ -f "$LSA_PRE_STEP" ] || skip "lsa-pre-step.sh not found"
    grep -qE 'update-step.*in_progress\|in_progress\|status.*in_progress' "$LSA_PRE_STEP"
}

@test "lsa-pre-step.sh updates current_phase" {
    [ -f "$LSA_PRE_STEP" ] || skip "lsa-pre-step.sh not found"
    grep -qE 'current_phase\|set-phase\|STEP_PHASE' "$LSA_PRE_STEP"
}

@test "lsa-pre-step.sh returns correct JSON format" {
    [ -f "$LSA_PRE_STEP" ] || skip "lsa-pre-step.sh not found"
    grep -qE '\{.*"continue".*true.*\}\|\{.*"decision"' "$LSA_PRE_STEP"
}

# ============================================================================
# Plan-Sync Post-Step Hook v2.54 Integration
# ============================================================================

@test "plan-sync-post-step.sh has v2.54 version" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -q 'VERSION.*2.54.0\|2\.54\.0' "$PLAN_SYNC_POST"
}

@test "plan-sync-post-step.sh integrates with state coordinator" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -q 'STATE_COORDINATOR' "$PLAN_SYNC_POST"
}

@test "plan-sync-post-step.sh integrates with event bus" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -q 'EVENT_BUS' "$PLAN_SYNC_POST"
}

@test "plan-sync-post-step.sh updates step status to completed" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -qE 'STEP_STATUS.*completed\|update-step.*completed' "$PLAN_SYNC_POST"
}

@test "plan-sync-post-step.sh updates step status to verified" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -qE 'STEP_STATUS.*verified\|verified' "$PLAN_SYNC_POST"
}

@test "plan-sync-post-step.sh checks phase completion" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -qE 'check-phase-complete\|PHASE_COMPLETE' "$PLAN_SYNC_POST"
}

@test "plan-sync-post-step.sh completes barriers" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -qE 'complete-barrier' "$PLAN_SYNC_POST"
}

@test "plan-sync-post-step.sh emits step.complete event" {
    [ -f "$PLAN_SYNC_POST" ] || skip "plan-sync-post-step.sh not found"
    grep -qE 'step\.complete\|step.complete' "$PLAN_SYNC_POST"
}

# ============================================================================
# State-Sync Hook v2.54
# ============================================================================

@test "state-sync.sh exists" {
    [ -f "$STATE_SYNC" ]
}

@test "state-sync.sh has v2.54 version" {
    [ -f "$STATE_SYNC" ] || skip "state-sync.sh not found"
    grep -q 'VERSION.*2.54.0\|2\.54\.0' "$STATE_SYNC"
}

@test "state-sync.sh handles Task completion" {
    [ -f "$STATE_SYNC" ] || skip "state-sync.sh not found"
    grep -qE 'handle_task_completion\|Task\)' "$STATE_SYNC"
}

@test "state-sync.sh handles Bash handoff commands" {
    [ -f "$STATE_SYNC" ] || skip "state-sync.sh not found"
    grep -qE 'handle_handoff_bash\|handoff' "$STATE_SYNC"
}

@test "state-sync.sh syncs barriers" {
    [ -f "$STATE_SYNC" ] || skip "state-sync.sh not found"
    grep -qE 'sync_barriers' "$STATE_SYNC"
}

@test "state-sync.sh repairs state consistency" {
    [ -f "$STATE_SYNC" ] || skip "state-sync.sh not found"
    grep -qE 'repair_state_consistency' "$STATE_SYNC"
}

@test "state-sync.sh resets active_agent after Task" {
    [ -f "$STATE_SYNC" ] || skip "state-sync.sh not found"
    grep -qE 'orchestrator\|set-active-agent.*orchestrator' "$STATE_SYNC"
}

@test "state-sync.sh returns correct JSON format" {
    [ -f "$STATE_SYNC" ] || skip "state-sync.sh not found"
    grep -qE '\{.*"continue".*true.*\}' "$STATE_SYNC"
}

# ============================================================================
# Event Bus v2.54 Integration
# ============================================================================

@test "event-bus.sh has v2.54 version" {
    [ -f "$EVENT_BUS" ] || skip "event-bus.sh not found"
    grep -q 'VERSION.*2.54.0\|2\.54\.0' "$EVENT_BUS"
}

@test "event-bus.sh integrates with state coordinator" {
    [ -f "$EVENT_BUS" ] || skip "event-bus.sh not found"
    grep -q 'STATE_COORDINATOR' "$EVENT_BUS"
}

@test "event-bus.sh uses state coordinator for barrier updates" {
    [ -f "$EVENT_BUS" ] || skip "event-bus.sh not found"
    grep -qE 'complete-barrier.*STATE_COORDINATOR\|STATE_COORDINATOR.*complete-barrier' "$EVENT_BUS"
}

# ============================================================================
# Ralph Script v2.54 Updates
# ============================================================================

@test "ralph script has cmd_process_status function" {
    grep -q 'cmd_process_status' "$RALPH_SCRIPT"
}

@test "ralph script has ps|processes case" {
    grep -qE 'ps\|processes\)' "$RALPH_SCRIPT"
}

@test "ralph script cmd_status uses observability" {
    grep -A20 'cmd_status()' "$RALPH_SCRIPT" | grep -qE 'plan-state\|PLAN_STATE\|status'
}

# ============================================================================
# Workflow Integration - EXECUTE-WITH-SYNC
# ============================================================================

@test "orchestration workflow uses state coordinator" {
    grep -qE 'state-coordinator\|STATE_COORDINATOR' "$RALPH_SCRIPT" || \
    [ -f "$STATE_COORDINATOR" ]
}

@test "orchestration workflow supports phase transitions" {
    [ -f "$STATE_COORDINATOR" ] || skip "state-coordinator.sh not found"
    grep -qE 'current_phase\|set-phase\|phase' "$STATE_COORDINATOR"
}

@test "orchestration workflow supports WAIT-ALL barriers" {
    [ -f "$STATE_COORDINATOR" ] || skip "state-coordinator.sh not found"
    grep -qE 'barrier\|WAIT-ALL' "$STATE_COORDINATOR"
}
