#!/bin/bash
# test-clarity-scoring.sh - Test clarity scoring algorithm
# VERSION: 2.0.0  (T36: repointed to live command-router.sh)
#
# T36 history:
#   The original (v1.0.0) suite declared HOOK_FILE (pointing at the now-
#   retired .claude/hooks/promptify-auto-detect.sh) and shipped its own
#   local copy of calculate_clarity_score() — extracted at script load.
#   That copy had THREE word-count tiers (<5, <10, <15); the live function
#   in .claude/hooks/command-router.sh (consolidated in 498556f) has only
#   TWO (<5, <10). The 3rd tier never existed in production; git log -S
#   'word_count' on command-router.sh returns only 498556f, and the
#   pre-consolidation promptify-auto-detect.sh (94cbf59) also had two
#   tiers. So the test was MORE permissive than production for 10-14
#   word prompts, with no way to detect its own drift (the copy cannot
#   see changes to the live function).
#
#   v2.0.0 follows the wrapper convention already established in this
#   directory by test-credential-redaction.sh, test-security-functions.sh,
#   and the validate_prompt_security path: source command-router.sh
#   SECTION 4 at runtime via awk, never inline a function body. The 20
#   existing test cases pass against the live function (verified by
#   score-divergence.sh). The new case that exercises the 10-14 word
#   tier boundary is deferred until the production intent is confirmed.

set -euo pipefail

readonly VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# The live home of calculate_clarity_score() after the 498556f consolidation.
readonly ROUTER_FILE="${PROJECT_ROOT}/.claude/hooks/command-router.sh"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
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

# Source calculate_clarity_score from the LIVE command-router.sh SECTION 4.
# This is the same extraction pattern test-e2e.sh uses (T34b). The wrapper
# convention in this directory (test-credential-redaction.sh:45,
# test-security-functions.sh:45 and :288) is `bash -c 'source "$1"; fn "$2"'`;
# this script extracts the section once into a temp file rather than
# spawning a subshell per call because the 20 test cases invoke
# calculate_clarity_score in-process.
source_live_clarity_score() {
    local promptify_src
    promptify_src=$(mktemp)
    trap 'rm -f "${promptify_src:-}"' EXIT

    if [[ ! -f "$ROUTER_FILE" ]]; then
        echo -e "${RED}FAIL${NC}: command-router.sh missing: $ROUTER_FILE" >&2
        echo "This suite exercises the live calculate_clarity_score() which" >&2
        echo "lives in command-router.sh SECTION 4. If the router itself is" >&2
        echo "absent, no assertion can be made — the wrapper fails loud." >&2
        exit 1
    fi

    awk '
        /SECTION 4: PROMPTIFY/ { in_section = 1 }
        in_section { print }
        /^# MAIN EXECUTION$/ { exit }
    ' "$ROUTER_FILE" > "$promptify_src"

    if [[ ! -s "$promptify_src" ]]; then
        echo -e "${RED}FAIL${NC}: SECTION 4: PROMPTIFY empty in $ROUTER_FILE" >&2
        exit 1
    fi

    # PROMPTIFY_CONFIG_FILE is defined at command-router.sh:40 (preamble
    # above SECTION 4). Sandbox HOME has no ~/.ralph/config/promptify.json
    # so the function falls back to its built-in defaults.
    : "${PROMPTIFY_CONFIG_FILE:=/nonexistent/promptify-test-fallback.json}"
    # log_message is also in the preamble. The function is called inside
    # calculate_clarity_score only when DEBUG is enabled; the test
    # never sets that, so a no-op stub is correct.
    log_message() { :; }
    # shellcheck disable=SC1090
    source "$promptify_src"
}

source_live_clarity_score

# Run tests
run_tests() {
    echo "========================================"
    echo "Promptify Clarity Scoring Test Suite v${VERSION}"
    echo "========================================"
    echo ""

    # Test cases: (prompt, min_expected, max_expected)
    declare -a TEST_CASES=(
        # Very vague prompts (0-30%)
        "fix the thing|0|30"
        "stuff|0|20"
        "help me|0|25"
        "do this|0|30"
        "make it better|0|30"

        # Moderately vague prompts (30-50%)
        "add auth|30|50"
        "create login|35|55"
        "fix error|30|50"
        "implement oauth|35|55"

        # Moderate clarity prompts (50-70%)
        "implement OAuth2 login for my app|55|75"
        "create a REST API with authentication|50|70"
        "add user authentication to the system|55|75"

        # High clarity prompts (70-90%)
        "You are a backend engineer. Implement OAuth2 login with PKCE flow and handle token refresh|70|90"
        "Create a REST API using Express.js with JWT authentication and role-based access control|75|95"

        # Very high clarity prompts (90-100%)
        "You are a senior backend engineer specialized in authentication. Implement OAuth2 login with PKCE flow, handle token refresh with retry logic, log all authentication events, write unit tests with 80 percent coverage, and document the API endpoints|90|100"

        # 10-14 word tier guard (T36): the local calculate_clarity_score copy
        # in v1.0.0 had THREE word-count tiers (<5, <10, <15 -> -40/-20/-10).
        # Production (command-router.sh SECTION 4) has only TWO; the 3rd tier
        # was an invention of the test copy and never existed in production.
        # This case exercises the 12-word band where the two diverge, with a
        # NARROW [98,100] range (2-point tolerance) so any future regression
        # that re-adds the 3rd tier in production fails loudly here. Score:
        # local copy -> 90 (FAIL), live function -> 100 (PASS).
        "You are an engineer. Implement OAuth2 login with PKCE. Must use JWT.|98|100"
    )

    # Run standard test cases
    echo "Standard Test Cases"
    echo "===================="
    echo ""

    for test_case in "${TEST_CASES[@]}"; do
        IFS='|' read -r prompt min_score max_score <<< "$test_case"

        # Run clarity scoring
        score=$(calculate_clarity_score "$prompt")

        # Check if score is in expected range
        if [[ $score -ge $min_score && $score -le $max_score ]]; then
            print_result "PASS" "\"$prompt\" → $score% (expected: $min_score-$max_score)"
        else
            print_result "FAIL" "\"$prompt\" → $score% (expected: $min_score-$max_score)"
        fi
    done

    echo ""
    echo "Edge Cases"
    echo "==========="
    echo ""

    # Test empty prompt.
    # La expectativa anterior (90-100%) estaba invertida: contradecia la
    # semantica del resto de la suite y del propio hook, donde un score ALTO
    # significa prompt CLARO ("clarity score is 35% (below 50% threshold)").
    # Un prompt vacio es el caso menos claro posible, asi que su score debe
    # quedar por debajo del de un prompt de 2 palabras (<=60% justo abajo).
    score=$(calculate_clarity_score "")
    if [[ $score -le 30 ]]; then
        print_result "PASS" "Empty prompt → $score% (expected: <=30%)"
    else
        print_result "FAIL" "Empty prompt → $score% (expected: <=30%)"
    fi

    # Test very short prompts
    score=$(calculate_clarity_score "hi")
    if [[ $score -le 60 ]]; then
        print_result "PASS" "Very short prompt (2 words) → $score% (expected: <=60%)"
    else
        print_result "FAIL" "Very short prompt (2 words) → $score% (expected: <=60%)"
    fi

    # Test structure bonuses
    score_no_structure=$(calculate_clarity_score "implement oauth")
    score_with_role=$(calculate_clarity_score "You are a backend engineer. Implement oauth")
    score_complete=$(calculate_clarity_score "You are a backend engineer. Implement oauth login with PKCE flow. Must handle errors. Return working system")

    if [[ $score_with_role -gt $score_no_structure ]]; then
        print_result "PASS" "Role bonus: $score_with_role > $score_no_structure"
    else
        print_result "FAIL" "Role bonus: Expected $score_with_role > $score_no_structure"
    fi

    if [[ $score_complete -gt $score_with_role ]]; then
        print_result "PASS" "Complete structure bonus: $score_complete > $score_with_role"
    else
        print_result "FAIL" "Complete structure bonus: Expected $score_complete > $score_with_role"
    fi

    # Test score bounds
    score_min=$(calculate_clarity_score "thing stuff something nothing fix it make it better help me do this whatever")
    if [[ $score_min -ge 0 && $score_min -le 100 ]]; then
        print_result "PASS" "Score lower bound: $score_min% >= 0%"
    else
        print_result "FAIL" "Score lower bound: $score_min% out of range"
    fi

    echo ""
}

# Print summary
print_summary() {
    echo "========================================"
    echo "Test Summary"
    echo "========================================"
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

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed${NC}"
        return 1
    fi
}

# Main execution
main() {
    run_tests
    print_summary
}

# Run tests if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
