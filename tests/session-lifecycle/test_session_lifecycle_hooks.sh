#!/bin/bash
# test_session_lifecycle_hooks.sh - Comprehensive tests for session lifecycle
# VERSION: 2.86.0
#
# Tests the complete session lifecycle:
#   SessionStart(*) → [work] → PreCompact → [compact] → SessionStart(compact) → [continue]
#                                                       ↓
#                                                SessionEnd → [terminate]

set -euo pipefail

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS_DIR="$REPO_ROOT/.claude/hooks"
SETTINGS_FILE="$HOME/.claude/settings.json"
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test helpers
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((TESTS_FAILED++))
}

warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
}

section() {
    echo ""
    echo "========================================"
    echo " $1"
    echo "========================================"
}

# =============================================================================
# TEST 1: Hook Files Exist
# =============================================================================
test_hook_files_exist() {
    section "TEST 1: Hook Files Exist"

    local hooks=(
        "pre-compact-handoff.sh"
        "post-compact-restore.sh"
        "session-end-handoff.sh"
    )

    for hook in "${hooks[@]}"; do
        if [[ -f "$HOOKS_DIR/$hook" ]]; then
            pass "Hook file exists: $hook"
        else
            fail "Hook file missing: $hook"
        fi
    done
}

# =============================================================================
# TEST 2: Hooks Are Executable
# =============================================================================
test_hooks_executable() {
    section "TEST 2: Hooks Are Executable"

    local hooks=(
        "pre-compact-handoff.sh"
        "post-compact-restore.sh"
        "session-end-handoff.sh"
    )

    for hook in "${hooks[@]}"; do
        if [[ -x "$HOOKS_DIR/$hook" ]]; then
            pass "Hook is executable: $hook"
        else
            fail "Hook not executable: $hook"
        fi
    done
}

# =============================================================================
# TEST 3: Hooks Registered in settings.json
# =============================================================================
test_hooks_registered() {
    section "TEST 3: Hooks Registered in settings.json"

    if [[ ! -f "$SETTINGS_FILE" ]]; then
        fail "settings.json not found at: $SETTINGS_FILE"
        return
    fi

    # Check PreCompact
    if jq -e '.hooks.PreCompact' "$SETTINGS_FILE" > /dev/null 2>&1; then
        pass "PreCompact hook registered"
    else
        fail "PreCompact hook NOT registered"
    fi

    # Check SessionStart with matcher="compact"
    if jq -e '.hooks.SessionStart[] | select(.matcher == "compact")' "$SETTINGS_FILE" > /dev/null 2>&1; then
        pass "SessionStart(matcher='compact') registered for post-compact restore"
    else
        fail "SessionStart(matcher='compact') NOT registered"
    fi

    # Check SessionEnd
    if jq -e '.hooks.SessionEnd' "$SETTINGS_FILE" > /dev/null 2>&1; then
        pass "SessionEnd hooks registered"
    else
        fail "SessionEnd hooks NOT registered"
    fi
}

# =============================================================================
# TEST 4: PreCompact Hook Output Format
# =============================================================================
test_precompact_output_format() {
    section "TEST 4: PreCompact Hook Output Format"

    local hook_file="$HOOKS_DIR/pre-compact-handoff.sh"

    # Check for JSON output format
    if grep -q '"continue"' "$hook_file"; then
        pass "PreCompact hook outputs JSON with 'continue' field"
    else
        fail "PreCompact hook missing 'continue' in output"
    fi

    # Check for hookSpecificOutput
    if grep -q 'hookSpecificOutput' "$hook_file"; then
        pass "PreCompact hook uses hookSpecificOutput for context injection"
    else
        warn "PreCompact hook may not inject context via hookSpecificOutput"
    fi
}

# =============================================================================
# TEST 5: SessionEnd Hook Matchers
# =============================================================================
test_session_end_matchers() {
    section "TEST 5: SessionEnd Hook Matchers"

    local matchers=("clear" "logout" "prompt_input_exit" "other")

    for matcher in "${matchers[@]}"; do
        if jq -e ".hooks.SessionEnd[] | select(.matcher == \"$matcher\")" "$SETTINGS_FILE" > /dev/null 2>&1; then
            pass "SessionEnd matcher '$matcher' registered"
        else
            fail "SessionEnd matcher '$matcher' NOT registered"
        fi
    done
}

# =============================================================================
# TEST 6: PostCompact Does NOT Exist (Critical)
# =============================================================================
test_postcompact_not_exists() {
    section "TEST 6: PostCompact Event Does NOT Exist (Critical)"

    # PostCompact is NOT a valid event in Claude Code
    # SessionStart(matcher="compact") should be used instead
    if jq -e '.hooks.PostCompact' "$SETTINGS_FILE" > /dev/null 2>&1; then
        fail "PostCompact is registered but should NOT exist - use SessionStart(matcher='compact') instead"
    else
        pass "PostCompact correctly NOT registered (doesn't exist in Claude Code)"
    fi
}

# =============================================================================
# TEST 7: Hook Input Format Validation
# =============================================================================
test_hook_input_format() {
    section "TEST 7: Hook Input Format Validation"

    local hook_file="$HOOKS_DIR/session-end-handoff.sh"

    # Check for stdin reading
    if grep -q 'head -c' "$hook_file" || grep -q 'cat' "$hook_file"; then
        pass "SessionEnd hook reads from stdin"
    else
        fail "SessionEnd hook may not read stdin properly"
    fi

    # Check for JSON parsing
    if grep -q 'jq' "$hook_file"; then
        pass "SessionEnd hook uses jq for JSON parsing"
    else
        warn "SessionEnd hook may not parse JSON input"
    fi
}

# =============================================================================
# TEST 8: Ledger Directory Creation
# =============================================================================
test_ledger_directory() {
    section "TEST 8: Ledger Directory Setup"

    local ledger_dir="$HOME/.ralph/ledgers"
    local handoff_dir="$HOME/.ralph/handoffs"

    # These directories should be created by hooks if they don't exist
    if grep -q "mkdir -p.*$ledger_dir" "$HOOKS_DIR"/*.sh 2>/dev/null; then
        pass "Hooks create ledger directory"
    else
        warn "Hooks may not create ledger directory"
    fi

    if grep -q "mkdir -p.*$handoff_dir" "$HOOKS_DIR"/*.sh 2>/dev/null; then
        pass "Hooks create handoff directory"
    else
        warn "Hooks may not create handoff directory"
    fi
}

# =============================================================================
# TEST 9: Session Lifecycle Flow Simulation
# =============================================================================
test_lifecycle_flow() {
    section "TEST 9: Session Lifecycle Flow Simulation"

    # Simulate the complete lifecycle
    echo "Simulating: SessionStart(*) → PreCompact → SessionStart(compact) → SessionEnd"

    # Step 1: Check SessionStart exists
    if jq -e '.hooks.SessionStart' "$SETTINGS_FILE" > /dev/null 2>&1; then
        pass "Step 1: SessionStart(*) registered"
    else
        fail "Step 1: SessionStart(*) NOT registered"
    fi

    # Step 2: Check PreCompact exists
    if jq -e '.hooks.PreCompact' "$SETTINGS_FILE" > /dev/null 2>&1; then
        pass "Step 2: PreCompact registered (saves state before compaction)"
    else
        fail "Step 2: PreCompact NOT registered"
    fi

    # Step 3: Check SessionStart(compact) for restoration
    if jq -e '.hooks.SessionStart[] | select(.matcher == "compact")' "$SETTINGS_FILE" > /dev/null 2>&1; then
        pass "Step 3: SessionStart(compact) registered (restores context after compaction)"
    else
        fail "Step 3: SessionStart(compact) NOT registered"
    fi

    # Step 4: Check SessionEnd for termination
    if jq -e '.hooks.SessionEnd' "$SETTINGS_FILE" > /dev/null 2>&1; then
        pass "Step 4: SessionEnd registered (saves state on termination)"
    else
        fail "Step 4: SessionEnd NOT registered"
    fi

    echo ""
    echo "Lifecycle Flow: SessionStart → [work] → PreCompact → [compact] → SessionStart(compact) → SessionEnd"
}

# =============================================================================
# TEST 10: Hook Timeout Configuration
# =============================================================================
test_hook_timeouts() {
    section "TEST 10: Hook Timeout Configuration"

    # Check SessionEnd has timeout
    local session_end_timeout
    session_end_timeout=$(jq -r '.hooks.SessionEnd[0].hooks[0].timeout // "not set"' "$SETTINGS_FILE" 2>/dev/null)

    if [[ "$session_end_timeout" != "not set" && "$session_end_timeout" != "null" ]]; then
        pass "SessionEnd has timeout: ${session_end_timeout}s"
    else
        warn "SessionEnd missing timeout configuration"
    fi

    # Check SessionStart(compact) has timeout
    local compact_timeout
    compact_timeout=$(jq -r '.hooks.SessionStart[] | select(.matcher == "compact") | .hooks[0].timeout // "not set"' "$SETTINGS_FILE" 2>/dev/null)

    if [[ "$compact_timeout" != "not set" && "$compact_timeout" != "null" ]]; then
        pass "SessionStart(compact) has timeout: ${compact_timeout}s"
    else
        warn "SessionStart(compact) missing timeout configuration"
    fi
}

# =============================================================================
# Main Test Runner
# =============================================================================
main() {
    echo "========================================"
    echo " Session Lifecycle Hooks Test Suite"
    echo " Version: 2.86.0"
    echo "========================================"
    echo ""
    echo "Repository: $REPO_ROOT"
    echo "Hooks Dir: $HOOKS_DIR"
    echo "Settings: $SETTINGS_FILE"
    echo ""

    # Run all tests
    test_hook_files_exist
    test_hooks_executable
    test_hooks_registered
    test_precompact_output_format
    test_session_end_matchers
    test_postcompact_not_exists
    test_hook_input_format
    test_ledger_directory
    test_lifecycle_flow
    test_hook_timeouts

    # Summary
    echo ""
    echo "========================================"
    echo " TEST SUMMARY"
    echo "========================================"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}Some tests failed. Please review the output above.${NC}"
        exit 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    fi
}

main "$@"
