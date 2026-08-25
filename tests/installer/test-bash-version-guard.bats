#!/usr/bin/env bats
#===============================================================================
# test-bash-version-guard.bats - Guard against the bash 3.2 silent-corruption bug
#
# VERSION: 1.0.0
# PURPOSE: Lock in the fix for issue #44.
#
# The bug: every validator in scripts/ builds its result tables with `declare -A`.
# Bash 3.2 — what macOS ships as /bin/bash — has no associative arrays, and does
# NOT abort on one. It writes "declare: -A: invalid option" to stderr, keeps
# going, and collapses every RESULTS[key]=... onto index 0, because an unset name
# used as an array subscript evaluates arithmetically to 0.
#
# The result was output that looked plausible and was wrong. In CI it surfaced as
# `jq: parse error: Invalid numeric literal at line 1, column N` where N matched
# no emitter — N was the character length of the failing script's own absolute
# path, because $output started with the bash error message instead of "{".
#
# These tests assert the two halves of the fix: the guard refuses to run under an
# old bash instead of degrading, and no validator can quietly opt out of it.
#===============================================================================

load test_helper

setup() {
    setup_installer_test
    VC_LIB="$PROJECT_ROOT/scripts/lib/validation-common.sh"
}

teardown() {
    teardown_installer_test
}

#===============================================================================
# STRUCTURAL: the guard cannot be bypassed by adding a new validator
#===============================================================================

@test "guard: every scripts/ script using declare -A declares VC_REQUIRE_BASH4" {
    local offenders=""
    local f
    for f in "$PROJECT_ROOT"/scripts/*.sh; do
        grep -q 'declare -A' "$f" || continue
        grep -q 'VC_REQUIRE_BASH4=1' "$f" || offenders="$offenders $(basename "$f")"
    done
    # declare -A without the declaration is a script that will silently corrupt its
    # own result tables on macOS — the #44 failure mode, reintroduced.
    [[ -z "$offenders" ]] || fail "declare -A without VC_REQUIRE_BASH4=1:$offenders"
}

@test "guard: no bash-3-clean script opts into the bash 4 requirement" {
    local offenders=""
    local f
    for f in "$PROJECT_ROOT"/scripts/*.sh; do
        grep -q 'VC_REQUIRE_BASH4=1' "$f" || continue
        grep -q 'declare -A' "$f" || offenders="$offenders $(basename "$f")"
    done
    # The converse matters just as much. Ten of the library's twenty callers are
    # bash-3 clean and one advertises "COMPAT: Bash 3.2+ (macOS native)" in its
    # header; making them require bash 4 would break them on stock macOS to solve a
    # problem they do not have.
    [[ -z "$offenders" ]] || fail "opted into bash 4 without needing it:$offenders"
}

@test "guard: validation-common.sh carries the version check, gated on the flag" {
    assert_file_exists "$VC_LIB"
    grep -q 'BASH_VERSINFO' "$VC_LIB"
    grep -q 'VC_REQUIRE_BASH4' "$VC_LIB"
}

#===============================================================================
# BEHAVIOURAL: what the guard does when bash is too old
#===============================================================================

# `sh` reproduces the entry condition on both runners: on Linux it is dash, which
# has no BASH_VERSINFO at all; on macOS it is bash 3.2 in POSIX mode, which is the
# literal interpreter that caused the bug. Either way the guard's condition holds.

@test "guard: re-execs under a newer bash when one is available" {
    run env VC_REQUIRE_BASH4=1 sh "$VC_LIB"
    # If the guard did not exec a real bash, the shell would reach `[[` further
    # down the library and die: reaching exit 0 is itself the proof it re-execed.
    [[ $status -eq 0 ]]
}

@test "guard: refuses with a clear message when no bash 4+ exists" {
    local stub="$TEST_TMPDIR/vc-no-candidates.sh"
    # Same library, with the candidate interpreters pointed at nothing. This is
    # the only part that has to be simulated: the machine running the suite has a
    # usable bash by definition, so the refusal path cannot be reached honestly.
    sed 's#^[[:space:]]*for _vc_bash in .*#    for _vc_bash in /nonexistent/bash; do#' \
        "$VC_LIB" > "$stub"
    grep -q '/nonexistent/bash' "$stub" || fail "stub rewrite did not apply"

    run env VC_REQUIRE_BASH4=1 sh "$stub"
    [[ $status -eq 78 ]]
    [[ "$output" == *"requires bash 4.0+"* ]]
    [[ "$output" == *"brew install bash"* ]]
}

@test "guard: a caller that does not opt in is never blocked by the version check" {
    local stub="$TEST_TMPDIR/vc-no-candidates-unflagged.sh"
    sed 's#^[[:space:]]*for _vc_bash in .*#    for _vc_bash in /nonexistent/bash; do#' \
        "$VC_LIB" > "$stub"
    grep -q '/nonexistent/bash' "$stub" || fail "stub rewrite did not apply"

    # Same old shell, same unreachable candidates, but no VC_REQUIRE_BASH4. The
    # bash-3-clean callers must sail straight past. 78 here would mean stock macOS
    # loses install-language-servers.sh and nine others to a guard they never needed.
    run sh "$stub"
    [[ $status -ne 78 ]]
    [[ "$output" != *"requires bash 4.0+"* ]]
}

#===============================================================================
# GNU-only tooling: the other half of #44
#===============================================================================

# Same failure shape, different command. validate-hooks-execution.sh bounds each hook
# with timeout(1), which is GNU coreutils; macOS ships neither it nor an equivalent, so
# the script exited 2 with "timeout command not found". bats' `run` merges stderr into
# $output, so that sentence is what the tests then fed to jq -- hence
# `Invalid literal at line 1, column 8`, "timeout" being seven characters long.
#
# This is the third instance of the same class in this file's history: `stat -f` in #43
# and `cat -A` in the debug step meant to diagnose #44.

@test "gnu-tooling: hooks-execution validator accepts gtimeout as a fallback" {
    local script="$PROJECT_ROOT/scripts/validate-hooks-execution.sh"
    assert_file_exists "$script"
    grep -q 'gtimeout' "$script"
    # The bare command must not survive: it is what broke on macOS.
    ! grep -qE '\$\(timeout "\$TIMEOUT_SECONDS"' "$script"
}

@test "gnu-tooling: hooks-execution validator names the remedy when neither exists" {
    grep -q 'brew install coreutils' "$PROJECT_ROOT/scripts/validate-hooks-execution.sh"
}

#===============================================================================
# END TO END: the symptom from issue #44 itself
#===============================================================================

@test "guard: validators emit parseable JSON, not a bash error message" {
    # Runs under the sandbox HOME that setup_installer_test provides, deliberately.
    # An earlier draft handed the real $HOME back so the validators would find a
    # provisioned install — which would have made this assertion depend on the
    # developer's own machine, the exact category docs/testing/ORPHAN_TEST_AUDIT.md
    # classifies as unfit for a gate. It buys nothing here: the claim under test is
    # that the output is JSON at all, and a validator reporting "fail" against an
    # empty home reports it in perfectly good JSON.
    local script
    for script in validate-directories validate-agents-registration \
                  validate-shell-config validate-skills-registration \
                  validate-system-requirements; do
        run "$PROJECT_ROOT/scripts/$script.sh" --format json
        # Assert on the shape of the failure the issue actually had: output that
        # begins with a path instead of a brace.
        [[ "$output" != "$PROJECT_ROOT"* ]] || \
            fail "$script.sh emitted a shell error, not JSON: ${output:0:120}"
        echo "$output" | jq empty || fail "$script.sh did not emit valid JSON"
    done
}
