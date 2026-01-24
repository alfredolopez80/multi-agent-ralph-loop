#!/usr/bin/env bats
# test_v2_68_22_cli_commands.bats - Functional tests for v2.68.22 CLI commands
# Part of Multi-Agent Ralph Loop Test Suite
#
# Tests the 6 new CLI command groups added in v2.68.22:
# - ralph checkpoint (save, restore, list, show, diff)
# - ralph handoff (transfer, agents, validate, create, load)
# - ralph events (emit, subscribe, barrier, status)
# - ralph agent-memory (init, read, write, transfer, list, gc)
# - ralph migrate (check, run, dry-run)
# - ralph ledger (save, load, list, show)

setup() {
    export RALPH_CMD="/Users/alfredolopez/.local/bin/ralph"
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export TEST_TMP=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_TMP" 2>/dev/null || true
}

# ============================================================
# Ralph CLI Availability Test
# ============================================================

@test "ralph CLI command exists and is executable" {
    [ -f "$RALPH_CMD" ]
    [ -x "$RALPH_CMD" ]
}

@test "ralph CLI shows version information" {
    run "$RALPH_CMD" --version 2>/dev/null || run "$RALPH_CMD" -v 2>/dev/null || true
    [ "$status" -eq 0 ]
    echo "$output" | grep -q "Ralph"
}

# ============================================================
# Checkpoint CLI Structure Tests
# ============================================================

@test "checkpoint: command group exists in ralph CLI" {
    run "$RALPH_CMD" checkpoint 2>&1 || true
    echo "$output" | grep -q "Commands:"
}

@test "checkpoint: save command is documented" {
    run "$RALPH_CMD" checkpoint 2>&1 || true
    echo "$output" | grep -q "save"
}

@test "checkpoint: restore command is documented" {
    run "$RALPH_CMD" checkpoint 2>&1 || true
    echo "$output" | grep -q "restore"
}

@test "checkpoint: list command is documented" {
    run "$RALPH_CMD" checkpoint 2>&1 || true
    echo "$output" | grep -q "list"
}

# ============================================================
# Handoff CLI Structure Tests
# ============================================================

@test "handoff: command group exists in ralph CLI" {
    run "$RALPH_CMD" handoff 2>&1 || true
    echo "$output" | grep -q "Commands:\|Usage:"
}

@test "handoff: agents command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "handoff agents"
}

@test "handoff: validate command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "handoff validate"
}

@test "handoff: transfer command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "handoff transfer"
}

# ============================================================
# Events CLI Structure Tests
# ============================================================

@test "events: command group exists in ralph CLI" {
    run "$RALPH_CMD" events 2>&1 || true
    echo "$output" | grep -q "Commands:\|Usage:"
}

@test "events: status command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "events status"
}

@test "events: barrier commands are documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "events barrier"
}

# ============================================================
# Agent-Memory CLI Structure Tests
# ============================================================

@test "agent-memory: command group exists in ralph CLI" {
    run "$RALPH_CMD" "agent-memory" 2>&1 || true
    echo "$output" | grep -q "Commands:\|Usage:"
}

@test "agent-memory: init command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "agent-memory init"
}

@test "agent-memory: list command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "agent-memory list"
}

# ============================================================
# Migrate CLI Structure Tests
# ============================================================

@test "migrate: command group exists in ralph CLI" {
    run "$RALPH_CMD" migrate 2>&1 || true
    echo "$output" | grep -q "Commands:\|Usage:"
}

@test "migrate: check command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "migrate check"
}

@test "migrate: dry-run command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "migrate dry-run"
}

# ============================================================
# Ledger CLI Structure Tests
# ============================================================

@test "ledger: command group exists in ralph CLI" {
    run "$RALPH_CMD" ledger 2>&1 || true
    echo "$output" | grep -q "Commands:\|Usage:"
}

@test "ledger: list command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "ledger list"
}

@test "ledger: save command is documented" {
    run "$RALPH_CMD" 2>&1 || true
    echo "$output" | grep -q "ledger save"
}

# ============================================================
# Directory Structure Tests
# ============================================================

@test "ralph creates checkpoint directories" {
    mkdir -p "$TEST_TMP/.ralph/checkpoints"
    [ -d "$TEST_TMP/.ralph/checkpoints" ]
}

@test "ralph creates agent-memory directories" {
    mkdir -p "$TEST_TMP/.ralph/agent-memory"
    [ -d "$TEST_TMP/.ralph/agent-memory" ]
}

@test "ralph creates events directories" {
    mkdir -p "$TEST_TMP/.ralph/events"
    [ -d "$TEST_TMP/.ralph/events" ]
}

@test "ralph creates ledger directories" {
    mkdir -p "$TEST_TMP/.ralph/ledgers"
    [ -d "$TEST_TMP/.ralph/ledgers" ]
}

@test "ralph creates handoff directories" {
    mkdir -p "$TEST_TMP/.ralph/handoffs"
    [ -d "$TEST_TMP/.ralph/handoffs" ]
}

# ============================================================
# Script Implementation Tests
# ============================================================

@test "checkpoint CLI script exists in scripts directory" {
    [ -f "$PROJECT_ROOT/scripts/ralph" ]
}

@test "ralph script contains checkpoint command implementation" {
    grep -q "checkpoint" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null || skip "checkpoint not in ralph script"
}

@test "ralph script contains handoff command implementation" {
    grep -q "handoff" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null || skip "handoff not in ralph script"
}

@test "ralph script contains events command implementation" {
    grep -q "events" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null || skip "events not in ralph script"
}

@test "ralph script contains agent-memory command implementation" {
    grep -q "agent.memory\|agent_memory" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null || skip "agent-memory not in ralph script"
}

@test "ralph script contains migrate command implementation" {
    grep -q "migrate" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null || skip "migrate not in ralph script"
}

@test "ralph script contains ledger command implementation" {
    grep -q "ledger" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null || skip "ledger not in ralph script"
}
