#!/usr/bin/env bats
# test_cross_platform.bats - Cross-platform shell compatibility tests (v2.27.1)

setup() {
    RALPH_SCRIPT="$BATS_TEST_DIRNAME/../scripts/ralph"
    if [[ "$OSTYPE" == darwin* ]]; then
        IS_MACOS=true
    else
        IS_MACOS=false
    fi

    [ -f "$RALPH_SCRIPT" ] || skip "ralph script not found at $RALPH_SCRIPT"
    TEST_TMPDIR=$(mktemp -d)
}

teardown() {
    [ -n "$TEST_TMPDIR" ] && rm -rf "$TEST_TMPDIR" 2>/dev/null || true
}

get_file_size() {
    local file="$1"
    stat -f%z "$file" 2>/dev/null || stat --printf=%s "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null
}

# ============================================================================
# realpath compatibility
# ============================================================================

@test "realpath alternative works" {
    run bash -c "set --; source \"$RALPH_SCRIPT\" >/dev/null; validate_path \"$TEST_TMPDIR\""
    [ "$status" -eq 0 ]
    expected=$(realpath "$TEST_TMPDIR" 2>/dev/null || (cd "$TEST_TMPDIR" && pwd))
    [ "$output" = "$expected" ]
}

@test "validate_path resolves existing directory" {
    subdir="$TEST_TMPDIR/subdir"
    mkdir -p "$subdir"
    run bash -c "set --; source \"$RALPH_SCRIPT\" >/dev/null; validate_path \"$subdir\""
    [ "$status" -eq 0 ]
    expected=$(realpath "$subdir" 2>/dev/null || (cd "$subdir" && pwd))
    [ "$output" = "$expected" ]
}

@test "validate_path returns input when check is skip" {
    path="$TEST_TMPDIR/does-not-exist"
    run bash -c "set --; source \"$RALPH_SCRIPT\" >/dev/null; validate_path \"$path\" skip"
    [ "$status" -eq 0 ]
    [ "$output" = "$path" ]
}

@test "validate_path uses realpath fallback pattern" {
    run grep -q 'realpath "$path" 2>/dev/null || (cd "$path" 2>/dev/null && pwd)' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================================
# stat file size
# ============================================================================

@test "get_file_size works on this platform" {
    file="$TEST_TMPDIR/size.txt"
    printf 'abcd' >"$file"
    size=$(get_file_size "$file")
    [ "$size" = "4" ]
}

@test "stat fallback returns numeric size" {
    file="$TEST_TMPDIR/size2.txt"
    printf '1234567' >"$file"
    run bash -c 'stat -f%z "$1" 2>/dev/null || stat --printf=%s "$1" 2>/dev/null || stat -c%s "$1" 2>/dev/null' _ "$file"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "script uses portable stat size fallback" {
    run grep -q 'stat -f%z .*|| stat -c%s' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================================
# date formatting
# ============================================================================

@test "date formatting is portable" {
    run date -u +"%Y-%m-%dT%H:%M:%SZ"
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "date UTC format ends with Z" {
    run date -u +"%Y-%m-%dT%H:%M:%SZ"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Z" ]]
}

@test "date +%s returns epoch seconds" {
    run date +%s
    [ "$status" -eq 0 ]
    [[ "$output" =~ ^[0-9]+$ ]]
}

@test "script uses UTC timestamp format" {
    run grep -q 'date -u +"%Y-%m-%dT%H:%M:%SZ"' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================================
# arithmetic expressions
# ============================================================================

@test "increment expression works with set -e" {
    run bash -e -c 'VAR=0; VAR=$((VAR + 1)); echo "$VAR"'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "post-increment fails with set -e when zero" {
    run bash -e -c 'VAR=0; ((VAR++)); echo "$VAR"'
    [ "$status" -ne 0 ]
}

@test "script uses safe increment pattern" {
    run grep -Fq 'ITER=$((ITER + 1))' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================================
# command substitution
# ============================================================================

@test "command substitution is safe" {
    run bash -c "set --; source \"$RALPH_SCRIPT\" >/dev/null; CMD_SUB=\"\$(printf \"%s\" \"\\\$(whoami)\")\"; validate_path \"\$CMD_SUB\""
    [ "$status" -ne 0 ]
}

@test "backticks are blocked" {
    run bash -c "set --; source \"$RALPH_SCRIPT\" >/dev/null; CMD_SUB=\"\$(printf \"%b\" \"\\x60whoami\\x60\")\"; validate_path \"\$CMD_SUB\""
    [ "$status" -ne 0 ]
}

@test "validate_path checks for command substitution patterns" {
    run grep -q 'BLOCKED_CMD_SUBSTITUTION' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "command substitution works in normal usage" {
    run bash -e -c 'OUT=$(printf "ok"); echo "$OUT"'
    [ "$status" -eq 0 ]
    [ "$output" = "ok" ]
}

# ============================================================================
# grep -c edge cases
# ============================================================================

@test "grep count handles empty input" {
    run bash -euo pipefail -c 'CONTENT=""; COUNT=$(echo "$CONTENT" | grep -ci "critical" 2>/dev/null | tr -cd "0-9" || true); COUNT=${COUNT:-0}; echo "$COUNT"'
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "grep count handles no matches in text" {
    run bash -euo pipefail -c 'CONTENT="none"; COUNT=$(echo "$CONTENT" | grep -ci "critical" 2>/dev/null | tr -cd "0-9" || true); COUNT=${COUNT:-0}; echo "$COUNT"'
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "grep count handles multiple matches" {
    run bash -euo pipefail -c 'CONTENT=$(printf "%b" "critical\ncritical"); COUNT=$(printf "%s" "$CONTENT" | grep -ci "critical" 2>/dev/null | tr -cd "0-9" || true); COUNT=${COUNT:-0}; echo "$COUNT"'
    [ "$status" -eq 0 ]
    [ "$output" = "2" ]
}

@test "grep count sanitizes non-numeric output" {
    run bash -euo pipefail -c 'CONTENT="critical"; COUNT=$(echo "$CONTENT" | grep -ci "critical" 2>/dev/null | tr -cd "0-9"); echo "${COUNT}x" | tr -cd "0-9"'
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "script defaults empty grep counts to zero" {
    run grep -q 'CRITICAL=\${CRITICAL:-0}' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script sanitizes grep counts with tr" {
    run grep -q 'grep -ci .* | tr -cd' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

# ============================================================================
# temp directory creation
# ============================================================================

@test "mktemp creates temp directory" {
    tmpdir=$(mktemp -d)
    [ -d "$tmpdir" ]
    rm -rf "$tmpdir"
}

@test "mktemp template uses ralph prefix" {
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/ralph.XXXXXXXXXX")
    [ -d "$tmpdir" ]
    basename=$(basename "$tmpdir")
    [[ "$basename" == ralph.* ]]
    rm -rf "$tmpdir"
}

@test "mktemp directory permissions are 700" {
    tmpdir=$(mktemp -d)
    chmod 700 "$tmpdir"
    perms=$(stat -f%Lp "$tmpdir" 2>/dev/null || stat -c%a "$tmpdir" 2>/dev/null)
    [ "$perms" = "700" ]
    rm -rf "$tmpdir"
}

@test "script uses mktemp template for tmpdir" {
    run grep -q 'mktemp -d "\${SYSTEM_TMPDIR}/ralph\.XXXXXXXXXX"' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script enforces tmpdir permissions" {
    run grep -q 'chmod 700 "\$RALPH_TMPDIR"' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}

@test "script verifies tmpdir permissions with stat fallback" {
    run grep -q 'PERMS=$(stat -f%Lp "\$RALPH_TMPDIR" 2>/dev/null || stat -c%a "\$RALPH_TMPDIR" 2>/dev/null)' "$RALPH_SCRIPT"
    [ "$status" -eq 0 ]
}
