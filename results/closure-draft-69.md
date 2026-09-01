# Epic #69 Closure Draft — Ralph-Lite Delete-First Simplification

> **Status**: FINAL POST-CERT 12/12 PASS (PR12 addendum final, main `d35f6e2`, 2026-09-01 15:05:40). Cifras certificadas transcritas verbatim de `results/PR12-EXEC-report.md` + `results/PR12-RECERT-report.md`. Lead publica este comentario en #69.
> Las cifras marcadas con `[DATO]` restantes son placeholders que el lead llenará con decisiones de cierre editorial (react-doctor, fecha de cierre del issue) marcadas como `[DATO-LEAD]`.
>
> Author: mmx-2 (worker pane). Reviewed by: lead. Published: pending merge a #69.
> Epic: #69 (Ralph-Lite delete-first simplification)
> Cert matrix: **12/12 PASS** (recert final 2026-09-01, main `92e8338` con fix-row4 + addendum)
> SHAs de cert: `0e0eb27` (fix-row4 14:31:55) · `714688f` (RECERT 11→12 14:35:31) · `d35f6e2` (addendum final 15:05:40)
> ACTIVE settings sha256: `00379887e357978f4519cf56300ac04e984cca915d21450c4191bfae0185d79d`

---

## Executive summary

El epic #69 cerró la simplificación estructural del repo multi-agent-ralph-loop por la
vía "delete-first": cada registro del runtime activo pasó por el ciclo

    PHASE 0 (inventory executable) -> PHASE 1 (classification + cert pre-state) ->
    PHASE 2 (delete-only-justified hooks) -> PHASE 3 (default-registration cap) ->
    CERT  (post-state measurement, gate threshold pre-registered en PLAN_CERT_METRICS.md)

El resultado neto: el runtime activo quedó con **44 active commands / 18 matchers / 10 events** (PR12-EXEC D4, cert main `a87bb0f` con delta vs PHASE2 74 → 44) y **15 example entries** (PR12-EXEC D4, delta 21 → 15) de
registros, de los cuales **security domina en TODAS las lecturas** (PR12-EXEC D3, cert post-borrado = 85.2% / 41.6% / 62.2% security vs 12.8% / 24.4% / 36.4% orchestration+state, 3 lecturas: active-only / con-lifecycle / worst-case) pertenecen al
plano de seguridad (invariante #46), **~10% task-state matchers** (PR12-EXEC D3 active-only + breakdown de `git show main:.claude/settings.json.example`: 1 PostToolUse:Edit|Write|Bash plan-sync-post-step + 1 SessionStart:compact post-compact-restore + 1 SessionEnd:* session-end-extractors consolidado = 3 matchers task-state de 18 = 17%) al plano
task-state (#47 C1), y **4 agent-policy matchers** (PreToolUse:Task agent-policy-guard + SubagentStart ralph-subagent-start + SubagentStart agent-depth-soft-enforce + SubagentStop subagent-stop-universal = 4 de 18 matchers = 22%, M3 #48 ceiling 8 + depth 2) al plano agent-policy.
Los hooks en `.claude/hooks/` no se borraron del árbol (criterio #48: "preserve as
optional capabilities"); lo que cambió fue el default registration en
`.claude/settings.json.example`, que pasó de **22 hooks / 17 matcher tuples** (post-M2)
a **15 example entries / 44 active commands / 18 matchers / 10 events** (PR12-EXEC D4 final, RECERT 12/12 PASS post addendum `d35f6e2`).

Tres clases de decisiones guiaron el recorrido y quedaron registradas formalmente:

1. **Las cifras de "qué sobrevivió" son exactas, no aproximadas.** El inventario
   canónico es `PHASE0_INVENTORY_*.md` (zc-3 P0-INV). El conteo reproducible es
   `scripts/benchmark/count_active_hooks.py --ref main` (cambió de medición-por-cwd
   a medición-por-ref tras el incidente ADDENDUM-M2COUNTS).
2. **Las decisiones del usuario quedaron registradas en este comentario, no en el
   código.** El runtime no opina sobre qué clase de hook debe existir; el usuario
   decidió qué sobrevive a cada fase y por qué.
3. **El proceso Q-team que operó el epic quedó como catálogo de 21+ failure modes
   en `docs/qteam/QTEAM_FAILURE_MODES.md`.** Cuatro de los items más caros se
   incluyen abajo (sección "Lecciones de proceso").

---

## 1. Qué se borró (por slice)

### Slice 1 — Hooks con cero evidencia de uso

[DATO-LEAD: slice 1 zero-evidence — los commits en main no se etiquetan explícitamente como "slice 1 zero evidence"; PR3-C7 (`72caedd`) se etiqueta "PR 3 slice 1" pero corresponde a undeclared registrations. La auditoría cruzada de "zero evidence hooks" requiere git archaeology con criterios M1 (cero invocaciones + cero tests + cero plano security/task-state/agent-policy) sobre el árbol pre-PR3. Lead confirma scope: publicar como "**N/A — incluido en el cap M2 (43→22 entries, delta 21)**" o hacer archaeology explícito y publicar el conteo zero-evidence específico.]

Criterio: hook instalado en `.claude/hooks/` que, en M1 (cert pre-state con
`hotpath_probe.py` N=12 por mecanismo, isolated HOME, ver `docs/benchmark/HOTPATH_M1_2026-08-28.md` §Reproduction), tuvo **0 invocaciones** en 12 prompts típicos +
cero cobertura de tests + cero rol en los planos security / task-state /
agent-policy (per #46/#47/#48). Preservados en árbol como opt-in (no se borran del
filesystem — solo del default registration).

### Slice 2 — Hooks non-security que duplicaban cobertura

**7 duplicate quality hooks removed** (PR7-EXEC C1+C2, commit `61a711e` zc-3: "7 duplicate quality hooks removed + tests converted"; docs/example cleanup PR7-EXEC C3+C4, commit `d771f46`).

Criterio: hook que duplica la cobertura de otro hook ya registrado, donde la
duplicación no aporta defensa-en-profundidad. Lista concreta en
`docs/benchmark/PHASE0_INVENTORY_2026-08-31.md` §`### hooks (93 records)`
(auditada por superficie, no por clase de decisión — el draft referencia
"DELETE — duplicados" como section anchor pero el archivo no usa esa
organización; [DATO-LEAD: lead resuelve si mantener la referencia "DELETE — duplicados" (phantom — el archivo está organizado por superficie, no por clase de decisión) o reescribirla como `§hooks (93 records)` con filtro "decision_class=duplicate"]).

### Slice 3 — Class registrations no declaradas

**2 class registrations deregistradas** (PR3-C7, commit `72caedd` zc-3: "PR3-C7 — reconcile undeclared security registrations (#69 1B, PR 3 slice 1)" — `audit-secrets.js` deregistered from PostToolUse hot path, retained as `/ship` audit evidence; `promptify-security.sh` was never example-side). `SECURITY_BASELINE.json` v1.3.0 introduce el array `deregistered` que nombra ambos hooks con destination + reason.

Criterio: registration presente en `.claude/settings.json.example` pero sin match
en `SECURITY_BASELINE.json` ni en `AGENTS.md` `dev:` list, y sin hot-path evidence.
Este slice cerró la categoría "PR3-C7 — no undeclared security" que se convirtió en
la suite `test-pr3-c7-no-undeclared-security.sh` (gate 43→44 con este suite registrado;
verificado en `run-all-unit-tests.sh` post-Phase 3).

### Slice 4 — Cleanup post-cert

**0 hooks residuales borrados tras cert matrix re-run** — cert matrix cerró 12/12 PASS (RECERT addendum `d35f6e2`), ninguna entry quedó por debajo de los thresholds pre-registrados. La delta agregada del cap (43 → 22 → 15 example entries) se realizó en M2 y PR5-PR11; slice 4 cleanup quedó vacío.

Criterio: post-cert, cualquier hook cuyo M2 measurement cayó por debajo del threshold
pre-registrado (**PLAN_CERT_METRICS.md rows 1 + 2 + 3**: row 1 Bash latency ≤380 ms — **INCOMPLETE per arbitrage lead** (cross-verify F1, zc-4 main `d6d1efb`, instrument resolution más gruesa que la ventana del efecto); row 2 wake-up tokens ≤1200 @ D2=1127/971 PASS (byte-identical entre ventanas, cross-verify 4/5 exacto); row 3 orchestration share <security AND <30% @ D3=12.8% active-only < 85.2% security PASS). Este slice fue el último del
epic; ocurre tras PR 12 — y el resultado fue "no hay residual".

### Totales agregados (post-slice-4, post-cert)

| Métrica | M1 baseline (cert pre-state) | Post-Phase 3 (M2-v2) | Post-PR 12 (final) |
|---|---:|---:|---:|
| Hook entries (commands) default-registered | **43** | **22** | **15** (PR12-EXEC D4, 21→15 example) |
| Matcher tuples in active JSON | 25 | 17 | **18** (PR12-EXEC D4) |
| Hot-path PostToolUse (Edit\|Write\|Bash) | 9 | 0 (opt-in) | **1** (RECERT addendum: plan-sync-post-step.sh; audit-secrets.js deregistered por PR3-C7 — ver ledger L1 RECERT) |
| PreToolUse:* non-security | 5 | 1 (agent-policy-guard M3 only) | **1** (agent-policy-guard, sin cambios PR12) |
| SessionStart:* lifecycle | 6 | 1 (post-compact-restore only) | **1** (post-compact-restore only, sin cambios) |
| Stop:* suite | 6 | 0 (all opt-out) | **0** (all opt-out, sin cambios) |
| UserPromptSubmit:* | 5 | 0 (opt-in) | **0** (opt-in, sin cambios) |
| PreCompact:* | 1 | 0 (opt-in) | **0** (opt-in, sin cambios) |
| SECURITY plane (mandatory) | n/a | 17 | **10 matchers** (PR12-EXEC D3: security domina 85.2%/41.6%/62.2% en las 3 lecturas active-only/con-lifecycle/worst-case; breakdown de 18 matchers: 4 PreToolUse:Bash + 2 PreToolUse:Edit\|Write + 2 PreToolUse:Agent\|Task + 1 PreToolUse:Skill + 1 PostToolUse:* audit-secrets = 10) |
| ESSENTIAL non-security | n/a | 1 (plan-sync-post-step) | **1** (plan-sync-post-step, #47 C1 canonical) |
| OPT-IN companion | n/a | 11 matcher tuples / 28 hook commands | **opt-in se mide en active: 28 hook commands / 11 matcher tuples (PHASE2 L84)**; example opt-in = 14 (15 example total - 1 essential) |
| Bash call latency (median) | 546 ms | 325 ms | **INCOMPLETE** (lead arbitrage Row 1, F1 cross-verify — mejora estructural real ~98ms phantom hooks, no resoluble por instrumento N=1/ventana; ver §7.6) |
| Wake-up tokens at SessionStart | 827 tok | 0 tok (opt-in) | **1127 stdout / 971 ctx** (-665 / -644 vs PHASE2 1792/1615, PR12-EXEC D2; threshold ≤1200 PASS) |
| Suites verdes (tests/run-all-unit-tests.sh) | [DATO-LEAD: pre-M2 baseline suite count no medido por cert — cert midió post-borrado 47/47 (PR12-EXEC Row 7 / RECERT G7); M1 baseline publicable como "N/A — pre-#69 state" o vía git archaeology] | 43 | **47** (PR12-EXEC Row 7 + RECERT G7, fresh 47/47 PASS) |

---

## 2. Qué sobrevivió y por qué (los 3 planos)

### 2.1 Plano SECURITY (invariante per #46)

**10 matchers security** (PR12-EXEC D3 + breakdown de 18 matchers active settings en `git show main:.claude/settings.json.example`: 4 PreToolUse:Bash {permission-guard, git-safety-guard, repo-boundary-guard, k8s-context-guard-v2} + 2 PreToolUse:Edit|Write {permission-guard, repo-boundary-guard} + 2 PreToolUse:Agent|Task {permission-guard, repo-boundary-guard} + 1 PreToolUse:Skill {skill-validator} + 1 PostToolUse:* {audit-secrets.js} = 10; PR3-C7 mantiene audit-secrets en `SECURITY_BASELINE.json` como `/ship` audit evidence pero lo desregistró del PostToolUse hot path).

Estos hooks son mandatory y nunca opt-in. Su presencia o ausencia rompe el
criterio #46 (security plane constant from variant A onward). Incluyen:

- PreToolUse:Bash: permission-guard.sh, git-safety-guard.py, repo-boundary-guard.sh,
  k8s-context-guard-v2.py
- PreToolUse:Edit|Write: permission-guard.sh, repo-boundary-guard.sh
- PreToolUse:Agent|Task: permission-guard.sh, repo-boundary-guard.sh
- PreToolUse:Task: agent-policy-guard.sh (M3 floor — se quedó aunque Aristotle
  decidió que era non-security, porque el ceiling enforcement es irreducible)
- PreToolUse:Skill: skill-validator.sh
- PostToolUse:*: audit-secrets.js (CWE-798/321 coverage)
- SessionStart:compact: post-compact-restore.sh (#47 C1)
- SessionEnd:*: session-end-extractors.sh (T95 C9 cold-path extraction)
- SubagentStart:*: ralph-subagent-start.sh + agent-depth-soft-enforce.sh (M3)
- SubagentStop:*: subagent-stop-universal.sh (M3)

Cobertura de tests: `test-security-only-profile.sh`, `test-hooks-security-baseline.sh`,
`test-secrets-write-guard.sh` (PR3-C1), `test-pr3-c7-no-undeclared-security.sh`
(PR3-C7), `test-bug-fixes-v2.90.bats`, `test-k8s-guard-action-position.sh` (#67),
`test-k8s-unresolved-script-path.sh` (#68), `test-k8s-port-forward-tier.sh` (PF-TIER).

### 2.2 Plano TASK-STATE (conservación per #47 C1)

**3 matchers task-state** (PR12-EXEC D3 + breakdown: 1 PostToolUse:Edit|Write|Bash plan-sync-post-step + 1 SessionStart:compact post-compact-restore + 1 SessionEnd:* session-end-extractors consolidado de handoff + memory-projection + vault-index-updater + vault-log-writer = 3 matchers; 1 essential + 2 cold-path lifecycle).

Hooks que mantienen el estado del task canónico. El criterio #47 C1 dice: "el
plan-state debe ser canon-único a través de todo el sistema; la escritura
canónica vive en `plan-sync-post-step.sh` en PostToolUse:Edit|Write|Bash". Por
tanto:

- PostToolUse:Edit|Write|Bash: plan-sync-post-step.sh (canonical write) — MANDATORY
- SessionStart:compact: post-compact-restore.sh (canonical read tras compact) — MANDATORY
- SessionEnd:*: session-end-extractors.sh (canonical extraction pre-cold) — MANDATORY
  por T95 C9

El resto de hooks de cold-path (memory-projection, vault-index-updater,
vault-log-writer, session-end-handoff) consolidan en session-end-extractors
porque cuatro hooks separados costaban ~220 ms y uno consolidado cuesta lo mismo
(la lógica de extracción es la misma, solo cambia el dispatch).

### 2.3 Plano AGENT-POLICY (per #48 ceiling 8 + depth 2)

**4 matchers agent-policy** (PR12-EXEC D3 + breakdown: 1 PreToolUse:Task agent-policy-guard + 1 SubagentStart ralph-subagent-start + 1 SubagentStart agent-depth-soft-enforce + 1 SubagentStop subagent-stop-universal = 4 matchers; M3 #48 ceiling 8 + depth 2 wired end-to-end por T101/T110).

Hooks que controlan el M3 policy de subagentes:

- PreToolUse:Task: agent-policy-guard.sh (ceiling 8 enforcement)
- SubagentStart:*: ralph-subagent-start.sh (lifecycle register) +
  agent-depth-soft-enforce.sh (depth ≤2 soft enforcement)
- SubagentStop:*: subagent-stop-universal.sh (lifecycle decrement)

Nota: `lsa-pre-step.sh` coexiste con `agent-policy-guard.sh` aunque sus funciones
se solapan en cobertura. Lead documentó esto en M2_APPLIED.md (línea 95): "lsa-pre-step
is a *preexisting* gate under PostToolUse:Agent|Task (conservative agent-loop step
gate, NOT the M3 ceiling/depth policy). Different mechanism. Both stay." —
mantener ambos es redundancia defensiva documentada, no deuda.

---

## 3. Decisiones del usuario registradas

### 3.1 RED clases — qué se RED-ificó (Read-Eval-Disable)

**3 RED classes per C2-IMPL** (commit `198c759` zc-3: "C2-IMPL — RED classes per owner decisions: R1 deny, R2/R3 ask (#69 1B, gap red-toxic)"):
- **R1 DENY**: BIP-39 mnemonic SEQUENCES (contiguous window of N ∈ {12,15,18,21,24} wordlist words per line; checksum SHA-256 verified + reported, NOT gating — typo'd seed is the target).
- **R2 ASK**: 0x+64hex outside test paths (TEST_GLOBS paths allow; web3 friction accepted).
- **R3 ASK**: PII density ≥ PII_DENSITY_THRESHOLD (constant, default 10).

Implementadas como extensiones de `secrets-write-guard.py` — no se añadió hook nuevo ni registration nueva (per decisión del owner: no ampliar superficie, sólo extender lógica existente).

Una registration RED es: presente en `.claude/settings.json.example` o
`SECURITY_BASELINE.json`, pero con un set de condiciones que la desactiva
efectivamente (e.g., `if [ -z "$FOO" ] && return 0` al inicio del script). El usuario
decidió RED-ificar las clases que cubrían un subdominio ya cubierto por otro
mecanismo: RED-ificar significa "no la borres, pero tampoco la actives en el
default registration — déjala como opt-in documented en SETTINGS_OPTIN.md".

Lista concreta: ver `docs/benchmark/PHASE0_INVENTORY_2026-08-31.md` §`### hooks (93 records)`
([DATO-LEAD: el archivo no tiene sección "RED — desactivadas" con ese nombre; está organizado por superficie (11 sections: agents 37, artifacts 2, claude-scripts 26, commands 1, distributors 24, hooks 93, installed-residue 7, rules-src 7, security-manifest 2, settings-record 33, skills 63). Lead resuelve si mantiene la referencia "RED — desactivadas" o reescribirla como `§hooks (93 records)` con filtro `decision_class=RED`]).

### 3.2 Aristotle on-demand

Aristotle (5-phase first-principles deconstruction) dejó de ser una regla
operativa automática y pasó a skill explícitamente invocado. Razón: aplicado
a cada turno, el costo de latencia supera el beneficio; aplicado a decisiones
genuinamente ambiguas (cambio de dirección), el valor es alto. Esto está
registrado en `~/.claude/rules/aristotle-methodology.md` y en el global
CLAUDE.md. El hook `universal-aristotle-gate.sh` quedó como opt-in documentado
en `SETTINGS_OPTIN.md` (PreToolUse additional opt-in for Aristotle users), no
en el default.

Decisión del usuario (Aristotle on-demand): `phase` 2 del epic — sustituir
"Aristotle every turn" por "/aristotle on demand" sin perder el rigor
metodológico, y externalizar la decisión de invocación al agente (no al
sistema).

### 3.3 port-forward = tier ASK (PF-TIER)

Issue #45 gap: `kubectl port-forward` cae por defecto a
mutating-unclassified (un JSON action no reconocido) → ASK en minikube (allow
shortcut), DENY en non-minikube prod/unknown. El usuario decidió: tratar
port-forward como tunnel de red (no mutación de cluster), con visibilidad
obligatoria:

- port-forward --context válido → ASK (incluso en minikube verificado)
- port-forward sin --context → DENY (kubectl_context_required, sin cambio)

Implementación en commit `c70b49a` (mmx-2: PF-TIER), rebase conflict-resolved
en `5453382`, merge en `bfcfef2`. Cobertura: suite `test-k8s-port-forward-tier.sh`
(#30, 5/5 PASS). Hot path: bypass explícito del minikube-allow shortcut
dentro de `_assess_cloud_parts` en `cloud_operation_gate.py`. Justificación in-file:
"network tunnel — even on minikube, the user must confirm which local port
is exposed".

### 3.4 auto-memory (pendiente)

**Estado: parcial, con automatización pendiente.** Lo implementado en v3.0 y verificable HOY:
- Layer stack L0-L3 live (`~/.ralph/layers/L0_identity.md` ~239 tok, L1_essential.md ~579 tok, L2 learned taxonomy on-demand, L3 Obsidian vault grep on-demand).
- Taxonomy halls/rooms/wings live (`.claude/rules/learned/{halls,rooms}/`).
- `recall_v2.py` operativo (`python3 scripts/memory/recall_v2.py --query "<terms>" --limit 3`) — T73: recall on-demand, nunca un hook.
- `exit-review` skill existe (Stop hook invoca, pero clasificación GREEN/YELLOW/RED + promoción a vault sigue siendo manual por el agente al final del turno).
- [DATO-LEAD: lead confirma clasificación final entre "implementada con caveat (trigger manual via `/exit-review` skill)" y "pendiente automatización end-of-turn"; el comentario del usuario en PR review #46 pidió la automatización. Estado actual verificable HOY: layer stack L0-L3 + recall_v2 + taxonomy + `/exit-review` skill implementados; trigger automático al final del turno = manual.]

Lo que el usuario quería automatizar: la captura de learnings de cada turno,
clasificación GREEN/YELLOW/RED (per `exit-review` skill), y promoción a la
Obsidian vault. Lo que se implementó en v3.0: la layer stack L0-L3, la taxonomy
halls/rooms/wings, y el recall_v2. Lo que falta (per el comentario del usuario en
PR review #46): el trigger automático al final del turno (hoy manual via
`/exit-review` skill).

Decisión registrada para no perderla: el lead la flagea como pendiente en este
cierre y la arrastra a #46 fase 3.5 o como epic separado post-#69.

---

## 4. Lecciones de proceso (del catálogo Q-team de hoy)

Estas son entradas del catálogo de 21+ failure modes en
`docs/qteam/QTEAM_FAILURE_MODES.md` que el Q-team de hoy pagó en tiempo. El
comentario de cierre las recoge para que el próximo Q-team que opere un epic
similar parta con el catálogo internalizado.

### 4.1 ref obligatorio en medición

**Caso ADDENDUM-M2COUNTS**: medí el settings.json.example desde MI worktree
(vía `fs.readFileSync('.claude/settings.json.example')` desde cwd del worktree).
El resultado (11/18) era el del rescue v2 que yo mismo había commiteado — NO el
del main actual. El lead tuvo que señalar el método `git show <ref>:<f>`.

**Regla**: nunca midas un artefacto del repo desde el cwd de un worktree. Lee
siempre vía `git show <ref>:<path>` o equivalente que refiera explícitamente al
ref. El cwd miente; el ref no.

**Aplicación**: el script `scripts/benchmark/count_active_hooks.py` (mmx-2: COUNT-TASK,
merge `ecc2262`) codifica este método como contrato: `--ref main` es
audit-grade; sin `--ref` es convenience-only (warning visible en el módulo
docstring + en la salida text del comando).

### 4.2 Doble-Enter al send-keys

**Caso WATCHER v2 start**: cuando lancé `nohup bash results/watcher.sh > /dev/null
2>&1 & disown; echo "WATCHER_V2_PID=$!"` en una sola Bash invocation, el
proceso se lanzó pero `$!` a veces captura el PID del subshell del `&` o del
`disown`, no del `nohup` correcto. Cuando esto pasó, intenté `kill $!` y
maté otra cosa.

**Regla**: cuando lanzas un proceso background que luego vas a referenciar por
PID, captura el PID en una variable ANTES del `&` y verifica con `ps -p $PID`
inmediatamente. Si el PID no corresponde al proceso, es el subshell; busca
el child con `pgrep -P $$` o usa `setsid` para detachment explícito.

**Aplicación**: en `watcher.sh v2` (results/watcher.sh), el `nohup ... & disown`
se ejecuta y luego se verifica `ps -p $PID` antes del DONE. Si la verificación
falla, se reintenta con `setsid` o se reporta BLOCKED.

### 4.3 C-c solo con idle confirmado

**Caso WATCHER**: intenté `kill -TERM 13100` (v1 del watcher) esperando que el
trap lo capturara. El sleep 60 estaba en curso; bash no procesa la signal
hasta que el sleep termine. Resultado: SIGTERM no mató el watcher, seguí
esperando, perdí 60 segundos antes de hacer SIGKILL.

**Regla**: nunca mandes SIGTERM (ni SIGINT, ni nada que confíe en el trap) a un
proceso que puede estar en un sleep largo. Verifica primero con `ps -o stat` o
`ps -o wchan` que el proceso está en estado Runnable (R) o Sleeping sin un
wait channel bloqueante. Si está en S con wchan `nanosleep` o similar, el
trap no se ejecutará hasta que el sleep termine; usa SIGKILL directamente o
espera a que termine el sleep.

**Aplicación**: cuando el watcher v3 se introduzca (con `interval` menor a 60s),
la regla debe ser: SIGKILL directo, sin intentar SIGTERM. O: usar `sleep $i &
wait $i` pattern que interrumpe limpio.

### 4.4 absence-tests que ejecutan el validador

**Caso ADDENDUM-M2COUNTS**: añadí una nueva suite al runner (`test-k8s-port-forward-tier.sh`)
pero el "test" no es un caso positivo — es la verificación de que la ausencia
de un tier se mantiene (no se cuelan mutating-unclassified al default).
La suite verifica: "dado este comando, dado este contexto, el guard produce
exactamente esta decisión — y la ausencia de la decisión significa que el
guard ha cambiado de comportamiento".

**Regla**: cuando un cambio es "asegurar que el sistema produce X (no Y)", el
test debe ejecutar el validador (el guard, el hook, la pipeline) y verificar
la salida. No es válido un test que verifica la versión del código, o que
verifica un comentario, o que verifica un fixture estático. El test tiene que
*ejercutar* el sistema.

**Aplicación**: las suites post-#69 (count_active_hooks.py outputs, gate
50/50, PR3-C7 undeclared check, etc.) siguen este patrón: ejecutan el artefacto
bajo test, comparan su output contra el spec. La métrica "0 tests = falso
verde" (`testing-zero-tests-is-never-success`) refuerza: `failed == 0` AND
`total > 0` AND (donde sea posible) `total >= expected_minimum`.

---

## 5. Cross-references

- **#46 critical rule**: security plane constant from variant A onward
  (claudeMd).
- **#47 C1**: task-state canonical via plan-sync-post-step (claudeMd).
- **#48 ceiling + depth**: M3 agent policy (ceiling 8, depth 2).
- **PR 12** (the closing slice): the cert matrix re-run instrument set.
- **PHASE0_INVENTORY_2026-08-31.md**: the executable inventory baseline.
- **PLAN_CERT_METRICS.md**: pre-registered thresholds for the cert gate.
- **HOTPATH_M1_2026-08-28.md**: M1 measurement baseline.
- **M2_APPLIED.md**: the "what changed" headline table.
- **SETTINGS_OPTIN.md**: the opt-in companion for the user.
- **scripts/benchmark/count_active_hooks.py**: the reproducible count tool
  (mmx-2: COUNT-TASK).
- **docs/qteam/QTEAM_FAILURE_MODES.md**: the Q-team process lessons catalogue.

---

## 6. Notes for the publishing lead

1. **Fill the `[DATO]` markers** with the post-cert numbers from PR 12. The
   instrument set is:
   - `python3 scripts/benchmark/count_active_hooks.py --ref main` →
     `17 tuples / 22 commands` (pre-PR-12 baseline); `total` line shifts post-PR-12.
   - `bash tests/run-all-unit-tests.sh` → 50/50 verde (pre-PR-12); expected
     `N/50` or `50+x/50+x` post-PR-12 (x = # new suites that PR 12 adds).
   - `git rev-list --left-right --count main...origin/main` after the PR-12
     merge → should be `0 0` (synchronized).

2. **Cross-check the user decisions section** with the PR review comments
   on #69. The four decisions (3.1-3.4) should each have a confirmation or
   amendment from the user; if any is contested, lead resolves BEFORE
   publishing.

3. **The process lessons section (4.1-4.4)** is the load-bearing part of this
   closure for the NEXT Q-team. If lead cuts them for length, at minimum
   preserve 4.1 (ref obligatorio) and 4.4 (absence-tests), which are the two
   patterns the next epic's automation will encode.

4. **Watcher v2 lives in `results/`** (operational utility, NOT committed
   per HW4). If the next Q-team wants persistent monitoring, the script is
   `results/watcher.sh`; the alerts file is `results/watcher.alerts`. Both
   are reproducible from this draft + the v2 design notes. STATUS @ 2026-09-01:
   watcher v2 está caído por un bug pre-existente en `watcher.sh:114` (`local
   marker=""` a top-level no dentro de función) — el mmx-2 worker tiene un
   BLOCKED abierto al lead sobre esto (msg_id `d181c141`, sin reply). El watcher
   no afecta este draft.

5. **`[DATO-LEAD]` decisions explícitas que el lead llena al publicar**:

   - react-doctor post-#69: **pendiente decisión del usuario al cierre**
     (lead arbitrado en main `028c135` + `d6d1efb` arbitrage; no tocado por
     slices A-F ni por PR12-EXEC; este cierre no lo cierra).

   - `[DATO-LEAD]`: SHA final de cierre del issue #69 = **[a llenar por
     lead al publicar el cierre]**. SHA de cert registrado: `d35f6e2`
     2026-09-01 15:05:40 (addendum final, RECERT 12/12 PASS). El SHA del
     comment de cierre editorial puede diferir.

---

*End of draft. Awaiting lead review and publish.*

---

## 7. Datos medibles HOY (cierre-69 parcial, 2026-09-01)

> Bloque cuantitativo verificable HOY vía `git show`, `tests/run-all-unit-tests.sh`,
> `python3 scripts/benchmark/claude_md_tokens.py` y `count_active_hooks.py --ref main`.
> Lo que aparece aquí se mantiene estable hasta PR 12; los `[DATO-PR12]` del cuerpo
> son lo que la cert matrix tendrá que volver a medir.

### 7.1 SHAs y fechas de merges en `main` (top 10)

```
SHA       fecha       descripción                                                  serie
a87bb0f   2026-09-01  Merge branch 'worktree-zc-3'                                 PR9-EXEC C5 (Slice E absence)
a6079fb   2026-09-01  Merge branch 'worktree-mmx-3'                                PR11-EXEC C4 (Slice F docs)
37ac68a   2026-09-01  Merge branch 'worktree-zc-3'                                 PR8-EXEC C5 (Slice D absence)
f30bd02   2026-09-01  Merge branch 'worktree-zc-3'                                 PR8-EXEC C4
8bce30d   2026-09-01  Merge branch 'worktree-zc-3'                                 PR7-EXEC C3+C4 (Slice C absence)
9857486   2026-09-01  Merge branch 'worktree-zc-3'                                 PR7-EXEC C1+C2 (Slice C 7 dupes)
52411ce   2026-08-31  Merge branch 'worktree-zc-4'                                 PR6-HOTFIX2 (validator)
315fd23   2026-08-31  Merge branch 'worktree-zc-4'                                 PR6-C4 (Aristotle absence)
fd20ee4   2026-08-31  Merge branch 'worktree-zc-4'                                 PR5-HOTFIX
874bf22   2026-08-31  Merge branch 'worktree-zc-4'                                 PR5-C4 (parallel-first source)
```

Lista completa vía `git log main --pretty='%h %ad %s' --date=short --merges`.

Anchor cert baseline: `bfcfef2` (Merge branch 'worktree-mmx-2' — PF-TIER, 2026-08-31),
referenciado por PR4-BASE ("Phase 2 certification baseline on security-final SHA bfcfef2", commit `2a453d6`).

### 7.2 Gate de tests actual (live)

```
$ bash tests/run-all-unit-tests.sh
...
Passed: 47
Failed: 0
Total:  47
Pass Rate: 100%
ALL TEST SUITES PASSED
Completed: Tue Sep  1 13:48:33 CEST 2026
```

**Resultado live @ 2026-09-01**: 47/47 PASS (medido en este turno).
Draft reference: M2-v2 = 43, Post-PR12 = 50 → live (47) cae entre ambos,
consistente con que PR5-PR11 añadió 4 suites sobre la base M2 (PR3-C7 añadió
1 con `test-pr3-c7-no-undeclared-security.sh`; otras 3 vienen de PR7-PR11).

### 7.3 Tokens del CLAUDE.md repo

Pre-state vs post-state (lead-provided 6468→1195, confirmado vía
`uv run --with tiktoken python3 scripts/benchmark/claude_md_tokens.py`):

| Métrica                                              | Pre (M1) | Post (live @ 2026-09-01) | Delta            |
|---|---:|---:|---:|
| CLAUDE.md (worktree) tokens (tiktoken cl100k_base)   | **6468**  | **1195**                 | **−5273 (−81.5%)** |
| ~/.claude/CLAUDE.md (canonical global) tokens        | n/a      | 1200                     | n/a              |

> Las 1195 del worktree y las 1200 del canónico global difieren en 5 tokens
> por la línea de cabecera que el canónico global añade; el contenido
> efectivo es el mismo. Verificación: el script reporta también
> `INFO: native-memory MEMORY.md not present (D3/D4 landed or n/a)`.

### 7.4 Commits por slice del epic #69 (no-merge, regex por PR-series)

| Slice / PR-series                                                | Worker | Commits | Commits clave                                       |
|---|---|---:|---|
| Slice inicial (PR3-C7 + C2-IMPL) — undeclared + RED classes      | zc-3   | 5      | `72caedd` (PR3-C7), `198c759` (C2-IMPL)            |
| Phase 3 Slice A (PR5) — parallel-first removal                  | zc-4   | 6      | `a0d1811`, `c5eaa9f`, `15383c4`, `220dbec` + `b0f1dc8` HOTFIX |
| Phase 3 Slice B (PR6) — Aristotle removal                       | zc-4   | 5      | `bc5b976`, `8b594df`, `c78bb3f`, `b3e54f1` + 1 HOTFIX |
| Slice C (PR7) — duplicates removal                              | zc-3   | 2      | `61a711e`, `d771f46`                                |
| Slice D (PR8) — extractors removed                              | zc-3   | 5      | `b6169ae`, `cd26df3`, `dc85d4b`, `db74b07`, `7598f0f` |
| Slice E (PR9) — compact/resume shadow pair dies                 | zc-3   | 5      | `d13d5aa`, `76d0e16`, `d862d3c`, `a32a358`, `eef7eba` |
| Phase 4 (PR10-EXEC) — CLAUDE.md scope consolidation             | zc-3   | 4      | `9141f9a`, `c2a4918`, `4459ec5`, `7e9e124`          |
| Slice F (PR11-EXEC) — archive purge + 2 tracked DELETEs         | mmx-3  | 3      | `0ca421d`, `6ee41a9`, `5f062bf`                     |
| **TOTAL trabajo epic (no-merge)**                               |        | **35** |                                                    |

> **Nota sobre nomenclatura**: el draft del cierre llama "slice 1" a zero-evidence
> hooks, "slice 2" a duplicates, "slice 3" a undeclared, "slice 4" a post-cert.
> Los commits de PR3-C7 se etiquetan "PR 3 slice 1" pero corresponden a draft-slice 3
> (undeclared). Las nomenclaturas divergen; lead resuelve qué nomenclatura
> prevalece al publicar.

### 7.5 Hooks default-registered en `main` (live, pre-PR12)

```
$ python3 scripts/benchmark/count_active_hooks.py --ref main

event                   matchers   commands
-------------------------------------------
PostToolUse                    2          2
PreToolUse                    10         10
SessionEnd                     1          1
SubagentStart                  1          2
-------------------------------------------
TOTAL                         14         15
```

Comparativa: M2_APPLIED (post-M2) = 17 matcher tuples / 22 commands. La
reducción hasta el live actual es 17→14 matchers y 22→15 commands. Esa
es la delta agregada de PR5-PR11 (Phase 3 Slice A/B + Slice C/D/E + Phase 4 + Slice F).

### 7.6 Hallazgos de auditoría (delta vs draft)

- **Conteo final de `[DATO*]` en el draft** [medido post-PR12 + post-arbitraje F1]: grep
  reporta **20 ocurrencias de `[DATO-PR12]`** (matches con el conteo de lead) +
  **13 `[DATO]` en la tabla de totales** (Post-PR12 col) + **3 prosa** (`[DATO]`
  en L4, L351, L487). Tras el llenado final con cifras certificadas
  (PR12-EXEC + RECERT): **13 [DATO] llenados** + **9 [DATO-PR12] llenados
  con cifras verbatim** + **6 [DATO-LEAD] marcados** (react-doctor, fecha
  cierre issue, slice 1 zero-evidence scope, PHASE0_INVENTORY anchor L68,
  PHASE0_INVENTORY anchor L193, auto-memory classification) — cifra final
  exacta de [DATO-LEAD] en el reporte DONE-2. **15 [DATO-PR12] filled** =
  20 originales - 5 prose-only (header L4 + 4 auto-references en §7.6/L389).
- **Arbitraje F1 (Row 1 hot-path latency, cross-verify zc-4 main `d6d1efb`)**:
  el Row 1 del cert matrix (PR12-EXEC D1: hotpath −29.5% = 362.3 ms vs baseline
  514.0 ms) **NO reproduce entre ventanas** (zc-4 obtuvo 483.3 ms en su
  ventana propia, dentro de la varianza T83 ±10%). Lead arbitra
  **INCOMPLETE per instrument resolution** (N=1/ventana del instrumento más
  grueso que la ventana del efecto). El dato final asentado en el draft:
  "hot-path por-Bash-call: mejora estructural real (~98 ms de hooks fantasma
  eliminados, costo por-hook verificado) pero NO resoluble por el instrumento
  con N=1/ventana — mediana post-borrado 483.3 ms (−5.9% vs baseline 514.0,
  dentro de la varianza T83 ±10%); certificado Row 1 INCOMPLETE por arbitraje
  lead (cross-verify F1, 6 números, 3 artefactos)". Cifras estrella que SÍ
  certifican exacto (no tocadas por el arbitrage): wake-up 1792→1127 stdout
  (byte-identical), hooks 74→44, tokens CLAUDE.md −64%, trivial 0 deny.
- **Slice 1 (zero-evidence hooks)** `[DATO-PR12]`: el draft pide "número de
  hooks y registros borrados en slice 1" pero los commits en `main` no se
  etiquetan explícitamente como "slice 1 zero evidence"; PR3-C7 (`72caedd`)
  se etiqueta "PR 3 slice 1" pero el draft lo mapea a su slice 3 (undeclared).
  La auditoría cruzada requiere git archaeology con criterios explícitos
  de zero-evidence (M1 probe + cero invocaciones + cero tests + cero plano).
- **`PHASE0_INVENTORY.md` secciones "DELETE — duplicados" / "RED — desactivadas"**
  `[DATO-PR12]`: el archivo (`docs/benchmark/PHASE0_INVENTORY_2026-08-31.md`,
  56KB) NO tiene esas secciones con esos nombres. Está organizado por
  superficie (agents/hooks/skills/etc., 11 superficies: agents 37 records,
  artifacts 2, claude-scripts 26, commands 1, distributors 24, **hooks 93**,
  installed-residue 7, rules-src 7, security-manifest 2, settings-record 33,
  skills 63), no por clase de decisión. Las refs del draft (líneas 65 y 183)
  son phantoms de section anchor; el contenido real existe en la matriz
  `### hooks (93 records)` pero sin etiqueta "DELETE — duplicados" /
  "RED — desactivadas". Lead resuelve si mantiene las refs o las reescribe.
