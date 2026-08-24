---
description: Revisa un PR de GitHub (por URL o número, en CUALQUIER repo) con múltiples agentes en paralelo — code review por área, seguridad, consistencia de contrato, rendimiento, tests y auditoría de comentarios de revisores — verifica cada hallazgo contra el código real y guarda un consolidado. Nunca comenta en el PR; eso es /pr-comment.
argument-hint: <url-o-#-del-pr> [foco libre y/o urls de comentarios a auditar]
---

PR a revisar: **$ARGUMENTS**

Este comando **solo analiza y reporta** — NUNCA publica comentarios, reviews, approvals ni labels en el PR, y NUNCA hace push/merge/commit. Publicar es trabajo de `/pr-comment`.

Es **agnóstico al repositorio**: funciona en cualquier repo Git con remoto GitHub. No asume ningún nombre de repo, subcarpeta ni layout. Detecta todo dinámicamente.

---

## 0. Resolución de repo y PR (NADA cableado)

Resuelve estas variables antes de cualquier otra cosa; si alguna falla, **detente y repórtalo** (fail-loud, nunca continúes a ciegas):

- **PR y repo destino** — de `$ARGUMENTS`:
  - Si es una **URL** `https://github.com/<OWNER>/<REPO>/pull/<N>` → extrae `OWNER`, `REPO`, `N` de la propia URL.
  - Si es solo un **número** `#N` o `N` → el repo es el del cwd: `OWNER/REPO = $(gh repo view --json nameWithOwner -q .nameWithOwner)`.
  - En todos los `gh` usa **`--repo "$OWNER/$REPO"`** para no depender del cwd.
- **Raíz del código** — `REPO_ROOT="$(git rev-parse --show-toplevel)"`. Todos los `git` locales usan `git -C "$REPO_ROOT" …`.
  - Verifica que el remoto del `REPO_ROOT` corresponde a `OWNER/REPO` (`git -C "$REPO_ROOT" remote get-url origin`). Si el PR pertenece a **otro** repo que no está en el cwd, avísame: puedo revisar por API/diff, pero el worktree con contexto de código real (paso 2) requiere estar en ese repo o clonarlo — pregúntame cómo proceder en vez de asumir.
- **Scratchpad de sesión** — `SP` = el directorio de scratchpad de esta sesión (para diff, worktree y borradores).
- **Directorio de salida del consolidado** — `OUT`, detectado en este orden (el primero que exista/aplique):
  1. `$REVIEW_OUTPUT_DIR` si está definido en el entorno.
  2. `"$REPO_ROOT/.local-notes/reviews/"` si `.local-notes/` existe en el repo.
  3. `"$REPO_ROOT/docs/reviews/"` si `docs/` existe.
  4. `"$REPO_ROOT/.local-notes/reviews/"` en cualquier otro caso (créalo).
  - En `OUT` **solo se crean archivos**; nunca corras `git` sobre `OUT` (suele estar gitignored — `.local-notes/` lo está por convención).

---

## 1. Contexto y alcance

- `gh pr view "$N" --repo "$OWNER/$REPO" --json title,body,author,baseRefName,headRefName,state,isDraft,mergeable,additions,deletions,changedFiles,files,labels,commits`
- `gh pr diff "$N" --repo "$OWNER/$REPO" > "$SP/pr-$N.diff"` — el **diff del PR es el único alcance** del review; el working tree local queda fuera.
- Si el diff está **vacío** o `gh` falla → detente y repórtalo (no hay review válido sobre cero cambios; fail-loud).
- De la lista de archivos deriva:
  - **Áreas de partición** = agrupaciones por directorio top-level / módulo / servicio **realmente tocados por el diff** (p. ej. `src/api/**`, `packages/web/**`, `cmd/**`, `.claude/hooks/**`). No uses una lista fija: sáctala del diff. Máximo ~4-5 áreas; agrupa lo pequeño.
  - **Stack/lenguajes** por extensión y ficheros clave (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `*.sol`, `Dockerfile`, `*.tf`, k8s manifests) → determina qué tipo de reviewer y qué comando de tests/typecheck/lint aplica.
  - **Superficies sensibles** tocadas (auth, crypto, hooks/guards, migraciones, IaC, CI, dependencias) → obligan reviewers específicos abajo.

## 1b. Comentarios del PR — input de primera clase, no adorno

Descarga **toda** la discusión (no solo la primera pantalla):
- `gh pr view "$N" --repo "$OWNER/$REPO" --json comments` → conversación.
- `gh api "repos/$OWNER/$REPO/pulls/$N/comments" --paginate` → comentarios inline sobre el diff (con `path` y `line`).
- `gh api "repos/$OWNER/$REPO/pulls/$N/reviews" --paginate` → reviews formales y su estado (APPROVED / CHANGES_REQUESTED / COMMENTED).
- `gh api "repos/$OWNER/$REPO/issues/$N/comments" --paginate` → comentarios top-level adicionales.
- Si `$ARGUMENTS` incluye **URLs de comentarios específicos**, resuélvelos por ancla:
  - `#issuecomment-<id>` → `gh api "repos/$OWNER/$REPO/issues/comments/<id>"`.
  - `#discussion_r<id>` → `gh api "repos/$OWNER/$REPO/pulls/comments/<id>"`.
  - Cita el texto **íntegro** de esos comentarios en el scratchpad — son foco explícito y **no pueden quedar sin veredicto**.
- Extrae: decisiones ya tomadas (**no las re-litigues**), objeciones abiertas, y afirmaciones técnicas **verificables** (que luego se comprueban contra el código).

## 2. Worktree temporal (código real con contexto, sin tocar el checkout)

- `git -C "$REPO_ROOT" fetch origin "pull/$N/head:pr-$N-review"`
- `git -C "$REPO_ROOT" worktree add "$SP/pr$N-worktree" "pr-$N-review"`
- Base del diff = `baseRefName` del PR; dentro del worktree los agentes aíslan cambios con `git -C "$SP/pr$N-worktree" diff "origin/<base>...HEAD"`.
- Registra un **trap de limpieza** (paso 5) para que el worktree y la rama se borren aunque el review falle a mitad.

## 3. Fan-out de agentes en paralelo (un solo mensaje, todas las invocaciones)

Elige los agentes según lo que el diff realmente toca. **Siempre exhaustivo**: cubre todas estas dimensiones (agrupa en un mismo agente cuando el diff es pequeño; sepáralas cuando hay volumen):

- **Code-reviewer por área** (1 por cada área del paso 1; máx ~4-5). Reviewer apropiado al lenguaje/stack detectado.
- **Security** (SIEMPRE, sobre el diff completo): authn/authz, inyección (SQL/command/path/template), deserialización, SSRF, secretos/tokens en código o logs, límites sin clamp, entradas no validadas en fronteras, fail-open vs fail-closed, y —si el PR toca hooks/guards/CI/IaC— debilitamiento de controles de seguridad.
- **Consistencia de contrato** (si el PR cruza **2+ capas/servicios con contrato**: HTTP/RPC/IPC/preload/esquemas/tipos compartidos): traza cada capability de punta a punta — nombres, tipos, optionality, defaults, semántica, y compatibilidad cliente-viejo↔server-nuevo y viceversa.
- **Arquitectura**: límites de módulos, cohesión/acoplamiento, patrones del repo, dueños únicos vs doble-responsabilidad, capas con fuga.
- **Correctness / bugs**: caminos de error, `off-by-one`, concurrencia/race, estados imposibles, precedencia de decisiones, edge cases.
- **Tests & cobertura**: corre la suite/typecheck/lint que aplique al stack; verifica que los tests nuevos **prueban lo correcto** (sin asserts débiles) y que la cobertura de lo cambiado es real; aplica **zero-tests-is-never-success** (una corrida de 0 tests NO es verde) y **fail-loud** (nada que enmascare fallos).
- **Rendimiento** (si aplica): N+1, trabajo en hot paths, allocs, I/O en bucles, complejidad, timeouts/retries sin límite.
- **Simplicidad / mantenibilidad**: complejidad innecesaria, duplicación, YAGNI, dead code, nombres.
- **Docs/comentarios**: comentarios que mienten sobre el código, docstrings desactualizados, claims no cumplidos, `CHANGELOG`/README desalineados.
- **Dependencias/supply-chain** (si el diff toca manifiestos/lockfiles): deps nuevas, versiones, CVEs conocidos, scripts de post-install.

A **cada** agente dale: ruta del worktree, ruta del diff (`$SP/pr-$N.diff`), sus archivos de alcance, el **intent del PR** (del body) y las decisiones ya tomadas (paso 1b), y el mandato ESTRICTO:
- **Verificar cada hallazgo contra el código real** — reproducir con snippets/tests desechables cuando sea posible, y **limpiarlos** después.
- Reportar con: **severidad** (Blocker / Critical / High / Medium / Low), `archivo:línea`, defecto en una frase, **escenario concreto de fallo** (inputs → resultado erróneo), y si fue **REPRODUCIDO** o solo leído.
- No inventar: un hallazgo no reproducible se marca como menor confianza, nunca se presenta como confirmado.

## 4. Consolidado (cuando terminen TODOS los agentes)

- **Deduplica** entre agentes (lo que repiten varios suele ser lo más sólido — márcalo).
- Ordena por **severidad**; distingue explícitamente **reproducido** vs solo leído.
- Cruza con el paso 1b: respeta decisiones ya tomadas; da **veredicto explícito** a cada comentario/objeción abierta y a cada URL de comentario que me pasaste.
- Incluye **"Lo que salió limpio"** (verificado, no asumido) y el **estado de suites/typecheck/lint** que los agentes corrieron (con el número de tests ejecutados; si fueron 0, dilo — no es verde).
- Escribe el consolidado en `"$OUT/$(date +%y-%m-%d)-pr-$N.md"` (**solo crear el archivo**; nunca `git` sobre `$OUT`). Este archivo es la fuente que `/pr-comment` usa si se corre en otra sesión. Incluye al inicio: `OWNER/REPO`, `#N`, título, base←head, autor, y conteo de findings por severidad.

## 5. Limpieza (garantizada)

- `git -C "$REPO_ROOT" worktree remove "$SP/pr$N-worktree" --force`
- `git -C "$REPO_ROOT" branch -D "pr-$N-review"`
- Ejecútala también si el review aborta a mitad (trap).

## 6. Repórtame en **español**

Consolidado con recomendación clara: **qué bloquea el merge** (Blocker/Critical), **qué va como follow-up** (High/Medium), **qué es opcional** (Low), y **qué decisiones son mías**. Indica la ruta del archivo guardado. Cierra recordando que **`/pr-comment` publica el comentario** en el PR si lo quiero (este comando nunca lo hace).
