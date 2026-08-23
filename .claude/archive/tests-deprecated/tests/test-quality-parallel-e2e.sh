#!/usr/bin/env bash
# End-to-End Quality Parallel System Test
# VERSION: 1.0.0

set -euo pipefail

readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
readonly TEST_DIR="${PROJECT_ROOT}/.claude/tests/quality-parallel"
readonly RESULTS_DIR="${PROJECT_ROOT}/.claude/quality-results"

mkdir -p "$TEST_DIR" "$RESULTS_DIR"

echo "🧪 Quality Parallel System - End-to-End Test"
echo "=============================================="

# Test 1: Clean File
echo ""
echo "Test 1: Clean File (No Vulnerabilities)"
echo "-----------------------------------------"

cat > "$TEST_DIR/test-clean.js" <<'EOF'
function greet(name) {
    return `Hello, ${name}!`;
}
module.exports = { greet };
EOF

echo '{"tool_name":"Write","tool_input":{"file_path":"'"$TEST_DIR"'/test-clean.js"}}' | \
  bash "${PROJECT_ROOT}/.claude/hooks/quality-parallel-async.sh" > /dev/null 2>&1

RUN_ID=$(ls -t "${RESULTS_DIR}"/*.done 2>/dev/null | head -1 | grep -oE '[0-9]{8}_[0-9]{5}_[0-9]{5}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("${PROJECT_ROOT}/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>/dev/null || echo "")
    FINDINGS=$(echo "$RESULTS" | jq -r '.summary.total_findings // 0' 2>/dev/null || echo "0")

    if [[ "$FINDINGS" -eq 0 ]]; then
        echo "✅ PASS: Clean file detected (0 findings)"
    else
        echo "❌ FAIL: Expected 0 findings, got $FINDINGS"
    fi
else
    echo "❌ FAIL: No results generated"
fi

# Test 2: Vulnerable File
echo ""
echo "Test 2: Vulnerable File (Security Issues)"
echo "------------------------------------------"

cat > "$TEST_DIR/test-vulnerable.js" <<'EOF'
const API_KEY = "sk-1234567890abcdef";
function authenticate(userId, password) {
    const query = "SELECT * FROM users WHERE id=" + userId;
    const hash = md5(password);
    return query;
}
EOF

echo '{"tool_name":"Write","tool_input":{"file_path":"'"$TEST_DIR"'/test-vulnerable.js"}}' | \
  bash "${PROJECT_ROOT}/.claude/hooks/quality-parallel-async.sh" > /dev/null 2>&1

rm -rf "${RESULTS_DIR}"/*
RUN_ID=$(ls -t "${RESULTS_DIR}"/*.done 2>/dev/null | head -1 | grep -oE '[0-9]{8}_[0-9]{5}_[0-9]{5}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("${PROJECT_ROOT}/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>/dev/null || echo "")
    FINDINGS=$(echo "$RESULTS" | jq -r '.summary.total_findings // 0' 2>/dev/null || echo "0")

    if [[ "$FINDINGS" -gt 0 ]]; then
        echo "✅ PASS: Vulnerabilities detected ($FINDINGS findings)"
    else
        echo "❌ FAIL: Expected findings, got 0"
    fi
else
    echo "❌ FAIL: No results generated"
fi

# Test 3: Orchestrator Integration
echo ""
echo "Test 3: Orchestrator Integration"
echo "---------------------------------"

cat > "$TEST_DIR/test-orchestrator.js" <<'EOF'
const express = require('express');
app.post('/login', (req, res) => {
    const query = "SELECT * FROM users WHERE username = '" + username + "'";
    db.execute(query);
});
EOF

# Simulate orchestrator workflow
COMPLEXITY=7
TARGET_FILE="$TEST_DIR/test-orchestrator.js"

"${PROJECT_ROOT}/.claude/scripts/quality-coordinator.sh" "$TARGET_FILE" "$COMPLEXITY" > /dev/null 2>&1

sleep 5

RUN_ID=$(cat "${RESULTS_DIR}/current_run_id.txt" 2>/dev/null || echo "")

if [[ -n "$RUN_ID" ]]; then
    QUALITY_RESULTS=$("${PROJECT_ROOT}/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>/dev/null || echo "")
    TOTAL_FINDINGS=$(echo "$QUALITY_RESULTS" | jq -r '.summary.total_findings // 0' 2>/dev/null || echo "0")

    echo "📊 Orchestrator would see: $TOTAL_FINDINGS findings"

    if [[ "$TOTAL_FINDINGS" -gt 0 ]]; then
        echo "✅ PASS: Orchestrator decision logic applicable"
    else
        echo "⚠️  WARN: No findings detected in vulnerable file"
    fi
else
    echo "❌ FAIL: Quality coordinator didn't create run_id"
fi

echo ""
echo "=============================================="
echo "🏁 End-to-End Test Complete"
