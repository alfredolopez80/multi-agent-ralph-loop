# Claude Code Hook JSON Format Reference (v2.57.3)

Based on OFFICIAL Claude Code documentation from /anthropics/claude-code

## Format Summary

| Hook Type | Format Key | Valid Values | Example |
|-----------|------------|--------------|---------|
| PostToolUse | `continue` | `true` / `false` (boolean) | `{"continue": true}` |
| PreToolUse | `continue` _or_ `hookSpecificOutput.permissionDecision` | `continue`: bool · `permissionDecision`: `"allow"` / `"deny"` / `"ask"` | `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}` |
| UserPromptSubmit | `continue` | `true` / `false` (boolean) | `{"continue": true}` |
| PreCompact | `continue` | `true` / `false` (boolean) | `{"continue": true}` |
| SessionStart | `hookSpecificOutput` | object | `{"hookSpecificOutput": {"additionalContext": "..."}}` |
| **Stop** | `decision` (block only) | `"block"` or **clean exit** to allow | `{"decision": "block"}` / `exit 0` |

## CRITICAL RULES

1. **The string `"continue"` is NEVER valid for the `decision` field**
   - WRONG: `{"decision": "continue"}` ❌
   - WRONG: `{"decision": "approve"}` ❌ (`"approve"` is NOT a valid Claude Code value)
   - RIGHT for Stop: clean `exit 0` to allow, `{"decision": "block"}` to block ✅
   - RIGHT for others: `{"continue": true}` or clean `exit 0` ✅

2. **Stop hooks are the ONLY hooks that use `decision`**
   - All other hooks use `continue` (boolean)

3. **Optional fields (all hook types)**:
   - `systemMessage`: string - Message for Claude
   - `suppressOutput`: boolean - Hide output from transcript
   - `additionalContext`: string - Extra context

4. **PreToolUse `permissionDecision` is `"allow"` / `"deny"` / `"ask"` — NEVER `"block"`**
   - WRONG: `{"hookSpecificOutput": {"permissionDecision": "block"}}` ❌ → fails with `Hook JSON output validation failed — (root): Invalid input`
   - RIGHT (deny): `{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "..."}}` ✅
   - `"block"` belongs to the **Stop** `decision` field ONLY. Do not cross the two vocabularies.
   - Pair a `deny` with a `permissionDecisionReason` so Claude can relay why.

## Test Validation Matrix

```python
def validate_hook_output(hook_type: str, output: dict) -> bool:
    if hook_type == "Stop":
        # allow == clean exit (no output); block == {"decision": "block"}. "approve" is invalid.
        return output == {} or output.get("decision") == "block"
    elif hook_type == "SessionStart":
        return "hookSpecificOutput" in output
    elif hook_type == "PreToolUse":
        # PreToolUse accepts EITHER {"continue": bool} OR
        # {"hookSpecificOutput": {"permissionDecision": "allow"|"deny"|"ask", ...}}.
        # "block" is INVALID here — it belongs to the Stop `decision` field only.
        if output == {} or ("continue" in output and isinstance(output["continue"], bool)):
            return True
        hso = output.get("hookSpecificOutput", {})
        return hso.get("permissionDecision") in ("allow", "deny", "ask")
    else:  # PostToolUse, UserPromptSubmit, PreCompact
        return output == {} or (
            "continue" in output and isinstance(output["continue"], bool)
        )
```

## Source

Official Claude Code documentation:
- https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/hook-development/SKILL.md
