# Swarm Mode Settings Configuration Guide

**Version**: 2.81.0
**Date**: 2026-01-29
**Status**: PRODUCTION READY

## Overview

This guide explains **EXACTLY** what settings are required for Swarm Mode v2.81.0 to work correctly, why each setting is needed, and how to reproduce this configuration on any machine.

---

## Table of Contents

1. [Required Settings](#required-settings)
2. [Setting Explanations](#setting-explanations)
3. [Configuration Validation](#configuration-validation)
4. [Reproduction Guide](#reproduction-guide)
5. [Troubleshooting](#troubleshooting)
6. [Environment-Specific Notes](#environment-specific-notes)

---

## Required Settings

### Location

```
~/.claude-sneakpeek/zai/config/settings.json
```

**IMPORTANT**: This is the REAL configuration location for the claude-sneakpeek/zai variant.

**NOT**: `~/.claude/settings.json` (legacy location, unused)

### Complete Configuration Block

```json
{
  "env": {
    // ... existing environment variables ...

    // Swarm Mode Agent Identity (REQUIRED)
    "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"
  },
  "permissions": {
    "allow": [
      // ... existing permissions ...
    ],
    "deny": [
      // ... existing permissions ...
    ],
    "defaultMode": "delegate"  // REQUIRED for swarm mode
  },
  "model": "glm-4.7"  // PRIMARY model for all tasks
}
```

---

## Setting Explanations

### 1. CLAUDE_CODE_AGENT_ID

**Value**: `"claude-orchestrator"`

**Purpose**: Unique identifier for this agent instance

**Why Required**:
- Identifies the agent in multi-agent coordination
- Used for inter-agent messaging (teammate mailbox)
- Required for TeammateTool to know who is sending messages

**Valid Values**: Any unique string (no spaces)

**Examples**:
- `"claude-orchestrator"` - Main orchestrator
- `"code-reviewer-1"` - Code reviewer instance
- `"test-architect"` - Test architect

**How It Works**:
```javascript
// When agent sends message to teammate
SendMessage({
  type: "message",
  sender: CLAUDE_CODE_AGENT_ID,  // "claude-orchestrator"
  recipient: "code-reviewer-1",
  content: "Please review this code"
})
```

### 2. CLAUDE_CODE_AGENT_NAME

**Value**: `"Orchestrator"`

**Purpose**: Human-readable name for this agent

**Why Required**:
- Displayed in UI and logs
- Used for plan approval messages
- Helps identify agents in multi-agent workflows

**Valid Values**: Any descriptive string

**Examples**:
- `"Orchestrator"` - Main coordinator
- `"Code Reviewer"` - Review agent
- `"Test Architect"` - Testing specialist

**How It Works**:
```javascript
// When teammate receives message
console.log(`Message from ${CLAUDE_CODE_AGENT_NAME}: ${content}`)
// Output: "Message from Orchestrator: Please review this code"
```

### 3. CLAUDE_CODE_TEAM_NAME

**Value**: `"multi-agent-ralph-loop"`

**Purpose**: Team identifier for shared task list and mailbox

**Why Required**:
- All agents on same team share task list
- Teammate mailbox only works within same team
- Enables coordination between spawned teammates

**Valid Values**: Any unique string (no spaces)

**Examples**:
- `"multi-agent-ralph-loop"` - Main project team
- `"code-review-team"` - Dedicated review team
- `"testing-team"` - Test execution team

**How It Works**:
```javascript
// Agents on same team can see each other's tasks
const teamTasks = getTasksForTeam(CLAUDE_CODE_TEAM_NAME)
// All agents with same TEAM_NAME see same tasks

// Teammate mailbox is team-scoped
const mailbox = getTeammateMailbox(CLAUDE_CODE_TEAM_NAME)
// Only agents on this team can send/receive messages
```

### 4. CLAUDE_CODE_PLAN_MODE_REQUIRED

**Value**: `"false"`

**Purpose**: Auto-approve plans for spawned teammates

**Why Required**:
- When `false`, teammates can proceed without leader approval
- When `true`, leader must approve each teammate's plan
- Set to `false` for faster autonomous execution

**Valid Values**: `"true"` or `"false"` (string, not boolean)

**Examples**:
- `"false"` - Auto-approve (recommended for automation)
- `"true"` - Manual approval (recommended for oversight)

**How It Works**:
```javascript
// When teammate exits plan mode
if (CLAUDE_CODE_PLAN_MODE_REQUIRED === "false") {
  // Auto-approve plan, continue execution
  approvePlan(teammateId)
} else {
  // Wait for leader to approve
  sendPlanForApproval(teammateId, plan)
  waitForApproval()
}
```

**Recommendation**:
- Use `"false"` for complexity < 7 (faster execution)
- Use `"true"` for complexity >= 7 (more oversight)

### 5. permissions.defaultMode

**Value**: `"delegate"`

**Purpose**: Default permission mode for Task tool

**Why Required**:
- `"delegate"` mode enables spawning teammates
- Other modes don't allow multi-agent coordination
- Required for ExitPlanMode to launch swarm

**Valid Values**: `"default"`, `"bypassPermissions"`, `"delegate"`

**Examples**:
- `"delegate"` - Can delegate to teammates (REQUIRED for swarm)
- `"bypassPermissions"` - Elevated permissions (no delegation)
- `"default"` - Standard permissions (no delegation)

**How It Works**:
```javascript
// When spawning teammate with delegate mode
Task({
  subagent_type: "code-reviewer",
  mode: "delegate",  // Allows this agent to spawn more teammates
  prompt: "Review this code"
})

// With defaultMode: "delegate", all Task calls default to mode: "delegate"
```

### 6. model

**Value**: `"glm-4.7"`

**Purpose**: Primary model for all tasks

**Why Required**:
- GLM-4.7 is now PRIMARY for ALL complexity levels (1-10)
- Replaces Opus/Sonnet hierarchy
- Cost-effective with high quality

**Valid Values**: Any Claude model identifier

**Examples**:
- `"glm-4.7"` - Primary model (recommended)
- `"claude-sonnet-4-5"` - Fallback option
- `"claude-opus-4-5"` - For high-complexity only

**How It Works**:
```javascript
// When no model specified, use default
Task({
  subagent_type: "orchestrator",
  // model defaults to settings.model (glm-4.7)
  prompt: "Execute task"
})
```

---

## Configuration Validation

### Automated Validation

Run the unit test suite:

```bash
bash tests/swarm-mode/test-swarm-mode-config.sh
```

Expected output:
```
✓ ALL TESTS PASSED
Swarm mode v2.81.0 is properly configured and ready for use.
```

### Manual Validation

Validate each setting:

```bash
# 1. Check settings.json location
ls -la ~/.claude-sneakpeek/zai/config/settings.json

# 2. Validate JSON syntax
jq empty ~/.claude-sneakpeek/zai/config/settings.json

# 3. Check agent environment variables
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.env | with_entries(select(.key | test("AGENT|TEAM"; "i")))'

# Expected output:
# {
#   "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
#   "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
#   "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop",
#   "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"
# }

# 4. Check defaultMode
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.permissions.defaultMode'
# Expected output: "delegate"

# 5. Check primary model
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.model'
# Expected output: "glm-4.7"
```

---

## Reproduction Guide

### Step 1: Backup Existing Configuration

```bash
# Create backup
cp ~/.claude-sneakpeek/zai/config/settings.json \
   ~/.claude-sneakpeek/zai/config/settings.json.backup.$(date +%Y%m%d-%H%M%S)
```

### Step 2: Add Agent Environment Variables

Edit `~/.claude-sneakpeek/zai/config/settings.json`:

```bash
# Open in editor
nano ~/.claude-sneakpeek/zai/config/settings.json
```

Add to `env` section (preserve existing variables):

```json
{
  "env": {
    // ... KEEP ALL EXISTING VARIABLES ...

    // ADD THESE NEW VARIABLES:
    "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"
  }
}
```

### Step 3: Verify permissions.defaultMode

Check `permissions` section:

```json
{
  "permissions": {
    "allow": [ ... ],
    "deny": [ ... ],
    "defaultMode": "delegate"  // MUST BE "delegate"
  }
}
```

If not set to `"delegate"`, change it:

```bash
# Update defaultMode
jq '.permissions.defaultMode = "delegate"' \
  ~/.claude-sneakpeek/zai/config/settings.json \
  > /tmp/settings.json.tmp && \
  mv /tmp/settings.json.tmp ~/.claude-sneakpeek/zai/config/settings.json
```

### Step 4: Verify primary model

Check `model` setting:

```json
{
  "model": "glm-4.7"  // MUST BE "glm-4.7"
}
```

If not set, add/update it:

```bash
# Update model
jq '.model = "glm-4.7"' \
  ~/.claude-sneakpeek/zai/config/settings.json \
  > /tmp/settings.json.tmp && \
  mv /tmp/settings.json.tmp ~/.claude-sneakpeek/zai/config/settings.json
```

### Step 5: Validate Configuration

```bash
# Run automated tests
bash tests/swarm-mode/test-swarm-mode-config.sh

# Expected: All tests pass
```

### Step 6: Test Swarm Mode

```bash
# Test with simple task
/orchestrator "create a hello world function"

# Expected:
# - Orchestrator creates team "multi-agent-ralph-loop"
# - Spawns 3 teammates
# - Teammates coordinate via shared task list
```

---

## Troubleshooting

### Issue: Teammates not spawning

**Symptoms**: `/orchestrator` doesn't spawn teammates

**Diagnosis**:
```bash
# Check if swarm gate is patched
grep -c "tengu_brass_pebble" ~/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js
# Expected: 0 (patched)

# Check if TeammateTool is available
grep -c "TeammateTool" ~/.claude-sneakpeek/zai/npm/node_modules/@anthropic-ai/claude-code/cli.js
# Expected: >0 (available)
```

**Solution**:
- Ensure Claude Code version >= 2.1.16
- Reinstall claude-sneakpeek zai variant

### Issue: Permission denied errors

**Symptoms**: `Task` tool fails with permission errors

**Diagnosis**:
```bash
# Check defaultMode
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.permissions.defaultMode'
# Expected: "delegate"
```

**Solution**:
- Set `defaultMode` to `"delegate"`

### Issue: Agent not receiving messages

**Symptoms**: Teammate mailbox not working

**Diagnosis**:
```bash
# Check if agents have same TEAM_NAME
# (Review orchestrator and teammate logs)

# Verify TEAM_NAME is set
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.env.CLAUDE_CODE_TEAM_NAME'
# Expected: "multi-agent-ralph-loop"
```

**Solution**:
- Ensure all agents have same `CLAUDE_CODE_TEAM_NAME`
- Restart Claude Code after changing settings

### Issue: Plans requiring manual approval

**Symptoms**: Teammates waiting for plan approval

**Diagnosis**:
```bash
# Check PLAN_MODE_REQUIRED
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.env.CLAUDE_CODE_PLAN_MODE_REQUIRED'
# Expected: "false"
```

**Solution**:
- Set `CLAUDE_CODE_PLAN_MODE_REQUIRED` to `"false"`

---

## Environment-Specific Notes

### Development Environment

**Purpose**: Local development and testing

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "dev-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Dev Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "dev-team",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"  // Auto-approve for speed
  }
}
```

### Production Environment

**Purpose**: Production deployment

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "prod-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Production Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "prod-team",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "true"  // Manual approval for safety
  }
}
```

### CI/CD Environment

**Purpose**: Automated testing and deployment

**Configuration**:
```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "ci-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "CI Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "ci-team",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"  // Auto-approve required
  },
  "permissions": {
    "defaultMode": "delegate"  // Required for CI
  }
}
```

---

## Quick Reference

### Minimum Required Settings

```json
{
  "env": {
    "CLAUDE_CODE_AGENT_ID": "claude-orchestrator",
    "CLAUDE_CODE_AGENT_NAME": "Orchestrator",
    "CLAUDE_CODE_TEAM_NAME": "multi-agent-ralph-loop",
    "CLAUDE_CODE_PLAN_MODE_REQUIRED": "false"
  },
  "permissions": {
    "defaultMode": "delegate"
  },
  "model": "glm-4.7"
}
```

### Validation Command

```bash
bash tests/swarm-mode/test-swarm-mode-config.sh
```

### File Locations

- **Settings**: `~/.claude-sneakpeek/zai/config/settings.json`
- **Tests**: `tests/swarm-mode/test-swarm-mode-config.sh`
- **Documentation**: `docs/architecture/SWARM_MODE_*.md`

---

## Conclusion

This configuration ensures that Swarm Mode v2.81.0 works correctly across all environments. The unit tests validate every component, and the reproduction guide allows you to set up swarm mode on any machine.

**Key Points**:
1. All 4 agent environment variables are **REQUIRED**
2. `defaultMode` **MUST** be `"delegate"`
3. `model` **SHOULD** be `"glm-4.7"` for optimal performance
4. Run tests after configuration to validate
5. Use appropriate `PLAN_MODE_REQUIRED` based on environment

---

**Status**: ✅ PRODUCTION READY
**Last Updated**: 2026-01-29
**Version**: 2.81.0
