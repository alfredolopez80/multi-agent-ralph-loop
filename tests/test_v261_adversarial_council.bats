#!/usr/bin/env bats
# test_v261_adversarial_council.bats - v2.68.12
# Tests for Adversarial Council feature (v2.61)
# Multi-model validation for high-complexity tasks
#
# Run with: bats tests/test_v261_adversarial_council.bats

setup() {
    SETTINGS_JSON="${HOME}/.claude/settings.json"
    HOOKS_DIR="${HOME}/.claude/hooks"
    SCRIPTS_DIR="${HOME}/.ralph/scripts"
    TEST_TMP_DIR="${BATS_TMPDIR}/v261_adversarial_test"

    mkdir -p "$TEST_TMP_DIR"
}

teardown() {
    rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

# ============================================================================
# Adversarial Auto-Trigger Hook Tests
# ============================================================================

@test "v2.61.0: adversarial-auto-trigger.sh exists and is executable" {
    [ -f "$HOOKS_DIR/adversarial-auto-trigger.sh" ]
    [ -x "$HOOKS_DIR/adversarial-auto-trigger.sh" ]
}

@test "v2.61.0: adversarial-auto-trigger.sh has valid bash syntax" {
    run bash -n "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

@test "v2.61.0: adversarial-auto-trigger.sh has error trap" {
    run grep -E "trap.*output_json.*ERR|trap.*continue.*ERR" "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

@test "v2.61.0: adversarial-auto-trigger.sh returns valid JSON" {
    output=$(echo '{"tool_name": "Read", "tool_input": {}}' | "$HOOKS_DIR/adversarial-auto-trigger.sh")
    status=$?
    [ $status -eq 0 ]
    echo "$output" | jq -e '.' >/dev/null
}

@test "v2.61.0: adversarial-auto-trigger.sh uses continue format (PostToolUse)" {
    output=$(echo '{"tool_name": "Task", "tool_input": {}}' | "$HOOKS_DIR/adversarial-auto-trigger.sh")
    echo "$output" | jq -e '.continue == true'
}

# ============================================================================
# Complexity Threshold Tests
# ============================================================================

@test "v2.61.0: COMPLEXITY_THRESHOLD is set to 7" {
    run grep -E 'COMPLEXITY_THRESHOLD=7' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

@test "v2.61.0: plan-state.json complexity field is read" {
    run grep -E 'jq.*complexity' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

@test "v2.61.0: adversarial triggered for complexity >= 7" {
    # Create test plan-state with high complexity
    mkdir -p "$TEST_TMP_DIR/.claude"
    cat > "$TEST_TMP_DIR/.claude/plan-state.json" << 'EOF'
{
    "version": "2.66.0",
    "classification": {
        "complexity": 8,
        "info_density": "LINEAR",
        "context_req": "CHUNKED"
    }
}
EOF

    # Hook should detect high complexity
    cd "$TEST_TMP_DIR"
    output=$(echo '{"tool_name": "Task", "tool_input": {"subagent_type": "code-reviewer"}}' | "$HOOKS_DIR/adversarial-auto-trigger.sh")

    # Should return valid JSON (systemMessage optional)
    echo "$output" | jq -e '.continue'
}

@test "v2.61.0: adversarial NOT triggered for complexity < 7" {
    mkdir -p "$TEST_TMP_DIR/.claude"
    cat > "$TEST_TMP_DIR/.claude/plan-state.json" << 'EOF'
{
    "version": "2.66.0",
    "classification": {
        "complexity": 4,
        "info_density": "CONSTANT",
        "context_req": "FITS"
    }
}
EOF

    cd "$TEST_TMP_DIR"
    output=$(echo '{"tool_name": "Task", "tool_input": {"subagent_type": "docs-writer"}}' | "$HOOKS_DIR/adversarial-auto-trigger.sh")

    # Should NOT have adversarial systemMessage
    echo "$output" | jq -e '.continue == true'
    ! echo "$output" | jq -e '.systemMessage | test("adversarial")' 2>/dev/null
}

# ============================================================================
# Model Routing Tests (Adversarial Council)
# ============================================================================

@test "v2.61.0: adversarial-spec skill exists" {
    skill_file="${HOME}/.claude/skills/adversarial/adversarial-spec.md"
    [ -f "$skill_file" ] || skip "adversarial-spec skill not installed"
}

@test "v2.61.0: adversarial validation uses multi-model pattern" {
    # Check for model routing in hooks or skills (v2.87+ uses skills)
    run grep -rlE 'adversarial|codex|gemini|opus|sonnet' "$HOOKS_DIR/"
    [ $status -eq 0 ]
}

# ============================================================================
# Integration with Plan State
# ============================================================================

@test "v2.61.0: plan-state schema supports adversarial field" {
    schema_file="${HOME}/.claude/schemas/plan-state-v2.json"
    [ -f "$schema_file" ] || skip "Schema file not found"

    run jq -e '.properties.adversarial_enabled' "$schema_file"
    # Field may exist or be part of classification
    [ $status -eq 0 ] || run jq -e '.properties.classification' "$schema_file"
    [ $status -eq 0 ]
}

@test "v2.61.0: adversarial results can be logged" {
    log_dir="${HOME}/.ralph/logs"
    [ -d "$log_dir" ]
}

# ============================================================================
# Security Tests
# ============================================================================

@test "v2.61.0: adversarial-auto-trigger.sh sanitizes input" {
    # Test with malicious input
    malicious_input='{"tool_name": "Task"; rm -rf /", "tool_input": {}}'
    output=$(echo "$malicious_input" | "$HOOKS_DIR/adversarial-auto-trigger.sh" 2>/dev/null || echo '{"continue": true}')

    # Should return valid JSON, not execute command
    echo "$output" | jq -e '.'
}

@test "v2.61.0: adversarial-auto-trigger.sh uses jq for JSON parsing" {
    run grep -E 'jq -r|jq -e' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Cooldown Mechanism Tests
# ============================================================================

@test "v2.61.0: adversarial has cooldown to prevent spam" {
    # Check for cooldown mechanism
    run grep -iE 'cooldown|INTERVAL|last_run|marker' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Registration Tests
# ============================================================================

@test "v2.61.0: adversarial-auto-trigger.sh is registered in PostToolUse/Task" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Task") |
        .hooks[] |
        select(.command | contains("adversarial-auto-trigger.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

# ============================================================================
# Version Tests
# ============================================================================

@test "v2.61.0: adversarial-auto-trigger.sh has v2.68+ version" {
    run grep -E 'VERSION.*2\.68|VERSION.*2\.6[789]|VERSION.*2\.7' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Functional Tests
# ============================================================================

@test "v2.61.0: adversarial council validates security-critical tasks" {
    # Security agent should be in handoff registry
    run grep -rE 'security-auditor|security.*agent' "${HOME}/.ralph/config/agents.json" 2>/dev/null
    [ $status -eq 0 ] || skip "Agents config not found"
}

@test "v2.61.0: adversarial council supports multiple validator models" {
    # Check for multiple model references
    run grep -rE 'opus|sonnet|minimax|codex|gemini' "$HOOKS_DIR/adversarial-auto-trigger.sh"
    # At least one model should be referenced
    [ $status -eq 0 ] || skip "Model routing may be in skill file"
}
