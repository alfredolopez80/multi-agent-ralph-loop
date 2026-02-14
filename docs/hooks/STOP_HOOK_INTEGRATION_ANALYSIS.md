# Stop Hook Integration Analysis for Ralph Wiggum Loop

**Date**: 2026-02-14
**Version**: v2.87.0 (proposed)
**Status**: ANALYSIS COMPLETE
**Related**: [COMPLETE_HOOKS_REFERENCE.md](./COMPLETE_HOOKS_REFERENCE.md)

## Executive Summary

This document analyzes how to integrate Claude Code's Stop hook with the `/orchestrator` and `/loop` skills to prevent premature session termination. The goal is to implement a "Ralph Wiggum Loop" pattern where Claude Code **does not stop** until all VERIFIED_DONE conditions are met.

---

## 1. Problem Statement

### Current Behavior

The current Stop hooks in multi-agent-ralph-loop:
- `reflection-engine.sh` - Always returns `{"decision": "approve"}`
- `stop-verification.sh` - Always returns `{"decision": "approve"}`
- `orchestrator-report.sh` - Always returns `{"decision": "approve"}`

**Gap**: None of these hooks actually **block** when conditions aren't met. Claude can stop at any time, even if:
- Tasks are incomplete
- Tests are failing
- Quality gates haven't passed
- VERIFIED_DONE conditions aren't satisfied

### Desired Behavior (Ralph Wiggum Loop)

```
     EXECUTE
        |
        v
    +---------+
    | VALIDATE |
    +---------+
        |
   Quality    YES    +---------------+
   Passed? --------> | VERIFIED_DONE |
        |            +---------------+
        | NO
        v
    +---------+
    | BLOCK   | <-- Stop hook returns {"decision": "block"}
    +---------+       with reason to continue
        |
        +-------> Claude continues working (NOT stopping)
```

---

## 2. Stop Hook Technical Details

### When Stop Hook Fires

- When Claude **finishes responding**
- Does **NOT** fire on user interrupts
- Fires at the end of every turn

### Input Schema (stdin JSON)

```json
{
  "session_id": "abc123",
  "transcript_path": "~/.claude/projects/.../transcript.jsonl",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": false    // CRITICAL FIELD!
}
```

### Output Schema

**Method 1: Exit Code 2 (Simple)**
```bash
echo "Tests failing. Fix before stopping." >&2
exit 2  # Blocks stop, stderr is fed back to Claude
```

**Method 2: JSON Output (Recommended)**
```json
{
  "decision": "block",
  "reason": "Quality gates not passed. Fix: [specific issues]"
}
```

### Exit Codes

| Exit Code | Meaning | Effect |
|-----------|---------|--------|
| **0** | Approve | Claude stops |
| **2** | Block | Claude continues with stderr/reason as instruction |
| **Any other** | Error | Claude stops (stderr shown in verbose mode only) |

### CRITICAL: Preventing Infinite Loops

The `stop_hook_active` field is `true` when Claude is already continuing due to a previous Stop hook block. **Always check this:**

```bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
  exit 0  # MUST allow Claude to stop to prevent infinite loop!
fi
```

---

## 3. VERIFIED_DONE Conditions (from /orchestrator)

The Stop hook should check these conditions before allowing Claude to stop:

| # | Condition | Type | Check Method |
|---|-----------|------|--------------|
| 1 | Smart Memory Search complete | Pre-step | Session state file |
| 2 | Task classified | Planning | Classification result |
| 3 | MUST_HAVE questions answered | Planning | Q&A log |
| 4 | Plan approved | Planning | Plan state file |
| 5 | Implementation complete | Execution | Git diff / files |
| 6 | CORRECTNESS passed | Quality | Build/syntax check |
| 7 | QUALITY passed | Quality | Type/lint check |
| 8 | Adversarial passed (if complexity >= 7) | Quality | Review results |
| 9 | Retrospective done + learnings saved | Learning | Memory check |

---

## 4. Implementation Design

### 4.1 New Hook: `ralph-stop-quality-gate.sh`

```bash
#!/bin/bash
# ralph-stop-quality-gate.sh - Quality gate for Stop event
# VERSION: 2.87.0
#
# Triggered by: Stop hook event
# Purpose: Prevent Claude from stopping until VERIFIED_DONE conditions are met
#
# Exit codes:
#   0 = Allow Claude to stop
#   2 = Block stop + send feedback to continue working
#
# Output (stdout JSON):
#   {"decision": "approve", "reason": "All conditions met"}
#   {"decision": "block", "reason": "Specific issues to fix"}

set -euo pipefail

# Configuration
REPO_ROOT="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
STATE_DIR="$HOME/.ralph/state"
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"

# Read stdin
INPUT=$(cat)

# CRITICAL: Check stop_hook_active to prevent infinite loops
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    # Claude is already continuing from a previous block
    # MUST allow stop to prevent infinite loop
    echo '{"decision": "approve", "reason": "Previous block already active"}'
    exit 0
fi

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop hook fired: session=$SESSION_ID" >> "$LOG_DIR/stop-hook.log"

# Initialize issues
BLOCKING_ISSUES=""

# ============================================
# VERIFIED_DONE CONDITION CHECKS
# ============================================

# Check 1: Is there an active orchestrator/loop session?
ORCHESTRATOR_STATE="$STATE_DIR/${SESSION_ID}/orchestrator.json"
if [ -f "$ORCHESTRATOR_STATE" ]; then
    CURRENT_PHASE=$(jq -r '.phase // "unknown"' "$ORCHESTRATOR_STATE")
    VERIFIED_DONE=$(jq -r '.verified_done // false' "$ORCHESTRATOR_STATE")

    if [ "$VERIFIED_DONE" != "true" ]; then
        BLOCKING_ISSUES+="Orchestrator phase '$CURRENT_PHASE' not complete. "
    fi
fi

# Check 2: Are there pending tasks in the task list?
TASKS_DIR="$STATE_DIR/${SESSION_ID}/tasks"
if [ -d "$TASKS_DIR" ]; then
    PENDING_COUNT=$(find "$TASKS_DIR" -name "*.json" -exec jq -r '.status' {} \; 2>/dev/null | grep -c "pending\|in_progress" || echo "0")
    if [ "$PENDING_COUNT" -gt 0 ]; then
        BLOCKING_ISSUES+="$PENDING_COUNT pending/in-progress tasks. "
    fi
fi

# Check 3: Are there uncommitted changes?
UNCOMMITTED=$(git status --porcelain 2>/dev/null | head -5 || echo "")
if [ -n "$UNCOMMITTED" ]; then
    # This is ADVISORY for loops, BLOCKING for orchestrator
    if [ -f "$ORCHESTRATOR_STATE" ]; then
        BLOCKING_ISSUES+="Uncommitted changes detected. "
    fi
fi

# Check 4: Did the last quality gate pass?
QUALITY_STATE="$STATE_DIR/${SESSION_ID}/quality-gate.json"
if [ -f "$QUALITY_STATE" ]; then
    LAST_RESULT=$(jq -r '.last_result // "unknown"' "$QUALITY_STATE")
    if [ "$LAST_RESULT" = "failed" ]; then
        BLOCKING_ISSUES+="Quality gate failed. Fix issues before stopping. "
    fi
fi

# Check 5: Are there failing tests? (optional, project-specific)
# if command -v npm &>/dev/null && [ -f "package.json" ]; then
#     if ! npm test --quiet 2>/dev/null; then
#         BLOCKING_ISSUES+="Tests failing. "
#     fi
# fi

# ============================================
# DECISION OUTPUT
# ============================================

if [ -n "$BLOCKING_ISSUES" ]; then
    # Block stop with specific feedback
    jq -n --arg reason "$BLOCKING_ISSUES" '{
        decision: "block",
        reason: $reason
    }'
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop BLOCKED: $BLOCKING_ISSUES" >> "$LOG_DIR/stop-hook.log"
    exit 2
else
    # All conditions met, allow stop
    echo '{"decision": "approve", "reason": "All VERIFIED_DONE conditions met"}'
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Stop APPROVED" >> "$LOG_DIR/stop-hook.log"
    exit 0
fi
```

### 4.2 Settings Configuration

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/ralph-stop-quality-gate.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

---

## 5. Integration with /orchestrator and /loop

### 5.1 Orchestrator Integration

The orchestrator skill writes state to `~/.ralph/state/{session_id}/orchestrator.json`:

```json
{
  "phase": "implementation",
  "verified_done": false,
  "conditions": {
    "memory_search": true,
    "task_classified": true,
    "must_have_answered": true,
    "plan_approved": true,
    "implementation_complete": false,
    "correctness_passed": null,
    "quality_passed": null,
    "adversarial_passed": null,
    "retrospective_done": false
  },
  "last_updated": "2026-02-14T12:00:00Z"
}
```

The Stop hook reads this state and blocks if `verified_done` is `false`.

### 5.2 Loop Integration

The loop skill writes state to `~/.ralph/state/{session_id}/loop.json`:

```json
{
  "task": "fix all type errors",
  "iteration": 3,
  "max_iterations": 25,
  "validation_result": "failed",
  "last_error": "Type error in src/auth.ts:42",
  "verified_done": false
}
```

The Stop hook blocks if:
- `verified_done` is `false` AND
- `iteration` < `max_iterations`

### 5.3 Flow Diagram

```
User runs: /orchestrator "implement auth"
    |
    v
[Orchestrator skill starts]
    |
    +-- Writes orchestrator.json with verified_done: false
    |
    v
[Execution phases...]
    |
    v
[Claude finishes turn]
    |
    v
[Stop hook fires: ralph-stop-quality-gate.sh]
    |
    +-- Check stop_hook_active?
    |       |
    |       +-- YES --> exit 0 (allow stop - prevent loop)
    |       |
    |       +-- NO --> Check VERIFIED_DONE conditions
    |               |
    |               +-- All met? --> exit 0 (allow stop)
    |               |
    |               +-- Not met? --> exit 2 with reason
    |                       |
    |                       v
    |               [Claude receives reason as next instruction]
    |                       |
    |                       v
    |               [Claude continues working]
    |                       |
    |                       v
    |               [Claude finishes turn again]
    |                       |
    |                       v
    |               [Stop hook fires again with stop_hook_active: true]
    |                       |
    |                       v
    |               [Hook exits 0 - allows stop this time]
    |
    v
[Eventually: All conditions met]
    |
    v
[verified_done: true in state]
    |
    v
[Stop hook allows stop]
    |
    v
[VERIFIED_DONE]
```

---

## 6. Agent Teams Hooks Integration

### 6.1 TeammateIdle Hook

Current: `teammate-idle-quality-gate.sh`

Checks before allowing teammate to go idle:
- No console.log/debug statements
- No debugger statements

**Already implemented** - Exit 2 blocks idle.

### 6.2 TaskCompleted Hook

Current: `task-completed-quality-gate.sh`

Checks before allowing task completion:
- No TODO/FIXME/XXX
- No placeholder code
- No console.log/debug
- No debugger statements

**Already implemented** - Exit 2 prevents completion.

### 6.3 SubagentStop Hook

For `ralph-*` subagents, implement quality gate:

```json
{
  "decision": "block",
  "reason": "Subagent has not completed all required tasks"
}
```

---

## 7. Comparison: Stop Hook vs Other Blocking Hooks

| Hook Event | Decision Method | Blocking Behavior | Use Case |
|------------|-----------------|-------------------|----------|
| **Stop** | `decision: "block"` or exit 2 | Claude continues conversation | Prevent premature session end |
| **PreToolUse** | `permissionDecision: "deny"` | Tool call blocked | Block dangerous commands |
| **UserPromptSubmit** | `decision: "block"` | Prompt not processed | Validate/modify user input |
| **TeammateIdle** | Exit 2 only | Teammate keeps working | Quality gate before idle |
| **TaskCompleted** | Exit 2 only | Task not marked complete | Quality gate before completion |
| **SubagentStop** | `decision: "block"` | Subagent continues | Quality gate for subagents |

---

## 8. Anti-Patterns to Avoid

### 8.1 Infinite Loop

**WRONG**:
```bash
# Always blocks - infinite loop!
echo '{"decision": "block", "reason": "Keep working"}'
exit 2
```

**CORRECT**:
```bash
INPUT=$(cat)
if [ "$(echo "$INPUT" | jq -r '.stop_hook_active')" = "true" ]; then
    exit 0  # Allow stop on second pass
fi
# ... check conditions ...
```

### 8.2 Forgetting to Update State

**WRONG**:
- Stop hook checks `verified_done` field
- Skills never set `verified_done: true`
- Claude blocks forever

**CORRECT**:
- `/orchestrator` updates state after each phase
- `/loop` updates state after each iteration
- Final state: `verified_done: true`

### 8.3 Blocking Without Actionable Feedback

**WRONG**:
```json
{"decision": "block", "reason": "Not done yet"}
```

**CORRECT**:
```json
{"decision": "block", "reason": "CORRECTNESS gate failed: 3 type errors in src/auth.ts. Fix these before stopping."}
```

---

## 9. Testing Strategy

### 9.1 Unit Tests

```bash
# Test 1: stop_hook_active = true should always allow stop
echo '{"stop_hook_active": true}' | ./ralph-stop-quality-gate.sh
# Expected: exit 0

# Test 2: No state file should allow stop
echo '{"stop_hook_active": false, "session_id": "test-123"}' | ./ralph-stop-quality-gate.sh
# Expected: exit 0

# Test 3: Incomplete orchestrator should block
mkdir -p ~/.ralph/state/test-456
echo '{"verified_done": false, "phase": "implementation"}' > ~/.ralph/state/test-456/orchestrator.json
echo '{"stop_hook_active": false, "session_id": "test-456"}' | ./ralph-stop-quality-gate.sh
# Expected: exit 2

# Test 4: Complete orchestrator should allow stop
echo '{"verified_done": true, "phase": "complete"}' > ~/.ralph/state/test-789/orchestrator.json
echo '{"stop_hook_active": false, "session_id": "test-789"}' | ./ralph-stop-quality-gate.sh
# Expected: exit 0
```

### 9.2 Integration Tests

```bash
# Test with actual /loop skill
/loop "create a simple hello world function" --max-iterations 5
# Observe: Stop hook should block until tests pass

# Test with /orchestrator
/orchestrator "implement user authentication"
# Observe: Stop hook should block until VERIFIED_DONE
```

---

## 10. Recommendations

### 10.1 Immediate Actions

1. **Create** `ralph-stop-quality-gate.sh` hook
2. **Register** in `~/.claude/settings.json` under Stop event
3. **Update** `/orchestrator` and `/loop` skills to write state files
4. **Test** with simple tasks to verify blocking behavior

### 10.2 Medium-term Improvements

1. **Implement** prompt-based Stop hook for complex condition evaluation
2. **Add** more granular condition checks (test coverage, lint, etc.)
3. **Create** dashboard for monitoring Stop hook decisions

### 10.3 Long-term Vision

1. **Agent-based Stop hook** that can read code, run tests, and make sophisticated decisions
2. **Integration** with external CI/CD for real-world validation
3. **Learning** from past blocks to improve condition detection

---

## 11. References

- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code Agent Teams](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Sub-agents](https://code.claude.com/docs/en/sub-agents)
- [GitHub Issue #19115](https://github.com/anthropics/claude-code/issues/19115) - JSON Response Schema Confusion
- [COMPLETE_HOOKS_REFERENCE.md](./COMPLETE_HOOKS_REFERENCE.md) - Ralph Hooks Documentation

---

## Appendix A: Full Hook Event Reference

| Event | Fires When | Can Block? | Decision Method |
|-------|------------|------------|-----------------|
| SessionStart | Session begins | No | - |
| UserPromptSubmit | User submits prompt | Yes | `decision: "block"` |
| PreToolUse | Before tool call | Yes | `permissionDecision` |
| PermissionRequest | Permission dialog | Yes | `decision.behavior` |
| PostToolUse | After tool success | No* | - |
| PostToolUseFailure | After tool failure | No* | - |
| Notification | Claude notification | No | - |
| SubagentStart | Subagent spawned | No | `additionalContext` |
| SubagentStop | Subagent finishes | Yes | `decision: "block"` |
| **Stop** | Claude finishes | **Yes** | `decision: "block"` |
| TeammateIdle | Teammate goes idle | Yes | Exit 2 |
| TaskCompleted | Task marked complete | Yes | Exit 2 |
| PreCompact | Before compaction | No | - |
| SessionEnd | Session terminates | No | - |

*PostToolUse can provide feedback but cannot block the action (already completed)

---

## Appendix B: State File Schemas

### orchestrator.json

```json
{
  "session_id": "abc123",
  "task": "implement auth",
  "phase": "implementation",
  "verified_done": false,
  "conditions": {
    "memory_search": true,
    "task_classified": true,
    "must_have_answered": true,
    "plan_approved": true,
    "implementation_complete": false,
    "correctness_passed": null,
    "quality_passed": null,
    "adversarial_passed": null,
    "retrospective_done": false
  },
  "iterations": 3,
  "created_at": "2026-02-14T10:00:00Z",
  "last_updated": "2026-02-14T12:00:00Z"
}
```

### loop.json

```json
{
  "session_id": "abc123",
  "task": "fix type errors",
  "iteration": 5,
  "max_iterations": 25,
  "validation_result": "failed",
  "last_error": "src/auth.ts:42 - Type 'string' is not assignable to type 'number'",
  "verified_done": false,
  "created_at": "2026-02-14T10:00:00Z",
  "last_updated": "2026-02-14T12:00:00Z"
}
```

### quality-gate.json

```json
{
  "session_id": "abc123",
  "last_result": "failed",
  "stages": {
    "correctness": {
      "status": "passed",
      "details": "No syntax errors"
    },
    "quality": {
      "status": "failed",
      "details": "3 type errors found"
    },
    "security": {
      "status": "pending",
      "details": null
    }
  },
  "last_updated": "2026-02-14T12:00:00Z"
}
```
