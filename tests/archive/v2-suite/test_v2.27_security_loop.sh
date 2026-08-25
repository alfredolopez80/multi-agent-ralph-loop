#!/usr/bin/env bash
# v2.27 Test Suite - Multi-Level Security Loop
# Tests security loop functions, CLI commands, and slash commands

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

# Test 1: Ralph script version is 2.27.0
test_version() {
    if grep -q 'VERSION="2.27.0"' "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Ralph script has VERSION=2.27.0"
    else
        test_fail "Ralph script should have VERSION=2.27.0"
    fi
}
test_version

# Test 2: CLAUDE.md references v2.27
test_claude_md_version() {
    if grep -q "v2.27" "$PROJECT_ROOT/CLAUDE.md"; then
        test_pass "CLAUDE.md references v2.27"
    else
        test_fail "CLAUDE.md should reference v2.27"
    fi
}
test_claude_md_version

# Test 3: README.md references v2.27
test_readme_version() {
    if grep -q "2.27" "$PROJECT_ROOT/README.md"; then
        test_pass "README.md references v2.27"
    else
        test_fail "README.md should reference v2.27"
    fi
}
test_readme_version

# Test 4: CHANGELOG.md exists
test_changelog_exists() {
    if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
        test_pass "CHANGELOG.md exists"
    else
        test_fail "CHANGELOG.md does not exist"
    fi
}
test_changelog_exists

# Test 5: CHANGELOG.md has v2.27 entry
test_changelog_v227() {
    if grep -q "\[2.27.0\]" "$PROJECT_ROOT/CHANGELOG.md"; then
        test_pass "CHANGELOG.md has v2.27.0 entry"
    else
        test_fail "CHANGELOG.md should have v2.27.0 entry"
    fi
}
test_changelog_v227

# ============================================================================
# Test Group 2: Security Loop Functions
# ============================================================================

echo ""
echo "=== Group 2: Security Loop Functions ==="

# Test 6: parse_security_findings() exists
test_parse_function() {
    if grep -q "^parse_security_findings()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "parse_security_findings() function exists"
    else
        test_fail "parse_security_findings() function not found"
    fi
}
test_parse_function

# Test 7: fix_security_issues() exists
test_fix_function() {
    if grep -q "^fix_security_issues()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "fix_security_issues() function exists"
    else
        test_fail "fix_security_issues() function not found"
    fi
}
test_fix_function

# Test 8: validate_fixes() exists
test_validate_function() {
    if grep -q "^validate_fixes()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "validate_fixes() function exists"
    else
        test_fail "validate_fixes() function not found"
    fi
}
test_validate_function

# Test 9: cmd_security_loop() exists
test_cmd_security_loop() {
    if grep -q "^cmd_security_loop()" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "cmd_security_loop() function exists"
    else
        test_fail "cmd_security_loop() function not found"
    fi
}
test_cmd_security_loop

# Test 10: security-loop calls require_tool for codex
test_require_codex() {
    if grep -A30 "cmd_security_loop()" "$PROJECT_ROOT/scripts/ralph" | grep -q 'require_tool.*codex'; then
        test_pass "security-loop calls require_tool for codex"
    else
        test_fail "security-loop should call require_tool for codex"
    fi
}
test_require_codex

# ============================================================================
# Test Group 3: CLI Command Registration
# ============================================================================

echo ""
echo "=== Group 3: CLI Command Registration ==="

# Test 11: security-loop case exists in main()
test_cli_case_securityloop() {
    if grep -q "security-loop|secloop)" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "security-loop CLI case exists"
    else
        test_fail "security-loop CLI case not found"
    fi
}
test_cli_case_securityloop

# Test 12: --max-rounds flag handling
test_max_rounds_flag() {
    if grep -q "\-\-max-rounds" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "--max-rounds flag is handled"
    else
        test_fail "--max-rounds flag handling not found"
    fi
}
test_max_rounds_flag

# Test 13: --yolo flag handling
test_yolo_flag() {
    if grep -q "\-\-yolo" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "--yolo flag is handled"
    else
        test_fail "--yolo flag handling not found"
    fi
}
test_yolo_flag

# Test 14: --strict flag handling
test_strict_flag() {
    if grep -q "\-\-strict" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "--strict flag is handled"
    else
        test_fail "--strict flag handling not found"
    fi
}
test_strict_flag

# Test 15: --hybrid flag handling
test_hybrid_flag() {
    if grep -q "\-\-hybrid" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "--hybrid flag is handled"
    else
        test_fail "--hybrid flag handling not found"
    fi
}
test_hybrid_flag

# ============================================================================
# Test Group 4: Slash Command
# ============================================================================

echo ""
echo "=== Group 4: Slash Command ==="

# Test 16: /security-loop command file exists
test_slash_command_exists() {
    if [ -f "$PROJECT_ROOT/.claude/commands/security-loop.md" ]; then
        test_pass "/security-loop command file exists"
    else
        test_fail "/security-loop command file does not exist"
    fi
}
test_slash_command_exists

# Test 17: Command has @secloop prefix
test_secloop_prefix() {
    if [ -f "$PROJECT_ROOT/.claude/commands/security-loop.md" ]; then
        local prefix=$(grep "^prefix:" "$PROJECT_ROOT/.claude/commands/security-loop.md" | awk '{print $2}' | tr -d '"')
        if [ "$prefix" = "@secloop" ]; then
            test_pass "/security-loop has @secloop prefix"
        else
            test_fail "/security-loop should have @secloop prefix, got: $prefix"
        fi
    else
        test_fail "/security-loop file not found"
    fi
}
test_secloop_prefix

# Test 18: Command is in review category
test_secloop_category() {
    if [ -f "$PROJECT_ROOT/.claude/commands/security-loop.md" ]; then
        if grep -q "category: review" "$PROJECT_ROOT/.claude/commands/security-loop.md"; then
            test_pass "/security-loop is in review category"
        else
            test_fail "/security-loop should be in review category"
        fi
    else
        test_fail "/security-loop file not found"
    fi
}
test_secloop_category

# Test 19: Command has red color
test_secloop_color() {
    if [ -f "$PROJECT_ROOT/.claude/commands/security-loop.md" ]; then
        if grep -q "color: red" "$PROJECT_ROOT/.claude/commands/security-loop.md"; then
            test_pass "/security-loop has red color"
        else
            test_fail "/security-loop should have red color"
        fi
    else
        test_fail "/security-loop file not found"
    fi
}
test_secloop_color

# ============================================================================
# Test Group 5: README Structure
# ============================================================================

echo ""
echo "=== Group 5: README Structure ==="

# Test 20: README has Overview section
test_readme_overview() {
    if grep -q "^## Overview" "$PROJECT_ROOT/README.md"; then
        test_pass "README has Overview section"
    else
        test_fail "README should have Overview section"
    fi
}
test_readme_overview

# Test 21: README has Key Features section
test_readme_features() {
    if grep -q "^## Key Features" "$PROJECT_ROOT/README.md"; then
        test_pass "README has Key Features section"
    else
        test_fail "README should have Key Features section"
    fi
}
test_readme_features

# Test 22: README has Core Workflows section
test_readme_workflows() {
    if grep -q "^## Core Workflows" "$PROJECT_ROOT/README.md"; then
        test_pass "README has Core Workflows section"
    else
        test_fail "README should have Core Workflows section"
    fi
}
test_readme_workflows

# Test 23: README references CHANGELOG.md
test_readme_changelog_ref() {
    if grep -q "CHANGELOG.md" "$PROJECT_ROOT/README.md"; then
        test_pass "README references CHANGELOG.md"
    else
        test_fail "README should reference CHANGELOG.md"
    fi
}
test_readme_changelog_ref

# ============================================================================
# Test Group 6: Security Loop Logic
# ============================================================================

echo ""
echo "=== Group 6: Security Loop Logic ==="

# Test 24: Default max rounds is 10
test_default_max_rounds() {
    if grep -q 'MAX_ROUNDS="${2:-10}"' "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Default max rounds is 10"
    else
        test_fail "Default max rounds should be 10"
    fi
}
test_default_max_rounds

# Test 25: Default approval mode is hybrid
test_default_approval_mode() {
    if grep -q 'APPROVAL_MODE="${3:-hybrid}"' "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Default approval mode is hybrid"
    else
        test_fail "Default approval mode should be hybrid"
    fi
}
test_default_approval_mode

# Test 26: Loop checks for 0 vulnerabilities
test_zero_vuln_check() {
    if grep -q 'if \[ "\$COUNT" -eq 0 \]' "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Loop checks for 0 vulnerabilities"
    else
        test_fail "Loop should check for 0 vulnerabilities"
    fi
}
test_zero_vuln_check

# Test 27: Codex is used for security audit
test_codex_audit() {
    if grep -A70 "cmd_security_loop()" "$PROJECT_ROOT/scripts/ralph" | grep -q "codex exec"; then
        test_pass "Codex is used for security audit"
    else
        test_fail "Security loop should use Codex for audit"
    fi
}
test_codex_audit

# Test 28: CWE references in audit prompt
test_cwe_references() {
    if grep -q "CWE-78\|CWE-89\|CWE-22" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "CWE references in audit prompt"
    else
        test_fail "Audit prompt should reference CWEs"
    fi
}
test_cwe_references

# ============================================================================
# Test Group 7: Hybrid Mode Logic
# ============================================================================

echo ""
echo "=== Group 7: Hybrid Mode Logic ==="

# Test 29: Hybrid mode auto-fixes MEDIUM/LOW
test_hybrid_auto_fix() {
    if grep -q "Auto-fixing.*MEDIUM/LOW" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Hybrid mode auto-fixes MEDIUM/LOW"
    else
        test_fail "Hybrid mode should auto-fix MEDIUM/LOW"
    fi
}
test_hybrid_auto_fix

# Test 30: Hybrid mode asks for CRITICAL/HIGH
test_hybrid_manual_approval() {
    if grep -q "CRITICAL/HIGH.*require manual approval\|MANUAL_APPROVAL_REQUIRED" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Hybrid mode asks for CRITICAL/HIGH approval"
    else
        test_fail "Hybrid mode should ask for CRITICAL/HIGH approval"
    fi
}
test_hybrid_manual_approval

# Test 31: YOLO mode auto-fixes all
test_yolo_mode() {
    if grep -q "YOLO mode: Auto-fixing all" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "YOLO mode auto-fixes all"
    else
        test_fail "YOLO mode should auto-fix all"
    fi
}
test_yolo_mode

# Test 32: Strict mode requires manual approval
test_strict_mode() {
    if grep -q "STRICT mode: Manual approval required\|STRICT_MODE_APPROVAL_REQUIRED" "$PROJECT_ROOT/scripts/ralph"; then
        test_pass "Strict mode requires manual approval"
    else
        test_fail "Strict mode should require manual approval"
    fi
}
test_strict_mode

# ============================================================================
# Summary
# ============================================================================

echo ""
echo "=============================================="
echo "v2.27 Security Loop Test Suite Summary"
echo "=============================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo -e "Total:  $TOTAL"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
