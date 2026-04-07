---
paths:
  - ".claude/hooks/**/*.sh"
  - ".claude/hooks/**/*.py"
---

# Hooks Rules (Auto-learned)

Rules from procedural memory. Confidence >= 0.7, usage >= 3.

## Critical

- CRITICAL: Use correct JSON format per hook type. PostToolUse/PreToolUse/UserPromptSubmit hooks MUST use {"continue": true/false}. Stop hooks ONLY use {"decision": "approve"/"block"}. The string 'continue' is NEVER valid for the 'decision' field. Verify format against tests/HOOK_FORMAT_REFERENCE.md before committing.

## Rules

- Implements structured logging

---

*Generated: 2026-04-07 19:03. Source: procedural memory (2 rules)*

- Hook Stdin Protocol: INPUT=$(cat) + jq parsing (confidence: 0.9, sessions: 8, source: /Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/hooks/stdin-protocol-pattern.md)
