# Room: Testing

**Topic**: Testing practices — test validation, hook testing, expectation correctness.
**Wing**: multi-agent-ralph-loop
**Sources**: testing.md (noise-excluded; "caching strategy" rule excluded as vague/domain-spill)

---

## Verify Test Expectations Before Fixing Implementation

FIRST verify test expectations are correct against official documentation (use Context7 MCP). Tests can be corrupted with wrong expectations.

**Example**: If a test expects `{"decision": "continue"}`, the TEST is wrong — fix the test, not the hook.

---

## Hook Test Pipeline

Run both before committing any hook change:

1. `./validate-hooks.sh` — verifies all hooks produce valid JSON
2. `pytest tests/test_hooks_*.py` — verifies format expectations
