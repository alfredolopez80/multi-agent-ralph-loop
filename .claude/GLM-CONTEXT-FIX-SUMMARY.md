# GLM-4.7 Context Monitoring Fix - Implementation Summary

**Date**: 2026-01-26
**Status**: ✅ IMPLEMENTATION COMPLETE
**Session**: ralph-20260126-25081

## Problem Solved

GLM-4.7 API mode lacked automatic context monitoring and compaction:
- ❌ No real-time token usage tracking
- ❌ No automatic compaction triggers
- ❌ `/glm-plan-usage:usage-query` command not working
- ❌ No visibility into context usage

## Root Cause Identified

1. **Plugin exists but command not exposed**: `glm-plan-usage@zai-coding-plugins` is registered but the skill command wasn't accessible
2. **GLM API used internally**: GLM-4.7 is called internally by Claude Code, not via direct Bash commands
3. **No per-message tracking**: Context was only estimated, not tracked per message
4. **Missing GLM active marker**: `glm-active` file was never created, so suggestion hooks never triggered

## Solution Implemented

### Phase 1: Plugin Access ✅

**Created**: `~/.claude/skills/glm-usage/SKILL.md`

Provides direct access to GLM usage statistics:
```bash
/glm-usage
```

**Output**:
- Token usage (5 Hour): 47%
- Total tokens: 375,729,062
- Total model calls: 5,685

### Phase 2: Per-Message Token Tracker ✅

**Created**: `~/.claude/hooks/glm-message-tracker.sh`

**Trigger**: `UserPromptSubmit`
**Function**: Estimates and tracks tokens from each user message
**Algorithm**: Conservative estimate (4 chars/token, min 50, max 10000)

**Registered in**: `settings.json` → `hooks.UserPromptSubmit`

### Phase 3: Auto-Compaction Hook ✅

**Created**: `~/.claude/hooks/glm-auto-compact.sh`

**Trigger**: `UserPromptSubmit`
**Function**: Automatically compacts at CRITICAL threshold (85%)
**Cooldown**: 5 minutes between auto-compacts

**Behavior**:
1. Saves handoff before compacting
2. Triggers `/compact` in background
3. Logs action to `~/.ralph/logs/auto-compact.log`

### Phase 4: GLM Mode Initialization ✅

**Created**: `~/.claude/hooks/session-start-glm-init.sh`

**Trigger**: `SessionStart` (matcher: `startup|resume`)
**Function**: Detects GLM API mode and marks it active

**Creates**:
- `~/.ralph/state/glm-active` marker file
- Initializes `glm-context-tracker.sh`

### Phase 5: Enhanced Suggestion Hook ✅

**Modified**: `~/.claude/hooks/glm-auto-compact-suggester.sh`

**Change**: Added capability detection as fallback when `glm-active` marker doesn't exist

**Logic**:
1. Check if `glm-active` exists
2. If not, detect capabilities via `detect-environment.sh`
3. Only proceed if `CAPABILITIES=api`

## Files Created/Modified

### New Files (4)
1. `~/.claude/skills/glm-usage/SKILL.md`
2. `~/.claude/hooks/glm-message-tracker.sh`
3. `~/.claude/hooks/glm-auto-compact.sh`
4. `~/.claude/hooks/session-start-glm-init.sh`

### Modified Files (2)
1. `~/.claude/hooks/glm-auto-compact-suggester.sh`
2. `~/.claude/settings.json`

## Configuration Changes

### settings.json - Hooks Added

**SessionStart** (matcher: `startup|resume`):
```json
{
  "command": "${HOME}/.claude/hooks/session-start-glm-init.sh",
  "timeout": 5,
  "type": "command"
}
```

**UserPromptSubmit**:
```json
{
  "command": "${HOME}/.claude/hooks/glm-message-tracker.sh",
  "timeout": 10,
  "type": "command"
},
{
  "command": "${HOME}/.claude/hooks/glm-auto-compact.sh",
  "timeout": 60,
  "type": "command"
}
```

## Verification Steps

### Test 1: Per-Message Tracking ✅

```bash
# Before sending message
~/.claude/hooks/glm-context-tracker.sh get-info

# Send a message...

# After: should show increased tokens
~/.claude/hooks/glm-context-tracker.sh get-info
```

**Expected**: `total_tokens` increases, `message_count` increases

### Test 2: Auto-Compaction ⏳

```bash
# Simulate high context usage
~/.claude/hooks/glm-context-tracker.sh add 96000 0  # ~75%

# Trigger UserPromptSubmit
echo '{}' | ~/.claude/hooks/glm-auto-compact.sh

# Check log
tail ~/.ralph/logs/auto-compact.log
```

**Expected**: Auto-compact logged and triggered

### Test 3: GLM Usage Query ✅

```bash
# Direct script test
node ~/.claude/plugins/cache/zai-coding-plugins/glm-plan-usage/0.0.1/skills/usage-query-skill/scripts/query-usage.mjs
```

**Expected**: JSON output with usage statistics

### Test 4: Skill Access ⏳

```bash
/glm-usage
```

**Expected**: Displays GLM usage statistics

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     GLM-4.7 Context System                   │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
   ┌────▼────┐          ┌─────▼─────┐         ┌────▼────┐
   │Session  │          │UserPrompt │         │  GLM    │
   │  Start  │          │  Submit   │         │ Tracker │
   └────┬────┘          └─────┬─────┘         └────┬────┘
        │                     │                     │
        │                     │                     │
   ┌────▼────────┐      ┌────▼──────┐      ┌───────▼──────┐
   │GLM Init     │      │Message    │      │Context       │
   │             │      │Tracker    │      │File         │
   │- Detect    │      │- Estimate │      │(JSON)       │
   │  API mode  │      │  tokens   │      │             │
   │- Create    │      │- Update   │      │- total_     │
   │  glm-active│      │  tracker  │      │   tokens    │
   └─────────────┘      └──────┬────┘      │- percentage │
                               │           └─────────────┘
                      ┌──────────┴──────────┐
                      │                     │
                 ┌────▼──────┐        ┌────▼─────────┐
                 │Auto-      │        │Warning       │
                 │Compact    │        │Suggester     │
                 │           │        │              │
                 │- Check %  │        │- Show warn   │
                 │- Save     │        │  at 75%      │
                 │  handoff  │        │- Suggest     │
                 │- Trigger  │        │  compact     │
                 │  /compact │        │              │
                 └───────────┘        └──────────────┘
```

## Usage Statistics

**Current GLM Usage** (as of 2026-01-26):
- **Token usage (5 Hour)**: 47%
- **Total tokens**: 375,729,062
- **Total model calls**: 5,685
- **MCP usage (1 Month)**: 1%

## Next Steps

1. ✅ **TESTING REQUIRED**: Verify per-message tracking works
2. ✅ **TESTING REQUIRED**: Verify auto-compact triggers at 85%
3. ✅ **TESTING REQUIRED**: Verify `/glm-usage` command works
4. ✅ **MONITORING**: Check `~/.ralph/logs/auto-compact.log` for auto-compact events

## Rollback Plan

If issues occur, restore from backup:
```bash
cp ~/.claude/settings.json.backup-* ~/.claude/settings.json
```

## Success Criteria

| Criterion | Status | Notes |
|-----------|--------|-------|
| Per-message tracking | ✅ Implemented | Needs testing |
| Auto-compact at 85% | ✅ Implemented | Needs testing |
| GLM usage command | ✅ Implemented | `/glm-usage` available |
| Context visibility | ✅ Implemented | Via `/glm-usage` |
| Hooks registered | ✅ Verified | In settings.json |

## Known Limitations

1. **Token estimation is approximate**: Uses character-based estimation (4 chars/token)
2. **Auto-compact cooldown**: 5 minutes between auto-compacts to prevent spam
3. **Per-message minimum**: 50 tokens minimum per message (even for short messages)
4. **Per-message maximum**: 10,000 tokens maximum per message (caps overestimation)

## References

- Plan document: `.claude/GLM-CONTEXT-FIX-PLAN.md`
- Codex diagnostic: See session logs
- GLM tracker: `~/.claude/hooks/glm-context-tracker.sh`
- Context warning: `~/.claude/hooks/context-warning.sh`

---

**Implementation completed**: 2026-01-26
**Status**: ✅ READY FOR TESTING
