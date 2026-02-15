#!/usr/bin/env bats
#===============================================================================
# test-settings-structure.bats - Test settings structure validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify settings structure validation works correctly
#===============================================================================

load test_helper

# Store original HOME for tests that need real settings
ORIGINAL_HOME="${HOME}"

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-settings-structure.sh"
    REAL_SETTINGS="${ORIGINAL_HOME}/.claude/settings.json"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "validate-settings-structure.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-settings-structure.sh is executable" {
    assert_executable "$VALIDATE_SCRIPT"
}

#===============================================================================
# HELP OUTPUT TESTS
#===============================================================================

@test "help flag shows usage" {
    run "$VALIDATE_SCRIPT" --help
    [[ $status -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
}

#===============================================================================
# JSON OUTPUT TESTS
#===============================================================================

@test "JSON output is valid JSON" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq empty
}

@test "JSON output has status field" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    local status_val
    status_val=$(echo "$output" | jq -r '.status')
    [[ "$status_val" =~ ^(pass|fail)$ ]]
}

@test "JSON output has summary" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
}

@test "JSON output has checks" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks' > /dev/null
}

#===============================================================================
# TEXT OUTPUT TESTS
#===============================================================================

@test "text output shows settings path" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"Settings:"* ]]
}

@test "text output shows summary" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
}

#===============================================================================
# CHECK VALIDATION TESTS
#===============================================================================

@test "validates JSON structure" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.json_valid' > /dev/null
}

@test "validates required keys" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.required_keys' > /dev/null
}

@test "validates hooks events" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.hooks_events' > /dev/null
}

@test "validates permissions structure" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.permissions_structure' > /dev/null
}

@test "validates env variables" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.env_variables' > /dev/null
}

@test "validates agent teams env" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.checks.agent_teams_env' > /dev/null
}

#===============================================================================
# EXIT CODE TESTS
#===============================================================================

@test "exits 0 when no failures" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    local status_val
    status_val=$(echo "$output" | jq -r '.status')

    if [[ "$status_val" == "pass" ]]; then
        [[ $status -eq 0 ]]
    fi
}
