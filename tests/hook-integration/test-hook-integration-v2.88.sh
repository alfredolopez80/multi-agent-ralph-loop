#!/bin/bash
#
# Hook Integration End-to-End Test Suite v2.88.0
# (reduced by #69 Phase 3 Slice C: findings #1/#2/#3/#5 exercised hooks
#  removed by that slice — ralph-subagent-stop, ralph-stop-quality-gate,
#  teammate-idle machinery. Finding #4 survives; it exercises the retained
#  ralph-subagent-start.sh state registration.)
#
# Usage: ./tests/hook-integration/test-hook-integration-v2.88.sh [-v]
#

set -uo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Configuration
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"

# T39: hermetic HOME. Standalone (pre-commit Phase 8) this suite used to run
# against the REAL home: fixtures under ~/.ralph/state and ~/.claude/teams
# raced with live sessions. Same pattern run-all-unit-tests.sh uses:
# mktemp home, trap, export. RALPH_TEST_KEEP_HOME=1 opts out for debugging.
if [[ "${RALPH_TEST_KEEP_HOME:-0}" != "1" ]]; then
    _SANDBOX_HOME="$(mktemp -d -t hookint-XXXXXX)"
    trap 'rm -rf "$_SANDBOX_HOME"' EXIT
    export HOME="$_SANDBOX_HOME"
    mkdir -p "$HOME/.ralph" "$HOME/.claude"
fi

STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"
TEAMS_DIR="$HOME/.claude/teams"
VERBOSE=false

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Parse arguments
[[ "${1:-}" == "-v" || "${1:-}" == "--verbose" ]] && VERBOSE=true

pass() { ((TESTS_PASSED++)); printf "${GREEN}.${NC}"; }
fail() { ((TESTS_FAILED++)); printf "${RED}F${NC}"; }

print_test() {
    $VERBOSE && echo -e "  Test: $1"
}

print_header() {
    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  $1${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
}

cleanup_test_state() {
    rm -rf "$STATE_DIR/test-session" 2>/dev/null || true
    rm -rf "$TEAMS_DIR/test-team" 2>/dev/null || true
    rm -rf "$HOME/.claude/tasks/test-team" 2>/dev/null || true
}

#######################################
# Test 4: SubagentStart State Registration (Finding #4 - MEDIUM)
#######################################
test_subagent_start_state() {
    print_header "Test 4: SubagentStart State (Finding #4)"

    cleanup_test_state

    # Test 4.1: Hook file exists
    print_test "ralph-subagent-start.sh exists"
    if [[ -f "$REPO_ROOT/.claude/hooks/ralph-subagent-start.sh" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ ralph-subagent-start.sh not found${NC}"
    fi

    # Test 4.2: Subagent state registered on start
    print_test "Subagent state registered on start"
    mkdir -p "$STATE_DIR/test-session"

    echo '{"subagentId": "test-subagent", "subagentType": "ralph-coder", "sessionId": "test-session", "parentId": "parent-1"}' | \
        "$REPO_ROOT/.claude/hooks/ralph-subagent-start.sh" >/dev/null 2>&1 || true

    if [[ -f "$STATE_DIR/test-session/subagents/test-subagent.json" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Subagent state not registered${NC}"
    fi

    # Test 4.3: State has correct fields
    print_test "Subagent state has required fields"
    local state_file="$STATE_DIR/test-session/subagents/test-subagent.json"
    local id_ok=$(jq -r '.id' "$state_file" 2>/dev/null)
    local type_ok=$(jq -r '.type' "$state_file" 2>/dev/null)
    local status_ok=$(jq -r '.status' "$state_file" 2>/dev/null)

    if [[ "$id_ok" == "test-subagent" && "$type_ok" == "ralph-coder" && "$status_ok" == "active" ]]; then
        pass
    else
        fail
        echo -e "  ${RED}✗ Subagent state missing fields (id=$id_ok, type=$type_ok, status=$status_ok)${NC}"
    fi

    cleanup_test_state
}

#######################################
# Summary
#######################################
print_summary() {
    local total=$((TESTS_PASSED + TESTS_FAILED))

    echo -e "\n${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}  HOOK INTEGRATION TEST SUMMARY${NC}"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════${NC}"

    echo -e "\n  ${GREEN}Passed:${NC}   $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC}   $TESTS_FAILED"
    echo -e "  ${BOLD}Total:${NC}    $total"

    if [[ $total -gt 0 ]]; then
        local rate=$((TESTS_PASSED * 100 / total))
        echo -e "\n  ${BOLD}Pass Rate: ${rate}%${NC}"
    fi

    echo ""
    echo -e "${BOLD}Findings Validated:${NC}"
    echo "  #4 (MEDIUM): SubagentStart registers state"
    echo "  (#1/#2/#3/#5 retired with their hooks in #69 Phase 3 Slice C)"

    if [[ $total -eq 0 ]]; then
        # T39: zero-tests is never success (same family as T33). A run that
        # asserted nothing must not print ALL PASSED over an empty set.
        echo -e "\n${RED}${BOLD}✗ ZERO TESTS EXECUTED${NC}"
        return 1
    fi

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}${BOLD}✓ ALL HOOK INTEGRATION TESTS PASSED${NC}"
        return 0
    else
        echo -e "\n${RED}${BOLD}✗ SOME TESTS FAILED${NC}"
        return 1
    fi
}

#######################################
# Main
#######################################
main() {
    echo -e "${BLUE}${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║     Hook Integration E2E Test Suite v2.88.0                ║${NC}"
    echo -e "${BLUE}${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"

    test_subagent_start_state

    print_summary
}

main "$@"
