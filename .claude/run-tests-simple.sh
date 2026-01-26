#!/bin/bash
# run-tests-simple.sh - Ejecutar tests básicos de validación
# VERSION: 1.0.0
#
# Este script ejecuta tests esenciales para validar el workflow /orchestrator
# sin depender de herramientas CLI externas

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Tests Esenciales /orchestrator${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_function="$2"

    TESTS_RUN=$((TESTS_RUN + 1))
    echo -e "${YELLOW}[$TESTS_RUN]${NC} $test_name"

    if $test_function; then
        echo -e "${GREEN}✅ PASSED${NC}\n"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}\n"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test 1: Timeout Configuration
test_timeout() {
    local timeout=$(jq '.hooks.PreToolUse[] | select(.matcher == "Task") | .hooks[] | select(.command | contains("smart-memory-search")) | .timeout' ~/.claude/settings.json 2>/dev/null || echo "30")

    if [[ "$timeout" -le 15 ]]; then
        echo "Timeout: ${timeout}s (correcto, ≤15s)"
        return 0
    else
        echo "Timeout: ${timeout}s (incorrecto, debe ser ≤15s)"
        return 1
    fi
}

# Test 2: Orchestrator Version Update
test_orchestrator_version() {
    local orchestrator_md="$HOME/.claude/agents/orchestrator.md"

    if grep -q "v2.70.1" "$orchestrator_md"; then
        echo "Orchestrator actualizado a v2.70.1"
        return 0
    else
        echo "Orchestrator no actualizado a v2.70.1"
        return 1
    fi
}

# Test 3: Auto-Verification Hook Exists
test_auto_verification_hook() {
    local hook="$HOME/.claude/hooks/auto-verification-coordinator.sh"

    if [[ -f "$hook" ]]; then
        echo "Hook auto-verification-coordinator.sh existe"
    else
        echo "Hook auto-verification-coordinator.sh NO existe"
        return 1
    fi

    if [[ -x "$hook" ]]; then
        echo "Hook es ejecutable"
    else
        echo "Hook NO es ejecutable"
        return 1
    fi

    # Test basic execution
    echo '{}' | timeout 5s bash "$hook" >/dev/null 2>&1
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        echo "Hook ejecuta correctamente"
        return 0
    else
        echo "Hook retornó error: $exit_code"
        return 1
    fi
}

# Test 4: Auto-Verification Hook Registered
test_auto_verification_registered() {
    if jq -e '.hooks.PostToolUse[]? | map(select(.matcher == "TaskUpdate")) | any(.hooks[]?.command | contains("auto-verification-coordinator"))' ~/.claude/settings.json 2>/dev/null; then
        echo "Hook registrado en settings.json"
        return 0
    else
        echo "Hook NO registrado en settings.json"
        return 1
    fi
}

# Test 5: Subagent Visibility Hook Exists
test_subagent_visibility_hook() {
    local hook="$HOME/.claude/hooks/subagent-visibility.sh"

    if [[ -f "$hook" ]]; then
        echo "Hook subagent-visibility.sh existe"
    else
        echo "Hook subagent-visibility.sh NO existe"
        return 1
    fi

    if [[ -x "$hook" ]]; then
        echo "Hook es ejecutable"
    else
        echo "Hook NO es ejecutable"
        return 1
    fi
}

# Test 6: Subagent Visibility Hook Registered
test_subagent_visibility_registered() {
    if jq -e '.hooks.PostToolUse[]? | map(select(.matcher == "Task|TaskUpdate")) | any(.hooks[]?.command | contains("subagent-visibility"))' ~/.claude/settings.json 2>/dev/null; then
        echo "Hook registrado en settings.json"
        return 0
    else
        echo "Hook NO registrado en settings.json"
        return 1
    fi
}

# Test 7: Marker Directory
test_marker_directory() {
    local markers_dir="$HOME/.ralph/markers"

    if [[ -d "$markers_dir" ]]; then
        echo "Directorio de marcadores existe: $markers_dir"
        return 0
    else
        echo "Directorio de marcadores NO existe"
        return 1
    fi
}

# Test 8: AUTO MODE Documented
test_auto_mode_documented() {
    local orchestrator_md="$HOME/.claude/agents/orchestrator.md"

    if grep -q "RALPH_AUTO_MODE=true" "$orchestrator_md"; then
        echo "RALPH_AUTO_MODE=documentado en orchestrator.md"
        return 0
    else
        echo "RALPH_AUTO_MODE NO documentado en orchestrator.md"
        return 1
    fi
}

# Test 9: Auto-Verification Flow Documented
test_auto_verification_flow_documented() {
    local orchestrator_md="$HOME/.claude/agents/orchestrator.md"

    if grep -q "Auto-Verification Flow" "$orchestrator_md"; then
        echo "Flujo de auto-verificación documentado"
        return 0
    else
        echo "Flujo de auto-verificación NO documentado"
        return 1
    fi
}

# Test 10: Critical Hooks Present
test_critical_hooks() {
    local hooks_dir="$HOME/.claude/hooks"
    local critical_hooks=(
        "smart-memory-search.sh"
        "code-review-auto.sh"
        "verification-subagent.sh"
        "quality-gates-v2.sh"
    )

    local missing_hooks=()

    for hook in "${critical_hooks[@]}"; do
        if [[ ! -f "$hooks_dir/$hook" ]]; then
            missing_hooks+=("$hook")
        fi
    done

    if [[ ${#missing_hooks[@]} -eq 0 ]]; then
        echo "Todos los hooks críticos están presentes"
        return 0
    else
        echo "Hooks críticos faltantes: ${missing_hooks[*]}"
        return 1
    fi
}

# Run all tests
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Ejecutando Tests${NC}"
echo -e "${BLUE}========================================${NC}\n"

run_test "1. Timeout Configuration" test_timeout
run_test "2. Orchestrator Version" test_orchestrator_version
run_test "3. Auto-Verification Hook Exists" test_auto_verification_hook
run_test "4. Auto-Verification Hook Registered" test_auto_verification_registered
run_test "5. Subagent Visibility Hook Exists" test_subagent_visibility_hook
run_test "6. Subagent Visibility Hook Registered" test_subagent_visibility_registered
run_test "7. Marker Directory" test_marker_directory
run_test "8. AUTO MODE Documented" test_auto_mode_documented
run_test "9. Auto-Verification Flow Documented" test_auto_verification_flow_documented
run_test "10. Critical Hooks Present" test_critical_hooks

# Summary
echo -e "\n${BLUE}========================================${NC}"
echo -e "${BLUE}  Resumen${NC}"
echo -e "${BLUE}========================================${NC}\n"

echo -e "Tests Ejecutados: $TESTS_RUN"
echo -e "Tests Pasados:  ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Fallados:  ${RED}$TESTS_FAILED${NC}"
echo -e ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}✅✅✅ TODOS LOS TESTS PASARON ✅✅✅${NC}\n"
    echo -e "${GREEN}El workflow /orchestrator está correctamente configurado${NC}"
    exit 0
else
    echo -e "${RED}❌ ALGUNOS TESTS FALLARON ❌${NC}\n"
    exit 1
fi
