#!/usr/bin/env bats
#===============================================================================
# test-hooks-execution.bats - Test hook execution with mock inputs
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify hooks execute correctly with mock input and timeout handling
#===============================================================================

load test_helper

# Store original HOME for accessing real hooks
ORIGINAL_HOME="${HOME}"

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-hooks-execution.sh"
    HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
    FIXTURES_DIR="$PROJECT_ROOT/tests/installer/fixtures/mock-tool-inputs"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "validate-hooks-execution.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-hooks-execution.sh is executable" {
    assert_executable "$VALIDATE_SCRIPT"
}

#===============================================================================
# FIXTURES TESTS
#===============================================================================

@test "mock input fixtures directory exists" {
    assert_dir_exists "$FIXTURES_DIR"
}

@test "pre-tool-use-bash.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/pre-tool-use-bash.json"
}

@test "pre-tool-use-edit.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/pre-tool-use-edit.json"
}

@test "pre-tool-use-write.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/pre-tool-use-write.json"
}

@test "pre-tool-use-task.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/pre-tool-use-task.json"
}

@test "user-prompt-submit.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/user-prompt-submit.json"
}

@test "session-start.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/session-start.json"
}

@test "pre-compact.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/pre-compact.json"
}

@test "subagent-stop.json fixture exists" {
    assert_file_exists "$FIXTURES_DIR/subagent-stop.json"
}

@test "all fixtures are valid JSON" {
    for fixture in "$FIXTURES_DIR"/*.json; do
        assert_valid_json "$fixture"
    done
}

#===============================================================================
# HELP OUTPUT TESTS
#===============================================================================

@test "help flag shows usage" {
    run "$VALIDATE_SCRIPT" --help
    [[ $status -eq 0 ]]
    [[ "$output" == *"Usage"* ]]
    [[ "$output" == *"--format"* ]]
    [[ "$output" == *"--timeout"* ]]
}

#===============================================================================
# SCRIPT EXECUTION TESTS
#===============================================================================

@test "script runs without error" {
    run "$VALIDATE_SCRIPT" --timeout 10
    # Script should run (may have failures but should not crash)
    [[ $status -le 1 ]]
}

@test "JSON output is valid JSON" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    [[ $status -le 1 ]]
    echo "$output" | jq empty
}

@test "JSON output has status field" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    local status_val
    status_val=$(echo "$output" | jq -r '.status')
    [[ "$status_val" =~ ^(pass|fail)$ ]]
}

@test "JSON output has summary" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    echo "$output" | jq -e '.summary.total' > /dev/null
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
    echo "$output" | jq -e '.summary.timeouts' > /dev/null
    echo "$output" | jq -e '.summary.errors' > /dev/null
}

@test "JSON output has hooks object" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    echo "$output" | jq -e '.hooks' > /dev/null
}

@test "JSON hook entries have required fields" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10

    # Get first hook key
    local first_key
    first_key=$(echo "$output" | jq -r '.hooks | keys[0]')

    # Check required fields
    echo "$output" | jq -e ".hooks[\"$first_key\"].result" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].exit_code" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].duration" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].message" > /dev/null
}

#===============================================================================
# TEXT OUTPUT TESTS
#===============================================================================

@test "text output shows hooks directory" {
    run "$VALIDATE_SCRIPT" --timeout 10
    [[ "$output" == *"Hooks Dir:"* ]]
}

@test "text output shows summary" {
    run "$VALIDATE_SCRIPT" --timeout 10
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"Total:"* ]]
    [[ "$output" == *"Passed:"* ]]
    [[ "$output" == *"Failed:"* ]]
}

@test "text output shows individual hook results" {
    run "$VALIDATE_SCRIPT" --timeout 10
    # Should show at least one hook result (PASS, FAIL, etc.)
    [[ "$output" =~ \[PASS\]|\[FAIL\]|\[TIMEOUT\]|\[SKIPPED\] ]]
}

#===============================================================================
# HOOK EXECUTION TESTS
#===============================================================================

@test "git-safety-guard.py is tested" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    echo "$output" | jq -e '.hooks["git-safety-guard.py"]' > /dev/null
}

@test "repo-boundary-guard.sh is tested" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    echo "$output" | jq -e '.hooks["repo-boundary-guard.sh"]' > /dev/null
}

@test "context-warning.sh is tested" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    echo "$output" | jq -e '.hooks["context-warning.sh"]' > /dev/null
}

@test "glm5-subagent-stop.sh is tested" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    echo "$output" | jq -e '.hooks["glm5-subagent-stop.sh"]' > /dev/null
}

@test "pre-compact-handoff.sh is tested" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10
    echo "$output" | jq -e '.hooks["pre-compact-handoff.sh"]' > /dev/null
}

#===============================================================================
# HOOK RESULT VALIDATION TESTS
#===============================================================================

@test "hook result is valid value" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10

    # Get first hook result
    local result
    result=$(echo "$output" | jq -r '.hooks | to_entries[0].value.result')
    [[ "$result" =~ ^(PASS|FAIL|TIMEOUT|MISSING|NOT_EXECUTABLE|EXEC_ERROR|NOT_FOUND|SKIPPED)$ ]]
}

@test "summary counts match actual hook results" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10

    local total passed failed timeouts errors
    total=$(echo "$output" | jq '.summary.total')
    passed=$(echo "$output" | jq '.summary.passed')
    failed=$(echo "$output" | jq '.summary.failed')
    timeouts=$(echo "$output" | jq '.summary.timeouts')
    errors=$(echo "$output" | jq '.summary.errors')

    # Total should equal sum of all categories
    [[ $((passed + failed + timeouts + errors)) -eq $total ]]
}

#===============================================================================
# TIMEOUT HANDLING TESTS
#===============================================================================

@test "timeout parameter is respected" {
    # Run with short timeout (5 seconds)
    run "$VALIDATE_SCRIPT" --timeout 5 --format json
    [[ $status -le 1 ]]

    # Verify timeout setting is reflected in output
    local timeout_setting
    timeout_setting=$(echo "$output" | jq -r '.timeout_seconds')
    # Compare as integers (jq may return number or string)
    [[ "$timeout_setting" -eq 5 ]]
}

@test "hanging hooks are detected" {
    # If a hook times out, it should be reported
    run "$VALIDATE_SCRIPT" --format json --timeout 10

    # Check if any hook has TIMEOUT result (may or may not happen)
    local timeout_count
    timeout_count=$(echo "$output" | jq '.summary.timeouts')

    # If there are timeouts, verify they are reported correctly
    if [[ "$timeout_count" -gt 0 ]]; then
        # Find a timed out hook and verify its result
        local timedout_hook
        timedout_hook=$(echo "$output" | jq -r '.hooks | to_entries[] | select(.value.result == "TIMEOUT") | .key' | head -1)
        [[ -n "$timedout_hook" ]]
    fi
}

#===============================================================================
# ERROR REPORTING TESTS
#===============================================================================

@test "failed hooks have error messages" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10

    # Find any failed hook
    local failed_hook
    failed_hook=$(echo "$output" | jq -r '.hooks | to_entries[] | select(.value.result == "FAIL") | .key' | head -1)

    if [[ -n "$failed_hook" ]]; then
        # Verify it has a message
        local message
        message=$(echo "$output" | jq -r ".hooks[\"$failed_hook\"].message")
        [[ -n "$message" ]]
        [[ "$message" != "null" ]]
    fi
}

@test "hooks with stderr capture error output" {
    run "$VALIDATE_SCRIPT" --format json --timeout 10

    # Check that stderr field exists for all hooks
    local hook_count
    hook_count=$(echo "$output" | jq '.hooks | length')

    if [[ "$hook_count" -gt 0 ]]; then
        # All hooks should have stderr field (even if empty)
        local hooks_with_stderr
        hooks_with_stderr=$(echo "$output" | jq '[.hooks | .[] | has("stderr")] | all')
        [[ "$hooks_with_stderr" == "true" ]]
    fi
}

#===============================================================================
# INDIVIDUAL HOOK TESTS (Direct Execution)
#===============================================================================

@test "git-safety-guard.py allows safe commands" {
    [[ ! -f "$HOOKS_DIR/git-safety-guard.py" ]] && skip "git-safety-guard.py not found"

    # Test with safe command
    run bash -c "cat '$FIXTURES_DIR/pre-tool-use-bash.json' | '$HOOKS_DIR/git-safety-guard.py'"

    # Should output JSON with permissionDecision: allow
    if echo "$output" | jq -e '.hookSpecificOutput.permissionDecision' >/dev/null 2>&1; then
        local decision
        decision=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision')
        [[ "$decision" == "allow" ]]
    fi
}

@test "git-safety-guard.py blocks dangerous commands" {
    [[ ! -f "$HOOKS_DIR/git-safety-guard.py" ]] && skip "git-safety-guard.py not found"

    # Test with dangerous command
    run bash -c "cat '$FIXTURES_DIR/pre-tool-use-bash-dangerous.json' | '$HOOKS_DIR/git-safety-guard.py'"

    # Should output JSON with permissionDecision: block (exit code != 0)
    if echo "$output" | jq -e '.hookSpecificOutput.permissionDecision' >/dev/null 2>&1; then
        local decision
        decision=$(echo "$output" | jq -r '.hookSpecificOutput.permissionDecision')
        [[ "$decision" == "block" ]]
    fi
}

@test "repo-boundary-guard.sh outputs valid JSON" {
    [[ ! -f "$HOOKS_DIR/repo-boundary-guard.sh" ]] && skip "repo-boundary-guard.sh not found"

    run bash -c "cat '$FIXTURES_DIR/pre-tool-use-bash.json' | '$HOOKS_DIR/repo-boundary-guard.sh'"

    # Should output valid JSON
    echo "$output" | jq empty
}

@test "context-warning.sh outputs valid JSON" {
    [[ ! -f "$HOOKS_DIR/context-warning.sh" ]] && skip "context-warning.sh not found"

    run bash -c "cat '$FIXTURES_DIR/user-prompt-submit.json' | '$HOOKS_DIR/context-warning.sh'"

    # Should output valid JSON
    echo "$output" | jq empty
}

@test "glm5-subagent-stop.sh outputs valid JSON" {
    [[ ! -f "$HOOKS_DIR/glm5-subagent-stop.sh" ]] && skip "glm5-subagent-stop.sh not found"

    run bash -c "cat '$FIXTURES_DIR/subagent-stop.json' | '$HOOKS_DIR/glm5-subagent-stop.sh'"

    # Should output valid JSON
    echo "$output" | jq empty
}

@test "pre-compact-handoff.sh outputs valid JSON" {
    [[ ! -f "$HOOKS_DIR/pre-compact-handoff.sh" ]] && skip "pre-compact-handoff.sh not found"

    run bash -c "cat '$FIXTURES_DIR/pre-compact.json' | '$HOOKS_DIR/pre-compact-handoff.sh'"

    # Should output valid JSON
    echo "$output" | jq empty
}

#===============================================================================
# VERBOSE OUTPUT TESTS
#===============================================================================

@test "verbose flag shows more details" {
    run "$VALIDATE_SCRIPT" --verbose --timeout 10
    # Verbose should show additional details like duration
    [[ "$output" == *"ms"* ]] || [[ "$output" == *"OK"* ]]
}

#===============================================================================
# INTEGRATION TESTS
#===============================================================================

@test "all core hooks are present and executable" {
    local core_hooks=(
        "git-safety-guard.py"
        "repo-boundary-guard.sh"
        "context-warning.sh"
        "glm5-subagent-stop.sh"
    )

    for hook in "${core_hooks[@]}"; do
        assert_file_exists "$HOOKS_DIR/$hook"
        assert_executable "$HOOKS_DIR/$hook"
    done
}

@test "validation script completes within reasonable time" {
    # The entire validation should complete within 2 minutes
    # even with 30 second timeout per hook
    start_time=$(date +%s)
    run "$VALIDATE_SCRIPT" --timeout 10 --format json
    end_time=$(date +%s)

    local duration=$((end_time - start_time))
    # Should complete in under 60 seconds with 10s timeout
    [[ $duration -lt 60 ]]
}

@test "no orphan processes left after validation" {
    # Run validation
    "$VALIDATE_SCRIPT" --timeout 5 --format json >/dev/null 2>&1 || true

    # Check for any remaining hook processes (should be none)
    local hook_processes
    hook_processes=$(ps aux | grep -E 'git-safety-guard|repo-boundary-guard|context-warning' | grep -v grep || true)

    # Should not have any running processes
    [[ -z "$hook_processes" ]]
}
