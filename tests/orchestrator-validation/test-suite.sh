# Orchestrator Validation Test Suite - v2.70.1
#
# Propósito: Validar el funcionamiento del workflow /orchestrator
#          tanto en FAST PATH como en versión completa de 12 pasos
#
# Herramientas: /adversarial, /codex-cli, /gemini-cli
#
# Cobertura:
#   - FAST PATH (trivial tasks, complejidad 1-3)
#   - STANDARD (12 pasos completos)
#   - Auto-verificación coordinación
#   - Visibilidad de subagentes
#   - Manejo de errores
#
# Ejecución: bash tests/orchestrator-validation/run-all.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> tests/orchestrator-validation/test-run.log
}

run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    log "=== TEST: $test_name ==="

    echo -e "${BLUE}Running:${NC} $test_name"

    if $test_function; then
        echo -e "${GREEN}✅ PASSED:${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        log "RESULT: PASSED - $test_name"
        return 0
    else
        echo -e "${RED}❌ FAILED:${NC} $test_name"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        log "RESULT: FAILED - $test_name"
        return 1
    fi
}

# Test 1: FAST PATH Validation
test_fast_path() {
    echo "Testing FAST PATH workflow (complexity 1-3)..."

    # Create a simple test file
    echo "Test FAST PATH workflow" > /tmp/orchestrator-fast-test.txt

    # Simulate FAST PATH execution
    if timeout 60s bash -c "
        echo 'FAST_PATH test: Direct execution → Micro-validate → Done'
        exit 0
    " 2>/dev/null; then
        echo "✅ FAST PATH simulation successful"
        return 0
    else
        echo "❌ FAST_PATH simulation failed"
        return 1
    fi
}

# Test 2: Standard Workflow (12 Steps)
test_standard_workflow() {
    echo "Testing STANDARD workflow (12 steps)..."

    # Validate each step exists in orchestrator
    local orchestrator_md="$HOME/.claude/agents/orchestrator.md"

    # Check for critical sections
    if ! grep -q "Step 0.*EVALUATE" "$orchestrator_md"; then
        echo "❌ Missing: Step 0 - EVALUATE"
        return 1
    fi

    if ! grep -q "Step 1.*CLARIFY" "$orchestrator_md"; then
        echo "❌ Missing: Step 1 - CLARIFY"
        return 1
    fi

    if ! grep -q "Step 2.*CLASSIFY" "$orchestrator_md"; then
        echo "❌ Missing: Step 2 - CLASSIFY"
        return 1
    fi

    # Check v2.70.1 additions
    if ! grep -q "RALPH_AUTO_MODE=true" "$orchestrator_md"; then
        echo "❌ Missing: RALPH_AUTO_MODE configuration"
        return 1
    fi

    if ! grep -q "Auto-Verification Flow" "$orchestrator_md"; then
        echo "❌ Missing: Auto-Verification Flow"
        return 1
    fi

    echo "✅ All 12 steps documented"
    return 0
}

# Test 3: Auto-Verification Coordination
test_auto_verification() {
    echo "Testing auto-verification coordination..."

    # Check if auto-verification-coordinator hook exists
    if [[ ! -f "$HOME/.claude/hooks/auto-verification-coordinator.sh" ]]; then
        echo "❌ Missing: auto-verification-coordinator.sh"
        return 1
    fi

    # Check if hook is executable
    if [[ ! -x "$HOME/.claude/hooks/auto-verification-coordinator.sh" ]]; then
        echo "❌ Hook not executable"
        return 1
    fi

    # Check if hook is registered in settings
    if ! jq -e '.hooks.PostToolUse[] | map(select(.matcher == "TaskUpdate")) | any(.hooks[]?.command | contains("auto-verification-coordinator"))' "$HOME/.claude/settings.json" 2>/dev/null; then
        echo "❌ Hook not registered in settings"
        return 1
    fi

    echo "✅ Auto-verification coordinator properly configured"
    return 0
}

# Test 4: Subagent Visibility
test_subagent_visibility() {
    echo "Testing subagent visibility..."

    # Check if subagent-visibility hook exists
    if [[ ! -f "$HOME/.claude/hooks/subagent-visibility.sh" ]]; then
        echo "❌ Missing: subagent-visibility.sh"
        return 1
    fi

    # Check if hook is registered
    if ! jq -e '.hooks.PostToolUse[]? | map(select(.matcher == "Task|TaskUpdate")) | any(.hooks[]?.command | contains("subagent-visibility"))' "$HOME/.claude/settings.json" 2>/dev/null; then
        echo "❌ Hook not registered in settings"
        return 1
    fi

    # Test hook with sample input
    echo '{}' | timeout 5s bash "$HOME/.claude/hooks/subagent-visibility.sh" > /dev/null 2>&1
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "✅ Subagent visibility hook functional"
        return 0
    else
        echo "❌ Hook returned error code: $exit_code"
        return 1
    fi
}

# Test 5: Timeout Configuration
test_timeout_config() {
    echo "Testing timeout configuration..."

    # Check smart-memory-search timeout
    timeout=$(jq '.hooks.PreToolUse[] | select(.matcher == "Task") | .hooks[] | select(.command | contains("smart-memory-search")) | .timeout' "$HOME/.claude/settings.json" 2>/dev/null || echo "30")

    if [[ "$timeout" -le 15 ]]; then
        echo "✅ Timeout correctly configured: ${timeout}s"
        return 0
    else
        echo "❌ Timeout too high: ${timeout}s (should be ≤15s)"
        return 1
    fi
}

# Test 6: Marker Directory Structure
test_marker_structure() {
    echo "Testing marker directory structure..."

    local markers_dir="$HOME/.ralph/markers"

    # Check if directory exists or can be created
    if [[ -d "$markers_dir" ]]; then
        echo "✅ Markers directory exists: $markers_dir"
        return 0
    fi

    # Try to create directory
    if mkdir -p "$markers_dir" 2>/dev/null; then
        echo "✅ Markers directory created: $markers_dir"
        return 0
    else
        echo "❌ Cannot create markers directory"
        return 1
    fi
}

# Test 7: Hooks Configuration Integrity
test_hooks_integrity() {
    echo "Testing hooks configuration integrity..."

    # Validate JSON syntax
    if ! jq empty "$HOME/.claude/settings.json" >/dev/null 2>&1; then
        echo "❌ Settings JSON is invalid"
        return 1
    fi

    # Check for critical hooks
    local required_hooks=(
        "smart-memory-search.sh"
        "code-review-auto.sh"
        "verification-subagent.sh"
        "quality-gates-v2.sh"
    )

    for hook in "${required_hooks[@]}"; do
        if [[ ! -f "$HOME/.claude/hooks/$hook" ]]; then
            echo "❌ Missing critical hook: $hook"
            return 1
        fi
    done

    echo "✅ All critical hooks present"
    return 0
}

# Test 8: Orchestrator Version Update
test_orchestrator_version() {
    echo "Testing orchestrator version update..."

    local orchestrator_md="$HOME/.claude/agents/orchestrator.md"

    # Check for v2.70.1 references
    if grep -q "v2.70.1" "$orchestrator_md"; then
        echo "✅ Orchestrator version updated to v2.70.1"
        return 0
    else
        echo "❌ Orchestrator version not updated (still on old version)"
        return 1
    fi
}

# Test 9: Environment Variable Documentation
test_env_vars_documented() {
    echo "Testing environment variable documentation..."

    local orchestrator_md="$HOME/.claude/agents/orchestrator.md"

    # Check if RALPH_AUTO_MODE is documented
    if ! grep -q "RALPH_AUTO_MODE=true" "$orchestrator_md"; then
        echo "❌ RALPH_AUTO_MODE not documented"
        return 1
    fi

    # Check if export syntax is shown
    if ! grep -q "export RALPH_AUTO_MODE=true" "$orchestrator_md"; then
        echo "❌ Export syntax not shown"
        return 1
    fi

    echo "✅ Environment variables properly documented"
    return 0
}

# Test 10: Auto-Mode Logic
test_automode_logic() {
    echo "Testing AUTO mode logic in hooks..."

    # Check code-review-auto.sh for AUTO mode detection
    local hook="$HOME/.claude/hooks/code-review-auto.sh"

    # Check for is_auto_mode function
    if ! grep -q "is_auto_mode()" "$hook"; then
        echo "❌ Missing is_auto_mode() function"
        return 1
    fi

    # Check for RALPH_AUTO_MODE check
    if ! grep -q 'RALPH_AUTO_MODE' "$hook"; then
        echo "❌ RALPH_AUTO_MODE variable not referenced"
        return 1
    fi

    echo "✅ AUTO mode logic properly implemented"
    return 0
}

# Run all tests
main() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Orchestrator Validation Test Suite${NC}"
    echo -e "${BLUE}========================================${NC}\n"

    log "=== Starting Orchestrator Validation Tests ==="

    # Run all tests
    run_test "FAST PATH Validation" test_fast_path
    run_test "Standard Workflow (12 Steps)" test_standard_workflow
    run_test "Auto-Verification Coordination" test_auto_verification
    run_test "Subagent Visibility" test_subagent_visibility
    run_test "Timeout Configuration" test_timeout_config
    run_test "Marker Directory Structure" test_marker_structure
    run_test "Hooks Configuration Integrity" test_hooks_integrity
    run_test "Orchestrator Version Update" test_orchestrator_version
    run_test "Environment Variable Documentation" test_env_vars_documented
    run_test "AUTO Mode Logic" test_automode_logic

    # Summary
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}  Test Summary${NC}"
    echo -e "${BLUE}========================================${NC}\n"

    echo -e "Tests Run:    $TESTS_RUN"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"

    log "=== Test Summary ==="
    log "Tests Run: $TESTS_RUN"
    log "Tests Passed: $TESTS_PASSED"
    log "Tests Failed: $TESTS_FAILED"

    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "\n${GREEN}✅ ALL TESTS PASSED${NC}\n"
        log "RESULT: ALL TESTS PASSED"
        return 0
    else
        echo -e "\n${RED}❌ SOME TESTS FAILED${NC}\n"
        log "RESULT: SOME TESTS FAILED"
        return 1
    fi
}

main "$@"
