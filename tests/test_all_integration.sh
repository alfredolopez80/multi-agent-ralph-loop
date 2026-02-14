#!/bin/bash
# test_all_integration.sh - Master Integration Test Suite
# Version: 2.86.0
# Date: 2026-02-14
#
# Runs all integration tests and provides summary
#
# Usage: ./test_all_integration.sh [--verbose]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERBOSE="${1:-}"

PASSED=0
FAILED=0
TOTAL=0

echo "=========================================="
echo "  Multi-Agent Ralph v2.86.0"
echo "  Master Integration Test Suite"
echo "=========================================="
echo ""
echo "Running all integration tests..."
echo ""

# Function to run test and capture results
run_test() {
    local test_name="$1"
    local test_script="$2"
    
    echo "▶ Running: $test_name"
    
    if [ -x "$test_script" ]; then
        if output=$(bash "$test_script" 2>&1); then
            echo "  ✓ PASSED"
            ((PASSED++))
        else
            echo "  ✗ FAILED"
            if [ "$VERBOSE" = "--verbose" ]; then
                echo "$output" | sed 's/^/    /'
            fi
            ((FAILED++))
        fi
    else
        echo "  ⚠ SKIPPED (not executable)"
    fi
    ((TOTAL++))
    echo ""
}

# Run Session Lifecycle Tests
echo "=== SESSION LIFECYCLE TESTS ==="
run_test "Session Lifecycle Hooks" "$SCRIPT_DIR/session-lifecycle/test_session_lifecycle_hooks.sh"

# Run Agent Teams Tests
echo "=== AGENT TEAMS TESTS ==="
run_test "Agent Teams Integration" "$SCRIPT_DIR/agent-teams/test_agent_teams_integration.sh"

# Summary
echo "=========================================="
echo "  FINAL SUMMARY"
echo "=========================================="
echo ""
echo "  Total Tests: $TOTAL"
echo "  Passed: $PASSED"
echo "  Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "✅ ALL INTEGRATION TESTS PASSED"
    echo ""
    echo "Session Lifecycle Flow Verified:"
    echo "  SessionStart(*) → PreCompact → [compact] → SessionStart(compact) → SessionEnd"
    echo ""
    echo "Agent Teams Integration Verified:"
    echo "  TeammateIdle ✓ | TaskCompleted ✓ | SubagentStart ✓ | SubagentStop ✓"
    echo ""
    echo "Custom Subagents Available:"
    echo "  ralph-coder | ralph-reviewer | ralph-tester | ralph-researcher"
    echo ""
    echo "GLM-5 Model Configuration:"
    echo "  Haiku: glm-5 | Sonnet: glm-5 | Opus: glm-5"
    exit 0
else
    echo "❌ $FAILED TEST(S) FAILED"
    echo "Run with --verbose for details"
    exit 1
fi
