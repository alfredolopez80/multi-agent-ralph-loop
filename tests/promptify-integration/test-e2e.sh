#!/bin/bash
# test-e2e.sh - End-to-end integration test for Promptify
# VERSION: 2.0.0  (T34b: repointed to live consolidated code)
#
# T34b history:
#   The original (v1.0.0) suite targeted `.claude/hooks/promptify-auto-detect.sh`,
#   which the runner counted as ✓ PASSED with zero assertions because the
#   suite's setup bailed out with `return 0` when that file was missing.
#   T30 closed the silent-skip class for the bats branch; T34 closed it for
#   the shell branch and made THIS suite fail loudly with the reason.
#
#   Lead then corrected T34: the hook was not retired in 498556f — it was
#   CONSOLIDATED into `.claude/hooks/command-router.sh`. `calculate_clarity_score()`
#   and `run_promptify_auto_detect()` live there now (functions at lines 302
#   and 377; invocation at line 434). v2.0.0 repoints the suite to exercise
#   the live function via a runtime extraction of SECTION 4: PROMPTIFY.
#
#   The T34 fail-loud verdict is preserved for the genuine "missing target"
#   case: if command-router.sh itself is gone, we still fail loud rather
#   than minting "Tests Run: 0 / Tests Passed: 0".
#
# Part of Promptify Integration Test Suite

set -euo pipefail

readonly VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# The Promptify logic was consolidated into command-router.sh in 498556f.
readonly ROUTER_FILE="${PROJECT_ROOT}/.claude/hooks/command-router.sh"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Print test result
print_result() {
    local status="$1"
    local message="$2"

    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        TESTS_PASSED=$((TESTS_PASSED+1))
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        TESTS_FAILED=$((TESTS_FAILED+1))
    fi
    TESTS_RUN=$((TESTS_RUN+1))
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
}

# Extract SECTION 4: PROMPTIFY from command-router.sh to a temp file and
# source it. We do NOT `source` command-router.sh directly because its
# bottom invokes run_command_router, run_curator_suggestion,
# run_prompt_analyzer and emits JSON to stdout — side effects we don't
# want from a unit test. The extraction is line-range based; SECTION 4
# is bounded by SECTION 5 (or end-of-file).
extract_promptify_functions() {
    local out="$1"
    # Extract SECTION 4: PROMPTIFY AUTO-DETECT only. command-router.sh does
#    not have a SECTION 5 — the next boundary is the `# MAIN EXECUTION`
#    banner that calls every analyzer and emits JSON. We do NOT want any
#    of that in a unit test.
    awk '
        /SECTION 4: PROMPTIFY/ { in_section = 1 }
        in_section { print }
        /^# MAIN EXECUTION$/ { exit }
    ' "$ROUTER_FILE" > "$out"
}

# Run E2E tests
run_e2e_tests() {
    print_header "End-to-End Integration Tests v${VERSION}"

    # The T34 fail-loud verdict — kept for the genuine missing-target case.
    # command-router.sh is the LIVE consolidated home of the Promptify
    # logic; if it is gone, the suite cannot exercise the behaviour it
    # claims to test, and reporting green over zero assertions would be
    # the same fail-open T34 closed. See docs/testing/ORPHAN_TEST_AUDIT.md.
    if [[ ! -f "$ROUTER_FILE" ]]; then
        echo -e "${RED}FAIL${NC}: command-router.sh missing: $ROUTER_FILE"
        echo "This suite tests the Promptify logic consolidated into"
        echo "command-router.sh (originally promptify-auto-detect.sh, retired"
        echo "as a standalone path in 498556f). If the router itself is"
        echo "absent, the suite cannot exercise any of the live behaviour."
        echo "Verdict options:"
        echo "  (a) Restore command-router.sh."
        echo "  (b) Update ROUTER_FILE in this suite if the logic moved again."
        echo "  (c) Retire this suite per the #50 precedent."
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        return 1
    fi

    # Extract Promptify functions to a temp file we can source safely.
    # Declared in the function's scope so it is unset once we return; the
    # trap uses ${promptify_src:-} so it survives the unset and never errors.
    local promptify_src
    promptify_src=$(mktemp)
    trap 'rm -f "${promptify_src:-}"' EXIT

    if ! extract_promptify_functions "$promptify_src"; then
        echo -e "${RED}FAIL${NC}: could not extract Promptify functions from $ROUTER_FILE"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        return 1
    fi

    if [[ ! -s "$promptify_src" ]]; then
        echo -e "${RED}FAIL${NC}: Promptify section empty in $ROUTER_FILE"
        echo "Expected SECTION 4: PROMPTIFY between the marker comment and"
        echo "the next section. Either the layout drifted or the SECTION 4"
        "marker is missing."
        TESTS_FAILED=$((TESTS_FAILED + 1))
        TESTS_RUN=$((TESTS_RUN + 1))
        return 1
    fi

    # Source the extracted functions. We do NOT want command-router.sh's
    # bottom (run_command_router + emit JSON), only the promptify block.
    # PROMPTIFY_CONFIG_FILE is defined at line 40 (above SECTION 4) in
    # command-router.sh; our extraction doesn't include it, so set a
    # fallback here. The test sandbox has no ~/.ralph/config/promptify.json
    # so the functions fall back to their built-in defaults.
    : "${PROMPTIFY_CONFIG_FILE:=/nonexistent/promptify-test-fallback.json}"
    # log_message is defined in command-router.sh's preamble (above SECTION 4).
    # The SECTION 4 functions call it but we don't want to bring the whole
    # preamble in (it has side effects like sourcing other libs). Stub it
    # so the call sites resolve; the test asserts the promptify behaviour,
    # not the log output.
    log_message() { :; }
    # ALL_SUGGESTIONS is the global aggregator populated by every analyzer.
    # run_promptify_auto_detect appends to it; declaring it here keeps the
    # call site working without the rest of command-router.sh.
    ALL_SUGGESTIONS=()
    # shellcheck disable=SC1090
    source "$promptify_src"

    # Test 1: calculate_clarity_score exists and is callable
    echo ""
    echo "Test 1: Live calculate_clarity_score() available"
    echo "================================================="
    if [[ "$(type -t calculate_clarity_score)" == "function" ]]; then
        print_result "PASS" "calculate_clarity_score() is defined in command-router.sh SECTION 4"
    else
        print_result "FAIL" "calculate_clarity_score() missing from SECTION 4"
        return 1
    fi

    # Test 2: a well-structured prompt scores high
    echo ""
    echo "Test 2: Structured prompt clarity"
    echo "================================="
    local score
    score=$(calculate_clarity_score "You are a senior backend engineer. Implement a rate limiter for the /api/users endpoint. Must handle 1000 req/s. Constraint: use Redis with sliding window.")
    if [[ "$score" -ge 80 && "$score" -le 100 ]]; then
        print_result "PASS" "structured prompt scores in [80,100]: $score"
    else
        print_result "FAIL" "structured prompt expected in [80,100], got $score"
    fi

    # Test 3: a vague prompt scores low
    echo ""
    echo "Test 3: Vague prompt clarity"
    echo "============================"
    score=$(calculate_clarity_score "fix the thing")
    if [[ "$score" -lt 50 ]]; then
        print_result "PASS" "vague prompt scores below threshold: $score < 50"
    else
        print_result "FAIL" "vague prompt expected < 50, got $score"
    fi

    # Test 4: vague-words list is present and applied
    echo ""
    echo "Test 4: Vague-words penalty"
    echo "============================"
    # Two prompts identical except for one containing a vague word.
    # The vague-word version must score lower (penalty -15 per vague word).
    local base_score
    base_score=$(calculate_clarity_score "Implement a clear migration plan for the legacy service")
    local vague_score
    vague_score=$(calculate_clarity_score "Implement a clear migration plan for the legacy thing")
    local diff=$((base_score - vague_score))
    if [[ "$diff" -ge 15 ]]; then
        print_result "PASS" "vague word 'thing' reduces score by $diff (>= 15)"
    else
        print_result "FAIL" "vague word penalty expected >= 15, got $diff"
    fi

    # Test 5: score is bounded to [0, 100]
    echo ""
    echo "Test 5: Score bounds"
    echo "==================="
    # Empty prompt hits every penalty; score should clamp to >= 0.
    local empty_score
    empty_score=$(calculate_clarity_score "")
    if [[ "$empty_score" -ge 0 && "$empty_score" -le 100 ]]; then
        print_result "PASS" "empty prompt score clamped to [0,100]: $empty_score"
    else
        print_result "FAIL" "empty prompt score out of bounds: $empty_score"
    fi

    # Test 6: command-router.sh actually invokes run_promptify_auto_detect
    # (the live wiring — without this, the function is dead code).
    echo ""
    echo "Test 6: Live wiring in command-router.sh"
    echo "=========================================="
    if grep -qE '^run_promptify_auto_detect(\b|[[:space:]]*$)' "$ROUTER_FILE"; then
        print_result "PASS" "command-router.sh invokes run_promptify_auto_detect"
    else
        print_result "FAIL" "command-router.sh does not invoke run_promptify_auto_detect (live wiring broken)"
    fi

    # Test 7: integration — calling run_promptify_auto_detect with
    # USER_PROMPT set should not error out (returns 0 even when the
    # clarity score is high enough not to suggest /promptify).
    echo ""
    echo "Test 7: run_promptify_auto_detect smoke"
    echo "========================================"
    USER_PROMPT="You are an API designer. Implement a /health endpoint that returns JSON. Must check DB and Redis."
    local rc=0
    run_promptify_auto_detect || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        print_result "PASS" "run_promptify_auto_detect returned 0 on a structured prompt"
    else
        print_result "FAIL" "run_promptify_auto_detect exited with rc=$rc on a structured prompt"
    fi

    echo ""
}

# Print summary
print_summary() {
    print_header "Test Summary"

    echo -e "Tests Run:    ${TESTS_RUN}"
    echo -e "${GREEN}Tests Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests Failed: ${TESTS_FAILED}${NC}"
    echo ""

    local pass_rate=0
    if [[ $TESTS_RUN -gt 0 ]]; then
        pass_rate=$((TESTS_PASSED * 100 / TESTS_RUN))
    fi

    echo -e "Pass Rate:    ${pass_rate}%"
    echo ""


# T94: zero-tests guard — fail loud when no assertion ran. Without
# this check, a broken collection that increments zero counters would
# print 'All tests passed!' and exit 0. Mirrors the canonic pattern in
# tests/unit/test_validation_common.sh (lines 56-58).
if [[ $TESTS_RUN -eq 0 ]]; then
    echo "FATAL: zero tests executed — cannot declare success" >&2
    exit 1
fi
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All E2E tests passed!${NC}"
        echo ""
        echo "Promptify integration is working correctly."
        return 0
    else
        echo -e "${RED}❌ Some E2E tests failed${NC}"
        echo ""
        echo "Please review the failed tests above."
        return 1
    fi
}

# Main execution
main() {
    run_e2e_tests
    print_summary
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi