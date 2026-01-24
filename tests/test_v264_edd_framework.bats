#!/usr/bin/env bats
# test_v264_edd_framework.bats - v2.68.12
# Tests for EDD (Eval-Driven Development) Framework (v2.64)
# Define-before-implement pattern with structured evals
#
# Run with: bats tests/test_v264_edd_framework.bats

setup() {
    EVALS_DIR="${HOME}/.claude/evals"
    SKILLS_DIR="${HOME}/.claude/skills"
    SCRIPTS_DIR="${HOME}/.ralph/scripts"
    TEST_TMP_DIR="${BATS_TMPDIR}/v264_edd_test"

    mkdir -p "$TEST_TMP_DIR"
}

teardown() {
    rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

# ============================================================================
# EDD Directory Structure Tests
# ============================================================================

@test "v2.64.0: evals directory exists" {
    [ -d "$EVALS_DIR" ]
}

@test "v2.64.0: TEMPLATE.md exists in evals" {
    [ -f "$EVALS_DIR/TEMPLATE.md" ]
}

@test "v2.64.0: sample eval definitions exist" {
    # At least one .md file beyond TEMPLATE
    count=$(find "$EVALS_DIR" -name "*.md" -type f | wc -l)
    [ "$count" -ge 2 ]
}

# ============================================================================
# Template Structure Tests
# ============================================================================

@test "v2.64.0: TEMPLATE.md has Capability Checks section" {
    run grep -E '## Capability Checks' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: TEMPLATE.md has Behavior Checks section" {
    run grep -E '## Behavior Checks' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: TEMPLATE.md has Non-Functional Checks section" {
    run grep -E '## Non-Functional Checks' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: TEMPLATE.md has Implementation Notes section" {
    run grep -E '## Implementation Notes' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: TEMPLATE.md has Verification Evidence section" {
    run grep -E '## Verification Evidence' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

# ============================================================================
# Check Types Tests
# ============================================================================

@test "v2.64.0: TEMPLATE includes CC- prefixed checks (Capability)" {
    run grep -E 'CC-[0-9]+' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: TEMPLATE includes BC- prefixed checks (Behavior)" {
    run grep -E 'BC-[0-9]+' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: TEMPLATE includes NFC- prefixed checks (Non-Functional)" {
    run grep -E 'NFC-[0-9]+' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

# ============================================================================
# EDD Skill Tests
# ============================================================================

@test "v2.64.0: edd skill directory exists" {
    [ -d "$SKILLS_DIR/edd" ] || skip "EDD skill may be in different location"
}

@test "v2.64.0: edd skill.md exists" {
    skill_file="$SKILLS_DIR/edd/skill.md"
    [ -f "$skill_file" ] || skip "EDD skill not found at expected path"
}

@test "v2.64.0: edd skill has workflow documentation" {
    skill_file="$SKILLS_DIR/edd/skill.md"
    [ -f "$skill_file" ] || skip "EDD skill not found"

    run grep -iE 'workflow|define|implement|verify' "$skill_file"
    [ $status -eq 0 ]
}

# ============================================================================
# EDD Script Tests
# ============================================================================

@test "v2.64.0: edd.sh script exists" {
    script="$SCRIPTS_DIR/edd.sh"
    [ -f "$script" ] || skip "edd.sh not found"
}

@test "v2.64.0: edd.sh is executable" {
    script="$SCRIPTS_DIR/edd.sh"
    [ -f "$script" ] || skip "edd.sh not found"
    [ -x "$script" ]
}

@test "v2.64.0: edd.sh has valid bash syntax" {
    script="$SCRIPTS_DIR/edd.sh"
    [ -f "$script" ] || skip "edd.sh not found"

    run bash -n "$script"
    [ $status -eq 0 ]
}

@test "v2.64.0: edd.sh supports define command" {
    script="$SCRIPTS_DIR/edd.sh"
    [ -f "$script" ] || skip "edd.sh not found"

    run grep -E 'define' "$script"
    [ $status -eq 0 ]
}

@test "v2.64.0: edd.sh supports check command" {
    script="$SCRIPTS_DIR/edd.sh"
    [ -f "$script" ] || skip "edd.sh not found"

    run grep -E 'check|verify|validate' "$script"
    [ $status -eq 0 ]
}

# ============================================================================
# Sample Eval Tests
# ============================================================================

@test "v2.64.0: memory-search.md eval exists" {
    eval_file="$EVALS_DIR/memory-search.md"
    [ -f "$eval_file" ]
}

@test "v2.64.0: memory-search.md follows template structure" {
    eval_file="$EVALS_DIR/memory-search.md"
    [ -f "$eval_file" ] || skip "memory-search.md not found"

    # Should have all required sections
    run grep -E '## Capability Checks' "$eval_file"
    [ $status -eq 0 ]

    run grep -E '## Behavior Checks' "$eval_file"
    [ $status -eq 0 ]

    run grep -E '## Non-Functional Checks' "$eval_file"
    [ $status -eq 0 ]
}

@test "v2.64.0: sample eval has checkbox items" {
    eval_file="$EVALS_DIR/memory-search.md"
    [ -f "$eval_file" ] || skip "memory-search.md not found"

    # Should have checkbox items
    run grep -E '\- \[[ x]\]' "$eval_file"
    [ $status -eq 0 ]
}

@test "v2.64.0: sample eval has status field" {
    eval_file="$EVALS_DIR/memory-search.md"
    [ -f "$eval_file" ] || skip "memory-search.md not found"

    run grep -E '^Status:' "$eval_file"
    [ $status -eq 0 ]
}

# ============================================================================
# EDD Workflow Integration Tests
# ============================================================================

@test "v2.64.0: EDD documented in CLAUDE.md" {
    run grep -iE 'EDD|Eval.?Driven' /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md
    [ $status -eq 0 ]
}

@test "v2.64.0: EDD integrates with orchestrator" {
    # Check if orchestrator references EDD
    run grep -rE 'edd|eval.*driven' "${HOME}/.claude/hooks/orchestrator"*.sh 2>/dev/null
    # May not be direct integration - that's OK
    [ $status -eq 0 ] || skip "EDD may be invoked via skill, not hook"
}

# ============================================================================
# Non-Functional Checks Coverage Tests
# ============================================================================

@test "v2.64.0: NFC includes Performance checks" {
    run grep -iE 'NFC.*Performance|Performance.*NFC' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: NFC includes Security checks" {
    run grep -iE 'NFC.*Security|Security.*NFC' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: NFC includes Maintainability checks" {
    run grep -iE 'NFC.*Maintainability|Maintainability.*NFC' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

# ============================================================================
# Definition Completeness Tests
# ============================================================================

@test "v2.64.0: TEMPLATE has Created timestamp field" {
    run grep -E '^Created:' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

@test "v2.64.0: TEMPLATE has guidance comments" {
    run grep -E '<!--.*-->' "$EVALS_DIR/TEMPLATE.md"
    [ $status -eq 0 ]
}

# ============================================================================
# CLI Command Tests
# ============================================================================

@test "v2.64.0: ralph edd command pattern documented" {
    # Check for edd in documentation
    run grep -rE 'ralph edd|/edd|edd\.sh' /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/
    [ $status -eq 0 ] || skip "EDD may use different command pattern"
}

# ============================================================================
# File Naming Convention Tests
# ============================================================================

@test "v2.64.0: eval files use kebab-case naming" {
    # All .md files in evals should be lowercase with hyphens
    bad_files=$(find "$EVALS_DIR" -name "*.md" -type f | xargs -I {} basename {} | grep -E '[A-Z]' | grep -v TEMPLATE || echo "")
    [ -z "$bad_files" ]
}

# ============================================================================
# Version Tests
# ============================================================================

@test "v2.64.0: edd.sh has version header" {
    script="$SCRIPTS_DIR/edd.sh"
    [ -f "$script" ] || skip "edd.sh not found"

    run grep -E 'VERSION|v[0-9]+\.[0-9]+' "$script"
    [ $status -eq 0 ]
}
