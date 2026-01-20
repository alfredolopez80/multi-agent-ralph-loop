# Claude Code Hook JSON Format Reference (v2.57.3)

Based on OFFICIAL Claude Code documentation from /anthropics/claude-code

## Format Summary

| Hook Type | Format Key | Valid Values | Example |
|-----------|------------|--------------|---------|
| PostToolUse | `continue` | `true` / `false` (boolean) | `{"continue": true}` |
| PreToolUse | `continue` | `true` / `false` (boolean) | `{"continue": true}` |
| UserPromptSubmit | `continue` | `true` / `false` (boolean) | `{"continue": true}` |
| PreCompact | `continue` | `true` / `false` (boolean) | `{"continue": true}` |
| SessionStart | `hookSpecificOutput` | object | `{"hookSpecificOutput": {"additionalContext": "..."}}` |
| **Stop** | `decision` | `"approve"` / `"block"` (string) | `{"decision": "approve"}` |

## CRITICAL RULES

1. **The string `"continue"` is NEVER valid for the `decision` field**
   - WRONG: `{"decision": "continue"}` ❌
   - RIGHT for Stop: `{"decision": "approve"}` ✅
   - RIGHT for others: `{"continue": true}` ✅

2. **Stop hooks are the ONLY hooks that use `decision`**
   - All other hooks use `continue` (boolean)

3. **Optional fields (all hook types)**:
   - `systemMessage`: string - Message for Claude
   - `suppressOutput`: boolean - Hide output from transcript
   - `additionalContext`: string - Extra context

## Test Validation Matrix

```python
def validate_hook_output(hook_type: str, output: dict) -> bool:
    if hook_type == "Stop":
        return output.get("decision") in ("approve", "block")
    elif hook_type == "SessionStart":
        return "hookSpecificOutput" in output
    else:  # PostToolUse, PreToolUse, UserPromptSubmit, PreCompact
        return output == {} or (
            "continue" in output and isinstance(output["continue"], bool)
        )
```

## Source

Official Claude Code documentation:
- https://github.com/anthropics/claude-code/blob/main/plugins/plugin-dev/skills/hook-development/SKILL.md
