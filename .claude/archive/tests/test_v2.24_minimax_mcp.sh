#!/usr/bin/env bash
# test_v2.24_minimax_mcp.sh
# Unit tests for v2.24 MiniMax MCP integration
# Tests: cmd_websearch(), cmd_image(), version consistency, routing

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

# Temp directory for test files
TEST_DIR=$(mktemp -d "/tmp/ralph-test-v2.24.XXXXXXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

# Mock ralph and mmc scripts for testing
setup_mocks() {
    # Create minimal test versions of scripts
    cat > "$TEST_DIR/ralph-test" << 'RALPH_EOF'
#!/usr/bin/env bash
set -euo pipefail
VERSION="2.24.0"

# Mock log functions
log_info() { echo "[INFO] $1"; }
log_error() { echo "[ERROR] $1" >&2; }

# Mock claude command
claude() {
    echo "MOCK_CLAUDE: $*"
}

validate_text_input() {
    local input="$1"
    local max_len="${2:-10000}"
    if [[ "$input" =~ [[:cntrl:]] ]] && ! [[ "$input" =~ ^[[:print:][:space:]]*$ ]]; then
        log_error "Invalid control characters in input"
        exit 1
    fi
    if [ ${#input} -gt "$max_len" ]; then
        log_error "Input too long (max: $max_len characters)"
        exit 1
    fi
    printf '%s' "$input"
}

validate_path() {
    local path="$1"
    if [[ "$path" =~ [[:cntrl:]] ]]; then
        log_error "Control characters not allowed in path"
        exit 1
    fi
    if [[ "$path" =~ [\;\|\&\$\`\(\)\{\}\<\>\*\?\[\]\!\~\#] ]]; then
        log_error "Invalid characters in path: $path"
        exit 1
    fi
    if [[ "$path" =~ \.\. ]]; then
        log_error "Path traversal not allowed: $path"
        exit 1
    fi
    realpath -s "$path" 2>/dev/null || printf '%s' "$path"
}

cmd_websearch() {
    local QUERY
    QUERY=$(validate_text_input "${1:-}")

    if [ -z "$QUERY" ]; then
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  MINIMAX WEB SEARCH: MCP-Powered Research (v2.24)             ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        exit 1
    fi

    log_info "MiniMax Web Search: $QUERY"
    log_info "Using mcp__MiniMax__web_search tool..."
    claude --print "Use the mcp__MiniMax__web_search tool to search for: \"$QUERY\""
}

cmd_image() {
    local PROMPT="${1:-}"
    local IMAGE_SOURCE="${2:-}"

    # Strip @ prefix
    IMAGE_SOURCE="${IMAGE_SOURCE#@}"

    # Validate prompt
    if [ -n "$PROMPT" ]; then
        PROMPT=$(validate_text_input "$PROMPT")
    fi

    if [ -z "$PROMPT" ] || [ -z "$IMAGE_SOURCE" ]; then
        echo "╔═══════════════════════════════════════════════════════════════╗"
        echo "║  MINIMAX IMAGE ANALYSIS: MCP-Powered Vision (v2.24)           ║"
        echo "╚═══════════════════════════════════════════════════════════════╝"
        exit 1
    fi

    # Check if URL or file
    if [[ "$IMAGE_SOURCE" =~ ^https?:// ]]; then
        log_info "Image source: URL"
    else
        # Local file validation
        IMAGE_SOURCE=$(validate_path "$IMAGE_SOURCE")
        if [ ! -f "$IMAGE_SOURCE" ]; then
            log_error "File not found: $IMAGE_SOURCE"
            exit 1
        fi

        # Check size (max 20MB)
        local FILE_SIZE
        FILE_SIZE=$(stat -f%z "$IMAGE_SOURCE" 2>/dev/null || stat -c%s "$IMAGE_SOURCE" 2>/dev/null)
        if [ "$FILE_SIZE" -gt 20971520 ]; then
            log_error "File too large (max 20MB): $IMAGE_SOURCE"
            exit 1
        fi

        # Check format
        local EXT="${IMAGE_SOURCE##*.}"
        EXT=$(echo "$EXT" | tr '[:upper:]' '[:lower:]')
        if [[ ! "$EXT" =~ ^(jpg|jpeg|png|webp)$ ]]; then
            log_error "Unsupported format: $EXT (use JPEG, PNG, or WebP)"
            exit 1
        fi

        log_info "Image source: Local file ($EXT)"
    fi

    log_info "MiniMax Image Analysis: $PROMPT"
    log_info "Image: $IMAGE_SOURCE"
    claude --print "Use the mcp__MiniMax__understand_image tool with prompt: \"$PROMPT\" and image_source: \"$IMAGE_SOURCE\""
}

# Main command router
case "${1:-}" in
    websearch|web-search|search)
        shift
        cmd_websearch "$@"
        ;;
    image|img|analyze-image)
        shift
        cmd_image "$@"
        ;;
    version)
        echo "ralph v$VERSION"
        ;;
    *)
        echo "Unknown command"
        exit 1
        ;;
esac
RALPH_EOF

    chmod +x "$TEST_DIR/ralph-test"
    export PATH="$TEST_DIR:$PATH"
}

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
# TEST SUITE: cmd_websearch()
# ============================================================================
test_suite_websearch() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: cmd_websearch()"
    echo "═══════════════════════════════════════════════════════════════"

    # Test 1: Empty query shows help
    test_start "Empty query should show help"
    if "$TEST_DIR/ralph-test" websearch 2>&1 | grep -q "MINIMAX WEB SEARCH"; then
        test_pass
    else
        test_fail "Expected help message for empty query"
    fi

    # Test 2: Valid query passes validation
    test_start "Valid query should pass"
    if "$TEST_DIR/ralph-test" websearch "React 19 features 2025" 2>&1 | grep -q "MiniMax Web Search"; then
        test_pass
    else
        test_fail "Valid query should pass validation"
    fi

    # Test 3: Special characters in query
    test_start "Query with special chars should be sanitized"
    if "$TEST_DIR/ralph-test" websearch "TypeScript 'satisfies' operator" 2>&1 | grep -q "MiniMax Web Search"; then
        test_pass
    else
        test_fail "Special characters should be handled"
    fi

    # Test 4: Very long query (over 10000 chars)
    test_start "Very long query should be rejected"
    local LONG_QUERY=$(printf 'a%.0s' {1..10001})
    if "$TEST_DIR/ralph-test" websearch "$LONG_QUERY" 2>&1 | grep -q "ERROR"; then
        test_pass
    else
        test_fail "Long query should be rejected"
    fi

    # Test 5: Control characters in query
    test_start "Control characters should be rejected"
    if "$TEST_DIR/ralph-test" websearch $'query\x00with\x00nulls' 2>&1 | grep -q "ERROR"; then
        test_pass
    else
        test_fail "Control characters should be blocked"
    fi
}

# ============================================================================
# TEST SUITE: cmd_image()
# ============================================================================
test_suite_image() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: cmd_image()"
    echo "═══════════════════════════════════════════════════════════════"

    # Setup: Create test image files
    touch "$TEST_DIR/test.png"
    touch "$TEST_DIR/test.jpg"
    touch "$TEST_DIR/test.webp"
    touch "$TEST_DIR/test.gif"
    dd if=/dev/zero of="$TEST_DIR/large.png" bs=1m count=21 2>/dev/null

    # Test 1: Missing arguments show help
    test_start "Missing arguments should show help"
    if "$TEST_DIR/ralph-test" image 2>&1 | grep -q "MINIMAX IMAGE ANALYSIS"; then
        test_pass
    else
        test_fail "Expected help for missing arguments"
    fi

    # Test 2: Valid local file path
    test_start "Valid local PNG file should work"
    if "$TEST_DIR/ralph-test" image "describe this" "$TEST_DIR/test.png" 2>&1 | grep -q "Image source: Local file (png)"; then
        test_pass
    else
        test_fail "Valid PNG file should be accepted"
    fi

    # Test 3: URL image source
    test_start "URL image source should work"
    if "$TEST_DIR/ralph-test" image "analyze" "https://example.com/image.jpg" 2>&1 | grep -q "Image source: URL"; then
        test_pass
    else
        test_fail "URL should be accepted"
    fi

    # Test 4: @ prefix stripping
    test_start "@ prefix should be stripped"
    if "$TEST_DIR/ralph-test" image "test" "@$TEST_DIR/test.jpg" 2>&1 | grep -q "Image source: Local file (jpg)"; then
        test_pass
    else
        test_fail "@ prefix should be stripped"
    fi

    # Test 5: Unsupported file format
    test_start "Unsupported format (GIF) should error"
    if "$TEST_DIR/ralph-test" image "test" "$TEST_DIR/test.gif" 2>&1 | grep -q "Unsupported format"; then
        test_pass
    else
        test_fail "GIF should be rejected"
    fi

    # Test 6: File size validation (>20MB)
    test_start "File >20MB should be rejected"
    if "$TEST_DIR/ralph-test" image "test" "$TEST_DIR/large.png" 2>&1 | grep -q "too large"; then
        test_pass
    else
        test_fail "Large file should be rejected"
    fi

    # Test 7: Path traversal attempt
    test_start "Path traversal should be blocked"
    if "$TEST_DIR/ralph-test" image "test" "../etc/passwd" 2>&1 | grep -q "Path traversal"; then
        test_pass
    else
        test_fail "Path traversal should be blocked"
    fi

    # Test 8: Non-existent file
    test_start "Non-existent file should error"
    if "$TEST_DIR/ralph-test" image "test" "$TEST_DIR/nonexistent.png" 2>&1 | grep -q "File not found"; then
        test_pass
    else
        test_fail "Non-existent file should error"
    fi
}

# ============================================================================
# TEST SUITE: Version Consistency
# ============================================================================
test_suite_version() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Version Consistency"
    echo "═══════════════════════════════════════════════════════════════"

    # Find project root
    local PROJECT_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
    if [ ! -d "$PROJECT_ROOT" ]; then
        PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    fi

    # Test 1: ralph script version
    test_start "ralph script has VERSION=\"2.24.0\""
    if grep -q '^VERSION="2.24.0"' "$PROJECT_ROOT/scripts/ralph" 2>/dev/null; then
        test_pass
    else
        test_fail "ralph script version mismatch"
    fi

    # Test 2: mmc script version
    test_start "mmc script has VERSION=\"2.24.0\""
    if grep -q '^VERSION="2.24.0"' "$PROJECT_ROOT/scripts/mmc" 2>/dev/null; then
        test_pass
    else
        test_fail "mmc script version mismatch"
    fi

    # Test 3: Version comment in ralph
    test_start "ralph has v2.24 comment"
    if grep -q "# Version 2.24" "$PROJECT_ROOT/scripts/ralph" 2>/dev/null; then
        test_pass
    else
        test_fail "ralph missing v2.24 comment"
    fi

    # Test 4: Version comment in mmc
    test_start "mmc has v2.24 comment"
    if grep -q "# Version 2.24" "$PROJECT_ROOT/scripts/mmc" 2>/dev/null; then
        test_pass
    else
        test_fail "mmc missing v2.24 comment"
    fi
}

# ============================================================================
# TEST SUITE: Integration - Case Statement Routing
# ============================================================================
test_suite_routing() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "  TEST SUITE: Command Routing"
    echo "═══════════════════════════════════════════════════════════════"

    # Test 1: websearch alias
    test_start "websearch command routes correctly"
    if "$TEST_DIR/ralph-test" websearch "test" 2>&1 | grep -q "MiniMax Web Search"; then
        test_pass
    else
        test_fail "websearch command not routed"
    fi

    # Test 2: web-search alias
    test_start "web-search command routes correctly"
    if "$TEST_DIR/ralph-test" web-search "test" 2>&1 | grep -q "MiniMax Web Search"; then
        test_pass
    else
        test_fail "web-search alias not routed"
    fi

    # Test 3: search alias
    test_start "search command routes correctly"
    if "$TEST_DIR/ralph-test" search "test" 2>&1 | grep -q "MiniMax Web Search"; then
        test_pass
    else
        test_fail "search alias not routed"
    fi

    # Test 4: image command
    test_start "image command routes correctly"
    touch "$TEST_DIR/test-route.png"
    if "$TEST_DIR/ralph-test" image "test" "$TEST_DIR/test-route.png" 2>&1 | grep -q "Image source: Local file"; then
        test_pass
    else
        test_fail "image command not routed"
    fi

    # Test 5: img alias
    test_start "img command routes correctly"
    if "$TEST_DIR/ralph-test" img "test" "$TEST_DIR/test-route.png" 2>&1 | grep -q "Image source: Local file"; then
        test_pass
    else
        test_fail "img alias not routed"
    fi

    # Test 6: analyze-image alias
    test_start "analyze-image command routes correctly"
    if "$TEST_DIR/ralph-test" analyze-image "test" "$TEST_DIR/test-route.png" 2>&1 | grep -q "Image source: Local file"; then
        test_pass
    else
        test_fail "analyze-image alias not routed"
    fi
}

# ============================================================================
# MAIN TEST RUNNER
# ============================================================================
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  RALPH v2.24 MINIMAX MCP INTEGRATION TESTS                    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"

    setup_mocks

    test_suite_websearch
    test_suite_image
    test_suite_version
    test_suite_routing

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
        echo -e "${GREEN}✓ All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        exit 1
    fi
}

main "$@"
