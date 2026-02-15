#!/usr/bin/env bats
#===============================================================================
# test_helper.bats - Test the test helper functions
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Verify test helper functions work correctly
#===============================================================================

load test_helper

setup() {
    setup_installer_test
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# SETUP/TEARDOWN TESTS
#===============================================================================

@test "setup_installer_test creates test directories" {
    assert_dir_exists "$TEST_HOME"
    assert_dir_exists "$TEST_HOME/.ralph"
    assert_dir_exists "$TEST_HOME/.local/bin"
    assert_dir_exists "$TEST_HOME/.claude"
}

@test "setup_installer_test sets environment variables" {
    [[ -n "$PROJECT_ROOT" ]]
    [[ -n "$TEST_TMPDIR" ]]
    [[ "$HOME" == "$TEST_HOME" ]]
}

@test "teardown_installer_test cleans up temp directory" {
    local tmpdir="$TEST_TMPDIR"
    teardown_installer_test
    [[ ! -d "$tmpdir" ]]
}

#===============================================================================
# MOCK BIN TESTS
#===============================================================================

@test "create_mock_bin creates executable" {
    create_mock_bin "testcmd" "hello" "1.2.3"

    assert_file_exists "$TEST_BIN/testcmd"
    assert_executable "$TEST_BIN/testcmd"
}

@test "create_mock_bin returns version" {
    create_mock_bin "testcmd" "" "1.2.3"

    run "$TEST_BIN/testcmd" --version
    [[ "$output" == "testcmd 1.2.3" ]]
}

@test "create_mock_bin returns output" {
    create_mock_bin "testcmd" "expected output"

    run "$TEST_BIN/testcmd"
    [[ "$output" == "expected output" ]]
}

#===============================================================================
# MOCK TOOL INPUT TESTS
#===============================================================================

@test "create_mock_tool_input creates Edit input" {
    local input_file
    input_file=$(create_mock_tool_input "Edit")

    assert_file_exists "$input_file"
    assert_valid_json "$input_file"
    assert_json_has_key "$input_file" "tool"
}

@test "create_mock_tool_input creates Write input" {
    local input_file
    input_file=$(create_mock_tool_input "Write")

    assert_valid_json "$input_file"
    run jq -r '.tool' < "$input_file"
    [[ "$output" == "Write" ]]
}

@test "create_mock_tool_input creates Bash input" {
    local input_file
    input_file=$(create_mock_tool_input "Bash")

    assert_valid_json "$input_file"
    run jq -r '.tool' < "$input_file"
    [[ "$output" == "Bash" ]]
}

@test "create_mock_tool_input creates Task input" {
    local input_file
    input_file=$(create_mock_tool_input "Task")

    assert_valid_json "$input_file"
    run jq -r '.tool' < "$input_file"
    [[ "$output" == "Task" ]]
}

#===============================================================================
# ASSERTION TESTS
#===============================================================================

@test "assert_file_exists passes for existing file" {
    touch "$TEST_TMPDIR/test.txt"
    run assert_file_exists "$TEST_TMPDIR/test.txt"
    [[ $status -eq 0 ]]
}

@test "assert_file_exists fails for missing file" {
    run assert_file_exists "$TEST_TMPDIR/nonexistent.txt"
    [[ $status -eq 1 ]]
}

@test "assert_dir_exists passes for existing directory" {
    run assert_dir_exists "$TEST_TMPDIR"
    [[ $status -eq 0 ]]
}

@test "assert_dir_exists fails for missing directory" {
    run assert_dir_exists "$TEST_TMPDIR/nonexistent"
    [[ $status -eq 1 ]]
}

@test "assert_executable passes for executable file" {
    touch "$TEST_TMPDIR/exec.sh"
    chmod +x "$TEST_TMPDIR/exec.sh"
    run assert_executable "$TEST_TMPDIR/exec.sh"
    [[ $status -eq 0 ]]
}

@test "assert_executable fails for non-executable file" {
    touch "$TEST_TMPDIR/nonexec.sh"
    run assert_executable "$TEST_TMPDIR/nonexec.sh"
    [[ $status -eq 1 ]]
}

@test "assert_valid_json passes for valid JSON" {
    echo '{"key": "value"}' > "$TEST_TMPDIR/valid.json"
    run assert_valid_json "$TEST_TMPDIR/valid.json"
    [[ $status -eq 0 ]]
}

@test "assert_valid_json fails for invalid JSON" {
    echo 'not json' > "$TEST_TMPDIR/invalid.json"
    run assert_valid_json "$TEST_TMPDIR/invalid.json"
    [[ $status -eq 1 ]]
}

#===============================================================================
# VERSION COMPARISON TESTS
#===============================================================================

@test "version_ge returns 0 for equal versions" {
    run version_ge "1.0.0" "1.0.0"
    [[ $status -eq 0 ]]
}

@test "version_ge returns 0 for greater versions" {
    run version_ge "2.0.0" "1.0.0"
    [[ $status -eq 0 ]]
}

@test "version_ge returns 1 for lesser versions" {
    run version_ge "1.0.0" "2.0.0"
    [[ $status -eq 1 ]]
}

@test "version_ge handles different lengths" {
    run version_ge "1.0.1" "1.0"
    [[ $status -eq 0 ]]
}

@test "version_ge handles major only" {
    run version_ge "18" "17"
    [[ $status -eq 0 ]]
}

#===============================================================================
# UTILITY FUNCTION TESTS
#===============================================================================

@test "get_project_root returns a directory" {
    local root
    root=$(get_project_root)
    assert_dir_exists "$root"
}

@test "tool_available returns true for existing tool" {
    run tool_available "bash"
    [[ $status -eq 0 ]]
}

@test "tool_available returns false for missing tool" {
    run tool_available "nonexistent_tool_xyz"
    [[ $status -eq 1 ]]
}

@test "get_min_version returns expected values" {
    [[ $(get_min_version "bash") == "4.0" ]]
    [[ $(get_min_version "git") == "2.0" ]]
    [[ $(get_min_version "node") == "18" ]]
    [[ $(get_min_version "python3") == "3.9" ]]
}

@test "get_shell_type returns valid shell" {
    local shell_type
    shell_type=$(get_shell_type)
    [[ "$shell_type" =~ ^(bash|zsh|sh)$ ]]
}
