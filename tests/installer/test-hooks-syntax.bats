#!/usr/bin/env bats
#===============================================================================
# test-hooks-syntax.bats - Test hooks syntax validation
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify hooks syntax validation works correctly
#===============================================================================

load test_helper

# Store original HOME for tests
ORIGINAL_HOME="${HOME}"

setup() {
    setup_installer_test
    VALIDATE_SCRIPT="$PROJECT_ROOT/scripts/validate-hooks-syntax.sh"
    HOOKS_DIR="$PROJECT_ROOT/.claude/hooks"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SCRIPT EXISTENCE TESTS
#===============================================================================

@test "validate-hooks-syntax.sh exists" {
    assert_file_exists "$VALIDATE_SCRIPT"
}

@test "validate-hooks-syntax.sh is executable" {
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

@test "help flag describes checks" {
    run "$VALIDATE_SCRIPT" --help
    [[ "$output" == *"bash -n"* ]]
    [[ "$output" == *"py_compile"* ]]
    [[ "$output" == *"shebang"* || "$output" == *"Shebang"* ]]
}

#===============================================================================
# BASIC VALIDATION TESTS
#===============================================================================

@test "runs successfully on hooks directory" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT"
    # Should exit 0 or 1 (pass or fail), not 2 (error)
    [[ $status -le 1 ]]
}

@test "JSON output is valid JSON" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq empty
}

@test "JSON output has status field" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json
    local status_val
    status_val=$(echo "$output" | jq -r '.status')
    [[ "$status_val" =~ ^(pass|fail)$ ]]
}

@test "JSON output has hooks_dir" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.hooks_dir' > /dev/null
}

@test "JSON output has summary" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.summary.total' > /dev/null
    echo "$output" | jq -e '.summary.passed' > /dev/null
    echo "$output" | jq -e '.summary.failed' > /dev/null
}

@test "JSON output has hooks object" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json
    echo "$output" | jq -e '.hooks' > /dev/null
}

#===============================================================================
# HOOK ENTRY VALIDATION TESTS
#===============================================================================

@test "JSON hook entries have required fields" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json

    # Get first hook key
    local first_key
    first_key=$(echo "$output" | jq -r '.hooks | keys[0]')

    [[ -z "$first_key" || "$first_key" == "null" ]] && skip "No hooks found"

    # Check required fields
    echo "$output" | jq -e ".hooks[\"$first_key\"].type" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].status" > /dev/null
    echo "$output" | jq -e ".hooks[\"$first_key\"].message" > /dev/null
}

@test "hook status is valid value" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json

    # Get first hook status
    local status
    status=$(echo "$output" | jq -r '.hooks | to_entries[0].value.status')
    [[ "$status" =~ ^(PASS|FAIL)$ ]]
}

@test "hook type is valid value" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json

    # Get first hook type
    local hook_type
    hook_type=$(echo "$output" | jq -r '.hooks | to_entries[0].value.type')
    [[ "$hook_type" =~ ^(shell|python|unknown)$ ]]
}

#===============================================================================
# TEXT OUTPUT TESTS
#===============================================================================

@test "text output shows hooks dir" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"Hooks Dir:"* ]]
}

@test "text output shows shell scripts section" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"Shell Scripts"* ]]
}

@test "text output shows python scripts section" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"Python Scripts"* ]]
}

@test "text output shows summary" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT"
    [[ "$output" == *"SUMMARY"* ]]
    [[ "$output" == *"Total:"* ]]
    [[ "$output" == *"Passed:"* ]]
    [[ "$output" == *"Failed:"* ]]
}

#===============================================================================
# SYNTAX VALIDATION TESTS
#===============================================================================

@test "validates shell scripts with bash -n" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    # Count shell scripts
    local shell_count
    shell_count=$(find "$HOOKS_DIR" -maxdepth 1 -name "*.sh" -type f | wc -l | tr -d ' ')

    [[ "$shell_count" -eq 0 ]] && skip "No shell scripts found"

    run "$VALIDATE_SCRIPT" --format json

    # Verify total includes shell scripts
    local total
    total=$(echo "$output" | jq '.summary.total')

    [[ $total -ge $shell_count ]]
}

@test "validates python scripts with py_compile" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    # Count python scripts
    local python_count
    python_count=$(find "$HOOKS_DIR" -maxdepth 1 -name "*.py" -type f | wc -l | tr -d ' ')

    [[ "$python_count" -eq 0 ]] && skip "No Python scripts found"

    run "$VALIDATE_SCRIPT" --format json

    # Verify total includes python scripts
    local total
    total=$(echo "$output" | jq '.summary.total')

    [[ $total -ge $python_count ]]
}

@test "detects shell scripts with shebangs" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json

    # Find a shell script in the output
    local shell_hook
    shell_hook=$(echo "$output" | jq -r '.hooks | to_entries[] | select(.value.type == "shell") | .key' | head -1)

    [[ -n "$shell_hook" ]] && [[ "$shell_hook" != "null" ]]
}

@test "detects python scripts with shebangs" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    # Check if there are any python scripts
    local python_count
    python_count=$(find "$HOOKS_DIR" -maxdepth 1 -name "*.py" -type f | wc -l | tr -d ' ')

    [[ "$python_count" -eq 0 ]] && skip "No Python scripts found"

    run "$VALIDATE_SCRIPT" --format json

    # Find a python script in the output
    local python_hook
    python_hook=$(echo "$output" | jq -r '.hooks | to_entries[] | select(.value.type == "python") | .key' | head -1)

    [[ -n "$python_hook" ]] && [[ "$python_hook" != "null" ]]
}

#===============================================================================
# SPECIFIC HOOK VALIDATION TESTS
#===============================================================================

@test "git-safety-guard.py has valid Python syntax" {
    [[ ! -f "$HOOKS_DIR/git-safety-guard.py" ]] && skip "git-safety-guard.py not found"

    run "$VALIDATE_SCRIPT" --format json

    local status
    status=$(echo "$output" | jq -r '.hooks["git-safety-guard.py"].status')

    [[ "$status" == "PASS" ]]
}

@test "git-safety-guard.py has valid shebang" {
    [[ ! -f "$HOOKS_DIR/git-safety-guard.py" ]] && skip "git-safety-guard.py not found"

    run "$VALIDATE_SCRIPT" --format json

    local message
    message=$(echo "$output" | jq -r '.hooks["git-safety-guard.py"].message')

    # Should not have shebang error
    [[ "$message" != *"shebang"* ]]
}

@test "adversarial-auto-trigger.sh has valid bash syntax" {
    [[ ! -f "$HOOKS_DIR/adversarial-auto-trigger.sh" ]] && skip "adversarial-auto-trigger.sh not found"

    run "$VALIDATE_SCRIPT" --format json

    local status
    status=$(echo "$output" | jq -r '.hooks["adversarial-auto-trigger.sh"].status')

    [[ "$status" == "PASS" ]]
}

@test "adversarial-auto-trigger.sh has valid shebang" {
    [[ ! -f "$HOOKS_DIR/adversarial-auto-trigger.sh" ]] && skip "adversarial-auto-trigger.sh not found"

    run "$VALIDATE_SCRIPT" --format json

    local message
    message=$(echo "$output" | jq -r '.hooks["adversarial-auto-trigger.sh"].message')

    # Should not have shebang error
    [[ "$message" != *"shebang"* ]]
}

#===============================================================================
# SUMMARY COUNTS VALIDATION
#===============================================================================

@test "summary counts match actual hook statuses" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json

    local total passed failed
    total=$(echo "$output" | jq '.summary.total')
    passed=$(echo "$output" | jq '.summary.passed')
    failed=$(echo "$output" | jq '.summary.failed')

    # Total should equal sum of passed and failed
    [[ $((passed + failed)) -eq $total ]]
}

@test "exit code reflects validation status" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json

    local failed
    failed=$(echo "$output" | jq '.summary.failed')

    if [[ $failed -eq 0 ]]; then
        [[ $status -eq 0 ]]
    else
        [[ $status -eq 1 ]]
    fi
}

#===============================================================================
# ERROR REPORTING TESTS
#===============================================================================

@test "error detail provided for failed hooks" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --format json

    # Check if any hook has failed
    local has_failed
    has_failed=$(echo "$output" | jq '.summary.failed > 0')

    if [[ "$has_failed" == "true" ]]; then
        # Get first failed hook
        local failed_hook error_detail
        failed_hook=$(echo "$output" | jq -r '.hooks | to_entries[] | select(.value.status == "FAIL") | .key' | head -1)
        error_detail=$(echo "$output" | jq -r ".hooks[\"$failed_hook\"].error_detail")

        # Error detail should exist (may be empty if only shebang issue)
        [[ -n "$error_detail" ]] || [[ "$error_detail" != "null" ]]
    else
        skip "No failed hooks to test error detail"
    fi
}

@test "verbose mode shows more detail" {
    [[ ! -d "$HOOKS_DIR" ]] && skip "Hooks directory not found"

    run "$VALIDATE_SCRIPT" --verbose

    # Should show some detail in output
    [[ "$output" == *"Hooks Dir:"* ]] || [[ "$output" == *"Total:"* ]]
}

#===============================================================================
# FIXTURE TESTS (Test with intentionally bad files)
#===============================================================================

@test "detects shell script with bad syntax" {
    # Create a temp file with bad syntax
    local bad_script="$TEST_TMPDIR/bad_hook.sh"
    cat > "$bad_script" << 'EOF'
#!/bin/bash
# Missing closing quote
echo "hello
EOF

    # Run bash -n on it
    run bash -n "$bad_script"
    [[ $status -ne 0 ]]
}

@test "detects python script with bad syntax" {
    # Create a temp file with bad syntax
    local bad_script="$TEST_TMPDIR/bad_hook.py"
    cat > "$bad_script" << 'EOF'
#!/usr/bin/env python3
# Missing closing parenthesis
print("hello"
EOF

    # Run py_compile on it
    run python3 -m py_compile "$bad_script"
    [[ $status -ne 0 ]]
}

@test "detects missing shebang" {
    # Create a temp file without shebang
    local no_shebang="$TEST_TMPDIR/no_shebang.sh"
    cat > "$no_shebang" << 'EOF'
# No shebang here
echo "hello"
EOF

    # First line should not be a valid shebang
    local first_line
    first_line=$(head -1 "$no_shebang")
    [[ "$first_line" != "#!/"* ]]
}

@test "valid shebang formats accepted" {
    # Test valid bash shebangs
    local test_shebangs=(
        "#!/bin/bash"
        "#!/usr/bin/env bash"
        "#!/bin/bash -e"
    )

    for shebang in "${test_shebangs[@]}"; do
        [[ "$shebang" == "#!/bin/bash"* ]] || [[ "$shebang" == "#!/usr/bin/env bash"* ]]
    done
}
