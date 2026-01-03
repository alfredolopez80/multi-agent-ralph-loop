#!/usr/bin/env bats
# test_tool_validation.bats - Tests for v2.22 tool validation functions
# Tests startup_validation(), require_tool(), require_tools() and tool arrays

setup() {
    RALPH_SCRIPT="$(dirname "$BATS_TEST_FILENAME")/../scripts/ralph"
    export RALPH_STARTUP_SHOWN=""  # Reset session flag for each test
}

# ============================================================================
# Version Tests
# ============================================================================

@test "version is 2.22" {
    run grep 'VERSION="2.22.0"' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "ralph version command outputs 2.22" {
    run bash "$RALPH_SCRIPT" version
    [[ "$output" == *"2.22"* ]]
}

# ============================================================================
# Tool Array Definition Tests
# ============================================================================

@test "CRITICAL_TOOLS array defined" {
    run grep -q 'CRITICAL_TOOLS=(' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "FEATURE_TOOLS array defined" {
    run grep -q 'FEATURE_TOOLS=(' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "QUALITY_GATE_TOOLS array defined" {
    run grep -q 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "CRITICAL_TOOLS contains claude" {
    run grep -A5 'CRITICAL_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"claude:"* ]]
}

@test "CRITICAL_TOOLS contains jq" {
    run grep -A5 'CRITICAL_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"jq:"* ]]
}

@test "CRITICAL_TOOLS contains git" {
    run grep -A5 'CRITICAL_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"git:"* ]]
}

@test "FEATURE_TOOLS contains wt" {
    run grep -A10 'FEATURE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"wt:"* ]]
}

@test "FEATURE_TOOLS contains gh" {
    run grep -A10 'FEATURE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"gh:"* ]]
}

@test "FEATURE_TOOLS contains mmc" {
    run grep -A10 'FEATURE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"mmc:"* ]]
}

@test "QUALITY_GATE_TOOLS contains pyright (Python)" {
    run grep -A20 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"pyright:"* ]]
}

@test "QUALITY_GATE_TOOLS contains ruff (Python)" {
    run grep -A20 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"ruff:"* ]]
}

@test "QUALITY_GATE_TOOLS contains staticcheck (Go)" {
    run grep -A20 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"staticcheck:"* ]]
}

@test "QUALITY_GATE_TOOLS contains cargo (Rust)" {
    run grep -A20 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"cargo:"* ]]
}

@test "QUALITY_GATE_TOOLS contains forge (Solidity)" {
    run grep -A20 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"forge:"* ]]
}

@test "QUALITY_GATE_TOOLS contains swiftlint (Swift)" {
    run grep -A25 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"swiftlint:"* ]]
}

@test "QUALITY_GATE_TOOLS contains yamllint (YAML)" {
    run grep -A25 'QUALITY_GATE_TOOLS=(' "$RALPH_SCRIPT"
    [[ "$output" == *"yamllint:"* ]]
}

# ============================================================================
# Function Definition Tests
# ============================================================================

@test "startup_validation function exists" {
    run grep -q 'startup_validation()' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "require_tool function exists" {
    run grep -q 'require_tool()' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "require_tools function exists" {
    run grep -q 'require_tools()' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================================
# Startup Validation Behavior Tests
# ============================================================================

@test "help command skips startup validation" {
    run bash "$RALPH_SCRIPT" help
    [ "$status" -eq 0 ]
}

@test "version command skips startup validation" {
    run bash "$RALPH_SCRIPT" version
    [ "$status" -eq 0 ]
}

@test "status command skips startup validation" {
    run bash "$RALPH_SCRIPT" status
    [ "$status" -eq 0 ]
}

# ============================================================================
# require_tool Integration Tests
# ============================================================================

@test "cmd_worktree calls require_tool for wt" {
    run grep -A3 'cmd_worktree()' "$RALPH_SCRIPT"
    [[ "$output" == *"require_tool"* ]] || [[ "$output" == *"wt"* ]]
}

@test "cmd_worktree_pr calls require_tools for wt and gh" {
    run grep -A3 'cmd_worktree_pr()' "$RALPH_SCRIPT"
    [[ "$output" == *"require_tools"* ]]
}

@test "cmd_minimax calls require_tool for mmc" {
    run grep -A3 'cmd_minimax()' "$RALPH_SCRIPT"
    [[ "$output" == *"require_tool"* ]] && [[ "$output" == *"mmc"* ]]
}

@test "cmd_adversarial calls require_tools for codex and gemini" {
    run grep -A3 'cmd_adversarial()' "$RALPH_SCRIPT"
    [[ "$output" == *"require_tools"* ]]
}

# ============================================================================
# Error Message Format Tests
# ============================================================================

@test "require_tool outputs ASCII box on missing tool" {
    run grep -A30 'require_tool()' "$RALPH_SCRIPT"
    [[ "$output" == *"MISSING"* ]] || [[ "$output" == *"ERROR"* ]]
}

@test "require_tools outputs ASCII box on missing tools" {
    run grep -A30 'require_tools()' "$RALPH_SCRIPT"
    [[ "$output" == *"MISSING"* ]] || [[ "$output" == *"ERROR"* ]]
}

# ============================================================================
# Main Function Integration Tests
# ============================================================================

@test "main calls startup_validation for non-skip commands" {
    run grep -A10 'main()' "$RALPH_SCRIPT"
    [[ "$output" == *"startup_validation"* ]]
}

@test "main skips validation for help command" {
    run grep -A10 'main()' "$RALPH_SCRIPT"
    [[ "$output" == *"help"* ]] && [[ "$output" == *"version"* ]]
}
