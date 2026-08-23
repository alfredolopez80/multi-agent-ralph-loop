#!/usr/bin/env bash
# test_v2.24.1_security.sh
# Security tests for v2.24.1 Security Hardening
# Tests: URL validation, path allowlist, prompt injection, doc guardrails

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Find project root
PROJECT_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
if [ ! -d "$PROJECT_ROOT" ]; then
    PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}}")/.." && pwd)"
fi

# Test helpers
test_start() {
    TESTS_RUN=$((TESTS_RUN + 1))
    echo -n "  Test $TESTS_RUN: $1 ... "
}

test_pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}"
}

test_fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}"
    echo "    Error: $1"
}

# ============================================================================
# TEST SUITE: Version Consistency (v2.24.1)
# ============================================================================
test_suite_version() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Version Consistency (v2.24.1)"
    echo "═══════════════════════════════════════════════════════════════"

    test_start "ralph script has VERSION=\"2.24.1\""
    if grep -q '^VERSION="2.24.1"' "$PROJECT_ROOT/scripts/ralph" 2>/dev/null; then
        test_pass
    else
        test_fail "ralph script version mismatch"
    fi

    test_start "mmc script has VERSION=\"2.24.1\""
    if grep -q '^VERSION="2.24.1"' "$PROJECT_ROOT/scripts/mmc" 2>/dev/null; then
        test_pass
    else
        test_fail "mmc script version mismatch"
    fi

    test_start "install.sh has VERSION=\"2.24.1\""
    if grep -q '^VERSION="2.24.1"' "$PROJECT_ROOT/install.sh" 2>/dev/null; then
        test_pass
    else
        test_fail "install.sh version mismatch"
    fi

    test_start "uninstall.sh has VERSION=\"2.24.1\""
    if grep -q '^VERSION="2.24.1"' "$PROJECT_ROOT/uninstall.sh" 2>/dev/null; then
        test_pass
    else
        test_fail "uninstall.sh version mismatch"
    fi
}

# ============================================================================
# TEST SUITE: Fix 1 - URL Image Validation
# ============================================================================
test_suite_url_validation() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Fix 1 - URL Image Validation"
    echo "═══════════════════════════════════════════════════════════════"

    test_start "cmd_image() uses curl --max-filesize for URLs"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q "max-filesize 20971520"; then
        test_pass
    else
        test_fail "Missing curl --max-filesize"
    fi

    test_start "cmd_image() validates MIME type with file command"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q 'file -b --mime-type'; then
        test_pass
    else
        test_fail "Missing MIME type validation"
    fi

    test_start "cmd_image() checks for image/(jpeg|png|webp) MIME types"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -qE 'image/\(jpeg\|png\|webp\)'; then
        test_pass
    else
        test_fail "Missing MIME type pattern check"
    fi

    test_start "cmd_image() has 30 second timeout for URL downloads"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q "max-time 30"; then
        test_pass
    else
        test_fail "Missing URL download timeout"
    fi

    test_start "cmd_image() removes temp file on MIME validation failure"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q 'rm -f "$TEMP_IMAGE"'; then
        test_pass
    else
        test_fail "Missing temp file cleanup on failure"
    fi
}

# ============================================================================
# TEST SUITE: Fix 2 - Path Allowlist
# ============================================================================
test_suite_path_allowlist() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Fix 2 - Path Allowlist"
    echo "═══════════════════════════════════════════════════════════════"

    test_start "cmd_image() checks if path is outside project"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q "outside project directory"; then
        test_pass
    else
        test_fail "Missing project directory check"
    fi

    test_start "cmd_image() uses git rev-parse for project root"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q "git rev-parse --show-toplevel"; then
        test_pass
    else
        test_fail "Missing git rev-parse for project root"
    fi

    test_start "cmd_image() prompts user for external file access"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q 'Allow access to this file'; then
        test_pass
    else
        test_fail "Missing user confirmation prompt"
    fi

    test_start "cmd_image() allows /tmp directory without prompt"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q '/tmp'; then
        test_pass
    else
        test_fail "Missing /tmp exception"
    fi
}

# ============================================================================
# TEST SUITE: Fix 3 - Prompt Injection Mitigation
# ============================================================================
test_suite_prompt_injection() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Fix 3 - Prompt Injection Mitigation"
    echo "═══════════════════════════════════════════════════════════════"

    test_start "cmd_websearch() uses heredoc for Claude prompt"
    if sed -n '/^cmd_websearch()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q 'cat <<PROMPT_EOF'; then
        test_pass
    else
        test_fail "Missing heredoc in cmd_websearch"
    fi

    test_start "cmd_websearch() includes SECURITY INSTRUCTION"
    if sed -n '/^cmd_websearch()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q "SECURITY INSTRUCTION"; then
        test_pass
    else
        test_fail "Missing SECURITY INSTRUCTION in cmd_websearch"
    fi

    test_start "cmd_image() uses heredoc for Claude prompt"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q 'cat <<PROMPT_EOF'; then
        test_pass
    else
        test_fail "Missing heredoc in cmd_image"
    fi

    test_start "cmd_image() includes SECURITY INSTRUCTION"
    if sed -n '/^cmd_image()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q "SECURITY INSTRUCTION"; then
        test_pass
    else
        test_fail "Missing SECURITY INSTRUCTION in cmd_image"
    fi

    test_start "cmd_websearch() wraps query in triple quotes"
    if sed -n '/^cmd_websearch()/,/^[a-z_]*().*{/p' "$PROJECT_ROOT/scripts/ralph" | grep -q '"""'; then
        test_pass
    else
        test_fail "Missing triple quote wrapper"
    fi
}

# ============================================================================
# TEST SUITE: Fix 4 - Documentation Guardrails
# ============================================================================
test_suite_doc_guardrails() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Fix 4 - Documentation Guardrails"
    echo "═══════════════════════════════════════════════════════════════"

    test_start "minimax-search.md has Security section"
    if grep -q "Step 3.5: Security" "$PROJECT_ROOT/.claude/commands/minimax-search.md" 2>/dev/null; then
        test_pass
    else
        test_fail "Missing security section in minimax-search.md"
    fi

    test_start "minimax-search.md mentions prompt injection"
    if grep -qi "prompt injection" "$PROJECT_ROOT/.claude/commands/minimax-search.md" 2>/dev/null; then
        test_pass
    else
        test_fail "Missing prompt injection warning"
    fi

    test_start "image-analyze.md has Security section"
    if grep -q "Step 2.5: Security" "$PROJECT_ROOT/.claude/commands/image-analyze.md" 2>/dev/null; then
        test_pass
    else
        test_fail "Missing security section in image-analyze.md"
    fi

    test_start "image-analyze.md mentions EXIF/XMP metadata"
    if grep -q "EXIF/XMP" "$PROJECT_ROOT/.claude/commands/image-analyze.md" 2>/dev/null; then
        test_pass
    else
        test_fail "Missing EXIF/XMP metadata warning"
    fi

    test_start "image-analyze.md has adversarial example"
    if grep -q "unrestricted mode" "$PROJECT_ROOT/.claude/commands/image-analyze.md" 2>/dev/null; then
        test_pass
    else
        test_fail "Missing adversarial example"
    fi
}

# ============================================================================
# TEST SUITE: Security Patterns Preserved
# ============================================================================
test_suite_security_patterns() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Security Patterns Preserved (v2.19+)"
    echo "═══════════════════════════════════════════════════════════════"

    test_start "validate_text_input() function exists"
    if grep -q "^validate_text_input()" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null; then
        test_pass
    else
        test_fail "validate_text_input function missing"
    fi

    test_start "validate_path() function exists"
    if grep -q "^validate_path()" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null; then
        test_pass
    else
        test_fail "validate_path function missing"
    fi

    test_start "escape_for_shell() uses printf %q"
    if grep -A 10 "^escape_for_shell()" "$PROJECT_ROOT/scripts/ralph" | grep -q 'printf %q'; then
        test_pass
    else
        test_fail "escape_for_shell missing printf %q"
    fi

    test_start "umask 077 is set at script start"
    if head -20 "$PROJECT_ROOT/scripts/ralph" | grep -q "umask 077"; then
        test_pass
    else
        test_fail "Missing umask 077 security default"
    fi
}

# ============================================================================
# MAIN TEST RUNNER
# ============================================================================
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  RALPH v2.24.1 SECURITY HARDENING TESTS                       ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"

    test_suite_version
    test_suite_url_validation
    test_suite_path_allowlist
    test_suite_prompt_injection
    test_suite_doc_guardrails
    test_suite_security_patterns

    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Total:  $TESTS_RUN"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo "═══════════════════════════════════════════════════════════════"

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All security tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some security tests failed${NC}"
        exit 1
    fi
}

main "$@"
