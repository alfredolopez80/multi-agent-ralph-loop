# GLM-4.7 Context Monitoring Fix Plan

**Date**: 2026-01-26
**Severity**: CRITICAL
**Status**: Planning

## Problem Summary

GLM-4.7 API mode lacks automatic context monitoring and compaction:
- No real-time token usage tracking
- No automatic compaction triggers
- `/glm-plan-usage:usage-query` command not working
- No visibility into context usage (neither Claude native nor Ralph wrapper)

## Root Cause Analysis

### 1. Plugin Registration Issue
**Finding**: `settings.json` has `"plugins": null`
**Impact**: `glm-plan-usage` plugin exists but is not registered
**Location**: `~/.claude/plugins/cache/zai-coding-plugins/glm-plan-usage/0.0.1/`

### 2. GLM Token Tracking Not Working
**Finding**: `glm-api-tracker.sh` only detects Bash commands with "z.ai" or "glm-4.7"
**Problem**: GLM-4.7 API is used internally by Claude Code, not via direct Bash commands
**Result**: Token counter never increments

**Evidence**:
- `operation-counter`: 149 (high)
- `message_count` in `~/.ralph/state/`: 0 (should be high!)
- `glm-context.json` message_count: 1 (only updated once)

### 3. Missing Per-Message Tracking
**Finding**: No hook updates GLM context on each message/tool call
**Current**: `context-warning.sh` only READS the context file, never WRITES to it
**Required**: Per-message token accumulation

### 4. No Auto-Compaction
**Finding**: No hook automatically executes `/compact` when threshold is reached
**Current**: Only manual compaction available
**Required**: Automatic trigger at 75-85% context usage

## Solution Architecture

### Phase 1: Enable GLM Plan Usage Plugin

**File**: `~/.claude/settings.json`

```json
{
  "plugins": [
    {
      "name": "glm-plan-usage",
      "path": "${HOME}/.claude/plugins/cache/zai-coding-plugins/glm-plan-usage/0.0.1",
      "enabled": true
    }
  ]
}
```

**Verification**:
```bash
# After fix, this should work:
/glm-plan-usage:usage-query
```

### Phase 2: Create Per-Message GLM Token Tracker

**New File**: `~/.claude/hooks/glm-message-tracker.sh`

**Trigger**: `UserPromptSubmit`

**Logic**:
```bash
#!/bin/bash
# Estimate tokens from current message
# Average: ~4 chars per token
MESSAGE_LENGTH=${#INPUT}
ESTIMATED_TOKENS=$((MESSAGE_LENGTH / 4))

# Update GLM context
~/.claude/hooks/glm-context-tracker.sh add "$ESTIMATED_TOKENS" 0

# Return empty JSON for UserPromptSubmit
echo '{}'
```

**Register in** `~/.claude/settings.json`:
```json
{
  "hooks": [
    {
      "command": "${HOME}/.claude/hooks/glm-message-tracker.sh",
      "timeout": 5,
      "type": "command"
    }
  ],
  "matcher": "UserPromptSubmit"
}
```

### Phase 3: Create Auto-Compaction Hook

**New File**: `~/.claude/hooks/glm-auto-compact.sh`

**Trigger**: `UserPromptSubmit` (after context warning)

**Logic**:
```bash
#!/bin/bash
# Get current context percentage
PCT=$(${HOME}/.claude/hooks/glm-context-tracker.sh get-percentage)

# Auto-compact at 75%
if [[ $PCT -ge 75 ]]; then
    # Execute compact
    claude --print "/compact" >/dev/null 2>&1 &

    # Log the action
    echo "[$(date)] Auto-compact triggered at ${PCT}%" \
        >> ~/.ralph/logs/auto-compact.log
fi

echo '{}'
```

**Register in** `~/.claude/settings.json`:
```json
{
  "hooks": [
    {
      "command": "${HOME}/.claude/hooks/glm-auto-compact.sh",
      "timeout": 60,
      "type": "command"
    }
  ],
  "matcher": "UserPromptSubmit"
}
```

### Phase 4: Update GLM API Tracker

**File**: `~/.claude/hooks/glm-api-tracker.sh`

**Current**: Only tracks direct Bash commands
**Fix**: Also track Claude Code API usage

**Approach**: Since we can't intercept internal API calls, rely on:
1. Per-message estimation (Phase 2)
2. Per-tool-call estimation (Phase 5)

### Phase 5: Add Per-Tool Token Estimation

**New File**: `~/.claude/hooks/glm-tool-tracker.sh`

**Trigger**: `PostToolUse`

**Logic**:
```bash
#!/bin/bash
# Estimate tokens from tool inputs/outputs
INPUT="${1:-}"
INPUT_LEN=${#INPUT}
ESTIMATED_TOKENS=$((INPUT_LEN / 4))

# Update GLM context
~/.claude/hooks/glm-context-tracker.sh add "$ESTIMATED_TOKENS" 0

echo '{"continue": true}'
```

**Register in** `~/.claude/settings.json`:
```json
{
  "hooks": [
    {
      "command": "${HOME}/.claude/hooks/glm-tool-tracker.sh",
      "timeout": 5,
      "type": "command"
    }
  ],
  "matcher": "Edit|Write|Bash|Read|Grep|Glob"
}
```

## Implementation Order

1. **Phase 1**: Enable plugin (quick win)
2. **Phase 2**: Create per-message tracker
3. **Phase 5**: Create per-tool tracker
4. **Phase 3**: Create auto-compact hook
5. **Phase 4**: Update existing tracker (optional)

## Verification Plan

### Test 1: Plugin Registration
```bash
# Should show usage data
/glm-plan-usage:usage-query
```

### Test 2: Token Tracking
```bash
# Before sending message
~/.claude/hooks/glm-context-tracker.sh get-info

# Send some messages...

# After: should show increased tokens
~/.claude/hooks/glm-context-tracker.sh get-info
```

### Test 3: Auto-Compaction
```bash
# Simulate high context usage
~/.claude/hooks/glm-context-tracker.sh add 96000 0  # ~75%

# Trigger UserPromptSubmit
echo '{}' | ~/.claude/hooks/glm-auto-compact.sh

# Check log
tail ~/.ralph/logs/auto-compact.log
```

### Test 4: Context Warning
```bash
# Should show warning when approaching threshold
echo '{}' | ~/.claude/hooks/context-warning.sh
```

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Over-estimation of tokens | False positives | Use conservative estimate (4 chars/token) |
| Auto-compact at wrong time | Lost context | Only compact at 75%+, save handoff first |
| Hook timeout | Delay in responses | Keep hooks fast (< 5s) |
| Race conditions | Data corruption | Use file locking in tracker |

## Success Criteria

1. ✅ `/glm-plan-usage:usage-query` works
2. ✅ Token count increases with each message/tool call
3. ✅ Context warning appears at 75%
4. ✅ Auto-compact triggers at 75%
5. ✅ Context visibility restored in statusline

## Next Steps

1. Review and approve this plan
2. Implement Phase 1 (plugin enablement)
3. Create and test Phase 2 (per-message tracker)
4. Implement auto-compact (Phase 3)
5. Full integration testing

## References

- Current GLM context: `~/.ralph/state/glm-context.json`
- Context warning hook: `~/.claude/hooks/context-warning.sh`
- GLM tracker: `~/.claude/hooks/glm-context-tracker.sh`
- Codex diagnostic output: See session logs
