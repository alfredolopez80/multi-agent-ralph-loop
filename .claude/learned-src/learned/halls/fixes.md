# Hall: Fixes

**Type**: Bug fixes and corrections — specific issues caught and how they were resolved.
**Wing**: multi-agent-ralph-loop
**Sources**: hooks.md, testing.md, security.md (noise-excluded)

---

## Hook Format Bug: Wrong `decision` Value

**Bug**: Hook returning `{"decision": "continue"}`.
**Fix**: Stop hooks must use `{"decision": "approve"}` or `{"decision": "block"}`. PostToolUse/PreToolUse hooks must use `{"continue": true/false}`.
**Detection**: `validate-hooks.sh` + `pytest tests/test_hooks_*.py`

---

## Test Expectation Bug

**Bug**: Test asserting `{"decision": "continue"}` — an invalid hook response format.
**Fix**: The test expectation was wrong. Fix the test to expect the correct format, not the hook.
**Principle**: Verify test expectations against official documentation before changing implementation.

---

## Input Validation Missing at API Boundary

**Bug**: User input passed directly to database/HTML without validation.
**Fix**: Validate all inputs at API boundaries. Use parameterized queries. Sanitize HTML output (XSS). Validate file uploads with allowlist.

---

## Auth Endpoint Missing Rate Limiting

**Bug**: Auth endpoints exposed to brute force without rate limiting.
**Fix**: Implement rate limiting on all auth endpoints.
