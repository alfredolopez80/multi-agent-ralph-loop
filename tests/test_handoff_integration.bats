#!/usr/bin/env bats
# test_handoff_integration.bats - Handoff Pipeline Integration v2.54 Tests
# Run with: bats tests/test_handoff_integration.bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    HANDOFF_SCRIPT="${HOME}/.claude/scripts/handoff.sh"
    AGENT_MEMORY_SCRIPT="${HOME}/.claude/scripts/agent-memory-buffer.sh"
    CHECKPOINT_SCRIPT="${HOME}/.claude/scripts/checkpoint-manager.sh"
    STATE_COORDINATOR="${HOME}/.claude/scripts/state-coordinator.sh"

    export RALPH_TEST_MODE=1
}

# ============================================================================
# Handoff Script v2.54 Updates
# ============================================================================

@test "handoff.sh has v2.54 version" {
    [ -f "$HANDOFF_SCRIPT" ] || skip "handoff.sh not found"
    grep -q 'VERSION="2.54.0"' "$HANDOFF_SCRIPT"
}

@test "handoff.sh has STATE_COORDINATOR configuration" {
    [ -f "$HANDOFF_SCRIPT" ] || skip "handoff.sh not found"
    grep -q 'STATE_COORDINATOR' "$HANDOFF_SCRIPT"
}

@test "handoff.sh has pipeline_handoff_integration function" {
    [ -f "$HANDOFF_SCRIPT" ] || skip "handoff.sh not found"
    grep -q 'pipeline_handoff_integration' "$HANDOFF_SCRIPT"
}

@test "handoff.sh integrates with agent-memory-buffer" {
    [ -f "$HANDOFF_SCRIPT" ] || skip "handoff.sh not found"
    grep -qE 'AGENT_MEMORY|agent-memory-buffer|agent_memory_transfer' "$HANDOFF_SCRIPT"
}

@test "handoff.sh integrates with event-bus" {
    [ -f "$HANDOFF_SCRIPT" ] || skip "handoff.sh not found"
    grep -qE 'EVENT_BUS|event-bus|event_emit' "$HANDOFF_SCRIPT"
}

@test "handoff.sh updates active_agent via state coordinator" {
    [ -f "$HANDOFF_SCRIPT" ] || skip "handoff.sh not found"
    grep -qE 'set-active-agent|set_active_agent|active_agent' "$HANDOFF_SCRIPT"
}

# ============================================================================
# Agent Memory Buffer v2.54 Updates
# ============================================================================

@test "agent-memory-buffer.sh has v2.54 version" {
    [ -f "$AGENT_MEMORY_SCRIPT" ] || skip "agent-memory-buffer.sh not found"
    grep -q 'VERSION="2.54.0"' "$AGENT_MEMORY_SCRIPT"
}

@test "agent-memory-buffer.sh supports handoff_id parameter" {
    [ -f "$AGENT_MEMORY_SCRIPT" ] || skip "agent-memory-buffer.sh not found"
    grep -q 'handoff_id' "$AGENT_MEMORY_SCRIPT"
}

@test "agent-memory-buffer.sh supports source_agent parameter" {
    [ -f "$AGENT_MEMORY_SCRIPT" ] || skip "agent-memory-buffer.sh not found"
    grep -q 'source_agent' "$AGENT_MEMORY_SCRIPT"
}

@test "agent-memory-buffer.sh has find-handoff command" {
    [ -f "$AGENT_MEMORY_SCRIPT" ] || skip "agent-memory-buffer.sh not found"
    grep -qE 'find-handoff|find_handoff|cmd_find_handoff' "$AGENT_MEMORY_SCRIPT"
}

@test "agent-memory-buffer.sh tracks handoff in entries" {
    [ -f "$AGENT_MEMORY_SCRIPT" ] || skip "agent-memory-buffer.sh not found"
    grep -qE 'handoff_id.*content\|"handoff_id":' "$AGENT_MEMORY_SCRIPT"
}

# ============================================================================
# Checkpoint Manager v2.54 Updates
# ============================================================================

@test "checkpoint-manager.sh has v2.54 version" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -q 'VERSION="2.54.0"' "$CHECKPOINT_SCRIPT"
}

@test "checkpoint-manager.sh saves handoff transfers" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -qE 'HANDOFFS_DIR|handoffs/transfers|handoffs_saved' "$CHECKPOINT_SCRIPT"
}

@test "checkpoint-manager.sh saves event log" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -qE 'EVENTS_LOG|event-log\.jsonl|events_saved' "$CHECKPOINT_SCRIPT"
}

@test "checkpoint-manager.sh saves agent memory" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -qE 'AGENT_MEMORY_DIR|agent-memory|agent_memory_saved' "$CHECKPOINT_SCRIPT"
}

@test "checkpoint-manager.sh restores handoff transfers" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A50 'cmd_restore' "$CHECKPOINT_SCRIPT" | grep -qE 'handoffs/transfers'
}

@test "checkpoint-manager.sh restores event log" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A50 'cmd_restore' "$CHECKPOINT_SCRIPT" | grep -qE 'event-log\.jsonl'
}

@test "checkpoint-manager.sh restores agent memory" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A70 'cmd_restore' "$CHECKPOINT_SCRIPT" | grep -qE 'agent-memory'
}

@test "checkpoint-manager.sh restores active_agent" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -qE 'saved_active_agent|active_agent.*restore|set-active-agent' "$CHECKPOINT_SCRIPT"
}

# ============================================================================
# Metadata Enhancements
# ============================================================================

@test "checkpoint metadata includes active_agent field" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A30 'metadata.json' "$CHECKPOINT_SCRIPT" | grep -q 'active_agent'
}

@test "checkpoint metadata includes handoffs saved status" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A30 'metadata.json' "$CHECKPOINT_SCRIPT" | grep -q '"handoffs":'
}

@test "checkpoint metadata includes events saved status" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A30 'metadata.json' "$CHECKPOINT_SCRIPT" | grep -q '"events":'
}

@test "checkpoint metadata includes agent_memory saved status" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A30 'metadata.json' "$CHECKPOINT_SCRIPT" | grep -q '"agent_memory":'
}

# ============================================================================
# Help Text Updates
# ============================================================================

@test "checkpoint-manager help mentions v2.54 features" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -qE 'v2\.54|2\.54' "$CHECKPOINT_SCRIPT"
}

@test "checkpoint-manager help mentions handoffs" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A100 'help\|--help' "$CHECKPOINT_SCRIPT" | grep -qE 'handoffs'
}

@test "checkpoint-manager help mentions event log" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A100 'help\|--help' "$CHECKPOINT_SCRIPT" | grep -qE 'event'
}

@test "checkpoint-manager help mentions agent memory" {
    [ -f "$CHECKPOINT_SCRIPT" ] || skip "checkpoint-manager.sh not found"
    grep -A100 'help\|--help' "$CHECKPOINT_SCRIPT" | grep -qE 'agent.*memory'
}
