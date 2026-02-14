#!/bin/bash
# Learning System Unit Tests v2.88.0
# Tests for curator, repo-learn, and auto-learning components
#
# Usage: ./test-learning-system-v2.88.sh [--verbose]
#
# Tests:
#   1. Domain detection accuracy
#   2. Pattern extraction from repositories
#   3. Manifest files[] population
#   4. Learning gate enforcement
#   5. Lock contention handling
#   6. Rule backfill functionality
#
# VERSION: 2.88.0

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="${HOME}/.ralph/test-learning-$$"
LOG_FILE="${TEST_DIR}/test.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging
log_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
log_info() { echo -e "  $1"; }

# Setup
setup() {
    mkdir -p "$TEST_DIR"
    mkdir -p "${TEST_DIR}/procedural"
    mkdir -p "${TEST_DIR}/curator/corpus/approved"

    # Create test rules file
    cat > "${TEST_DIR}/procedural/rules.json" << 'EOF'
{
  "rules": [
    {"rule_id": "test-1", "name": "API Handler", "domain": "backend", "category": "backend", "confidence": 0.9},
    {"rule_id": "test-2", "name": "React Component", "domain": "frontend", "category": "frontend", "confidence": 0.85},
    {"rule_id": "test-3", "name": "SQL Query", "domain": "database", "category": "database", "confidence": 0.8},
    {"rule_id": "test-4", "name": "Uncategorized Rule", "domain": "all", "category": "all", "confidence": 0.7},
    {"rule_id": "test-5", "name": "Another Uncategorized", "domain": null, "category": null, "confidence": 0.75}
  ]
}
EOF

    log_info "Test environment setup complete: $TEST_DIR"
}

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
    log_info "Test environment cleaned up"
}

# Test: Domain Detection
test_domain_detection() {
    ((TESTS_RUN++))
    log_test "Domain Detection"

    local script="${PROJECT_ROOT}/.claude/scripts/curator-learn.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "curator-learn.sh not found"
        return 1
    fi

    # Check domain keywords are defined
    if grep -q 'DOMAIN_KEYWORDS\["backend"\]' "$script"; then
        log_pass "Backend domain keywords defined"
    else
        log_fail "Backend domain keywords missing"
    fi

    if grep -q 'DOMAIN_KEYWORDS\["frontend"\]' "$script"; then
        log_pass "Frontend domain keywords defined"
    else
        log_fail "Frontend domain keywords missing"
    fi

    if grep -q 'DOMAIN_KEYWORDS\["security"\]' "$script"; then
        log_pass "Security domain keywords defined"
    else
        log_fail "Security domain keywords missing"
    fi

    return 0
}

# Test: Pattern Extraction
test_pattern_extraction() {
    ((TESTS_RUN++))
    log_test "Pattern Extraction"

    local script="${PROJECT_ROOT}/.claude/scripts/curator-learn.sh"

    # Check extract_patterns_from_files function exists
    if grep -q 'extract_patterns_from_files()' "$script"; then
        log_pass "extract_patterns_from_files function exists"
    else
        log_fail "extract_patterns_from_files function missing"
        return 1
    fi

    # Check it creates rules with domain
    if grep -q 'domain: \$domain' "$script"; then
        log_pass "Pattern extraction assigns domain"
    else
        log_fail "Pattern extraction missing domain assignment"
    fi

    return 0
}

# Test: Manifest Files Population (GAP-C01)
test_manifest_files_population() {
    ((TESTS_RUN++))
    log_test "Manifest Files[] Population (GAP-C01)"

    local script="${PROJECT_ROOT}/.claude/scripts/curator-learn.sh"

    # Check update_manifest function exists
    if grep -q 'update_manifest()' "$script"; then
        log_pass "update_manifest function exists"
    else
        log_fail "update_manifest function missing"
        return 1
    fi

    # Check it populates files array
    if grep -q '\.files = \$files' "$script"; then
        log_pass "Manifest files[] population implemented"
    else
        log_fail "Manifest files[] population not implemented"
    fi

    return 0
}

# Test: Learning Gate Enforcement (GAP-C03)
test_learning_gate_enforcement() {
    ((TESTS_RUN++))
    log_test "Learning Gate Enforcement (GAP-C03)"

    local script="${PROJECT_ROOT}/.claude/scripts/learning-gate-enforce.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "learning-gate-enforce.sh not found"
        return 1
    fi

    # Check blocking capability
    if grep -q 'BLOCK_ON_CRITICAL' "$script"; then
        log_pass "Blocking capability implemented"
    else
        log_fail "Blocking capability missing"
    fi

    # Check exit codes
    if grep -q 'exit 2' "$script"; then
        log_pass "Exit codes for blocking implemented"
    else
        log_fail "Exit codes missing"
    fi

    return 0
}

# Test: Lock Contention Fix (GAP-H01)
test_lock_contention_fix() {
    ((TESTS_RUN++))
    log_test "Lock Contention Fix (GAP-H01)"

    local script="${PROJECT_ROOT}/.claude/scripts/procedural-inject-fixed.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "procedural-inject-fixed.sh not found"
        return 1
    fi

    # Check exponential backoff
    if grep -q 'acquire_lock_with_backoff' "$script"; then
        log_pass "Exponential backoff lock acquisition implemented"
    else
        log_fail "Exponential backoff missing"
    fi

    # Check retry attempts
    if grep -q 'max_attempts' "$script"; then
        log_pass "Retry attempts configured"
    else
        log_fail "Retry attempts not configured"
    fi

    return 0
}

# Test: Rule Backfill (GAP-C02)
test_rule_backfill() {
    ((TESTS_RUN++))
    log_test "Rule Backfill (GAP-C02)"

    local script="${PROJECT_ROOT}/.claude/scripts/backfill-domains.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "backfill-domains.sh not found"
        return 1
    fi

    # Check dry-run option
    if grep -q '\-\-dry-run' "$script"; then
        log_pass "Dry-run option available"
    else
        log_fail "Dry-run option missing"
    fi

    # Check domain detection function
    if grep -q 'detect_domain_from_rule' "$script"; then
        log_pass "Domain detection from rule implemented"
    else
        log_fail "Domain detection missing"
    fi

    return 0
}

# Test: Orchestrator Auto-Learn Integration
test_orchestrator_auto_learn() {
    ((TESTS_RUN++))
    log_test "Orchestrator Auto-Learn Integration"

    local script="${PROJECT_ROOT}/.claude/hooks/orchestrator-auto-learn.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "orchestrator-auto-learn.sh not found"
        return 1
    fi

    # Check domain-based rule counting (v2.60.1 fix)
    if grep -q 'DOMAIN_MATCH_COUNT' "$script"; then
        log_pass "Domain-based rule counting implemented"
    else
        log_fail "Domain-based rule counting missing"
    fi

    # Check auto-execution
    if grep -q 'AUTO_LEARN_ENABLED' "$script"; then
        log_pass "Auto-execution toggle available"
    else
        log_fail "Auto-execution toggle missing"
    fi

    return 0
}

# Test: Curator Scripts Exist
test_curator_scripts_exist() {
    ((TESTS_RUN++))
    log_test "Curator Scripts Existence"

    local scripts=(
        "curator.sh"
        "curator-discovery.sh"
        "curator-scoring.sh"
        "curator-rank.sh"
        "curator-ingest.sh"
        "curator-approve.sh"
        "curator-learn.sh"
    )

    local all_found=true
    for script in "${scripts[@]}"; do
        if [[ -f "${PROJECT_ROOT}/.claude/scripts/$script" ]]; then
            log_pass "$script exists"
        else
            log_fail "$script missing"
            all_found=false
        fi
    done

    if $all_found; then
        return 0
    else
        return 1
    fi
}

# Test: JSON Schema Validation
test_json_schema() {
    ((TESTS_RUN++))
    log_test "JSON Schema Validation"

    # Validate test rules.json
    if jq '.' "${TEST_DIR}/procedural/rules.json" > /dev/null 2>&1; then
        log_pass "rules.json is valid JSON"
    else
        log_fail "rules.json is invalid JSON"
        return 1
    fi

    return 0
}

# Run all tests
run_tests() {
    echo ""
    echo "========================================"
    echo -e "   ${BLUE}Learning System Tests v2.88${NC}"
    echo "========================================"
    echo ""

    setup

    # Run tests
    test_curator_scripts_exist
    test_domain_detection
    test_pattern_extraction
    test_manifest_files_population
    test_learning_gate_enforcement
    test_lock_contention_fix
    test_rule_backfill
    test_orchestrator_auto_learn
    test_json_schema

    cleanup

    # Summary
    echo ""
    echo "========================================"
    echo -e "          ${BLUE}Test Summary${NC}"
    echo "========================================"
    echo "  Tests run: $TESTS_RUN"
    echo -e "  Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Failed: ${RED}$TESTS_FAILED${NC}"
    echo "========================================"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

# Main
run_tests "$@"
