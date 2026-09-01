# PR12-RECERT report — post fix-row4 + fixes de mmx-3 (EXECUTOR REPORT)

- Date: 2026-09-01T12:34Z
- Worker: zc-3 · Runbook: mmx-3 con enmiendas G5/G8 documentadas (sección "amendments" del runbook)
- Tree: fix-row4 commit `0e0eb27` sobre main `f8c2e42` (fix-g12 de mmx-3 incluido)
- ACTIVE settings sha256: `00379887e357978f4519cf56300ac04e984cca915d21450c4191bfae0185d79d` (sin cambios desde el EXEC run)

## Conteo final: **row4 fixed + recert 11/12 PASS** (1 FAIL: G8, contradicción interna de la enmienda — ver L1)

## Fix-row4 (commit `0e0eb27`)
Verificación previa por gap (stop-gate de lead): los 5 statuses tienen respaldo registrado,
cada transición en su propio commit del plan #69 1B —
`control-declarado` ← d19b570 (PR3-C1 secrets write gate) · 198c759 (C2-IMPL red-toxic;
decisiones owner **R1 deny, R2/R3 ask** citadas en el mensaje) · 0f985fe (PR3-C3b mcp-egress) —
`resolved` ← 22f5388 (PR3-C4 package-manager ask tier) · 9aeb739 (PR3-C5 symlink-escape deny).
Cronología: enum nacido 2026-08-25 (4c26be5) con el manifiesto de nacimiento; transiciones el
2026-08-31; el enum nunca se actualizó. Enmienda con comentario citando las 5 referencias;
**negative-validated**: un status desconocido sigue FAIL (la aserción no se afloja, se registra
la evolución). Suites Row 4: **22/22**.

## Los 12 hard-gates (re-corridos en esta ventana, comandos enmendados donde mmx-3 los enmendó)

| # | gate | resultado | evidencia |
|---|---|---|---|
| G1 | 7 filas Plan C PASS | **PASS** — Row 4 verde tras fix-row4; las otras 6 PASS del EXEC run (mismo árbol de sondas, sin cambios de comportamiento) | `results/PR12-EXEC-report.md` + este recert |
| G2 | Manifiesto intacto (6 controls + 5 gaps) | **PASS** (exit 0) | comando verbatim |
| G3 | 5 hooks worker-blocked-safe | **PASS** (5/5) | test -f ×5 |
| G4 | Slice B absence | **PASS** (20 passed con G6) | pytest |
| G5 | Slice C absence (COMANDO ENMENDADO por mmx-3: suite bash) | **PASS** — 26/26 | `results/pr12-recert-g5.log` |
| G6 | Slice F absence | **PASS** | pytest |
| G7 | Full suite (failed==0 AND total>0) | **PASS** — 47/47 fresco | `results/pr12-recert-g7.log` |
| G8 | PostToolUse E\|W\|B del example (CRITERIO RECALIBRADO por mmx-3: exactamente 2 líneas) | **FAIL por letra** — medido **1 línea** (`plan-sync-post-step.sh`); la enmienda cuenta también `audit-secrets.js`, pero PR3-C7 lo desregistró del example (decisión REGISTRADA en el manifiesto, sección `deregistered`) | jq verbatim + `/tmp/g8-recal.txt` |
| G9 | /ship existe + 3 detectores | **PASS** (3 ≥ 3; fix de mmx-3) | grep -cE |
| G10 | archive-purge documentada | **PASS** (3 ≥ 1; fix de mmx-3) | grep -icE |
| G11 | .gitignore __pycache__ | **PASS** (2 ≥ 1) | grep -cE |
| G12 | 0 referencias distributor (19 hooks) | **PASS** — 19/19 OK (fix-g12 de mmx-3: 8 array entries + 2 comments podados en 3 distributors) | `results/pr12-recert-g12.log` |

## Ledger del recert

- **L1 (G8)**: la enmienda de mmx-3 y el manifiesto se contradicen: la enmienda espera
  `audit-secrets.js` registrado en el example; PR3-C7 lo desregistró de ahí Y del active
  settings por decisión registrada (#69 §1B: PostToolUse audit-only no es superviviente
  de seguridad; el control real del gap secrets-ordinary-work es el PreToolUse
  secrets-write-guard.py). La medición (1 línea) es MÁS estricta que el espíritu del gate
  (menos registros en el camino caliente, y el registro presente es el escritor canónico
  de #47 C1). Resolución propuesta para lead, dos opciones: (a) re-enmendar G8 a
  "exactamente 1 línea: plan-sync-post-step.sh" citando PR3-C7, o (b) re-registrar
  audit-secrets — lo que chocaría con #69 §1B y con el manifiesto. Ninguna la ejecuto yo
  (allowed paths).
- **L2 (G1)**: las 6 filas PASS del EXEC run se heredan sin re-sonda: el fix-row4 y los
  fixes de mmx-3 no tocan ningún camino medido por las sondas (solo enum de test, skill
  ship, README archive, filas de validadores). G7 re-verifica la suite completa fresca.
- **L3 (aceptación)**: el runbook exige 12/12 para cerrar; 11/12 queda BLOCKED por letra.
  El único FAIL es la contradicción documento-interna L1, no un defecto del árbol — la
  decisión de cierre es de lead.

## Sign-off
- Author: zc-3 (executor) — verificación previa por gap, enmienda con trazabilidad,
  negative-validation, umbral sin mover
- Owner: lead (zc) — pendiente: adjudicar L1 (G8) y el cierre de #69/#48/#45
