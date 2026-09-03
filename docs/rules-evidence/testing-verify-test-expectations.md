> Full text of the global rule ~/.claude/rules/proven/testing-verify-test-expectations.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# verify-test-expectations

FIRST verify test expectations are correct against official documentation (use Context7 MCP). Tests can be corrupted with wrong expectations. If test expects {"decision": "continue"}, the TEST is wrong - fix the test, not the hook.

**Trigger**: When tests fail after hook changes  
**Domain**: testing  
**Confidence**: 1.0  
**Usage**: 509  
