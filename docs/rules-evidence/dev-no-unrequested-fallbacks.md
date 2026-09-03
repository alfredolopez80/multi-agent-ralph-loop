> Full text of the global rule ~/.claude/rules/proven/dev-no-unrequested-fallbacks.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# dev-no-unrequested-fallbacks

ABSOLUTE PROHIBITION: Never add fallback logic in ANY development, in ANY project, UNLESS the user has requested it explicitly and clearly. Fail loud and fail fast by default.

## Forbidden (unless explicitly requested)

- Silent `try/except` / `try/catch` blocks that swallow errors
- Default-value fallbacks like `value || defaultValue` / `value ?? fallback` that mask failures
- `catch` blocks that degrade silently or return a "safe" stand-in instead of propagating
- "If the real thing fails, use this instead" branches
- Retry-then-pretend-success patterns
- Mock/offline fallbacks left active in production paths

## Why

Fallbacks hide failures and create silent, hard-to-debug behavior. A loud failure surfaces the real problem immediately; a silent fallback buries it until it costs far more.

## The Only Exception

A fallback is permitted ONLY when the user explicitly and unambiguously asks for it for a specific case. "Be defensive" or "handle errors" is NOT explicit authorization for a silent fallback — ask what behavior is wanted on failure.

## Detection Duty (applies even outside the current scope)

If you detect an unrequested fallback in ANY file — whether or not that file is the target of the current analysis, PR, or task — you MUST:

1. Run `git blame` on the offending line(s) to identify when and by whom it was introduced.
2. Report the finding to the user (file, line, blame author/commit, and what failure it is silently masking).
3. Do NOT silently keep or remove it without surfacing it first.

**Trigger**: Any code authoring, review, analysis, or PR in any project
**Domain**: development
**Confidence**: 1.0
**Usage**: 1
