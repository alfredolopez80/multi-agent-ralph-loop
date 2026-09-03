> Full text of the global rule ~/.claude/rules/proven/dev-no-placeholders.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# dev-no-placeholders

ABSOLUTE PROHIBITION: Never write placeholder code in ANY development, in ANY project. Every line delivered MUST be real, functional, and complete.

## Forbidden

- Stub values, dummy return values, sample/hardcoded data standing in for real logic
- `TODO` / `FIXME` left as the actual implementation
- `foo` / `bar` / `baz` / `example.com` / `lorem ipsum` as load-bearing values
- `pass` / `...` / `throw new Error("not implemented")` / `NotImplementedError` left as the final delivered state
- Empty function bodies or "fill this in later" comments shipped as done

## If You Cannot Complete It

STOP and ask the user. Do NOT fill the gap with a placeholder. An honest "I need clarification on X" is always better than fake code.

## Detection Duty (applies even outside the current scope)

If you detect a placeholder in ANY file — whether or not that file is the target of the current analysis, PR, or task — you MUST:

1. Run `git blame` on the offending line(s) to identify when and by whom it was introduced.
2. Report the finding to the user (file, line, blame author/commit, and why it is a placeholder).
3. Do NOT silently fix or ignore it.

**Trigger**: Any code authoring, review, analysis, or PR in any project
**Domain**: development
**Confidence**: 1.0
**Usage**: 1
