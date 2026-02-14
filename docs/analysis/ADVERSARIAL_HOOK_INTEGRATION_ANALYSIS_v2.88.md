# Adversarial Analysis: Hook Integration Gaps

**Date**: 2026-02-14
**Version**: v2.88.0
**Status**: CRITICAL FINDINGS
**Methodology**: ZeroLeaks-inspired adversarial code analysis

---

## Executive Summary

This adversarial analysis identifies **5 critical gaps** in the integration between Agent Teams hooks (TeammateIdle, TaskCompleted, SubagentStart, SubagentStop) and the Stop hook (ralph-stop-quality-gate.sh) that could allow premature session termination or inconsistent VERIFIED_DONE enforcement.

---

## 1. Integration Flow Analysis

### Current Architecture

```
+------------------------------------------------------------------+
|                    HOOK INTEGRATION FLOW                          |
+------------------------------------------------------------------+
|                                                                   |
|   [TeammateIdle] ---------> [TaskCompleted]                       |
|        |                           |                              |
|        v                           v                              |
|   Quality Check              Quality Check                        |
|   (console.log,              (TODO, placeholder,                  |
|    debugger)                  console, debugger)                  |
|        |                           |                              |
|        +-------------+-------------+                              |
|                      |                                            |
|                      v                                            |
|              [SubagentStop]                                       |
|                      |                                            |
|                      v                                            |
|        +-------------+-------------+                              |
|        |                           |                              |
|        v                           v                              |
|   [ralph-* hook]            [glm5-* hook]                         |
|   MISSING!                  glm5-subagent-stop.sh                 |
|        |                           |                              |
|        +-------------+-------------+                              |
|                      |                                            |
|                      v                                            |
|              [Stop Hook]                                          |
|         ralph-stop-quality-gate.sh                                |
|                      |                                            |
|                      v                                            |
|              [VERIFIED_DONE?]                                     |
|                      |                                            |
|           YES <-----+-----> NO                                    |
|            |                 |                                    |
|            v                 v                                    |
|        [Allow Stop]    [Block + Continue]                         |
|                                                                   |
+------------------------------------------------------------------+
```

---

## 2. Critical Findings

### Finding #1: Missing `ralph-subagent-stop.sh` (CRITICAL)

**Severity**: CRITICAL
**Category**: Trust Boundary Violation
**Exploitability**: HIGH

**Description**:
The SubagentStop hook has a matcher for `ralph-*` subagents but points to `teammate-idle-quality-gate.sh` instead of a dedicated `ralph-subagent-stop.sh`:

```json
"SubagentStop": [
  {"matcher": "ralph-*", "hooks": [{"command": ".../teammate-idle-quality-gate.sh"}]}
]
```

**Impact**:
- `ralph-*` subagents use the TeammateIdle hook (wrong event)
- Quality checks meant for idle are applied to stop
- No dedicated quality gate when `ralph-*` subagents stop

**Attack Vector**:
```bash
# A ralph-coder could complete a task without proper stop validation
# because SubagentStop uses the wrong hook script
```

**Recommendation**:
Create dedicated `/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/ralph-subagent-stop.sh`:

```bash
#!/bin/bash
# ralph-subagent-stop.sh - Quality gate for ralph-* subagent termination
# VERSION: 2.88.0

# Check:
# 1. All assigned tasks completed
# 2. Quality gates passed
# 3. No blocking issues in state files

STATE_DIR="$HOME/.ralph/state"
SUBAGENT_ID=$(jq -r '.subagentId // "unknown"')

# Check if subagent has pending work
if [ -f "$STATE_DIR/$SUBAGENT_ID/task.json" ]; then
    STATUS=$(jq -r '.status // "unknown"' "$STATE_DIR/$SUBAGENT_ID/task.json")
    if [ "$STATUS" != "completed" ]; then
        jq -n '{"decision": "block", "reason": "Subagent has incomplete tasks"}'
        exit 2
    fi
fi

jq -n '{"decision": "approve", "reason": "All subagent tasks completed"}'
exit 0
```

---

### Finding #2: Stop Hook Missing Teammate State Check (HIGH)

**Severity**: HIGH
**Category**: State Synchronization Gap
**Exploitability**: MEDIUM

**Description**:
The `ralph-stop-quality-gate.sh` checks for pending team tasks but does NOT check:
1. Are all teammates idle (not actively working)?
2. Have all teammates reported completion?
3. Are there any teammates stuck in error state?

**Current Check (lines 122-141)**:
```bash
# Check 3: Are there pending tasks in a team task list?
TEAMS_DIR="$HOME/.claude/teams"
if [ -d "$TEAMS_DIR" ]; then
    for team_config in "$TEAMS_DIR"/*/config.json; do
        # Only counts pending tasks, not teammate status
        PENDING_COUNT=$(find "$TASKS_DIR" -name "*.json" -exec jq -r '.status' {} \; | grep -c "pending\|in_progress")
    done
fi
```

**Missing Checks**:
```bash
# NOT CHECKED: Are teammates still active?
# NOT CHECKED: Are teammates in error state?
# NOT CHECKED: Have all teammates reported final status?
```

**Impact**:
- Stop hook could approve while teammates are still working
- Teammates in error state could be abandoned
- Race condition between teammate completion and stop check

**Recommendation**:
Add teammate state verification:

```bash
# Check 3b: Are all teammates idle and healthy?
for member in "$TEAMS_DIR/$TEAM_NAME/members"/*.json; do
    MEMBER_STATUS=$(jq -r '.status // "unknown"' "$member")
    MEMBER_ERROR=$(jq -r '.last_error // ""' "$member")

    if [ "$MEMBER_STATUS" = "working" ]; then
        BLOCKING_ISSUES+="Teammate $(basename $member) still working. "
    fi

    if [ -n "$MEMBER_ERROR" ]; then
        BLOCKING_ISSUES+="Teammate $(basename $member) has error: $MEMBER_ERROR. "
    fi
done
```

---

### Finding #3: No State Update on Hook Blocking (HIGH)

**Severity**: HIGH
**Category**: Persistence Gap
**Exploitability**: MEDIUM

**Description**:
When hooks (TeammateIdle, TaskCompleted, Stop) block execution with exit 2, they do NOT update state files to track:
1. Why the block occurred
2. What feedback was provided
3. Retry count for same issue

**Current Behavior**:
```bash
# teammate-idle-quality-gate.sh (lines 77-84)
if [[ -n "$BLOCKING_ISSUES" ]]; then
    feedback=$(echo -e "$BLOCKING_ISSUES" | tr '\n' ' ')
    cat <<EOF
{"continue": false, "reason": "Quality issues found", "feedback": $feedback_escaped}
EOF
    exit 2  # No state update!
fi
```

**Impact**:
- No audit trail of blocked attempts
- Cannot detect repeated blocks on same issue
- Cannot implement "max retries" escalation

**Recommendation**:
Add state tracking:

```bash
# In each hook, before exit 2:
BLOCK_STATE="$STATE_DIR/${SESSION_ID}/blocks.json"
BLOCK_COUNT=$(jq -r '.block_count // 0' "$BLOCK_STATE" 2>/dev/null || echo "0")

jq -n \
    --arg count $((BLOCK_COUNT + 1)) \
    --arg reason "$feedback" \
    --arg time "$(date -Iseconds)" \
    '.block_count = ($count | tonumber) | .last_block = {reason: $reason, time: $time}' \
    > "$BLOCK_STATE"

# Escalate after 3 blocks on same issue
if [ $((BLOCK_COUNT + 1)) -ge 3 ]; then
    jq '. + {escalate: true}' "$BLOCK_STATE" > "${BLOCK_STATE}.tmp" && mv "${BLOCK_STATE}.tmp" "$BLOCK_STATE"
fi
```

---

### Finding #4: SubagentStart Does Not Register State (MEDIUM)

**Severity**: MEDIUM
**Category**: Reconnaissance Gap
**Exploitability**: LOW

**Description**:
The `ralph-subagent-start.sh` hook injects context but does NOT:
1. Register the subagent in a state file
2. Track parent-child relationships
3. Enable Stop hook to know which subagents exist

**Current Behavior (lines 35-36)**:
```bash
# Log the event
echo "[$(date '+%Y-%m-%d %H:%M:%S')] SubagentStart: ${subagent_id} (${subagent_type}) parent=${parent_id}" >> "$LOG_DIR/agent-teams.log"
# No state file created!
```

**Impact**:
- Stop hook cannot verify all subagents have completed
- No way to track subagent lifecycle
- Orphaned subagents possible

**Recommendation**:
Register subagent in state:

```bash
# In ralph-subagent-start.sh, after context injection:
SUBAGENT_STATE="$STATE_DIR/subagents/${subagent_id}.json"
mkdir -p "$(dirname "$SUBAGENT_STATE")"

jq -n \
    --arg id "$subagent_id" \
    --arg type "$subagent_type" \
    --arg parent "$parent_id" \
    --arg time "$(date -Iseconds)" \
    '{
        id: $id,
        type: $type,
        parent: $parent,
        status: "active",
        started_at: $time
    }' > "$SUBAGENT_STATE"
```

---

### Finding #5: No Cross-Session State Isolation (MEDIUM)

**Severity**: MEDIUM
**Category**: Context Overflow
**Exploitability**: LOW

**Description**:
State files are stored by `session_id` but there's no validation that:
1. The session_id is valid/current
2. State files from old sessions are cleaned up
3. Concurrent sessions don't interfere

**Current State Path**:
```bash
STATE_DIR="$HOME/.ralph/state"
ORCHESTRATOR_STATE="$STATE_DIR/${SESSION_ID}/orchestrator.json"
```

**Impact**:
- Stale state files could block new sessions
- Session ID collision could cause false blocks
- No cleanup of completed session state

**Recommendation**:
Add session validation and cleanup:

```bash
# In ralph-stop-quality-gate.sh, before checks:
SESSION_FILE="$STATE_DIR/${SESSION_ID}/session.json"
if [ ! -f "$SESSION_FILE" ]; then
    # No active session, allow stop
    echo '{"decision": "approve", "reason": "No active session"}'
    exit 0
fi

SESSION_AGE=$(jq -r '.age_seconds // 0' "$SESSION_FILE")
if [ "$SESSION_AGE" -gt 86400 ]; then  # 24 hours
    # Stale session, cleanup and allow stop
    rm -rf "$STATE_DIR/${SESSION_ID}"
    echo '{"decision": "approve", "reason": "Stale session cleaned up"}'
    exit 0
fi
```

---

## 3. Attack Tree Analysis

```
ROOT: Premature Session Termination
├── VECTOR 1: Subagent Stop Bypass
│   ├── Exploit: Missing ralph-subagent-stop.sh
│   ├── Probability: HIGH
│   └── Impact: Subagent stops without quality check
│
├── VECTOR 2: Teammate State Race
│   ├── Exploit: Stop hook checks before teammates finish
│   ├── Probability: MEDIUM
│   └── Impact: Incomplete work marked as VERIFIED_DONE
│
├── VECTOR 3: Block Count Exhaustion
│   ├── Exploit: No retry limit, infinite blocking
│   ├── Probability: LOW
│   └── Impact: DoS on Claude session
│
├── VECTOR 4: Session ID Collision
│   ├── Exploit: State files not isolated
│   ├── Probability: LOW
│   └── Impact: False blocking or false approval
│
└── VECTOR 5: Orphaned Subagent
│   ├── Exploit: SubagentStart doesn't register state
│   ├── Probability: MEDIUM
│   └── Impact: Subagent work not tracked for VERIFIED_DONE
```

---

## 4. Remediation Priority Matrix

| Finding | Severity | Exploitability | Effort | Priority |
|---------|----------|----------------|--------|----------|
| #1 Missing ralph-subagent-stop.sh | CRITICAL | HIGH | Low | **P0** |
| #2 Missing teammate state check | HIGH | MEDIUM | Medium | **P1** |
| #3 No state update on block | HIGH | MEDIUM | Low | **P1** |
| #4 SubagentStart no state | MEDIUM | LOW | Low | **P2** |
| #5 No session isolation | MEDIUM | LOW | Medium | **P2** |

---

## 5. Recommended Implementation Order

### Phase 1 (Immediate - P0)

1. **Create `ralph-subagent-stop.sh`**
   - Implement quality gate for `ralph-*` subagent termination
   - Register in settings.json under SubagentStop with matcher `ralph-*`

2. **Update settings.json SubagentStop**
   ```json
   "SubagentStop": [
     {
       "matcher": "ralph-*",
       "hooks": [
         {"command": ".../ralph-subagent-stop.sh", "timeout": 60}
       ]
     },
     {
       "matcher": "glm5-*",
       "hooks": [
         {"command": ".../glm5-subagent-stop.sh"}
       ]
     }
   ]
   ```

### Phase 2 (This Week - P1)

3. **Add teammate state verification to Stop hook**
   - Check teammate status in team config
   - Block if any teammate is "working"
   - Escalate if teammate has errors

4. **Add block state tracking**
   - Create `blocks.json` in state directory
   - Track block count and reasons
   - Implement 3-block escalation

### Phase 3 (Next Week - P2)

5. **Register subagent state on start**
   - Create subagent state file
   - Track parent-child relationship
   - Enable lifecycle tracking

6. **Implement session isolation**
   - Validate session age
   - Cleanup stale sessions
   - Prevent ID collision

---

## 6. Test Cases for Remediation

### Test: ralph-subagent-stop.sh

```bash
# Test 1: Incomplete task blocks stop
mkdir -p ~/.ralph/state/test-subagent
echo '{"status": "in_progress"}' > ~/.ralph/state/test-subagent/task.json
echo '{"subagentId": "test-subagent"}' | ./ralph-subagent-stop.sh
# Expected: exit 2, decision: block

# Test 2: Complete task allows stop
echo '{"status": "completed"}' > ~/.ralph/state/test-subagent/task.json
echo '{"subagentId": "test-subagent"}' | ./ralph-subagent-stop.sh
# Expected: exit 0, decision: approve
```

### Test: Teammate State in Stop Hook

```bash
# Test: Teammate still working blocks stop
mkdir -p ~/.claude/teams/test-team/members
echo '{"status": "working"}' > ~/.claude/teams/test-team/members/coder.json
# Run stop hook with active team
# Expected: BLOCKING_ISSUES contains "Teammate coder still working"
```

### Test: Block State Tracking

```bash
# Test: Multiple blocks escalate
for i in {1..3}; do
  # Trigger block
  echo '{"session_id": "test"}' | ./teammate-idle-quality-gate.sh
done
# Expected: blocks.json shows block_count: 3, escalate: true
```

---

## 7. Conclusion

The current hook integration has **5 gaps** that could compromise the VERIFIED_DONE guarantee. The most critical is the missing `ralph-subagent-stop.sh` hook, which allows `ralph-*` subagents to terminate without proper quality validation.

Immediate action required:
1. Create `ralph-subagent-stop.sh`
2. Update `settings.json` to register the hook
3. Add teammate state verification to Stop hook

---

## References

- [Stop Hook Integration Analysis](../hooks/STOP_HOOK_INTEGRATION_ANALYSIS.md)
- [Evolution Analysis v2.88](./EVOLUTION_ANALYSIS_v2.88.md)
- [Unified Architecture v2.87](../architecture/UNIFIED_ARCHITECTURE_v2.87.md)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
