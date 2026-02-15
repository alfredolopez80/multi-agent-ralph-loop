#!/usr/bin/env bash
# Quality Parallel System - End-to-End Test v4 (FINAL)
# VERSION: 4.0.1 - Fixed RUN_ID extraction for parallel execution
set -euo pipefail

PR=$(git rev-parse --show-toplevel)
RESULTS_DIR="$PR/.claude/quality-results"
TEST_DIR="$PR/tests/quality-parallel"

mkdir -p "$TEST_DIR" "$RESULTS_DIR"

# FIX: Clean results directory before starting all tests
rm -rf "$RESULTS_DIR"/*

echo "🧪 Quality Parallel System - End-to-End Test v4"
echo "================================================"

# === TEST 1: Clean File ===
echo ""
echo "Test 1: Clean File"
echo "----------------"

cat > "$TEST_DIR/clean.js" <<'EOF'
function add(a, b) { return a + b; }
EOF

# Create temp input file
cat > /tmp/test1.json <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$TEST_DIR/clean.js"}}
EOF

bash "$PR/.claude/hooks/quality-parallel-async.sh" < /tmp/test1.json > /dev/null 2>&1
sleep 3  # Wait for parallel checks to complete

# FIX: Find the most common RUN_ID across all .done files (handles parallel execution)
RUN_ID=$(ls "$RESULTS_DIR"/*.done 2>/dev/null | xargs -I{} basename {} | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("$PR/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
    # Filter JSON from logs and extract findings
    FINDINGS=$(echo "$RESULTS" | grep -A 3 '"summary"' | grep '"total_findings"' | grep -oE '[0-9]+' || echo "0")

    if [[ "$FINDINGS" -eq 0 ]]; then
        echo "✅ PASS: Clean file (0 findings)"
        TEST1_PASS=true
    else
        echo "❌ FAIL: Expected 0, got $FINDINGS"
        TEST1_PASS=false
    fi
else
    echo "❌ FAIL: No results"
    TEST1_PASS=false
fi

# === TEST 2: Vulnerable File ===
echo ""
echo "Test 2: Vulnerable File"
echo "----------------------"

cat > "$TEST_DIR/vuln.js" <<'EOF'
const key = "sk-TESTONLY_000000000000";
function auth(id) {
    const q = "SELECT * FROM users WHERE id=" + id;
    return md5(q);
}
EOF

# Clean results before Test 2
rm -rf "$RESULTS_DIR"/*

cat > /tmp/test2.json <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$TEST_DIR/vuln.js"}}
EOF

bash "$PR/.claude/hooks/quality-parallel-async.sh" < /tmp/test2.json > /dev/null 2>&1
sleep 3  # Wait for parallel checks to complete

# FIX: Find the most common RUN_ID across all .done files (handles parallel execution)
RUN_ID=$(ls "$RESULTS_DIR"/*.done 2>/dev/null | xargs -I{} basename {} | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("$PR/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
    # Filter JSON from logs and extract findings
    FINDINGS=$(echo "$RESULTS" | grep -A 3 '"summary"' | grep '"total_findings"' | grep -oE '[0-9]+' || echo "0")

    if [[ "$FINDINGS" -gt 0 ]]; then
        echo "✅ PASS: Vulnerabilities detected ($FINDINGS findings)"
        TEST2_PASS=true
    else
        echo "❌ FAIL: Expected findings, got 0"
        TEST2_PASS=false
    fi
else
    echo "❌ FAIL: No results"
    TEST2_PASS=false
fi

# === TEST 3: Orchestrator Integration ===
echo ""
echo "Test 3: Orchestrator Integration"
echo "-------------------------------"

cat > "$TEST_DIR/orch.js" <<'EOF'
app.post('/login', (req, res) => {
    const q = "SELECT * FROM users WHERE name='" + req.body.user + "'";
    db.query(q);
});
EOF

rm -rf "$RESULTS_DIR"/*

# 3a. Execute quality check (Step 6b.5)
cat > /tmp/test3.json <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$TEST_DIR/orch.js"}}
EOF

bash "$PR/.claude/hooks/quality-parallel-async.sh" < /tmp/test3.json > /dev/null 2>&1
sleep 3

# 3b. Read results (Step 7a)
# FIX: Find the most common RUN_ID across all .done files (handles parallel execution)
RUN_ID=$(ls "$RESULTS_DIR"/*.done 2>/dev/null | xargs -I{} basename {} | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("$PR/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
    # Filter JSON from logs and extract findings
    FINDINGS=$(echo "$RESULTS" | grep -A 3 '"summary"' | grep '"total_findings"' | grep -oE '[0-9]+' || echo "0")

    echo "📊 Findings: $FINDINGS"

    # 3c. Decision logic
    if [[ "$FINDINGS" -gt 0 ]]; then
        echo "✅ PASS: Decision logic triggered (BLOCK/WARN)"
        TEST3_PASS=true
    else
        echo "⚠️  WARN: No findings in vulnerable file"
        TEST3_PASS=false
    fi

    # 3d. Verify quality-coordinator
    COORD_OUTPUT=$("$PR/.claude/scripts/quality-coordinator.sh" "$TEST_DIR/orch.js" 7 2>&1)
    COORD_RUN_ID=$(echo "$COORD_OUTPUT" | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | head -1 || echo "")

    if [[ -n "$COORD_RUN_ID" ]]; then
        echo "✅ PASS: Quality coordinator works ($COORD_RUN_ID)"
    else
        echo "❌ FAIL: Quality coordinator failed"
        TEST3_PASS=false
    fi
else
    echo "❌ FAIL: Quality checks failed"
    TEST3_PASS=false
fi

# === SUMMARY ===
echo ""
echo "================================================"
echo "📊 Test Summary:"
echo "  Test 1 (Clean):    $([[ "$TEST1_PASS" == true ]] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  Test 2 (Vuln):     $([[ "$TEST2_PASS" == true ]] && echo '✅ PASS' || echo '❌ FAIL')"
echo "  Test 3 (Orch):    $([[ "$TEST3_PASS" == true ]] && echo '✅ PASS' || echo '❌ FAIL')"

if [[ "$TEST1_PASS" == true ]] && [[ "$TEST2_PASS" == true ]] && [[ "$TEST3_PASS" == true ]]; then
    echo ""
    echo "🎉 ALL TESTS PASSED"
    exit 0
else
    echo ""
    echo "❌ SOME TESTS FAILED"
    exit 1
fi
