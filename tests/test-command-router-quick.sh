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

# After Promptify integration in the Command Router hook (the hook now emits
# /promptify suggestions for vague prompts), the "Hola que tal" case correctly
# triggers a Promptify suggestion. The expectation is updated to match the
# new (deliberate) behavior, not to mask a bug. The other 9 cases still
# validate Command Router detection.
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
    "promptify"
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

    # Extract command from suggestion. The hook may emit multiple
    # backtick-delimited /cmd suggestions (Command Router + Promptify, etc.),
    # so we take the FIRST one — Command Router runs before Promptify in the
    # hook, so the first /cmd is always the Command Router suggestion when
    # it has one. grep -oE avoids the sed-greedy trap that used to pick up
    # only /promptify.
    if echo "$result" | grep -q "additionalContext"; then
        detected=$(echo "$result" | grep -oE '`/[a-z]+`' | head -1 | sed 's/[`/]//g')
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


# T94: zero-tests guard — fail loud when no assertion ran. Without
# this check, a broken collection that increments zero counters would
# print 'All tests passed!' and exit 0. Mirrors the canonic pattern in
# tests/unit/test_validation_common.sh (lines 56-58).
if [[ $PASSED -eq 0 && $FAILED -eq 0 ]]; then
    echo "FATAL: zero tests executed — cannot declare success" >&2
    exit 1
fi
if [[ $FAILED -eq 0 ]]; then
    echo -e "\n✅ All tests passed!"
    exit 0
else
    echo -e "\n❌ Some tests failed"
    exit 1
fi
