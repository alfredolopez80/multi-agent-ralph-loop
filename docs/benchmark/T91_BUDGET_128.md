# T91 — Budget 128 measured (closes the 128/256/400/800 row of #47)

**Task**: T91-budget128
**Issue**: #47, acceptance criterion *"128/256/400/800 budget comparison is recorded"*
**Date**: 2026-08-28
**Worker**: mmx-3
**Status of the row**: 128/256/400/800 now measured; 1200 added as a sanity reference.

---

## Briefing delta (must be raised to lead)

The ASSIGN for T91 said:

> *"the doc de benchmark de T76 está en docs/benchmark/ (localízalo vía el diff del commit)"*

This premise is **factually wrong against the repo**:

1. `git show ba3b31a --stat` (the T76 commit) touches only two files:
   `scripts/memory/recall_v2.py` and `tests/memory/test_recall_v2.py`.
   **No doc under `docs/benchmark/` is created or modified.**
2. `ls docs/benchmark/` on this worktree contains four docs (`BASELINE_A_SECURITY_ONLY_2026-08-26.md`,
   `MEMORY_BASELINE_2026-04-07.md`, `TEST_RESULTS_W4.3_2026-04-07.md`, `WAKE_UP_COST_2026-04-07.md`)
   and one subdir (`t83/`). **None of them document the 256/400/800/1200 row.**

Where T76 actually registered the row: the **commit message** of `ba3b31a`, the
**inline comment** in `scripts/memory/recall_v2.py:518-527` (the `budget_limit=800`
default), and the **regression test** `test_budget_valley_is_real_and_documented`.

For T91 I therefore register the new 128 row **here** (this is the closest analogue
to a benchmark doc the repo has, and the ASSIGN names `docs/benchmark/` as the
intended location) **and** in the regression test, mirroring the two places T76
actually wrote to. The integrated-tick decision belongs to whoever merges.

---

## What was measured

The T76 fixture from `test_budget_valley_is_real_and_documented` is the corpus.
It reproduces the geometry T72 measured on the real procedural-rules corpus
(see the docstring of that test: *"the fixture reproduces the measured geometry
(T72 real corpus: big rule 257u, smalls 33-48u)"*). Geometry = number of items
selected, whether the big high-ranked item is admitted, and whether the
non-monotonic valley (400 < 256) holds.

**What this row is NOT**: it is not a re-run of T72's measurement on the real
corpus. The real-corpus score_sum (87.5 at 256, 79.5 at 400, plateau 161 at
800/1200) comes from `~/.ralph/procedural/rules.json` plus the migrated
`TreeStore` for the project — that depends on global state, and the T91 ASSIGN
explicitly forbids improvising a method to reproduce it. The fixture-based
numbers below are comparable to T76 in **shape**, not in absolute score_sum.

### Table (all five rows measured on the same fixture, in the same run)

| budget | selected | score_sum | units_used (sum) | units_used (trace) | scores              | units each       |
|-------:|---------:|----------:|-----------------:|-------------------:|---------------------|------------------|
|    128 |    **3** | **101.0** |          **125** |            **125** | 42.0, 31.0, 28.0    | 42, 41, 42       |
|    256 |    **5** | **147.0** |          **210** |            **210** | 42.0, 31.0, 28.0, 26.0, 20.0 | 42, 41, 42, 42, 43 |
|    400 |    **3** | **107.0** |          **360** |            **360** | 42.0, 34.0, 31.0    | 42, 277, 41      |
|    800 |    **5** | **161.0** |          **444** |            **444** | 42.0, 34.0, 31.0, 28.0, 26.0 | 42, 277, 41, 42, 42 |
|   1200 |    **5** | **161.0** |          **444** |            **444** | 42.0, 34.0, 31.0, 28.0, 26.0 | 42, 277, 41, 42, 42 |

Notes on the table:

- 128 selects the top-3 smalls; the big item (277u) cannot fit and is rejected
  with `budget_exceeded`. Two smalls also fail to fit (would push `used` past 128).
- 256 selects all 5 smalls; the big item still cannot fit (its 277u > remaining 256-125 = 131).
- 400 admits the big item, then fits only 2 smalls on top; remaining budget
  cannot fit the 3rd small. **This is the same valley geometry T76 published.**
- 800/1200 select all 5 with the big included; units_used saturates at 444 —
  the plateau.

### Geometry parity vs T76 (commit ba3b31a)

| claim from T76                                                                              | this run  | verdict |
|---------------------------------------------------------------------------------------------|-----------|---------|
| 256 fills the limit with small items, big excluded                                          | 5 smalls, units=210 ≤ 256, big excluded | **OK** |
| 400 admits the big item and crowds out small ones, fewer items than 256                      | 3 items (big + 2 smalls), < 5            | **OK** |
| 400 score_sum < 256 score_sum (the valley)                                                  | 107 < 147                                | **OK** |
| 800 / 1200 are equivalent (plateau); 1200 is 2.9× oversized over the plateau                | 161 == 161 at units=444 in both         | **OK** |
| 256 score_sum == 87.5 on the real corpus                                                    | fixture measures 147; corpus differs    | **N/A — corpus mismatch, see above** |

### What 128 actually says (the result the issue asked for)

- **3 items, score_sum 101, units_used 125.** Below the 800/1200 plateau
  (5 items, score_sum 161), and below 256 (5 items, score_sum 147).
- **score / units ratio is 0.81 at 128** vs 0.70 at 256 and 0.30 at 400:
  128 is the most *efficient* budget of the range per unit of budget, but
  pays for that by leaving two smalls off the list. Whether that trade is
  acceptable depends on whether the caller wants fewer-but-higher-density
  context (128 wins) or coverage (256 wins).
- There is **no anomaly at 128** — no inversion, no surprising greedy
  behaviour. The greedy behaves exactly as expected: the big item does not
  fit, so it is skipped, then smalls are admitted in score order until the
  budget saturates.
- **128 is below the 257u big item's own footprint**. So long as a single
  top-1 rule in the corpus renders above 128u, 128 will never be able to
  carry it. T76's chosen default (800) is robust against that; 128 is not.

---

## Command and output (verbatim)

Command:

```bash
python3 results/measure_budget_128.py
```

Output:

```
# T91 budget=128 measurement (fixture = T76's test_budget_valley_is_real_and_documented)

| budget | selected | score_sum | units_used (sum) | units_used (trace) | scores | units each |
|-------:|---------:|----------:|-----------------:|-------------------:|-------:|------------|
|   128 |        3 |    101.00 |              125 |                125 | 42.0,31.0,28.0 | 42,41,42 |
|   256 |        5 |    147.00 |              210 |                210 | 42.0,31.0,28.0,26.0,20.0 | 42,41,42,42,43 |
|   400 |        3 |    107.00 |              360 |                360 | 42.0,34.0,31.0 | 42,277,41 |
|   800 |        5 |    161.00 |              444 |                444 | 42.0,34.0,31.0,28.0,26.0 | 42,277,41,42,42 |
|  1200 |        5 |    161.00 |              444 |                444 | 42.0,34.0,31.0,28.0,26.0 | 42,277,41,42,42 |

…

Control-parity verdict: DRIFT vs T76
EXIT=1
```

`EXIT=1` is the script's own *control-parity* check failing on the **score_sum**
column (147 vs 87.5 at 256; 107 vs 79.5 at 400). This is the corpus-mismatch
artifact explained above — not a regression in the engine. The geometry checks
(all five in the table) **pass**.

---

## Verdict on #47 acceptance bullet

The bullet:

> *- [ ] 128/256/400/800 budget comparison is recorded.*

After T91:

- **128**: measured on the T76 fixture. 3 items, score_sum 101, units 125.
- **256**: 5 items, score_sum 147, units 210 (matches T76 geometry; score_sum
  on fixture, not on corpus).
- **400**: 3 items, score_sum 107, units 360 (matches T76 valley geometry).
- **800**: 5 items, score_sum 161, units 444 (plateau).
- **1200**: 5 items, score_sum 161, units 444 (plateau, equivalent to 800).

**The bullet is tildable**: the comparison is recorded with measurements on
the same fixture, in the same run, in one place. The comparison T76 was
missing (the 128 point) is now present. The integrated tick should also note
the corpus caveat above, because the real-corpus re-run is a separate piece
of work that requires global state and was not in scope for T91.

The default (`budget_limit=800`) is unchanged — T91 only adds a data point;
it does not propose changing the default.

---

## Files changed by T91

- `results/measure_budget_128.py` — measurement script (allowed path).
- `docs/benchmark/T91_BUDGET_128.md` — this doc (allowed path).
- `tests/memory/test_recall_v2.py` — extends
  `test_budget_valley_is_real_and_documented` with a 128 row (allowed path;
  pins the new measurement against drift).

## Regression-test pin (preview)

The test will gain an additional block (same style as the 256/400 assertions):

> `sel_128 = recall(query, ctx, home, limit=5, budget_limit=128)["memory_context"]`
>
> `assert len(sel_128) == 3`
>
> `assert all(estimate_units(i) != big_units for i in sel_128)`
>
> `assert sum(i["score"] for i in sel_128) == 101.0`

Final validation: `bash tests/run-all-unit-tests.sh` is run before the DONE.
