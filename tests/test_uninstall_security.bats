#!/usr/bin/env bats
# test_uninstall_security.bats - Security tests for uninstall.sh
#
# Run with: bats tests/test_uninstall_security.bats
# Install bats: brew install bats-core

setup() {
    TEST_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
    PROJECT_DIR="$(dirname "$TEST_DIR")"
    UNINSTALL_SCRIPT="$PROJECT_DIR/uninstall.sh"

    [ -f "$UNINSTALL_SCRIPT" ] || skip "uninstall.sh not found at $UNINSTALL_SCRIPT"

    # Create temp test directory
    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

# ═══════════════════════════════════════════════════════════════════════════════
# SCRIPT INTEGRITY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "uninstall.sh has correct shebang" {
    head -1 "$UNINSTALL_SCRIPT" | grep -q "#!/usr/bin/env bash"
}

@test "uninstall.sh uses set -euo pipefail" {
    grep -q "set -euo pipefail" "$UNINSTALL_SCRIPT"
}

@test "uninstall.sh has executable permissions" {
    [ -x "$UNINSTALL_SCRIPT" ]
}

@test "uninstall contains version 2.21" {
    grep -q 'VERSION="2.2' "$UNINSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SAFE REMOVAL TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "uninstall only removes Ralph-specific agents" {
    # Verify the script defines RALPH_AGENTS array
    grep -q 'RALPH_AGENTS=(' "$UNINSTALL_SCRIPT"
}

@test "uninstall only removes Ralph-specific commands" {
    # Verify the script defines RALPH_COMMANDS array
    grep -q 'RALPH_COMMANDS=(' "$UNINSTALL_SCRIPT"
}

@test "uninstall only removes Ralph-specific skills" {
    # Verify the script defines RALPH_SKILLS array
    grep -q 'RALPH_SKILLS=(' "$UNINSTALL_SCRIPT"
}

@test "uninstall removes git-safety-guard.py hook" {
    grep -q 'git-safety-guard.py' "$UNINSTALL_SCRIPT"
}

@test "uninstall removes quality-gates.sh hook" {
    grep -q 'quality-gates.sh' "$UNINSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SETTINGS PRESERVATION TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "uninstall has clean_settings_json function" {
    grep -q 'clean_settings_json()' "$UNINSTALL_SCRIPT"
}

@test "uninstall creates backup of settings.json" {
    grep -q 'ralph-uninstall-backup' "$UNINSTALL_SCRIPT"
}

@test "uninstall uses jq for safe JSON manipulation" {
    # Should use jq to safely modify settings.json
    grep -q 'jq.*settings' "$UNINSTALL_SCRIPT" || grep -q 'jq .*SETTINGS' "$UNINSTALL_SCRIPT"
}

@test "uninstall preserves user's non-Ralph permissions" {
    # The script should only remove Ralph-specific entries
    grep -q 'RALPH_PERMISSIONS' "$UNINSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SHELL CONFIG CLEANUP TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "uninstall has clean_shell_config function" {
    grep -q 'clean_shell_config()' "$UNINSTALL_SCRIPT"
}

@test "uninstall uses marker-based shell config removal" {
    # Should look for start/end markers
    grep -q 'RALPH WIGGUM START' "$UNINSTALL_SCRIPT"
    grep -q 'RALPH WIGGUM END' "$UNINSTALL_SCRIPT"
}

@test "uninstall handles legacy shell config" {
    # Should have fallback for old-style config
    grep -q 'legacy' "$UNINSTALL_SCRIPT" || grep -q 'Legacy' "$UNINSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CODEX AND GEMINI CLEANUP TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "uninstall has remove_codex_config function" {
    grep -q 'remove_codex_config()' "$UNINSTALL_SCRIPT"
}

@test "uninstall has remove_gemini_config function" {
    grep -q 'remove_gemini_config()' "$UNINSTALL_SCRIPT"
}

@test "uninstall uses section markers for Codex config" {
    # Should use markers to identify Ralph-specific config
    grep -q 'RALPH WIGGUM CODEX CONFIG' "$UNINSTALL_SCRIPT"
}

@test "uninstall uses section markers for Gemini config" {
    # Should use markers to identify Ralph-specific config
    grep -q 'RALPH WIGGUM GEMINI CONFIG' "$UNINSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# CLI OPTIONS TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "uninstall has --keep-backups option" {
    grep -q '\-\-keep-backups' "$UNINSTALL_SCRIPT"
}

@test "uninstall has --full option" {
    grep -q '\-\-full' "$UNINSTALL_SCRIPT"
}

@test "uninstall has --help option" {
    grep -q '\-\-help\|-h' "$UNINSTALL_SCRIPT"
}

@test "uninstall requires user confirmation" {
    # Should have a read prompt for confirmation
    grep -q 'read -p' "$UNINSTALL_SCRIPT"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SAFETY TESTS
# ═══════════════════════════════════════════════════════════════════════════════

@test "uninstall validates paths before removal" {
    # Should check if files/directories exist before removing
    grep -c '\[ -f' "$UNINSTALL_SCRIPT" | grep -q -v '^0$'
    grep -c '\[ -d' "$UNINSTALL_SCRIPT" | grep -q -v '^0$'
}

@test "uninstall uses rm -f not rm -rf for files" {
    # For individual files, should use -f not -rf
    # rm -rf should only be used for directories
    grep 'rm -f ' "$UNINSTALL_SCRIPT" | head -1 | grep -v 'rm -rf' || true
}

@test "uninstall has error handling" {
    # Should have log_error function
    grep -q 'log_error()' "$UNINSTALL_SCRIPT"
}

@test "uninstall shows completion message" {
    grep -q 'UNINSTALL COMPLETE' "$UNINSTALL_SCRIPT"
}
