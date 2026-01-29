# Swarm Mode Integration Analysis

**Date**: 2026-01-29
**Version**: v2.81.0
**Status**: IMPLEMENTATION REQUIRED
**Claude Code Version**: 2.1.22

## Summary

Claude Code 2.1.22 has **native swarm mode ALREADY ENABLED** (gate `tengu_brass_pebble` patched), but `/orchestrator` and `/loop` commands are not using swarm parameters. This analysis identifies required changes to enable full multi-agent orchestration.

## Current State

### ✅ What Works

| Component | Status | Details |
|-----------|--------|---------|
| **Claude Code** | ✅ 2.1.22 | Meets requirement (≥2.1.16) |
| **Swarm Gate** | ✅ Patched | `tengu_brass_pebble` not found = enabled |
| **TeammateTool** | ✅ Available | Present in cli.js |
| **Task Tool** | ✅ Available | Can spawn subagents |
| **ExitPlanMode** | ✅ Supports Swarm | Accepts `launchSwarm` + `teammateCount` |

### ❌ What's Missing

| Component | Status | Details |
|-----------|--------|---------|
| **Agent Env Vars** | ❌ Missing | No `CLAUDE_CODE_AGENT_*` in settings.json |
| **Swarm Parameters** | ❌ Not Used | Task tool calls lack `team_name`, `mode`, `launchSwarm` |
| **Team Coordination** | ❌ Not Active | No multi-agent collaboration |

## Required Changes

### 1. Environment Variables (settings.json)

Add to `~/.claude-sneakpeek/zai/config/settings.json`:

```json
{
  "env": {
    // ... existing vars ...

    // Agent Identity (REQUIRED for swarm mode)
    "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop",

    // Agent Behavior (OPTIONAL)
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"  // Auto-approve plans for subagents
  }
}
```

### 2. /orchestrator Command Updates

**Current implementation:**
```yaml
Task:
  subagent_type: "orchestrator"
  model: "opus"
  prompt: "$ARGUMENTS"
```

**Required changes:**
```yaml
Task:
  subagent_type: "orchestrator"
  model: "sonnet"                      # glm-4.7 is PRIMARY, sonnet manages it
  prompt: "$ARGUMENTS"
  team_name: "orchestration-team"      # NEW - Creates team
  name: "orchestrator-lead"            # NEW - Agent name in team
  mode: "delegate"                     # NEW - Enables delegation to teammates
```

**ExitPlanMode changes:**
```yaml
ExitPlanMode:
  launchSwarm: true                    # NEW - Spawn teammates
  teammateCount: 3                     # NEW - Number of teammates (1-5)
```

### 3. /loop Command Updates

**Current implementation:**
```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"                      # glm-4.7 is PRIMARY, sonnet manages it
  max_iterations: 15
  run_in_background: true
  prompt: |
    Execute the following task iteratively until VERIFIED_DONE...
```

**Required changes:**
```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"                      # glm-4.7 is PRIMARY, sonnet manages it
  max_iterations: 15
  run_in_background: true
  team_name: "loop-execution-team"     # NEW - Creates team
  name: "loop-lead"                    # NEW - Agent name in team
  mode: "delegate"                     # NEW - Can delegate to teammates
  prompt: |
    Execute the following task iteratively until VERIFIED_DONE...
```

### 4. Agent Integration Pattern

**Swarm-Enabled Task Tool Pattern:**
```yaml
# Spawn subagent WITHIN team context
Task:
  subagent_type: "code-reviewer"
  team_name: "orchestration-team"      # Same team as parent
  name: "reviewer-1"                   # Unique name within team
  mode: "delegate"                     # Required for swarm
  prompt: "Review the following code..."

# Exit plan mode WITH swarm launch
ExitPlanMode:
  launchSwarm: true
  teammateCount: 3
```

**Benefits:**
- **Team mailbox**: Inter-agent messaging (`teammate_mailbox`)
- **Shared task list**: All teammates see same tasks
- **Plan approval**: Leader can approve/reject teammate plans
- **Graceful shutdown**: Coordinated termination

## Swarm Mode Features (Now Available)

### TeammateTool Operations

| Operation | Purpose |
|-----------|---------|
| `spawnTeam` | Create new team (= project = task list) |
| `approveJoin` | Approve teammate joining request |
| `rejectJoin` | Reject with feedback |
| `approvePlan` | Approve teammate's plan |
| `rejectPlan` | Reject plan with feedback |
| `requestShutdown` | Gracefully shutdown teammate |

### Environment Variables Reference

| Variable | Purpose | Required |
|----------|---------|----------|
| `CLAUDE_CODE_AGENT_ID` | Unique agent identifier | **Yes** |
| `CLAUDE_CODE_AGENT_NAME` | Human-readable name | **Yes** |
| `CLAUDE_CODE_TEAM_NAME` | Team identifier | **Yes** |
| `CLAUDE_CODE_PLAN_MODE_REQUIRED` | Require plan approval | Optional |
| `CLAUDE_CODE_AGENT_SWARMS` | Disable swarm (0/false) | Optional |

### Task Tool Modes

| Mode | Description | When to Use |
|------|-------------|-------------|
| `default` | Standard execution | Single-agent tasks |
| `delegate` | **Can delegate to teammates** | **Swarm mode (REQUIRED)** |
| `bypassPermissions` | Elevated permissions | Trusted agents |

## Implementation Priority

### Phase 1: Core Configuration (HIGH PRIORITY)
1. ✅ Verify swarm mode enabled (DONE - already patched)
2. ⏳ Add agent environment variables to settings.json
3. ⏳ Update /orchestrator command with swarm parameters
4. ⏳ Update /loop command with swarm parameters

### Phase 2: Testing & Validation (HIGH PRIORITY)
1. ⏳ Test /orchestrator with `launchSwarm: true`
2. ⏳ Test /loop with team context
3. ⏳ Verify teammate mailbox works
4. ⏳ Test plan approval/rejection flow

### Phase 3: Advanced Features (MEDIUM PRIORITY)
1. ⏳ Implement teammate coordination hooks
2. ⏳ Add swarm mode to quality gates
3. ⏳ Create multi-agent quality validation

## Testing Strategy

### Manual Test 1: Basic Swarm

```bash
# After implementation
/orchestrator "test swarm mode"

# Expected behavior:
# 1. Orchestrator agent creates team "orchestration-team"
# 2. Calls ExitPlanMode with launchSwarm: true
# 3. Spawns 3 teammates (code-reviewer, test-architect, security-auditor)
# 4. Teammates coordinate via shared task list
# 5. Leader approves plans from teammates
```

### Manual Test 2: Loop with Team

```bash
/loop "implement feature X"

# Expected behavior:
# 1. Loop agent creates team "loop-execution-team"
# 2. Can delegate to teammates (e.g., code-reviewer)
# 3. All teammates share same task list
# 4. Progress tracked across team
```

### Manual Test 3: Teammate Mailbox

```bash
# In teammate session
SendMessage:
  type: "message"
  recipient: "orchestrator-lead"
  content: "Code review complete, 3 issues found"

# Expected: Leader receives message in mailbox
```

## Verification Commands

```bash
# 1. Verify swarm mode enabled
grep -c "tengu_brass_pebble" ~/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js
# Expected: 0 (gate patched)

# 2. Verify TeammateTool available
grep -c "TeammateTool" ~/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js
# Expected: >0 (tool exists)

# 3. Check agent env vars (after implementation)
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.env | with_entries(select(.key | test("AGENT"; "i")))'
# Expected: CLAUDE_CODE_AGENT_ID, CLAUDE_CODE_AGENT_NAME, CLAUDE_CODE_TEAM_NAME

# 4. Test swarm spawn (after implementation)
# Run /orchestrator and check if teammates spawn
```

## References

- [Native Multi-Agent Gates Documentation](https://github.com/mikekelly/claude-sneakpeek/blob/main/docs/research/native-multiagent-gates.md)
- [Swarm Mode Demo Video](https://x.com/NicerInPerson/status/2014989679796347375)
- [Claude Code Swarm Orchestration Skill](https://gist.github.com/kieranklaassen/4f2aba89594a4aea4ad64d753984b2ea)
- [Claude Code Swarms Blog](https://zenvanriel.nl/ai-engineer-blog/claude-code-swarms-multi-agent-orchestration/)

## Open Questions

1. **Should we auto-approve plans?** Currently `CLAUDE_CODE_PLAN_MODE_REQUIRED=false` means auto-approve. Should we require approval for complexity ≥7?

2. **How many teammates for /orchestrator?** Analysis suggests 3 teammates (code-reviewer, test-architect, security-auditor). Should this be configurable?

3. **Should /loop use swarm?** Loop is inherently iterative. Should it spawn teammates for parallel execution, or stay single-agent?

4. **Teammate cleanup?** How do we ensure teammates gracefully shut down after task completion?

## Next Steps

1. ✅ Complete analysis (this document)
2. ⏳ Update settings.json with agent env vars
3. ⏳ Update /orchestrator command with swarm parameters
4. ⏳ Update /loop command with swarm parameters
5. ⏳ Test swarm mode functionality
6. ⏳ Document swarm mode usage in CLAUDE.md

---

**Status**: Ready for implementation
**Estimated effort**: 2-3 hours
**Risk level**: LOW (swarm mode already enabled, just need configuration)
