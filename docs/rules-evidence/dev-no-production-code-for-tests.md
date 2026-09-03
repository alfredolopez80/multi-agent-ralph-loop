> Full text of the global rule ~/.claude/rules/proven/dev-no-production-code-for-tests.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# dev-no-production-code-for-tests

ABSOLUTE PROHIBITION: Never add, weaken, or special-case PRODUCTION code for the sole purpose of making a test pass, in ANY project. Production code expresses real requirements; tests verify it. Never invert this relationship.

## Forbidden

- Hardcoding in production the exact value a test asserts
- Adding `if (testMode)` / `if (NODE_ENV === 'test')` branches to production logic to satisfy a test
- Special-casing the specific inputs a test happens to use
- Shaping production logic around test expectations instead of real requirements
- Loosening validation, types, or guards in production just so a test stops failing

## Correct Order When a Test Fails

1. FIRST verify the test expectation is correct against the real requirement / official documentation (see `verify-test-expectations`). Tests can be corrupted with wrong expectations.
2. If the TEST is wrong → fix the test, not the production code.
3. If a REAL requirement is missing → implement it properly in production code for the right reason. The test passing is a consequence, never the goal.

## Detection Duty (applies even outside the current scope)

If you detect production code that was clearly added or shaped only to pass a test in ANY file — whether or not that file is the target of the current analysis, PR, or task — you MUST:

1. Run `git blame` on the offending line(s) to identify when and by whom it was introduced.
2. Report the finding to the user (file, line, blame author/commit, and which test it was gaming).
3. Do NOT silently keep it.

**Trigger**: Any test-driven change, code authoring, review, analysis, or PR in any project
**Domain**: testing
**Confidence**: 1.0
**Usage**: 1
