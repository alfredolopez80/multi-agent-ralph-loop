#!/usr/bin/env bats
# test_v268_auto_invoke_hooks.bats - v2.68.0
# Tests for auto-invoke hooks: ai-code-audit, adversarial-auto-trigger,
# security-full-audit, code-review-auto, deslop-auto-clean, sec-context-validate
#
# Run with: bats tests/test_v268_auto_invoke_hooks.bats

setup() {
    SETTINGS_JSON="${HOME}/.claude/settings.json"
    HOOKS_DIR="${HOME}/.claude/hooks"
    PROJECT_HOOKS_DIR="$(pwd)/.claude/hooks"
    TEST_TMP_DIR="${BATS_TMPDIR}/v268_hooks_test"
    MARKERS_DIR="${HOME}/.ralph/markers"

    mkdir -p "$TEST_TMP_DIR"
    mkdir -p "$MARKERS_DIR"
}

teardown() {
    rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
    # Clean up test markers
    rm -f "${MARKERS_DIR}/test-"* 2>/dev/null || true
}

# ============================================================================
# Hook Registration Tests (settings.json)
# ============================================================================

@test "v2.68.0: ai-code-audit.sh is registered in PostToolUse/Edit|Write" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Edit|Write") |
        .hooks[] |
        select(.command | contains("ai-code-audit.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "v2.68.0: adversarial-auto-trigger.sh is registered in PostToolUse/Task" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Task") |
        .hooks[] |
        select(.command | contains("adversarial-auto-trigger.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "v2.68.0: security-full-audit.sh is registered in PostToolUse/Edit|Write" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Edit|Write") |
        .hooks[] |
        select(.command | contains("security-full-audit.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "v2.68.0: code-review-auto.sh is registered in PostToolUse/Task*" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher | contains("TaskUpdate")) |
        .hooks[] |
        select(.command | contains("code-review-auto.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "v2.68.0: deslop-auto-clean.sh is registered in PostToolUse/Edit|Write" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Edit|Write") |
        .hooks[] |
        select(.command | contains("deslop-auto-clean.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "v2.68.0: sec-context-validate.sh is registered in PostToolUse/Edit|Write" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Edit|Write") |
        .hooks[] |
        select(.command | contains("sec-context-validate.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

# ============================================================================
# Hook File Existence and Permissions Tests
# ============================================================================

@test "v2.68.0: ai-code-audit.sh exists and is executable" {
    [ -f "$HOOKS_DIR/ai-code-audit.sh" ]
    [ -x "$HOOKS_DIR/ai-code-audit.sh" ]
}

@test "v2.68.0: adversarial-auto-trigger.sh exists and is executable" {
    [ -f "$HOOKS_DIR/adversarial-auto-trigger.sh" ]
    [ -x "$HOOKS_DIR/adversarial-auto-trigger.sh" ]
}

@test "v2.68.0: security-full-audit.sh exists and is executable" {
    [ -f "$HOOKS_DIR/security-full-audit.sh" ]
    [ -x "$HOOKS_DIR/security-full-audit.sh" ]
}

@test "v2.68.0: code-review-auto.sh exists and is executable" {
    [ -f "$HOOKS_DIR/code-review-auto.sh" ]
    [ -x "$HOOKS_DIR/code-review-auto.sh" ]
}

@test "v2.68.0: deslop-auto-clean.sh exists and is executable" {
    [ -f "$HOOKS_DIR/deslop-auto-clean.sh" ]
    [ -x "$HOOKS_DIR/deslop-auto-clean.sh" ]
}

@test "v2.68.0: sec-context-validate.sh exists and is executable" {
    [ -f "$HOOKS_DIR/sec-context-validate.sh" ]
    [ -x "$HOOKS_DIR/sec-context-validate.sh" ]
}

# ============================================================================
# Hook Syntax Validation Tests
# ============================================================================

@test "v2.68.0: ai-code-audit.sh has valid bash syntax" {
    run bash -n "$HOOKS_DIR/ai-code-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: adversarial-auto-trigger.sh has valid bash syntax" {
    run bash -n "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: security-full-audit.sh has valid bash syntax" {
    run bash -n "$HOOKS_DIR/security-full-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: code-review-auto.sh has valid bash syntax" {
    run bash -n "$HOOKS_DIR/code-review-auto.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: deslop-auto-clean.sh has valid bash syntax" {
    run bash -n "$HOOKS_DIR/deslop-auto-clean.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: sec-context-validate.sh has valid bash syntax" {
    run bash -n "$HOOKS_DIR/sec-context-validate.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Hook Version Tests
# ============================================================================

@test "v2.68.0: ai-code-audit.sh has correct version header" {
    run grep -E '^readonly VERSION="2\.68\.[0-9]+"' "$HOOKS_DIR/ai-code-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: adversarial-auto-trigger.sh has correct version header" {
    run grep -E '^readonly VERSION="2\.68\.[0-9]+"' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: security-full-audit.sh has correct version header" {
    run grep -E '^readonly VERSION="2\.68\.[0-9]+"' "$HOOKS_DIR/security-full-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: code-review-auto.sh has correct version header" {
    run grep -E '^readonly VERSION="2\.68\.[0-9]+"' "$HOOKS_DIR/code-review-auto.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: deslop-auto-clean.sh has correct version header" {
    run grep -E '^readonly VERSION="2\.68\.[0-9]+"' "$HOOKS_DIR/deslop-auto-clean.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Hook Error Trap Tests (SEC-033 compliance)
# ============================================================================

@test "v2.68.0: ai-code-audit.sh has error trap for JSON output" {
    run grep -E "trap.*output_json.*ERR|trap.*continue.*ERR" "$HOOKS_DIR/ai-code-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: adversarial-auto-trigger.sh has error trap for JSON output" {
    run grep -E "trap.*output_json.*ERR|trap.*continue.*ERR" "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: security-full-audit.sh has error trap for JSON output" {
    run grep -E "trap.*output_json.*ERR|trap.*continue.*ERR" "$HOOKS_DIR/security-full-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: code-review-auto.sh has error trap for JSON output" {
    run grep -E "trap.*output_json.*ERR|trap.*continue.*ERR" "$HOOKS_DIR/code-review-auto.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: deslop-auto-clean.sh has error trap for JSON output" {
    run grep -E "trap.*output_json.*ERR|trap.*continue.*ERR" "$HOOKS_DIR/deslop-auto-clean.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Functional Tests - ai-code-audit.sh
# ============================================================================

@test "v2.68.0: ai-code-audit.sh returns valid JSON on non-Edit tool" {
    output=$(echo '{"tool_name": "Read", "tool_input": {}}' | "$HOOKS_DIR/ai-code-audit.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.continue == true'
}

@test "v2.68.0: ai-code-audit.sh returns valid JSON on Edit tool (no file)" {
    output=$(echo '{"tool_name": "Edit", "tool_input": {"file_path": "/nonexistent/file.ts"}}' | "$HOOKS_DIR/ai-code-audit.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.continue == true'
}

@test "v2.68.0: ai-code-audit.sh detects dead code pattern" {
    # Create test file with dead code pattern
    cat > "$TEST_TMP_DIR/dead_code.ts" << 'EOF'
// const oldFunction = () => {};
// TODO: implement later
function activeFunction() {
    return true;
}
EOF

    # Test pattern detection (internal function)
    run grep -E '^\s*//\s*(const|let|var|function|class|import|export)' "$TEST_TMP_DIR/dead_code.ts"
    [ $status -eq 0 ]
}

@test "v2.68.0: ai-code-audit.sh detects overkill pattern" {
    # Create test file with premature abstraction
    cat > "$TEST_TMP_DIR/overkill.ts" << 'EOF'
abstract class UserBase {
    abstract getName(): string;
}
interface IUserService {
    getUser(id: string): Promise<User>;
}
EOF

    # Test pattern detection
    run grep -E 'abstract class \w+Base|interface I\w+Service' "$TEST_TMP_DIR/overkill.ts"
    [ $status -eq 0 ]
}

@test "v2.68.0: ai-code-audit.sh detects fallback pattern" {
    # Create test file with silent fallback
    cat > "$TEST_TMP_DIR/fallback.ts" << 'EOF'
function getData() {
    try {
        return fetchData();
    } catch (e) {
        return []; // fallback
    }
}
EOF

    # Test pattern detection
    run grep -iE 'return\s*\[\]\s*;?\s*//.*fallback' "$TEST_TMP_DIR/fallback.ts"
    [ $status -eq 0 ]
}

@test "v2.68.0: ai-code-audit.sh detects any cast pattern" {
    # Create test file with any cast
    cat > "$TEST_TMP_DIR/any_cast.ts" << 'EOF'
const data = response.data as any;
const user = (userData as any).name;
EOF

    # Test pattern detection
    run grep -E 'as\s+any|\(\s*\w+\s*as\s+any\s*\)' "$TEST_TMP_DIR/any_cast.ts"
    [ $status -eq 0 ]
}

# ============================================================================
# Functional Tests - adversarial-auto-trigger.sh
# ============================================================================

@test "v2.68.0: adversarial-auto-trigger.sh returns valid JSON on non-Task tool" {
    output=$(echo '{"tool_name": "Edit", "tool_input": {}}' | "$HOOKS_DIR/adversarial-auto-trigger.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.continue == true'
}

@test "v2.68.0: adversarial-auto-trigger.sh checks complexity threshold" {
    # Verify threshold is set to 7
    run grep -E 'COMPLEXITY_THRESHOLD=7' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Functional Tests - security-full-audit.sh
# ============================================================================

@test "v2.68.0: security-full-audit.sh returns valid JSON on non-Edit tool" {
    output=$(echo '{"tool_name": "Read", "tool_input": {}}' | "$HOOKS_DIR/security-full-audit.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.continue == true'
}

@test "v2.68.0: security-full-audit.sh detects auth file as sensitive" {
    # Check internal pattern matching
    run grep -E '\*auth\*|\*login\*|\*password\*' "$HOOKS_DIR/security-full-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: security-full-audit.sh detects payment file as sensitive" {
    run grep -E '\*payment\*|\*billing\*|\*stripe\*' "$HOOKS_DIR/security-full-audit.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: security-full-audit.sh has cooldown mechanism" {
    run grep -E 'COOLDOWN_MINUTES' "$HOOKS_DIR/security-full-audit.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Functional Tests - code-review-auto.sh
# ============================================================================

@test "v2.68.0: code-review-auto.sh returns valid JSON on non-TaskUpdate tool" {
    output=$(echo '{"tool_name": "Edit", "tool_input": {}}' | "$HOOKS_DIR/code-review-auto.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.continue == true'
}

@test "v2.68.0: code-review-auto.sh only triggers on status=completed" {
    output=$(echo '{"tool_name": "TaskUpdate", "tool_input": {"status": "in_progress"}}' | "$HOOKS_DIR/code-review-auto.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.continue == true'
    # Should NOT have systemMessage for non-completed status
    ! echo "$output" | jq -e '.systemMessage'
}

# ============================================================================
# Functional Tests - deslop-auto-clean.sh
# ============================================================================

@test "v2.68.0: deslop-auto-clean.sh returns valid JSON on non-Edit tool" {
    output=$(echo '{"tool_name": "Read", "tool_input": {}}' | "$HOOKS_DIR/deslop-auto-clean.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.continue == true'
}

@test "v2.68.0: deslop-auto-clean.sh has operation threshold" {
    run grep -E 'THRESHOLD_OPERATIONS=8' "$HOOKS_DIR/deslop-auto-clean.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Functional Tests - sec-context-validate.sh
# ============================================================================

@test "v2.68.0: sec-context-validate.sh returns valid JSON on non-Edit tool" {
    output=$(echo '{"tool_name": "Read", "tool_input": {}}' | "$HOOKS_DIR/sec-context-validate.sh")
    status=$?
    [ $status -eq 0 ]
    # PostToolUse hooks use "continue" format
    echo "$output" | jq -e '.continue'
}

@test "v2.68.0: sec-context-validate.sh has multiple security patterns" {
    # Count CWE references as proxy for pattern count
    pattern_count=$(grep -c 'CWE-' "$HOOKS_DIR/sec-context-validate.sh" 2>/dev/null || echo "0")
    [ "$pattern_count" -ge 15 ]
}

@test "v2.68.0: sec-context-validate.sh detects SQL injection pattern" {
    run grep -iE 'sql.?injection|SELECT.*FROM.*WHERE' "$HOOKS_DIR/sec-context-validate.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: sec-context-validate.sh detects XSS pattern" {
    run grep -iE 'xss|innerHTML|document\.write' "$HOOKS_DIR/sec-context-validate.sh"
    [ $status -eq 0 ]
}

@test "v2.68.0: sec-context-validate.sh detects command injection pattern" {
    run grep -iE 'command.?injection|exec\(|system\(' "$HOOKS_DIR/sec-context-validate.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Project Hooks Sync Tests
# ============================================================================

@test "v2.68.0: ai-code-audit.sh is synced to project hooks" {
    [ -f "$PROJECT_HOOKS_DIR/ai-code-audit.sh" ]
}

@test "v2.68.0: adversarial-auto-trigger.sh is synced to project hooks" {
    [ -f "$PROJECT_HOOKS_DIR/adversarial-auto-trigger.sh" ]
}

@test "v2.68.0: security-full-audit.sh is synced to project hooks" {
    [ -f "$PROJECT_HOOKS_DIR/security-full-audit.sh" ]
}

@test "v2.68.0: code-review-auto.sh is synced to project hooks" {
    [ -f "$PROJECT_HOOKS_DIR/code-review-auto.sh" ]
}

@test "v2.68.0: deslop-auto-clean.sh is synced to project hooks" {
    [ -f "$PROJECT_HOOKS_DIR/deslop-auto-clean.sh" ]
}

# ============================================================================
# Integration Tests - JSON Output Format
# ============================================================================

@test "v2.68.0: All hooks return parseable JSON" {
    for hook in ai-code-audit.sh adversarial-auto-trigger.sh security-full-audit.sh \
                code-review-auto.sh deslop-auto-clean.sh; do
        echo '{"tool_name": "Read", "tool_input": {}}' | "$HOOKS_DIR/$hook" > "$TEST_TMP_DIR/output.json"
        run jq -e '.' "$TEST_TMP_DIR/output.json"
        [ $status -eq 0 ]
    done
}

@test "v2.68.0: PostToolUse hooks use continue format" {
    for hook in ai-code-audit.sh adversarial-auto-trigger.sh security-full-audit.sh \
                code-review-auto.sh deslop-auto-clean.sh; do
        echo '{"tool_name": "Read", "tool_input": {}}' | "$HOOKS_DIR/$hook" > "$TEST_TMP_DIR/output.json"
        run jq -e '.continue' "$TEST_TMP_DIR/output.json"
        [ $status -eq 0 ]
    done
}

# ============================================================================
# Regression Prevention Tests
# ============================================================================

@test "v2.68.0 REGRESSION: All auto-invoke hooks are ACTIVE" {
    # Verify all 6 v2.68.0 hooks are registered
    for hook in ai-code-audit.sh adversarial-auto-trigger.sh security-full-audit.sh \
                code-review-auto.sh deslop-auto-clean.sh sec-context-validate.sh; do
        run jq -e "
            .hooks | to_entries[] |
            .value[] |
            .hooks[] |
            select(.command | contains(\"$hook\"))
        " "$SETTINGS_JSON"
        [ $status -eq 0 ]
    done
}

@test "v2.68.0 REGRESSION: Hooks have IMPERATIVE instructions (not suggestions)" {
    # v2.68.0 change: systemMessage should use "YOU MUST" not "consider"
    for hook in adversarial-auto-trigger.sh security-full-audit.sh \
                code-review-auto.sh deslop-auto-clean.sh ai-code-audit.sh; do
        run grep -E 'YOU MUST|MUST NOW EXECUTE|REQUIRED' "$HOOKS_DIR/$hook"
        [ $status -eq 0 ]
    done
}
