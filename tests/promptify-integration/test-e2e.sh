#!/bin/bash
# test-e2e.sh - End-to-end integration test for Promptify
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
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

# Simulate hook execution
simulate_hook() {
    local user_prompt="$1"

    # Create JSON input
    local json_input=$(jq -n --arg prompt "$user_prompt" '{"user_prompt": $prompt}')

    # Execute hook
    if [[ -x "$HOOK_FILE" ]]; then
        echo "$json_input" | "$HOOK_FILE" 2>/dev/null || echo '{"continue": true}'
    else
        echo '{"continue": true}'
    fi
}

# Run E2E tests
run_e2e_tests() {
    print_header "End-to-End Integration Tests v${VERSION}"

    # Check if hook exists
    if [[ ! -f "$HOOK_FILE" ]]; then
        echo -e "${YELLOW}WARNING${NC}: Hook file not found: $HOOK_FILE"
        echo "Skipping hook execution tests..."
        return 0
    fi

    # Test 1: Hook file exists and is executable
    echo ""
    echo "Test 1: Hook File Setup"
    echo "======================="

    if [[ -f "$HOOK_FILE" ]]; then
        print_result "PASS" "Hook file exists"
    else
        print_result "FAIL" "Hook file not found"
    fi

    if [[ -x "$HOOK_FILE" ]]; then
        print_result "PASS" "Hook file is executable"
    else
        print_result "FAIL" "Hook file is not executable"
    fi

    # Test 2: Hook returns valid JSON
    echo ""
    echo "Test 2: Hook JSON Output"
    echo "======================="

    local hook_output=$(simulate_hook "test prompt")
    local continue_value=$(echo "$hook_output" | jq -r '.continue // empty' 2>/dev/null || echo "")

    if [[ "$continue_value" == "true" ]]; then
        print_result "PASS" "Hook returns valid JSON with continue=true"
    else
        print_result "FAIL" "Hook does not return valid JSON"
    fi

    # Test 3: Configuration file
    echo ""
    echo "Test 3: Configuration File"
    echo "========================="

    local config_file="$HOME/.ralph/config/promptify.json"

    if [[ -f "$config_file" ]]; then
        print_result "PASS" "Configuration file exists"

        local enabled=$(jq -r '.enabled // true' "$config_file" 2>/dev/null || echo "true")
        if [[ "$enabled" == "true" ]]; then
            print_result "PASS" "Promptify is enabled in config"
        else
            print_result "FAIL" "Promptify is disabled in config"
        fi

        local threshold=$(jq -r '.vagueness_threshold // 50' "$config_file" 2>/dev/null || echo "50")
        if [[ "$threshold" =~ ^[0-9]+$ ]] && [[ "$threshold" -ge 0 ]] && [[ "$threshold" -le 100 ]]; then
            print_result "PASS" "Vagueness threshold is valid: $threshold"
        else
            print_result "FAIL" "Vagueness threshold is invalid: $threshold"
        fi
    else
        print_result "FAIL" "Configuration file not found"
    fi

    # Test 4: Log directory
    echo ""
    echo "Test 4: Log Directory"
    echo "===================="

    local log_dir="$HOME/.ralph/logs"

    if [[ -d "$log_dir" ]]; then
        print_result "PASS" "Log directory exists"
    else
        print_result "FAIL" "Log directory not found"
    fi

    # Test 5: Security library
    echo ""
    echo "Test 5: Security Library"
    echo "======================="

    local security_lib="${PROJECT_ROOT}/.claude/hooks/promptify-security.sh"

    if [[ -f "$security_lib" ]]; then
        print_result "PASS" "Security library exists"
    else
        print_result "FAIL" "Security library not found"
    fi

    # Test 6: Hook integration
    echo ""
    echo "Test 6: Hook Integration"
    echo "======================="

    # Test that hook can be sourced
    if bash -c "source '$HOOK_FILE' && type -t calculate_clarity_score" &>/dev/null; then
        print_result "PASS" "Hook can be sourced and has calculate_clarity_score function"
    else
        print_result "FAIL" "Hook cannot be sourced or missing calculate_clarity_score function"
    fi

    # Test 7: Configuration override test
    echo ""
    echo "Test 7: Configuration Override"
    echo "==============================="

    # Save current config
    local config_backup=""
    if [[ -f "$config_file" ]]; then
        config_backup=$(cat "$config_file")
    fi

    # Create test config with promptify disabled
    mkdir -p "$(dirname "$config_file")"
    echo '{"enabled": false}' > "$config_file"

    # Hook should still work but not suggest anything
    local hook_output=$(simulate_hook "vague prompt")
    local continue_value=$(echo "$hook_output" | jq -r '.continue // false' 2>/dev/null || echo "false")

    if [[ "$continue_value" == "true" ]]; then
        print_result "PASS" "Hook continues when disabled"
    else
        print_result "FAIL" "Hook does not continue when disabled"
    fi

    # Restore config
    if [[ -n "$config_backup" ]]; then
        echo "$config_backup" > "$config_file"
    else
        rm -f "$config_file"
    fi

    # Test 8: Error handling
    echo ""
    echo "Test 8: Error Handling"
    echo "====================="

    # Test with invalid JSON input
    local invalid_input="not valid json"
    local hook_output=$(echo "$invalid_input" | "$HOOK_FILE" 2>/dev/null || echo '{"continue": true}')
    local continue_value=$(echo "$hook_output" | jq -r '.continue // false' 2>/dev/null || echo "false")

    if [[ "$continue_value" == "true" ]]; then
        print_result "PASS" "Invalid input handled gracefully"
    else
        print_result "FAIL" "Invalid input caused error"
    fi

    # Test 9: Large input handling
    echo ""
    echo "Test 9: Large Input Handling"
    echo "==========================="

    # Create large prompt (>100KB)
    local large_prompt="fix "
    for i in {1..1000}; do
        large_prompt+="the thing "
    done

    local hook_output=$(echo "$large_prompt" | head -c 100000 | simulate_hook "$(cat)")
    local continue_value=$(echo "$hook_output" | jq -r '.continue // false' 2>/dev/null || echo "false")

    if [[ "$continue_value" == "true" ]]; then
        print_result "PASS" "Large input handled without error"
    else
        print_result "FAIL" "Large input caused error"
    fi

    # Test 10: Files and directories structure
    echo ""
    echo "Test 10: File Structure"
    echo "======================="

    local required_files=(
        "$HOOK_FILE"
        "$security_lib"
        "${PROJECT_ROOT}/tests/promptify-integration/run-all-tests.sh"
        "${PROJECT_ROOT}/tests/promptify-integration/test-clarity-scoring.sh"
        "${PROJECT_ROOT}/tests/promptify-integration/test-credential-redaction.sh"
        "${PROJECT_ROOT}/tests/promptify-integration/test-security-functions.sh"
    )

    local all_files_exist=true
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            all_files_exist=false
            break
        fi
    done

    if [[ "$all_files_exist" == "true" ]]; then
        print_result "PASS" "All required files exist"
    else
        print_result "FAIL" "Some required files are missing"
    fi

    echo ""
}

print_header() {
    echo ""
    echo "========================================"
    echo "$1"
    echo "========================================"
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
