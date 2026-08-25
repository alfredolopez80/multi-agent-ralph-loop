#!/usr/bin/env bash
# skill-lint-test.sh - Test suite for scripts/skill-lint.py
#
# 3-assertion rule (per repo convention):
#   1. Pasa sobre una fixture limpia con scanned >= 2.
#   2. FALLA sobre una violación fresca: SKILL.md sin frontmatter o hook que
#      referencia una skill inexistente.
#   3. Escape hatch: silencia un caso anotado; sin razon escrita -> sigue
#      fallando.
#   4. Alcance cero: fixture sin skills -> exit !=0 con "zero skills scanned".
#
# All test cases use a tmpdir so they are hermetic and parallelizable.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LINT="${PROJECT_ROOT}/scripts/skill-lint.py"

# Counters (assignment not post-increment under set -e: see
# testing-zero-tests-is-never-success).
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
DIM='\033[2m'
RESET='\033[0m'

log_test() { echo -e "${CYAN}[TEST]${RESET} $1"; }
log_pass() {
    TESTS_PASSED=$((TESTS_PASSED+1))
    TESTS_TOTAL=$((TESTS_TOTAL+1))
    echo -e "  ${GREEN}\xe2\x9c\x93 PASS${RESET} $1"
}
log_fail() {
    TESTS_FAILED=$((TESTS_FAILED+1))
    TESTS_TOTAL=$((TESTS_TOTAL+1))
    echo -e "  ${RED}\xe2\x9c\x97 FAIL${RESET} $1"
    if [[ -n "$2" ]]; then
        echo -e "         ${DIM}Expected: $2${RESET}"
        echo -e "         ${DIM}Got: $3${RESET}"
    fi
}

# Build a clean fixture: 2 valid skills + 1 hook that does NOT reference
# any non-existent skill. The fixture is rebuilt for each test that needs
# it, so tests are independent.
build_clean_fixture() {
    local fixture_root="$1"
    rm -rf "$fixture_root"
    mkdir -p "$fixture_root/skills/fixture-skill-a"
    mkdir -p "$fixture_root/skills/fixture-skill-b"
    mkdir -p "$fixture_root/hooks"
    cat > "$fixture_root/skills/fixture-skill-a/SKILL.md" <<'EOF'
---
name: fixture-skill-a
version: 1.0.0
description: "Test skill A. Used by skill-lint fixture to verify the lint accepts valid frontmatter."
user-invocable: true
---

# Fixture Skill A

This is a fixture used by skill-lint-test.sh.
EOF
    cat > "$fixture_root/skills/fixture-skill-b/SKILL.md" <<'EOF'
---
name: fixture-skill-b
version: 1.0.0
description: "Test skill B. Used by skill-lint fixture to verify cross-skill references work."
user-invocable: true
---

# Fixture Skill B

This is a fixture used by skill-lint-test.sh.
EOF
    cat > "$fixture_root/hooks/fixture-clean-hook.sh" <<'EOF'
#!/usr/bin/env bash
# A clean hook that does not reference any skill.
echo '{"continue": true}'
exit 0
EOF
    chmod +x "$fixture_root/hooks/fixture-clean-hook.sh"
    echo "$fixture_root"
}

# =============================================================================
# Test 1: Pasa sobre una fixture limpia
# =============================================================================
test_clean_fixture_passes() {
    log_test "Clean fixture (2 valid skills, clean hook) -> lint passes"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-clean-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    build_clean_fixture "$fixture" >/dev/null

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -eq 0 ]]; then
        log_pass "clean fixture passed (exit 0)"
    else
        log_fail "clean fixture should pass" "exit 0" "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}

# =============================================================================
# Test 2: FALLA cuando un SKILL.md no tiene frontmatter
# =============================================================================
test_no_frontmatter_fails() {
    log_test "SKILL.md without frontmatter -> lint fails with specific message"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-nofm-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    build_clean_fixture "$fixture" >/dev/null
    # Inject: a SKILL.md with no frontmatter
    mkdir -p "$fixture/skills/broken-no-fm"
    cat > "$fixture/skills/broken-no-fm/SKILL.md" <<'EOF'
# No frontmatter here

This file has no frontmatter at all. The lint should catch it.
EOF

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -ne 0 ]] && grep -q "frontmatter" "$fixture/out"; then
        log_pass "missing frontmatter detected (exit !=0, message names check)"
    else
        log_fail "missing frontmatter should fail" "exit !=0 + 'frontmatter' in output" \
            "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}

# =============================================================================
# Test 3: FALLA cuando un hook referencia una skill inexistente
# =============================================================================
test_hook_orphan_ref_fails() {
    log_test "Hook referencing non-existent skill -> lint fails with specific message"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-orphan-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    build_clean_fixture "$fixture" >/dev/null
    # Inject: a hook that references a skill that doesn't exist.
    # Use the exact pattern the lint catches: "/<name> for <text>"
    # (mirrors smart-skill-reminder's hardcoded emissions).
    cat > "$fixture/hooks/fixture-orphan-hook.sh" <<'EOF'
#!/usr/bin/env bash
# This hook references a skill that does not exist in the corpus.
echo "/nonexistent-skill for the test"
exit 0
EOF
    chmod +x "$fixture/hooks/fixture-orphan-hook.sh"

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -ne 0 ]] && grep -q "nonexistent-skill" "$fixture/out"; then
        log_pass "orphan ref detected (exit !=0, names the missing skill)"
    else
        log_fail "orphan ref should fail" "exit !=0 + 'nonexistent-skill' in output" \
            "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}

# =============================================================================
# Test 4: Escape hatch silencia con razon escrita
# =============================================================================
test_ignore_with_reason_silences() {
    log_test "Ignore entry with reason -> lint passes that file"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-ignore-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    build_clean_fixture "$fixture" >/dev/null
    # Inject: a SKILL.md with no frontmatter
    mkdir -p "$fixture/skills/broken-no-fm"
    cat > "$fixture/skills/broken-no-fm/SKILL.md" <<'EOF'
# No frontmatter here
EOF
    # Add the broken file to the ignore with a reason
    cat > "$fixture/skills/.skill-lint-ignore" <<'EOF'
broken-no-fm/SKILL.md|fixture: intentionally no frontmatter for the test
EOF

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -eq 0 ]]; then
        log_pass "ignore with reason silenced the violation"
    else
        log_fail "ignore with reason should pass" "exit 0" \
            "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}

# =============================================================================
# Test 5: Escape hatch SIN razon sigue fallando
# =============================================================================
test_ignore_without_reason_fails() {
    log_test "Ignore entry WITHOUT reason -> lint still fails (entry is invalid)"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-badignore-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    build_clean_fixture "$fixture" >/dev/null
    mkdir -p "$fixture/skills/broken-no-fm"
    cat > "$fixture/skills/broken-no-fm/SKILL.md" <<'EOF'
# No frontmatter here
EOF
    # Ignore entry without a reason (just path, no |reason)
    cat > "$fixture/skills/.skill-lint-ignore" <<'EOF'
broken-no-fm/SKILL.md
EOF

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -ne 0 ]] && grep -q "missing '|' separator\|empty reason" "$fixture/out"; then
        log_pass "empty reason rejected (exit !=0, names the problem)"
    else
        log_fail "empty reason should fail" "exit !=0 + reason error in output" \
            "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}

# =============================================================================
# Test 6: Alcance cero -> exit !=0
# =============================================================================
test_zero_skills_fails() {
    log_test "Empty corpus (no skills scanned) -> lint fails with 'zero skills scanned'"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-zero-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    mkdir -p "$fixture/skills"
    mkdir -p "$fixture/hooks"

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -ne 0 ]] && grep -q "zero skills scanned" "$fixture/out"; then
        log_pass "zero-scanned fails (exit !=0, names the problem)"
    else
        log_fail "zero-scanned should fail" "exit !=0 + 'zero skills scanned'" \
            "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}

# =============================================================================
# Test 7: name en frontmatter != nombre del directorio -> falla
# =============================================================================
test_name_mismatch_fails() {
    log_test "name in frontmatter != directory name -> lint fails"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-namemismatch-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    build_clean_fixture "$fixture" >/dev/null
    # The directory is fixture-skill-a but the frontmatter name is wrong
    cat > "$fixture/skills/fixture-skill-a/SKILL.md" <<'EOF'
---
name: WRONG-NAME
version: 1.0.0
description: "Frontmatter name does not match the directory name."
user-invocable: true
---

# Wrong name
EOF

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -ne 0 ]] && grep -q "does not match" "$fixture/out"; then
        log_pass "name/dir mismatch detected (exit !=0, names the problem)"
    else
        log_fail "name/dir mismatch should fail" "exit !=0 + 'does not match'" \
            "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}

# =============================================================================
# Test 8: Obsolete ignore entry -> lint reports it
# =============================================================================
test_ignore_obsolete_reported() {
    log_test "Ignore entry that silences nothing -> lint reports it as obsolete"

    local fixture
    fixture=$(mktemp -d "/tmp/skill-lint-obs-XXXXXX")
    trap "rm -rf '$fixture'" EXIT

    build_clean_fixture "$fixture" >/dev/null
    # The fixture has 2 valid skills, no broken file. The ignore entry
    # below points at a path that doesn't have a violation -> obsolete.
    cat > "$fixture/skills/.skill-lint-ignore" <<'EOF'
nonexistent-path/SKILL.md|fixture: this entry is obsolete for the test
EOF

    local rc=0
    python3 "$LINT" --skills-dir "$fixture/skills" --hooks-dir "$fixture/hooks" >"$fixture/out" 2>&1 || rc=$?

    if [[ $rc -ne 0 ]] && grep -q "obsolete" "$fixture/out"; then
        log_pass "obsolete entry reported (exit !=0, names the problem)"
    else
        log_fail "obsolete entry should be reported" "exit !=0 + 'obsolete' in output" \
            "exit $rc; output: $(cat "$fixture/out")"
    fi
    rm -rf "$fixture"
}


# =============================================================================
# Test 9: Real-world fixture (macos-cleaner) passes the lint
# This fixture is the daymade-skills/macos-cleaner/SKILL.md, copied
# verbatim. If the lint can't handle real-world content (e.g. it
# mistakes "sudo rm -rf" mentions in a SKILL.md's body for a skill
# reference, or counts paths in the body as orphan refs), the lint is
# too narrow and the gate is unfit for the corpus.
# =============================================================================
test_macos_cleaner_fixture_passes() {
    log_test "Real-world fixture (macos-cleaner) passes the lint"

    local fixture="$SCRIPT_DIR/fixtures/skill-lint/macos-cleaner"
    if [[ ! -d "$fixture" ]]; then
        log_fail "fixture dir missing" "fixture at $fixture" "missing"
        return
    fi

    # Use an empty hooks dir for the scan so the lint doesn't pick up
    # unrelated *.sh files from the test host (e.g. scratchpad trees
    # with archived hooks). The macos-cleaner fixture is only about
    # the SKILL.md itself.
    local empty_hooks
    empty_hooks=$(mktemp -d "/tmp/skill-lint-empty-hooks-XXXXXX")
    trap "rm -rf '$empty_hooks'" EXIT

    local rc=0
    python3 "$LINT" --skills-dir "$fixture" --hooks-dir "$empty_hooks" >/dev/null 2>&1 || rc=$?

    if [[ $rc -eq 0 ]]; then
        log_pass "macos-cleaner SKILL.md is well-formed (frontmatter, description, name)"
    else
        local detail
        detail=$(python3 "$LINT" --skills-dir "$fixture" --hooks-dir "$empty_hooks" 2>&1)
        log_fail "macos-cleaner should pass" "exit 0" "exit $rc; output: $detail"
    fi
    rm -rf "$empty_hooks"
}


# =============================================================================
# Main
# =============================================================================
main() {
    echo -e "${CYAN}============================================================${RESET}"
    echo -e "${CYAN}skill-lint test suite (T50)${RESET}"
    echo -e "${CYAN}============================================================${RESET}"
    echo

    test_clean_fixture_passes
    test_no_frontmatter_fails
    test_hook_orphan_ref_fails
    test_ignore_with_reason_silences
    test_ignore_without_reason_fails
    test_zero_skills_fails
    test_name_mismatch_fails
    test_ignore_obsolete_reported
    test_macos_cleaner_fixture_passes

    echo
    echo -e "${CYAN}-----------------------------------------------------------${RESET}"
    echo -e "Results: ${GREEN}${TESTS_PASSED} passed${RESET}, ${RED}${TESTS_FAILED} failed${RESET}, ${DIM}${TESTS_TOTAL} total${RESET}"
    echo -e "${CYAN}-----------------------------------------------------------${RESET}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
}

main "$@"
