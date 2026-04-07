# Room: Hooks

**Topic**: Ralph hook system — authoring, format, validation.
**Wing**: multi-agent-ralph-loop
**Sources**: hooks.md, testing.md (noise-excluded)

---

## Hook JSON Format (CRITICAL)

Use the correct JSON response format per hook event type:

| Hook Event | Required Format |
|------------|----------------|
| `PostToolUse` | `{"continue": true}` or `{"continue": false}` |
| `PreToolUse` | `{"continue": true}` or `{"continue": false}` |
| `UserPromptSubmit` | `{"continue": true}` or `{"continue": false}` |
| `Stop` | `{"decision": "approve"}` or `{"decision": "block"}` |

`"continue"` is NEVER valid as a value for the `decision` field.
**Verify**: `tests/HOOK_FORMAT_REFERENCE.md` before committing.

---

## Hook Stdin Protocol

```bash
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
```

**Source**: hooks.md (confidence: 0.9, sessions: 8)
**Vault**: `~/Documents/Obsidian/MiVault/global/wiki/hooks/stdin-protocol-pattern.md`

---

## umask 077 — Defense in Depth

```bash
#!/usr/bin/env bash
umask 077
INPUT=$(cat)
```

**Source**: security.md (confidence: 0.9, sessions: 6)
**Vault**: `~/Documents/Obsidian/MiVault/global/wiki/security/umask-077-defense.md`

---

## Hook Validation Before Commit

1. `./validate-hooks.sh` — all hooks produce valid JSON
2. `pytest tests/test_hooks_*.py` — format expectations are correct

Never commit hooks that fail either check.
