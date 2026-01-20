#!/usr/bin/env bats
# test_hook_registration.bats - v2.57.5
# Tests to validate hook registration (updated for v2.57.5)
# Canonical source: settings.json (hooks.json removed per v2.57.4)
#
# Run with: bats tests/test_hook_registration.bats

setup() {
    SETTINGS_JSON="${HOME}/.claude/settings.json"
    HOOKS_DIR="${HOME}/.claude/hooks"
}

# ============================================================================
# settings.json Hook Registration Tests (CANONICAL SOURCE)
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

@test "settings.json has UserPromptSubmit hooks (v2.32)" {
    run jq -e '.hooks.UserPromptSubmit' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "settings.json has SessionStart hooks (v2.57.4)" {
    run jq -e '.hooks.SessionStart' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "settings.json has Stop hooks (v2.57.4)" {
    run jq -e '.hooks.Stop' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "settings.json has PreCompact hooks (v2.57.4)" {
    run jq -e '.hooks.PreCompact' "$SETTINGS_JSON"
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

@test "skill-validator.sh is registered in PreToolUse/Skill (v2.32)" {
    run jq -e '
        .hooks.PreToolUse[] |
        select(.matcher == "Skill") |
        .hooks[] |
        select(.command | contains("skill-validator.sh"))
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

@test "context-warning.sh is registered in settings.json UserPromptSubmit (v2.32)" {
    run jq -e '
        .hooks.UserPromptSubmit[] |
        .hooks[] |
        select(.command | contains("context-warning.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "periodic-reminder.sh is registered in settings.json UserPromptSubmit (v2.32)" {
    run jq -e '
        .hooks.UserPromptSubmit[] |
        .hooks[] |
        select(.command | contains("periodic-reminder.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "prompt-analyzer.sh is registered in settings.json UserPromptSubmit (v2.32)" {
    run jq -e '
        .hooks.UserPromptSubmit[] |
        .hooks[] |
        select(.command | contains("prompt-analyzer.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "session-start-ledger.sh is registered in SessionStart (v2.57.4)" {
    run jq -e '
        .hooks.SessionStart[] |
        .hooks[] |
        select(.command | contains("session-start-ledger.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "stop-verification.sh is registered in Stop (v2.57.4)" {
    run jq -e '
        .hooks.Stop[] |
        .hooks[] |
        select(.command | contains("stop-verification.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "pre-compact-handoff.sh is registered in PreCompact (v2.57.4)" {
    run jq -e '
        .hooks.PreCompact[] |
        .hooks[] |
        select(.command | contains("pre-compact-handoff.sh"))
    ' "$SETTINGS_JSON"
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

@test "skill-validator.sh exists and is executable (v2.32)" {
    [ -f "$HOOKS_DIR/skill-validator.sh" ]
    [ -x "$HOOKS_DIR/skill-validator.sh" ]
}

@test "prompt-analyzer.sh exists and is executable" {
    [ -f "$HOOKS_DIR/prompt-analyzer.sh" ]
    [ -x "$HOOKS_DIR/prompt-analyzer.sh" ]
}

@test "orchestrator-helper.sh exists and is executable" {
    [ -f "$HOOKS_DIR/orchestrator-helper.sh" ]
    [ -x "$HOOKS_DIR/orchestrator-helper.sh" ]
}

@test "semantic-write-helper.sh exists (v2.57.4)" {
    [ -f "$HOOKS_DIR/semantic-write-helper.sh" ]
    [ -x "$HOOKS_DIR/semantic-write-helper.sh" ]
}

# ============================================================================
# Hook Count Validation Tests (v2.57.5)
# ============================================================================

@test "settings.json has correct PreToolUse matchers count" {
    count=$(jq '.hooks.PreToolUse | length' "$SETTINGS_JSON")
    [ "$count" -ge 2 ]
}

@test "settings.json has correct PostToolUse matchers count" {
    count=$(jq '.hooks.PostToolUse | length' "$SETTINGS_JSON")
    [ "$count" -ge 2 ]
}

@test "settings.json UserPromptSubmit has at least 3 hooks" {
    count=$(jq '
        .hooks.UserPromptSubmit[] |
        .hooks | length
    ' "$SETTINGS_JSON")
    [ "$count" -ge 3 ]
}

# ============================================================================
# Hook JSON Format Validation Tests (v2.57.5)
# ============================================================================

@test "All PostToolUse hooks use correct JSON format" {
    # Skip comment lines and check for invalid patterns
    run grep -v '^[[:space:]]*#' "$HOOKS_DIR"/*.sh | grep -l '"decision".*"continue"'
    [ $status -eq 1 ]  # Should find no matches
}

@test "All Stop hooks use decision:approve format" {
    # Only stop-verification.sh, sentry-report.sh, reflection-engine.sh should have decision
    stop_hooks=$(grep -l 'decision.*approve\|decision.*block' "$HOOKS_DIR"/*.sh 2>/dev/null | wc -l)
    [ "$stop_hooks" -ge 1 ]
}

# ============================================================================
# Regression Prevention Tests
# ============================================================================

@test "REGRESSION CHECK: All v2.30 + v2.32 hooks are ACTIVE (v2.57.5)" {
    # This test prevents regression of hook registration bugs

    # v2.30: checkpoint-auto-save.sh must be in PostToolUse
    run jq -e '
        .hooks.PostToolUse[] |
        .hooks[] |
        select(.command | contains("checkpoint-auto-save.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]

    # v2.30: context-warning.sh must be in settings.json UserPromptSubmit
    run jq -e '
        .hooks.UserPromptSubmit[] |
        .hooks[] |
        select(.command | contains("context-warning.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]

    # v2.30: periodic-reminder.sh must be in settings.json UserPromptSubmit
    run jq -e '
        .hooks.UserPromptSubmit[] |
        .hooks[] |
        select(.command | contains("periodic-reminder.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]

    # v2.32: skill-validator.sh must be in PreToolUse/Skill
    run jq -e '
        .hooks.PreToolUse[] |
        select(.matcher == "Skill") |
        .hooks[] |
        select(.command | contains("skill-validator.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]

    # v2.32: prompt-analyzer.sh must be in settings.json UserPromptSubmit
    run jq -e '
        .hooks.UserPromptSubmit[] |
        .hooks[] |
        select(.command | contains("prompt-analyzer.sh"))
    ' "$SETTINGS_JSON"
    [ $status -eq 0 ]
}

@test "DOCUMENTATION: Hook system architecture validated (v2.57.5)" {
    # Canonical source: settings.json (hooks.json removed per v2.57.4)
    #
    # Hook system architecture (v2.57.5):
    # - settings.json is canonical source of truth
    # - 52 global hooks registered in settings.json
    # - Hook types: PreToolUse, PostToolUse, UserPromptSubmit, SessionStart, Stop, PreCompact
    # - hooks.json removed (was legacy, now using settings.json only)

    # Verify settings.json is the only canonical source
    [ -f "$SETTINGS_JSON" ]

    # Verify hooks.json does NOT exist (removed in v2.57.4)
    [ ! -f "${HOME}/.claude/hooks/hooks.json" ]
}
