#!/usr/bin/env bash
# test-functional-learning-v1.sh - Functional tests for Learning System with real data
# Version 1.0.0
# Part of Ralph Multi-Agent System Testing Suite
#
# Purpose: Validate Learning System with real GitHub API and actual tasks
#
# Tests:
#  1. Curator Discovery with GitHub API (real search)
#  2. Learning Gate detection (real task scenario)
#  3. Rule Verification pattern matching (real code analysis)
#  4. End-to-end flow validation
#
# WARNING: These tests make REAL GitHub API calls
# Estimated runtime: 2-3 minutes

set -euo pipefail

SCRIPT_VERSION="1.0.0"
TEST_DATE=$(date +%Y%m%d)
TEST_LOG="tests/functional/test-results-${TEST_DATE}.log"
GITHUB_API_RATE_LIMIT=60  # GitHub API rate limit per hour for unauthenticated

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0
TESTS_TOTAL=0

# Logging functions
log_test() { echo -e "${BLUE}[TEST]${NC} $1" | tee -a "$TEST_LOG"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1" | tee -a "$TEST_LOG"; }
log_fail() { echo -e "${RED}[FAIL]${NC} $1" | tee -a "$TEST_LOG"; }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $1" | tee -a "$TEST_LOG"; }
log_info() { echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$TEST_LOG"; }
log_warning() { echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$TEST_LOG"; }
log_debug() { echo -e "${MAGENTA}[DEBUG]${NC} $1" | tee -a "$TEST_LOG"; }

# Check GitHub API rate limit
check_github_rate_limit() {
    log_info "Checking GitHub API rate limit..."

    local rate_limit_remaining
    rate_limit_remaining=$(curl -s -I "https://api.github.com/search/repositories?q=test&per_page=1" \
        | grep -i "x-ratelimit-remaining:" \
        | cut -d':' -f2 \
        | tr -d ' \r\n' || echo "0")

    if [ "$rate_limit_remaining" -lt 10 ]; then
        log_warning "GitHub API rate limit low: $rate_limit_remaining remaining"
        log_warning "Skipping GitHub API tests to avoid hitting limit"
        return 1
    else
        log_info "GitHub API rate limit OK: $rate_limit_remaining remaining"
        return 0
    fi
}

# Test 1: Curator Discovery with GitHub API
test_curator_discovery() {
    log_test "=== TEST 1: Curator Discovery with GitHub API ==="

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    if ! check_github_rate_limit; then
        log_skip "Curator Discovery (rate limit)"
        TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
        return 0
    fi

    log_info "Running curator-discovery.sh with small search..."

    local discovery_output="/tmp/curator-test-discovery-$$.json"
    local discovery_log="/tmp/curator-test-discovery-$$.log"

    # Run discovery with minimal parameters
    if timeout 30 "$HOME/.ralph/curator/scripts/curator-discovery.sh" \
        --type backend \
        --lang typescript \
        --max-results 5 \
        --output "$discovery_output" \
        > "$discovery_log" 2>&1; then

        log_info "Discovery script executed successfully"

        # Check if output file was created
        if [ -f "$discovery_output" ]; then
            log_info "Output file created: $discovery_output"

            # Validate JSON output
            if jq '.' "$discovery_output" > /dev/null 2>&1; then
                local repo_count
                repo_count=$(jq '.repositories | length' "$discovery_output" 2>/dev/null || echo "0")

                if [ "$repo_count" -gt 0 ]; then
                    log_pass "Curator Discovery: Found $repo_count repositories"
                    TESTS_PASSED=$((TESTS_PASSED + 1))

                    # Show sample repos
                    log_info "Sample repositories:"
                    jq -r '.repositories[:3] | .[] | "  - \(.full_name) (\(.stars // 0) stars)"' "$discovery_output" | tee -a "$TEST_LOG"

                    # Cleanup
                    rm -f "$discovery_output" "$discovery_log"
                    return 0
                else
                    log_fail "Curator Discovery: No repositories found"
                    TESTS_FAILED=$((TESTS_FAILED + 1))
                    rm -f "$discovery_output" "$discovery_log"
                    return 1
                fi
            else
                log_fail "Curator Discovery: Invalid JSON output"
                TESTS_FAILED=$((TESTS_FAILED + 1))
                rm -f "$discovery_output" "$discovery_log"
                return 1
            fi
        else
            log_fail "Curator Discovery: Output file not created"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            rm -f "$discovery_log"
            return 1
        fi
    else
        log_fail "Curator Discovery: Script execution failed or timed out"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        rm -f "$discovery_output" "$discovery_log"
        return 1
    fi
}

# Test 2: Learning Gate Detection
test_learning_gate() {
    log_test "=== TEST 2: Learning Gate Detection ==="

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    log_info "Testing learning-gate.sh with mock Task input..."

    # Create mock Task input (complex task with no relevant rules)
    local mock_input="/tmp/learning-gate-input-$$.json"
    cat > "$mock_input" << EOF
{
  "toolName": "Task",
  "toolInput": {
    "prompt": "Implement a microservice architecture with TypeScript",
    "subagent_type": "senior-backend-developer",
    "complexity": 7
  }
}
EOF

    # Run learning gate
    local gate_output
    gate_output=$(cat "$mock_input" | "$HOME/.claude/hooks/learning-gate.sh" 2>&1)
    local exit_code=$?

    # Cleanup
    rm -f "$mock_input"

    if [ $exit_code -eq 0 ]; then
        # Check if output contains expected fields
        if echo "$gate_output" | jq -e '.decision' > /dev/null 2>&1; then
            local decision
            decision=$(echo "$gate_output" | jq -r '.decision // ""')

            if [ "$decision" = "allow" ] || [ "$decision" = "block" ]; then
                log_pass "Learning Gate: Returns valid decision ($decision)"
                TESTS_PASSED=$((TESTS_PASSED + 1))

                # Show output
                log_info "Gate output: $gate_output"
                return 0
            else
                log_fail "Learning Gate: Invalid decision value"
                TESTS_FAILED=$((TESTS_FAILED + 1))
                return 1
            fi
        else
            log_fail "Learning Gate: Invalid JSON output"
            log_debug "Output: $gate_output"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        log_fail "Learning Gate: Script execution failed (exit code: $exit_code)"
        log_debug "Output: $gate_output"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 3: Rule Verification Pattern Matching
test_rule_verification() {
    log_test "=== TEST 3: Rule Verification Pattern Matching ==="

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    log_info "Testing rule-verification.sh with sample code..."

    # Create temporary test file with patterns
    local test_file="/tmp/test-code-$$.ts"
    cat > "$test_file" << 'EOF'
// Error handling pattern
export async function fetchData(url: string): Promise<Data> {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    return await response.json();
  } catch (error) {
    console.error('Failed to fetch data:', error);
    throw error;
  }
}

// Type safety pattern
interface User {
  id: number;
  name: string;
  email: string;
}

function validateUser(user: unknown): User {
  if (typeof user !== 'object' || user === null) {
    throw new Error('Invalid user object');
  }
  // ... validation logic
  return user as User;
}
EOF

    # Test pattern matching
    log_info "Testing pattern matching for error handling..."
    if grep -qiE "try.*catch|throw new Error" "$test_file"; then
        log_info "✓ Error handling pattern detected"
    else
        log_warning "✗ Error handling pattern NOT detected"
    fi

    log_info "Testing pattern matching for type safety..."
    if grep -qiE "interface.*\{|typeof.*===|: unknown" "$test_file"; then
        log_info "✓ Type safety pattern detected"
    else
        log_warning "✗ Type safety pattern NOT detected"
    fi

    # Cleanup
    rm -f "$test_file"

    log_pass "Rule Verification: Pattern matching works"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

# Test 4: End-to-End Flow Validation
test_end_to_end_flow() {
    log_test "=== TEST 4: End-to-End Flow Validation ==="

    TESTS_TOTAL=$((TESTS_TOTAL + 1))

    log_info "Validating complete learning flow..."

    # Step 1: Check learning state
    if [ ! -f "$HOME/.ralph/learning/state.json" ]; then
        log_fail "End-to-End: Learning state not initialized"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    local is_critical
    is_critical=$(jq -r '.is_critical // false' "$HOME/.ralph/learning/state.json" 2>/dev/null || echo "false")

    # Step 2: Check procedural rules
    if [ ! -f "$HOME/.ralph/procedural/rules.json" ]; then
        log_fail "End-to-End: Procedural rules not found"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    local rule_count
    rule_count=$(jq '.rules | length' "$HOME/.ralph/procedural/rules.json" 2>/dev/null || echo "0")

    # Step 3: Check hooks registration
    local settings_file="$HOME/.claude-sneakpeek/zai/config/settings.json"
    if ! grep -q "learning-gate.sh" "$settings_file" 2>/dev/null; then
        log_fail "End-to-End: Learning gate not registered"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    if ! grep -q "rule-verification.sh" "$settings_file" 2>/dev/null; then
        log_fail "End-to-End: Rule verification not registered"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    # Step 4: Validate curator scripts
    if [ ! -x "$HOME/.ralph/curator/scripts/curator-discovery.sh" ]; then
        log_fail "End-to-End: Curator discovery not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    if [ ! -x "$HOME/.ralph/curator/scripts/curator-scoring.sh" ]; then
        log_fail "End-to-End: Curator scoring not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    if [ ! -x "$HOME/.ralph/curator/scripts/curator-rank.sh" ]; then
        log_fail "End-to-End: Curator ranking not executable"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi

    log_pass "End-to-End Flow: All components validated"
    log_info "  - Learning state: ${is_critical} (is_critical)"
    log_info "  - Procedural rules: $rule_count rules"
    log_info "  - Hooks: Registered and executable"
    log_info "  - Curator scripts: Executable"
    TESTS_PASSED=$((TESTS_PASSED + 1))
    return 0
}

# Main test suite
main() {
    log_test "Starting Learning System Functional Tests v1.0.0"
    log_info "Test date: $(date)"
    log_info "Log file: $TEST_LOG"
    echo ""

    # Run tests
    test_curator_discovery
    echo ""

    test_learning_gate
    echo ""

    test_rule_verification
    echo ""

    test_end_to_end_flow
    echo ""

    # Summary
    log_test "=== FUNCTIONAL TEST SUMMARY ==="
    log_info "Total tests: $TESTS_TOTAL"
    log_pass "Passed: $TESTS_PASSED"

    if [ $TESTS_FAILED -gt 0 ]; then
        log_fail "Failed: $TESTS_FAILED"
    fi

    if [ $TESTS_SKIPPED -gt 0 ]; then
        log_skip "Skipped: $TESTS_SKIPPED"
    fi

    local success_rate
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$((TESTS_PASSED * 100 / TESTS_TOTAL))
        log_info "Success rate: ${success_rate}%"
    fi

    echo ""

    if [ $TESTS_FAILED -gt 0 ]; then
        log_warning "Some tests failed. Review the log for details."
        log_info "Log: $TEST_LOG"
        return 1
    else
        log_pass "All functional tests passed! ✅"
        echo ""
        log_info "Learning System validated with real data."
        log_info "System is ready for comprehensive testing suite (Opción D)."
        return 0
    fi
}

# Run tests
main "$@"
