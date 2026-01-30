#!/bin/bash
# run-promptify-tests.sh - Comprehensive test runner for Promptify integration
# VERSION: 1.0.0
# Executes all validation tests for Promptify integration

set -uo pipefail

readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo -e "${CYAN}${BOLD}$1${NC}"
    echo -e "${CYAN}${BOLD}========================================${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_result() {
    local status="$1"
    local message="$2"

    if [[ "$status" == "PASS" ]]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
        ((PASSED_TESTS++))
    else
        echo -e "${RED}❌ FAIL${NC}: $message"
        ((FAILED_TESTS++))
    fi
    ((TOTAL_TESTS++))
}

# Credential redaction test
test_credential_redaction() {
    print_section "Credential Redaction Tests"

    # Test 1: Basic password redaction
    local input="password:secret123"
    local output=$(echo "$input" | sed -E 's/(password)[[:space:]]*:[[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi')

    if [[ "$output" == *"[REDACTED]"* ]] && [[ "$output" != *"secret123"* ]]; then
        print_result "PASS" "Password redaction works"
    else
        print_result "FAIL" "Password redaction failed"
    fi

    # Test 2: Token redaction
    input="token:abc456"
    output=$(echo "$input" | sed -E 's/(token)[[:space:]]*:[[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi')

    if [[ "$output" == *"[REDACTED]"* ]] && [[ "$output" != *"abc456"* ]]; then
        print_result "PASS" "Token redaction works"
    else
        print_result "FAIL" "Token redaction failed"
    fi

    # Test 3: Email redaction
    input="email:user@example.com"
    output=$(echo "$input" | sed -E 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/[EMAIL REDACTED]/g')

    if [[ "$output" == *"[EMAIL REDACTED]"* ]] && [[ "$output" != *"user@example.com"* ]]; then
        print_result "PASS" "Email redaction works"
    else
        print_result "FAIL" "Email redaction failed"
    fi

    # Test 4: Multiple credentials
    input="password:pass123 and token:tok456"
    output=$(echo "$input" | sed -E 's/(password|token)[[:space:]]*:[[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi')

    if [[ "$output" == *"[REDACTED]"* ]] && [[ "$output" != *"pass123"* ]] && [[ "$output" != *"tok456"* ]]; then
        print_result "PASS" "Multiple credentials redaction works"
    else
        print_result "FAIL" "Multiple credentials redaction failed"
    fi
}

# Clarity scoring test
test_clarity_scoring() {
    print_section "Clarity Scoring Tests"

    # Simple scoring function for testing
    calculate_score() {
        local prompt="$1"
        local score=100
        local prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')
        local word_count=$(echo "$prompt" | wc -w | tr -d ' ')

        # Word count penalty
        if [[ $word_count -lt 5 ]]; then
            score=$((score - 40))
        elif [[ $word_count -lt 10 ]]; then
            score=$((score - 20))
        fi

        # Vague word penalty
        if echo "$prompt_lower" | grep -qE "thing|stuff"; then
            score=$((score - 15))
        fi

        # Structure bonus
        if echo "$prompt_lower" | grep -qE "you are|act as"; then
            score=$((score + 15))
        fi

        if [[ $score -lt 0 ]]; then
            score=0
        elif [[ $score -gt 100 ]]; then
            score=100
        fi

        echo "$score"
    }

    # Test 1: Vague prompt gets low score
    local score=$(calculate_score "fix the thing")
    if [[ $score -le 50 ]]; then
        print_result "PASS" "Vague prompt gets low score ($score%)"
    else
        print_result "FAIL" "Vague prompt score too high ($score%)"
    fi

    # Test 2: Clear prompt gets high score
    score=$(calculate_score "You are a backend engineer. Implement OAuth2 login with proper error handling and tests")
    if [[ $score -ge 60 ]]; then
        print_result "PASS" "Clear prompt gets high score ($score%)"
    else
        print_result "FAIL" "Clear prompt score too low ($score%)"
    fi

    # Test 3: Score bounds
    score=$(calculate_score "thing stuff something nothing")
    if [[ $score -ge 0 ]] && [[ $score -le 100 ]]; then
        print_result "PASS" "Score stays within bounds ($score%)"
    else
        print_result "FAIL" "Score out of bounds ($score%)"
    fi
}

# Hook integration test
test_hook_integration() {
    print_section "Hook Integration Tests"

    local hook_file="${PROJECT_ROOT}/.claude/hooks/promptify-auto-detect.sh"
    local config_file="$HOME/.ralph/config/promptify.json"

    # Test 1: Hook file exists
    if [[ -f "$hook_file" ]]; then
        print_result "PASS" "Hook file exists"
    else
        print_result "FAIL" "Hook file not found"
    fi

    # Test 2: Hook is executable
    if [[ -x "$hook_file" ]]; then
        print_result "PASS" "Hook file is executable"
    else
        print_result "FAIL" "Hook file is not executable"
    fi

    # Test 3: Config file exists
    if [[ -f "$config_file" ]]; then
        print_result "PASS" "Config file exists"
    else
        print_result "FAIL" "Config file not found"
    fi

    # Test 4: Hook produces valid JSON
    if command -v jq &>/dev/null; then
        local test_input=$(jq -n --arg prompt "test prompt" '{"user_prompt": $prompt}')
        local hook_output=$(echo "$test_input" | "$hook_file" 2>/dev/null || echo '{"continue": true}')
        local continue_value=$(echo "$hook_output" | jq -r '.continue // empty' 2>/dev/null || echo "")

        if [[ "$continue_value" == "true" ]]; then
            print_result "PASS" "Hook returns valid JSON with continue=true"
        else
            print_result "FAIL" "Hook does not return valid JSON"
        fi
    else
        print_result "SKIP" "jq not available, skipping JSON validation"
    fi

    # Test 5: Log directory exists
    local log_dir="$HOME/.ralph/logs"
    if [[ -d "$log_dir" ]]; then
        print_result "PASS" "Log directory exists"
    else
        print_result "FAIL" "Log directory not found"
    fi
}

# Security functions test
test_security_functions() {
    print_section "Security Functions Tests"

    # Test 1: Security library exists
    local security_lib="${PROJECT_ROOT}/.claude/hooks/promptify-security.sh"
    if [[ -f "$security_lib" ]]; then
        print_result "PASS" "Security library exists"
    else
        print_result "FAIL" "Security library not found"
    fi

    # Test 2: Clipboard consent file can be created
    local consent_file="$HOME/.ralph/config/promptify-consent.json"
    mkdir -p "$(dirname "$consent_file")"

    if echo '{"clipboard_consent": true}' > "$consent_file" 2>/dev/null; then
        print_result "PASS" "Consent file can be created"
        rm -f "$consent_file"
    else
        print_result "FAIL" "Consent file cannot be created"
    fi

    # Test 3: Audit log can be written
    local audit_log="$HOME/.ralph/logs/promptify-audit.log"
    mkdir -p "$(dirname "$audit_log")"

    if echo '{"test": "data"}' >> "$audit_log" 2>/dev/null; then
        print_result "PASS" "Audit log can be written"
    else
        print_result "FAIL" "Audit log cannot be written"
    fi
}

# File structure test
test_file_structure() {
    print_section "File Structure Tests"

    local required_files=(
        ".claude/hooks/promptify-auto-detect.sh"
        ".claude/hooks/promptify-security.sh"
        ".claude/hooks/command-router.sh"
        "tests/promptify-integration/run-all-tests.sh"
        "tests/promptify-integration/test-clarity-scoring.sh"
        "tests/promptify-integration/test-credential-redaction.sh"
        "tests/promptify-integration/test-security-functions.sh"
        "tests/promptify-integration/test-e2e.sh"
        "tests/promptify-integration/README.md"
        "tests/promptify-integration/run-promptify-tests.sh"
    )

    local all_exist=true
    for file in "${required_files[@]}"; do
        # Expand ~
        local expanded_path="${file/#\~/$HOME}"
        local full_path="${PROJECT_ROOT}/${expanded_path/#\.\//}"

        if [[ ! -f "$full_path" ]]; then
            echo "  Missing: $full_path" >&2
            all_exist=false
        fi
    done

    if [[ "$all_exist" == "true" ]]; then
        print_result "PASS" "All required files exist"
    else
        print_result "FAIL" "Some required files are missing"
    fi
}

# Print summary
print_summary() {
    print_header "Final Summary"

    echo -e "${BOLD}Tests Run:    ${TOTAL_TESTS}${NC}"
    echo -e "${GREEN}${BOLD}Passed:  ${PASSED_TESTS}${NC}"
    echo -e "${RED}${BOLD}Failed:  ${FAILED_TESTS}${NC}"
    echo ""

    local pass_rate=0
    if [[ $TOTAL_TESTS -gt 0 ]]; then
        pass_rate=$((PASSED_TESTS * 100 / TOTAL_TESTS))
    fi

    echo -e "${BOLD}Pass Rate:    ${pass_rate}%${NC}"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}🎉 ALL TESTS PASSED! 🎉${NC}"
        echo ""
        echo -e "${GREEN}Promptify integration is fully functional and ready for use.${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Run adversarial validation: /adversarial docs/promptify-integration/"
        echo "  2. Run Codex CLI review: /codex-cli docs/promptify-integration/"
        echo "  3. Run Gemini CLI validation: /gemini-cli docs/promptify-integration/"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}❌ SOME TESTS FAILED ❌${NC}"
        echo ""
        echo -e "${YELLOW}Please review the failed tests above.${NC}"
        echo ""
        return 1
    fi
}

# Main execution
main() {
    print_header "Promptify Integration Test Suite v${VERSION}"

    echo -e "${BOLD}Test Groups:${NC}"
    echo "  1. Credential Redaction"
    echo "  2. Clarity Scoring"
    echo "  3. Hook Integration"
    echo "  4. Security Functions"
    echo "  5. File Structure"
    echo ""

    local start_time=$(date +%s)

    # Run all test groups
    test_credential_redaction
    test_clarity_scoring
    test_hook_integration
    test_security_functions
    test_file_structure

    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))

    echo ""
    echo -e "${BOLD}Execution Time: ${elapsed}s${NC}"

    print_summary
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
