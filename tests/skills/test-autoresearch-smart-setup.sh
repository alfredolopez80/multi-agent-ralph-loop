#!/usr/bin/env bash
# test-autoresearch-smart-setup.sh - Tests for Smart Setup (Phase 0/1/2) in /autoresearch v3.1.0
# VERSION: 3.1.0
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SKILL_PATH="$REPO_ROOT/.claude/skills/autoresearch/SKILL.md"
AGENT_PATH="$REPO_ROOT/.claude/agents/autoresearch.md"
TEMPLATE_PATH="$REPO_ROOT/.claude/skills/autoresearch/program-template.md"
ANALYSIS_PATH="$REPO_ROOT/docs/analysis/autoresearch-ux-improvement.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=========================================="
echo "  TEST: /autoresearch Smart Setup (v3.1.0)"
echo "=========================================="

# =============================================
# SCOUT TESTS (Phase 0)
# =============================================
echo ""
echo "=== Phase 0: SCOUT Tests ==="

# T1: SKILL.md contains Phase 0 SCOUT section
echo ""
echo "--- T1: SCOUT section exists in SKILL.md ---"
if grep -q "Phase 0: SCOUT" "$SKILL_PATH"; then
  pass "Phase 0: SCOUT section found in SKILL.md"
else
  fail "Phase 0: SCOUT section missing from SKILL.md"
fi

# T2: Project type detection table present
echo ""
echo "--- T2: Project type detection table ---"
if grep -q "package.json" "$SKILL_PATH" && grep -q "pyproject.toml" "$SKILL_PATH" && grep -q "Cargo.toml" "$SKILL_PATH"; then
  pass "Project type detection covers Node.js, Python, Rust"
else
  fail "Project type detection table incomplete"
fi

# T3: Script discovery section present
echo ""
echo "--- T3: Script discovery section ---"
if grep -q "Script Discovery" "$SKILL_PATH"; then
  pass "Script Discovery section found"
else
  fail "Script Discovery section missing"
fi

# T4: Metric pattern detection present
echo ""
echo "--- T4: Metric pattern detection ---"
if grep -q "Metric Pattern Detection" "$SKILL_PATH"; then
  pass "Metric Pattern Detection section found"
else
  fail "Metric Pattern Detection section missing"
fi

# T5: File structure analysis present
echo ""
echo "--- T5: File structure analysis ---"
if grep -q "File Structure Analysis" "$SKILL_PATH"; then
  pass "File Structure Analysis section found"
else
  fail "File Structure Analysis section missing"
fi

# T6: SCOUT output schema defined
echo ""
echo "--- T6: SCOUT output schema ---"
if grep -q "scout_result" "$SKILL_PATH"; then
  pass "scout_result schema defined"
else
  fail "scout_result schema missing"
fi

# T7: Go language detection included
echo ""
echo "--- T7: Go detection ---"
if grep -q "go.mod" "$SKILL_PATH"; then
  pass "Go language detection (go.mod) present"
else
  fail "Go language detection missing"
fi

# T8: Java detection included
echo ""
echo "--- T8: Java detection ---"
if grep -q "pom.xml" "$SKILL_PATH" || grep -q "build.gradle" "$SKILL_PATH"; then
  pass "Java detection (pom.xml/build.gradle) present"
else
  fail "Java detection missing"
fi

# T9: Sensitive file detection
echo ""
echo "--- T9: Sensitive file detection ---"
if grep -q '\.env' "$SKILL_PATH" && grep -q "migrations" "$SKILL_PATH"; then
  pass "Sensitive file patterns (.env, migrations) detected"
else
  fail "Sensitive file detection incomplete"
fi

# =============================================
# DOMAIN TEMPLATE TESTS
# =============================================
echo ""
echo "=== Domain Template Tests ==="

# T10: ML Training template exists
echo ""
echo "--- T10: ML Training template ---"
if grep -q "Template: ML Training" "$SKILL_PATH"; then
  pass "ML Training template found"
else
  fail "ML Training template missing"
fi

# T11: Node.js Test Speed template exists
echo ""
echo "--- T11: Node.js Test Speed template ---"
if grep -q "Template: Node.js Test Speed" "$SKILL_PATH"; then
  pass "Node.js Test Speed template found"
else
  fail "Node.js Test Speed template missing"
fi

# T12: Bundle Size template exists
echo ""
echo "--- T12: Bundle Size template ---"
if grep -q "Template: Bundle Size" "$SKILL_PATH"; then
  pass "Bundle Size template found"
else
  fail "Bundle Size template missing"
fi

# T13: Python Test Speed template exists
echo ""
echo "--- T13: Python Test Speed template ---"
if grep -q "Template: Python Test Speed" "$SKILL_PATH"; then
  pass "Python Test Speed template found"
else
  fail "Python Test Speed template missing"
fi

# T14: Prompt Engineering template exists
echo ""
echo "--- T14: Prompt Engineering template ---"
if grep -q "Template: Prompt Engineering" "$SKILL_PATH"; then
  pass "Prompt Engineering template found"
else
  fail "Prompt Engineering template missing"
fi

# T15: SQL Query Optimization template exists
echo ""
echo "--- T15: SQL Query Optimization template ---"
if grep -q "Template: SQL Query Optimization" "$SKILL_PATH"; then
  pass "SQL Query Optimization template found"
else
  fail "SQL Query Optimization template missing"
fi

# T16: Rust Performance template exists
echo ""
echo "--- T16: Rust Performance template ---"
if grep -q "Template: Rust Performance" "$SKILL_PATH"; then
  pass "Rust Performance template found"
else
  fail "Rust Performance template missing"
fi

# T17: Lighthouse template exists
echo ""
echo "--- T17: Lighthouse template ---"
if grep -q "Template: Lighthouse" "$SKILL_PATH"; then
  pass "Lighthouse template found"
else
  fail "Lighthouse template missing"
fi

# T18: Custom fallback template exists
echo ""
echo "--- T18: Custom fallback template ---"
if grep -q "Template: Custom" "$SKILL_PATH"; then
  pass "Custom fallback template found"
else
  fail "Custom fallback template missing"
fi

# T19: All templates have metric_direction
echo ""
echo "--- T19: Templates include metric_direction ---"
TEMPLATE_COUNT=$(grep -c "metric_direction:" "$SKILL_PATH" || true)
if [[ "$TEMPLATE_COUNT" -ge 8 ]]; then
  pass "All templates have metric_direction ($TEMPLATE_COUNT found)"
else
  fail "Not all templates have metric_direction (only $TEMPLATE_COUNT found)"
fi

# =============================================
# INTENT PARSING TESTS
# =============================================
echo ""
echo "=== Intent Parsing Tests ==="

# T20: Intent parsing section exists
echo ""
echo "--- T20: Intent parsing section ---"
if grep -q "Intent Parsing" "$SKILL_PATH"; then
  pass "Intent Parsing section found"
else
  fail "Intent Parsing section missing"
fi

# T21: Test speed intent pattern
echo ""
echo "--- T21: Test speed intent ---"
if grep -q "optimize tests" "$SKILL_PATH" && grep -q "test_speed" "$SKILL_PATH"; then
  pass "Test speed intent mapping present"
else
  fail "Test speed intent mapping missing"
fi

# T22: Bundle size intent pattern
echo ""
echo "--- T22: Bundle size intent ---"
if grep -q "reduce bundle" "$SKILL_PATH" && grep -q "bundle_size" "$SKILL_PATH"; then
  pass "Bundle size intent mapping present"
else
  fail "Bundle size intent mapping missing"
fi

# T23: Direction keywords documented
echo ""
echo "--- T23: Direction keywords ---"
if grep -q "lower_is_better" "$SKILL_PATH" && grep -q "higher_is_better" "$SKILL_PATH"; then
  pass "Direction keywords documented"
else
  fail "Direction keywords missing"
fi

# =============================================
# WIZARD TESTS (Phase 1)
# =============================================
echo ""
echo "=== Phase 1: WIZARD Tests ==="

# T24: WIZARD section exists
echo ""
echo "--- T24: WIZARD section ---"
if grep -q "Phase 1: WIZARD" "$SKILL_PATH"; then
  pass "Phase 1: WIZARD section found"
else
  fail "Phase 1: WIZARD section missing"
fi

# T25: AskUserQuestion Q1 Objective
echo ""
echo "--- T25: Q1 Objective question ---"
if grep -q "Question 1.*Objective" "$SKILL_PATH"; then
  pass "Q1 Objective question documented"
else
  fail "Q1 Objective question missing"
fi

# T26: AskUserQuestion Q2 Budget
echo ""
echo "--- T26: Q2 Budget question ---"
if grep -q "Question 2.*Budget" "$SKILL_PATH"; then
  pass "Q2 Budget question documented"
else
  fail "Q2 Budget question missing"
fi

# T27: AskUserQuestion Q3 Scope (conditional)
echo ""
echo "--- T27: Q3 Scope question (conditional) ---"
if grep -q "Question 3.*Scope" "$SKILL_PATH" && grep -q "only if ambiguous" "$SKILL_PATH"; then
  pass "Q3 Scope question with conditional trigger"
else
  fail "Q3 Scope question or conditional missing"
fi

# T28: Budget options include Quick/Standard/Deep/Unlimited
echo ""
echo "--- T28: Budget options ---"
if grep -q "Quick" "$SKILL_PATH" && grep -q "Standard" "$SKILL_PATH" && grep -q "Deep" "$SKILL_PATH" && grep -q "Unlimited" "$SKILL_PATH"; then
  pass "All 4 budget options present"
else
  fail "Budget options incomplete"
fi

# T29: Preview field used in AskUserQuestion
echo ""
echo "--- T29: Preview field usage ---"
if grep -q "preview:" "$SKILL_PATH"; then
  pass "Preview field used in AskUserQuestion"
else
  fail "Preview field not used"
fi

# =============================================
# VALIDATE TESTS (Phase 2)
# =============================================
echo ""
echo "=== Phase 2: VALIDATE Tests ==="

# T30: VALIDATE section exists
echo ""
echo "--- T30: VALIDATE section ---"
if grep -q "Phase 2: VALIDATE" "$SKILL_PATH"; then
  pass "Phase 2: VALIDATE section found"
else
  fail "Phase 2: VALIDATE section missing"
fi

# T31: Git clean check (V1)
echo ""
echo "--- T31: Git clean validation ---"
if grep -q "Git is clean" "$SKILL_PATH"; then
  pass "Git clean check documented"
else
  fail "Git clean check missing"
fi

# T32: Eval harness execution check (V3)
echo ""
echo "--- T32: Eval harness validation ---"
if grep -q "Eval harness executes" "$SKILL_PATH"; then
  pass "Eval harness execution check documented"
else
  fail "Eval harness execution check missing"
fi

# T33: Metric extraction check (V4)
echo ""
echo "--- T33: Metric extraction validation ---"
if grep -q "Metric extracts" "$SKILL_PATH"; then
  pass "Metric extraction check documented"
else
  fail "Metric extraction check missing"
fi

# T34: Auto-fix for metric extraction
echo ""
echo "--- T34: Auto-fix metric extraction ---"
if grep -q "Auto-Fix" "$SKILL_PATH"; then
  pass "Auto-fix for metric extraction documented"
else
  fail "Auto-fix for metric extraction missing"
fi

# =============================================
# INVOCATION MODE TESTS
# =============================================
echo ""
echo "=== Invocation Mode Tests ==="

# T35: Smart Mode documented
echo ""
echo "--- T35: Smart Mode ---"
if grep -q "Smart Mode" "$SKILL_PATH"; then
  pass "Smart Mode documented"
else
  fail "Smart Mode not documented"
fi

# T36: Manual Mode documented
echo ""
echo "--- T36: Manual Mode ---"
if grep -q "Manual Mode" "$SKILL_PATH" && grep -q "\-\-manual" "$SKILL_PATH"; then
  pass "Manual Mode with --manual flag documented"
else
  fail "Manual Mode or --manual flag missing"
fi

# T37: Direct Mode documented
echo ""
echo "--- T37: Direct Mode ---"
if grep -q "Direct Mode" "$SKILL_PATH"; then
  pass "Direct Mode documented"
else
  fail "Direct Mode not documented"
fi

# =============================================
# BACKWARD COMPATIBILITY TESTS
# =============================================
echo ""
echo "=== Backward Compatibility Tests ==="

# T38: Original Setup Contract preserved (renamed to Manual Mode)
echo ""
echo "--- T38: Setup Contract preserved ---"
if grep -q "Setup Contract.*Manual Mode" "$SKILL_PATH"; then
  pass "Setup Contract preserved as Manual Mode"
else
  fail "Setup Contract section missing or not renamed"
fi

# T39: All 4 required parameters still documented
echo ""
echo "--- T39: Required parameters ---"
REQUIRED_PARAMS=0
grep -q "target.*File(s) the agent CAN modify" "$SKILL_PATH" && REQUIRED_PARAMS=$((REQUIRED_PARAMS + 1))
grep -q "eval_harness.*Command that produces" "$SKILL_PATH" && REQUIRED_PARAMS=$((REQUIRED_PARAMS + 1))
grep -q "primary_metric.*Name.*extraction pattern" "$SKILL_PATH" && REQUIRED_PARAMS=$((REQUIRED_PARAMS + 1))
grep -q "metric_direction.*Which direction" "$SKILL_PATH" && REQUIRED_PARAMS=$((REQUIRED_PARAMS + 1))
if [[ "$REQUIRED_PARAMS" -eq 4 ]]; then
  pass "All 4 required parameters preserved"
else
  fail "Only $REQUIRED_PARAMS of 4 required parameters found"
fi

# T40: Loop execution pattern unchanged
echo ""
echo "--- T40: Loop pattern unchanged ---"
if grep -q "LOOP FOREVER" "$SKILL_PATH" && grep -q "NEVER STOP" "$SKILL_PATH"; then
  pass "Loop execution pattern and NEVER STOP preserved"
else
  fail "Loop execution pattern changed"
fi

# =============================================
# AGENT DEFINITION TESTS
# =============================================
echo ""
echo "=== Agent Definition Tests ==="

# T41: Agent has Smart Setup Awareness section
echo ""
echo "--- T41: Agent Smart Setup Awareness ---"
if grep -q "Smart Setup Awareness" "$AGENT_PATH"; then
  pass "Agent has Smart Setup Awareness section"
else
  fail "Agent missing Smart Setup Awareness"
fi

# T42: Agent documents all 4 modes (Smart, Manual, Direct, Resume)
echo ""
echo "--- T42: Agent documents all modes ---"
MODES=0
grep -q "Smart Mode" "$AGENT_PATH" && MODES=$((MODES + 1))
grep -q "Manual Mode" "$AGENT_PATH" && MODES=$((MODES + 1))
grep -q "Direct Mode" "$AGENT_PATH" && MODES=$((MODES + 1))
grep -q "Resume Mode" "$AGENT_PATH" && MODES=$((MODES + 1))
if [[ "$MODES" -eq 4 ]]; then
  pass "Agent documents all 4 invocation modes"
else
  fail "Agent only documents $MODES of 4 modes"
fi

# T43: Agent version updated to 3.1.0
echo ""
echo "--- T43: Agent version ---"
if grep -q "v3.1.0" "$AGENT_PATH"; then
  pass "Agent version updated to v3.1.0"
else
  fail "Agent version not updated"
fi

# T44: Agent intent-to-config flow documented
echo ""
echo "--- T44: Agent intent-to-config ---"
if grep -q "Intent-to-Config" "$AGENT_PATH"; then
  pass "Intent-to-Config flow documented in agent"
else
  fail "Intent-to-Config flow missing from agent"
fi

# =============================================
# PROGRAM TEMPLATE TESTS
# =============================================
echo ""
echo "=== Program Template Tests ==="

# T45: Template has Smart Setup section
echo ""
echo "--- T45: Template Smart Setup ---"
if grep -q "Smart Setup" "$TEMPLATE_PATH"; then
  pass "Template has Smart Setup section"
else
  fail "Template missing Smart Setup section"
fi

# T46: Template version updated
echo ""
echo "--- T46: Template version ---"
if grep -q "v3.1.0" "$TEMPLATE_PATH"; then
  pass "Template version updated to v3.1.0"
else
  fail "Template version not updated"
fi

# T47: Template documents Phase 0/1/2
echo ""
echo "--- T47: Template phases ---"
PHASES=0
grep -q "Phase 0: SCOUT" "$TEMPLATE_PATH" && PHASES=$((PHASES + 1))
grep -q "Phase 1: WIZARD" "$TEMPLATE_PATH" && PHASES=$((PHASES + 1))
grep -q "Phase 2: VALIDATE" "$TEMPLATE_PATH" && PHASES=$((PHASES + 1))
if [[ "$PHASES" -eq 3 ]]; then
  pass "Template documents all 3 phases"
else
  fail "Template only documents $PHASES of 3 phases"
fi

# T48: Template preserves Configuration YAML block
echo ""
echo "--- T48: Configuration YAML preserved ---"
if grep -q '{{TARGET}}' "$TEMPLATE_PATH" && grep -q '{{EVAL_HARNESS}}' "$TEMPLATE_PATH"; then
  pass "Configuration YAML template placeholders preserved"
else
  fail "Configuration YAML template placeholders missing"
fi

# T49: Template --manual skip documented
echo ""
echo "--- T49: --manual skip ---"
if grep -q "\-\-manual" "$TEMPLATE_PATH"; then
  pass "--manual skip documented in template"
else
  fail "--manual skip missing from template"
fi

# =============================================
# ANALYSIS DOCUMENT TESTS
# =============================================
echo ""
echo "=== Analysis Document Tests ==="

# T50: Analysis document exists
echo ""
echo "--- T50: Analysis document ---"
if [[ -f "$ANALYSIS_PATH" ]]; then
  pass "Analysis document exists at docs/analysis/autoresearch-ux-improvement.md"
else
  fail "Analysis document not found"
fi

# =============================================
# RESULTS
# =============================================
echo ""
echo "=========================================="
TOTAL=$((PASS + FAIL))
echo "  RESULTS: $PASS/$TOTAL passed, $FAIL failed"
echo "=========================================="

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
