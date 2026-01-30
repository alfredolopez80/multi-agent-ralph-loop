#!/bin/bash
# test-clarity-scoring.sh - Test clarity scoring algorithm
# VERSION: 1.0.0
# Part of Promptify Integration Test Suite

set -euo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
readonly HOOK_FILE="${PROJECT_ROOT}/.claude/hooks/promptify-auto-detect.sh"

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
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Calculate clarity score (extracted from hook)
calculate_clarity_score() {
    local prompt="$1"
    local score=100
    local prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

    # 1. Word count penalty (too short = vague)
    local word_count=$(echo "$prompt" | wc -w | tr -d ' ')
    if [[ $word_count -lt 5 ]]; then
        score=$((score - 40))
    elif [[ $word_count -lt 10 ]]; then
        score=$((score - 20))
    elif [[ $word_count -lt 15 ]]; then
        score=$((score - 10))
    fi

    # 2. Vague word penalty
    local vague_words=("thing" "stuff" "something" "anything" "nothing" "fix it" "make it better" "help me" "whatsit" "thingy" "whatever")
    for word in "${vague_words[@]}"; do
        if echo "$prompt_lower" | grep -qE "$word"; then
            score=$((score - 15))
        fi
    done

    # 3. Pronoun penalty (ambiguous references)
    if echo "$prompt_lower" | grep -qE "\b(this|that|it|they|them)\s+\b"; then
        score=$((score - 10))
    fi

    # 4. Missing structure penalty
    local has_role=false
    local has_task=false
    local has_constraints=false

    # Check for role indicators
    if echo "$prompt_lower" | grep -qE "(you are|act as|role|persona|you.re a|you are an?)"; then
        has_role=true
    fi

    # Check for task indicators
    if echo "$prompt_lower" | grep -qE "(implement|create|build|write|analyze|design|fix|add|make|develop|code)"; then
        has_task=true
    fi

    # Check for constraint indicators
    if echo "$prompt_lower" | grep -qE "(must|should|constraint|requirement|limit|except|but|however)"; then
        has_constraints=true
    fi

    if [[ "$has_role" == false ]]; then
        score=$((score - 15))
    fi
    if [[ "$has_task" == false ]]; then
        score=$((score - 20))
    fi
    if [[ "$has_constraints" == false ]]; then
        score=$((score - 10))
    fi

    # Ensure score is within 0-100 range
    if [[ $score -lt 0 ]]; then
        score=0
    elif [[ $score -gt 100 ]]; then
        score=100
    fi

    echo "$score"
}

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

    # Test empty prompt
    score=$(calculate_clarity_score "")
    if [[ $score -ge 90 && $score -le 100 ]]; then
        print_result "PASS" "Empty prompt → $score% (expected: 90-100%)"
    else
        print_result "FAIL" "Empty prompt → $score% (expected: 90-100%)"
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
