# Archived smart-skill-reminder v3 test suite

**Archived on**: 2026-08-25
**Issue**: #64 (T49 / T52, follow-up to T30)
**Verdict**: REMOVED FROM GATE — mechanism retired, test file preserved as archaeology
**Action**: archived (not deleted) per T30 / T52 decision

## Why it is here

The smart-skill-reminder v3 test suite exercised the v3 implementation
of the hook (filesystem-derived index, hard cap of 3 emissions,
`permissionDecisionReason` channel, double-verification at emit time).
The v3 hook itself was retired in T52 after lead + zc measured that
none of the three channels it tried actually delivered the suggestion
to the model:

  1. additionalContext not honored in PreToolUse: 0/1343 deliveries.
  2. permissionDecisionReason for allow has no slot in the tool_result
     flow: 0/25.
  3. Matching by generic extension produces alphabetical selection,
     not relevance: 60+ skills, first-match wins by file-walk order,
     which is alphabetical on most filesystems.

The hook is now a deprecation header plus a no-op body (consumes stdin
SEC-111, emits the empty allow). The file is NOT registered in
~/.claude/settings.json. Re-registering it would re-introduce a
mechanism that consumes tokens and produces nothing.

This test file was the v3 attempt's evidence. Five tests (PASS on
real skill, FAIL on fresh-regen violation, FAIL on stale-index
violation, 4th-emission silent, regression grep) — they all pass
under v3 because v3's code is internally consistent. They would all
FAIL now because the v3 code is gone (the no-op doesn't emit anything
the tests check for). A failing test for a retired mechanism is worse
than no test: it adds a "red in the gate" entry that nobody acts on.

## Why archive, not delete

The 5 tests document the design intent and the failure modes of v3.
For the next person who considers rebuilding a skill reminder on this
enumerator, the test file is the most concrete description of "what
the v3 attempt expected" — easier to read than the commit message.
The 240 lines are an archaeological artifact, not a regression risk.

## Where the design went

The build-skill-index.sh piece of the v3 attempt survived as the
standalone enumerator (T52) used by mmx-2's lint (T50) for check #4
(no hook references a skill without its SKILL.md). The matching logic
is NOT in scope — the catalog in the model's context (246 skills,
19,705 tokens already paid) replaces any substring-based selector.

## Re-activation guard

The lead's documented criterion in the deprecation header:

  IF YOU'RE READING THIS AND THINKING "MAYBE I CAN MAKE IT WORK":
  1. additionalContext: docs say optional; validation ignores it;
     harness has no slot. Three independent failures.
  2. permissionDecisionReason + allow: no slot in the tool_result flow.
  3. Extension matching: index order IS the selector. Even if the
     channel delivered, the suggestion would be alphabetical noise.

Any of the three is fatal. Build something different.