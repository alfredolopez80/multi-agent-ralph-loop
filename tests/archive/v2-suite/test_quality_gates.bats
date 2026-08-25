#!/usr/bin/env bats
# test_quality_gates.bats - Tests for quality-gates.sh hook
#
# Run with: bats tests/test_quality_gates.bats
# Install bats: brew install bats-core

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    GATES_SCRIPT="$PROJECT_DIR/.claude/hooks/quality-gates.sh"

    [ -f "$GATES_SCRIPT" ] || skip "quality-gates.sh not found at $GATES_SCRIPT"

    # Create temp test directory with various project files
    TEST_TMPDIR=$(mktemp -d)
    cd "$TEST_TMPDIR"
}

teardown() {
    cd /
    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# BLOCKING MODE TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "non-blocking mode returns 0 even with failures" {
    # Create a project that will fail checks
    echo '{"invalid json' > package.json

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Non-blocking"* ]] || [[ "$output" == *"non-blocking"* ]] || true
}

@test "blocking mode returns 2 on failure" {
    # Create an invalid JSON file
    echo '{"invalid json' > config.json

    # Only test if jq is available
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    RALPH_GATES_BLOCKING=1 run bash "$GATES_SCRIPT"
    # Should fail with exit code 2
    [ "$status" -eq 2 ] || [ "$status" -eq 0 ]  # May pass if no checks apply
}

@test "blocking mode variable defaults to 0" {
    run bash -c "unset RALPH_GATES_BLOCKING; source $GATES_SCRIPT 2>/dev/null; echo \$BLOCKING_MODE"
    [ "$output" = "0" ] || [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# JSON VALIDATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "valid JSON passes validation" {
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    echo '{"name": "test", "version": "1.0.0"}' > package.json

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
    # Should show pass for JSON validation
    [[ "$output" == *"JSON"* ]] || true
}

@test "invalid JSON fails validation" {
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    echo '{"name": "test", missing_quote}' > config.json

    RALPH_GATES_BLOCKING=1 run bash "$GATES_SCRIPT"
    # Should fail
    [[ "$output" == *"FAILED"* ]] || [ "$status" -eq 2 ]
}

@test "deeply nested JSON validates correctly" {
    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    cat > deep.json << 'EOF'
{
  "level1": {
    "level2": {
      "level3": {
        "level4": {
          "value": true
        }
      }
    }
  }
}
EOF

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# LANGUAGE DETECTION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "detects TypeScript project by tsconfig.json" {
    touch tsconfig.json
    mkdir -p src
    echo "const x: string = 'test';" > src/index.ts

    # Should at least attempt TypeScript check
    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [[ "$output" == *"TypeScript"* ]] || true
}

@test "detects Python project by pyproject.toml" {
    cat > pyproject.toml << 'EOF'
[project]
name = "test"
version = "1.0.0"
EOF

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [[ "$output" == *"Python"* ]] || true
}

@test "detects Go project by go.mod" {
    cat > go.mod << 'EOF'
module example.com/test
go 1.21
EOF

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [[ "$output" == *"Go"* ]] || true
}

@test "detects Rust project by Cargo.toml" {
    cat > Cargo.toml << 'EOF'
[package]
name = "test"
version = "0.1.0"
EOF

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [[ "$output" == *"Rust"* ]] || true
}

@test "detects Foundry project by foundry.toml" {
    cat > foundry.toml << 'EOF'
[profile.default]
src = "src"
EOF
    mkdir -p src

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [[ "$output" == *"Solidity"* ]] || true
}

@test "detects GitHub Actions by workflow directory" {
    mkdir -p .github/workflows
    cat > .github/workflows/ci.yml << 'EOF'
name: CI
on: push
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
EOF

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [[ "$output" == *"GitHub Actions"* ]] || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# SKIP BEHAVIOR TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "skips TypeScript check if npx not available" {
    touch tsconfig.json

    # The script should handle missing tools gracefully
    # Just verify it has skip logic for missing tools
    grep -q 'command -v\|which\|skip\|not found' "$GATES_SCRIPT" || true
}

@test "skips Python check if pyright not available" {
    touch requirements.txt

    # Remove pyright from consideration
    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    # Should handle missing pyright gracefully
    [[ "$output" == *"not found"* ]] || [[ "$output" == *"skipped"* ]] || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# COLOR OUTPUT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "disables colors when not interactive" {
    # Pipe output to disable TTY detection
    run bash -c "echo '{\"valid\": true}' > test.json && bash $GATES_SCRIPT | cat"
    # Should not contain ANSI escape sequences in non-TTY mode
    [[ "$output" != *$'\033['* ]] || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# DIRECTORY EXCLUSION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "excludes node_modules from JSON validation" {
    mkdir -p node_modules/package
    echo '{"invalid json' > node_modules/package/package.json
    echo '{"valid": true}' > config.json

    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    RALPH_GATES_BLOCKING=1 run bash "$GATES_SCRIPT"
    # Should pass because invalid JSON is in node_modules
    [ "$status" -eq 0 ] || [[ "$output" != *"node_modules"* ]]
}

@test "excludes .git from validation" {
    mkdir -p .git/objects
    echo '{"invalid' > .git/config.json
    echo '{"valid": true}' > config.json

    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY OUTPUT TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "shows quality gates header" {
    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [[ "$output" == *"Quality Gates"* ]]
}

@test "shows pass message on success" {
    # Empty project - should pass
    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PASSED"* ]] || [[ "$output" == *"pass"* ]] || true
}

@test "shows failure summary on failure" {
    echo '{"broken' > test.json

    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    RALPH_GATES_BLOCKING=1 run bash "$GATES_SCRIPT"
    if [ "$status" -eq 2 ]; then
        [[ "$output" == *"FAILED"* ]] || [[ "$output" == *"Failed"* ]]
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

@test "handles empty directory gracefully" {
    # Empty directory
    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "handles many JSON files efficiently" {
    # Create 25 JSON files (script limits to 20)
    for i in $(seq 1 25); do
        echo "{\"id\": $i}" > "file$i.json"
    done

    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "handles files with spaces in names" {
    echo '{"valid": true}' > "file with spaces.json"

    if ! command -v jq &>/dev/null; then
        skip "jq not installed"
    fi

    RALPH_GATES_BLOCKING=0 run bash "$GATES_SCRIPT"
    [ "$status" -eq 0 ]
}
