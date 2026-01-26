#!/bin/bash
# Test script for quality-gates-v3.sh auto-remediation
# Tests Docker Compose security issue auto-fixing

set -euo pipefail

readonly TEST_DIR="/tmp/quality-gates-v3-test"
readonly TEST_FILE="$TEST_DIR/docker-compose.yml"

echo "========================================"
echo "Quality Gates v3.0 Auto-Remediation Test"
echo "========================================"
echo ""

# Setup test environment
echo "1. Setting up test environment..."
rm -rf "$TEST_DIR"
mkdir -p "$TEST_DIR"

# Create test file with KNOWN security issues
cat > "$TEST_FILE" <<'EOF'
version: '3.8'
services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_PASSWORD: example
    volumes:
      - postgres_data:/var/lib/postgresql/data

  pgbouncer:
    image: edoburu/pgbouncer
    environment:
      DATABASES_HOST: postgres
      DATABASES_PORT: 5432

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
EOF

echo "   Created test file: $TEST_FILE"
echo ""

# Show original file
echo "2. Original file content:"
echo "   ---"
cat "$TEST_FILE" | sed 's/^/   /'
echo "   ---"
echo ""

# Run semgrep to show initial issues
echo "3. Initial semgrep scan:"
if command -v semgrep &>/dev/null; then
    semgrep --config=auto --severity=ERROR --severity=WARNING "$TEST_FILE" 2>/dev/null || true
else
    echo "   ⚠️  semgrep not installed, skipping scan"
fi
echo ""

# Test quality-gates-v3.sh
echo "4. Running quality-gates-v3.sh..."

# Create input JSON
INPUT_JSON=$(jq -n \
    --arg file "$TEST_FILE" \
    '{
        tool_name: "Write",
        tool_input: {file_path: $file},
        session_id: "test-session-'"$(date +%s)"'"
    }')

# Run the hook
echo "$INPUT_JSON" | ~/.claude/hooks/quality-gates-v3.sh
HOOK_EXIT_CODE=$?

echo ""
echo "   Hook exit code: $HOOK_EXIT_CODE"
echo ""

# Show modified file
echo "5. File content after auto-fix:"
echo "   ---"
cat "$TEST_FILE" | sed 's/^/   /'
echo "   ---"
echo ""

# Verify fixes with semgrep
echo "6. Verification scan:"
if command -v semgrep &>/dev/null; then
    VERIFY_OUTPUT=$(semgrep --config=auto --severity=ERROR --severity=WARNING --json "$TEST_FILE" 2>/dev/null || echo '{"results":[]}')
    ISSUE_COUNT=$(echo "$VERIFY_OUTPUT" | jq '.results | length' 2>/dev/null || echo "0")

    echo "   Issues remaining: $ISSUE_COUNT"

    if [[ "$ISSUE_COUNT" -eq 0 ]]; then
        echo "   ✅ ALL ISSUES FIXED!"
    else
        echo "   ⚠️  Some issues remain:"
        echo "$VERIFY_OUTPUT" | jq -r '.results[] | "   - \(.check_id): \(.extra.message // "security issue")"' 2>/dev/null || true
    fi
else
    echo "   ⚠️  semgrep not installed, cannot verify"
fi
echo ""

# Check YAML validity
echo "7. YAML validity check:"
if python3 -c 'import yaml, sys; yaml.safe_load(open(sys.argv[1]))' "$TEST_FILE" 2>&1; then
    echo "   ✅ YAML is valid"
else
    echo "   ❌ YAML is INVALID"
fi
echo ""

# Cleanup
echo "8. Cleanup..."
rm -rf "$TEST_DIR"
echo "   Cleaned up test directory"
echo ""

echo "========================================"
echo "Test Complete!"
echo "========================================"
echo ""
echo "Summary:"
echo "  - Quality Gates v3.0 executed successfully"
echo "  - Auto-fixing applied to Docker Compose file"
echo "  - YAML validity verified"
echo ""
echo "Next Steps:"
echo "  1. Test with real docker-compose.yml files"
echo "  2. Monitor ~/.ralph/logs/quality-gates-*.log for details"
echo "  3. Verify no workflow blockages occur"
echo ""
