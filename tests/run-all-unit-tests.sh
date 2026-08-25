#!/bin/bash
# run-all-unit-tests.sh - Run all unit tests and report results
# Version: 2.87.0
# Date: 2026-02-14
# Purpose: CI/CD validation script for multi-agent-ralph-loop
#
# Usage:
#   ./tests/run-all-unit-tests.sh [--verbose] [--coverage]
#
# Exit codes:
#   0 - All tests passed (100%)
#   1 - Some tests failed
#   2 - Script error

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

# Options
VERBOSE=false
COVERAGE=false
WITH_INSTALL=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --verbose|-v) VERBOSE=true ;;
        --coverage|-c) COVERAGE=true ;;
        --with-install) WITH_INSTALL=true ;;
        --help|-h)
            echo "Usage: $0 [--verbose] [--coverage] [--with-install]"
            echo ""
            echo "Options:"
            echo "  --verbose        Show detailed output from each test"
            echo "  --coverage       Generate coverage report (future feature)"
            echo "  --with-install   Also run suites that require a provisioned"
            echo "                   ~/.claude / ~/.ralph / vault (fail on a clean runner)"
            exit 0
            ;;
    esac
done

# Sandbox HOME for the whole run.
#
# These suites were written to be run by hand and several write to the real home
# directory. tests/promptify-integration/test-security-functions.sh appends fabricated
# entries to ~/.ralph/logs/promptify-audit.log -- creating it 0644, while the hook that
# owns that log sets `umask 077` and chmod 600 on rotation -- and it overwrites
# ~/.ralph/config/promptify-consent.json, a consent control, restoring it without a
# trap. Harmless when a developer chose to run one suite; not acceptable now that CI
# runs all of them on every push, and not acceptable on a contributor's machine either.
#
# RALPH_TEST_KEEP_HOME=1 opts out for anyone debugging against a provisioned home.
if [[ "${RALPH_TEST_KEEP_HOME:-0}" != "1" ]]; then
    _SANDBOX_HOME="$(mktemp -d)"
    trap 'rm -rf "$_SANDBOX_HOME"' EXIT
    export HOME="$_SANDBOX_HOME"
    mkdir -p "$HOME/.ralph" "$HOME/.claude" "$HOME/.local/bin"
fi

echo ""
echo -e "${BOLD}${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║         Multi-Agent Ralph Loop - Unit Test Runner            ║${NC}"
echo -e "${BOLD}${CYAN}║         Version 2.87.0                                        ║${NC}"
echo -e "${BOLD}${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Repository: $REPO_ROOT"
echo "Verbose: $VERBOSE"
echo "Started: $(date)"
echo ""

# Test suites to run (issue #42)
#
# This array held exactly ONE entry, and that entry was already covered by
# pre-commit. Meanwhile 62 shell/bats suites under tests/ were invoked by nothing at
# all -- not CI, not pre-commit, not any aggregate runner. They were not obsolete;
# they simply had no way to run, so nobody could tell which of them still worked.
#
# All 62 were executed to find out. The split below is that measurement, not a guess:
#
#   TEST_SUITES                  23 suites that pass on a bare checkout. Safe for CI.
#   TEST_SUITES_REQUIRE_INSTALL  suites that assert on a provisioned machine --
#                                symlinks under ~/.claude, ~/.codex, ~/.ralph, or an
#                                Obsidian vault. They fail on any clean runner by
#                                construction, so they are opt-in via --with-install
#                                rather than wired into the gate.
#
# The remaining suites are neither list: see docs/testing/ORPHAN_TEST_AUDIT.md for the
# per-suite verdict. Nothing was deleted on the strength of "it had no runner".
TEST_SUITES=(
    "hooks/test_no_hook_hangs_or_blocks.sh:Hooks: no hangs or blocks"
    "hooks/test_plan_state_writer.sh:Hooks: plan-state writer"
    "hooks/test_quality_check_registry.sh:Hooks: quality check registry"
    "hooks/test_react_doctor_runner_failures.sh:Hooks: react-doctor runner failures"
    "hooks/test_session_dedup_key.sh:Hooks: session dedup key"
    "hooks/test_single_json_emission.sh:Hooks: single JSON emission"
    "hooks/test_task_list_projection.sh:Hooks: task list projection"
    "memory/test-seed-dev-prohibitions.sh:Memory: seed dev prohibitions"
    "promptify-integration/test-clarity-scoring.sh:Promptify: clarity scoring"
    "promptify-integration/test-credential-redaction.sh:Promptify: credential redaction"
    "promptify-integration/test-e2e.sh:Promptify: end to end"
    "promptify-integration/test-security-functions.sh:Promptify: security functions"
    "security/test-command-injection-prevention.sh:Security: command injection prevention"
    "security/test-environment-validation.sh:Security: environment validation"
    "security/test-json-error-handling.sh:Security: JSON error handling"
    "security/test-logging-standards.sh:Security: logging standards"
    "security/test-shell-syntax-validation.sh:Security: shell syntax validation"
    "security/test-sql-injection-blocking.sh:Security: SQL injection blocking"
    "skills/test-autoresearch-smart-setup.sh:Skills: autoresearch smart setup"
    "stop-hook/test-ralph-stop-quality-gate.sh:Stop hook: quality gate"
    "stop-hook/test-ralph-subagent-stop.sh:Stop hook: subagent stop"
    "unit/test-context-warning-v2.90.sh:Unit: context warning"
    "unit/test-quality-gates-v2.90.sh:Unit: quality gates"
    "unit/test_validation_common.sh:Unit: validation-common library"
    "unit/test-wt-lead-scripts.sh:Unit: wt-lead scope and provenance guards"
    "unit/test-statusline-context.sh:Unit: statusline context (hardened against talking-tests #42)"
)

# Opt-in: these assert against a provisioned machine -- symlinks under ~/.claude,
# ~/.codex, ~/.ralph, ~/.config/agents, or an Obsidian vault -- so they fail on a clean
# runner by construction, not because anything is broken. Run with --with-install.
#
# They were classified from their failure diagnostics on a bare checkout; they have NOT
# been verified green on a fully provisioned machine, so treat a failure here as
# "investigate", not "regression". Verdict per suite: docs/testing/ORPHAN_TEST_AUDIT.md
TEST_SUITES_REQUIRE_INSTALL=(
    "unit/test-skills-unification-v2.87.sh:Skills Unification (needs global symlinks)"
    "orchestrator-validation/test-suite.sh:Orchestrator validation (needs ~/.claude/agents)"
    "session-lifecycle/test_skills_centralization.sh:Skills centralization (needs ~/.claude/skills)"
    "skills/test-iterate.sh:Skills: iterate (needs global symlinks)"
    "skills/test-autoresearch.sh:Skills: autoresearch (needs global symlinks)"
    "skills/test-autoresearch-integrations.sh:Skills: autoresearch integrations (needs global symlinks)"
    "skills/test-batch-skills-integration.sh:Skills: batch integration (needs global symlinks)"
    "skills/test-task-batch.sh:Skills: task-batch (needs global symlinks)"
    "skills/test-create-task-batch.sh:Skills: create-task-batch (needs global symlinks)"
    "vault/test-vault-health.sh:Vault health (needs an Obsidian vault)"
    "test_v2.33_sentry_integration.sh:Sentry integration (needs global config)"
)

if $WITH_INSTALL; then
    TEST_SUITES+=("${TEST_SUITES_REQUIRE_INSTALL[@]}")
fi

# bats suites, run by `bats` rather than `bash`.
#
# These four were missing from the first pass of the audit, and the reason is worth
# recording: the classification loop was `while read -r f; do bats "$f"; done < list`,
# and bats reads stdin -- so it ate four lines out of the list it was being driven by.
# Four suites vanished from a measurement that presented itself as exhaustive. The
# `< /dev/null` in run_bats_suite below is what stops that recurring.
#
# All five pass on a bare checkout: 157 assertions, zero failures. test_cross_platform
# is the valuable one -- 30 tests covering portable stat/date/realpath/mktemp, i.e. the
# GNU-vs-BSD class that produced #43, #44 and the `cat -A` debug step that failed to
# diagnose #44. The repo already owned a guard against its own recurring bug and
# nothing ran it.
BATS_SUITES=(
    "test_cross_platform.bats:Cross-platform portability (GNU vs BSD)"
    "test_quality_gates.bats:Quality gates"
    "test_security_functions.bats:Security functions"
    "test_settings_merge.bats:Settings merge"
    "test_worktree_workflow.bats:Worktree workflow"
    "security/test-bug-fixes-v2.90.bats:Security: v2.90 bug fixes"
)

#######################################
# Run a test suite
#######################################
run_test_suite() {
    local test_script="$1"
    local test_name="$2"
    local full_path="$SCRIPT_DIR/$test_script"

    ((TOTAL_SUITES++))

    echo -e "${BOLD}[Test Suite $TOTAL_SUITES] $test_name${NC}"
    echo -e "  Script: $test_script"

    if [[ ! -f "$full_path" ]]; then
        echo -e "  ${RED}✗ Test script not found${NC}"
        ((FAILED_SUITES++))
        return 1
    fi

    if [[ ! -x "$full_path" ]]; then
        echo -e "  ${YELLOW}⚠ Making script executable${NC}"
        chmod +x "$full_path"
    fi

    echo ""

    # Run the test
    local start_time
    start_time=$(date +%s)

    local verbose_flag=""
    $VERBOSE && verbose_flag="--verbose"

    if "$full_path" $verbose_flag; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        echo -e "  ${GREEN}✓ PASSED${NC} (${duration}s)"
        ((PASSED_SUITES++))
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        echo ""
        echo -e "  ${RED}✗ FAILED${NC} (${duration}s)"
        ((FAILED_SUITES++))
        return 1
    fi
}

#######################################
# Main execution
#######################################

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Running Test Suites${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

FAILED_TESTS=""

for suite in "${TEST_SUITES[@]}"; do
    IFS=':' read -r script name <<< "$suite"

    echo ""
    if ! run_test_suite "$script" "$name"; then
        FAILED_TESTS="$FAILED_TESTS $name"
    fi
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
done

# bats suites. `< /dev/null` is mandatory: bats reads stdin, and without it a suite
# would consume the loop's own input. That is not hypothetical -- it is how four
# suites went missing from the audit that produced this list.
if command -v bats &>/dev/null; then
    for suite in "${BATS_SUITES[@]}"; do
        IFS=':' read -r script name <<< "$suite"
        full="$SCRIPT_DIR/$script"

        TOTAL_SUITES=$((TOTAL_SUITES + 1))
        echo ""
        echo -e "${BOLD}[Test Suite $TOTAL_SUITES] $name${NC}"
        echo -e "  Script: $script (bats)"
        echo ""

        if [[ ! -f "$full" ]]; then
            echo -e "  ${RED}✗ Test script not found${NC}"
            FAILED_SUITES=$((FAILED_SUITES + 1))
            FAILED_TESTS="$FAILED_TESTS $name"
        elif bats "$full" < /dev/null; then
            echo -e "  ${GREEN}✓ PASSED${NC}"
            PASSED_SUITES=$((PASSED_SUITES + 1))
        else
            echo -e "  ${RED}✗ FAILED${NC}"
            FAILED_SUITES=$((FAILED_SUITES + 1))
            FAILED_TESTS="$FAILED_TESTS $name"
        fi
        echo ""
        echo -e "${BLUE}───────────────────────────────────────────────────────────────${NC}"
    done
else
    # Loud, not silent: these suites are part of the gate, so their absence is
    # reported rather than quietly skipped.
    echo ""
    echo -e "${YELLOW}⚠ bats not installed — ${#BATS_SUITES[@]} bats suites were NOT run${NC}"
    echo "  Install: apt-get install -y bats   |   brew install bats-core"
fi

#######################################
# Summary
#######################################
echo ""
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}  Test Summary${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "  ${GREEN}Passed:${NC} $PASSED_SUITES"
echo -e "  ${RED}Failed:${NC} $FAILED_SUITES"
echo -e "  ${BOLD}Total:${NC}  $TOTAL_SUITES"
echo ""

pass_rate=0
if [[ $TOTAL_SUITES -gt 0 ]]; then
    pass_rate=$((PASSED_SUITES * 100 / TOTAL_SUITES))
fi

echo -e "  ${BOLD}Pass Rate: ${pass_rate}%${NC}"
echo ""

# A run that executed nothing is not a pass. Without this, an empty or mis-pathed
# TEST_SUITES array reports "ALL TEST SUITES PASSED" over zero suites -- which is how
# this runner could sit at one entry for months and still look healthy.
if [[ $TOTAL_SUITES -eq 0 ]]; then
    echo -e "${RED}${BOLD}✗ NO TEST SUITES RAN${NC}"
    echo ""
    echo "TEST_SUITES is empty or every path was unresolvable. That is a failure,"
    echo "not a clean run."
    echo ""
    exit 2
fi

if [[ $FAILED_SUITES -eq 0 ]]; then
    echo -e "${GREEN}${BOLD}✓ ALL TEST SUITES PASSED${NC}"
    echo ""
    echo "Completed: $(date)"
    echo ""
    exit 0
else
    echo -e "${RED}${BOLD}✗ SOME TEST SUITES FAILED${NC}"
    echo ""
    echo "Failed suites:$FAILED_TESTS"
    echo ""
    echo "Run with --verbose for detailed output"
    echo ""
    echo "Completed: $(date)"
    echo ""
    exit 1
fi
