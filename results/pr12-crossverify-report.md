# pr12-crossverify-report — zc-4 independent cross-verification of PR12-EXEC/RECERT

Task: cross-verify PR12 · Verifier: zc-4 · Date: 2026-09-01
Tree: my worktree rebased to main `92e8338` (certified tree; rebase deduped my
checklist patch as predicted). ACTIVE settings sha256 at my run:
`00379887e357978f4519cf56300ac04e984cca915d21450c4191bfae0185d79d` — IDENTICAL to
the EXEC and RECERT reports' hash: no user-side drift, all exact comparisons valid.
Method: bars pre-registered in `results/pr12-crossverify-checklist.md` BEFORE any
measurement (same epistemics as the thresholds). Same instruments, my own runs,
my own artifacts under `results/zc4-xv-*`. Thresholds untouched throughout.

## Verdict: cross-verify 4/5 REPRODUCED + 1 FINDING (A1)

Every deterministic figure in the EXEC/RECERT reports reproduces EXACTLY. The one
latency figure that carries a PASS verdict (Row 1) does NOT reproduce in two
independent same-instrument runs in my window — documented as FINDING F1, escalated
to lead for arbitration. No band was moved to reconcile anything.

## Per-sona results

| sonda | zc-3 claim | my re-measurement | agreement | verdict |
|---|---|---|---|---|
| A1 hotpath per-Bash-call | **362.3 ms** → Row 1 PASS (≤380) | run1 **567.8** / run2 **483.3** (Pre 383.5/314.0 + Post 184.3/169.3) | **OUT of ±15% band** | **NOT REPRODUCED — F1** |
| A2 wake-up tokens | 1127 stdout / 971 ctx | **1127 / 971** | EXACT (byte-identical capture, 4180 B) | REPRODUCED ✓ |
| A3 trivial probe | 21 cells: 18 allow / 0 deny / 0 ask / 3 other | **21 / 18 / 0 / 0 / 3**, `fixtures_with_deny=0` | EXACT | REPRODUCED ✓ |
| A4 counts (ACTIVE) | 44 commands / 18 matchers / 10 events | **44 / 18 / 10 events** | EXACT (same settings hash) | REPRODUCED ✓ |
| A4 counts (example @ main) | 21 → 15 | **15 commands / 14 matchers** | EXACT | REPRODUCED ✓ |
| A5 maintenance | 192 raw mentions, 11-of-25 transcripts, 0 mid-prompt executions | per-hook totals match sample.txt (46+39+81+13+index); **11-of-25 recomputed by me from the sample rows**; **my own line-level audit of the 46-line evidence file: 0 mid-prompt executions** (all lines = SessionStart injection / user-model prose / queue-operations) | method + evidence | REPRODUCED ✓ |
| claude_md scopes (PR10) | 1195 repo + 1200 global, 79/79 lines, GATE PASS | **1195 + 1200, 79/79, GATE PASS (exit 0)**; MEMORY.md absent — D3/D4 landed as claimed | EXACT | REPRODUCED ✓ |
| Row 4 security plane | 22/22 | **22 passed in 0.29s** (`test_security_only_profile.py` + `test_hooks_security_baseline.py`) | EXACT | REPRODUCED ✓ |
| Row 5 recall budget | T92 verde + budget 800 | T92 probe EXIT=0; `budget_limit` default **== 800** asserted | EXACT | REPRODUCED ✓ |

## F1 (the finding): Row 1's PASS does not reproduce — six numbers, three artifacts

| measurement | per-Bash-call | vs frozen baseline 514.0 (PHASE2 L42) | artifact |
|---|---:|---:|---|
| zc-3 certified (window ~11:57Z) | 362.3 ms | −29.5 % | `worktrees/zc-3/results/pr12-posthoc-hotpath/hotpath-probe.{json,txt}` |
| zc-4 run 1 (window ~14:5xZ) | 567.8 ms | +10.4 % | `results/zc4-xv-hotpath/hotpath-probe.{json,txt}` |
| zc-4 run 2 (attribution, minutes later) | 483.3 ms | −6.0 % | `results/zc4-xv-hotpath-run2/hotpath-probe.{json,txt}` |

- Both MY runs are inside T83's documented ±10 % run-to-run variance **of the frozen
  baseline**; zc-3's certified number sits −29.5 % from baseline — outside that band —
  and outside my pre-registered ±15 % agreement band vs both my runs.
- Read plainly: in MY window the per-Bash-call hot path is statistically
  indistinguishable from the pre-deletion baseline; the certified −29.5 % improvement
  is window-dependent. I can NOT rule out that zc-3's window was a genuinely quieter
  machine state — their run is internally consistent (their per-hook table sums to
  their aggregate exactly) and every OTHER figure they certified reproduces exactly.
  This is an arbitration question for lead, not something I adjudicate.
- Recommended arbitration (thresholds untouched): one lead-supervised N=3 re-run in
  a controlled idle window (no live worker sessions measuring concurrently), report
  all three numbers, and certify Row 1 against the MEDIAN of the window — or record
  Row 1 as INCOMPLETE with that rationale, which the runbook's G1 admits with
  explicit rationale only for rows 5/6, so amending G1's scope is a lead decision,
  not mine.
- Per-hook shape (both parties' tables agree on the composition): permission-guard
  dominates and swings the aggregate (zc-3 142.7 / my run1 210.6 / run2 185.8 vs
  PHASE2 baseline median 192.2). My security-plane medians are within ±10 % of the
  PHASE2 baseline per hook; zc-3's are uniformly below it. The disagreement is a
  window/regime effect, not an instrument or tree difference (same 17-row table, same
  3 HOOK_NOT_FOUND, both post-Slice-E trees).

## Minor findings (documented, none affect verdicts)

- **F2 lifecycle variance**: `session-end-handoff` medians 179.1 (zc-3) / 9.3 (my r1) /
  223.2 ms (my r2) on identical code — the lifecycle plane's run-to-run spread is ~25×
  and my probe-home-state hypothesis was FALSIFIED by run 2 (warm home, slow again).
  Excluded from Row 1 by design (fires on SessionEnd), but any future lifecycle-plane
  claim needs its own variance treatment.
- **F3 evidence-file naming**: the A5 line-level evidence lives at
  `results/pr4-maintenance-evidence.txt` (PR4-BASE name), while runbook §A5 names
  `pr12-maintenance-evidence.txt`. Naming-only; substance audited by me above.
- **F4 zero-headroom boundary**: global `~/.claude/CLAUDE.md` measures EXACTLY 1200
  tokens — the gate boundary. PASS today; any single added line breaks it. Informational
  for whoever edits that file next.
- **F5 A3 cell-count reconciliation**: baseline 27 cells → certified 21 (3 fixtures ×
  9 hooks measured, 6 results uncounted by the probe's cell rule after Slice B/C
  removals). The pre-registered invariant is "0 DENY + 0 NEW deny", which holds in my
  run exactly; the runbook's "cells stay 27" prediction was wrong and zc-3 documented
  the reconciliation instead of massaging it — correct behavior, noted for the record.

## Claims vs narrativa

Every verdict-bearing number in EXEC/RECERT traced to a raw artifact that exists and
reproduces (A2/A3/A4 byte-exact; A5 recomputed from their sample rows; Row 4/5
re-executed). Cache counters correctly "not measured" (pre-registered). The G8
amendments (mmx-3 recalibration + lead adjudication L1(a), runbook refinement cited
at lines 399–422) are the sanctioned fix-the-guard path, out of my re-measurement
scope per the GO — recorded as observation, not verified by me.

## Artifacts (mine, uncommitted per results/ policy)

`results/zc4-xv-hotpath/` + `-run2/` (A1), `/tmp/zc4-wu.txt` (A2 capture),
`results/zc4-xv-trivial/` (A3), `results/zc4-xv-count-{example,active}.json` (A4),
this report (the only force-added file, per ASSIGN).

End of report. Rule honored: no threshold, band, baseline or instrument was changed
to reconcile any disagreement — F1 travels to lead with its raw artifacts.
