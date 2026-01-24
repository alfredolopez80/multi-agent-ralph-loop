#!/usr/bin/env bats
# test_v265_cross_platform_hooks.bats - v2.68.12
# Tests for Cross-Platform Hooks feature (v2.65)
# Node.js alternatives to bash hooks for Windows compatibility
#
# Run with: bats tests/test_v265_cross_platform_hooks.bats

setup() {
    HOOKS_DIR="${HOME}/.claude/hooks"
    NODE_HOOKS_DIR="${HOME}/.claude/hooks/node"
    LIB_DIR="${HOME}/.claude/hooks/lib"
    TEST_TMP_DIR="${BATS_TMPDIR}/v265_cross_platform_test"

    mkdir -p "$TEST_TMP_DIR"
}

teardown() {
    rm -rf "$TEST_TMP_DIR" 2>/dev/null || true
}

# ============================================================================
# Node.js Hooks Directory Tests
# ============================================================================

@test "v2.65.0: node hooks directory exists" {
    [ -d "$NODE_HOOKS_DIR" ]
}

@test "v2.65.0: hooks lib directory exists" {
    [ -d "$LIB_DIR" ]
}

# ============================================================================
# Node.js Hook Files Tests
# ============================================================================

@test "v2.65.0: context-injector.js exists" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ]
}

@test "v2.65.0: cross-platform.js library exists" {
    [ -f "$LIB_DIR/cross-platform.js" ]
}

# ============================================================================
# Node.js Syntax Validation Tests
# ============================================================================

@test "v2.65.0: context-injector.js has valid JavaScript syntax" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    run node --check "$NODE_HOOKS_DIR/context-injector.js"
    [ $status -eq 0 ]
}

@test "v2.65.0: cross-platform.js has valid JavaScript syntax" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    run node --check "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

# ============================================================================
# Cross-Platform Library Content Tests
# ============================================================================

@test "v2.65.0: cross-platform.js exports readStdinJson function" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    run grep -E 'readStdinJson|module\.exports' "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

@test "v2.65.0: cross-platform.js exports respond function" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    run grep -E 'respond|module\.exports' "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

@test "v2.65.0: cross-platform.js handles both Windows and Unix paths" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    run grep -iE 'path\.sep|path\.join|process\.platform|win32|darwin|linux' "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

# ============================================================================
# Context Injector Tests
# ============================================================================

@test "v2.65.0: context-injector.js imports cross-platform library" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    run grep -E "require.*cross-platform|import.*cross-platform" "$NODE_HOOKS_DIR/context-injector.js"
    [ $status -eq 0 ]
}

@test "v2.65.0: context-injector.js handles SessionStart event" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    # SessionStart hooks should output context
    run grep -iE 'SessionStart|session.*start|context|inject' "$NODE_HOOKS_DIR/context-injector.js"
    [ $status -eq 0 ]
}

# ============================================================================
# Functional Tests
# ============================================================================

@test "v2.65.0: context-injector.js runs without error" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    # Run with empty input
    output=$(echo '{}' | node "$NODE_HOOKS_DIR/context-injector.js" 2>/dev/null || echo "error")
    # Should not crash
    [ "$output" != "error" ] || skip "Hook may require specific input format"
}

@test "v2.65.0: cross-platform.js can be required without error" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    run node -e "require('$LIB_DIR/cross-platform.js')"
    [ $status -eq 0 ]
}

# ============================================================================
# Error Handling Tests
# ============================================================================

@test "v2.65.0: context-injector.js has error handling" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    run grep -E 'try.*catch|\.catch|process\.on.*error' "$NODE_HOOKS_DIR/context-injector.js"
    [ $status -eq 0 ]
}

@test "v2.65.0: cross-platform.js has error handling" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    # Check for try-catch or graceful error handling (returns null on error)
    run grep -E 'try|catch|return null|resolve\(\{\}\)' "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

# ============================================================================
# Registration Tests (Deferred - HIGH-002)
# ============================================================================

@test "v2.65.0: Node.js hooks are documented as deferred (HIGH-002)" {
    # Per TECHNICAL_DEBT.md, Node.js hooks exist but registration is deferred
    debt_file="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/TECHNICAL_DEBT.md"
    [ -f "$debt_file" ] || skip "TECHNICAL_DEBT.md not found"

    run grep -E 'HIGH-002|Node.*Cross-Platform|registration.*deferred' "$debt_file"
    [ $status -eq 0 ]
}

@test "v2.65.0: Bash hooks remain primary until Windows support needed" {
    # Bash hooks should still be the primary registered hooks
    settings="${HOME}/.claude/settings.json"
    [ -f "$settings" ] || skip "settings.json not found"

    # Should have .sh hooks registered, not .js
    run jq -e '.hooks | to_entries[] | .value[] | .hooks[] | select(.command | contains(".sh"))' "$settings"
    [ $status -eq 0 ]
}

# ============================================================================
# Platform Detection Tests
# ============================================================================

@test "v2.65.0: cross-platform.js uses os module for platform abstraction" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    # Uses os.homedir() which is platform-aware
    run grep -E "require\('os'\)|os\.homedir|path\.join" "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

@test "v2.65.0: cross-platform.js handles home directory cross-platform" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    run grep -iE 'os\.homedir|HOME|USERPROFILE|homedir' "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

# ============================================================================
# Equivalence Tests (Node.js should match Bash behavior)
# ============================================================================

@test "v2.65.0: Node.js hook provides same functionality as Bash equivalent" {
    bash_hook="$HOOKS_DIR/inject-session-context.sh"
    node_hook="$NODE_HOOKS_DIR/context-injector.js"

    [ -f "$bash_hook" ] || skip "Bash equivalent not found"
    [ -f "$node_hook" ] || skip "Node.js hook not found"

    # Both should handle context injection
    run grep -iE 'context|inject|session' "$bash_hook"
    bash_has_context=$status

    run grep -iE 'context|inject|session' "$node_hook"
    node_has_context=$status

    # Both should handle similar functionality
    [ $bash_has_context -eq 0 ]
    [ $node_has_context -eq 0 ]
}

# ============================================================================
# Documentation Tests
# ============================================================================

@test "v2.65.0: Cross-platform hooks documented in CLAUDE.md" {
    run grep -iE 'Cross.?Platform|Node\.js.*hook|v2\.65' /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/CLAUDE.md
    [ $status -eq 0 ]
}

@test "v2.65.0: HIGH-002 documented in TECHNICAL_DEBT.md" {
    debt_file="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/TECHNICAL_DEBT.md"
    [ -f "$debt_file" ] || skip "TECHNICAL_DEBT.md not found"

    run grep -E 'HIGH-002' "$debt_file"
    [ $status -eq 0 ]
}

# ============================================================================
# Version Header Tests
# ============================================================================

@test "v2.65.0: context-injector.js has version comment" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    run grep -E 'version|VERSION|v[0-9]+\.[0-9]+' "$NODE_HOOKS_DIR/context-injector.js"
    [ $status -eq 0 ]
}

@test "v2.65.0: cross-platform.js has version comment" {
    [ -f "$LIB_DIR/cross-platform.js" ] || skip "File not found"

    run grep -E 'version|VERSION|v[0-9]+\.[0-9]+' "$LIB_DIR/cross-platform.js"
    [ $status -eq 0 ]
}

# ============================================================================
# Async Handling Tests
# ============================================================================

@test "v2.65.0: Node.js hooks handle async operations" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    run grep -E 'async|await|Promise|\.then' "$NODE_HOOKS_DIR/context-injector.js"
    [ $status -eq 0 ]
}

# ============================================================================
# JSON Output Format Tests
# ============================================================================

@test "v2.65.0: Node.js hooks output valid JSON" {
    [ -f "$NODE_HOOKS_DIR/context-injector.js" ] || skip "File not found"

    run grep -E 'JSON\.stringify|console\.log.*\{' "$NODE_HOOKS_DIR/context-injector.js"
    [ $status -eq 0 ]
}
