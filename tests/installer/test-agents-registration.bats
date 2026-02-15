#!/usr/bin/env bats
#===============================================================================
# test-agents-registration.bats - Test agents registration validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify agents registration validation works correctly
#===============================================================================

load test_helper

ORIGINAL_HOME="${HOME}"

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-agents-registration.sh"
}

teardown() {
    teardown_installer_test
}

@test "validate-agents-registration.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-agents-registration.sh is executable" {
    assert_executable "$VALIDATE_SCRIPT"
}

@test "help flag shows usage" {
    run "$VALIDATE_SCRIPT" --help
    [[ $status -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
}

@test "JSON output is valid JSON" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq empty
}

@test "JSON output has status field" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    local status_val
    status_val=$(echo "$output" | jq -r '.status')
    [[ "$status_val" =~ ^(pass|fail)$ ]]
}

@test "JSON output has summary" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
}

@test "JSON output has agents object" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.agents' > /dev/null
}

@test "validates ralph-coder agent" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.agents["ralph-coder"]' > /dev/null
}

@test "validates ralph-reviewer agent" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.agents["ralph-reviewer"]' > /dev/null
}

@test "validates ralph-tester agent" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.agents["ralph-tester"]' > /dev/null
}

@test "validates ralph-researcher agent" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.agents["ralph-researcher"]' > /dev/null
}

@test "text output shows summary" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
}
