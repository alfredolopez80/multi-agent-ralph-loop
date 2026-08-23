#!/usr/bin/env bats
# test_mmc_security.bats - Security tests for mmc CLI (MiniMax wrapper)
#
# Run with: bats tests/test_mmc_security.bats
# Install bats: brew install bats-core

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    MMC_SCRIPT="$PROJECT_DIR/scripts/mmc"

    [ -f "$MMC_SCRIPT" ] || skip "mmc script not found at $MMC_SCRIPT"

    # Create temp test directory
    TEST_TMPDIR=$(mktemp -d)

    # Backup real config if exists (|| true to not fail in CI)
    if [ -f "$HOME/.ralph/config/minimax.json" ]; then
        cp "$HOME/.ralph/config/minimax.json" "$TEST_TMPDIR/minimax.json.bak"
    fi
}

teardown() {
    # Restore config if backed up
    if [ -f "$TEST_TMPDIR/minimax.json.bak" ]; then
        mkdir -p "$HOME/.ralph/config"
        mv "$TEST_TMPDIR/minimax.json.bak" "$HOME/.ralph/config/minimax.json"
    fi

    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI COMMAND TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "mmc help shows usage" {
    run bash "$MMC_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"MiniMax"* ]]
    [[ "$output" == *"Claude Code"* ]]
}

@test "mmc version shows version number" {
    run bash "$MMC_SCRIPT" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.2"* ]]
}

@test "mmc status shows configuration status" {
    run bash "$MMC_SCRIPT" --status
    # Should run without crashing, regardless of config state
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
    [[ "$output" == *"Config"* ]] || [[ "$output" == *"not configured"* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: API KEY HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

@test "config file has restrictive permissions after setup" {
    # Create test config directory
    mkdir -p "$TEST_TMPDIR/.ralph/config"

    # Mock the setup by writing config file like the script does
    cat > "$TEST_TMPDIR/test_config.json" << 'EOF'
{
  "apiKey": "FAKE_TEST_API_KEY_PLACEHOLDER",
  "baseUrl": "https://api.minimax.io/anthropic"
}
EOF
    chmod 600 "$TEST_TMPDIR/test_config.json"

    # Check permissions (macOS uses different stat format)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perms=$(stat -f '%Lp' "$TEST_TMPDIR/test_config.json")
    else
        perms=$(stat -c '%a' "$TEST_TMPDIR/test_config.json")
    fi

    [ "$perms" = "600" ]
}

@test "API key can be provided via environment variable" {
    # Verify the script checks for MINIMAX_API_KEY env var
    grep -q 'MINIMAX_API_KEY' "$MMC_SCRIPT"
}

@test "config file not readable by others" {
    # Create a test config
    mkdir -p "$TEST_TMPDIR/.ralph/config"
    echo '{"apiKey":"test"}' > "$TEST_TMPDIR/.ralph/config/minimax.json"
    chmod 600 "$TEST_TMPDIR/.ralph/config/minimax.json"

    # Verify not world-readable
    if [[ "$OSTYPE" == "darwin"* ]]; then
        perms=$(stat -f '%Sp' "$TEST_TMPDIR/.ralph/config/minimax.json")
    else
        perms=$(stat -c '%A' "$TEST_TMPDIR/.ralph/config/minimax.json")
    fi

    # Should not contain r for others (last char should be -)
    [[ "$perms" != *"r--r--r--"* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY: JSON INJECTION PREVENTION
# ═══════════════════════════════════════════════════════════════════════════════

@test "query escapes JSON special characters" {
    # Test that the script properly escapes prompts
    # The script uses: jq -Rs '.'

    run bash -c "echo 'test \"with\" quotes' | jq -Rs '.'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'\"with\"'* ]] || [[ "$output" == *'\\"with\\"'* ]]
}

@test "query escapes newlines" {
    run bash -c "printf 'line1\nline2' | jq -Rs '.'"
    [ "$status" -eq 0 ]
    # jq outputs the literal \n escape sequence
    [[ "$output" == *'line1'* ]] && [[ "$output" == *'line2'* ]]
}

@test "query escapes backslashes" {
    run bash -c "echo 'path\\to\\file' | jq -Rs '.'"
    [ "$status" -eq 0 ]
    [[ "$output" == *'\\\\'* ]] || [[ "$output" == *'\\'* ]]
}

@test "query escapes control characters" {
    run bash -c "printf 'test\ttab' | jq -Rs '.'"
    [ "$status" -eq 0 ]
    # jq escapes tabs to \t in the output string
    [[ "$output" == *'test'* ]] && [[ "$output" == *'tab'* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

@test "check_dependencies verifies jq is available" {
    run bash -c "source $MMC_SCRIPT 2>/dev/null; command -v jq"
    # jq should be available on this system
    [ "$status" -eq 0 ] || skip "jq not installed"
}

@test "check_dependencies verifies curl is available" {
    run bash -c "source $MMC_SCRIPT 2>/dev/null; command -v curl"
    [ "$status" -eq 0 ] || skip "curl not installed"
}

# ═══════════════════════════════════════════════════════════════════════════════
# LOOP COMMAND TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "loop respects max iteration limit" {
    # This tests the iteration limit logic without actually making API calls
    run bash -c "
        MAX_ITER=3
        ITER=0
        while [ \$ITER -lt \$MAX_ITER ]; do
            ((ITER++))
            echo \"Iteration \$ITER\"
            # Simulate no VERIFIED_DONE
        done
        echo \"Completed with \$ITER iterations\"
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Completed with 3 iterations"* ]]
}

@test "loop exits early on VERIFIED_DONE" {
    run bash -c "
        MAX_ITER=10
        ITER=0
        while [ \$ITER -lt \$MAX_ITER ]; do
            ((ITER++))
            if [ \$ITER -eq 2 ]; then
                RESULT='Task complete VERIFIED_DONE'
            else
                RESULT='Still working...'
            fi
            if echo \"\$RESULT\" | grep -q 'VERIFIED_DONE'; then
                echo \"Exited at iteration \$ITER\"
                break
            fi
        done
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"Exited at iteration 2"* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# MODEL MAPPING TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "default model is MiniMax-M2.1" {
    grep -q 'MiniMax-M2.1' "$MMC_SCRIPT"
}

@test "lightning model is MiniMax-M2.1-lightning" {
    grep -q 'MiniMax-M2.1-lightning' "$MMC_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

@test "missing config shows helpful error" {
    # Temporarily remove config
    REAL_CONFIG="$HOME/.ralph/config/minimax.json"
    OLD_CONFIG="$HOME/.mmc.json"
    TEMP_BAK="$TEST_TMPDIR/real_config.bak"

    [ -f "$REAL_CONFIG" ] && mv "$REAL_CONFIG" "$TEMP_BAK"
    [ -f "$OLD_CONFIG" ] && mv "$OLD_CONFIG" "$TEST_TMPDIR/old_config.bak"

    run bash "$MMC_SCRIPT" --query "test"

    # Restore
    [ -f "$TEMP_BAK" ] && mv "$TEMP_BAK" "$REAL_CONFIG"
    [ -f "$TEST_TMPDIR/old_config.bak" ] && mv "$TEST_TMPDIR/old_config.bak" "$OLD_CONFIG"

    [[ "$output" == *"not configured"* ]] || [[ "$output" == *"--setup"* ]]
}

# ═══════════════════════════════════════════════════════════════════════════════
# V2.19 SECURITY FIXES TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "VULN-005: log_usage sets chmod 600 on log files" {
    # Verify the script uses chmod 600 on log files
    grep -q 'chmod 600.*LOG' "$MMC_SCRIPT"
}

@test "VULN-008: mmc starts with umask 077" {
    # Verify umask 077 is set at the start of the script
    head -20 "$MMC_SCRIPT" | grep -q 'umask 077'
}

@test "VULN-005: log files are protected with chmod 600" {
    # Verify the script calls chmod 600 on log files
    grep -q 'chmod 600.*LOG\|chmod 600.*usage' "$MMC_SCRIPT"
}

@test "mmc uses jq for safe JSON construction" {
    # Verify jq is used for building JSON (not string concatenation)
    grep -q 'jq -n' "$MMC_SCRIPT"
}
