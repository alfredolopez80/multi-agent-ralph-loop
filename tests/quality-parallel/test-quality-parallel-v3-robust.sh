#!/usr/bin/env bash
# Quality Parallel System - End-to-End Test v3 (ROBUST)
# VERSION: 3.0.1 - Fixed JSON input handling
#
# ----------------------------------------------------------------------------
# DIAGNOSTIC 2026-08-25 (T14-runtests2, #51 part 2): OPT-IN (candidate)
# What I see after mmx-2's sandbox fix in T1 (#52): the real defect.
#   Test 1 (clean file):   PASS  -> detector correctly returns 0 findings
#   Test 2 (API key+SQLi): FAIL  -> detector returns 0, expected >0
#   Test 3 (orch SQLi):    FAIL  -> WARN "no findings", then coordinator runs
#                                 but TEST3_PASS stays false (logic bug)
# Root cause: ee2f95f dropped 3 of 4 registered quality checks
# (sec-context-validate.sh, quality-gates-v2.sh, deslop-auto-clean.sh) because
# they pointed at .claude/archive/ scripts. The detector now only does
# stop-slop. Test 2 fixture's secrets/SQLi patterns are out of scope for the
# current detector; Test 3 has the same out-of-scope fixture plus a logic bug
# (no TEST3_PASS=true after coordinator success).
# Verdict: opt-in. Wired requires either fixture update (to a stop-slop
# pattern) or detector expansion (re-registering equivalent checks). Both are
# out of scope for this task.
# ----------------------------------------------------------------------------
set -euo pipefail

PR=$(git rev-parse --show-toplevel)
RESULTS_DIR="$PR/.claude/quality-results"

# Sandbox: copy fixtures into a fresh temp dir so the suite never mutates
# the tracked files under tests/quality-parallel/ (issue #52).
SCRATCH=$(mktemp -d "${TMPDIR:-/tmp}/quality-parallel-v3.XXXXXX")
trap 'rm -rf "$SCRATCH"' EXIT
TEST_DIR="$SCRATCH"

mkdir -p "$RESULTS_DIR"

# FIX: Clean results directory before starting
rm -rf "$RESULTS_DIR"/*

echo "🧪 Quality Parallel System - End-to-End Test v3 (ROBUST)"
echo "================================================================"

# === TEST 1: Clean File ===
echo ""
echo "Test 1: Clean File (No Vulnerabilities)"
echo "-----------------------------------------"

cat > "$TEST_DIR/clean-test.js" <<'EOF'
function add(a, b) { return a + b; }
module.exports = { add };
EOF

cat > /tmp/test1.json <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$TEST_DIR/clean-test.js"}}
EOF

bash "$PR/.claude/hooks/quality-parallel-async.sh" < /tmp/test1.json > /dev/null 2>&1
sleep 3

# Find the most recent RUN_ID
RUN_ID=$(ls "$RESULTS_DIR"/*.done 2>/dev/null | xargs -I{} basename {} | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("$PR/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
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
echo "Test 2: Vulnerable File (Security Issues)"
echo "------------------------------------------"

cat > "$TEST_DIR/vulnerable-test.js" <<'EOF'
const API_KEY = "sk-TESTONLY_000000000000";
function query(id) {
    return "SELECT * FROM users WHERE id=" + id;
}
EOF

rm -rf "$RESULTS_DIR"/*

cat > /tmp/test2.json <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$TEST_DIR/vulnerable-test.js"}}
EOF

bash "$PR/.claude/hooks/quality-parallel-async.sh" < /tmp/test2.json > /dev/null 2>&1
sleep 3

RUN_ID=$(ls "$RESULTS_DIR"/*.done 2>/dev/null | xargs -I{} basename {} | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("$PR/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
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

cat > "$TEST_DIR/orchestrator-test.js" <<'EOF'
app.post('/login', (req, res) => {
    const q = "SELECT * FROM users WHERE name='" + req.body.user + "'";
    db.query(q);
});
EOF

rm -rf "$RESULTS_DIR"/*

cat > /tmp/test3.json <<EOF
{"tool_name":"Write","tool_input":{"file_path":"$TEST_DIR/orchestrator-test.js"}}
EOF

bash "$PR/.claude/hooks/quality-parallel-async.sh" < /tmp/test3.json > /dev/null 2>&1
sleep 3

RUN_ID=$(ls "$RESULTS_DIR"/*.done 2>/dev/null | xargs -I{} basename {} | grep -oE '[0-9]{8}_[0-9]+_[0-9]+' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}' || echo "")

if [[ -n "$RUN_ID" ]]; then
    RESULTS=$("$PR/.claude/scripts/read-quality-results.sh" "$RUN_ID" 2>&1)
    FINDINGS=$(echo "$RESULTS" | grep -A 3 '"summary"' | grep '"total_findings"' | grep -oE '[0-9]+' || echo "0")

    echo "📊 Findings: $FINDINGS"

    if [[ "$FINDINGS" -gt 0 ]]; then
        echo "✅ PASS: Decision logic triggered (BLOCK/WARN)"
        TEST3_PASS=true
    else
        echo "⚠️  WARN: No findings in vulnerable file"
        TEST3_PASS=false
    fi

    COORD_OUTPUT=$("$PR/.claude/scripts/quality-coordinator.sh" "$TEST_DIR/orchestrator-test.js" 7 2>&1)
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
echo "================================================================"
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
