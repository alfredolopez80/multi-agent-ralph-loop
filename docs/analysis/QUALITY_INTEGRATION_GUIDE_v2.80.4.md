# Quality Gates Integration Guide - Step by Step

**Date**: 2026-01-28
**Version**: 1.0.0
**Status**: READY FOR IMPLEMENTATION
**Orchestrator Version**: v2.47.2

---

## Overview

This guide details how to integrate the 4-agent quality parallel system with the orchestrator using Claude Code 2.1+ native **Task tool** for multi-agent coordination.

**Based on**: [Native Multi-Agent Gates](https://github.com/mikekelly/claude-sneakpeek/blob/main/docs/research/native-multiagent-gates.md)

---

## Architecture Diagram

```
ORCHESTRATOR WORKFLOW (Enhanced)
│
├─ Step 6: EXECUTE-WITH-SYNC
│   ├─ 6a. LSA-VERIFY (architecture check)
│   ├─ 6b. IMPLEMENT (parallel if independent)
│   │   └─ NEW: 6b.5 QUALITY-PARALLEL ← NEW STEP
│   ├─ 6c. PLAN-SYNC (drift detection)
│   └─ 6d. MICRO-GATE (max 3 retries)
│
└─ Step 7: VALIDATE (Enhanced)
    ├─ 7a. READ QUALITY RESULTS ← NEW SUBSTEP
    ├─ 7b. CORRECTNESS (blocking)
    ├─ 7c. QUALITY (blocking)
    ├─ 7d. CONSISTENCY (advisory)
    └─ 7e. ADVERSARIAL (if complexity >= 7)
```

---

## STEP 1: Verify Scripts Are Executable

```bash
# Check scripts exist and are executable
ls -la .claude/scripts/quality-coordinator.sh
ls -la .claude/scripts/read-quality-results.sh

# Make executable if needed
chmod +x .claude/scripts/quality-coordinator.sh
chmod +x .claude/scripts/read-quality-results.sh
```

**Expected Output**:
```
-rwxr-xr-x  1 user  staff  2921 Jan 28 22:14 quality-coordinator.sh
-rwxr-xr-x  1 user  staff  4296 Jan 28 22:14 read-quality-results.sh
```

---

## STEP 2: Test Quality Coordinator Script

```bash
# Test with a sample file
./.claude/scripts/quality-coordinator.sh README.md 5
```

**Expected Output**:
```json
{
  "parallel_tasks": [
    {"task_file": ".../security_task.json", "agent": "security-auditor"},
    {"task_file": ".../code-review_task.json", "agent": "code-reviewer"},
    {"task_file": ".../deslop_task.json", "agent": "refactorer"},
    {"task_file": ".../stop-slop_task.json", "agent": "docs-writer"}
  ],
  "run_id": "20250128_221437_12345",
  "target": "README.md",
  "complexity": 5
}
```

---

## STEP 3: Test Results Reader Script

```bash
# First, create dummy results for testing
mkdir -p .claude/quality-results
echo '{"status": "complete", "findings": 0}' > .claude/quality-results/sec-context_test_12345.json
echo '{"status": "complete", "findings": 2}' > .claude/quality-results/code-review_test_12345.json
touch .claude/quality-results/sec-context_test_12345.done
touch .claude/quality-results/code-review_test_12345.done

# Test the reader
./.claude/scripts/read-quality-results.sh test_12345
```

**Expected Output**:
```json
{
  "run_id": "test_12345",
  "timestamp": "2026-01-28T...",
  "checks": {
    "sec-context": {...},
    "code-review": {...}
  },
  "summary": {
    "total_checks": 2,
    "completed": 2,
    "total_findings": 2
  }
}
```

---

## STEP 4: Update Orchestrator Skill

Edit `.claude/skills/orchestrator/SKILL.md` to add quality parallel steps.

### Add after Step 6b:

```markdown
### Step 6b.5: QUALITY-PARALLEL (NEW v2.53)

**Trigger**: `complexity >= 5` OR security-related code

**Execute quality coordinator**:
```bash
# Launch 4 parallel quality checks
QUALITY_RESULT=$(./.claude/scripts/quality-coordinator.sh "$TARGET_FILE" "$COMPLEXITY")

# Parse result and extract run_id
RUN_ID=$(echo "$QUALITY_RESULT" | jq -r '.run_id')

# Store run_id for step 7
echo "$RUN_ID" > .claude/quality-results/current_run_id.txt
```

**Quality Agents Launched** (parallel, non-blocking):
1. **Security** (27 patterns, P0/P1/P2)
2. **Code Review** (4 agents, confidence ≥80)
3. **Deslop** (AI code cleanup)
4. **Stop-Slop** (AI prose cleanup)

**Store RUN_ID** for retrieval in step 7.
```

### Add before Step 7a:

```markdown
### Step 7a: READ QUALITY RESULTS (NEW v2.53)

**Check if quality checks completed**:
```bash
# Read current run_id
if [[ -f .claude/quality-results/current_run_id.txt ]]; then
    CURRENT_RUN_ID=$(cat .claude/quality-results/current_run_id.txt)

    # Read aggregated results
    QUALITY_RESULTS=$(./.claude/scripts/read-quality-results.sh "$CURRENT_RUN_ID")

    # Parse results
    CRITICAL_COUNT=$(echo "$QUALITY_RESULTS" | jq -r '.summary.critical_findings // 0')
    TOTAL_FINDINGS=$(echo "$QUALITY_RESULTS" | jq -r '.summary.total_findings // 0')

    echo "Quality Results: $TOTAL_FINDINGS findings ($CRITICAL_COUNT critical)"
fi
```

**Decision Logic**:
- `CRITICAL_COUNT > 0`: BLOCK and require fixes
- `TOTAL_FINDINGS == 0`: Proceed to validation
- `TOTAL_FINDINGS > 0` but `CRITICAL_COUNT == 0`: Proceed with warnings
```

---

## STEP 5: Create Orchestrator Test Case

Create a test file to validate the full workflow:

```bash
# Create test file
cat > /tmp/test_quality.js <<'EOF'
// Test file with intentional issues for validation
const API_KEY = "sk-1234567890abcdef";  // P0: Hardcoded secret
const query = "SELECT * FROM users WHERE id=" + req.params.id;  // P0: SQL injection
console.log("This is AI-generated slop filler text.");  // Stop-slop
EOF

# Test the quality coordinator
./.claude/scripts/quality-coordinator.sh /tmp/test_quality.js 7
```

---

## STEP 6: Validate Task Tool Integration

Test that the orchestrator can use the Task tool to create quality tasks:

```bash
# In a Claude Code session, invoke orchestrator with a test task
/orchestrator "Create a simple user authentication function with email and password"
```

**Expected Behavior**:
1. Orchestrator classifies complexity
2. If complexity >= 5, launches quality coordinator
3. Quality coordinator creates 4 task definitions
4. Orchestrator should see these tasks available

---

## STEP 7: Verify Hook Registration

Verify that the async hook is properly registered:

```bash
# Check settings.json for quality-parallel-async hook
grep -A 5 "quality-parallel-async.sh" ~/.claude-sneakpeek/zai/config/settings.json
```

**Expected Output**:
```json
{
  "type": "command",
  "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/quality-parallel-async.sh",
  "async": true,
  "timeout": 60
}
```

---

## STEP 8: Test Full Workflow

### Manual Test

```bash
# 1. Create a test file
cat > test_file.js <<'EOF'
function authenticate(user, password) {
    const key = "hardcoded-key";  // Security issue
    const query = "SELECT * FROM users WHERE id=" + user.id;  // SQL injection
    // TODO: Implement this later  // Deslop candidate
    return "In conclusion, this is important.";  // Stop-slop candidate
}
EOF

# 2. Run quality coordinator
./.claude/scripts/quality-coordinator.sh test_file.js 7

# 3. Wait and read results
sleep 10 && ./.claude/scripts/read-quality-results.sh $(ls -t .claude/quality-results/*.done | head -1 | sed 's/.*_\([0-9]*_[0-9]*\).done/\1/')
```

### Orchestrator Test

```bash
# Invoke orchestrator with a task
/orchestrator "Implement user authentication with OAuth2"
```

**Watch for**:
- Quality coordinator being invoked
- 4 tasks being created
- Results being aggregated
- Orchestrator reading results before validation

---

## STEP 9: Validate Results Files

Check that results are being created correctly:

```bash
# List all quality result files
ls -la .claude/quality-results/

# Check aggregated results
cat .claude/quality-results/aggregated_*.json | jq '.'

# Check individual agent results
cat .claude/quality-results/sec-context_*.json | jq '.'
```

---

## STEP 10: Integration Complete Checklist

Verify all components are working:

- [ ] **Scripts executable**: `quality-coordinator.sh`, `read-quality-results.sh`
- [ ] **Hook registered**: `quality-parallel-async.sh` in settings.json
- [ ] **Skill available**: `/quality-gates-parallel` command works
- [ ] **Results created**: Files appear in `.claude/quality-results/`
- [ ] **Aggregation works**: `aggregated_*.json` contains all findings
- [ ] **Orchestrator integration**: Step 6b.5 and 7a execute correctly
- [ ] **Decision logic**: Orchestrator blocks on critical findings

---

## Troubleshooting

### Issue: Scripts not found

**Solution**: Verify scripts are in correct location:
```bash
ls -la .claude/scripts/quality-*.sh
```

### Issue: Hook not triggering

**Solution**: Check settings.json for correct path:
```bash
grep -B 2 -A 2 "quality-parallel-async" ~/.claude-sneakpeek/zai/config/settings.json
```

### Issue: No results created

**Solution**: Check script permissions and logs:
```bash
ls -la .claude/quality-results/
cat .claude/quality-results/coordinator.log
```

### Issue: Orchestrator doesn't read results

**Solution**: Verify run_id is stored:
```bash
cat .claude/quality-results/current_run_id.txt
```

---

## Next Steps After Integration

1. **Monitor performance**: Measure impact on orchestrator execution time
2. **Fine-tune threshold**: Adjust complexity trigger (currently >=5)
3. **Add metrics**: Track quality findings over time
4. **Update documentation**: Document any changes to workflow

---

## References

- Quality consolidation report: `docs/analysis/QUALITY_PARALLEL_CONSOLIDATION_v2.80.3.md`
- Async hooks correction: `docs/analysis/ASYNC_HOOKS_CORRECTION_v2.80.2.md`
- Native multi-agent gates: [claude-sneakpeek docs](https://github.com/mikekelly/claude-sneakpeek/blob/main/docs/research/native-multiagent-gates.md)
- Orchestrator skill: `.claude/skills/orchestrator/SKILL.md`
- Quality coordinator: `.claude/scripts/quality-coordinator.sh`
- Results reader: `.claude/scripts/read-quality-results.sh`
