# pr12-crossverify-checklist — zc-4's independent verification plan for PR12-EXEC

Task: pr12-precheck · Author: zc-4 · Base: main `847450e` per ASSIGN (probes are
SHA-sensitive; I re-anchor to the exact SHA zc-3 certifies before re-measuring) ·
Date: 2026-09-01
Sources read (no edits): `.claude/worktrees/mmx-3/results/PR12-PREP-runbook.md`
(320 L), `docs/benchmark/PHASE2_BASELINE_2026-08-31.md` (137 L, via
`git show main:`), `docs/benchmark/PLAN_CERT_METRICS.md` L25–70 (threshold
matrix), the 4 probes at `scripts/benchmark/` (docstrings + methods, via
`git show main:`).
Hard rule (inherited, restated): thresholds are pre-registered
(PLAN_CERT_METRICS L29–L37) and DO NOT MOVE. My mandate is to DETECT figures
that do not reproduce and gates that got relaxed — never to adjust a threshold,
a baseline number, or an instrument to reconcile a disagreement.

## §0 — Precheck facts already verified (before zc-3's report exists)

| check | result |
|---|---|
| Baseline drift | `git log main -- docs/benchmark/PHASE2_BASELINE_2026-08-31.md` → exactly ONE commit (`2a453d6`, PR4-BASE). Frozen intact since `bfcfef2`. |
| Runbook exists | mmx-3 worktree, 20,462 B, mtime 2026-08-31 23:52. |
| Baseline anchors | main SHA `bfcfef251ee…`; ACTIVE settings sha256 `c6195c54ec7b…` (PHASE2 L15) — G-evidence item 4 compares against this. |
| gitignore policy | `.gitignore:194–195`: results/ is read-by-lead, nobody commits. THIS checklist is committed via explicit `git add -f` because the ASSIGN demands a commit — deviation is deliberate and recorded in the commit message. zc-3's raw artifacts stay uncommitted (policy holds for them). |

## §1 — What I re-run when zc-3's report arrives (per sonda)

### A1 — Hot-path latency (Row 1; threshold ≤380 ms/Bash-call, pre-registered)

- Re-run: `python3 scripts/benchmark/hotpath_probe.py --setup` then `--out results/zc4-xv-hotpath` in MY worktree, rebased to the certified SHA.
- Compare vs zc-3's number AND vs baseline 514.0 ms (PHASE2 L42; M1 anchor 546 ms).
- Agreement band: **±15%** between the two independent runs (10% T83 run-to-run variance on each side, compounded). Threshold verdict is INDEPENDENT of the band: each run is judged alone against ≤380 ms.
- Security plane invariance: security-plane medians within ±10% of baseline 261.7 ms (L31) — those 4 hooks are slice-untouched; a bigger shift = environment drift, investigate before trusting any other number.
- **FAIL**: either run >380 ms; agreement outside ±15% without a named cause (machine load, rebase mismatch); security plane shifted >±10%; report omits per-hook min/median/p90/max; N<10.

### A2 — Wake-up tokens (Row 2; threshold ≤1200 tok, pre-registered)

- Re-run: the literal PHASE2 L51–L54 command, **`</dev/null` is MANDATORY** (hook blocks forever otherwise — documented trap). Measure BOTH whole-stdout and `additionalContext`-only figures (baseline L58: 1792 / L59: 1615).
- tiktoken env: runbook uses `scripts/benchmark/.venv`. If absent in my worktree: `uv run --with tiktoken` fallback, same cl100k_base encoder, **disclosed in my report as an env deviation** (instrument-adjacent, not instrument change).
- Content drift is expected (vault stats + recall top-rules move between runs): agreement band **±5%** vs zc-3's figures. HARD FAIL only vs the threshold itself — and per runbook §A2 caveat, a threshold breach here is a FINDING to report, not an executor error and never a threshold edit.
- **FAIL**: only one of the two figures reported (stdout vs additionalContext conflated); no raw `/tmp/wu.txt`-equivalent artifact; number invented without a capture file.

### A3 — Trivial task probe (Row 6; 0 DENY + 0 NEW deny vs T96)

- Re-run: `python3 scripts/benchmark/trivial_task_probe.py` (stdlib-only, deterministic).
- Expected EXACT replica of PHASE2 L71–L73: **cells=27, allow=24, deny=0, ask=0, other=3, any_deny=False, any_ask=False**.
- **FAIL (zero tolerance)**: ANY cell differs — a new PreToolUse:Bash hook, a changed decision class, a moved k8s-context-guard "other". Determinism means agreement is the only acceptable outcome. Cross-check `--strict` exit: with deny=0 it must exit 0; if the report claims deny=0 but `--strict` would exit 1, the report is wrong.

### A4 — Active registration counts (Row 4-adjacent; invariance = security plane)

- Re-run BOTH commands: `--ref main --json` (example profile) and `--path ~/.claude/settings.json --json` (ACTIVE).
- Example count at the SAME SHA: **EXACT match** required (the probe reads via `git show <ref>:` — same SHA must give the same number; baseline L83: 21 commands / 16 matchers).
- ACTIVE count: snapshot `shasum -a 256 ~/.claude/settings.json` BEFORE my run. If my hash == zc-3's reported hash → counts must match EXACTLY. If hash differs → user-side drift between runs: report both (count, hash) pairs; the comparison becomes "did the count move WITH a recorded, explainable settings change" — an unexplained delta is a FAIL.
- Arithmetic sanity (runbook L104, inference NOT threshold): ACTIVE ~56 expected from 74 − 8 (F) − 7 (C) − 3 (B) + ~5 (F additions) − PR10 C5 deltas. A number far from this WITHOUT a named slice-by-slice reconciliation in the report = red flag to escalate, not a FAIL by itself.
- **FAIL**: example count differs at same SHA; ACTIVE numbers without a hash; dedup rule changed (the probe's tally rule is documented at PHASE2 L87–L91 — the report must use the same instrument's number, not `grep -c` of its own).

### A5 — Maintenance sampling (Row 7; 0 mid-prompt EXECUTIONS)

- Not reproducible by re-running (transcript set moves). My verification is methodological + evidential:
  1. Method invariants in zc-3's run: N≥20 transcripts, ordinary-prompt filter applied, instrument = the runbook's `pr12-maintenance-sample.py` (not reinvented), evidence file EXISTS and is non-empty (fail-loud: an absent evidence file voids the row, not "passes by default").
  2. **I re-review the line-level evidence MYSELF** (this is the claims/narrative boundary the runbook L133 draws): every evidence line is either SessionStart/End-context injection (allowed) or a mid-prompt execution (FAIL). One mid-prompt execution line = Row 7 FAIL regardless of the raw mention count.
- **FAIL**: verdict derived from raw mention counts alone (the exact conflation PHASE2 L111–L117 forbids); evidence file missing/empty; any mid-prompt execution line unexplained.

### Probe-adjacent — claude_md_tokens.py (PR10 scope, cross-checked cheap)

- Re-run `uv run --with tiktoken python3 scripts/benchmark/claude_md_tokens.py --gate 1200`; deterministic given the same files. If zc-3's cert cites CLAUDE.md numbers, my re-run must match EXACTLY unless the files changed (then re-anchor SHA). Exit 1 with reason is the fail-loud contract — a green claim with exit-1 behavior = report error.

## §2 — The 12 hard-gates: I re-run ALL of them myself

Mechanics note: my Bash guard blocks shell `for` loops — I write the gate
commands into a flat script (`results/zc4-xv-gates.sh`) and run it plain
(documented pattern). Gate-by-gate FAIL criteria:

| gate | my FAIL criterion beyond "command nonzero" |
|---|---|
| G1 | row table has ≠7 rows; verdict arithmetic wrong (PASS≥7, or 5 PASS + 2 INCOMPLETE with rationale for exactly rows 5/6); INCOMPLETE used on rows 1–4 or 7 |
| G2 | manifest exists but control/gap sets differ from the literal set in the runbook |
| G3 | any of the 5 worker-blocked-safe hooks missing from `.claude/hooks/` |
| G4–G6 | any absence suite fails OR is skipped with exit-code laundering (pytest exit 5 "no tests collected" is FAILURE per zero-tests rule, never success) |
| G7 | full suite: `failed==0` AND `total>0` BOTH asserted; a "PASS" report without a visible total is rejected |
| G8 | any non-audit-secrets command under PostToolUse Edit\|Write\|Bash |
| G9 | /ship skill missing or cites <3 of the three relocated detectors |
| G10 | archive README missing or without purge policy line |
| G11 | no `__pycache__`/`.pyc` pattern in .gitignore |
| G12 | ANY of the 19 deleted hooks referenced by a distributor (`scripts/`, `install*.sh`) outside the excluded doc/archive/worktree paths — one hit is FAIL, "19 OK lines" is the only green |

Gate-relaxation detection (my actual mandate): I diff each gate's verification
command in zc-3's report against the runbook §C text. A gate run with a modified
pattern (added `grep -v`, widened exclusion, `|| true`, exit-code swallowed) is a
**relaxed gate = FAIL of the report**, even if the gate's output says OK.

## §3 — Claims vs narrativa in zc-3's report

| class | items | my treatment |
|---|---|---|
| VERIFIABLE CLAIM | every post-borrado number (A1 medians, A2 tokens, A3 cells, A4 counts), ACTIVE settings sha256, gate outputs 1–12, pytest exits (G4–G6), delta column with sign | must cite a raw artifact path (`results/pr12-*`); I re-derive each independently per §1/§2 |
| NARRATIVE (acceptable) | methodology note wording, sign-off, caveats, "not measured" for cache counters (pre-registered as such, PHASE2 L119–L124) | consistency check only |
| RED FLAGS (report-level FAIL) | a number with no artifact path; "approximately"/rounded-only values in verdict cells; delta without sign; a threshold restated with a different value or softened form; PASS verdict on a row whose number is absent; INCOMPLETE outside rows 5/6; a cache-counter number (inventing one is a placebo by definition); "the gate passed" claims for gates run with modified commands | each occurrence = escalate to lead with the exact quote and my contradicting evidence |

## §4 — Preconditions and escalation

1. Re-anchor my worktree to the exact SHA zc-3 certifies (probes are SHA-sensitive) — REBASE flow via lead if behind.
2. Snapshot settings hash before A4; disclose any drift between runs.
3. I do NOT run any sonda before zc-3's report exists (ASSIGN order) — this checklist only pre-registers MY tolerances, so my future disagreement cannot be accused of being tuned post-hoc (same pre-registration logic as the thresholds themselves).
4. Any FAIL → SendMessage BLOCKED/finding to lead with raw output, command, and my artifact path. Never "fix" a probe, threshold, baseline, or report to reconcile. A delta that reads as failure is DOCUMENTED, not rewritten (runbook closing rule).
5. What I do NOT verify (out of scope): §D issue-close wording, #46 already-closed documentation, lead's interpretation of findings.

## §5 — Tolerance summary (one table)

| sonda | nature | agreement band vs zc-3 | hard FAIL criterion |
|---|---|---|---|
| A1 hotpath | stochastic-bounded | ±15% (10% T83 compounded) | >380 ms either run; band breach w/o named cause; security plane >±10% |
| A2 wake-up | content-dependent | ±5% | threshold breach (reported as FINDING); conflated figures; no artifact |
| A3 trivial | deterministic | EXACT | any cell differs; `--strict` contradiction |
| A4 counts | deterministic (example) / hash-gated (ACTIVE) | EXACT at same SHA/hash | example diff at same SHA; unexplained ACTIVE delta |
| A5 maintenance | non-reproducible | method invariants | any mid-prompt execution line; evidence file absent; verdict from raw mentions |
| claude_md | deterministic | EXACT per file state | gate exit-1 with green claim |
| G1–G12 | deterministic | EXACT (12/12 PASS) | any FAIL, any modified gate command, any exit-code laundering |

End of checklist. Everything above pre-registers MY future behavior so that when
zc-3's report lands, my cross-verification is comparison against pre-stated bars —
the same epistemics the runbook demands of the certification itself.
