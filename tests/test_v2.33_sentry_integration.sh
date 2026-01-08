#!/usr/bin/env bash
# v2.33 Test Suite - Sentry Observability Integration
# Tests Sentry skills integration, CLI commands, hooks, and enhanced skills

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
TOTAL=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
    ((TOTAL++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
    ((TOTAL++))
}

# ============================================================================
# Test Group 1: Version and Documentation
# ============================================================================

echo ""
echo "=== Group 1: Version and Documentation ==="

# Test 1: CLAUDE.md references v2.33
test_claude_md_version() {
    if grep -q "# Multi-Agent Ralph v2.33" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md title is v2.33"
    else
        test_fail "CLAUDE.md should have title v2.33"
    fi
}
test_claude_md_version

# Test 2: CLAUDE.md has v2.33 Sentry section
test_claude_md_sentry() {
    if grep -q "## v2.33 Key Changes (Sentry Observability Integration)" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md has v2.33 Sentry section"
    else
        test_fail "CLAUDE.md should have v2.33 Sentry section"
    fi
}
test_claude_md_sentry

# Test 3: CHANGELOG.md has v2.33 entry
test_changelog_version() {
    if grep -q "## \[2.33.0\]" "$PROJECT_ROOT/CHANGELOG.md"; then
        test_pass "CHANGELOG.md has v2.33.0 entry"
    else
        test_fail "CHANGELOG.md should have v2.33.0 entry"
    fi
}
test_changelog_version

# Test 4: CHANGELOG.md mentions Sentry integration
test_changelog_sentry() {
    if grep -q "Sentry Observability Integration" "$PROJECT_ROOT/CHANGELOG.md"; then
        test_pass "CHANGELOG.md mentions Sentry integration"
    else
        test_fail "CHANGELOG.md should mention Sentry integration"
    fi
}
test_changelog_sentry

# ============================================================================
# Test Group 2: CLI Commands
# ============================================================================

echo ""
echo "=== Group 2: CLI Commands ==="

# Test 5: cmd_sentry_init function exists
test_sentry_init_function() {
    if grep -q "cmd_sentry_init()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "cmd_sentry_init() function exists in ralph"
    else
        test_fail "cmd_sentry_init() function should exist in ralph"
    fi
}
test_sentry_init_function

# Test 6: cmd_sentry_validate function exists
test_sentry_validate_function() {
    if grep -q "cmd_sentry_validate()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "cmd_sentry_validate() function exists in ralph"
    else
        test_fail "cmd_sentry_validate() function should exist in ralph"
    fi
}
test_sentry_validate_function

# Test 7: cmd_code_review_sentry function exists
test_code_review_sentry_function() {
    if grep -q "cmd_code_review_sentry()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "cmd_code_review_sentry() function exists in ralph"
    else
        test_fail "cmd_code_review_sentry() function should exist in ralph"
    fi
}
test_code_review_sentry_function

# Test 8: sentry-init dispatcher case exists
test_sentry_init_dispatcher() {
    if grep -q "sentry-init|sentry_init)" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "sentry-init dispatcher case exists"
    else
        test_fail "sentry-init dispatcher case should exist"
    fi
}
test_sentry_init_dispatcher

# Test 9: sentry-validate dispatcher case exists
test_sentry_validate_dispatcher() {
    if grep -q "sentry-validate|sentry_validate)" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "sentry-validate dispatcher case exists"
    else
        test_fail "sentry-validate dispatcher case should exist"
    fi
}
test_sentry_validate_dispatcher

# Test 10: code-review-sentry dispatcher case exists
test_code_review_sentry_dispatcher() {
    if grep -q "code-review-sentry|code_review_sentry)" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "code-review-sentry dispatcher case exists"
    else
        test_fail "code-review-sentry dispatcher case should exist"
    fi
}
test_code_review_sentry_dispatcher

# Test 11: sentry-init detects project types
test_sentry_init_project_detection() {
    if grep -q 'if \[\[ -f "package.json" \]\]; then' "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "sentry-init detects Node.js projects"
    else
        test_fail "sentry-init should detect Node.js projects"
    fi
}
test_sentry_init_project_detection

# Test 12: sentry-validate checks DSN
test_sentry_validate_dsn() {
    if grep -q 'if \[\[ -z "$SENTRY_DSN" \]\]; then' "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "sentry-validate checks SENTRY_DSN"
    else
        test_fail "sentry-validate should check SENTRY_DSN"
    fi
}
test_sentry_validate_dsn

# Test 13: sentry-validate checks sample rates
test_sentry_validate_sample_rates() {
    if grep -q "tracesSampleRate" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "sentry-validate checks for 100% sample rates"
    else
        test_fail "sentry-validate should check for 100% sample rates"
    fi
}
test_sentry_validate_sample_rates

# ============================================================================
# Test Group 3: Hooks
# ============================================================================

echo ""
echo "=== Group 3: Hooks ==="

# Test 14: sentry-check-status.sh exists
test_sentry_check_status_hook() {
    if [ -f "$HOME/.claude/hooks/sentry-check-status.sh" ]; then
        test_pass "sentry-check-status.sh hook exists"
    else
        test_fail "sentry-check-status.sh hook should exist"
    fi
}
test_sentry_check_status_hook

# Test 15: sentry-check-status.sh is executable
test_sentry_check_status_executable() {
    if [ -x "$HOME/.claude/hooks/sentry-check-status.sh" ]; then
        test_pass "sentry-check-status.sh is executable"
    else
        test_fail "sentry-check-status.sh should be executable"
    fi
}
test_sentry_check_status_executable

# Test 16: sentry-correlation.sh exists
test_sentry_correlation_hook() {
    if [ -f "$HOME/.claude/hooks/sentry-correlation.sh" ]; then
        test_pass "sentry-correlation.sh hook exists"
    else
        test_fail "sentry-correlation.sh hook should exist"
    fi
}
test_sentry_correlation_hook

# Test 17: sentry-correlation.sh is executable
test_sentry_correlation_executable() {
    if [ -x "$HOME/.claude/hooks/sentry-correlation.sh" ]; then
        test_pass "sentry-correlation.sh is executable"
    else
        test_fail "sentry-correlation.sh should be executable"
    fi
}
test_sentry_correlation_executable

# Test 18: sentry-report.sh exists
test_sentry_report_hook() {
    if [ -f "$HOME/.claude/hooks/sentry-report.sh" ]; then
        test_pass "sentry-report.sh hook exists"
    else
        test_fail "sentry-report.sh hook should exist"
    fi
}
test_sentry_report_hook

# Test 19: sentry-report.sh is executable
test_sentry_report_executable() {
    if [ -x "$HOME/.claude/hooks/sentry-report.sh" ]; then
        test_pass "sentry-report.sh is executable"
    else
        test_fail "sentry-report.sh should be executable"
    fi
}
test_sentry_report_executable

# Test 20: sentry-check-status.sh has correct trigger comment
test_sentry_check_status_trigger() {
    if grep -q "# Triggered by: PostToolUse(Bash(gh pr" "$HOME/.claude/hooks/sentry-check-status.sh"; then
        test_pass "sentry-check-status.sh has correct trigger comment"
    else
        test_fail "sentry-check-status.sh should have correct trigger comment"
    fi
}
test_sentry_check_status_trigger

# Test 21: sentry-correlation.sh checks for sentry-cli
test_sentry_correlation_cli_check() {
    if grep -q 'if ! command -v sentry-cli' "$HOME/.claude/hooks/sentry-correlation.sh"; then
        test_pass "sentry-correlation.sh checks for sentry-cli"
    else
        test_fail "sentry-correlation.sh should check for sentry-cli"
    fi
}
test_sentry_correlation_cli_check

# Test 22: sentry-report.sh checks for .sentry-used file
test_sentry_report_used_check() {
    if grep -q 'if \[\[ ! -f ".sentry-used" \]\]; then' "$HOME/.claude/hooks/sentry-report.sh"; then
        test_pass "sentry-report.sh checks for .sentry-used file"
    else
        test_fail "sentry-report.sh should check for .sentry-used file"
    fi
}
test_sentry_report_used_check

# ============================================================================
# Test Group 4: Settings.json
# ============================================================================

echo ""
echo "=== Group 4: Settings.json ==="

# Test 23: settings.json has Stop hook
test_settings_stop_hook() {
    if grep -q '"Stop":' "$HOME/.claude/settings.json"; then
        test_pass "settings.json has Stop hook section"
    else
        test_fail "settings.json should have Stop hook section"
    fi
}
test_settings_stop_hook

# Test 24: settings.json has sentry-report.sh in Stop hook
test_settings_sentry_report() {
    if grep -q "sentry-report.sh" "$HOME/.claude/settings.json"; then
        test_pass "settings.json includes sentry-report.sh"
    else
        test_fail "settings.json should include sentry-report.sh"
    fi
}
test_settings_sentry_report

# Test 25: settings.json has gh pr permission
test_settings_gh_pr_permission() {
    if grep -q '"Bash(gh pr' "$HOME/.claude/settings.json"; then
        test_pass "settings.json has gh pr permission"
    else
        test_fail "settings.json should have gh pr permission"
    fi
}
test_settings_gh_pr_permission

# Test 26: settings.json has gh api sentry permission
test_settings_gh_api_sentry() {
    if grep -q '"Bash(gh api \*sentry' "$HOME/.claude/settings.json"; then
        test_pass "settings.json has gh api sentry permission"
    else
        test_fail "settings.json should have gh api sentry permission"
    fi
}
test_settings_gh_api_sentry

# Test 27: settings.json has sentry-cli permission
test_settings_sentry_cli() {
    if grep -q '"Bash(sentry-cli' "$HOME/.claude/settings.json"; then
        test_pass "settings.json has sentry-cli permission"
    else
        test_fail "settings.json should have sentry-cli permission"
    fi
}
test_settings_sentry_cli

# ============================================================================
# Test Group 5: Enhanced Skills
# ============================================================================

echo ""
echo "=== Group 5: Enhanced Skills ==="

# Test 28: iterate-pr skill exists
test_iterate_pr_skill() {
    if [ -f "$HOME/.claude/skills/iterate-pr/SKILL.md" ]; then
        test_pass "iterate-pr skill exists"
    else
        test_fail "iterate-pr skill should exist"
    fi
}
test_iterate_pr_skill

# Test 29: iterate-pr has context: fork
test_iterate_pr_context() {
    if grep -q "context: fork" "$HOME/.claude/skills/iterate-pr/SKILL.md"; then
        test_pass "iterate-pr has context: fork"
    else
        test_fail "iterate-pr should have context: fork"
    fi
}
test_iterate_pr_context

# Test 30: iterate-pr has PostToolUse hook
test_iterate_pr_hook() {
    if grep -q "PostToolUse:" "$HOME/.claude/skills/iterate-pr/SKILL.md"; then
        test_pass "iterate-pr has PostToolUse hook"
    else
        test_fail "iterate-pr should have PostToolUse hook"
    fi
}
test_iterate_pr_hook

# Test 31: iterate-pr references sentry-check-status.sh
test_iterate_pr_sentry_hook() {
    if grep -q "sentry-check-status.sh" "$HOME/.claude/skills/iterate-pr/SKILL.md"; then
        test_pass "iterate-pr references sentry-check-status.sh"
    else
        test_fail "iterate-pr should reference sentry-check-status.sh"
    fi
}
test_iterate_pr_sentry_hook

# Test 32: iterate-pr has Step 3a for Sentry bot comments
test_iterate_pr_step_3a() {
    if grep -q "### Step 3a: Process Sentry Bot Comments" "$HOME/.claude/skills/iterate-pr/SKILL.md"; then
        test_pass "iterate-pr has Step 3a for Sentry bot comments"
    else
        test_fail "iterate-pr should have Step 3a for Sentry bot comments"
    fi
}
test_iterate_pr_step_3a

# Test 33: iterate-pr mentions Sentry priority
test_iterate_pr_priority() {
    if grep -q "Priority order (v2.33)" "$HOME/.claude/skills/iterate-pr/SKILL.md"; then
        test_pass "iterate-pr mentions Sentry priority"
    else
        test_fail "iterate-pr should mention Sentry priority"
    fi
}
test_iterate_pr_priority

# Test 34: find-bugs skill exists
test_find_bugs_skill() {
    if [ -f "$HOME/.claude/skills/find-bugs/SKILL.md" ]; then
        test_pass "find-bugs skill exists"
    else
        test_fail "find-bugs skill should exist"
    fi
}
test_find_bugs_skill

# Test 35: find-bugs has context: fork
test_find_bugs_context() {
    if grep -q "context: fork" "$HOME/.claude/skills/find-bugs/SKILL.md"; then
        test_pass "find-bugs has context: fork"
    else
        test_fail "find-bugs should have context: fork"
    fi
}
test_find_bugs_context

# Test 36: find-bugs has Phase 0
test_find_bugs_phase_0() {
    if grep -q "## Phase 0: Sentry Pre-Check" "$HOME/.claude/skills/find-bugs/SKILL.md"; then
        test_pass "find-bugs has Phase 0: Sentry Pre-Check"
    else
        test_fail "find-bugs should have Phase 0: Sentry Pre-Check"
    fi
}
test_find_bugs_phase_0

# Test 37: find-bugs has Phase 6
test_find_bugs_phase_6() {
    if grep -q "## Phase 6: Sentry Correlation" "$HOME/.claude/skills/find-bugs/SKILL.md"; then
        test_pass "find-bugs has Phase 6: Sentry Correlation"
    else
        test_fail "find-bugs should have Phase 6: Sentry Correlation"
    fi
}
test_find_bugs_phase_6

# Test 38: find-bugs references sentry-correlation.sh
test_find_bugs_hook() {
    if grep -q "sentry-correlation.sh" "$HOME/.claude/skills/find-bugs/SKILL.md"; then
        test_pass "find-bugs references sentry-correlation.sh"
    else
        test_fail "find-bugs should reference sentry-correlation.sh"
    fi
}
test_find_bugs_hook

# Test 39: deslop skill exists
test_deslop_skill() {
    if [ -f "$HOME/.claude/skills/deslop/SKILL.md" ]; then
        test_pass "deslop skill exists"
    else
        test_fail "deslop skill should exist"
    fi
}
test_deslop_skill

# Test 40: deslop has context: fork
test_deslop_context() {
    if grep -q "context: fork" "$HOME/.claude/skills/deslop/SKILL.md"; then
        test_pass "deslop has context: fork"
    else
        test_fail "deslop should have context: fork"
    fi
}
test_deslop_context

# Test 41: deslop has Sentry anti-patterns section
test_deslop_sentry_section() {
    if grep -q "## Sentry-Specific Anti-Patterns" "$HOME/.claude/skills/deslop/SKILL.md"; then
        test_pass "deslop has Sentry anti-patterns section"
    else
        test_fail "deslop should have Sentry anti-patterns section"
    fi
}
test_deslop_sentry_section

# Test 42: deslop mentions excessive instrumentation
test_deslop_instrumentation() {
    if grep -q "Excessive Manual Instrumentation" "$HOME/.claude/skills/deslop/SKILL.md"; then
        test_pass "deslop mentions excessive instrumentation"
    else
        test_fail "deslop should mention excessive instrumentation"
    fi
}
test_deslop_instrumentation

# Test 43: deslop mentions sample rates
test_deslop_sample_rates() {
    if grep -q "100% Sample Rates" "$HOME/.claude/skills/deslop/SKILL.md"; then
        test_pass "deslop mentions 100% sample rates"
    else
        test_fail "deslop should mention 100% sample rates"
    fi
}
test_deslop_sample_rates

# ============================================================================
# Test Group 6: Orchestrator Integration
# ============================================================================

echo ""
echo "=== Group 6: Orchestrator Integration ==="

# Test 44: Orchestrator file exists
test_orchestrator_exists() {
    if [ -f "$HOME/.claude/agents/orchestrator.md" ]; then
        test_pass "orchestrator.md exists"
    else
        test_fail "orchestrator.md should exist"
    fi
}
test_orchestrator_exists

# Test 45: Orchestrator has Step 2c
test_orchestrator_step_2c() {
    if grep -q "## Step 2c: SENTRY SETUP" "$HOME/.claude/agents/orchestrator.md"; then
        test_pass "Orchestrator has Step 2c: SENTRY SETUP"
    else
        test_fail "Orchestrator should have Step 2c: SENTRY SETUP"
    fi
}
test_orchestrator_step_2c

# Test 46: Step 2c is marked as optional
test_orchestrator_step_2c_optional() {
    if grep -q "Step 2c: SENTRY SETUP (OPTIONAL - v2.33)" "$HOME/.claude/agents/orchestrator.md"; then
        test_pass "Step 2c is marked as optional"
    else
        test_fail "Step 2c should be marked as optional"
    fi
}
test_orchestrator_step_2c_optional

# Test 47: Orchestrator has Step 6b
test_orchestrator_step_6b() {
    if grep -q "### 6b. SENTRY VALIDATION" "$HOME/.claude/agents/orchestrator.md"; then
        test_pass "Orchestrator has Step 6b: SENTRY VALIDATION"
    else
        test_fail "Orchestrator should have Step 6b: SENTRY VALIDATION"
    fi
}
test_orchestrator_step_6b

# Test 48: Step 6b is marked as optional
test_orchestrator_step_6b_optional() {
    if grep -q "6b. SENTRY VALIDATION (OPTIONAL - v2.33)" "$HOME/.claude/agents/orchestrator.md"; then
        test_pass "Step 6b is marked as optional"
    else
        test_fail "Step 6b should be marked as optional"
    fi
}
test_orchestrator_step_6b_optional

# Test 49: Orchestrator has enhanced Step 7b
test_orchestrator_step_7b() {
    if grep -q "## Step 7b: PR REVIEW (ENHANCED - v2.33" "$HOME/.claude/agents/orchestrator.md"; then
        test_pass "Orchestrator has enhanced Step 7b"
    else
        test_fail "Orchestrator should have enhanced Step 7b"
    fi
}
test_orchestrator_step_7b

# Test 50: Step 7b mentions Sentry bot priority
test_orchestrator_step_7b_priority() {
    if grep -q "Prioritize Sentry bot comments" "$HOME/.claude/agents/orchestrator.md"; then
        test_pass "Step 7b mentions Sentry bot priority"
    else
        test_fail "Step 7b should mention Sentry bot priority"
    fi
}
test_orchestrator_step_7b_priority

# Test 51: Mandatory Flow updated with v2.33 steps
test_orchestrator_mandatory_flow() {
    if grep -q "2c. SENTRY SETUP (OPTIONAL - v2.33)" "$HOME/.claude/agents/orchestrator.md"; then
        test_pass "Mandatory Flow includes Step 2c"
    else
        test_fail "Mandatory Flow should include Step 2c"
    fi
}
test_orchestrator_mandatory_flow

# ============================================================================
# Test Group 7: Backward Compatibility
# ============================================================================

echo ""
echo "=== Group 7: Backward Compatibility ==="

# Test 52: Old commands still work (version)
test_old_command_version() {
    if "$PROJECT_ROOT/scripts/ralph" version >/dev/null 2>&1 || [ $? -eq 0 ]; then
        test_pass "ralph version command still works"
    else
        test_fail "ralph version command should still work"
    fi
}
test_old_command_version

# Test 53: No breaking changes to ralph function signatures
test_no_breaking_function_changes() {
    # Check that existing functions haven't been removed
    if grep -q "cmd_orch()" "$PROJECT_ROOT/scripts/ralph" && \
       grep -q "cmd_security()" "$PROJECT_ROOT/scripts/ralph" && \
       grep -q "cmd_gates()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Existing ralph functions preserved"
    else
        test_fail "Existing ralph functions should be preserved"
    fi
}
test_no_breaking_function_changes

# Test 54: Settings.json still has existing hooks
test_settings_backward_compat() {
    if grep -q "quality-gates.sh" "$HOME/.claude/settings.json" && \
       grep -q "git-safety-guard.py" "$HOME/.claude/settings.json"; then
        test_pass "Existing hooks preserved in settings.json"
    else
        test_fail "Existing hooks should be preserved in settings.json"
    fi
}
test_settings_backward_compat

# Test 55: Sentry plugin enabled in settings
test_sentry_plugin_enabled() {
    if grep -q '"sentry@claude-plugins-official": true' "$HOME/.claude/settings.json"; then
        test_pass "Sentry plugin enabled in settings.json"
    else
        test_fail "Sentry plugin should be enabled in settings.json"
    fi
}
test_sentry_plugin_enabled

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "========================================"
echo "Test Results Summary"
echo "========================================"
echo -e "Total:  ${TOTAL} tests"
echo -e "Passed: ${GREEN}${PASSED}${NC} tests"
echo -e "Failed: ${RED}${FAILED}${NC} tests"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}✗ Some tests failed${NC}"
    exit 1
fi
