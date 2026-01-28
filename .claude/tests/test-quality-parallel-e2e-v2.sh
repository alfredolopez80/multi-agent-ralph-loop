#!/usr/bin/env bash
# End-to-End Quality Parallel System Test v2
set -euo pipefail

readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
readonly TEST_DIR="${PROJECT_ROOT}/.claude/tests/quality-parallel"
readonly RESULTS_DIR="${PROJECT_ROOT}/.claude/quality-results"

mkdir -p "$TEST_DIR" "$RESULTS_DIR"

echo "🧪 Quality Parallel System - End-to-End Test v2"
echo "================================================="

# Test 1: Clean File
echo ""
echo "Test 1: Clean File (No Vulnerabilities)"
echo "-----------------------------------------"

cat > "$TEST_DIR/test-clean.js" <<'EOF'
function greet(name) { return `Hello, ${name}!`; }
module.exports = { greet };
