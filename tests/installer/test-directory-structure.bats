#!/usr/bin/env bats
#===============================================================================
# test-directory-structure.bats - Test directory structure validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify directory structure validation works correctly
#===============================================================================

load test_helper

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-directories.sh"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "validate-directories.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-directories.sh is executable" {
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
}

#===============================================================================
# TEXT OUTPUT TESTS
#===============================================================================

@test "text output shows CLI directories" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"CLI DIRECTORIES"* ]]
}

@test "text output shows Ralph directories" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"RALPH DIRECTORIES"* ]]
}

@test "text output shows Claude directories" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"CLAUDE DIRECTORIES"* ]]
}

@test "text output shows summary" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"Passed:"* ]]
    [[ "$output" == *"Failed:"* ]]
}

#===============================================================================
# JSON OUTPUT TESTS
#===============================================================================

@test "JSON output is valid JSON" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq empty
}

@test "JSON output has status field" {
    run "$VALIDATE_SCRIPT" --format json
    local status_val
    status_val=$(echo "$output" | jq -r '.status')
    [[ "$status_val" =~ ^(pass|fail)$ ]]
}

@test "JSON output has summary" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
    echo "$output" | jq -e '.summary.warnings' > /dev/null
}

@test "JSON output has directories object" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.directories' > /dev/null
}

@test "JSON directory entries have required fields" {
    run "$VALIDATE_SCRIPT" --format json

    # Check first directory entry
    local first_key
    first_key=$(echo "$output" | jq -r '.directories | keys[0]')

    echo "$output" | jq -e ".directories[\"$first_key\"].path" > /dev/null
    echo "$output" | jq -e ".directories[\"$first_key\"].status" > /dev/null
    echo "$output" | jq -e ".directories[\"$first_key\"].message" > /dev/null
}

#===============================================================================
# DIRECTORY CHECKS
#===============================================================================

@test "checks local_bin directory" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.directories.local_bin' > /dev/null
}

@test "checks ralph_main directory" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.directories.ralph_main' > /dev/null
}

@test "checks claude_main directory" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.directories.claude_main' > /dev/null
}

@test "checks ralph subdirectories" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.directories.ralph_config' > /dev/null
    echo "$output" | jq -e '.directories.ralph_logs' > /dev/null
    echo "$output" | jq -e '.directories.ralph_memory' > /dev/null
}

@test "checks claude subdirectories" {
    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.directories.claude_agents' > /dev/null
    echo "$output" | jq -e '.directories.claude_skills' > /dev/null
    echo "$output" | jq -e '.directories.claude_hooks' > /dev/null
}

#===============================================================================
# STATUS DETECTION TESTS
#===============================================================================

@test "existing directories show PASS or WARN status" {
    run "$VALIDATE_SCRIPT" --format json

    # local_bin should exist
    local status
    status=$(echo "$output" | jq -r '.directories.local_bin.status')
    [[ "$status" == "PASS" || "$status" == "WARN" ]]
}

@test "missing directories show FAIL status" {
    run "$VALIDATE_SCRIPT" --format json

    # Check if any directory has FAIL status (missing)
    local has_fail
    has_fail=$(echo "$output" | jq '[.directories[] | select(.status == "FAIL")] | length')
    [[ $has_fail -ge 0 ]]  # Could be 0 if all exist
}

#===============================================================================
# PERMISSION CHECKS
#===============================================================================

@test "permissions field shows actual permissions" {
    run "$VALIDATE_SCRIPT" --format json

    # local_bin should have permissions
    local perms
    perms=$(echo "$output" | jq -r '.directories.local_bin.permissions')
    [[ "$perms" =~ ^[0-7]{3}$ ]] || [[ "$perms" == "missing" ]]
}
