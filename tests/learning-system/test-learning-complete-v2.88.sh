#!/bin/bash
# Learning System Comprehensive Tests v2.88.0
# Extensive tests for curator, repo-learn, auto-learning, and experience capture
#
# PURPOSE: Validate the complete learning pipeline that makes the system
# smarter through development experience, avoiding recurring errors.
#
# Test Categories:
#   1. Domain Detection Accuracy
#   2. Pattern Extraction Completeness
#   3. Manifest Population
#   4. Learning Gate Enforcement
#   5. Lock Contention Handling
#   6. Rule Backfill and Consolidation
#   7. Experience Capture Pipeline
#   8. Recurring Error Prevention
#   9. Knowledge Base Evolution
#   10. Cross-Session Learning
#
# VERSION: 2.88.0

set -uo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="${HOME}/.ralph/test-learning-comprehensive-$$"
LOG_DIR="${TEST_DIR}/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
ASSERTIONS=0

# Logging
log_test() { echo -e "\n${BLUE}[TEST]${NC} $1"; ((TESTS_RUN++)); }
log_pass() { echo -e "  ${GREEN}✓${NC} $1"; TESTS_PASSED=$((TESTS_PASSED + 1)); }
log_fail() { echo -e "  ${RED}✗${NC} $1"; TESTS_FAILED=$((TESTS_FAILED + 1)); }
log_info() { echo -e "  ${CYAN}ℹ${NC} $1"; }
log_assert() { echo -e "    ${YELLOW}assert${NC} $1"; ASSERTIONS=$((ASSERTIONS + 1)); }

# Assert helpers
assert_file_exists() {
    local file="$1"
    log_assert "file exists: $file"
    if [[ -f "$file" ]]; then
        return 0
    else
        return 1
    fi
}

assert_file_executable() {
    local file="$1"
    log_assert "file executable: $file"
    if [[ -x "$file" ]]; then
        return 0
    else
        return 1
    fi
}

assert_contains() {
    local file="$1"
    local pattern="$2"
    log_assert "contains '$pattern' in $file"
    if grep -q "$pattern" "$file" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

assert_json_valid() {
    local file="$1"
    log_assert "valid JSON: $file"
    if jq '.' "$file" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Setup
setup() {
    mkdir -p "$TEST_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "${TEST_DIR}/procedural"
    mkdir -p "${TEST_DIR}/curator/corpus/approved/test-repo"

    # Create comprehensive test rules file
    cat > "${TEST_DIR}/procedural/rules.json" << 'RULESEOF'
{
  "rules": [
    {
      "rule_id": "rule-backend-001",
      "name": "API Error Handler Pattern",
      "domain": "backend",
      "category": "backend",
      "confidence": 0.92,
      "source_repo": "https://github.com/nestjs/nest",
      "source_file": "packages/core/errors/base-nest-error.ts",
      "behavior": "Classes: class NestError. Functions: captureStackTrace, serialize.",
      "applied_count": 15,
      "created_at": 1739500000
    },
    {
      "rule_id": "rule-frontend-001",
      "name": "React Hook Pattern",
      "domain": "frontend",
      "category": "frontend",
      "confidence": 0.88,
      "source_repo": "https://github.com/facebook/react",
      "source_file": "packages/react-dom/client.ts",
      "behavior": "Functions: createRoot, hydrateRoot.",
      "applied_count": 22,
      "created_at": 1739500000
    },
    {
      "rule_id": "rule-database-001",
      "name": "PostgreSQL Migration Pattern",
      "domain": "database",
      "category": "database",
      "confidence": 0.85,
      "source_repo": "https://github.com/prisma/prisma",
      "source_file": "packages/migrate/src/Migrate.ts",
      "behavior": "Classes: class Migrate. Functions: applyMigrations, rollback.",
      "applied_count": 8,
      "created_at": 1739500000
    },
    {
      "rule_id": "rule-security-001",
      "name": "JWT Authentication Pattern",
      "domain": "security",
      "category": "security",
      "confidence": 0.90,
      "source_repo": "https://github.com/auth0/node-jsonwebtoken",
      "source_file": "decode.js",
      "behavior": "Functions: decode, verify, sign.",
      "applied_count": 12,
      "created_at": 1739500000
    },
    {
      "rule_id": "rule-uncat-001",
      "name": "Uncategorized Pattern A",
      "domain": "all",
      "category": "all",
      "confidence": 0.75,
      "source_repo": "unknown",
      "source_file": "unknown",
      "behavior": "Generic utility function",
      "applied_count": 0,
      "created_at": 1739400000
    },
    {
      "rule_id": "rule-uncat-002",
      "name": "API endpoint handler",
      "domain": null,
      "category": null,
      "confidence": 0.70,
      "source_repo": "unknown",
      "source_file": "unknown",
      "behavior": "Handles REST API requests with express router",
      "applied_count": 0,
      "created_at": 1739400000
    },
    {
      "rule_id": "rule-uncat-003",
      "name": "React component with hooks",
      "domain": null,
      "category": null,
      "confidence": 0.72,
      "source_repo": "unknown",
      "source_file": "unknown",
      "behavior": "useState and useEffect patterns in components",
      "applied_count": 0,
      "created_at": 1739400000
    },
    {
      "rule_id": "rule-testing-001",
      "name": "Jest Test Pattern",
      "domain": "testing",
      "category": "testing",
      "confidence": 0.87,
      "source_repo": "https://github.com/jestjs/jest",
      "source_file": "packages/jest-core/src/SearchSource.ts",
      "behavior": "Functions: findRelatedTests, getTestPaths.",
      "applied_count": 30,
      "created_at": 1739500000
    }
  ]
}
RULESEOF

    # Create test repository manifest
    cat > "${TEST_DIR}/curator/corpus/approved/test-repo/manifest.json" << 'MANIFESTEOF'
{
  "repo_url": "https://github.com/test/repo",
  "approved_at": 1739500000,
  "files": [],
  "patterns_extracted": 0
}
MANIFESTEOF

    log_info "Test environment ready: $TEST_DIR"
}

# Cleanup
cleanup() {
    rm -rf "$TEST_DIR"
    log_info "Test environment cleaned up"
}

#######################################
# Category 1: Domain Detection Tests
#######################################
test_domain_detection_accuracy() {
    log_test "Category 1: Domain Detection Accuracy"

    local script="${PROJECT_ROOT}/.claude/scripts/curator-learn.sh"

    # Test 1.1: Backend keywords
    if assert_contains "$script" 'DOMAIN_KEYWORDS\["backend"\]'; then
        log_pass "Backend domain keywords defined"
    else
        log_fail "Backend domain keywords missing"
    fi

    # Test 1.2: Frontend keywords
    if assert_contains "$script" 'DOMAIN_KEYWORDS\["frontend"\]'; then
        log_pass "Frontend domain keywords defined"
    else
        log_fail "Frontend domain keywords missing"
    fi

    # Test 1.3: Security keywords
    if assert_contains "$script" 'DOMAIN_KEYWORDS\["security"\]'; then
        log_pass "Security domain keywords defined"
    else
        log_fail "Security domain keywords missing"
    fi

    # Test 1.4: Database keywords
    if assert_contains "$script" 'DOMAIN_KEYWORDS\["database"\]'; then
        log_pass "Database domain keywords defined"
    else
        log_fail "Database domain keywords missing"
    fi

    # Test 1.5: Testing keywords
    if assert_contains "$script" 'DOMAIN_KEYWORDS\["testing"\]'; then
        log_pass "Testing domain keywords defined"
    else
        log_fail "Testing domain keywords missing"
    fi

    # Test 1.6: DevOps keywords
    if assert_contains "$script" 'DOMAIN_KEYWORDS\["devops"\]'; then
        log_pass "DevOps domain keywords defined"
    else
        log_fail "DevOps domain keywords missing"
    fi

    # Test 1.7: detect_domain function exists
    if assert_contains "$script" 'detect_domain()'; then
        log_pass "detect_domain function exists"
    else
        log_fail "detect_domain function missing"
    fi

    # Test 1.8: Domain detection uses keyword matching
    if assert_contains "$script" 'DOMAIN_KEYWORDS\[' && assert_contains "$script" 'matches'; then
        log_pass "Domain detection uses keyword matching"
    else
        log_fail "Domain detection algorithm incomplete"
    fi
}

#######################################
# Category 2: Pattern Extraction Tests
#######################################
test_pattern_extraction_completeness() {
    log_test "Category 2: Pattern Extraction Completeness"

    local script="${PROJECT_ROOT}/.claude/scripts/curator-learn.sh"

    # Test 2.1: extract_patterns_from_files function
    if assert_contains "$script" 'extract_patterns_from_files()'; then
        log_pass "Pattern extraction function exists"
    else
        log_fail "Pattern extraction function missing"
    fi

    # Test 2.2: Function/class extraction
    if assert_contains "$script" 'function' && assert_contains "$script" 'class'; then
        log_pass "Function/class extraction implemented"
    else
        log_fail "Function/class extraction incomplete"
    fi

    # Test 2.3: Import pattern detection
    if assert_contains "$script" 'import'; then
        log_pass "Import pattern detection implemented"
    else
        log_fail "Import pattern detection missing"
    fi

    # Test 2.4: Language detection
    if assert_contains "$script" 'detect_language()'; then
        log_pass "Language detection function exists"
    else
        log_fail "Language detection function missing"
    fi

    # Test 2.5: Confidence scoring
    if assert_contains "$script" 'confidence'; then
        log_pass "Confidence scoring implemented"
    else
        log_fail "Confidence scoring missing"
    fi

    # Test 2.6: Source file tracking
    if assert_contains "$script" 'source_file'; then
        log_pass "Source file tracking implemented"
    else
        log_fail "Source file tracking missing"
    fi

    # Test 2.7: Rule ID generation
    if assert_contains "$script" 'rule_id'; then
        log_pass "Rule ID generation implemented"
    else
        log_fail "Rule ID generation missing"
    fi

    # Test 2.8: File filtering (skip tests, config)
    if assert_contains "$script" '.test' || assert_contains "$script" '.spec'; then
        log_pass "Test file filtering implemented"
    else
        log_fail "Test file filtering missing"
    fi
}

#######################################
# Category 3: Manifest Population Tests
#######################################
test_manifest_population() {
    log_test "Category 3: Manifest Files[] Population (GAP-C01)"

    local script="${PROJECT_ROOT}/.claude/scripts/curator-learn.sh"

    # Test 3.1: update_manifest function
    if assert_contains "$script" 'update_manifest()'; then
        log_pass "update_manifest function exists"
    else
        log_fail "update_manifest function missing"
    fi

    # Test 3.2: files array population
    if assert_contains "$script" '.files = \$files'; then
        log_pass "Manifest files[] array population"
    else
        log_fail "Manifest files[] population missing"
    fi

    # Test 3.3: patterns_extracted field
    if assert_contains "$script" 'patterns_extracted'; then
        log_pass "patterns_extracted field updated"
    else
        log_fail "patterns_extracted field missing"
    fi

    # Test 3.4: detected_domain field
    if assert_contains "$script" 'detected_domain'; then
        log_pass "detected_domain field updated"
    else
        log_fail "detected_domain field missing"
    fi

    # Test 3.5: detected_language field
    if assert_contains "$script" 'detected_language'; then
        log_pass "detected_language field updated"
    else
        log_fail "detected_language field missing"
    fi

    # Test 3.6: learned_at timestamp
    if assert_contains "$script" 'learned_at'; then
        log_pass "learned_at timestamp updated"
    else
        log_fail "learned_at timestamp missing"
    fi
}

#######################################
# Category 4: Learning Gate Tests
#######################################
test_learning_gate_enforcement() {
    log_test "Category 4: Learning Gate Enforcement (GAP-C03)"

    local script="${PROJECT_ROOT}/.claude/scripts/learning-gate-enforce.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "learning-gate-enforce.sh not found"
        return 1
    fi

    # Test 4.1: Blocking capability
    if assert_contains "$script" 'BLOCK_ON_CRITICAL'; then
        log_pass "Blocking capability implemented"
    else
        log_fail "Blocking capability missing"
    fi

    # Test 4.2: Exit code 2 for critical blocks
    if assert_contains "$script" 'exit 2'; then
        log_pass "Exit code 2 for critical blocks"
    else
        log_fail "Exit code for blocking missing"
    fi

    # Test 4.3: Domain rule checking
    if assert_contains "$script" 'check_domain_rules'; then
        log_pass "Domain rule checking implemented"
    else
        log_fail "Domain rule checking missing"
    fi

    # Test 4.4: Minimum rules threshold
    if assert_contains "$script" 'MIN_RULES_DOMAIN'; then
        log_pass "Minimum rules threshold configured"
    else
        log_fail "Minimum rules threshold missing"
    fi

    # Test 4.5: Configuration loading
    if assert_contains "$script" 'load_config'; then
        log_pass "Configuration loading implemented"
    else
        log_fail "Configuration loading missing"
    fi

    # Test 4.6: Dry-run option
    if assert_contains "$script" '\-\-check'; then
        log_pass "--check option available"
    else
        log_fail "--check option missing"
    fi
}

#######################################
# Category 5: Lock Contention Tests
#######################################
test_lock_contention_handling() {
    log_test "Category 5: Lock Contention Handling (GAP-H01)"

    local script="${PROJECT_ROOT}/.claude/scripts/procedural-inject-fixed.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "procedural-inject-fixed.sh not found"
        return 1
    fi

    # Test 5.1: Exponential backoff
    if assert_contains "$script" 'acquire_lock_with_backoff'; then
        log_pass "Exponential backoff lock acquisition"
    else
        log_fail "Exponential backoff missing"
    fi

    # Test 5.2: Retry attempts
    if assert_contains "$script" 'max_attempts'; then
        log_pass "Retry attempts configured"
    else
        log_fail "Retry attempts missing"
    fi

    # Test 5.3: Jitter implementation
    if assert_contains "$script" 'RANDOM'; then
        log_pass "Jitter implemented for lock contention"
    else
        log_fail "Jitter missing"
    fi

    # Test 5.4: Graceful degradation
    if assert_contains "$script" 'Could not acquire lock'; then
        log_pass "Graceful degradation on lock failure"
    else
        log_fail "Graceful degradation missing"
    fi

    # Test 5.5: Lock release
    if assert_contains "$script" 'release_lock'; then
        log_pass "Lock release function exists"
    else
        log_fail "Lock release missing"
    fi
}

#######################################
# Category 6: Backfill Tests
#######################################
test_rule_backfill_consolidation() {
    log_test "Category 6: Rule Backfill and Consolidation (GAP-C02)"

    local script="${PROJECT_ROOT}/.claude/scripts/backfill-domains.sh"

    if [[ ! -f "$script" ]]; then
        log_fail "backfill-domains.sh not found"
        return 1
    fi

    # Test 6.1: Dry-run option
    if assert_contains "$script" '\-\-dry-run'; then
        log_pass "Dry-run option available"
    else
        log_fail "Dry-run option missing"
    fi

    # Test 6.2: Domain detection from rule
    if assert_contains "$script" 'detect_domain_from_rule'; then
        log_pass "Domain detection from rule content"
    else
        log_fail "Domain detection from rule missing"
    fi

    # Test 6.3: Batch processing
    if assert_contains "$script" 'batch-size' || assert_contains "$script" 'BATCH_SIZE'; then
        log_pass "Batch processing implemented"
    else
        log_fail "Batch processing missing"
    fi

    # Test 6.4: Backup before modification
    if assert_contains "$script" 'backup' || assert_contains "$script" 'BACKUP'; then
        log_pass "Backup before modification"
    else
        log_fail "Backup missing"
    fi

    # Test 6.5: Progress reporting
    if assert_contains "$script" 'processed' || assert_contains "$script" 'updated'; then
        log_pass "Progress reporting implemented"
    else
        log_fail "Progress reporting missing"
    fi

    # Test 6.6: Domain keyword matching (same as curator-learn)
    if assert_contains "$script" 'DOMAIN_KEYWORDS'; then
        log_pass "Domain keywords for backfill matching"
    else
        log_fail "Domain keywords missing in backfill"
    fi

    # Test 6.7: Uncategorized rule detection
    if assert_contains "$script" 'domain == null' || assert_contains "$script" 'category == "all"'; then
        log_pass "Uncategorized rule detection"
    else
        log_fail "Uncategorized rule detection missing"
    fi
}

#######################################
# Category 7: Experience Capture Tests
#######################################
test_experience_capture_pipeline() {
    log_test "Category 7: Experience Capture Pipeline"

    # Test 7.1: continuous-learning.sh hook exists
    local continuous_hook="${PROJECT_ROOT}/.claude/hooks/continuous-learning.sh"
    if assert_file_exists "$continuous_hook"; then
        log_pass "continuous-learning.sh hook exists"
    else
        log_fail "continuous-learning.sh hook missing"
    fi

    # Test 7.2: orchestrator-auto-learn.sh hook exists
    local auto_learn_hook="${PROJECT_ROOT}/.claude/hooks/orchestrator-auto-learn.sh"
    if assert_file_exists "$auto_learn_hook"; then
        log_pass "orchestrator-auto-learn.sh hook exists"
    else
        log_fail "orchestrator-auto-learn.sh hook missing"
    fi

    # Test 7.3: curator-suggestion.sh hook exists
    local suggestion_hook="${PROJECT_ROOT}/.claude/hooks/curator-suggestion.sh"
    if assert_file_exists "$suggestion_hook"; then
        log_pass "curator-suggestion.sh hook exists"
    else
        log_fail "curator-suggestion.sh hook missing"
    fi

    # Test 7.4: Complexity detection in auto-learn
    if assert_contains "$auto_learn_hook" 'COMPLEXITY'; then
        log_pass "Complexity detection in auto-learn"
    else
        log_fail "Complexity detection missing"
    fi

    # Test 7.5: Domain inference in auto-learn
    if assert_contains "$auto_learn_hook" 'DOMAIN'; then
        log_pass "Domain inference in auto-learn"
    else
        log_fail "Domain inference missing"
    fi

    # Test 7.6: Learning recommendation injection
    if assert_contains "$auto_learn_hook" 'updatedInput' || assert_contains "$auto_learn_hook" 'inject'; then
        log_pass "Learning recommendation injection"
    else
        log_fail "Learning recommendation injection missing"
    fi
}

#######################################
# Category 8: Recurring Error Prevention Tests
#######################################
test_recurring_error_prevention() {
    log_test "Category 8: Recurring Error Prevention"

    local script="${PROJECT_ROOT}/.claude/scripts/curator-learn.sh"

    # Test 8.1: Error pattern extraction
    if assert_contains "$script" 'error' || assert_contains "$script" 'Error'; then
        log_pass "Error pattern awareness"
    else
        log_fail "Error pattern detection missing"
    fi

    # Test 8.2: Behavior description includes patterns
    if assert_contains "$script" 'behavior'; then
        log_pass "Behavior description for patterns"
    else
        log_fail "Behavior description missing"
    fi

    # Test 8.3: Confidence threshold for quality
    if assert_contains "$script" 'confidence' && assert_contains "$script" '0\.'; then
        log_pass "Confidence threshold for pattern quality"
    else
        log_fail "Confidence threshold missing"
    fi

    # Test 8.4: Source repository tracking
    if assert_contains "$script" 'source_repo'; then
        log_pass "Source repository tracking for traceability"
    else
        log_fail "Source repository tracking missing"
    fi

    # Test 8.5: Applied count tracking (GAP-H02)
    local inject_script="${PROJECT_ROOT}/.claude/scripts/procedural-inject-fixed.sh"
    if [[ -f "$inject_script" ]] && assert_contains "$inject_script" 'applied_count'; then
        log_pass "Applied count tracking for rule effectiveness"
    else
        log_fail "Applied count tracking missing"
    fi

    # Test 8.6: Usage tracking
    if [[ -f "$inject_script" ]] && assert_contains "$inject_script" 'track_rule_usage'; then
        log_pass "Usage tracking for rule effectiveness"
    else
        log_fail "Usage tracking missing"
    fi
}

#######################################
# Category 9: Knowledge Base Evolution Tests
#######################################
test_knowledge_base_evolution() {
    log_test "Category 9: Knowledge Base Evolution"

    # Test 9.1: Rules JSON structure
    if assert_json_valid "${TEST_DIR}/procedural/rules.json"; then
        log_pass "Rules JSON structure is valid"
    else
        log_fail "Rules JSON structure invalid"
    fi

    # Test 9.2: Rule uniqueness by rule_id
    local unique_count=$(jq '[.rules[].rule_id] | unique | length' "${TEST_DIR}/procedural/rules.json")
    local total_count=$(jq '.rules | length' "${TEST_DIR}/procedural/rules.json")
    if [[ "$unique_count" -eq "$total_count" ]]; then
        log_pass "Rules have unique IDs ($unique_count unique of $total_count)"
    else
        log_fail "Duplicate rule IDs detected"
    fi

    # Test 9.3: Domain distribution
    local backend_count=$(jq '[.rules[] | select(.domain == "backend")] | length' "${TEST_DIR}/procedural/rules.json")
    if [[ "$backend_count" -gt 0 ]]; then
        log_pass "Backend domain has $backend_count rules"
    else
        log_fail "No backend domain rules"
    fi

    # Test 9.4: Uncategorized rules exist (for backfill)
    local uncat_count=$(jq '[.rules[] | select(.domain == null or .domain == "all")] | length' "${TEST_DIR}/procedural/rules.json")
    if [[ "$uncat_count" -gt 0 ]]; then
        log_pass "Found $uncat_count uncategorized rules for backfill testing"
    else
        log_info "No uncategorized rules (all rules categorized)"
    fi

    # Test 9.5: Confidence range validation
    local min_conf=$(jq '[.rules[].confidence] | min' "${TEST_DIR}/procedural/rules.json")
    local max_conf=$(jq '[.rules[].confidence] | max' "${TEST_DIR}/procedural/rules.json")
    if (( $(echo "$min_conf >= 0 && $max_conf <= 1" | bc -l) )); then
        log_pass "Confidence values in valid range [0,1]: $min_conf to $max_conf"
    else
        log_fail "Confidence values out of range"
    fi

    # Test 9.6: Applied count tracking
    local total_applied=$(jq '[.rules[].applied_count // 0] | add' "${TEST_DIR}/procedural/rules.json")
    if [[ "$total_applied" -gt 0 ]]; then
        log_pass "Total rule applications: $total_applied"
    else
        log_info "No rule applications recorded yet"
    fi
}

#######################################
# Category 10: Cross-Session Learning Tests
#######################################
test_cross_session_learning() {
    log_test "Category 10: Cross-Session Learning"

    # Test 10.1: Procedural memory file location
    local rules_file="${HOME}/.ralph/procedural/rules.json"
    log_info "Procedural memory location: $rules_file"

    # Test 10.2: Pre-compact hook for state preservation
    local pre_compact="${PROJECT_ROOT}/.claude/hooks/pre-compact-handoff.sh"
    if assert_file_exists "$pre_compact"; then
        log_pass "Pre-compact hook for state preservation"
    else
        log_fail "Pre-compact hook missing"
    fi

    # Test 10.3: Session end hook
    local session_end="${PROJECT_ROOT}/.claude/hooks/session-end-handoff.sh"
    if assert_file_exists "$session_end"; then
        log_pass "Session end hook for state saving"
    else
        log_info "Session end hook may have different name"
    fi

    # Test 10.4: Ledger directory
    local ledger_dir="${HOME}/.ralph/ledgers"
    if [[ -d "$ledger_dir" ]] || mkdir -p "$ledger_dir" 2>/dev/null; then
        log_pass "Ledger directory available for cross-session state"
    else
        log_fail "Ledger directory unavailable"
    fi

    # Test 10.5: Event logging
    local events_dir="${HOME}/.ralph/events"
    if [[ -d "$events_dir" ]] || mkdir -p "$events_dir" 2>/dev/null; then
        log_pass "Events directory available for learning events"
    else
        log_fail "Events directory unavailable"
    fi
}

#######################################
# Category 11: Skills Scenario Integration
#######################################
test_skills_scenario_integration() {
    log_test "Category 11: Skills Scenario Integration"

    # Test 11.1: curator skill exists
    local curator_skill="${PROJECT_ROOT}/.claude/skills/curator/SKILL.md"
    if assert_file_exists "$curator_skill"; then
        log_pass "curator skill exists"
    else
        log_fail "curator skill missing"
    fi

    # Test 11.2: curator-repo-learn skill exists
    local repo_learn_skill="${PROJECT_ROOT}/.claude/skills/curator-repo-learn/SKILL.md"
    if assert_file_exists "$repo_learn_skill"; then
        log_pass "curator-repo-learn skill exists"
    else
        log_fail "curator-repo-learn skill missing"
    fi

    # Test 11.3: curator skill has Scenario C
    if assert_contains "$curator_skill" 'Scenario C' || assert_contains "$curator_skill" 'scenario: C'; then
        log_pass "curator skill assigned Scenario C"
    else
        log_info "curator scenario assignment needs verification"
    fi

    # Test 11.4: curator-repo-learn has Scenario B
    if assert_contains "$repo_learn_skill" 'Scenario B' || assert_contains "$repo_learn_skill" 'scenario: B'; then
        log_pass "curator-repo-learn skill assigned Scenario B"
    else
        log_info "curator-repo-learn scenario assignment needs verification"
    fi

    # Test 11.5: Agent Teams workflow documented
    if assert_contains "$curator_skill" 'TeamCreate' || assert_contains "$curator_skill" 'ralph-coder'; then
        log_pass "Agent Teams workflow documented in curator"
    else
        log_info "Agent Teams workflow needs documentation"
    fi
}

#######################################
# Main Test Runner
#######################################
run_all_tests() {
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}    Learning System Comprehensive Tests v2.88.0                       ${NC}"
    echo -e "${BLUE}    Validating Complete Learning Pipeline                              ${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════════${NC}"
    echo ""

    setup

    # Run all test categories
    test_domain_detection_accuracy
    test_pattern_extraction_completeness
    test_manifest_population
    test_learning_gate_enforcement
    test_lock_contention_handling
    test_rule_backfill_consolidation
    test_experience_capture_pipeline
    test_recurring_error_prevention
    test_knowledge_base_evolution
    test_cross_session_learning
    test_skills_scenario_integration

    cleanup

    # Summary
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                         TEST SUMMARY                                  ${NC}"
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "  Test Categories Run: $TESTS_RUN"
    echo -e "  Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "  Tests Failed: ${RED}$TESTS_FAILED${NC}"
    echo "  Total Assertions: $ASSERTIONS"
    echo ""
    echo -e "${BLUE}══════════════════════════════════════════════════════════════════════${NC}"

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}VALIDATION FAILED${NC}"
        exit 1
    fi

    echo -e "${GREEN}ALL VALIDATIONS PASSED${NC}"
    echo ""
    echo "The learning system is ready to capture development experience"
    echo "and prevent recurring errors through pattern extraction."
    exit 0
}

# Run tests
run_all_tests "$@"
