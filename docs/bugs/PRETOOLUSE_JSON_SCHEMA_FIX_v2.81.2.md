# PreToolUse JSON Schema Fix v2.81.2

**Date**: 2026-01-30
**Version**: v2.81.2
**Status**: RESOLVED
**Severity**: HIGH
**Type**: Bug Fix

## Summary

Fixed critical JSON schema validation errors in PreToolUse hooks that were causing error messages on every Edit, Write, and Bash operation.

## Problem Description

### Symptoms

Every time a PreToolUse hook was triggered (Edit, Write, Bash operations), the following error appeared:

```
⎿  PreToolUse:Write hook error: JSON validation failed: Hook JSON output validation failed:
- : Invalid input

Expected schema:
{
  "hookSpecificOutput": {
    "for PreToolUse": {
      "hookEventName": "\"PreToolUse\"",
      "permissionDecision": "\"allow\" | \"deny\" | \"ask\" (optional)",
      "permissionDecisionReason": "string (optional)",
      "updatedInput": "object (optional) - Modified tool input to use"
    }
  }
}
The hook's stdout was: {
  "decision": "allow",
  "additionalContext": "💾 Auto-checkpoint saved before refactor operation"
}
```

### Root Cause

Multiple PreToolUse hooks were using **incorrect JSON schema formats**:

| Incorrect Format | Used For | Problem |
|------------------|----------|---------|
| `{"decision": "allow"}` | Stop hooks | Wrong event type |
| `{"decision": "allow", "additionalContext": "..."}` | UserPromptSubmit hooks | Wrong event type |
| `{"decision": "allow", "tool_input": {...}}` | Custom format | Missing wrapper |

The correct format for **PreToolUse hooks** requires `hookSpecificOutput` wrapper.

## Affected Hooks (4 files)

| Hook File | Incorrect Output | Correct Output |
|-----------|-----------------|----------------|
| `checkpoint-auto-save.sh` | `{"decision": "allow", "additionalContext": "..."}` | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}` |
| `fast-path-check.sh` | `{"decision": "allow", "additionalContext": "..."}` | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "..."}}` |
| `agent-memory-auto-init.sh` | `{"decision": "allow"}` | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}` |
| `orchestrator-auto-learn.sh` | `{"decision": "allow", "tool_input": {...}}` | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": {...}}}` |

## Correct JSON Schema for PreToolUse

### Standard Format (allow operation)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow"
  }
}
```

### With Reason Message

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "FAST_PATH_ELIGIBLE: This task appears trivial"
  }
}
```

### With Modified Input (e.g., orchestrator-auto-learn.sh)

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "updatedInput": {
      "subagent_type": "orchestrator",
      "prompt": "Modified prompt with injected context..."
    }
  }
}
```

## Schema Comparison by Event Type

| Event Type | Required Fields | Optional Fields |
|------------|----------------|-----------------|
| **PreToolUse** | `hookSpecificOutput.hookEventName`, `hookSpecificOutput.permissionDecision` | `permissionDecisionReason`, `updatedInput` |
| **PostToolUse** | `continue` | `additionalContext` |
| **UserPromptSubmit** | `hookSpecificOutput.additionalContext` | - |
| **Stop** | `decision` | `reason` |
| **SessionStart** | (no JSON required) | - |

## Implementation Details

### File: `checkpoint-auto-save.sh`

**Before (v2.69.0)**:
```bash
echo "{\"decision\": \"allow\", \"additionalContext\": \"💾 Auto-checkpoint saved before $trigger operation\"}"
```

**After (v2.81.2)**:
```bash
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
```

**Note**: The `additionalContext` message was removed because PreToolUse hooks don't support this field. The checkpoint is still logged to the log file.

### File: `fast-path-check.sh`

**Before (v2.69.0)**:
```bash
echo '{"decision": "allow", "additionalContext": "FAST_PATH_ELIGIBLE: This task appears trivial..."}'
```

**After (v2.81.2)**:
```bash
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "permissionDecisionReason": "FAST_PATH_ELIGIBLE: This task appears trivial..."}}'
```

**Note**: The message was moved to `permissionDecisionReason` field.

### File: `agent-memory-auto-init.sh`

**Before (v2.69.0)**:
```bash
echo '{"decision": "allow"}'
```

**After (v2.81.2)**:
```bash
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
```

### File: `orchestrator-auto-learn.sh`

**Before (v2.69.0)**:
```bash
jq -n --argjson tool_input "$NEW_TOOL_INPUT" '{"decision": "allow", "tool_input": $tool_input}'
```

**After (v2.81.2)**:
```bash
jq -n --argjson tool_input "$NEW_TOOL_INPUT" '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow", "updatedInput": $tool_input}}'
```

**Note**: The modified tool input is now properly wrapped in `hookSpecificOutput.updatedInput`.

## Validation

### Testing PreToolUse Hook Output

```bash
# Test hook manually
echo '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/test.txt"}}' | \
  ~/.claude/hooks/checkpoint-auto-save.sh

# Expected output:
# {"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow"}}
```

### Verification Checklist

- ✅ All PreToolUse hooks use `hookSpecificOutput` wrapper
- ✅ `hookEventName` is set to `"PreToolUse"`
- ✅ `permissionDecision` is used (not `decision`)
- ✅ `permissionDecisionReason` is used for informational messages
- ✅ `updatedInput` is used when modifying tool input
- ✅ No `additionalContext` in PreToolUse hooks (PostToolUse only)
- ✅ No bare `decision` field (Stop hooks only)

## References

- **Hook Schema Documentation**: See Claude Code official documentation for hook JSON schemas
- **Related Fixes**:
  - [POSTCOMPACT_DOES_NOT_EXIST.md](../hooks/POSTCOMPACT_DOES_NOT_EXIST.md) - v2.81.1 fix
  - [CLAUDE_MEM_HOOKS_FIX.md](../CLAUDE_MEM_HOOKS_FIX.md) - v2.73.2 fix

## Prevention

### Code Review Guidelines

When creating or modifying PreToolUse hooks:

1. **Always use `hookSpecificOutput` wrapper**
2. **Set `hookEventName` to `"PreToolUse"`**
3. **Use `permissionDecision` instead of `decision`**
4. **Use `permissionDecisionReason` for informational messages**
5. **Use `updatedInput` when modifying tool input**
6. **Never use `additionalContext` in PreToolUse hooks**
7. **Test hook output with `jq` to verify valid JSON**

### Template for PreToolUse Hooks

```bash
#!/bin/bash
# template-pretooluse.sh
# Hook: PreToolUse

# Read input
INPUT=$(head -c 100000)

# Error trap
trap 'echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"allow\"}}"' ERR EXIT

# Parse input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Your logic here...

# Output correct format
trap - ERR EXIT
echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
```

## Changelog Entry

```
## [v2.81.2] - 2026-01-30

### Fixed
- PreToolUse hooks JSON schema validation (4 hooks)
  - checkpoint-auto-save.sh
  - fast-path-check.sh
  - agent-memory-auto-init.sh
  - orchestrator-auto-learn.sh
- Hooks now use correct hookSpecificOutput format
- Removed error messages on Edit/Write/Bash operations
```

## Impact

**Before Fix**:
- Every Edit, Write, or Bash operation showed JSON validation error
- 4 PreToolUse hooks affected
- User confusion about hook functionality

**After Fix**:
- No more JSON validation errors
- Clean hook execution
- Proper hook output format for all event types

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v2.81.2 | 2026-01-30 | Fixed PreToolUse JSON schema in 4 hooks |
| v2.69.0 | 2026-01-28 | Previous version with incorrect schema |
| v2.57.0 | Various | Initial hook implementations |
