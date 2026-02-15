---
paths:
  - "tests/**/*"
  - "**/*test*"
  - "**/*spec*"
---

# Testing Rules (Auto-learned)

Rules from procedural memory. Confidence >= 0.7, usage >= 3.

## Rules

- FIRST verify test expectations are correct against official documentation (use Context7 MCP). Tests can be corrupted with wrong expectations. If test expects {"decision": "continue"}, the TEST is wrong - fix the test, not the hook.
- Run validate-hooks.sh to verify all hooks produce valid JSON. Run pytest tests/test_hooks_*.py to verify format expectations. Never commit hooks that fail validation.
- Implements caching strategy

---

*Generated: 2026-02-15 22:58. Source: procedural memory (3 rules)*
