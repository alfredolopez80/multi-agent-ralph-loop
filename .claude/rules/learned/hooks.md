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

*Generated: 2026-02-15 22:58. Source: procedural memory (2 rules)*
