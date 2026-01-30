#!/bin/bash
# test-credential-redaction.sh - Test credential redaction functionality
# VERSION: 1.0.1
# Part of Promptify Integration Test Suite

set -euo pipefail

readonly VERSION="1.0.1"

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

# Credential redaction function (simplified, cross-platform)
redact_credentials() {
    local text="$1"

    # Use multiple sed commands for better portability
    echo "$text" | sed -E '
        s/(password|passwd|pwd)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi;
        s/(secret|token|api_key|apikey|access_token|auth_token|credential)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi;
        s/(bearer|authorization)[[:space:]]*:[[:space:]]*[A-Za-z0-9._~=-]+/\1: [REDACTED]/gi;
        s/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[EMAIL REDACTED]/g;
        s/[0-9]{3}-[0-9]{3}-[0-9]{4}/[PHONE REDACTED]/g;
        s/sk-[a-zA-Z0-9]{32,}/[SK-KEY REDACTED]/g;
        s/ghp_[a-zA-Z0-9]{36,}/[GH-TOKEN REDACTED]/g;
        s/xoxb-[a-zA-Z0-9-]{10,}/[SLACK-TOKEN REDACTED]/g;
    '
}

# Test cases: (input, should_contain, should_not_contain)
declare -a TEST_CASES=(
    # Basic patterns
    "password:secret123|[REDACTED]|secret123"
    "token:abc456|[REDACTED]|abc456"
    "email:user@example.com|[EMAIL REDACTED]|user@example.com"
    "phone:123-456-7890|[PHONE REDACTED]|123-456-7890"
)

# Run tests
run_tests() {
    echo "========================================"
    echo "Credential Redaction Test Suite v${VERSION}"
    echo "========================================"
    echo ""

    for test_case in "${TEST_CASES[@]}"; do
        IFS='|' read -r input expected_output should_not_contain <<< "$test_case"

        # Run redaction
        output=$(redact_credentials "$input")

        # Check if expected output is present
        if [[ "$output" == *"$expected_output"* ]]; then
            # Check if original value is NOT in output
            if [[ "$output" != *"$should_not_contain"* ]]; then
                print_result "PASS" "\"$input\" → credential redacted"
            else
                print_result "FAIL" "\"$input\" → credential NOT redacted (found: $should_not_contain)"
            fi
        else
            print_result "FAIL" "\"$input\" → expected output not found (expected: $expected_output, got: $output)"
        fi
    done

    echo ""
    echo "Edge Case Tests"
    echo "================"
    echo ""

    # Test empty input
    output=$(redact_credentials "")
    if [[ -z "$output" ]]; then
        print_result "PASS" "Empty input handled correctly"
    else
        print_result "FAIL" "Empty input produced unexpected output: $output"
    fi

    # Test input without credentials
    input="This is a normal prompt about implementing OAuth"
    output=$(redact_credentials "$input")
    if [[ "$output" == "$input" ]]; then
        print_result "PASS" "Normal text without credentials unchanged"
    else
        print_result "FAIL" "Normal text was modified unexpectedly"
    fi

    # Test case sensitivity
    input1="password:secret123"
    input2="PASSWORD:secret123"

    output1=$(redact_credentials "$input1")
    output2=$(redact_credentials "$input2")

    if [[ "$output1" == *"[REDACTED]"* && "$output2" == *"[REDACTED]"* ]]; then
        print_result "PASS" "Case insensitivity works correctly"
    else
        print_result "FAIL" "Case insensitivity failed"
    fi

    # Test multiple credentials
    input="password:pass123 and token:tok456"
    output=$(redact_credentials "$input")

    if [[ "$output" == *"[REDACTED]"* ]] && [[ "$output" != *"pass123"* ]] && [[ "$output" != *"tok456"* ]]; then
        print_result "PASS" "Multiple credentials redacted correctly"
    else
        print_result "FAIL" "Multiple credentials not fully redacted"
    fi

    echo ""
    echo "Performance Test"
    echo "================"
    echo ""

    # Generate large text with credentials
    large_text=""
    for i in {1..50}; do
        large_text+="password:pass${i} token:tok${i} "
    done

    start_time=$(date +%s%N)
    output=$(redact_credentials "$large_text")
    end_time=$(date +%s%N)

    elapsed=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds

    if [[ $elapsed -lt 1000 ]]; then
        print_result "PASS" "Performance: ${elapsed}ms for 50 credentials (target: <1000ms)"
    else
        print_result "FAIL" "Performance: ${elapsed}ms for 50 credentials (target: <1000ms)"
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
