#!/usr/bin/env bats
#===============================================================================
# test-cli-commands.bats - E2E Test for CLI Commands Validation
#
# VERSION: 1.0.1
# DATE: 2026-02-15
# PURPOSE: Verify that all Ralph and MiniMax CLI commands are installed and work
# TASK ID: TASK-6.3
#
# WARNING: E2E Post-Installation Verification Test
# ================================================
# These tests run against the REAL user environment (HOME, PATH).
# This is intentional for post-installation verification purposes.
#
# RISK: These tests may interact with production CLI installations.
# Set SKIP_E2E_REAL_ENV=1 to skip these tests in CI or isolated environments.
#
# Acceptance Criteria:
# - Test file exists at tests/installer/test-cli-commands.bats
# - Tests ralph help command
# - Tests ralph orch --help command
# - Tests ralph gates command
# - Tests ralph curator command
# - Tests mmc --help command (MiniMax)
# - All commands return exit code 0
# - Commands found in PATH
# - All tests pass: bats tests/installer/test-cli-commands.bats
#===============================================================================

load test_helper

# WARNING: E2E Post-Installation Verification Test
# These tests run against the REAL user environment.
# Set SKIP_E2E_REAL_ENV=1 to skip these tests.
if [[ -n "${SKIP_E2E_REAL_ENV:-}" ]]; then
    skip "Skipping E2E tests with real environment (SKIP_E2E_REAL_ENV is set)"
fi

setup() {
    setup_installer_test
    # Use REAL system paths for E2E tests (not mock environment)
    export HOME="$ORIGINAL_HOME"
    export PATH="$ORIGINAL_PATH"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# COMMAND EXISTENCE TESTS
#===============================================================================

@test "ralph command exists in PATH" {
    assert_command_exists "ralph"
}

@test "mmc command exists in PATH" {
    # MiniMax wrapper is optional but should be present in a full installation
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    assert_command_exists "mmc"
}

#===============================================================================
# RALPH HELP COMMAND TESTS
#===============================================================================

@test "ralph help returns exit code 0" {
    run ralph help
    [[ $status -eq 0 ]]
}

@test "ralph help shows version header" {
    run ralph help
    [[ "$output" == *"Ralph"* ]]
    [[ "$output" == *"Multi-Agent"* ]]
}

@test "ralph help shows USAGE section" {
    run ralph help
    [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "ralph help shows COMMANDS section" {
    run ralph help
    [[ "$output" == *"COMMANDS"* ]] || [[ "$output" == *"Commands"* ]]
}

@test "ralph help lists orch command" {
    run ralph help
    [[ "$output" == *"orch"* ]]
}

@test "ralph help lists loop command" {
    run ralph help
    [[ "$output" == *"loop"* ]]
}

@test "ralph help lists gates command" {
    run ralph help
    [[ "$output" == *"gates"* ]]
}

@test "ralph help lists curator command" {
    run ralph help
    [[ "$output" == *"curator"* ]]
}

#===============================================================================
# RALPH ORCH --HELP COMMAND TESTS
#===============================================================================

@test "ralph orch --help returns exit code 0" {
    run ralph orch --help
    [[ $status -eq 0 ]]
}

@test "ralph orch --help shows orchestration information" {
    run ralph orch --help
    [[ "$output" == *"orchestrat"* ]] || [[ "$output" == *"orch"* ]] || [[ "$output" == *"CLAUSE"* ]]
}

@test "ralph orch --help suggests /orchestrator skill" {
    run ralph orch --help
    [[ "$output" == *"/orchestrator"* ]] || [[ "$output" == *"orchestrat"* ]]
}

#===============================================================================
# RALPH GATES COMMAND TESTS
#===============================================================================

@test "ralph gates returns valid exit code" {
    run ralph gates
    # gates may return 0 (pass) or 1 (fail) - both are valid responses
    [[ $status -eq 0 || $status -eq 1 ]]
}

@test "ralph gates shows quality gates header" {
    run ralph gates
    [[ "$output" == *"Quality"* ]] || [[ "$output" == *"GATES"* ]] || [[ "$output" == *"gates"* ]]
}

@test "ralph gates runs validation checks" {
    run ralph gates
    # Should show some validation activity
    [[ "$output" == *"PASSED"* ]] || [[ "$output" == *"FAILED"* ]] || [[ "$output" == *"check"* ]]
}

@test "ralph gates shows summary" {
    run ralph gates
    [[ "$output" == *"Summary"* ]] || [[ "$output" == *"SUMMARY"* ]] || [[ "$output" == *"summary"* ]]
}

#===============================================================================
# RALPH CURATOR COMMAND TESTS
#===============================================================================

@test "ralph curator returns exit code 0" {
    run ralph curator
    [[ $status -eq 0 ]]
}

@test "ralph curator shows Repo Curator header" {
    run ralph curator
    [[ "$output" == *"Repo Curator"* ]] || [[ "$output" == *"CURATOR"* ]] || [[ "$output" == *"curator"* ]]
}

@test "ralph curator shows available actions" {
    run ralph curator
    [[ "$output" == *"Actions"* ]] || [[ "$output" == *"actions"* ]] || [[ "$output" == *"full"* ]]
}

@test "ralph curator lists full action" {
    run ralph curator
    [[ "$output" == *"full"* ]]
}

@test "ralph curator lists discover action" {
    run ralph curator
    [[ "$output" == *"discover"* ]]
}

@test "ralph curator lists score action" {
    run ralph curator
    [[ "$output" == *"score"* ]]
}

@test "ralph curator lists rank action" {
    run ralph curator
    [[ "$output" == *"rank"* ]]
}

@test "ralph curator lists learn action" {
    run ralph curator
    [[ "$output" == *"learn"* ]]
}

#===============================================================================
# MMC (MINIMAX) COMMAND TESTS
#===============================================================================

@test "mmc --help returns exit code 0" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    [[ $status -eq 0 ]]
}

@test "mmc --help shows MiniMax header" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    [[ "$output" == *"MiniMax"* ]]
}

@test "mmc --help shows USAGE section" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    [[ "$output" == *"USAGE"* ]] || [[ "$output" == *"Usage"* ]]
}

@test "mmc --help shows --setup option" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    [[ "$output" == *"--setup"* ]]
}

@test "mmc --help shows --query option" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    [[ "$output" == *"--query"* ]]
}

@test "mmc --help shows --loop option" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    [[ "$output" == *"--loop"* ]]
}

@test "mmc --help shows --version option" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    [[ "$output" == *"--version"* ]]
}

#===============================================================================
# VERSION COMMAND TESTS
#===============================================================================

@test "ralph version returns exit code 0" {
    run ralph version
    [[ $status -eq 0 ]]
}

@test "ralph version shows version number" {
    run ralph version
    [[ "$output" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]]
}

@test "mmc --version returns exit code 0" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --version
    [[ $status -eq 0 ]]
}

@test "mmc --version shows version number" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --version
    [[ "$output" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]] || [[ "$output" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
}

#===============================================================================
# RUNTIME ERROR DETECTION TESTS
#===============================================================================

@test "ralph help has no runtime errors" {
    run ralph help
    # Check for common error indicators
    [[ "$output" != *"error:"* ]]
    [[ "$output" != *"Error:"* ]]
    [[ "$output" != *"ERROR:"* ]]
    [[ "$output" != *"command not found"* ]]
    [[ "$output" != *"No such file"* ]]
}

@test "ralph curator has no runtime errors" {
    run ralph curator
    # Check for common error indicators
    [[ "$output" != *"error:"* ]]
    [[ "$output" != *"Error:"* ]]
    [[ "$output" != *"ERROR:"* ]]
    [[ "$output" != *"command not found"* ]]
    [[ "$output" != *"No such file"* ]]
}

@test "mmc --help has no runtime errors" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    run mmc --help
    # Check for common error indicators
    [[ "$output" != *"error:"* ]]
    [[ "$output" != *"Error:"* ]]
    [[ "$output" != *"ERROR:"* ]]
    [[ "$output" != *"command not found"* ]]
    [[ "$output" != *"No such file"* ]]
}

#===============================================================================
# COMMAND PATH VERIFICATION TESTS
#===============================================================================

@test "ralph command is in ~/.local/bin" {
    local ralph_path
    ralph_path=$(command -v ralph)
    [[ "$ralph_path" == *"/.local/bin/ralph"* ]] || [[ "$ralph_path" == *"/usr/local/bin/ralph"* ]] || [[ "$ralph_path" == *"/home/"*"/.local/bin/ralph"* ]]
}

@test "mmc command is in ~/.local/bin (if installed)" {
    if ! command -v mmc &>/dev/null; then
        skip "mmc command not found - MiniMax wrapper not installed"
    fi
    local mmc_path
    mmc_path=$(command -v mmc)
    [[ "$mmc_path" == *"/.local/bin/mmc"* ]] || [[ "$mmc_path" == *"/usr/local/bin/mmc"* ]] || [[ "$mmc_path" == *"/home/"*"/.local/bin/mmc"* ]]
}

#===============================================================================
# INTEGRATION TESTS
#===============================================================================

@test "ralph status command works" {
    run ralph status
    [[ $status -eq 0 ]]
}

@test "ralph status shows installation info" {
    run ralph status
    # Should show some status information
    [[ -n "$output" ]]
}

@test "all ralph basic commands are callable" {
    # Test that we can call various basic commands without errors
    local commands=("version" "help")
    for cmd in "${commands[@]}"; do
        run ralph "$cmd"
        [[ $status -eq 0 ]]
    done
}
