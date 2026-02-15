#!/usr/bin/env bats
#===============================================================================
# test-skills-registration.bats - Test skills registration validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify skills registration validation works correctly
#===============================================================================

load test_helper

ORIGINAL_HOME="${HOME}"

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-skills-registration.sh"
}

teardown() {
    teardown_installer_test
}

@test "validate-skills-registration.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-skills-registration.sh is executable" {
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

@test "JSON output has skills object" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.skills' > /dev/null
}

@test "validates orchestrator skill" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.skills.orchestrator' > /dev/null
}

@test "validates loop skill" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.skills.loop' > /dev/null
}

@test "validates gates skill" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.skills.gates' > /dev/null
}

@test "validates task-batch skill" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.skills["task-batch"]' > /dev/null
}

@test "text output shows summary" {
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
}
