#!/bin/bash
# Quick validation test for Intelligent Command Router
# VERSION: 1.0.0

echo "════════════════════════════════════════════════════════════════"
echo "  Intelligent Command Router - Quick Validation Test"
echo "════════════════════════════════════════════════════════════════"
echo ""

HOOK_SCRIPT="$(dirname "$0")/../.claude/hooks/command-router.sh"

# Test cases with expected results (using index-based arrays for compatibility)
TEST_PROMPTS=(
    "Tengo un bug en el login"
    "Define una feature para búsqueda"
    "Implementa autenticación OAuth y luego agrega tokens"
    "Itera hasta que pasen los tests"
    "Refina esta especificación y valida los edge cases"
    "Ejecuta quality gates para validar"
    "Audita la seguridad del módulo"
    "Haz una revisión comprehensiva de múltiples aspectos"
    "Haz un audit de calidad del proyecto"
    "Hola que tal"
)

TEST_EXPECTED=(
    "bug"
    "edd"
    "orchestrator"
    "loop"
    "adversarial"
    "gates"
    "security"
    "parallel"
    "audit"
    "none"
)

PASSED=0
FAILED=0

# Run tests
for i in "${!TEST_PROMPTS[@]}"; do
    prompt="${TEST_PROMPTS[$i]}"
    expected="${TEST_EXPECTED[$i]}"
    echo "Testing: $prompt"
    echo "Expected: $expected"

    result=$(echo "{\"user_prompt\": \"$prompt\"}" | "$HOOK_SCRIPT" 2>&1)

    # Extract command from suggestion (using sed for macOS compatibility)
    if echo "$result" | grep -q "additionalContext"; then
        detected=$(echo "$result" | sed -n 's/.*`\/\([a-z]*\)`.*/\1/p')
        if [[ "$detected" == "$expected" ]]; then
            echo -e "  ✅ PASS: Detected /$detected\n"
            ((PASSED++))
        else
            echo -e "  ⚠️  MISMATCH: Expected /$expected, got /$detected"
            echo "  Result: $result\n"
            ((FAILED++))
        fi
    else
        if [[ "$expected" == "none" ]]; then
            echo -e "  ✅ PASS: No suggestion (as expected)\n"
            ((PASSED++))
        else
            echo -e "  ❌ FAIL: Expected /$expected, but got no suggestion"
            echo "  Result: $result\n"
            ((FAILED++))
        fi
    fi
done

echo "════════════════════════════════════════════════════════════════"
echo "  Results: $PASSED passed, $FAILED failed"
echo "════════════════════════════════════════════════════════════════"

if [[ $FAILED -eq 0 ]]; then
    echo -e "\n✅ All tests passed!"
    exit 0
else
    echo -e "\n❌ Some tests failed"
    exit 1
fi
