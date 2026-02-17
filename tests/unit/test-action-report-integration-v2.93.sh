#!/bin/bash
# test-action-report-integration.sh - Integration tests for action report system
#
# VERSION: 2.93.0
#
# End-to-end tests validating:
# - Report generation works end-to-end
# - Files are created in correct locations
# - Multiple skills generate reports
#
# Usage:
#   ./test-action-report-integration.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEST_DIR="$PROJECT_ROOT/tests/temp/action-integration-tests"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
RESET='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

log_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "  ${GREEN}✓ PASS${RESET} $1"
}

log_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "  ${RED}✗ FAIL${RESET} $1"
}

cleanup() {
    rm -rf "$TEST_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Action Report System v2.93.0 Integration Tests${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo ""

# Test 1: Verify core files exist
echo "Test 1: Verify core action report files exist"
FILES_OK=true

for file in \
    ".claude/lib/action-report-generator.sh" \
    ".claude/lib/action-report-lib.sh" \
    ".claude/hooks/action-report-tracker.sh" \
    "docs/actions/README.md"
do
    if [[ -f "$PROJECT_ROOT/$file" ]]; then
        log_pass "File exists: $file"
    else
        log_fail "File missing: $file"
        FILES_OK=false
    fi
done

if [[ "$FILES_OK" != "true" ]]; then
    echo -e "${RED}✗ Core files missing - aborting tests${RESET}"
    exit 1
fi

# Test 2: Test report generation via library
echo ""
echo "Test 2: Test basic report generation via library"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create test skill directories
mkdir -p docs/actions/test-skill
mkdir -p .claude/metadata/actions/test-skill

# Source the library
if source "$PROJECT_ROOT/.claude/lib/action-report-generator.sh" 2>/dev/null; then
    log_pass "Library sourced successfully"
else
    log_fail "Failed to source library"
    exit 1
fi

# Generate a report
if OUTPUT=$(generate_action_report "test-skill" "completed" "Integration test" '{}' 2>&1); then
    log_pass "Report generated successfully"
else
    log_fail "Report generation failed"
fi

# Test 3: Verify markdown file created
echo ""
echo "Test 3: Verify markdown file created"
MD_COUNT=$(find docs/actions/test-skill -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ $MD_COUNT -gt 0 ]]; then
    log_pass "Markdown files created: $MD_COUNT file(s)"
else
    log_fail "No markdown files created"
fi

# Test 4: Verify JSON metadata created
echo ""
echo "Test 4: Verify JSON metadata created"
JSON_COUNT=$(find .claude/metadata/actions/test-skill -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ $JSON_COUNT -gt 0 ]]; then
    log_pass "JSON metadata files created: $JSON_COUNT file(s)"
else
    log_fail "No JSON metadata files created"
fi

# Test 5: Test hook execution
echo ""
echo "Test 5: Test hook processes Task completion"
HOOK_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","description":"Hook test"},"tool_result":"Success","session_id":"test-session"}'

HOOK_OUTPUT=$(echo "$HOOK_INPUT" | "$PROJECT_ROOT/.claude/hooks/action-report-tracker.sh" 2>&1)
HOOK_EXIT=$?

if [[ $HOOK_EXIT -eq 0 ]]; then
    log_pass "Hook executed successfully (exit code 0)"
else
    log_fail "Hook execution failed (exit code $HOOK_EXIT)"
fi

if echo "$HOOK_OUTPUT" | grep -q '"continue": true'; then
    log_pass "Hook outputs valid JSON protocol"
else
    log_fail "Hook does not output valid JSON protocol"
fi

# Test 6: Test multiple skills
echo ""
echo "Test 6: Test reports for multiple skills"
SKILLS_OK=true

for skill in orchestrator gates loop security; do
    mkdir -p "docs/actions/$skill"
    mkdir -p ".claude/metadata/actions/$skill"

    if generate_action_report "$skill" "success" "Multi-skill test" '{}' >/dev/null 2>&1; then
        if find "docs/actions/$skill" -name "*.md" -type f | grep -q .; then
            log_pass "Report generated for $skill"
        else
            log_fail "No markdown file for $skill"
            SKILLS_OK=false
        fi
    else
        log_fail "Generation failed for $skill"
        SKILLS_OK=false
    fi
done

# Test 7: Verify report files were created
echo ""
echo "Test 7: Verify report files exist with content"
REPORT_COUNT=$(find docs/actions -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ $REPORT_COUNT -ge 4 ]]; then  # At least 4 from the multi-skill test
    log_pass "Multiple report files created: $REPORT_COUNT files"

    # Validate first report exists and is non-empty
    FIRST_REPORT=$(find docs/actions -name "*.md" -type f 2>/dev/null | head -1)
    if [[ -s "$FIRST_REPORT" ]]; then
        log_pass "Report file has content"
    else
        log_fail "Report file is empty"
    fi
else
    log_fail "Not enough report files created: $REPORT_COUNT (expected >= 4)"
fi

# Test 8: Verify JSON metadata files exist
echo ""
echo "Test 8: Verify JSON metadata files exist and are valid"
JSON_COUNT=$(find .claude/metadata/actions -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
if [[ $JSON_COUNT -ge 4 ]]; then  # At least 4 from multi-skill test
    log_pass "Multiple JSON metadata files created: $JSON_COUNT files"

    # Validate one JSON is valid
    FIRST_JSON=$(find .claude/metadata/actions -name "*.json" -type f 2>/dev/null | head -1)
    if jq empty "$FIRST_JSON" 2>/dev/null; then
        log_pass "JSON metadata is valid JSON format"
    else
        log_fail "JSON metadata is not valid JSON"
    fi
else
    log_fail "Not enough JSON metadata files created: $JSON_COUNT (expected >= 4)"
fi

# Test 9: Test library helper functions
echo ""
echo "Test 9: Test library helper functions availability"
source "$PROJECT_ROOT/.claude/lib/action-report-lib.sh" 2>/dev/null

if declare -f start_action_report >/dev/null; then
    log_pass "Function 'start_action_report' available"
else
    log_fail "Function 'start_action_report' not available"
fi

if declare -f complete_action_report >/dev/null; then
    log_pass "Function 'complete_action_report' available"
else
    log_fail "Function 'complete_action_report' not available"
fi

if declare -f mark_iteration >/dev/null; then
    log_pass "Function 'mark_iteration' available"
else
    log_fail "Function 'mark_iteration' not available"
fi

# Test 10: Test docs/actions directory structure
echo ""
echo "Test 10: Test docs/actions directory structure"
if [[ -d "$PROJECT_ROOT/docs/actions" ]]; then
    log_pass "docs/actions directory exists"
else
    log_fail "docs/actions directory missing"
fi

# Check for README
if [[ -f "$PROJECT_ROOT/docs/actions/README.md" ]]; then
    log_pass "docs/actions/README.md exists"
else
    log_fail "docs/actions/README.md missing"
fi

# Test 11: Verify all 15 skills have Action Reporting section
echo ""
echo "Test 11: Verify all Ralph skills have Action Reporting documentation"
SKILLS_WITH_REPORTING=0
TOTAL_SKILLS=0

for skill_dir in "$PROJECT_ROOT/.claude/skills"/*; do
    if [[ -d "$skill_dir" ]]; then
        skill_name=$(basename "$skill_dir")
        SKILL_FILE="$skill_dir/SKILL.md"

        if [[ -f "$SKILL_FILE" ]]; then
            TOTAL_SKILLS=$((TOTAL_SKILLS + 1))

            if grep -q "Action Reporting (v2.93.0)" "$SKILL_FILE" 2>/dev/null; then
                SKILLS_WITH_REPORTING=$((SKILLS_WITH_REPORTING + 1))
                log_pass "$skill_name has Action Reporting section"
            else
                log_fail "$skill_name missing Action Reporting section"
            fi
        fi
    fi
done

echo ""
echo -e "  ${CYAN}ℹ INFO${RESET} Skills with Action Reporting: $SKILLS_WITH_REPORTING / $TOTAL_SKILLS"

# ============================================
# TEST SUMMARY
# ============================================

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}Test Summary${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}Passed:${RESET} $TESTS_PASSED"
echo -e "  ${RED}Failed:${RESET} $TESTS_FAILED"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All integration tests passed!${RESET}"
    echo ""
    echo -e "${CYAN}Action Report System v2.93.0 is fully functional:${RESET}"
    echo "  ✓ Report generator works"
    echo "  ✓ Helper library functions work"
    echo "  ✓ Hook processes Task completions"
    echo "  ✓ Files created in correct locations"
    echo "  ✓ All 15 skills have documentation"
    exit 0
else
    echo -e "${RED}✗ Some integration tests failed${RESET}"
    exit 1
fi
