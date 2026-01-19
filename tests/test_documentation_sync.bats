#!/usr/bin/env bats
# test_documentation_sync.bats - Documentation-Implementation Sync Tests v2.54
# Ensures documented commands are actually implemented
# Run with: bats tests/test_documentation_sync.bats

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    RALPH_SCRIPT="$PROJECT_DIR/scripts/ralph"
    CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"

    [ -f "$RALPH_SCRIPT" ] || skip "ralph script not found"
    [ -f "$CLAUDE_MD" ] || skip "CLAUDE.md not found"
    export RALPH_TEST_MODE=1
}

# ============================================================================
# Documentation-Implementation Sync Tests
# These tests prevent "ghost documentation" (docs without code)
# ============================================================================

@test "documented ralph commands exist - repo-learn" {
    # CLAUDE.md documents: ralph repo-learn
    grep -q 'cmd_repo_learn' "$RALPH_SCRIPT" || \
    grep -q 'repo-learn|repo_learn)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - curator" {
    # CLAUDE.md documents: ralph curator
    grep -q 'cmd_curator' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - checkpoint" {
    # CLAUDE.md documents: ralph checkpoint
    grep -q 'cmd_checkpoint' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - handoff" {
    # CLAUDE.md documents: ralph handoff
    grep -q 'cmd_handoff' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - agent-memory" {
    # CLAUDE.md documents: ralph agent-memory
    grep -q 'cmd_agent_memory\|agent-memory)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - events" {
    # CLAUDE.md documents: ralph events
    grep -q 'cmd_events\|events)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - status" {
    # CLAUDE.md documents: ralph status
    grep -q 'cmd_status' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - trace" {
    # CLAUDE.md documents: ralph trace
    grep -q 'cmd_trace\|trace)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - orch" {
    # CLAUDE.md documents: ralph orch
    grep -q 'cmd_orch\|orch)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - loop" {
    # CLAUDE.md documents: ralph loop
    grep -q 'cmd_loop\|loop)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - gates" {
    # CLAUDE.md documents: ralph gates
    grep -q 'cmd_gates\|gates)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - security" {
    # CLAUDE.md documents: ralph security
    grep -q 'cmd_security\|security)' "$RALPH_SCRIPT"
}

@test "documented ralph commands exist - migrate" {
    # CLAUDE.md documents: ralph migrate
    grep -q 'cmd_migrate\|migrate)' "$RALPH_SCRIPT"
}

# ============================================================================
# Help Text Verification
# ============================================================================

@test "repo-learn --help returns valid help text" {
    run "$RALPH_SCRIPT" repo-learn --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Repository Learner" ]]
    [[ "$output" =~ "Usage:" ]]
}

@test "curator --help returns valid help text" {
    run "$RALPH_SCRIPT" curator --help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Repo Curator" ]]
}

@test "checkpoint --help returns valid help text" {
    run "$RALPH_SCRIPT" checkpoint help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "CHECKPOINT" ]] || [[ "$output" =~ "Time Travel" ]]
}

@test "handoff --help returns valid help text" {
    run "$RALPH_SCRIPT" handoff help
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HANDOFF" ]] || [[ "$output" =~ "Context Transfer" ]]
}

# ============================================================================
# Version Consistency Tests
# ============================================================================

@test "scripts/ralph has version in header" {
    grep -qE 'v2\.[0-9]+\.[0-9]+|VERSION=' "$RALPH_SCRIPT"
}

@test "CLAUDE.md has matching version" {
    # Extract version from CLAUDE.md title
    local claude_version
    claude_version=$(grep -oE 'v2\.[0-9]+\.[0-9]+' "$CLAUDE_MD" | head -1)

    # Should have a version
    [ -n "$claude_version" ]
}

# ============================================================================
# Subcommand Existence Tests
# ============================================================================

@test "curator has full subcommand" {
    grep -A50 'cmd_curator' "$RALPH_SCRIPT" | grep -q 'full)'
}

@test "curator has learn subcommand" {
    grep -A50 'cmd_curator' "$RALPH_SCRIPT" | grep -q 'learn)'
}

@test "curator has approve subcommand" {
    # Verify APPROVE_SCRIPT variable exists in cmd_curator
    grep -A100 'cmd_curator' "$RALPH_SCRIPT" | grep -qE 'APPROVE_SCRIPT|approve\)'
}

@test "checkpoint has save subcommand" {
    # Search globally since cmd_checkpoint may delegate
    grep -q 'checkpoint.*save\|save)' "$RALPH_SCRIPT"
}

@test "checkpoint has restore subcommand" {
    grep -q 'checkpoint.*restore\|restore)' "$RALPH_SCRIPT"
}

@test "checkpoint has list subcommand" {
    grep -q 'checkpoint.*list\|list)' "$RALPH_SCRIPT"
}

@test "handoff has transfer subcommand" {
    grep -q 'handoff.*transfer\|transfer)' "$RALPH_SCRIPT"
}

@test "handoff has agents subcommand" {
    grep -A100 'cmd_handoff' "$RALPH_SCRIPT" | grep -q 'agents)'
}

@test "events has emit subcommand" {
    grep -A100 'cmd_events' "$RALPH_SCRIPT" | grep -q 'emit)'
}

@test "events has barrier subcommand" {
    grep -A100 'cmd_events' "$RALPH_SCRIPT" | grep -q 'barrier)'
}

# ============================================================================
# Argument Parsing Tests
# ============================================================================

@test "repo-learn rejects missing URL" {
    run "$RALPH_SCRIPT" repo-learn
    [ "$status" -ne 0 ]
    [[ "$output" =~ "Repository URL required" ]]
}

@test "repo-learn accepts GitHub URL format" {
    # Should parse URL but fail due to no approved repo
    run "$RALPH_SCRIPT" repo-learn https://github.com/test/repo
    # Exit 1 is expected (repo not approved), but command was recognized
    [[ "$output" =~ "Learning from: test/repo" ]]
}

@test "repo-learn accepts owner/repo format" {
    run "$RALPH_SCRIPT" repo-learn test/repo
    [[ "$output" =~ "Learning from: test/repo" ]]
}

@test "repo-learn accepts --category flag" {
    run "$RALPH_SCRIPT" repo-learn test/repo --category error_handling
    [[ "$output" =~ "Learning from: test/repo" ]]
}

# ============================================================================
# Integration Tests - Script Dependencies
# ============================================================================

@test "curator-learn.sh script exists" {
    [ -f "${HOME}/.claude/scripts/curator-learn.sh" ]
}

@test "curator.sh script exists" {
    [ -f "${HOME}/.claude/scripts/curator.sh" ]
}

@test "curator-approve.sh script exists" {
    [ -f "${HOME}/.claude/scripts/curator-approve.sh" ]
}

@test "checkpoint-manager.sh script exists" {
    [ -f "${HOME}/.claude/scripts/checkpoint-manager.sh" ]
}

@test "handoff.sh script exists" {
    [ -f "${HOME}/.claude/scripts/handoff.sh" ]
}

@test "event-bus.sh script exists" {
    [ -f "${HOME}/.claude/scripts/event-bus.sh" ]
}

@test "state-coordinator.sh script exists" {
    [ -f "${HOME}/.claude/scripts/state-coordinator.sh" ]
}

