#!/usr/bin/env bats
# test_hook_registration.bats - v2.32
# Tests to validate hook registration (fixing v2.30 issue)
# Ensures hooks are properly registered and won't go inactive again
#
# Run with: bats tests/test_hook_registration.bats

setup() {
    SETTINGS_JSON="${HOME}/.claude/settings.json"
    HOOKS_JSON="${HOME}/.claude/hooks/hooks.json"
    HOOKS_DIR="${HOME}/.claude/hooks"
}

# ============================================================================
# settings.json Hook Registration Tests
# ============================================================================

@test "settings.json exists and is readable" {
    [ -f "$SETTINGS_JSON" ]
    [ -r "$SETTINGS_JSON" ]
}

@test "settings.json has valid JSON syntax" {
    run jq empty "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "settings.json has hooks section" {
    run jq -e '.hooks' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "settings.json has PreToolUse hooks" {
    run jq -e '.hooks.PreToolUse' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "settings.json has PostToolUse hooks" {
    run jq -e '.hooks.PostToolUse' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "git-safety-guard.py is registered in PreToolUse/Bash" {
    run jq -e '
        .hooks.PreToolUse[] |
        select(.matcher == "Bash") |
        .hooks[] |
        select(.command | contains("git-safety-guard.py"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "quality-gates.sh is registered in PostToolUse/Edit" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Edit") |
        .hooks[] |
        select(.command | contains("quality-gates.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "quality-gates.sh is registered in PostToolUse/Write" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Write") |
        .hooks[] |
        select(.command | contains("quality-gates.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "checkpoint-auto-save.sh is registered in PostToolUse/Edit (v2.30 fix)" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Edit") |
        .hooks[] |
        select(.command | contains("checkpoint-auto-save.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "checkpoint-auto-save.sh is registered in PostToolUse/Write (v2.30 fix)" {
    run jq -e '
        .hooks.PostToolUse[] |
        select(.matcher == "Write") |
        .hooks[] |
        select(.command | contains("checkpoint-auto-save.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

# ============================================================================
# hooks.json Event Hook Registration Tests
# ============================================================================

@test "hooks.json exists and is readable" {
    [ -f "$HOOKS_JSON" ]
    [ -r "$HOOKS_JSON" ]
}

@test "hooks.json has valid JSON syntax" {
    run jq empty "$HOOKS_JSON"
    [ $status -eq 0 ]
}

@test "hooks.json has hooks array" {
    run jq -e '.hooks | type == "array"' "$HOOKS_JSON"
    [ $status -eq 0 ]
}

@test "session-start-welcome.sh is registered in SessionStart" {
    run jq -e '
        .hooks[] |
        select(.event == "SessionStart") |
        select(.command.args[] | contains("session-start-welcome.sh"))
    ' "$HOOKS_JSON"
    [ $status -eq 0 ]
}

@test "context-warning.sh is registered in UserPromptSubmit (v2.30 fix)" {
    run jq -e '
        .hooks[] |
        select(.event == "UserPromptSubmit") |
        select(.command.args[] | contains("context-warning.sh"))
    ' "$HOOKS_JSON"
    [ $status -eq 0 ]
}

@test "periodic-reminder.sh is registered in UserPromptSubmit (v2.30 fix)" {
    run jq -e '
        .hooks[] |
        select(.event == "UserPromptSubmit") |
        select(.command.args[] | contains("periodic-reminder.sh"))
    ' "$HOOKS_JSON"
    [ $status -eq 0 ]
}

# ============================================================================
# Hook File Existence Tests
# ============================================================================

@test "hooks directory exists" {
    [ -d "$HOOKS_DIR" ]
}

@test "git-safety-guard.py exists and is executable" {
    [ -f "$HOOKS_DIR/git-safety-guard.py" ]
    [ -x "$HOOKS_DIR/git-safety-guard.py" ]
}

@test "quality-gates.sh exists and is executable" {
    [ -f "$HOOKS_DIR/quality-gates.sh" ]
    [ -x "$HOOKS_DIR/quality-gates.sh" ]
}

@test "checkpoint-auto-save.sh exists and is executable (v2.30)" {
    [ -f "$HOOKS_DIR/checkpoint-auto-save.sh" ]
    [ -x "$HOOKS_DIR/checkpoint-auto-save.sh" ]
}

@test "context-warning.sh exists and is executable (v2.30)" {
    [ -f "$HOOKS_DIR/context-warning.sh" ]
    [ -x "$HOOKS_DIR/context-warning.sh" ]
}

@test "periodic-reminder.sh exists and is executable (v2.30)" {
    [ -f "$HOOKS_DIR/periodic-reminder.sh" ]
    [ -x "$HOOKS_DIR/periodic-reminder.sh" ]
}

@test "session-start-welcome.sh exists and is executable" {
    [ -f "$HOOKS_DIR/session-start-welcome.sh" ]
    [ -x "$HOOKS_DIR/session-start-welcome.sh" ]
}

# ============================================================================
# Hook Count Validation Tests (prevent regression)
# ============================================================================

@test "settings.json has exactly 1 PreToolUse matcher (Bash)" {
    count=$(jq '.hooks.PreToolUse | length' "$SETTINGS_JSON")
    [ "$count" -eq 1 ]
}

@test "settings.json has exactly 2 PostToolUse matchers (Edit + Write)" {
    count=$(jq '.hooks.PostToolUse | length' "$SETTINGS_JSON")
    [ "$count" -eq 2 ]
}

@test "settings.json PostToolUse/Edit has exactly 2 hooks (quality-gates + checkpoint)" {
    count=$(jq '
        .hooks.PostToolUse[] |
        select(.matcher == "Edit") |
        .hooks | length
    ' "$SETTINGS_JSON")
    [ "$count" -eq 2 ]
}

@test "settings.json PostToolUse/Write has exactly 2 hooks (quality-gates + checkpoint)" {
    count=$(jq '
        .hooks.PostToolUse[] |
        select(.matcher == "Write") |
        .hooks | length
    ' "$SETTINGS_JSON")
    [ "$count" -eq 2 ]
}

@test "hooks.json has at least 3 hooks registered (SessionStart + 2x UserPromptSubmit)" {
    count=$(jq '.hooks | length' "$HOOKS_JSON")
    [ "$count" -ge 3 ]
}

@test "hooks.json has exactly 2 UserPromptSubmit hooks (context-warning + periodic-reminder)" {
    count=$(jq '[.hooks[] | select(.event == "UserPromptSubmit")] | length' "$HOOKS_JSON")
    [ "$count" -eq 2 ]
}

# ============================================================================
# Hook Content Validation Tests
# ============================================================================

@test "checkpoint-auto-save.sh has correct header (v2.30)" {
    run grep -q "checkpoint-auto-save.sh - v2.30" "$HOOKS_DIR/checkpoint-auto-save.sh"
    [ $status -eq 0 ]
}

@test "context-warning.sh has correct header (v2.30)" {
    run grep -q "context-warning.sh" "$HOOKS_DIR/context-warning.sh"
    [ $status -eq 0 ]
}

@test "periodic-reminder.sh has correct header (v2.30)" {
    run grep -q "periodic-reminder.sh - v2.30" "$HOOKS_DIR/periodic-reminder.sh"
    [ $status -eq 0 ]
}

# ============================================================================
# Regression Prevention Tests
# ============================================================================

@test "REGRESSION CHECK: All v2.30 hooks are ACTIVE (not INACTIVE)" {
    # This test documents the v2.30 bug that was fixed
    # checkpoint-auto-save.sh must be in PostToolUse
    run jq -e '
        .hooks.PostToolUse[] |
        .hooks[] |
        select(.command | contains("checkpoint-auto-save.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]  # checkpoint-auto-save.sh MUST be registered in PostToolUse

    # context-warning.sh must be in hooks.json UserPromptSubmit
    run jq -e '
        .hooks[] |
        select(.event == "UserPromptSubmit") |
        select(.command.args[] | contains("context-warning.sh"))
    ' "$HOOKS_JSON"
    [ $status -eq 0 ]  # context-warning.sh MUST be registered in UserPromptSubmit

    # periodic-reminder.sh must be in hooks.json UserPromptSubmit
    run jq -e '
        .hooks[] |
        select(.event == "UserPromptSubmit") |
        select(.command.args[] | contains("periodic-reminder.sh"))
    ' "$HOOKS_JSON"
    [ $status -eq 0 ]  # periodic-reminder.sh MUST be registered in UserPromptSubmit
}

@test "DOCUMENTATION: Hook system architecture is validated" {
    # Two hook systems exist:
    # 1. settings.json - PreToolUse/PostToolUse (git-safety-guard, quality-gates, checkpoint-auto-save)
    # 2. hooks.json - Event hooks (SessionStart, UserPromptSubmit)

    # Verify both systems are present
    [ -f "$SETTINGS_JSON" ] && [ -f "$HOOKS_JSON" ]
}
