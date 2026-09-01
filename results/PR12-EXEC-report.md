# Certification report PR12-post-borrado (EXECUTOR REPORT — results/ copy)

- Date: 2026-09-01T11:57Z
- Worker: zc-3 (executor) · Runbook: mmx-3 (`results/PR12-PREP-runbook.md`, read-only)
- Machine: this laptop (macOS, Darwin 25.6.0) — same machine as PHASE2_BASELINE L17
- main SHA at measurement: worktree measured @ `a87bb0f`; main advanced to `847450e`
  (mmx-3 informe, docs-only) DURING the run — no hook/settings file touched by that commit
- ACTIVE settings sha256: `00379887e357978f4519cf56300ac04e984cca915d21450c4191bfae0185d79d`
  (PHASE2_BASELINE L15 was `c619c54...` — differs, reflecting the C5 deletions, as §D-#69 requires)

## Methodology note
Same instruments, same windows as PHASE2_BASELINE (PLAN_CERT_METRICS rows 1-7). No
sonda invented or modified. Every number below has a raw artifact under `results/pr12-*`.
Ghost-hook caveat (cross-checked with Sonda A4): the hotpath probe measures its fixed
baseline list; 5 of the PostToolUse hooks it measured (progress-tracker, status-auto-check,
console-log-detector, ai-code-audit, auto-format-prettier; sum 98.0 ms) are NO LONGER in
the ACTIVE settings — they run zero times in production. Both aggregations are reported.

## The 5 deltas (lead's done-when)

| # | sonda | baseline (file:line) | post-borrado | delta | raw artifact |
|---|---|---|---|---|---|
| D1 | hotpath per-Bash-call | 514.0 ms (PHASE2 L42) | **362.3 ms** same-instrument (PreToolUse 234.8 + PostToolUse 127.5); **264.2 ms** active-only | **-151.7 ms (-29.5%)** / -249.8 active-only | `results/pr12-posthoc-hotpath/hotpath-probe.{json,txt}` |
| D2 | wake-up tokens | 1792 stdout / 1615 ctx (PHASE2 L58-L59) | **1127 stdout / 971 ctx** | **-665 stdout / -644 ctx** | `/tmp/wu.txt` + venv tiktoken (transcript en §Rows) |
| D3 | orchestration+state share | 61 % (BASELINE_A L51, full-plane T82) | **12.8 %** active-only per-turn; 24.4 % con lifecycle; 36.4 % peor lectura (por-turno con fantasmas) | **-48.2 pts** (lectura activa); security domina en TODAS las lecturas (85.2 % / 41.6 % / 62.2 %) | derivado de D1 + A4 |
| D4 | active registrations | 74 commands (PHASE2 L84) | **44 commands** / 18 matchers / 10 events | **-30 commands** | `results/pr12-count-active.json` (+ example @ main: 21 → 15, `results/pr12-count-example.json`) |
| D5 | maintenance mentions | 248 raw / 10-of-25 transcripts (PHASE2 L103-L109) | **192 raw / 11-of-25 transcripts** | **-56 raw (-22.6 %)**; +1 transcript (ver ledger L7) | `results/pr12-maintenance-sample.txt` + `results/pr4-maintenance-evidence.txt` |
| — | CLAUDE.md scopes (instrumento 5, post-C5) | 6468 repo + 3343 global | **1195 + 1200 tok** (79/79 líneas) | repo -5273 / global -2143 | `uv run --with tiktoken …claude_md_tokens.py --gate 1200` → GATE PASS |

## Rows (Plan C, 7 filas — schema §B del runbook)

| metric | baseline (file:line) | post-borrado | delta | threshold | verdict |
|---|---|---|---|---|---|
| Row 1: hotpath per-Bash-call | 514.0 ms (PHASE2 L42); 546 M1 (PLAN_CERT L31) | 362.3 ms (264.2 active-only) | -151.7 | ≤ 380 ms (PLAN_CERT L31) | **PASS** |
| Row 2: wake-up tokens | 1792 stdout / 1615 ctx (PHASE2 L58-L59); ~1950-2000 M1 (PLAN_CERT L32) | 1127 stdout / 971 ctx | -665 / -644 | ≤ 1200 tok (PLAN_CERT L32) | **PASS** |
| Row 3: orchestration share | 61 % (PLAN_CERT L33; BASELINE_A L51) | 12.8 % active-only (36.4 % peor lectura) | -48.2 pts | orquestación deja de dominar: < share de security AND < 30 % | **PASS** (dirección; ver ledger L3) |
| Row 4: security plane 22/22 | 22/22 (PLAN_CERT L34, BASELINE_A) | **21/22** — `test_hooks_security_baseline.py::test_manifest_exists_nonempty_and_wellformed` FAIL | -1 | 22/22 green; any regression = automatic FAIL | **FAIL** |
| Row 5: T92 + budget 800 | T92 pending (PLAN_CERT L35) | probe `results/t92_c3_probe.py` EXIT=0 + `budget_limit` default **== 800** | n/a | T92 verde + default 800 (ba3b31a) | **PASS** |
| Row 6: trivial 0 deny | 0 DENY on 27 cells (PHASE2 L71) | **0 DENY / 0 ASK on 21 cells** (allow=18, other=3); 6 cells menos por hooks borrados | n/a | 0 DENY + 0 NEW deny | **PASS** |
| Row 7: maintenance 0 mid-prompt | 248 raw, 10/25 (PHASE2 L103-L109) | 192 raw, 11/25; line-level: 0 ejecuciones mid-prompt observadas (todo: SessionStart-injected / contexto / texto de usuario) | -56 raw | 0 mid-prompt executions | **PASS** |

**Rows: 6 PASS / 1 FAIL (Row 4).**

## Cache counters
Not measured — same constraint as PHASE2_BASELINE L121-L124 (no observable counter
without runtime instrumentation). Recorded per the pre-registration rule.

## Hard-gates (§C, corridos en orden, comandos verbatim)

| # | gate | resultado | evidencia |
|---|---|---|---|
| G1 | 7 filas PASS (o INCOMPLETE con rationale) | **6 PASS / 1 FAIL** — no cumple el conteo | esta tabla |
| G2 | SECURITY_BASELINE.json intacta (6 controls + 5 gaps) | **PASS** (exit 0; ids exactos) | comando §C |
| G3 | 5 hooks worker-blocked-safe | **PASS** (5/5 existen) | test -f ×5 |
| G4 | Slice B absence green | **PASS** | `pytest tests/test_aristotle_optin_absence.py` ✓ |
| G5 | Slice C absence green | **FAIL as-written**: `tests/test_slice_c_absence.py` NO EXISTE; intent-equivalente `tests/security/test-slice-c-absence.sh` → **26/26 PASS** (`results/pr12-g5-slice-c-bash.log`) | ver ledger L5 |
| G6 | Slice F absence green | **PASS** | `pytest tests/test_slice_f_absence.py` ✓ (20 passed con G4) |
| G7 | Full suite (failed==0 AND total>0) | **PASS** — 47/47 fresco, misma ventana | `results/pr12-g7-gate.log` |
| G8 | PostToolUse E\|W\|B del example = solo audit-secrets | **FAIL as-written**: 1 línea extra (`plan-sync-post-step.sh`) | jq verbatim §C |
| G9 | /ship existe + invoca F5/F6/F7 | **FAIL**: SKILL.md existe pero **0** referencias a los 3 detectores (gate: ≥3) | grep -cE |
| G10 | archive-purge policy documentada | **FAIL**: `.claude/archive/README.md` existe pero 0 líneas purge/delete (gate: ≥1) | grep -icE |
| G11 | .gitignore contra __pycache__ | **PASS** (2 líneas) | grep -cE |
| G12 | 0 referencias distributor a 19 hooks borrados | **FAIL**: 16 OK / 3 REFERENCED — progress-tracker y status-auto-check en `validate-hooks-{registration,execution}.sh`; ai-code-audit en `check-gnu-only-commands.sh` (filas stale de listas, no re-creaciones funcionales) | `results/pr12-g12.log` |

**Hard-gates: 6 PASS / 5 FAIL / 1 derivado (G1) — aceptación del runbook: 12 PASS cierra;
≤11 = BLOCKED. → CERTIFICATION BLOCKED.**

## Decision ledger (deltas FAIL y ambigüedades — nada reescrito)

- **L1 (Row 4 / G2-adyacente)**: `test_manifest_exists_nonempty_and_wellformed` falla porque
  `VALID_GAP_STATUS = {"no-hook","partial"}` (test L38) y el manifiesto hoy usa
  `control-declarado` ×3 (secrets-ordinary-work, red-toxic, mcp-egress) y `resolved` ×2
  (package-manager, symlink-escape). El test aborta en el PRIMER gap ofensor (red-toxic):
  las 5 entradas están fuera del enum, no solo una. El manifiesto derivó de sus statuses
  registrados; G2 (que solo mira controls/gap-ids) pasa. No arreglado por el executor
  (allowed paths: results/). Arreglo candidato para lead: restaurar los statuses al enum
  del test o enmendar el test con justificación — decisión de lead, no mía.
- **L2 (G8)**: el example @ main aún registra `plan-sync-post-step.sh` en
  PostToolUse:Edit|Write|Bash y el ACTIVE settings lo confirma (A4). La predicción del
  runbook ("Slice F lo removió") no se realizó — PR11-EXEC C3 borró solo 2 tracked files.
  El gate refleja la realidad: FAIL.
- **L3 (Row 3)**: el 61 % pre-registrado viene del método full-plane T82/BASELINE_A
  (incluye SessionStart backgrounded), no reproducible post-borrado sin re-derivar ese
  costo (la sonda no existe como script). Veredicto PASS en forma dirección: security
  domina en las 3 lecturas (85.2/41.6/62.2 % vs orch 12.8/36.4/24.4 %). La lectura
  por-turno-con-fantasmas (36.4 % > 30 %) queda registrada como la peor caso.
- **L4 (D1)**: las dos agregaciones conviven: 362.3 ms mismo-instrumento (con 98.0 ms de
  fantasmas que en producción no corren) y 264.2 ms active-only. Ambas ≤ 380.
- **L5 (G5)**: el runbook cita un path pytest que PR7-EXEC nunca creó (la suite vive como
  bash `tests/security/test-slice-c-absence.sh`, 26/26). FAIL as-written + equivalente
  verde; enmendar el comando del runbook es decisión de lead/mmx-3.
- **L6 (G9/G10)**: `/ship` existe sin los 3 detectores; `.claude/archive/README.md`
  existe sin política purge/delete (PR11-EXEC C2 declaró "archive-purge policy" — el
  documento que el gate espera no está en ese fichero).
- **L7 (D5)**: raw mentions -56 pero transcripts con mención 10→11 (+1): los transcripts
  nuevos son sesiones post-borrado donde las menciones son inyecciones SessionStart
  (permitidas) — el threshold es 0 EJECUCIONES mid-prompt y el line-level no encontró
  ninguna; el +1 es ruido de ventana, no ejecución.
- **L8 (Row 5)**: el runbook decía "T92 pending zc-3 close" — la sonda existe
  (`results/t92_c3_probe.py`) y pasa; el estado del runbook estaba stale. PASS sin
  reabrir nada.
- **L9 (ventana)**: main avanzó a `847450e` (informe docs-only de mmx-3) durante la
  medición; todas las sondas corrieron contra el árbol `a87bb0f`. Ningún fichero medido
  cambió en ese commit.

## Sign-off
- Author: zc-3 (executor) — umbral no tocado, delta FAIL documentado, no arreglado
- Owner: lead (zc) — decisión de cierre #69/#48/#45 pendiente de este reporte
- Conteo: **5 deltas medidos · 6/7 rows PASS (1 FAIL Row 4) · 6/12 hard-gates PASS (5 FAIL) → BLOCKED per runbook acceptance**
