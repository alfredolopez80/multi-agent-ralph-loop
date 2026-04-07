# Hall: Anti-Patterns

**Type**: Negative patterns — things that cause problems and should be avoided.
**Wing**: multi-agent-ralph-loop + _global
**Sources**: security.md, agent-engineering.md (noise-excluded)

---

## Never Log Sensitive Data

Never log passwords, tokens, or PII. Use environment variables for secrets. Encrypt sensitive data at rest. Use HTTPS for all communications.

**Source**: security.md
**Wing**: _global

---

## 27 Security Anti-Patterns (CWE-mapped)

Reference library of 27 security anti-patterns with CWE mappings.

**Source**: security.md (confidence: 0.95, sessions: 10)
**Vault**: `/Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/security/27-anti-patterns.md`
**Wing**: _global

---

## Anti-Rationalization Tables for AI Agents

Reference tables for recognizing when an agent or developer is rationalizing a bad decision instead of applying first principles.

**Source**: agent-engineering.md (confidence: 0.8, sessions: 3)
**Vault**: `/Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/agent-engineering/anti-rationalization.md`
**Wing**: _global

---

## Wrong Hook JSON Decision Field

Never use `{"decision": "continue"}` — only `"approve"` or `"block"` are valid for the `decision` field.

**Source**: hooks.md (Critical section)
**Fix**: Use `{"continue": true}` for PostToolUse/PreToolUse/UserPromptSubmit. Use `{"decision": "approve"/"block"}` only for Stop hooks.
**Wing**: multi-agent-ralph-loop
