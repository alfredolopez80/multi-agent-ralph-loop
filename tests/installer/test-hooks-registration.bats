#!/usr/bin/env bats
#===============================================================================
# test-hooks-registration.bats - Test hooks registration validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify hooks registration validation works correctly
#===============================================================================

load test_helper

# Store original HOME for tests that need real settings
ORIGINAL_HOME="${HOME}"

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-hooks-registration.sh"
    REAL_SETTINGS="${ORIGINAL_HOME}/.claude/settings.json"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "validate-hooks-registration.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-hooks-registration.sh is executable" {
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
# SETTINGS FILE TESTS
#===============================================================================

@test "requires settings.json to exist" {
    # Skip if real settings.json doesn't exist
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"

    # Run with real HOME to access actual settings
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    # Either passes or fails based on hooks, but shouldn't error with code 2
    [[ $status -le 1 ]]
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

@test "JSON output has settings path" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.settings_path' > /dev/null
}

@test "JSON output has hooks dir" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.hooks_dir' > /dev/null
}

@test "JSON output has summary" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.summary.total' > /dev/null
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
    echo "$output" | jq -e '.summary.warnings' > /dev/null
}

@test "JSON output has hooks object" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.hooks' > /dev/null
}

@test "JSON hook entries have required fields" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    # Get first hook key
    local first_key
    first_key=$(echo "$output" | jq -r '.hooks | keys[0]')

    # Check required fields
    echo "$output" | jq -e ".hooks[\"$first_key\"].event" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].matcher" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].status" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].message" > /dev/null
}

#===============================================================================
# TEXT OUTPUT TESTS
#===============================================================================

@test "text output shows settings path" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"Settings:"* ]]
}

@test "text output shows hooks dir" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"Hooks Dir:"* ]]
}

@test "text output shows summary" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"Total:"* ]]
    [[ "$output" == *"Passed:"* ]]
    [[ "$output" == *"Failed:"* ]]
}

@test "text output shows event categories" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT"
    [[ "$output" == *"SessionStart"* ]]
    [[ "$output" == *"PreToolUse"* ]]
    [[ "$output" == *"PostToolUse"* ]]
}

#===============================================================================
# HOOK VALIDATION TESTS
#===============================================================================

@test "validates SessionStart hooks" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    # Should have auto-migrate-plan-state.sh
    echo "$output" | jq -e '.hooks["auto-migrate-plan-state.sh"]' > /dev/null
}

@test "validates PreToolUse Bash hooks" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    # Should have git-safety-guard.py
    echo "$output" | jq -e '.hooks["git-safety-guard.py"]' > /dev/null
}

@test "validates PostToolUse hooks" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    # Should have adversarial-auto-trigger.sh (a PostToolUse:Task hook)
    echo "$output" | jq -e '.hooks["adversarial-auto-trigger.sh"]' > /dev/null
}

@test "validates UserPromptSubmit hooks" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    # Should have context-warning.sh
    echo "$output" | jq -e '.hooks["context-warning.sh"]' > /dev/null
}

@test "validates SubagentStop hooks" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    # Should have glm5-subagent-stop.sh
    echo "$output" | jq -e '.hooks["glm5-subagent-stop.sh"]' > /dev/null
}

#===============================================================================
# STATUS CHECKS
#===============================================================================

@test "hook status is valid value" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    # Get first hook status
    local status
    status=$(echo "$output" | jq -r '.hooks | to_entries[0].value.status')
    [[ "$status" =~ ^(PASS|FAIL|WARN)$ ]]
}

@test "summary counts match actual hook statuses" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    local total passed failed warnings
    total=$(echo "$output" | jq '.summary.total')
    passed=$(echo "$output" | jq '.summary.passed')
    failed=$(echo "$output" | jq '.summary.failed')
    warnings=$(echo "$output" | jq '.summary.warnings')

    # Total should equal sum of passed, failed, warnings
    [[ $((passed + failed + warnings)) -eq $total ]]
}

#===============================================================================
# SECURITY HOOK TESTS
#===============================================================================

@test "git-safety-guard.py is validated" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    local status
    status=$(echo "$output" | jq -r '.hooks["git-safety-guard.py"].status')
    [[ "$status" =~ ^(PASS|FAIL|WARN)$ ]]
}

@test "repo-boundary-guard.sh is validated" {
    [[ ! -f "$REAL_SETTINGS" ]] && skip "Real settings.json not found"
    run env HOME="$ORIGINAL_HOME" "$VALIDATE_SCRIPT" --format json

    local status
    status=$(echo "$output" | jq -r '.hooks["repo-boundary-guard.sh"].status')
    [[ "$status" =~ ^(PASS|FAIL|WARN)$ ]]
}
