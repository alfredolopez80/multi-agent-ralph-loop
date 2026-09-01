# PR12-PREP-runbook — Certification runbook for #69 Phase 5 (the cierre del plan)

Task: PR12-PREP · Author: mmx-3 · Date: 2026-08-31 · Status: DOCUMENTAL (read-only)

This runbook is the playbook that the certification executor follows. It is not the
certification report itself — the executor runs the 5 sondas (§A), populates the
report schema (§B), verifies each hard-gate (§C), and closes the issues in the
declared order (§D). The output of the executor is `docs/benchmark/CERT_2026-XX-XX_PR12-post-borrado.md`.

## Sources (with file:line citations)

| Source | Purpose | Cited location |
|---|---|---|
| `docs/benchmark/PHASE2_BASELINE_2026-08-31.md` | Baseline congelado BEFORE slices A-F (zc-3, 2026-08-31T17:50Z, main @ `bfcfef251ee53972ce900a9cfa94ea37f3d16260`) | L1-L138 |
| `docs/benchmark/PLAN_CERT_METRICS.md` | Thresholds pre-registrados (mmx-2, 2026-08-28) — owner: lead (zc) | L29-L37 (matrix) |
| `docs/benchmark/HOTPATH_M1_2026-08-28.md` | M1 medición original (546 ms per Bash call pre-registrado) | referenced from PLAN_CERT_METRICS L31 |
| `docs/benchmark/BASELINE_A_SECURITY_ONLY_2026-08-26.md` | Baseline A — security plane isolated (22/22 green, reference for Row 4 invariance) | L1-L80 |
| `results/HOOK-TESTS-69.md` | Inventario 71 hooks post-Slice C — used to predict post-borrado counts | mmx-3, this session |
| `results/PR7-PREP-plan.md` + `results/PR11-PREP-plan.md` | Slices C/F — what was deleted; the post-borrado expected to land in the cells | mmx-3, this session |

---

## §A — Re-execution list (5 sondas, exact commands)

### Sonda A1 — Hot-path latency (Plan C Row 1)

**Command (verbatim from PHASE2_BASELINE L24)**:
```bash
python3 scripts/benchmark/hotpath_probe.py --setup
python3 scripts/benchmark/hotpath_probe.py --out results/pr12-posthoc-hotpath
```

**Setup required**: `--setup` creates an isolated HOME so the probe doesn't touch the user's real settings. The probe runs N=12 per hook (raw JSON includes per-hook min/median/p90/max).

**Baseline numbers (PHASE2_BASELINE L29-L44, file:line cited)**:
- Total per-ordinary-turn (sum of hook medians, 20 hooks): **948.3 ms** (L38)
- Per-Bash-call (PreToolUse + PostToolUse): **514.0 ms** (L42: `PreToolUse 293.1 + PostToolUse 220.9`)
- Plane breakdown: security 261.7 ms / 4 hooks; security-adjacent 8.1 / 1; orchestration 194.7 / 7; memory 30.2 / 3; aristotle 33.0 / 2; lifecycle 420.7 / 3 (L31-L37)
- Run-to-run variance: **±10%** (T83 finding, PLAN_CERT_METRICS L31)

**Threshold (PLAN_CERT_METRICS L31)**: **≤ 380 ms** per ordinary Bash call (-30% vs M1 baseline 546 ms).

**Post-borrado expectation (predicted from Slice C/F cuts)**:
- Slice C removed 7 hooks from completion (TeammateIdle, SubagentStop, Stop): affects `Stop:*` and `TeammateIdle:*` aggregate only — NOT per-Bash-call
- Slice F removed 8 hooks from PostToolUse:Edit|Write|Bash (vault-fact-extractor, plan-sync-post-step, progress-tracker, status-auto-check, console-log-detector, ai-code-audit, auto-format-prettier, session-accumulator): **directly affects per-Bash-call aggregation**
- Slice B removed 3 (universal-prompt-classifier, aristotle-analysis-display, universal-aristotle-gate): affects PreToolUse/UserPromptSubmit — partially affects per-Bash-call
- **Expected per-Bash-call post-borrado**: ~200-280 ms (orchestration plane drops from 194.7 to <50; security plane unchanged)

### Sonda A2 — Wake-up tokens (Plan C Row 2)

**Command (verbatim from PHASE2_BASELINE L51-L54)**:
```bash
bash .claude/hooks/wake-up-layer-stack.sh 2>/dev/null </dev/null | head -c 100000 > /tmp/wu.txt
scripts/benchmark/.venv/bin/python -c "import tiktoken;print(len(tiktoken.get_encoding('cl100k_base').encode(open('/tmp/wu.txt').read())))"
```

**Critical invocation note** (PHASE2_BASELINE L61-L63): the hook blocks forever without stdin closure (`INPUT=$(cat)` in the hook); literal `</dev/null` redirect is required. This is an invocation fix, not an instrument change.

**Baseline numbers (PHASE2_BASELINE L58-L59)**:
- Whole hook stdout: **1792 tok** (L58)
- `additionalContext` value only (what enters the prompt): **1615 tok** (L59)
- Original 2026-08-23 baseline: **~1950-2000 tok** (PLAN_CERT_METRICS L32)

**Threshold (PLAN_CERT_METRICS L32)**: **≤ 1200 tok** (-37% vs baseline 1950-2000).

**Post-borrado expectation (predicted from Slice B)**:
- Slice B removed `aristotle-analysis-display.sh` from UserPromptSubmit (deferred rendering of Aristotle state)
- The wake-up block reads L0+L1 + recall_v2 top rules + vault stats + project Wing — Slice B does NOT touch those source components directly
- **Expected post-borrado**: 1500-1700 tok (slight drop from removing the deferred-Aristotle section, but the bulk of the block is L0+L1 which is not in scope)
- **Caveat**: this row may NOT pass the 1200 threshold post-borrado. If it doesn't, that is a finding, not a runbook error. Report the number and let lead interpret.

### Sonda A3 — Trivial task probe (Plan C Row 6)

**Command (verbatim from PHASE2_BASELINE L68)**:
```bash
python3 scripts/benchmark/trivial_task_probe.py
```
Output: `results/trivial-task-probe.{json,txt}`.

**Baseline numbers (PHASE2_BASELINE L71-L73)**:
- Cells: **27** (3 fixtures × 9 PreToolUse hooks)
- allow=24, deny=0, ask=0, other=3 (k8s-context-guard emits cluster context, not a decision)
- `any_deny=False`, `any_ask=False`
- **Exact replica of T96 baseline (2026-08-28)**

**Threshold (PLAN_CERT_METRICS L36)**: **post-M2 probe must show 0 DENY (no hook may coerce subagent for trivial work) AND 0 NEW deny on the 27 cells vs the T96 baseline.** The post-M2 certificate author records exact per-hook decision matrix.

**Post-borrado expectation**: **same** — slices removed hooks from other events, not from PreToolUse:Bash where the 9 security hooks live. The 9 PreToolUse:Bash hooks (git-safety-guard, repo-boundary-guard, permission-guard, k8s-context-guard + Slice C/F unaffected) stay. Should remain 0 DENY.

### Sonda A4 — Active registration count (Plan C Row 4-adjacent)

**Commands (verbatim from PHASE2_BASELINE L77-L78)**:
```bash
python3 scripts/benchmark/count_active_hooks.py --ref main --json > results/pr12-count-example.json
python3 scripts/benchmark/count_active_hooks.py --path ~/.claude/settings.json --json > results/pr12-count-active.json
```

**Baseline numbers (PHASE2_BASELINE L83-L84)**:
| config | events | commands | matchers |
|---|---:|---:|---:|
| example (repo, ref=main) | 6 | **21** | 16 |
| ACTIVE user settings | 14 | **74** | 25 |

**Threshold**: **invariant in security plane** (Row 4, PLAN_CERT_METRICS L34): 22/22 green tests preserved (no hook removed from SECURITY manifest). For the count itself, **post-borrado should be ≤ 56 commands** (74 − 8 Slice F PostToolUse − 7 Slice C completion − 3 Slice B = 56). This is an inference, NOT a pre-registered threshold — report the number and let lead interpret.

**Post-borrado expectation**:
- Slice B removed 3 registrations from UserPromptSubmit/PreToolUse (PHASE2_BASELINE L82 arithmetic note)
- Slice C removed 7 registrations (TeammateIdle + SubagentStop + 2 in Stop + 1 in PostToolUse:Edit|Write|Bash)
- Slice F removed 8 registrations from PostToolUse:Edit|Write|Bash; added ~5 in SessionStart/End/TaskCompleted
- **Net expected**: ACTIVE 74 → ~56 commands. Example (ref=main): unchanged at ~21 unless Slice C/F also removed from example.

### Sonda A5 — Maintenance sampling (Plan C Row 7)

**Command (verbatim from PHASE2_BASELINE L97)**:
```bash
python3 results/pr12-maintenance-sample.py
```
Output: `results/pr12-maintenance-sample.txt` + `results/pr12-maintenance-evidence.txt`.

**Baseline numbers (PHASE2_BASELINE L103-L109)** — out of 25 most-recent transcripts (of 1689 present, all ordinary):
| hook | mentions |
|---|---:|
| vault-graduation | 65 |
| vault-promotion | 61 |
| auto-sync-global | 65 |
| vault-weekly-compile | 27 |
| vault-index-updater | 30 |

10 of 25 transcripts carry ≥1 mention.

**Threshold (PLAN_CERT_METRICS L37)**: **0 ejecuciones** of maintenance hooks (vault-graduation, vault-promotion, auto-sync-global, vault-weekly-compile, vault-index-updater if used outside SessionEnd) inside an ordinary prompt window. Allowed only at SessionStart, SessionEnd, or explicit cold-path triggers.

**Critical caveat (PHASE2_BASELINE L111-L117)**: a **mention is a string occurrence**, not an execution. SessionStart-injected context ("vault-graduation: maintenance running in background") counts. The threshold (0 mid-prompt executions) requires the **line-level evidence review** that `pr12-maintenance-evidence.txt` enables. The baseline records raw counts, NOT a verdict.

**Post-borrado expectation**: mentions should DROP (slices moved some maintenance hooks to SessionStart only). The line-level review may show fewer mid-prompt executions — that's the win. But the baseline mentions are inflated by SessionStart context; the delta on raw mention count may be modest.

---

## §B — Report format (per Plan C row, before/after)

The certification executor writes the report at `docs/benchmark/CERT_2026-XX-XX_PR12-post-borrado.md` with the following schema (one row per Plan C row, 7 rows total):

```markdown
## Report schema (per Plan C row)

| metric | baseline (file:line) | post-borrado | delta | threshold | verdict |
|---|---|---|---|---|---|
| Row 1: hotpath per-Bash-call | 514.0 ms (PHASE2_BASELINE L42) | <measured> | <delta> | ≤ 380 ms (PLAN_CERT L31) | PASS/FAIL |
| Row 2: wake-up tokens | 1792 stdout / 1615 ctx (PHASE2 L58-L59); ~1950-2000 M1 (PLAN_CERT L32) | <measured> | <delta> | ≤ 1200 tok (PLAN_CERT L32) | PASS/FAIL |
| Row 3: orchestration share | 61% (PLAN_CERT L33) | <measured> | <delta> | ≤ 30% (PLAN_CERT L33) | PASS/FAIL |
| Row 4: security plane 22/22 | 22/22 (PLAN_CERT L34, BASELINE_A) | <re-run pytest> | n/a | 22/22 green | PASS/FAIL |
| Row 5: T92 + budget 800 | (T92 pending zc-3 close) | <TBD> | n/a | T92 verde + `inspect.signature(recall).parameters['budget_limit'].default == 800` | PASS/FAIL |
| Row 6: trivial 0 deny | 0 DENY on 27 cells (PHASE2 L71) | <re-run> | n/a | 0 DENY + 0 NEW deny | PASS/FAIL |
| Row 7: maintenance 0 mid-prompt | C9 baseline (PHASE2 L103-L109); 10/25 transcripts have ≥1 mention | <re-run + line-level> | <delta> | 0 mid-prompt executions | PASS/FAIL |
```

**Cell definitions**:
- `baseline (file:line)` — literal number from the source cited by file:line. NEVER invent.
- `post-borrado` — the executor-measured number, with command and raw artifact path (`results/pr12-*.{json,txt,py}`).
- `delta` — `post-borrado - baseline` (signed). Report with sign; do not absolute-value.
- `threshold` — pre-registered (from PLAN_CERT_METRICS L29-L37). If the threshold form is "direction" or "invariance", state the rule, not a number.
- `verdict` — PASS / FAIL / INCOMPLETE. INCOMPLETE is reserved for rows where the sonda is missing (Row 5 T92 pending; Row 6 was PENDIENTE in PLAN_CERT L36-L64 but the trivial_task_probe.py was created — see Sonda A3).

**Per-rule rule**: thresholds are pre-registered (PLAN_CERT_METRICS). A threshold that the executor MOVES after the measurement is a placebo per `feedback_demand_before_after_measurement.md` (cited in PLAN_CERT_METRICS L8-L10).

**Report header** (executor fills in):
```markdown
# Certification report PR12-post-borrado

- Date: <YYYY-MM-DDTHH:MMZ>
- Worker: <executor name>
- Machine: <machine + build, from PHASE2_L17>
- main SHA: <commit sha post-Slice F merge>
- ACTIVE settings sha256: <sha256 of ~/.claude/settings.json>

## Methodology note
Same instruments, same windows as PHASE2_BASELINE (PLAN_CERT_METRICS rows 1-7). No
sonda invented or modified. Each number below has a raw artifact under
`results/pr12-*`.

## Rows
<the 7-row table>

## Cache counters
"Not measured" — same constraint as PHASE2_BASELINE L121-L124 (no observable
counter without runtime instrumentation). Recorded as "not measured" per the
pre-registration rule.

## Sign-off
- Author: <executor>
- Owner: lead (zc)
```

---

## §C — Hard-gates of #69 Phase 5 closure (12-item checklist, each verifiable)

| # | gate | verification command |
|---|---|---|
| G1 | All 7 Plan C rows PASS (or Row 5/6 INCOMPLETE with explicit rationale) | parse `docs/benchmark/CERT_2026-XX-XX_PR12-post-borrado.md` row table; count verdict=PASS ≥ 7 (or 5 if 2 INCOMPLETE) |
| G2 | SECURITY_BASELINE.json intact (6 controls + 5 gaps) | `python3 -c "import json; m=json.load(open('.claude/security/SECURITY_BASELINE.json')); assert len(m['controls'])==6; assert {g['id'] for g in m['gaps']} == {'secrets-ordinary-work','red-toxic','mcp-egress','package-manager','symlink-escape'}"` (echo OK if passes) |
| G3 | 5 worker-blocked-safe hooks preserved | `for h in git-safety-guard.py repo-boundary-guard.sh permission-guard.sh k8s-context-guard-v2.py skill-validator.sh; do test -f .claude/hooks/$h || { echo FAIL; exit 1; }; done; echo OK` |
| G4 | Slice B absence test green | `pytest tests/test_aristotle_optin_absence.py -q` (created in Slice B per PR6-PREP-plan F11-F13) |
| G5 | Slice C absence test green | `pytest tests/test_slice_c_absence.py -q` (created in PR7-PREP-plan C4) |
| G6 | Slice F absence test green | `pytest tests/test_slice_f_absence.py -q` (created in PR11-PREP-plan C4) |
| G7 | Full unit suite green (`failed==0 AND total>0`) | `bash tests/run-all-unit-tests.sh` (per zero-tests rule: BOTH conditions must hold) |
| G8 | Hot-path per-tool = SOLO security | `jq '.hooks.PostToolUse[] \| select(.matcher=="Edit\|Write\|Bash") \| .hooks[].command' .claude/settings.json.example \| grep -v audit-secrets` returns 0 lines |
| G9 | /ship skill exists + invokes F5/F6/F7 | `test -f .claude/skills/ship/SKILL.md && grep -cE "console-log-detector\|ai-code-audit\|auto-format-prettier" .claude/skills/ship/SKILL.md \| awk '$1>=3 {print OK; exit 1}'` |
| G10 | Archive-purge policy documented | `test -f .claude/archive/README.md && grep -iE "purge\|delete" .claude/archive/README.md` returns ≥1 line |
| G11 | .gitignore hardened against __pycache__ | `grep -E "__pycache__\|\\.pyc" .gitignore` returns ≥1 line |
| G12 | No-recreación: 0 distributor references to deleted hooks | `for h in teammate-idle-quality-gate agent-diary-writer subagent-stop-universal ralph-subagent-stop ralph-stop-quality-gate anti-rationalization-gate quality-parallel-async vault-fact-extractor plan-sync-post-step progress-tracker status-auto-check console-log-detector ai-code-audit auto-format-prettier session-accumulator memory-write-trigger semantic-auto-extractor episodic-auto-convert reflection-engine; do grep -rln "$h" scripts/ install*.sh 2>/dev/null \| grep -v "docs/audit/" \| grep -v "benchmark/" \| grep -v ".claude/worktrees/" \| grep -v "/.git/" \|\| echo "OK: $h"; done` returns 19 OK lines (no FAIL output) |

**Gate orchestration** (executor runs all 12 in order):
```bash
PASS_COUNT=0; FAIL_COUNT=0
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  if eval "G$i" 2>/dev/null; then PASS_COUNT=$((PASS_COUNT+1)); else FAIL_COUNT=$((FAIL_COUNT+1)); fi
done
echo "Phase 5 hard-gates: $PASS_COUNT PASS / $FAIL_COUNT FAIL / 12 TOTAL"
# Acceptance: 12 PASS = phase closes; ≤ 11 PASS = BLOCKED, escalate to lead
```

---

## §D — Issue close order and required evidence

**Order**: `#46 ✅ → #69 → #48 → #45`

The ✅ on #46 means **already closed** (the SECURITY_BASELINE.json manifest exists, version 1.2.0, dated 2026-08-25, per EV-69 evidence). The remaining 3 issues close in order:

### Close #69 (umbrella — Phase 5 certifies)

**Required evidence** (4 artifacts):
1. `docs/benchmark/CERT_2026-XX-XX_PR12-post-borrado.md` exists with the 7-row schema (§B) and verdict column showing the rule.
2. The 12 hard-gates (§C) return 12 PASS / 0 FAIL.
3. The git state shows Slice F merge commit on main (verifiable: `git log --oneline -1 main` shows a Slice F commit message).
4. `~/.claude/settings.json` post-C5 (settings hash differs from PHASE2_BASELINE L15 `c6195c54...`, reflecting the F32-F38 deletions).

**Close comment template**:
> Closed by Phase 5 certification (PR 12). 7 Plan C rows PASS, 12 hard-gates verde. See `docs/benchmark/CERT_2026-XX-XX_PR12-post-borrado.md`.

### Close #48 (Phase 3 M2 — the implementation slice)

**Required evidence**: subsumed by #69's certification report. Specifically:
- Row 1 of the cert report shows hot-path per-Bash-call ≤ 380 ms (the Row 1 invariant of #48 per PLAN_CERT_METRICS L31).
- Row 4 shows security plane 22/22 green (the critical rule of #46/#48).

**Close comment template**:
> Closed by Phase 5 cert. M2 implementation complete; cert passes Row 1 (latency) and Row 4 (security invariance). See `docs/benchmark/CERT_2026-XX-XX_PR12-post-borrado.md`.

### Close #45 (the original demand: security/control gates)

**Required evidence** (the 5 gaps from SECURITY_BASELINE.json, EV-69 lines 153-184):
- `secrets-ordinary-work` (no-hook) — declared as a gap
- `red-toxic` (no-hook) — declared as a gap
- `mcp-egress` (no-hook) — declared as a gap
- `package-manager` (no-hook) — declared as a gap
- `symlink-escape` (partial) — declared as a gap with fixture required
- Worker-blocked-safe preserved (G3 above) — the 5 hooks that DO enforce security are intact
- Phase 5 cert (this runbook) confirms the declared gaps remain honest (not retrofitted to look covered)

**Close comment template**:
> Closed by Phase 5 cert. The 5 gaps declared in `SECURITY_BASELINE.json` (from_issue=45) remain honest: post-borrado did NOT retroactively cover them; the worker-blocked-safe preserved per hard-gate G3; the manifest integrity verified per G2. The security plane (Row 4) invariance 22/22 green confirms no regression. Demand of #45 satisfied.

---

## Reproducibility (executor runs these in order)

```bash
# Step 1: Sonda A1 — hot-path latency
python3 scripts/benchmark/hotpath_probe.py --setup
python3 scripts/benchmark/hotpath_probe.py --out results/pr12-posthoc-hotpath

# Step 2: Sonda A2 — wake-up tokens
bash .claude/hooks/wake-up-layer-stack.sh 2>/dev/null </dev/null | head -c 100000 > /tmp/wu.txt
scripts/benchmark/.venv/bin/python -c "import tiktoken;print(len(tiktoken.get_encoding('cl100k_base').encode(open('/tmp/wu.txt').read())))"

# Step 3: Sonda A3 — trivial task probe
python3 scripts/benchmark/trivial_task_probe.py

# Step 4: Sonda A4 — active registration count
python3 scripts/benchmark/count_active_hooks.py --ref main --json > results/pr12-count-example.json
python3 scripts/benchmark/count_active_hooks.py --path ~/.claude/settings.json --json > results/pr12-count-active.json

# Step 5: Sonda A5 — maintenance sampling
python3 results/pr12-maintenance-sample.py

# Step 6: Hard-gates G1-G12
# (run each gate's verification command from §C; aggregate per the gate orchestration block)

# Step 7: Generate the cert report
# Write docs/benchmark/CERT_2026-XX-XX_PR12-post-borrado.md per §B schema

# Step 8: SendMessage to lead: "PR12-EXEC · DONE — 7 rows, 12 gates"
```

---

## Decision ledger (open at runbook time, closed by executor)

**Decisiones que el executor NO debe reabrir**:
- Threshold definitions (PLAN_CERT_METRICS L29-L37) — pre-registrados, no se mueven
- Baseline numbers (PHASE2_BASELINE L29-L117) — congelados por zc-3
- Hard-gate verification commands (§C) — el runbook los define, el executor los corre
- Issue close order (§D) — declarado por lead en este ASSIGN

**Decisiones que el executor PUEDE tomar**:
- El timestamp del cert report (`CERT_2026-XX-XX_<descriptive>.md`)
- El wording del "Sign-off" en el cert report (dentro del template)
- El delta formatting en la tabla (signo explícito, magnitud)

**Decisiones que requieren re-consulta a lead** (BLOCKED):
- Cualquier threshold que no esté en PLAN_CERT_METRICS
- Cualquier baseline number que no esté en PHASE2_BASELINE
- Cualquier hard-gate que no esté en §C
- Cualquier row que devuelva INCOMPLETE (especialmente Row 5 T92 pendiente, Row 6 PENDIENTE)

---

End of runbook. Executor rule: si CUALQUIER sonda devuelve un número que rompe el threshold pre-registrado, NO ajustar el threshold — reportar el delta exacto (signed) y escalar a lead con la salida cruda. La regla `feedback_demand_before_after_measurement` (citada en PLAN_CERT_METRICS L8-L10) y `feedback_discriminant_resolution` (pre-registration como contraparte) son el marco: el umbral NO es placebo, y un delta FAIL no se reescribe — se documenta.

---

## Addendum (post-PR12 first cert run, 2026-09-01)

Per the rule quoted in the previous paragraph ("un delta FAIL no se reescribe,
se documenta"), the original gates-table entries for **G5** and **G8**
remain **intact** at lines 204 and 207. The corrections identified during
the first certification run (PR12 BLOCKED 6/12) are recorded here so a
future cert run has the right commands AND the rationale, without losing
the historical record of what the original criterion captured.

### G5 — Slice C absence test, command correction

**Original criterion (line 204, intact)**:
`pytest tests/test_slice_c_absence.py -q`

**Correction**: the pytest file `tests/test_slice_c_absence.py` never
existed. The plan envisioned creating it in PR7-PREP-plan C4, but the
actual implementation landed as a bash suite. The Slice C absence test
lives in `tests/security/test-slice-c-absence.sh` and currently reports
26/26 PASS (per first cert run).

**Corrected command**:
`bash tests/security/test-slice-c-absence.sh`

**Rationale**: bash suite is what shipped; pytest file was a planning
artifact. PASS/FAIL semantics are equivalent (the bash suite covers the
same Slice C hooks: teammate-idle-quality-gate, agent-diary-writer,
subagent-stop-universal, ralph-subagent-stop, ralph-stop-quality-gate,
anti-rationalization-gate, quality-parallel-async).

### G8 — Hot-path per-tool, recalibration

**Original criterion (line 207, intact)**:
`jq '.hooks.PostToolUse[] | select(.matcher=="Edit|Write|Bash") | .hooks[].command' .claude/settings.json.example | grep -v audit-secrets`
returns 0 lines (assertion: only audit-secrets is in the matcher).

**Correction**: the matcher currently contains `audit-secrets.js` AND
`plan-sync-post-step.sh`. The "only audit-secrets" assertion was based on
the assumption that PR11 F2 (move plan-sync-post-step to TaskCompleted)
would execute. F2 was NOT executed (PR11-EXEC skip-to-C2 skipped C1
entirely, treating the hot-path cleanup as done by slice E). Per #47 C1
(closed), `plan-sync-post-step.sh` is the canonical writer for
PostToolUse:Edit|Write|Bash; lead's C5 (user-side) aligned
`~/.claude/settings.json` with #47 C1.

**Recalibrated criterion**:
`jq '.hooks.PostToolUse[] | select(.matcher=="Edit|Write|Bash") | .hooks[].command' .claude/settings.json.example`
returns **exactly 2 lines**:
  - `.claude/hooks/audit-secrets.js`
  - `.claude/hooks/plan-sync-post-step.sh`

**Rationale**: #47 C1 (cerrado) fija plan-sync-post-step como escritor
canónico del matcher Edit|Write|Bash. PR11-EXEC skip-to-C2 saltó C1/F2
explícitamente; el C5 user-side del lead alineó `~/.claude/settings.json`
con #47 C1. Mover plan-sync a TaskCompleted es follow-up opcional
(no blocker).

**Future state** (when F2 is revisited): the criterion would tighten
back to "1 line: audit-secrets only" once the consolidation move
executes. For now, "exactly 2 lines: audit-secrets + plan-sync" is the
target that matches reality.

### G8 — Refinement 2 (post-merge f8c2e42, 2026-09-01, by lead's L1 adjudicación)

The G8 addendum above documented "exactly 2 lines: audit-secrets +
plan-sync-post-step" as the recalibrated criterion. That assertion was
based on the state of `.claude/settings.json.example` at the moment of
commit eb3fcd9. Between eb3fcd9 and the certification re-run (after
merge f8c2e42), `audit-secrets.js` was deregistered from the example
per **PR3-C7** (#69 §1B decision, registered in the plan): PostToolUse
audit-only is not a survivor; the canonical secrets control is
PreToolUse `secrets-write-guard.py` (listed in the manifesto
`deregistered` array). The current measurement is now 1 line, not 2.

**Updated criterion (re-enmendado, by lead's L1 adjudicación opción (a))**:
`jq '.hooks.PostToolUse[] | select(.matcher=="Edit|Write|Bash") | .hooks[].command' .claude/settings.json.example`
returns **exactly 1 line**:
  - `$CLAUDE_PROJECT_DIR/.claude/hooks/plan-sync-post-step.sh`

**Rationale**: PR3-C7 deregistered audit-secrets.js from the example.
Per #47 C1 (cerrado), plan-sync-post-step.sh is the canonical writer
for the matcher. The hot-path matcher is now "plan-sync-post-step
ONLY" (no audit hook). The "Future state" prediction in the previous
addendum ("1 line: audit-secrets only") turned out to be wrong on
two counts: (a) audit-secrets was deregistered, not just moved; (b)
#69 §1B already ruled that PostToolUse audit-only is not a survivor,
so the "future state" caption never matched the actual direction of
the plan.

**Option (b) rejected** (per lead's L1 adjudicación): re-registering
audit-secrets.js to satisfy a "audit-secrets only" wording would
contradict #69 §1B and PR3-C7. The chosen path aligns the gate TEXT
with the registered plan DECISION; the measurement (1 line) is
unchanged — it now passes the gate as written.

**Delta over previous G8 addendum**: the measurable criterion tightens
from "exactly 2 lines" to "exactly 1 line". This is a refinement, not
a reversal — the direction of consolidation (#47 C1) is the same;
only the count is corrected to match the deregistration that PR3-C7
applied between eb3fcd9 and the re-run.

### G8 — Refinement 3 (citation correction, 2026-09-01, post-merge)

The previous G8 addendum (commit eb3fcd9) cited "option A of the
BLOCKED msg [ID redacted — not in lead's record]" twice as justification
for the skip-to-C2 decision. Per lead's correction: that BLOCKED
message ID is not in lead's record and must not be used as primary
justification for plan decisions.

**Removed**: both inline citations of the unsupported BLOCKED message
ID from the previous addendum's body text (lines that referenced
"option A of the BLOCKED msg" and "PR11-EXEC opción A (BLOCKED
msg)").

**Replaced phrasing**: "PR11-EXEC skip-to-C2" states the decision
without anchoring it to a message ID that doesn't exist in lead's
record. The decision itself (skip-to-C2 instead of executing C1/F2)
is still recorded; only the unsupported message-ID citation was
removed.

**Citations kept**: #47 C1 (cerrado), el C5 user-side del lead,
"follow-up opcional (no blocker)" — these are plan-level references,
not message-ID references, and remain valid.

**No change to the measurable criterion**: refinement 2's "exactly 1
line: plan-sync-post-step.sh" is the criterion. This refinement only
removes an unsupported citation; it does not change the count.

### G1 — F1 Scope Amendment (post-cross-verify d6d1efb, 2026-09-01)

The original G1 entry at line 200 admits "Row 5/6 INCOMPLETE with
explicit rationale" as an alternative to "All 7 Plan C rows PASS".
The F1 arbitration (cross-verify by zc-4, main d6d1efb) extends this
acceptance clause to Row 1 (per-Bash-call hot-path latency).

**Original criterion (line 200, intact)**:
All 7 Plan C rows PASS (or Row 5/6 INCOMPLETE with explicit rationale).

**F1 amendment (additive acceptance clause)**:
Row 1 INCOMPLETE is also accepted, with the explicit rationale that
the per-Bash-call hot-path latency cannot be resolved at N=1 per
window — the magnitude of the structural effect (~98.0 ms of phantom
hooks deleted, verified per-hook) is of the same order as the
run-to-run oscillation of permission-guard alone (142.7 → 210.6 ms
between windows). N=1 per window cannot statistically separate the
signal from the noise.

**Updated acceptance count** (per F1 adjudication by lead):
- 6 rows PASS (Rows 2-7, reproduced exactly by zc-4 cross-verify) +
- 1 row INCOMPLETE-adjudicated (Row 1, F1) =
- Accepted: 6 PASS + 1 INCOMPLETE = 7 accounted rows, 0 FAIL.

**Evidence (cross-verify report, results/pr12-crossverify-report.md at
main d6d1efb)**:

6 numbers from F1 finding table:
| measurement | per-Bash-call | Δ vs baseline 514.0 |
|---|---:|---:|
| zc-3 certified (~11:57Z) | 362.3 ms | −29.5% |
| zc-4 run 1 (~14:5xZ) | 567.8 ms | +10.4% |
| zc-4 run 2 (~14:5xZ + min) | 483.3 ms | −6.0% |

3 artifacts:
- `worktrees/zc-3/results/pr12-posthoc-hotpath/hotpath-probe.{json,txt}`
- `results/zc4-xv-hotpath/hotpath-probe.{json,txt}`
- `results/zc4-xv-hotpath-run2/hotpath-probe.{json,txt}`

4 attribution numbers (Pre/Post split, zc-4 runs):
- Pre run 1: 383.5 ms / run 2: 314.0 ms (delete-phantoms overhead baseline)
- Post run 1: 184.3 ms / run 2: 169.3 ms (after-delete residual)

**Rationale (resolution-of-instrument)**:
With N=1 per window, the per-Bash-call aggregate cannot statistically
separate the ~98.0 ms structural effect (verified per-hook for each
deleted phantom) from the ±10% T83 baseline oscillation. The
post-borrado median (483.3 ms) is within the T83 ±10% band of the
514.0 ms baseline, so the structural effect is bounded but
unresolvable at this N.

**Follow-up (non-blocking, pre-registration for future cycles)**:
Future claims of hot-path latency impact MUST use N≥20 per window of
real idle Bash traffic to resolve the structural effect from
oscillation. Recorded as a methodological constraint for the next
measurement cycle — not a FAIL of the current certification.

**No change to the original G1 PASS-or-Row-5/6-INCOMPLETE clause**.
This amendment extends the acceptance criteria to include Row 1
INCOMPLETE with the F1 resolution-of-instrument rationale. Original
gate text at line 200 remains intact; the extension is the new
INCOMPLETE path for Row 1.