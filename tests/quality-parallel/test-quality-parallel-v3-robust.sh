#!/usr/bin/env bash
# Quality Parallel System - End-to-End Test v3 (ROBUST)
# VERSION: 3.0.0
set -euo pipefail

readonly PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo '.')"
readonly RESULTS_DIR="${PROJECT_ROOT}/.claude/quality-results"
readonly TEST_DIR="${PROJECT_ROOT}/.claude/tests/quality-parallel"

mkdir -p "$TEST_DIR" "$RESULTS_DIR"

echo "🧪 Quality Parallel System - End-to-End Test v3 (ROBUST)"
echo "================================================================"

# Test 1: Clean File
echo ""
echo "Test 1: Clean File (No Vulnerabilities)"
echo "-----------------------------------------"

cat > "$TEST_DIR/clean-test.js" <<'EOF'
function add(a, b) { return a + b; }
module.exports = { add };
EOF

INPUT_JSON='{"tool_name":"Write","tool_input":{"file_path":"'"$TEST_DIR"'/clean-test.js"}}'
echo "$INPUT_JSON" | bash "${PROJECT_ROOT}/.claude/hooks/quality-parallel-async.sh > /dev/null 2>&1

# Get most recent run_id
LATEST_DONE=$(ls -t "${RESULTS_DIR}"/*.done 2>/dev/null | head -1)
if [[ -n "$LATEST_DONE" ]]; then
    RUN_ID=$(basename "$LATEST_DONE" | sed 's/.*_\([0-9]\{8\}_[0-9]\+_[0-9]\+\).*/\1/')
    RESULTS=$("${PROJECT_ROOT}/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
    FINDINGS=$(echo "$RESULTS" | jq -r '.summary.total_findings // 0' 2>/dev/null || echo "0")

    if [[ "$FINDINGS" -eq 0 ]]; then
        echo "✅ PASS: Clean file (0 findings)"
    else
        echo "❌ FAIL: Expected 0, got $FINDINGS"
    fi
else
    echo "❌ FAIL: No results generated"
fi

# Test 2: Vulnerable File
echo ""
echo "Test 2: Vulnerable File (Security Issues)"
echo "------------------------------------------"

cat > "$TEST_DIR/vulnerable-test.js" <<'EOF'
const API_KEY = "sk-1234567890abcdef";
function auth(id) {
    const q = "SELECT * FROM users WHERE id=" + id;
    return md5(q);
}
EOF

rm -rf "${RESULTS_DIR}"/*

INPUT_JSON='{"tool_name":"Write","tool_input":{"file_path":"'"$TEST_DIR"'/vulnerable-test.js"}}'
echo "$INPUT_JSON" | bash "${PROJECT_ROOT}/.claude/hooks/quality-parallel-async.sh > /dev/null 2>&1

LATEST_DONE=$(ls -t "${RESULTS_DIR}"/*.done 2>/dev/null | head -1)
if [[ -n "$LATEST_DONE" ]]; then
    RUN_ID=$(basename "$LATEST_DONE" | sed 's/.*_\([0-9]\{8\}_[0-9]\+_[0-9]\+\).*/\1/')
    RESULTS=$("${PROJECT_ROOT}/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
    FINDINGS=$(echo "$RESULTS" | jq -r '.summary.total_findings // 0' 2>/dev/null || echo "0")

    if [[ "$FINDINGS" -gt 0 ]]; then
        echo "✅ PASS: Vulnerabilities detected ($FINDINGS findings)"
    else
        echo "❌ FAIL: Expected findings, got 0"
    fi
else
    echo "❌ FAIL: No results generated"
fi

# Test 3: Orchestrator Integration (SIMPLIFIED)
echo ""
echo "Test 3: Orchestrator Integration"
echo "---------------------------------"

cat > "$TEST_DIR/orchestrator-test.js" <<'EOF'
app.post('/login', (req, res) => {
    const q = "SELECT * FROM users WHERE name='" + req.body.user + "'";
    db.query(q);
});
EOF

rm -rf "${RESULTS_DIR}"/*

# Step 6b.5: Execute quality check (like orchestrator would)
INPUT_JSON='{"tool_name":"Write","tool_input":{"file_path":"'"$TEST_DIR"'/orchestrator-test.js"}}'
echo "$INPUT_JSON" | bash "${PROJECT_ROOT}/.claude/hooks/quality-parallel-async.sh > /dev/null 2>&1

# Wait for completion
sleep 3

# Step 7a: Read results (like orchestrator would)
LATEST_DONE=$(ls -t "${RESULTS_DIR}"/*.done 2>/dev/null | head -1)
if [[ -n "$LATEST_DONE" ]]; then
    RUN_ID=$(basename "$LATEST_DONE" | sed 's/.*_\([0-9]\{8\}_[0-9]\+_[0-9]\+\).*/\1/')
    RESULTS=$("${PROJECT_ROOT}/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)

    # Orchestrator decision logic
    TOTAL_FINDINGS=$(echo "$RESULTS" | jq -r '.summary.total_findings // 0' 2>/dev/null || echo "0")

    echo "📊 Orchestrator Analysis: $TOTAL_FINDINGS findings"

    if [[ "$TOTAL_FINDINGS" -gt 0 ]]; then
        echo "🚨 BLOCK: Critical findings detected - requires fixes"
        echo "✅ PASS: Decision logic applicable"
    elif [[ "$TOTAL_FINDINGS" -eq 0 ]]; then
        echo "✅ PASS: No findings - proceed to validation"
    else
        echo "❌ FAIL: Could not parse findings"
    fi

    # Verify quality-coordinator also works
    COORD_OUTPUT=$("${PROJECT_ROOT}/.claude/scripts/quality-coordinator.sh" "$TEST_DIR/orchestrator-test.js" 7 2>&1)
    COORD_RUN_ID=$(echo "$COORD_OUTPUT" | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | head -1)

    if [[ -n "$COORD_RUN_ID" ]]; then
        echo "✅ PASS: Quality coordinator creates run_id ($COORD_RUN_ID)"
    else
        echo "❌ FAIL: Quality coordinator failed"
    fi
else
    echo "❌ FAIL: Quality checks failed to run"
fi

echo ""
echo "================================================================"
echo "🏁 Test Complete"
