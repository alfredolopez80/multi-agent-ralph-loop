#!/usr/bin/env bats
#===============================================================================
# test-shell-environment.bats - Test shell environment validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify shell environment validation works correctly
#===============================================================================

load test_helper

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-shell-config.sh"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "validate-shell-config.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-shell-config.sh is executable" {
    assert_executable "$VALIDATE_SCRIPT"
}

#===============================================================================
# HELP OUTPUT TESTS
#===============================================================================

@test "help flag shows usage" {
    run "$VALIDATE_SCRIPT" --help
    [[ $status -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--format"* ]]
    [[ "$output" == *"--verbose"* ]]
}

#===============================================================================
# TEXT OUTPUT TESTS
#===============================================================================

@test "text output shows shell type" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"Shell:"* ]]
}

@test "text output shows RC file" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"RC File:"* ]]
}

@test "text output shows checks section" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"CHECKS"* ]]
}

@test "text output shows summary" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"Passed:"* ]]
    [[ "$output" == *"Warnings:"* ]]
}

#===============================================================================
# JSON OUTPUT TESTS
#===============================================================================

@test "JSON output is valid JSON" {
    run "$VALIDATE_SCRIPT" --format json
    [[ $status -eq 0 ]]
    echo "$output" | jq empty
}

@test "JSON output has status field" {
    run "$VALIDATE_SCRIPT" --format json
    local status_val
    status_val=$(echo "$output" | jq -r '.status')
    [[ "$status_val" =~ ^(pass|fail)$ ]]
}

@test "JSON output has shell info" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.shell.type' > /dev/null
    echo "$output" | jq -e '.shell.rc_file' > /dev/null
}

@test "JSON output has summary" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
    echo "$output" | jq -e '.summary.warnings' > /dev/null
}

@test "JSON output has checks" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks' > /dev/null
}

#===============================================================================
# CHECK VALIDATION TESTS
#===============================================================================

@test "detects PATH check" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.path_local_bin' > /dev/null
}

@test "detects RC file check" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.rc_file_exists' > /dev/null
}

@test "detects shell version check" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.shell_version' > /dev/null
}

@test "detects ralph aliases check" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.ralph_aliases' > /dev/null
}

@test "detects minimax aliases check" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.minimax_aliases' > /dev/null
}

@test "detects claude env check" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.claude_env' > /dev/null
}

#===============================================================================
# EXIT CODE TESTS
#===============================================================================

@test "exits 0 when no failures (with json to verify status)" {
    # The script should pass (no FAIL status, only PASS and WARN)
    run "$VALIDATE_SCRIPT" --format json

    # Check JSON status
    local json_status
    json_status=$(echo "$output" | jq -r '.status')

    # If status is pass, exit code should be 0
    if [[ "$json_status" == "pass" ]]; then
        [[ $status -eq 0 ]]
    fi
}

#===============================================================================
# SHELL DETECTION TESTS
#===============================================================================

@test "correctly detects current shell" {
    run "$VALIDATE_SCRIPT" --format json
    local shell_type
    shell_type=$(echo "$output" | jq -r '.shell.type')
    [[ "$shell_type" =~ ^(bash|zsh|sh)$ ]]
}

@test "correctly identifies RC file path" {
    run "$VALIDATE_SCRIPT" --format json
    local rc_file
    rc_file=$(echo "$output" | jq -r '.shell.rc_file')
    [[ "$rc_file" == *".zshrc" ]] || [[ "$rc_file" == *".bashrc" ]] || [[ "$rc_file" == *".profile" ]]
}
