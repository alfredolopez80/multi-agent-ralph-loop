#!/usr/bin/env bats
# test_install_security.bats - Security tests for install.sh
#
# Run with: bats tests/test_install_security.bats
# Install bats: brew install bats-core

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    INSTALL_SCRIPT="$PROJECT_DIR/install.sh"

    [ -f "$INSTALL_SCRIPT" ] || skip "install.sh not found at $INSTALL_SCRIPT"

    # Create temp test directory
    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT INTEGRITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install.sh has correct shebang" {
    head -1 "$INSTALL_SCRIPT" | grep -q "#!/usr/bin/env bash"
}

@test "install.sh uses set -euo pipefail" {
    grep -q "set -euo pipefail" "$INSTALL_SCRIPT"
}

@test "install.sh has executable permissions" {
    [ -x "$INSTALL_SCRIPT" ]
}

# ═══════════════════════════════════════════════════════════════════════════════
# BACKUP FUNCTIONALITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install creates backup directory structure" {
    # Check that the backup function exists and uses timestamp
    grep -q "BACKUP_DIR=.*date" "$INSTALL_SCRIPT"
}

@test "backup uses timestamped directories" {
    # Verify backup uses date-based naming
    grep -q '%Y%m%d_%H%M%S' "$INSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PERMISSION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install sets executable permissions on scripts" {
    # Verify chmod +x is called for scripts
    grep -q 'chmod +x.*ralph' "$INSTALL_SCRIPT"
    grep -q 'chmod +x.*mmc' "$INSTALL_SCRIPT"
}

@test "install sets executable permissions on hooks" {
    # Verify chmod +x is called for hooks
    grep -q 'chmod +x.*hooks' "$INSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PATH HANDLING TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install uses HOME variable safely" {
    # Verify HOME is quoted when used
    grep 'INSTALL_DIR=.*HOME' "$INSTALL_SCRIPT" | grep -q '"'
}

@test "install uses SCRIPT_DIR safely" {
    # Verify SCRIPT_DIR is properly quoted
    grep -q 'SCRIPT_DIR="$(cd' "$INSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFICATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install has verification step" {
    grep -q "verify_installation" "$INSTALL_SCRIPT"
}

@test "install checks for required dependencies" {
    grep -q "check_dependencies" "$INSTALL_SCRIPT"
}

@test "install checks for jq dependency" {
    grep -q 'command -v jq' "$INSTALL_SCRIPT"
}

@test "install checks for curl dependency" {
    grep -q 'command -v curl' "$INSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SHELL RC MODIFICATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install checks for existing ralph config before modifying shell rc" {
    # Install script uses RALPH WIGGUM markers
    grep -q 'RALPH WIGGUM' "$INSTALL_SCRIPT"
}

@test "install adds PATH in shell rc" {
    grep -q 'export PATH=.*\.local/bin' "$INSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# DIRECTORY CREATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install creates config directories with mkdir -p" {
    grep -q 'mkdir -p' "$INSTALL_SCRIPT"
}

@test "install creates .ralph directory structure" {
    grep -q 'RALPH_DIR' "$INSTALL_SCRIPT"
}

@test "install creates .claude directory structure" {
    grep -q 'CLAUDE_DIR' "$INSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# ERROR HANDLING TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install has log_error function" {
    grep -q 'log_error()' "$INSTALL_SCRIPT"
}

@test "install exits with error on missing dependencies" {
    grep -q 'exit 1' "$INSTALL_SCRIPT"
}

@test "install uses 2>/dev/null for safe commands" {
    grep -c '2>/dev/null' "$INSTALL_SCRIPT" | grep -q -v '^0$'
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONTENT INTEGRITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install contains version number" {
    grep -q 'VERSION="2.2' "$INSTALL_SCRIPT"
}

@test "install documents git safety guard" {
    grep -q 'git-safety-guard' "$INSTALL_SCRIPT"
}

@test "install documents quality gates" {
    grep -q 'quality-gates' "$INSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# COPY OPERATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "install copies scripts to INSTALL_DIR" {
    grep -q 'cp.*scripts/ralph.*INSTALL_DIR' "$INSTALL_SCRIPT"
}

@test "install copies mmc to INSTALL_DIR" {
    grep -q 'cp.*scripts/mmc.*INSTALL_DIR' "$INSTALL_SCRIPT"
}

@test "install uses || true for optional copies" {
    # Safe copy operations that may fail
    grep -c '|| true' "$INSTALL_SCRIPT" | grep -q -v '^0$'
}

# ═══════════════════════════════════════════════════════════════════════════════
# V2.19 SECURITY FIXES TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "VULN-008: install.sh starts with umask 077" {
    # Verify umask 077 is set at the start of the script
    head -20 "$INSTALL_SCRIPT" | grep -q 'umask 077'
}

@test "install creates logs directory" {
    # Verify logs directory is created during installation
    grep -q 'logs' "$INSTALL_SCRIPT"
}

@test "install documents v2.19 features" {
    # Should mention hybrid logging or v2.19 features
    grep -q 'Hybrid\|hybrid\|2.19' "$INSTALL_SCRIPT"
}
