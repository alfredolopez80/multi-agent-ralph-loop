# Plan C — Certification Metrics for #48 Phase 3 (post-implementation)

**Date**: 2026-08-28 · **Worker**: mmx-2 · **Machine**: this laptop
**Owner**: lead (zc) · **Source**: T93 amendment of 2026-08-28
**Purpose**: pre-register the certification matrix BEFORE anyone runs #48 M2.
A threshold that is set after the implementation is a placebo — this document
locks the rules in advance so the before/after measurement is not movable.
The repo rule on before/after measurement (`feedback_demand_before_after_measurement.md`)
says exactly this: "Umbrales pre-registrados ANTES de implementar, misma
sonda antes/después, y el epic cierra por sonda re-ejecutada, no por tildado".

## Status taxonomy for each row

- **Sonda**: the instrument that produces the number. MUST exist already
  at the time of pre-registration (a probe promised for the future is a
  phantom threshold).
- **Baseline**: the value the sonda produced on this tree on the date the
  row was pre-registered. Re-running the sonda today MUST produce a
  number within the run-to-run variance of the recorded baseline, or the
  pre-registration is stale.
- **Threshold (umbral)**: the rule that determines PASS/FAIL for the
  post-M2 measurement. Three forms are used below:
  - **Numeric cap** (row 1, 2, 6, 7): post-M2 number ≤ target.
  - **Direction** (row 3): post-M2 number moves toward a stated regime.
  - **Invariance** (row 4, 5): post-M2 number equals the baseline exactly.

## The matrix

| # | Metric | Sonda | Baseline | Threshold (umbral) |
|---|---|---|---|---|
| 1 | Latencia hooks por turno ordinario | `scripts/benchmark/hotpath_probe.py` (N=12, isolated HOME) | **546 ms** per ordinary Bash call (PreToolUse 320 + PostToolUse 226; details in HOTPATH_M1_2026-08-28.md) | **≤ 380 ms** per ordinary Bash call (-30% vs baseline). Run-to-run variance is ±10% per T83 finding, so the threshold must be re-measured in the same window as the post-M2 measurement; a one-shot "looks lower" reading is not certification. |
| 2 | Tokens inyectados en SessionStart (wake-up block) | `tiktoken cl100k_base` over the wake-up-layer-stack.sh block as rendered today | **~1950-2000 tok** (2026-08-23, see project CLAUDE.md layer stack section; cite, do not re-derive) | **≤ 1200 tok** (-37% vs baseline). Wake-up tokens are the easiest pre-registration: a direct number with no decomposition needed. |
| 3 | Overhead por plano (orchestration+state vs security) | re-use the 9 BASELINE_A metrics, particularly plane attribution | 61% / 29% / 6.7% / 2% / 1.4% (orchestration+state / security / aristotle / security-adjacent / memory) | **orquestación+estado deja de dominar** = its share drops below the security plane's share AND below 30%. Pre-M2 state: 61% > 29%. Post-M2 must be ≤ 30% (so security is at least 2× orchestration). |
| 4 | Security plane (cero regresión) | `pytest tests/test_security_only_profile.py` + `pytest tests/test_hooks_security_baseline.py` (manifest + equivalence gate) | **22/22 green today** (12 + 10) | **22/22 green post-M2**. Any regression on either suite is an automatic FAIL for the certification. The plane is held constant from real variant A onward — this is the critical rule of #46, not just a convenience. |
| 5 | Recall on-demand útil (verde + budget 800 intacto) | T92 probe (to be requested from zc-3 once they close T92) + the wake-up block's default budget | T92 (pending zc-3 close) — pre-registered rule does NOT change with the baseline value | **PASS = (a) T92 probe verde AND (b) the default budget of 800 in `recall()` is unchanged from ba3b31a**. The budget is measured by `inspect.signature(recall).parameters["budget_limit"].default == 800` (covered by `test_default_budget_is_the_measured_plateau`). |
| 6 | Trivial task zero-subagent (no hook DENIES direct Edit/Write) | `scripts/benchmark/trivial_task_probe.py` (N=3 fixtures × 9 PreToolUse hooks = 27 cells, isolated HOME, parses each hook's JSON decision) | **0 DENY, 0 ASK on 27 cells; 24 ALLOW + 3 OTHER (k8s-context-guard emits cluster context, not a decision)** — T96 baseline 2026-08-28. Probe output: `results/trivial-task-probe.{json,txt}`. Survey result: the only hook that touches subagent dispatch is `fast-path-check.sh` (PreToolUse:Task only); it SUGGESTS direct execution for trivial, does NOT deny direct work. | **PENDIENTE (post-M2 registration).** Pre-registered rule will be: post-M2 probe must show 0 DENY (no hook may coerce subagent for trivial work) AND 0 NEW deny on the 27 cells vs the T96 baseline. The post-M2 certificate author will record exact per-hook decision matrix. |
| 7 | Maintenance fuera del prompt ordinario | trace audit over N>=20 ordinary prompts (manual sampling of jsonl transcripts under `~/.claude/projects/**/*.jsonl`) | C9 (vault-graduation, vault-promotion, auto-sync-global, vault-weekly-compile run during prompts) | **0 ejecuciones** of any maintenance hook (vault-graduation, vault-promotion, auto-sync-global, vault-weekly-compile, vault-index-updater if used outside SessionEnd) inside an ordinary prompt window. Allowed only at SessionStart, SessionEnd, or explicit cold-path triggers. |

## How to run the certification

```bash
# Reconstitute the M1 baseline (same instrument)
scripts/benchmark/hotpath_probe.py --out results/baseline-m1-2026-08-28

# Run all security-plane regressions
pytest tests/test_security_only_profile.py -q
pytest tests/test_hooks_security_baseline.py -q

# Inspect the wake-up block (SessionStart tokens)
bash .claude/hooks/wake-up-layer-stack.sh 2>/dev/null \
  | head -c 100000 \
  | results/t93-venv/bin/python -c "import tiktoken,sys; print(len(tiktoken.get_encoding('cl100k_base').encode(sys.stdin.read())))"

# Check the recall default budget is unchanged
results/t93-venv/bin/python -c "import inspect, sys; sys.path.insert(0,'scripts/memory'); from recall_v2 import recall; assert inspect.signature(recall).parameters['budget_limit'].default == 800, 'budget drifted'; print('budget 800 OK')"
```

The T92 probe for row 5 is a zc-3 deliverable — request it via SendMessage
when needed; do not invent a placeholder.

The probe for row 6 must be designed and added to the tree before #48 M2
can be certified. Until then, the certification status of #48 is
"INCOMPLETE — row 6 has no sonda". This is a real state, not a paperwork
gap; M2 must NOT close with this row unresolved.

## Why pre-registration matters here

The full catalogue of `feedback_discriminant_resolution.md` is the
complement: a threshold that the implementer can move after the
measurement is a placebo, not a discrimination rule. Three of the seven
rows above are pure numeric thresholds (1, 2, 7), two are invariance
rules (4, 5), one is a regime change (3), one is a probe-existence gate
(6). None of them is movable: the only way to make a row PASS is to
produce a number the sonda can confirm.

A common failure mode (not in this repo but seen elsewhere): an
"optimization" task records a faster post-measurement by relaxing the
baseline in passing. Pre-registration in this file is the structural
countermeasure. If a future row ever reads "PENDIENTE" with a date older
than the M1 date, that row MUST be rejected — the slot exists to keep
the implementer honest.

## Sign-off

- Author: mmx-2, 2026-08-28.
- Owner: lead (zc) — accepts or amends by SendMessage.
- Linkage: this file is the input to the post-M2 certification report
  (to be added under `docs/benchmark/CERT_2026-XX-XX_<descriptive>.md` when
  M2 completes).
