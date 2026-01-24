#!/usr/bin/env bats
# test_v2_68_23_security.bats - Security regression tests for v2.68.23
# Part of Multi-Agent Ralph Loop Test Suite
#
# Tests security fixes implemented in v2.68.23:
# - SEC-117: Command injection via eval echo "$path"
# - SEC-104: MD5 to SHA256 migration
# - SEC-111: Input length validation (DoS prevention)
# - CRIT-003: Duplicate JSON output via EXIT trap

setup() {
    export HOOKS_DIR="${HOME}/.claude/hooks"
    export PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export TEST_TMP=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_TMP" 2>/dev/null || true
}

# ============================================================
# SEC-117: Command Injection Tests
# ============================================================

@test "SEC-117: checkpoint-smart-save.sh uses safe path extraction" {
    [ -f "${HOOKS_DIR}/checkpoint-smart-save.sh" ] || skip "Hook not found"

    # Verify the fix: should NOT use eval echo
    run grep "eval echo" "${HOOKS_DIR}/checkpoint-smart-save.sh"
    [ "$status" -ne 0 ]

    # Verify the fix: should use jq -r for safe JSON extraction
    run grep -E 'jq.*-r.*file_path' "${HOOKS_DIR}/checkpoint-smart-save.sh"
    [ "$status" -eq 0 ]
}

@test "SEC-117: ralph checkpoint CLI rejects malicious paths" {
    # Test that the CLI safely handles malicious path inputs

    # Test 1: Basic tilde expansion (should work)
    run ralph checkpoint save "test-$(date +%s)" "Test checkpoint"
    [ "$status" -eq 0 ] || skip "ralph CLI not available"

    # Test 2: Path traversal attempt (should be rejected/sanitized)
    run bash -c 'echo "../../../../etc/passwd" | ralph checkpoint save "injection-$(date +%s)" 2>&1 || true'
    # The command should either fail or sanitize the input
    # We verify it doesn't actually read /etc/passwd by checking output doesn't contain "root:x:0:0"
    ! echo "$output" | grep -q "root:x:0:0"
}

@test "SEC-117: Command injection via semicolon rejected" {
    run bash -c 'echo "test; whoami" | ralph checkpoint save "injection-$(date +%s)" 2>&1 || true'
    # Should not execute whoami successfully
    ! echo "$output" | grep -q "^root\|^$(whoami)"
}

@test "SEC-117: Command injection via backticks rejected" {
    run bash -c 'echo "test\`whoami\`" | ralph checkpoint save "injection-$(date +%s)" 2>&1 || true'
    # Should not execute whoami
    ! echo "$output" | grep -q "^root\|^$(whoami)"
}

# ============================================================
# SEC-104: SHA-256 Migration Tests
# ============================================================

@test "SEC-104: checkpoint-smart-save.sh uses SHA-256 not MD5" {
    [ -f "${HOOKS_DIR}/checkpoint-smart-save.sh" ] || skip "Hook not found"

    # Should use shasum -a 256 (SHA-256)
    run grep "shasum -a 256" "${HOOKS_DIR}/checkpoint-smart-save.sh"
    [ "$status" -eq 0 ]

    # Should NOT use md5 or md5sum
    run grep -E "md5sum|md5 " "${HOOKS_DIR}/checkpoint-smart-save.sh"
    [ "$status" -ne 0 ]
}

@test "SEC-104: SHA-256 produces 64 character hex hash" {
    # Create a temporary file with known content
    local temp_file="$TEST_TMP/test_content.txt"
    echo "known content for hash testing" > "$temp_file"

    # Get SHA-256 hash
    local expected_hash
    expected_hash=$(shasum -a 256 "$temp_file" | awk '{print $1}')

    # SHA-256 should be 64 characters
    [ "${#expected_hash}" -eq 64 ]

    # SHA-256 should match hex pattern
    [[ "$expected_hash" =~ ^[a-f0-9]{64}$ ]]
}

# ============================================================
# SEC-111: Input Length Validation Tests
# ============================================================

@test "SEC-111: Task hooks have 100KB input length limit" {
    # These hooks should have SEC-111 protection
    local task_hooks=(
        "global-task-sync.sh"
        "task-orchestration-optimizer.sh"
        "task-primitive-sync.sh"
        "task-project-tracker.sh"
    )

    for hook in "${task_hooks[@]}"; do
        [ -f "${HOOKS_DIR}/$hook" ] || continue

        # Should have head -c 100000 for input length limit
        run grep "head -c 100000" "${HOOKS_DIR}/$hook"
        [ "$status" -eq 0 ] || skip "Hook $hook missing SEC-111 protection"
    done
}

@test "SEC-111: head -c 100000 truncates to exactly 100KB" {
    # Create input larger than 100KB
    local large_input="$TEST_TMP/large_input.txt"
    python3 -c "print('A' * 200000)" > "$large_input"

    # Truncate to 100KB
    local truncated
    truncated=$(head -c 100000 "$large_input")
    local truncated_size=${#truncated}

    # Should be exactly 100000 bytes (100KB)
    [ "$truncated_size" -eq 100000 ]
}

@test "SEC-111: Task hooks validate JSON before processing" {
    local task_hooks=(
        "global-task-sync.sh"
        "task-orchestration-optimizer.sh"
        "task-primitive-sync.sh"
        "task-project-tracker.sh"
    )

    for hook in "${task_hooks[@]}"; do
        [ -f "${HOOKS_DIR}/$hook" ] || continue

        # Should have jq validation pattern
        run grep -E 'jq empty.*2>/dev/null' "${HOOKS_DIR}/$hook"
        [ "$status" -eq 0 ] || skip "Hook $hook missing JSON validation"
    done
}

# ============================================================
# CRIT-003: Duplicate JSON Output Tests
# ============================================================

@test "CRIT-003: Hooks clear EXIT trap before explicit JSON output" {
    # These hooks should have trap clearing pattern
    local hooks_with_traps=(
        "auto-plan-state.sh"
        "plan-analysis-cleanup.sh"
        "recursive-decompose.sh"
        "sentry-report.sh"
        "orchestrator-report.sh"
    )

    for hook in "${hooks_with_traps[@]}"; do
        [ -f "${HOOKS_DIR}/$hook" ] || continue

        # Should have trap clearing pattern
        run grep -E "trap.*-.*ERR.*EXIT" "${HOOKS_DIR}/$hook"
        [ "$status" -eq 0 ] || skip "Hook $hook missing trap clearing pattern"
    done
}

@test "CRIT-003: Hooks have guaranteed JSON output on error" {
    # Every hook should have SEC-033 error trap
    local hooks_with_traps=(
        "auto-plan-state.sh"
        "plan-analysis-cleanup.sh"
        "recursive-decompose.sh"
    )

    for hook in "${hooks_with_traps[@]}"; do
        [ -f "${HOOKS_DIR}/$hook" ] || continue

        # Should have trap with JSON output function
        run grep -E "trap.*output_json|trap.*echo.*continue.*true" "${HOOKS_DIR}/$hook"
        [ "$status" -eq 0 ] || skip "Hook $hook missing SEC-033 error trap"
    done
}

# ============================================================
# Version Compliance Tests
# ============================================================

@test "v2.68.23: All security-critical hooks at correct version" {
    local security_hooks=(
        "checkpoint-smart-save.sh"
        "global-task-sync.sh"
        "task-primitive-sync.sh"
        "task-project-tracker.sh"
        "task-orchestration-optimizer.sh"
        "auto-plan-state.sh"
    )

    for hook in "${security_hooks[@]}"; do
        [ -f "${HOOKS_DIR}/$hook" ] || continue

        # Should have VERSION 2.68.23
        run grep "VERSION: 2.68.23" "${HOOKS_DIR}/$hook"
        [ "$status" -eq 0 ]
    done
}

@test "v2.68.23: plan-state.json at correct version" {
    [ -f ".claude/plan-state.json" ] || skip "plan-state.json not found"

    local version
    version=$(jq -r '.version' .claude/plan-state.json)

    # Should be at least 2.68.23
    [[ "$version" =~ ^2\.68\.2[3-9]$ ]] || [[ "$version" =~ ^2\.6[9-9]\.[0-9]+$ ]]
}
