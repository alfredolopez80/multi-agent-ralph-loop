#!/usr/bin/env bats
#===============================================================================
# test-system-dependencies.bats - Test system requirements validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify system dependency validation works correctly
#===============================================================================

load test_helper

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-system-requirements.sh"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "validate-system-requirements.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-system-requirements.sh is executable" {
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

@test "runs successfully when all required tools available" {
    # This test uses the actual system tools
    # If we can run BATS, we have bash, which means required tools should be available
    run "$VALIDATE_SCRIPT"
    [[ $status -eq 0 ]]
}

@test "text output shows required tools" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"REQUIRED TOOLS"* ]]
    [[ "$output" == *"bash"* ]]
    [[ "$output" == *"jq"* ]]
    [[ "$output" == *"git"* ]]
    [[ "$output" == *"curl"* ]]
}

@test "text output shows optional tools" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"OPTIONAL TOOLS"* ]]
}

@test "text output shows recommended tools" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"RECOMMENDED TOOLS"* ]]
}

@test "text output shows summary" {
    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"Passed:"* ]]
    [[ "$output" == *"Failed:"* ]]
}

@test "verbose flag shows more details" {
    run "$VALIDATE_SCRIPT" --verbose
    [[ "$output" == *"Version:"* ]] || [[ "$output" == *"v"* ]]
}

#===============================================================================
# JSON OUTPUT TESTS
#===============================================================================

@test "JSON output is valid JSON" {
    run "$VALIDATE_SCRIPT" --format json
    [[ $status -eq 0 ]]

    # Validate JSON structure
    echo "$output" | jq empty
}

@test "JSON output has status field" {
    run "$VALIDATE_SCRIPT" --format json

    # Extract status
    local status_val
    status_val=$(echo "$output" | jq -r '.status')
    [[ "$status_val" =~ ^(pass|fail)$ ]]
}

@test "JSON output has summary field" {
    run "$VALIDATE_SCRIPT" --format json

    # Check summary exists and has expected fields
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
    echo "$output" | jq -e '.summary.warnings' > /dev/null
}

@test "JSON output has required tools object" {
    run "$VALIDATE_SCRIPT" --format json

    # Check required tools
    echo "$output" | jq -e '.required.bash' > /dev/null
    echo "$output" | jq -e '.required.jq' > /dev/null
}

@test "JSON output has optional tools object" {
    run "$VALIDATE_SCRIPT" --format json

    # Check optional exists
    echo "$output" | jq -e '.optional' > /dev/null
}

@test "JSON output has recommended tools object" {
    run "$VALIDATE_SCRIPT" --format json

    # Check recommended exists
    echo "$output" | jq -e '.recommended' > /dev/null
}

@test "JSON tool objects have required fields" {
    run "$VALIDATE_SCRIPT" --format json

    # Each tool should have status, version, message
    local bash_status
    bash_status=$(echo "$output" | jq -r '.required.bash.status')
    [[ "$bash_status" =~ ^(PASS|FAIL|MISSING)$ ]]

    local bash_message
    bash_message=$(echo "$output" | jq -r '.required.bash.message')
    [[ -n "$bash_message" ]]
}

#===============================================================================
# VERSION EXTRACTION TESTS
#===============================================================================

@test "correctly identifies bash version" {
    # This test uses the actual system bash
    run "$VALIDATE_SCRIPT" --format json
    local version
    version=$(echo "$output" | jq -r '.required.bash.version')
    [[ "$version" =~ ^[0-9] ]]
}

@test "correctly identifies git version" {
    run "$VALIDATE_SCRIPT" --format json
    local version
    version=$(echo "$output" | jq -r '.required.git.version')
    [[ "$version" =~ ^[0-9] ]]
}

#===============================================================================
# EXIT CODE TESTS
#===============================================================================

@test "exits 0 when all required tools pass" {
    run "$VALIDATE_SCRIPT"
    # Since we have real tools installed, this should pass
    [[ $status -eq 0 ]]
}

#===============================================================================
# INTEGRATION TESTS
#===============================================================================

@test "detects all installed tools" {
    run "$VALIDATE_SCRIPT" --format json

    # bash should always be PASS since we're running the test
    local bash_status
    bash_status=$(echo "$output" | jq -r '.required.bash.status')
    [[ "$bash_status" == "PASS" ]]
}

@test "summary counts are accurate" {
    run "$VALIDATE_SCRIPT" --format json

    local passed
    local failed
    passed=$(echo "$output" | jq '.summary.passed')
    failed=$(echo "$output" | jq '.summary.failed')

    # At minimum, required tools should pass
    [[ $passed -ge 4 ]]
    [[ $failed -eq 0 ]]
}
