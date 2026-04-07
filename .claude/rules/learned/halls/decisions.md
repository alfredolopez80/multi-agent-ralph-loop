# Hall: Decisions

**Type**: Architectural decisions — choices made with rationale.
**Wing**: multi-agent-ralph-loop + _global
**Sources**: architecture.md, hooks.md, testing.md, security.md (noise-excluded)

---

## Procedural Rules Filtering: 27/1003 High-Value Threshold

Only 27 of 1003 procedural rules meet the High-Value threshold (confidence >= 0.8, sessions >= 3). Loading the full corpus degrades retrieval quality.

**Source**: architecture.md (confidence: 0.8, sessions: 4)
**Vault**: `/Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/architecture/procedural-rules-filtering.md`
**Wing**: _global

---

## Hook JSON Format Standard (CRITICAL)

Use the correct JSON response format per hook event type:

| Hook Event | Required Format |
|------------|----------------|
| `PostToolUse` / `PreToolUse` / `UserPromptSubmit` | `{"continue": true/false}` |
| `Stop` | `{"decision": "approve"}` or `{"decision": "block"}` |

`"continue"` is NEVER a valid value for the `decision` field.

**Source**: hooks.md (Critical section)
**Verify**: `tests/HOOK_FORMAT_REFERENCE.md`
**Wing**: multi-agent-ralph-loop

---

## Test-First Expectation Verification

Before fixing a failing test, verify the test expectation is correct against official documentation (use Context7 MCP). If a test expects `{"decision": "continue"}`, the TEST is wrong — fix the test, not the hook.

**Source**: testing.md
**Wing**: multi-agent-ralph-loop

---

## Use Established Auth Libraries (CRITICAL)

Use established auth libraries (Auth0, Firebase Auth). Never implement crypto yourself. Use bcrypt (cost >= 12) for password hashing. Implement rate limiting on auth endpoints.

**Source**: security.md (Critical section)
**Wing**: _global
