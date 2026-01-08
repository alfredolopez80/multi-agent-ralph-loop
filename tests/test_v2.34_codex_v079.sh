#!/usr/bin/env bash
# Test suite for Codex CLI v0.79.0 integration (v2.34)

set -euo pipefail

PASSED=0
FAILED=0
TOTAL=0

test_pass() {
    ((PASSED++))
    ((TOTAL++))
    echo "✅ PASS: $1"
}

test_fail() {
    ((FAILED++))
    ((TOTAL++))
    echo "❌ FAIL: $1"
}

# Test 1: Codex version
echo "Test: Codex CLI version is 0.79.0"
VERSION=$(codex --version 2>&1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" || echo "not found")
if [[ "$VERSION" == "0.79.0" ]]; then
    test_pass "Codex version is 0.79.0"
else
    test_fail "Codex version is $VERSION, expected 0.79.0"
fi

# Test 2: Config has safe defaults
echo "Test: ~/.codex/config.toml has safe defaults"
if grep -q "approval_policy.*=.*\"on-request\"" ~/.codex/config.toml && \
   grep -q "sandbox_mode.*=.*\"workspace-write\"" ~/.codex/config.toml; then
    test_pass "Config has safe defaults"
else
    test_fail "Config does not have safe defaults"
fi

# Test 3: Security audit profile exists
echo "Test: [profiles.security-audit] exists in config"
if grep -q "\[profiles\.security-audit\]" ~/.codex/config.toml; then
    test_pass "security-audit profile exists"
else
    test_fail "security-audit profile missing"
fi

# Test 4: Bug hunting profile exists
echo "Test: [profiles.bug-hunting] exists in config"
if grep -q "\[profiles\.bug-hunting\]" ~/.codex/config.toml; then
    test_pass "bug-hunting profile exists"
else
    test_fail "bug-hunting profile missing"
fi

# Test 5: Code review profile exists
echo "Test: [profiles.code-review] exists in config"
if grep -q "\[profiles\.code-review\]" ~/.codex/config.toml; then
    test_pass "code-review profile exists"
else
    test_fail "code-review profile missing"
fi

# Test 6: Unit tests profile exists
echo "Test: [profiles.unit-tests] exists in config"
if grep -q "\[profiles\.unit-tests\]" ~/.codex/config.toml; then
    test_pass "unit-tests profile exists"
else
    test_fail "unit-tests profile missing"
fi

# Test 7: CI/CD profile exists
echo "Test: [profiles.ci-cd] exists in config"
if grep -q "\[profiles\.ci-cd\]" ~/.codex/config.toml; then
    test_pass "ci-cd profile exists"
else
    test_fail "ci-cd profile missing"
fi

# Test 8: Schemas directory exists
echo "Test: ~/.ralph/schemas/ directory exists"
if [[ -d ~/.ralph/schemas/ ]]; then
    test_pass "Schemas directory exists"
else
    test_fail "Schemas directory missing"
fi

# Test 9: Security schema is valid JSON
echo "Test: security-output.json is valid JSON"
if [[ -f ~/.ralph/schemas/security-output.json ]] && jq empty ~/.ralph/schemas/security-output.json 2>/dev/null; then
    test_pass "security-output.json is valid"
else
    test_fail "security-output.json is invalid or missing"
fi

# Test 10: Bugs schema is valid JSON
echo "Test: bugs-output.json is valid JSON"
if [[ -f ~/.ralph/schemas/bugs-output.json ]] && jq empty ~/.ralph/schemas/bugs-output.json 2>/dev/null; then
    test_pass "bugs-output.json is valid"
else
    test_fail "bugs-output.json is invalid or missing"
fi

# Test 11: Tests schema is valid JSON
echo "Test: tests-output.json is valid JSON"
if [[ -f ~/.ralph/schemas/tests-output.json ]] && jq empty ~/.ralph/schemas/tests-output.json 2>/dev/null; then
    test_pass "tests-output.json is valid"
else
    test_fail "tests-output.json is invalid or missing"
fi

# Test 12: ralph script has no --yolo usage
echo "Test: scripts/ralph does not use deprecated --yolo flag"
if ! grep -q "codex.*--yolo\|--yolo.*codex" scripts/ralph 2>/dev/null; then
    test_pass "No --yolo usage found in ralph"
else
    YOLO_COUNT=$(grep -c "codex.*--yolo\|--yolo.*codex" scripts/ralph || echo 0)
    test_fail "Found $YOLO_COUNT --yolo usages (should be 0)"
fi

# Test 13: Agents have no --yolo usage
echo "Test: .claude/agents/*.md files do not use --yolo flag"
if ! grep -q "codex.*--yolo\|--yolo.*codex" .claude/agents/*.md 2>/dev/null; then
    test_pass "No --yolo usage in agents"
else
    YOLO_COUNT=$(grep -c "codex.*--yolo\|--yolo.*codex" .claude/agents/*.md | grep -v ":0" | wc -l || echo 0)
    test_fail "Found --yolo in $YOLO_COUNT agent files"
fi

# Test 14: Skills have no --yolo usage
echo "Test: .codex/skills/*.md files do not use --yolo flag"
if ! grep -q "codex.*--yolo\|--yolo.*codex" .codex/skills/*.md 2>/dev/null; then
    test_pass "No --yolo usage in skills"
else
    YOLO_COUNT=$(grep -c "codex.*--yolo\|--yolo.*codex" .codex/skills/*.md | grep -v ":0" | wc -l || echo 0)
    test_fail "Found --yolo in $YOLO_COUNT skill files"
fi

# Test 15: Features list works
echo "Test: codex features list works"
if codex features list &>/dev/null; then
    test_pass "codex features list works"
else
    test_fail "codex features list failed"
fi

# Test 16: Skills feature is enabled
echo "Test: skills feature is enabled"
if codex features list 2>&1 | grep -q "skills"; then
    test_pass "skills feature found in features list"
else
    test_fail "skills feature not found"
fi

# Test 17: init_codex_schemas function exists in ralph
echo "Test: init_codex_schemas() function exists in scripts/ralph"
if grep -q "^init_codex_schemas()" scripts/ralph; then
    test_pass "init_codex_schemas() function exists"
else
    test_fail "init_codex_schemas() function missing"
fi

# Test 18: init_codex_schemas is called from startup_validation
echo "Test: init_codex_schemas is called from startup_validation()"
if grep -A 10 "^startup_validation()" scripts/ralph | grep -q "init_codex_schemas"; then
    test_pass "init_codex_schemas called from startup_validation"
else
    test_fail "init_codex_schemas not called from startup_validation"
fi

# Test 19: .codex/instructions.md mentions v0.79.0
echo "Test: .codex/instructions.md references v0.79.0"
if grep -q "0\.79\.0" .codex/instructions.md; then
    test_pass ".codex/instructions.md mentions v0.79.0"
else
    test_fail ".codex/instructions.md does not mention v0.79.0"
fi

# Test 20: Config backup exists
echo "Test: Config backup file exists (pre-v2.34)"
if [[ -f ~/.codex/config.toml.backup-pre-v2.34 ]]; then
    test_pass "Config backup exists"
else
    test_fail "Config backup missing (not critical)"
fi

# Results
echo ""
echo "==========================================="
echo "  TEST RESULTS"
echo "==========================================="
echo "  PASSED: $PASSED"
echo "  FAILED: $FAILED"
echo "  TOTAL:  $TOTAL"
echo "==========================================="

if [[ $FAILED -eq 0 ]]; then
    echo "✅ ALL TESTS PASSED"
    exit 0
else
    echo "❌ $FAILED TESTS FAILED"
    exit 1
fi
