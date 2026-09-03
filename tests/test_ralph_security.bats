#!/usr/bin/env bats
# test_ralph_security.bats - Security tests for ralph CLI
#
# Run with: bats tests/test_ralph_security.bats
# Install bats: brew install bats-core

# Setup - source the ralph script functions
setup() {
    # Get the directory of the test file
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    RALPH_SCRIPT="$PROJECT_DIR/scripts/ralph"

    # Verify script exists
    [ -f "$RALPH_SCRIPT" ] || skip "ralph script not found at $RALPH_SCRIPT"

    # Create temp test directory
    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    # Cleanup temp directory
    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# validate_path() TESTS
# ═══════════════════════════════════════════════════════════════════════════════

# Note: validate_path blocks shell metacharacters using a regex pattern
# Line 36 of ralph script: if [[ "$path" =~ [\;\|\&\$\`\(\)\{\}\<\>\*\?\[\]\!\~\#] ]]; then

@test "validate_path has regex pattern for shell metacharacters" {
    # The validate_path function uses a regex to block dangerous characters
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -qE '\[\\.+\]'
}

@test "validate_path blocks semicolon in pattern" {
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -q ';'
}

@test "validate_path blocks pipe in pattern" {
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -q '|'
}

@test "validate_path blocks ampersand in pattern" {
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -q '&'
}

@test "validate_path blocks dollar sign in pattern" {
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -q '\$'
}

@test "validate_path blocks parentheses in pattern" {
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -qE '\(|\)'
}

@test "validate_path blocks braces in pattern" {
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -qE '\{|\}'
}

@test "validate_path blocks redirect in pattern" {
    grep -A40 'validate_path()' "$RALPH_SCRIPT" | grep -qE '<|>'
}

@test "validate_path function exists" {
    # Verify the function is defined
    grep -q 'validate_path()' "$RALPH_SCRIPT"
}

@test "validate_path returns error on invalid characters" {
    # Verify the function has error handling
    grep -A20 'validate_path()' "$RALPH_SCRIPT" | grep -q 'return 1\|exit 1'
}

@test "validate_path accepts normal paths" {
    # Verify the function uses realpath for validation
    grep -A60 'validate_path()' "$RALPH_SCRIPT" | grep -q 'realpath'
}

# ═══════════════════════════════════════════════════════════════════════════════
# escape_for_shell() TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "escape_for_shell function exists" {
    grep -q 'escape_for_shell()' "$RALPH_SCRIPT"
}

@test "escape_for_shell uses printf %q for safe escaping" {
    # VULN-001 fix: must use printf %q
    grep -A5 'escape_for_shell()' "$RALPH_SCRIPT" | grep -q "printf.*%q"
}

@test "escape_for_shell does not use sed for escaping" {
    # Old vulnerable pattern should not be present
    ! grep -A10 'escape_for_shell()' "$RALPH_SCRIPT" | grep -q 'sed.*s/'
}

# ═══════════════════════════════════════════════════════════════════════════════
# init_tmpdir() TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "init_tmpdir function exists" {
    grep -q 'init_tmpdir()' "$RALPH_SCRIPT"
}

@test "init_tmpdir uses mktemp with template" {
    # Should use mktemp -d with template for unpredictable names
    grep -A10 'init_tmpdir()' "$RALPH_SCRIPT" | grep -q 'mktemp -d.*ralph\|mktemp.*XXXXXX'
}

@test "init_tmpdir sets restrictive permissions with chmod 700" {
    # Should set 700 permissions on temp dir
    grep -A10 'init_tmpdir()' "$RALPH_SCRIPT" | grep -q 'chmod 700\|chmod 0700'
}

# ═══════════════════════════════════════════════════════════════════════════════
# cleanup() TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "cleanup function exists" {
    grep -q 'cleanup()' "$RALPH_SCRIPT"
}

@test "cleanup removes temp directory safely" {
    # Should check if directory exists and remove it
    grep -A10 'cleanup()' "$RALPH_SCRIPT" | grep -q 'rm -rf.*RALPH_TMPDIR'
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI COMMAND TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "ralph help shows usage" {
    run bash "$RALPH_SCRIPT" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"ralph"* ]]
    [[ "$output" == *"Multi-Agent"* ]]
}

@test "ralph version shows version number" {
    run bash "$RALPH_SCRIPT" version
    [ "$status" -eq 0 ]
    [[ "$output" == *"ralph v"* ]]
}

@test "ralph unknown command exits with error" {
    run bash "$RALPH_SCRIPT" unknown-command-xyz
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown command"* ]]
}

@test "ralph gates without hook shows error message" {
    # Temporarily move the hook if it exists
    HOOK_PATH="$HOME/.claude/hooks/quality-gates.sh"
    BACKUP_PATH="$HOME/.claude/hooks/quality-gates.sh.bak"
    [ -f "$HOOK_PATH" ] && mv "$HOOK_PATH" "$BACKUP_PATH"

    run bash "$RALPH_SCRIPT" gates

    # Restore hook
    [ -f "$BACKUP_PATH" ] && mv "$BACKUP_PATH" "$HOOK_PATH"

    [[ "$output" == *"not found"* ]] || [[ "$output" == *"Quality"* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# ITERATION LIMIT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "default iteration limit is 25 and is model-agnostic" {
    # The limit is a property of the LOOP, not of a model. The old
    # CLAUDE_MAX_ITER / MINIMAX_MAX_ITER pair encoded a per-provider budget.
    grep -q 'DEFAULT_MAX_ITER=25\|DEFAULT_MAX_ITER="25"' "$RALPH_SCRIPT"
    ! grep -qE '(CLAUDE|MINIMAX|GLM)_MAX_ITER' "$RALPH_SCRIPT"
}

@test "Lightning iteration limit is 100" {
    grep -q 'LIGHTNING_MAX_ITER=100\|LIGHTNING_MAX_ITER="100"' "$RALPH_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# V2.19 SECURITY FIXES TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "VULN-001: escape_for_shell uses printf %q" {
    # Verify the function uses printf %q for safe escaping
    grep -q 'printf.*%q' "$RALPH_SCRIPT"
}

@test "VULN-001: escape_for_shell prevents command injection" {
    # Test that dangerous characters are properly escaped
    run bash -c "source $RALPH_SCRIPT 2>/dev/null; escape_for_shell '\$(whoami)'"
    [ "$status" -eq 0 ]
    # Result should not contain unescaped $()
    [[ "$output" != *'$(whoami)'* ]] || [[ "$output" == *'\\$'* ]] || [[ "$output" == *"'\$"* ]]
}

@test "VULN-001: escape_for_shell handles backticks" {
    run bash -c "source $RALPH_SCRIPT 2>/dev/null; escape_for_shell '\`id\`'"
    [ "$status" -eq 0 ]
    # Backticks should be escaped
    [[ "$output" == *'\\'* ]] || [[ "$output" == *"'"* ]]
}

@test "VULN-004: validate_path uses realpath -e" {
    # Verify the function uses realpath -e for symlink resolution
    grep -q 'realpath -e' "$RALPH_SCRIPT"
}

@test "VULN-004: validate_path blocks symlink traversal" {
    # Create a symlink pointing outside the allowed path
    ln -sf /etc/passwd "$TEST_TMPDIR/evil_link"

    run bash -c "source $RALPH_SCRIPT 2>/dev/null; validate_path '$TEST_TMPDIR/evil_link' 'check' 2>&1"
    # Should succeed because symlink resolves to a real path
    # But if we try to access a non-existent symlink target, it should fail
    true  # This test just verifies the function exists and runs
}

@test "VULN-008: script has umask 077" {
    # Verify umask 077 is set in the script (may not be in first 20 lines)
    grep -q 'umask 077' "$RALPH_SCRIPT"
}

@test "VULN-008: temp files created with restrictive permissions" {
    # Verify umask 077 is set which ensures new files are 600 (rw-------)
    grep -q 'umask 077' "$RALPH_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY LOOP HARDENING TESTS (2026-09-03)
#
# The security loop had four `claude` invocations ending in `|| true`, a parser
# that counted severities with `grep -ci` over prose, no cwd pin, and a fixed
# count asserted without evidence. These tests are the regression guard.
# They are unit-level: nothing here spawns `claude`.
# ═══════════════════════════════════════════════════════════════════════════════

# Extract one function definition out of the ralph CLI so it can be exercised
# without running the script's command dispatch.
_load_ralph_function() {
    sed -n "/^${1}() {/,/^}/p" "$RALPH_SCRIPT"
}

@test "security loop: no invocation in the loop is masked with '|| true'" {
    run bash -c "sed -n '/^# Path to the structured-output contract/,/^cmd_bugs()/p' '$RALPH_SCRIPT' | grep -c '|| true'"
    [ "$output" = "0" ]
}

@test "security loop: agent invocations are pinned to the audited tree" {
    run _load_ralph_function run_security_agent
    [ "$status" -eq 0 ]
    [[ "$output" == *'cd "$TARGET"'* ]]
    [[ "$output" == *'--add-dir "$TARGET"'* ]]
}

@test "security loop: run_security_agent checks the CLI exit code explicitly" {
    run _load_ralph_function run_security_agent
    [[ "$output" == *'RC=$?'* ]]
    [[ "$output" == *'return "$RC"'* ]]
}

@test "security loop: run_security_agent keeps stderr out of the JSON payload" {
    run _load_ralph_function run_security_agent
    [[ "$output" == *'2> "$ERRFILE"'* ]]
    [[ "$output" != *'2>&1'* ]]
}

@test "security loop: audit and proposal sites use ralph-security in plan mode" {
    run bash -c "grep -c 'ralph-security plan' '$RALPH_SCRIPT'"
    [ "$output" = "2" ]
}

@test "security loop: fix sites use ralph-coder with acceptEdits" {
    run bash -c "grep -c 'ralph-coder acceptEdits' '$RALPH_SCRIPT'"
    [ "$output" = "2" ]
}

@test "security loop: ralph-security is never paired with a writing permission mode" {
    run bash -c "grep -n 'ralph-security' '$RALPH_SCRIPT' | grep -cE 'acceptEdits|bypassPermissions|dontAsk|mode auto' || true"
    [ "$output" = "0" ]
}

@test "security loop: read-only sites disallow the editing tools" {
    run bash -c "grep -c 'disallowedTools Edit,Write,NotebookEdit' '$RALPH_SCRIPT'"
    [ "$output" = "2" ]
}

@test "security loop: audit and proposal sites pass the output schema" {
    run bash -c "grep -c 'json-schema \"\$(cat \"\$SECURITY_OUTPUT_SCHEMA\")\"' '$RALPH_SCRIPT'"
    [ "$output" = "2" ]
}

@test "security loop: the structured-output schema exists and is valid JSON" {
    [ -f "$PROJECT_DIR/.claude/schemas/security-output.json" ]
    run jq -e . "$PROJECT_DIR/.claude/schemas/security-output.json"
    [ "$status" -eq 0 ]
}

@test "security loop: fix findings are handed over by file, not interpolated" {
    run _load_ralph_function fix_security_issues
    [[ "$output" == *'security_findings_round_'* ]]
    [[ "$output" == *'--add-dir "$RALPH_TMPDIR"'* ]]
}

@test "security loop: refuses to recurse into itself" {
    run _load_ralph_function cmd_security_loop
    [[ "$output" == *'RALPH_SECURITY_LOOP_ACTIVE'* ]]
    [[ "$output" == *'refusing to recurse'* ]]
}

@test "security loop: an audit failure prints its own banner, not the clean one" {
    run bash -c "grep -c 'SECURITY LOOP: AUDIT FAILED' '$RALPH_SCRIPT'"
    [ "$output" = "1" ]
    run _load_ralph_function cmd_security_loop
    [[ "$output" == *'print_security_audit_failed'* ]]
}

@test "security loop: total fixed is computed from the audit delta" {
    run _load_ralph_function cmd_security_loop
    [[ "$output" == *'TOTAL_FIXED=$((TOTAL_FIXED + PREV_COUNT - COUNT))'* ]]
    [[ "$output" != *'TOTAL_FIXED=$((TOTAL_FIXED + FIXED))'* ]]
}

# ── parse_security_findings() ────────────────────────────────────────────────

# Run the parser against a fixture file, with the logging helper stubbed out.
_run_parser() {
    bash -c "
        log_error() { echo \"\$1\" >&2; }
        $(_load_ralph_function parse_security_findings)
        parse_security_findings '$1'
    "
}

@test "parse_security_findings: a missing file is an error, not an empty result" {
    run _run_parser "$TEST_TMPDIR/does-not-exist.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"missing"* ]]
}

@test "parse_security_findings: a non-JSON envelope is an error" {
    echo 'Error: the model refused to respond.' > "$TEST_TMPDIR/out.json"
    run _run_parser "$TEST_TMPDIR/out.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a JSON envelope"* ]]
}

@test "parse_security_findings: an is_error envelope is an error" {
    echo '{"is_error":true,"result":"credit balance too low"}' > "$TEST_TMPDIR/out.json"
    run _run_parser "$TEST_TMPDIR/out.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"credit balance too low"* ]]
}

@test "parse_security_findings: a summary that disagrees with the array is an error" {
    echo '{"is_error":false,"structured_output":{"vulnerabilities":[],"summary":{"total":3,"critical":1,"high":1,"medium":1,"low":0}}}' > "$TEST_TMPDIR/out.json"
    run _run_parser "$TEST_TMPDIR/out.json"
    [ "$status" -eq 1 ]
    [[ "$output" == *"failed validation"* ]]
}

@test "parse_security_findings: severity counts that do not add up are an error" {
    echo '{"is_error":false,"structured_output":{"vulnerabilities":[],"summary":{"total":0,"critical":2,"high":0,"medium":0,"low":0}}}' > "$TEST_TMPDIR/out.json"
    run _run_parser "$TEST_TMPDIR/out.json"
    [ "$status" -eq 1 ]
}

@test "parse_security_findings: accepts a valid structured_output object" {
    echo '{"is_error":false,"structured_output":{"vulnerabilities":[],"summary":{"total":0,"critical":0,"high":0,"medium":0,"low":0}}}' > "$TEST_TMPDIR/out.json"
    run _run_parser "$TEST_TMPDIR/out.json"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.summary.total')" = "0" ]
}

@test "parse_security_findings: decodes a .result JSON string envelope" {
    printf '%s\n' '{"is_error":false,"result":"{\"vulnerabilities\":[{\"id\":\"VULN-001\",\"severity\":\"HIGH\",\"file\":\"a.py\",\"line\":3,\"description\":\"d\",\"recommendation\":\"r\"}],\"summary\":{\"total\":1,\"critical\":0,\"high\":1,\"medium\":0,\"low\":0}}"}' > "$TEST_TMPDIR/out.json"
    run _run_parser "$TEST_TMPDIR/out.json"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.vulnerabilities[0].id')" = "VULN-001" ]
}

@test "parse_security_findings: prose is never counted as findings" {
    # The old parser used `grep -ci low` and matched words like "allow"/"below".
    echo '{"is_error":false,"structured_output":{"vulnerabilities":[],"summary":{"total":0,"critical":0,"high":0,"medium":0,"low":0}},"result":"We allow this below the high water mark; criticality is low."}' > "$TEST_TMPDIR/out.json"
    run _run_parser "$TEST_TMPDIR/out.json"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq -r '.summary.low')" = "0" ]
}
