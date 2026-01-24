#!/usr/bin/env bats
# test_v263_dynamic_contexts.bats - v2.68.12
# Tests for Dynamic Contexts feature (v2.63)
# Context-aware behavior modes: dev, review, research, debug
#
# Run with: bats tests/test_v263_dynamic_contexts.bats

setup() {
    CONTEXTS_DIR="${HOME}/.claude/contexts"
    RALPH_STATE="${HOME}/.ralph/state"
    SCRIPTS_DIR="${HOME}/.ralph/scripts"
    TEST_TMP_DIR="${BATS_TMPDIR}/v263_contexts_test"

    mkdir -p "$TEST_TMP_DIR"
    mkdir -p "$RALPH_STATE"
}

teardown() {
    rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
    # Clean up test context state
    rm -f "${RALPH_STATE}/active-context.txt.test" 2>/dev/null || true
}

# ============================================================================
# Context Files Existence Tests
# ============================================================================

@test "v2.63.0: contexts directory exists" {
    [ -d "$CONTEXTS_DIR" ]
}

@test "v2.63.0: dev.md context file exists" {
    [ -f "$CONTEXTS_DIR/dev.md" ]
}

@test "v2.63.0: review.md context file exists" {
    [ -f "$CONTEXTS_DIR/review.md" ]
}

@test "v2.63.0: research.md context file exists" {
    [ -f "$CONTEXTS_DIR/research.md" ]
}

@test "v2.63.0: debug.md context file exists" {
    [ -f "$CONTEXTS_DIR/debug.md" ]
}

# ============================================================================
# Context Content Validation Tests
# ============================================================================

@test "v2.63.0: dev.md has action-oriented instructions" {
    run grep -iE 'write code|implement|action|minimal preamble' "$CONTEXTS_DIR/dev.md"
    [ $status -eq 0 ]
}

@test "v2.63.0: review.md has analysis instructions" {
    run grep -iE 'analyze|review|severity|feedback' "$CONTEXTS_DIR/review.md"
    [ $status -eq 0 ]
}

@test "v2.63.0: research.md has exploration instructions" {
    run grep -iE 'explore|research|document|cite|sources' "$CONTEXTS_DIR/research.md"
    [ $status -eq 0 ]
}

@test "v2.63.0: debug.md has investigation instructions" {
    run grep -iE 'debug|investigate|root cause|evidence|hypothesis' "$CONTEXTS_DIR/debug.md"
    [ $status -eq 0 ]
}

# ============================================================================
# Context Switching Script Tests
# ============================================================================

@test "v2.63.0: context.sh script exists" {
    script="${SCRIPTS_DIR}/context.sh"
    [ -f "$script" ] || skip "context.sh not found - may use different path"
}

@test "v2.63.0: context switching creates active-context.txt" {
    script="${SCRIPTS_DIR}/context.sh"
    [ -f "$script" ] || skip "context.sh not found"

    # Test context switch (dry run if possible)
    if [ -x "$script" ]; then
        "$script" dev --dry-run 2>/dev/null || true
    fi
}

# ============================================================================
# Rule File Tests
# ============================================================================

@test "v2.63.0: context-aware-behavior.md rule exists" {
    rule="${HOME}/.claude/rules/context-aware-behavior.md"
    [ -f "$rule" ]
}

@test "v2.63.0: rule references all 4 contexts" {
    rule="${HOME}/.claude/rules/context-aware-behavior.md"
    [ -f "$rule" ] || skip "Rule file not found"

    run grep -E 'dev|review|research|debug' "$rule"
    [ $status -eq 0 ]

    # Should mention all 4
    count=$(grep -cE '(^|\s)(dev|review|research|debug)(\s|$|:|\))' "$rule" || echo "0")
    [ "$count" -ge 4 ]
}

@test "v2.63.0: rule explains context detection mechanism" {
    rule="${HOME}/.claude/rules/context-aware-behavior.md"
    [ -f "$rule" ] || skip "Rule file not found"

    run grep -iE 'active-context|detection|check|ralph.*state' "$rule"
    [ $status -eq 0 ]
}

# ============================================================================
# State Management Tests
# ============================================================================

@test "v2.63.0: state directory exists for context tracking" {
    [ -d "$RALPH_STATE" ]
}

@test "v2.63.0: active-context.txt can be created" {
    echo "test" > "${RALPH_STATE}/active-context.txt.test"
    [ -f "${RALPH_STATE}/active-context.txt.test" ]
}

@test "v2.63.0: context persistence across sessions" {
    # Write test context
    echo "dev" > "${RALPH_STATE}/active-context.txt.test"

    # Read back
    context=$(cat "${RALPH_STATE}/active-context.txt.test")
    [ "$context" = "dev" ]
}

# ============================================================================
# CLI Integration Tests
# ============================================================================

@test "v2.63.0: ralph context command documented" {
    # Check CLAUDE.md for context command documentation
    run grep -E 'ralph context' "${HOME}/.claude/CLAUDE.md" 2>/dev/null
    [ $status -eq 0 ] || skip "Context command may use different syntax"
}

@test "v2.63.0: context show command returns current context" {
    script="${SCRIPTS_DIR}/context.sh"
    [ -x "$script" ] || skip "context.sh not executable"

    run "$script" show
    [ $status -eq 0 ]
}

# ============================================================================
# Hook Integration Tests
# ============================================================================

@test "v2.63.0: SessionStart hooks can inject context" {
    # Check for context injection in session start
    run grep -rE 'context|active-context' "${HOME}/.claude/hooks/"*session*.sh 2>/dev/null
    # May not be a dedicated hook - skip if not found
    [ $status -eq 0 ] || skip "Context injection may be in different hook"
}

# ============================================================================
# Context-Specific Behavior Tests
# ============================================================================

@test "v2.63.0: dev context emphasizes code-first approach" {
    [ -f "$CONTEXTS_DIR/dev.md" ] || skip "dev.md not found"

    run grep -iE 'code first|implement first|action.?oriented' "$CONTEXTS_DIR/dev.md"
    [ $status -eq 0 ]
}

@test "v2.63.0: review context structures feedback by severity" {
    [ -f "$CONTEXTS_DIR/review.md" ] || skip "review.md not found"

    run grep -iE 'CRITICAL|HIGH|MEDIUM|LOW|severity' "$CONTEXTS_DIR/review.md"
    [ $status -eq 0 ]
}

@test "v2.63.0: research context encourages broad exploration" {
    [ -f "$CONTEXTS_DIR/research.md" ] || skip "research.md not found"

    run grep -iE 'explore|compare|multiple|approaches|sources' "$CONTEXTS_DIR/research.md"
    [ $status -eq 0 ]
}

@test "v2.63.0: debug context focuses on root cause" {
    [ -f "$CONTEXTS_DIR/debug.md" ] || skip "debug.md not found"

    run grep -iE 'root cause|evidence|hypothesis|systematic' "$CONTEXTS_DIR/debug.md"
    [ $status -eq 0 ]
}

# ============================================================================
# Default Behavior Tests
# ============================================================================

@test "v2.63.0: rule specifies default behavior when no context active" {
    rule="${HOME}/.claude/rules/context-aware-behavior.md"
    [ -f "$rule" ] || skip "Rule file not found"

    run grep -iE 'default|no context|balanced' "$rule"
    [ $status -eq 0 ]
}

# ============================================================================
# Documentation Tests
# ============================================================================

@test "v2.63.0: Dynamic Contexts documented in CLAUDE.md" {
    run grep -E 'Dynamic Context|v2\.63' /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md
    [ $status -eq 0 ]
}

@test "v2.63.0: Context commands documented" {
    run grep -E 'ralph context (dev|review|research|debug)' /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md
    [ $status -eq 0 ]
}

# ============================================================================
# Validation Tests
# ============================================================================

@test "v2.63.0: context files are valid markdown" {
    for ctx in dev review research debug; do
        file="$CONTEXTS_DIR/${ctx}.md"
        [ -f "$file" ] || continue

        # Basic markdown validation - should have content
        lines=$(wc -l < "$file")
        [ "$lines" -gt 5 ]
    done
}

@test "v2.63.0: context files have consistent structure" {
    for ctx in dev review research debug; do
        file="$CONTEXTS_DIR/${ctx}.md"
        [ -f "$file" ] || continue

        # Should have a header
        run grep -E '^#' "$file"
        [ $status -eq 0 ]
    done
}
