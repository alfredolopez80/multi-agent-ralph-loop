# Unified Herding Blanket — Plan de Mejora v3.0

## Context

**Problem**: Multi-Agent Ralph Loop v2.95 tiene 41 agentes, 55 skills, 108 hooks — pero carece de: (1) frontend orchestration dedicada, (2) design system input para agentes, (3) spec-driven development, (4) anti-rationalization, (5) knowledge compounding. Estas carencias hacen que el sistema sea poderoso para backend pero débil para frontend y que el conocimiento no acumule entre sesiones.

**Research sources**: Karpathy LLM Knowledge Bases, addyosmani/agent-skills (19 skills, 6 fases), VoltAgent/awesome-design-md (55+ DESIGN.md), godofprompt Aristotle First Principles, análisis completo del repo actual.

**Goal**: Framework de desarrollo maximamente autónomo que no depende del modelo sino de procesos y herramientas optimizadas. Mejora tanto code agent como frontend agent.

---

## REGLA FUNDAMENTAL: Inmutabilidad del Plan

**ESTE PLAN ES INMUTABLE DURANTE LA IMPLEMENTACIÓN.**

Ningún agente, skill, o hook puede modificar este archivo ni desviarse de sus instrucciones sin cumplir TODAS estas condiciones:

1. El agente DEBE detectar que la desviación es necesaria (no conveniente, NECESARIA)
2. El agente DEBE invocar `/clarify` o `AskUserQuestion` explicando:
   - Qué paso del plan quiere cambiar
   - Por qué es necesario (no "sería mejor", sino "no funciona porque X")
   - Qué alternativa propone
3. El usuario DEBE aprobar explícitamente la desviación
4. La desviación se documenta como addendum al final de este plan (nunca se modifica el texto original)

**Mecanismo de protección**:
- Crear `.claude/rules/plan-immutability.md` que establece esta regla como rule file cargado automáticamente
- El hook `task-completed-quality-gate.sh` verifica que cada step completado corresponde al plan original
- Si un agente intenta editar este archivo durante implementación, el `PreToolUse` hook lo bloquea

**Anti-Rationalization específica**:
| Excuse del agente | Rebuttal |
|---|---|
| "El plan no contemplaba este edge case" | Documenta como addendum, no modifiques el plan |
| "Sería más eficiente hacer X en vez de Y" | Eficiencia no justifica desviación. Pide permiso. |
| "Ya hice el cambio, actualizaré el plan" | NUNCA. Revierte el cambio y consulta primero. |
| "El plan tiene un error" | Puede ser. Consulta con el usuario antes de cambiar nada. |

---

## P0 — CRITICAL (Semana 1)

### 0a. Fix: Registrar Plan Hooks Faltantes en settings.json

**Problema**: De 8 hooks de gestión de planes, solo 5 están registrados en `~/.cc-mirror/minimax/config/settings.json`. Los 3 faltantes causan que la inicialización del plan, auto-plan-state en Tasks, y la limpieza no funcionen.

**Hooks faltantes a registrar**:

| Hook | Evento | Función |
|---|---|---|
| `plan-state-init.sh` | `PreToolUse` (Task) | Inicializa plan-state.json cuando se crea un Task |
| `auto-plan-state.sh` | `PreToolUse` (Task) | Auto-inicialización del plan state con specs verificables |
| `plan-analysis-cleanup.sh` | `PostToolUse` | Limpia archivos de análisis temporal del plan |

**Acción**: Añadir estos 3 hooks a settings.json bajo los eventos correspondientes, siguiendo el formato de los hooks ya registrados.

**Además**: Crear `.claude/rules/plan-immutability.md` (de la sección REGLA FUNDAMENTAL arriba) como rule file que Claude carga automáticamente para proteger planes durante implementación.

**Verificación**:
- `grep -c "plan-state-init\|auto-plan-state\|plan-analysis-cleanup" ~/.cc-mirror/minimax/config/settings.json` retorna 3
- Claude al iniciar sesión carga la rule de inmutabilidad

**Además**: Actualizar `.gitignore` del repo público para excluir datos privados:
```gitignore
# Private vault data (per developer, NEVER committed)
.claude/vault/
.claude/rules/learned/
.claude/context-payload.md
.claude/memory-context.json
.claude/orchestrator-analysis.md
```

**Deps**: Ninguna. Este es un fix de infraestructura.

---

### 0b. Hook Audit: Consolidación y Registro

**Problema**: 106 hooks en filesystem, solo 51 registrados (48%). 22 hooks duplican funcionalidad. 2 están obsoletos. Esto causa latencia innecesaria y funcionalidad dormida.

**Fase 1 — Limpiar (eliminar/mover)**:
- ELIMINAR `semantic-auto-extractor.sh` — deprecated, migración a claude-mem completa
- ELIMINAR `semantic-write-helper.sh` — deprecated, migración a claude-mem completa
- MOVER `agent-teams-coordinator.sh` → `.claude/lib/agent-teams-coordinator.sh` (es biblioteca, no hook)
- MOVER `handoff-integrity.sh` → `.claude/lib/handoff-integrity.sh` (es biblioteca, no hook)

**Fase 2 — Consolidar (fusionar 22 hooks en existentes)**:

| Hook destino (registrado) | Hooks a fusionar |
|---|---|
| `checkpoint-smart-save.sh` | + `auto-save-context.sh` |
| `session-start-restore-context.sh` | + `context-injector.sh` + `session-start-context-visible.sh` + `session-start-context-zai.sh` |
| `command-router.sh` | + `curator-suggestion.sh` + `prompt-analyzer.sh` + `promptify-auto-detect.sh` |
| `glm-context-update.sh` | + `glm-context-tracker.sh` |
| `auto-plan-state.sh` | + `plan-state-init.sh` (añadir trigger SessionStart) |
| `quality-gates-v2.sh` | + `ralph-quality-gates.sh` + `security-real-audit.sh` + `stop-verification.sh` |
| `ralph-subagent-start.sh` | + `ralph-context-injector.sh` + `ralph-integration.sh` + `ralph-memory-integration.sh` |
| `auto-sync-global.sh` | + `usage-consolidate.sh` |
| Nuevo `project-state.sh` | + `skills-sync-validator.sh` + `unified-context-tracker.sh` |

**Fase 3 — Registrar (23 hooks de alta prioridad)**:

| Hook | Evento | Matcher | Prioridad |
|---|---|---|---|
| `sanitize-secrets.js` | PostToolUse | * | CRITICAL |
| `continuous-learning.sh` | Stop | * | HIGH |
| `episodic-auto-convert.sh` | PostToolUse | Edit\|Write | HIGH |
| `auto-plan-state.sh` | PostToolUse | Write | HIGH |
| `plan-analysis-cleanup.sh` | PostToolUse | ExitPlanMode | HIGH |
| `ralph-stop-quality-gate.sh` | Stop | * | HIGH |
| `ralph-subagent-stop.sh` | SubagentStop | ralph-* | HIGH |
| `subagent-stop-universal.sh` | SubagentStop | * | HIGH |
| `validate-lsp-servers.sh` | PreToolUse | Bash | HIGH |
| `verification-subagent.sh` | PostToolUse | Task | HIGH |
| `auto-checkpoint.sh` | PostToolUse | Edit\|Write | HIGH |
| `agent-memory-auto-init.sh` | PreToolUse | Task | HIGH |
| `project-state.sh` | SessionStart | * | HIGH |
| `procedural-forget.sh` | UserPromptSubmit | * | HIGH |
| `action-report-tracker.sh` | PostToolUse | Task | MEDIUM |
| `batch-progress-tracker.sh` | PostToolUse | Task | MEDIUM |
| `deslop-auto-clean.sh` | PostToolUse | Edit\|Write | MEDIUM |
| `glm-visual-validation.sh` | PostToolUse | Edit\|Write | MEDIUM |
| `task-orchestration-optimizer.sh` | PostToolUse | Task | MEDIUM |
| `task-project-tracker.sh` | PostToolUse | Task | MEDIUM |
| `sentry-report.sh` | Stop | * | MEDIUM |
| `stop-slop-hook.sh` | Stop | * | MEDIUM |
| `auto-format-prettier.sh` | PostToolUse | Edit\|Write | LOW |

**Impacto estimado**:
- Reducción de hooks: 106 → ~85 (-20%)
- Cobertura de registro: 48% → 70%
- Latencia de SessionStart: -15-20% (menos hooks a ejecutar)
- Funcionalidad recuperada: learning pipeline, quality gates, security

**Verificación**:
- `ls .claude/hooks/*.sh .claude/hooks/*.js .claude/hooks/*.py | wc -l` ≤ 90
- `grep -c "command" ~/.cc-mirror/minimax/config/settings.json` ≥ 70
- Benchmark: `time echo '{}' | .claude/hooks/session-start-restore-context.sh` < 500ms

**Deps**: Ninguna. Hacer ANTES de añadir hooks nuevos del plan.

---

### 0c. Aristotle First Principles como Metodología Base

**Qué**: El framework de 5 fases de Aristotle First Principles Deconstructor se convierte en la **metodología fundacional** del sistema. TODO problema, tarea o decisión pasa por estas 5 fases antes de ejecutarse. Esto se integra en el system prompt del orchestrator y en CLAUDE.md.

**Las 5 Fases**:
1. **Assumption Autopsy** — Identificar TODAS las asunciones heredadas en cómo se enmarcó el problema. "El 80% de tu 'problema' son asunciones heredadas que nunca cuestionaste."
2. **Irreducible Truths** — Solo lo que permanece cuando se remueven TODAS las asunciones. Lista numerada de verdades fundamentales irrefutables.
3. **Reconstruction from Zero** — Usando SOLO las verdades irreducibles, reconstruir la solución como si ningún enfoque previo existiera. Generar 3 enfoques distintos.
4. **Assumption vs Truth Map** — Comparación clara mostrando dónde el pensamiento convencional engañaba vs dónde la nueva base conduce.
5. **The Aristotelian Move** — Identificar la ÚNICA acción de máximo apalancamiento que emerge del pensamiento de primeros principios.

**Archivos nuevos**:
- `docs/reference/aristotle-first-principles.md` — Documentación completa del framework con ejemplos por tipo de tarea (bug, feature, refactor, architecture)
- `.claude/rules/aristotle-methodology.md` — Rule file que el sistema carga automáticamente

**Archivos a modificar**:
- `CLAUDE.md` — Añadir sección "## Analysis Methodology" que establece Aristotle como proceso por defecto
- `.claude/skills/orchestrator/SKILL.md` — Step 0 (EVALUATE) se expande: antes de clasificar complejidad, ejecutar las 5 fases de Aristotle para entender el problema real. Para complexity 1-3 puede ser versión corta (2 fases: Assumption Autopsy + Aristotelian Move). Para complexity 4+, las 5 fases completas.
- `.claude/skills/adversarial/SKILL.md` — Integrar Aristotle como primer paso de refinamiento adversarial
- `.claude/skills/spec/SKILL.md` (nuevo, Item 3) — La sección "Invariants" se construye a partir de las Irreducible Truths de la fase 2
- `.claude/skills/clarify/SKILL.md` — Las preguntas de clarificación se enfocan primero en cuestionar asunciones (Phase 1)

**Integración con el workflow existente**:
```
USER INPUT
    ↓
ARISTOTLE PHASE 1: Assumption Autopsy
  "¿Qué estamos asumiendo sin cuestionar?"
    ↓
ARISTOTLE PHASE 2: Irreducible Truths
  "¿Qué es verdaderamente cierto, sin asunciones?"
    ↓
ARISTOTLE PHASE 3: Reconstruction from Zero
  "Si empezáramos de cero, ¿qué 3 enfoques emergen?"
    ↓
ARISTOTLE PHASE 4: Assumption vs Truth Map
  "¿Dónde el enfoque convencional nos engaña?"
    ↓
ARISTOTLE PHASE 5: The Aristotelian Move
  "¿Cuál es la ÚNICA acción de máximo impacto?"
    ↓
ORCHESTRATOR Step 0-8 (flujo normal con la claridad de primeros principios)
```

**Verificación**: El orchestrator, dado un task "optimize database queries", primero identifica asunciones (ej: "asumimos que las queries son el bottleneck, no el schema"), luego verdades irreducibles, y el plan resultante refleja la claridad de primeros principios — no simplemente "reescribir las queries".

**Deps**: Ninguna. Esto es la base sobre la que se construye todo lo demás.

---

### 1. DESIGN.md System

**Qué**: Sistema de diseño en Markdown que los agentes frontend leen para generar UI consistente.

**Archivos nuevos**:
- `.claude/skills/design-system/SKILL.md` — Skill `/design-system` con acciones: `init`, `load`, `validate`
- `docs/templates/DESIGN.md.template` — Template con 9 secciones (Visual Theme, Color Palette, Typography, Components, Layout, Depth, Do's/Don'ts, Responsive, Agent Prompt Guide)

**Archivos a modificar**:
- `.claude/skills/orchestrator/SKILL.md` — Step 3 (PLAN): si tarea es frontend y existe DESIGN.md, incluir como contexto
- `.claude/skills/create-task-batch/SKILL.md` — Preguntar por design system en Phase 1 para frontend tasks

**Verificación**: `/design-system init` produce DESIGN.md válido con 9 secciones. `senior-frontend-developer` usa tokens del DESIGN.md al generar componentes.

**Deps**: Ninguna.

---

### 2. Frontend Agent (ralph-frontend)

**Qué**: Nuevo teammate de Agent Teams especializado en frontend, integrado con hooks existentes.

**Archivos nuevos**:
- `.claude/agents/ralph-frontend.md` — Teammate con tools: LSP, Read, Edit, Write, Bash(npm/npx/bun/git), Chrome DevTools MCP. Prompt incluye: cargar DESIGN.md, WCAG 2.1 AA, 8 estados de componente. 5to pilar de calidad: UI CONSISTENCY.

**Archivos a modificar**:
- `.claude/agents/senior-frontend-developer.md` — Bump a v2.96, campo `team-compatible: true`
- `.claude/agents/frontend-reviewer.md` — Bump a v2.96, añadir "DESIGN.md compliance check"
- `.claude/skills/orchestrator/SKILL.md` — Step 5 (DELEGATE): si tarea es frontend, spawn `ralph-frontend` en vez de `ralph-coder`
- `CLAUDE.md` — Añadir ralph-frontend a tabla de Teammate Types
- `.claude/hooks/teammate-idle-quality-gate.sh` — Nuevo case para `ralph-frontend`

**Verificación**: `Task(subagent_type="ralph-frontend")` funciona. Con DESIGN.md, genera componentes que usan design tokens especificados.

**Deps**: Item 1 (DESIGN.md).

---

### 3. Spec-Driven Development

**Qué**: Skill `/spec` que produce especificación técnica verificable antes de codificar.

**Archivos nuevos**:
- `.claude/skills/spec/SKILL.md` — 6 secciones mandatorias: Interfaces, Behaviors, Invariants, File Plan, Test Plan, Exit Criteria (comandos bash + resultado esperado)
- `docs/templates/SPEC.md.template` — Template con campos y ejemplo

**Archivos a modificar**:
- `.claude/skills/orchestrator/SKILL.md` — Nuevo Step 1.5 (SPECIFY): para complexity > 4, invocar `/spec` antes de planificar
- `.claude/skills/task-batch/SKILL.md` — Phase 3 (DECOMPOSE): para tasks complexity > 6, invocar `/spec`

**Verificación**: `/spec "OAuth2 authentication"` produce `.spec.md` con 6 secciones. Exit Criteria son comandos ejecutables.

**Deps**: Ninguna.

---

### 4. Anti-Rationalization Tables

**Qué**: Tablas de "excusas que hacen los agentes + rebuttals" por skill (patrón de addyosmani/agent-skills).

**Archivos nuevos**:
- `docs/reference/anti-rationalization.md` — Master table con 30+ entries. Formato: `| Excuse | Rebuttal | Affected Skills | Severity |`

**Archivos a modificar** (añadir sección "Anti-Rationalization"):
- `.claude/skills/orchestrator/SKILL.md` — 5-7 entries (saltarse pasos, ignorar memoria)
- `.claude/skills/iterate/SKILL.md` — 5-7 entries (declarar VERIFIED_DONE prematuramente)
- `.claude/skills/task-batch/SKILL.md` — Expandir existente "Partial Success Anti-Pattern" con 5 más
- `.claude/skills/gates/SKILL.md` — 5 entries (saltarse gates, ignorar warnings)
- `.claude/skills/autoresearch/SKILL.md` — 5 entries (parar experimentos temprano)
- `.claude/agents/ralph-coder.md` — Sección "Before Completing" referenciando master table
- `.claude/agents/ralph-frontend.md` — Anti-rationalizations específicas de frontend

**Verificación**: Cada SKILL.md modificado tiene sección "Anti-Rationalization" con ≥5 entries. Master table tiene ≥30 entries.

**Deps**: Item 2 (ralph-frontend).

---

## P1 — HIGH (Semana 2)

### 5. Context Engineering Skill

**Qué**: Skill `/context-engineer` que determina QUÉ contexto necesita un agente y lo empaqueta.

**Archivos nuevos**:
- `.claude/skills/context-engineer/SKILL.md` — Acciones: Analyze (qué necesita), Load (ensamblar), Prune (recortar por token budget), Inject (escribir a `.claude/context-payload.md`)

**Archivos a modificar**:
- `.claude/skills/orchestrator/SKILL.md` — Step 5 (DELEGATE): invocar `/context-engineer` antes de spawn teammate
- `.claude/hooks/ralph-subagent-start.sh` — Si `.claude/context-payload.md` existe, inyectar en prompt

**Verificación**: `/context-engineer "implement OAuth2"` produce payload ≤8000 tokens con archivos relevantes, specs, y memoria.

**Deps**: Item 3 (spec como fuente de contexto).

---

### 6. Browser Testing Integration

**Qué**: Skill `/browser-test` que usa Chrome DevTools MCP y Playwright para verificación visual.

**Archivos nuevos**:
- `.claude/skills/browser-test/SKILL.md` — Start dev server, navigate, screenshot, Lighthouse audit, console errors, network check

**Archivos a modificar**:
- `.claude/skills/gates/SKILL.md` — Nuevo Stage 5: BROWSER (advisory para frontend projects)
- `.claude/skills/orchestrator/SKILL.md` — Step 7 (VALIDATE): incluir browser testing si frontend

**Verificación**: `/browser-test http://localhost:3000` produce reporte con: a11y score, console errors, performance score, screenshot.

**Deps**: Ninguna directa.

---

### 7. Incremental Vertical Slices

**Qué**: Flag `--slices` en `/task-batch` para descomponer en slices verticales (backend+frontend+test por feature).

**Archivos a modificar**:
- `.claude/skills/task-batch/SKILL.md` — Phase 3 (DECOMPOSE): nueva estrategia `--slices`. Cada slice incluye API + UI + test + spec verification
- `.claude/skills/create-task-batch/SKILL.md` — Opción de slicing vertical en "New Feature"

**Verificación**: `/task-batch tasks.md --slices` descompone "user login" en: (1) POST /login + form + test, (2) session + protected route + test, (3) error handling + a11y + test.

**Deps**: Item 3 (spec-per-slice).

---

### 8. Living Knowledge Base (Vault + Obsidian Implementation)

**Qué**: Implementar las primeras fases del vault system plan (ya auditado, commit 3a24941) siguiendo el pipeline de Karpathy, con Obsidian como frontend humano.

#### 8a. Instalación y Configuración de Obsidian (Gratuito, Local)

**Obsidian es 100% gratuito para uso personal y local.** No requiere cuenta, suscripción, ni conexión a internet.

**Paso 1 — Instalación**:
```bash
# macOS via Homebrew (recomendado)
brew install --cask obsidian

# Alternativa: descargar desde https://obsidian.md/download
# Seleccionar macOS (Universal), instalar arrastrando a /Applications
```

**Paso 2 — Crear Vault Local**:
```bash
# Crear directorio del vault
mkdir -p ~/Documents/Obsidian/MiVault

# Crear estructura base para el pipeline Karpathy
mkdir -p ~/Documents/Obsidian/MiVault/{raw,wiki,output,decisions,lessons}

# Crear archivo de configuración Obsidian
mkdir -p ~/Documents/Obsidian/MiVault/.obsidian
```

**Paso 3 — Configurar Obsidian**:
1. Abrir Obsidian → "Open folder as vault" → seleccionar `~/Documents/Obsidian/MiVault`
2. Settings → Core plugins → activar:
   - **Backlinks** (para wiki cross-linking)
   - **Graph view** (para visualizar conexiones)
   - **Templates** (para templates de vault entries)
   - **Daily notes** (para session logs)
3. Settings → Community plugins → instalar:
   - **Dataview** (queries sobre YAML frontmatter — GRATIS)
   - **Templater** (templates avanzados — GRATIS)

**Paso 4 — Crear Template para Vault Entries**:
```bash
# Crear template base
cat > ~/Documents/Obsidian/MiVault/.obsidian/templates/vault-entry.md << 'EOF'
---
type: {{type}}
source: {{source}}
date: {{date}}
tags: []
classification: GREEN
---

# {{title}}

## Context


## Content


## Links

EOF
```

**Paso 5 — Sincronización y Respaldo (git local + repo privado)**:

**Estrategia**: Git local para versionado + GitHub private repo para respaldo ante pérdida de máquina.

```bash
# Inicializar git en el vault
cd ~/Documents/Obsidian/MiVault
git init
git branch -M main

# .gitignore para Obsidian (evitar conflictos de config cache)
cat > .gitignore << 'GITIGNORE'
# Obsidian workspace cache (regenerable, causa conflictos)
.obsidian/workspace.json
.obsidian/workspace-mobile.json
.obsidian/cache/

# OS files
.DS_Store
Thumbs.db

# Temporary files
*.tmp
*.swp
GITIGNORE

# Commit inicial
git add -A
git commit -m "vault: initial structure"

# Crear repo privado en GitHub y conectar
gh repo create vault-knowledge-base --private --source=. --remote=origin --push
```

**Auto-commit hook** (opcional, para que cada sesión de Claude se respalde):
```bash
# Añadir a .claude/hooks/session-end-handoff.sh:
# Al final de cada sesión, commit + push del vault
VAULT_DIR="$HOME/Documents/Obsidian/MiVault"
if [ -d "$VAULT_DIR/.git" ]; then
  cd "$VAULT_DIR"
  git add -A
  git diff --cached --quiet || git commit -m "vault: session $(date +%Y-%m-%d-%H%M)"
  git push origin main 2>/dev/null || true  # silent fail si no hay internet
fi
```

**Ventajas de este enfoque**:
- **Versionado**: Cada cambio del wiki tiene historial git completo
- **Respaldo**: Private repo en GitHub = recuperable ante pérdida de máquina
- **Sin costo**: GitHub repos privados son gratuitos
- **Offline-first**: Funciona sin internet, push cuando haya conexión
- **Diff amigable**: `.md` files son text-based, diffs legibles
- **Sin conflictos**: Solo un escritor (tu máquina), no hay merge conflicts

**Qué NO hacer**:
- NO usar iCloud/Dropbox para el vault (causa conflictos de sync con .obsidian/)
- NO poner el vault dentro de multi-agent-ralph-loop (son repos separados con propósitos distintos)
- NO hacer public el repo (puede contener learnings con contexto sensible)

**Paso 6 — Integración con Claude/Ralph**:
```bash
# El MCP filesystem ya puede leer el vault (configurar en settings.json)
# Scope limitado al directorio del vault:
# "allowedDirectories": ["/Users/alfredolopez/Documents/Obsidian/MiVault"]
```

**Estructura del Vault — Arquitectura Multi-Proyecto + Pipeline Karpathy**:

**Problema**: Tienes múltiples proyectos (multi-agent-ralph-loop, otros repos). El conocimiento debe:
1. NO mezclarse entre proyectos (un pattern de blockchain no contamina un proyecto frontend)
2. SÍ compartir aprendizajes genéricos (un pattern de TypeScript sirve para todos)
3. Componer automáticamente (cada sesión enriquece el wiki)

**Solución: 3 capas + clasificación GREEN/YELLOW/RED**:

```
~/Documents/Obsidian/MiVault/           # VAULT GLOBAL (git + private repo)
│
├── .obsidian/                          # Config Obsidian
│
├── global/                             # CAPA 1: Conocimiento cross-proyecto (GREEN)
│   ├── raw/                            # Sources sin procesar genéricos
│   │   ├── articles/                   # Web clips (Obsidian Web Clipper)
│   │   ├── papers/                     # PDFs y research
│   │   └── images/                     # Screenshots, diagramas
│   ├── wiki/                           # Wiki compilado por LLM
│   │   ├── typescript/                 # Patterns TypeScript (genérico)
│   │   ├── react/                      # Patterns React (genérico)
│   │   ├── security/                   # Security patterns (genérico)
│   │   ├── testing/                    # Testing patterns (genérico)
│   │   ├── agent-engineering/          # Cómo construir agentes (meta-knowledge)
│   │   ├── architecture/              # Patterns arquitectónicos
│   │   └── _index.md                   # Índice auto-mantenido por LLM
│   ├── output/                         # Artefactos generados
│   │   ├── slides/                     # Marp presentations
│   │   └── reports/                    # Análisis
│   └── decisions/                      # ADRs globales
│
├── projects/                           # CAPA 2: Conocimiento por proyecto (YELLOW)
│   ├── multi-agent-ralph-loop/         # ← Tu repo principal
│   │   ├── raw/                        # Sources específicos del proyecto
│   │   ├── wiki/                       # Wiki del proyecto
│   │   │   ├── architecture.md         # Arquitectura del proyecto
│   │   │   ├── hooks-system.md         # Cómo funcionan los hooks
│   │   │   ├── agent-routing.md        # Cómo se enrutan los agentes
│   │   │   ├── known-issues.md         # Issues conocidos
│   │   │   └── _index.md              # Índice del proyecto
│   │   ├── lessons/                    # Learnings por sesión
│   │   │   └── 2026-04-04-*.md        # Una entry por sesión
│   │   └── decisions/                  # ADRs del proyecto
│   │
│   ├── otro-proyecto/                  # Otro repo
│   │   ├── raw/
│   │   ├── wiki/
│   │   ├── lessons/
│   │   └── decisions/
│   │
│   └── _project-index.md              # Índice de todos los proyectos
│
└── _vault-index.md                     # Índice maestro del vault completo
```

**Flujo de datos (Pipeline Karpathy adaptado a multi-proyecto)**:

```
SESIÓN DE TRABAJO EN PROYECTO X
        ↓
┌─────────────────────────────────────────────────────┐
│ HOOKS EXISTENTES (ya funcionan en Ralph)            │
│                                                     │
│ session-accumulator.sh (PostToolUse)                │
│   → Captura learnings durante la sesión             │
│   → Los guarda en buffer temporal                   │
│                                                     │
│ pre-compact-handoff.sh (PreCompact)                 │
│   → Antes de compactar, salva contexto              │
│                                                     │
│ session-end-handoff.sh (SessionEnd)                 │
│   → Al final, trigger exit-review                   │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ EXIT-REVIEW (nuevo skill, al final de sesión)       │
│                                                     │
│ Para cada learning acumulado:                       │
│                                                     │
│ CLASIFICAR con GREEN/YELLOW/RED:                    │
│                                                     │
│ GREEN = Genérico (sirve para cualquier proyecto)    │
│   Ejemplo: "Usar zod para runtime validation"       │
│   Destino: vault/global/wiki/{category}/            │
│                                                     │
│ YELLOW = Específico del proyecto                    │
│   Ejemplo: "El hook sanitize-secrets.js usa 28      │
│            patterns, no modificar sin auditoría"     │
│   Destino: vault/projects/{project}/wiki/           │
│                                                     │
│ RED = Contiene secretos o info sensible             │
│   Ejemplo: "API key de producción es sk-..."        │
│   Destino: DESCARTADO (nunca guardado)              │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ VAULT COMPILE (periódico o bajo demanda)            │
│                                                     │
│ /vault compile                                      │
│   → Lee raw/ + lessons/ recientes                   │
│   → LLM compila nuevos artículos en wiki/           │
│   → Actualiza backlinks entre artículos             │
│   → Actualiza _index.md                             │
│   → "Lint+Heal": busca inconsistencias,             │
│     sugiere nuevos artículos, imputa info faltante  │
│                                                     │
│ Karpathy insight: "Every answer compounds"          │
│ → Las respuestas de Q&A se "filan" de vuelta       │
│   al wiki, enriqueciendo futuras consultas          │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ CONSULTA (próxima sesión en cualquier proyecto)     │
│                                                     │
│ /vault search "OAuth2 patterns"                     │
│   → Busca en: global/wiki/ + projects/{current}/    │
│   → NO busca en otros proyectos (aislamiento)       │
│   → Retorna: artículos relevantes + lessons         │
│                                                     │
│ Integración con hooks existentes:                   │
│   smart-memory-search.sh ya hace búsqueda parallel: │
│   ├─ claude-mem (ephemeral)                         │
│   ├─ memvid (vector)                                │
│   ├─ handoffs (session snapshots)                   │
│   ├─ ledgers (continuity)                           │
│   └─ vault (NUEVO: curated knowledge) ← SE AÑADE   │
└─────────────────────────────────────────────────────┘
```

**Integración con hooks de aprendizaje existentes**:

| Hook existente | Función actual | Mejora con Vault |
|---|---|---|
| `smart-memory-search.sh` | Búsqueda paralela en 4 fuentes | +1 fuente: vault (global + project) |
| `session-end-handoff.sh` | Guarda handoff para próxima sesión | + trigger exit-review para clasificar learnings |
| `pre-compact-handoff.sh` | Salva contexto pre-compaction | + salva learnings acumulados al vault buffer |
| `continuous-learning.sh` | Captura patterns en tiempo real | + classifica patterns como GREEN/YELLOW en tiempo real |
| `episodic-auto-convert.sh` | Convierte episodios a memoria | + los episodios GREEN van al vault global wiki |
| `orchestrator-auto-learn.sh` | Aprende de retrospectivas | + las retrospectivas alimentan vault/projects/{project}/lessons/ |

**Pipeline Vault → Rules (Knowledge Graduation)**:

El conocimiento del vault DEBE graduarse a `.claude/rules/` para que Claude lo aplique automáticamente. Sin este pipeline, el vault es solo un archivo que nadie lee.

```
VAULT (conocimiento acumulado)
        ↓
┌─────────────────────────────────────────────────────┐
│ /vault compile (incluye paso de graduation)         │
│                                                     │
│ Para cada artículo en wiki/:                        │
│   1. Contar: ¿cuántas sesiones confirman este       │
│      pattern? (confidence score)                    │
│   2. Si confidence >= 0.7 Y usage >= 3 sesiones:    │
│      → GRADUAR a .claude/rules/learned/{category}.md│
│   3. Si confidence < 0.7:                           │
│      → Mantener en vault, esperar más evidencia     │
│                                                     │
│ Formato de rule graduada:                           │
│   - Rule text (una línea actionable)                │
│   - Source: vault article path                      │
│   - Confidence: 0.7-1.0                             │
│   - Sessions confirmed: N                           │
│   - Last confirmed: YYYY-MM-DD                      │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ .claude/rules/learned/{category}.md                 │
│                                                     │
│ Archivos existentes que se enriquecen:              │
│   - general.md    (actualmente 2 rules → crecerá)   │
│   - frontend.md   (actualmente 2 rules → crecerá)   │
│   - backend.md    (patterns backend)                │
│   - security.md   (security patterns)               │
│   - testing.md    (testing patterns)                │
│   - hooks.md      (hooks patterns)                  │
│   - database.md   (database patterns)               │
│                                                     │
│ Claude Code carga estos automáticamente al inicio   │
│ de CADA sesión → el comportamiento mejora           │
│ progresivamente sin intervención manual              │
└─────────────────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────────────────┐
│ RESULTADO: Aprendizaje Compuesto                    │
│                                                     │
│ Sesión 1: Descubre "usar zod para validation"       │
│   → vault/global/wiki/typescript/validation.md      │
│   → confidence: 0.3 (solo 1 sesión)                 │
│                                                     │
│ Sesión 5: Confirma el pattern por 3ra vez           │
│   → confidence: 0.7, usage: 3                       │
│   → GRADUADO a .claude/rules/learned/frontend.md    │
│   → "Use zod for runtime validation at API          │
│      boundaries (confidence: 0.7, 3 sessions)"     │
│                                                     │
│ Sesión 10+: Claude aplica automáticamente zod       │
│   → No necesita que se lo digas                     │
│   → El conocimiento está en sus rules               │
└─────────────────────────────────────────────────────┘
```

**Hook para graduation automática** (nuevo):
- `.claude/hooks/vault-graduation.sh` — Se ejecuta en `SessionStart`. Revisa vault para learnings con confidence >= 0.7 y los promueve a `.claude/rules/learned/`. El usuario VE los cambios en el diff al hacer commit.

**Protección contra rules basura**:
- Solo se gradúan learnings con confidence >= 0.7 Y >= 3 sesiones de confirmación
- Cada rule incluye su source (vault article path) para trazabilidad
- El usuario puede editar/eliminar rules en `.claude/rules/learned/` — son archivos de texto
- `/vault demote "rule text"` revierte una rule al vault si resulta incorrecta

**Reglas de aislamiento entre proyectos**:
1. Un proyecto SOLO lee: `global/wiki/` + `projects/{su-propio-nombre}/`
2. NUNCA lee `projects/{otro-proyecto}/` directamente
3. Si un learning de un proyecto es útil globalmente, se "promueve" a `global/wiki/` durante vault compile
4. La clasificación GREEN/YELLOW es la que determina dónde va cada learning
5. SHA-256 deduplication: si el mismo learning ya existe en global, no se duplica en el proyecto

**Costo total: $0.** Obsidian es gratuito para uso personal. Los plugins recomendados (Dataview, Templater) son gratuitos. La sincronización local (iCloud/git) es gratuita.

#### 8b. Skills y Hooks del Vault

**Archivos nuevos**:
- `.claude/skills/vault/SKILL.md` — `/vault search`, `/vault save`, `/vault index`, `/vault compile` (compilar raw/ → wiki/ → rules graduation)
- `.claude/hooks/session-accumulator.sh` — PostToolUse hook que captura learnings
- `.claude/hooks/vault-graduation.sh` — SessionStart hook que promueve learnings de alta confianza a `.claude/rules/learned/`
- `.claude/skills/exit-review/SKILL.md` — Review GREEN/YELLOW/RED al final de sesión
- `scripts/setup-obsidian-vault.sh` — Script automatizado de los pasos 1-6

**Archivos a modificar**:
- `.claude/hooks/pre-compact-handoff.sh` — Save vault context antes de compaction

**Verificación**:
- `scripts/setup-obsidian-vault.sh` crea la estructura completa sin errores
- `/vault search "OAuth2 patterns"` retorna entries de sesiones anteriores
- `/vault compile` toma archivos de `raw/` y produce artículos en `wiki/`
- Session accumulator captura ≥3 snippets por sesión no-trivial
- Obsidian muestra el graph view con backlinks entre artículos del wiki

**Deps**: Ninguna (vault plan ya auditado).

---

## P2 — MEDIUM (Semana 3)

### 9. Performance Optimization Skill
- `.claude/skills/perf/SKILL.md` — Core Web Vitals via Lighthouse, bundle size, métricas over time
- `docs/reference/performance-checklist.md`
- Deps: Item 6

### 10. ADR System
- `.claude/skills/adr/SKILL.md` — `/adr create`, `/adr list`, `/adr search`
- `docs/decisions/README.md` + `docs/templates/ADR.md.template`
- Deps: Ninguna

### 11. Shipping Checklist
- `.claude/skills/ship/SKILL.md` — Pre-launch checklist orquestando `/gates`, `/security`, `/browser-test`
- `docs/reference/shipping-checklist.md`
- Deps: Items 6, 9, 10

### 12. Reference Checklists
- `docs/reference/testing-patterns.md` — 20+ items
- `docs/reference/security-checklist.md` — OWASP Top 10
- `docs/reference/accessibility-checklist.md` — WCAG 2.1 AA por component type
- Deps: Items 2, 5

---

## P3 — NICE TO HAVE

### 13. Accessibility Audit
Extender `/browser-test` con `--a11y` (axe-core via Lighthouse). Block en ralph-frontend quality gate.

### 14. Visual Regression
Extender `/browser-test` para guardar screenshots en `.claude/quality-results/screenshots/`. Usar `mcp__zai-mcp-server__ui_diff_check` para comparación.

### 15. Cross-Task Learning
Extender vault session accumulator con task IDs. `/task-batch` consulta vault para learnings de tasks previos del mismo batch.

---

## Summary

| Priority | Items | New Files | Modified Files |
|----------|-------|-----------|----------------|
| P0 | 5 items (0-4) | 9 | 19 |
| P1 | 4 items | 6 | 6 |
| P2 | 4 items | 8 | 3 |
| P3 | 4 items | 0 | 4 |
| **Total** | **16 items** | **23** | **30** |

## Orden de Implementación

```
FASE ALFA (Foundation):
0a (Fix plan hooks) → 0b (Hook audit: consolidate+register) → 0c (Aristotle Base)
→ 1 (DESIGN.md) → 3 (spec) → 2 (ralph-frontend) → 4 (anti-rationalization)

FASE BETA (Extensions):
→ 5 (context-engineer) → 6 (browser-test) → 8 (vault+Obsidian) → 7 (vertical slices)
→ 10 (ADR) → 9 (perf) → 12 (checklists) → 11 (ship)
→ 13-15 (nice to have)
```

## Symlinks (por item)

Cada nuevo skill requiere symlinks a 6 directorios (per CLAUDE.md v2.90.1):
```bash
SKILL_NAME="<name>"
REPO="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
for dir in ~/.claude/skills ~/.codex/skills ~/.ralph/skills \
           ~/.cc-mirror/zai/config/skills ~/.cc-mirror/minimax/config/skills \
           ~/.config/agents/skills; do
  mkdir -p "$dir"
  ln -sfn "$REPO/.claude/skills/$SKILL_NAME" "$dir/$SKILL_NAME"
done
```

## Verification (End-to-End)

1. **P0 smoke test**: Crear DESIGN.md con `/design-system init` → generar spec con `/spec "landing page"` → spawn `ralph-frontend` → verificar que usa design tokens → verificar anti-rationalization bloquea shortcuts
2. **P1 smoke test**: `/context-engineer` empaqueta DESIGN.md + spec → `/browser-test` toma screenshot → `/vault save` guarda el resultado
3. **Full integration**: `/task-batch landing-page.prq.md --slices` ejecuta feature completa con vertical slices, browser testing, y vault accumulation

---

## Adversarial Audit (Opus Review — 2026-04-04)

### BLOCKING Issues (Fixed)

**B1. Plan contradice vault plan existente.**
El `.claude/plans/vault-system-implementation-plan.md` (v1.1.0, auditado) tiene 7 issues BLOCKING no resueltos. Item 8 del plan redeseña el vault con estructura diferente sin reconciliar.
**FIX**: Item 8 DEBE adoptar el vault plan existente como base y resolver sus 7 blocking issues primero. La estructura `global/` + `projects/` es una extensión del plan existente, no un reemplazo.

**B2. SessionEnd NO existe como evento.**
`session-end-handoff.sh` está registrado bajo `Stop`, no `SessionEnd`. CLAUDE.md dice "11 events including SessionEnd" pero settings.json solo tiene 10.
**FIX**: Usar evento `Stop` para trigger de exit-review. NO asumir SessionEnd.

**B3. Hook performance saturation.**
58 hooks registrados. `PreToolUse(Task)` tiene 11 hooks secuenciales. Añadir más sin medir latencia → riesgo de timeout.
**FIX**: Antes de añadir hooks nuevos, ejecutar benchmark de latencia actual. Budget: <2s por evento. Consolidar hooks si es necesario.

**B4. Verificación y matchers incompletos.**
Item 0a no especifica EXACTOS JSON entries para settings.json (qué evento, qué matcher).
**FIX**: Cada hook nuevo DEBE incluir su JSON entry exacto para settings.json.

### IMPORTANT Issues (Fixed)

**I1. Dependency Item 4→2 invertida.** Anti-rationalization tables son documentación — NO dependen de ralph-frontend.
**FIX**: Item 4 ya no depende de Item 2. Anti-rat tables se crean primero, se extienden a ralph-frontend cuando exista.

**I3. MCP tools NO van en teammate tools array.** Los ralph-* teammates usan tools restringidos (`Bash(npm:*)`). MCP tools no se listan en frontmatter.
**FIX**: ralph-frontend invoca browser testing via skill (`/browser-test`), no via MCP tools en frontmatter.

**I6. `team-compatible: true` es campo ficticio.** No existe en ningún agente actual. Ralph teammates se reconocen por prefijo `ralph-` y matcher en SubagentStart.
**FIX**: Eliminar `team-compatible: true`. En su lugar, ralph-frontend se identifica por naming convention `ralph-*` y matcher en `ralph-subagent-start.sh`.

**I4. Aristotle como pre-step vs integrado.** Añadir 5 fases ANTES de Step 0 renumera todos los steps.
**FIX**: Aristotle se INTEGRA DENTRO del Step 0 existente (EVALUATE), no como pre-step nuevo. Para complexity 1-3: 2 fases rápidas integradas. Para 4+: 5 fases completas como parte de EVALUATE.

**I5. Obsidian como opcional, no dependencia.** El vault funciona como plain markdown + git. Obsidian es viewer opcional.
**FIX**: El vault NO depende de Obsidian. `scripts/setup-obsidian-vault.sh` instala Obsidian como OPCIONAL. El vault funciona sin él.

### Scope Recommendation del Adversarial

El "Aristotelian Move" sugiere reducir a 4 items core:
1. Fix 3 hooks faltantes
2. Vault/learning pipeline end-to-end
3. ralph-frontend minimal
4. DESIGN.md template

**Decision**: Mantener los 16 items como plan COMPLETO, pero implementar en 2 fases:
- **Fase Alfa** (items 0a, 0b, 1, 2, 3, 4): Core foundation
- **Fase Beta** (items 5-15): Extensions una vez Alfa validada

---

## Test Plan (Post-Implementación)

### Test Files a Crear (16 total)

| File | Tipo | Item | Tests |
|------|------|------|-------|
| `tests/test_plan_hooks_registration_v3.py` | pytest | 0a | 7 |
| `tests/unit/test-plan-hooks-registration-v3.sh` | bash | 0a | 8 |
| `tests/test_plan_immutability_rule.py` | pytest | 0a | 5 |
| `tests/skills/test-aristotle-methodology.sh` | bash | 0b | 13 |
| `tests/test_aristotle_integration.py` | pytest | 0b | 5 |
| `tests/skills/test-design-system.sh` | bash | 1 | 18 |
| `tests/skills/test-ralph-frontend.sh` | bash | 2 | 12 |
| `tests/skills/test-spec.sh` | bash | 3 | 13 |
| `tests/skills/test-anti-rationalization.sh` | bash | 4 | 12 |
| `tests/test_anti_rationalization.py` | pytest | 4 | 8 |
| `tests/skills/test-vault.sh` | bash | 8 | 10 |
| `tests/skills/test-exit-review.sh` | bash | 8 | 6 |
| `tests/unit/test-vault-setup.sh` | bash | 8 | 7 |
| `tests/test_vault_hooks.py` | pytest | 8 | 10 |
| `tests/integration/test-vault-pipeline.sh` | bash | 5 |
| `tests/test_vault_full_pipeline.py` | pytest | 8 | 9 |

### Archivos Test Existentes a Modificar

| File | Cambio |
|------|--------|
| `tests/test_hooks_registration.py` | +5 hooks al HOOK_REGISTRY |
| `tests/test_skills.py` | +6 skills a EXPECTED_SKILLS |
| `tests/conftest.py` | Update critical_skills fixture |
| `tests/run_tests.sh` | Add `vault` y `hb` test modes |

### Smoke Tests (Quick Validation)

```bash
# P0a: Verify 3 plan hooks registered
grep -cE "plan-state-init|auto-plan-state|plan-analysis-cleanup" \
  ~/.cc-mirror/minimax/config/settings.json

# P0b: Aristotle in 4 files
grep -l "Aristotle\|first.principles" .claude/skills/orchestrator/SKILL.md \
  .claude/rules/aristotle-methodology.md docs/reference/aristotle-first-principles.md CLAUDE.md

# P0-1: DESIGN.md template has 9 sections
grep -c "^##" docs/templates/DESIGN.md.template

# P0-2: ralph-frontend exists and references DESIGN.md
test -f .claude/agents/ralph-frontend.md && grep -q "DESIGN.md" .claude/agents/ralph-frontend.md

# P0-3: spec skill has 6 sections
grep -cE "Interfaces|Behaviors|Invariants|File Plan|Test Plan|Exit Criteria" \
  .claude/skills/spec/SKILL.md

# P1-8: vault pipeline
test -f .claude/skills/vault/SKILL.md && test -f .claude/hooks/session-accumulator.sh \
  && test -f .claude/hooks/vault-graduation.sh
```

### Tests de Aislamiento Público/Privado

**Principio arquitectónico**: `multi-agent-ralph-loop` es un repo PÚBLICO que contiene el FRAMEWORK de aprendizaje (skills, hooks, procesos). El VAULT es un repo PRIVADO separado que contiene el CONOCIMIENTO aprendido. Nunca deben mezclarse.

| Componente | Ubicación | Visibilidad | Contiene |
|---|---|---|---|
| Framework | `multi-agent-ralph-loop/` | PÚBLICO | Skills, hooks, agents, templates, procesos |
| Vault | `~/Documents/Obsidian/MiVault/` | PRIVADO (local + repo privado) | Learnings, wiki, decisions, patterns personales |
| Rules learned | `.claude/rules/learned/` | LOCAL (no committed) | Reglas graduadas del vault, por desarrollador |
| Settings | `~/.cc-mirror/minimax/config/` | LOCAL | API keys, config personal |

**File**: `tests/security/test-vault-isolation.sh`

```bash
# Test 1: No vault data in git tracked files
# El repo público NO debe contener datos del vault
grep -rn "MiVault\|vault-knowledge-base" --include="*.md" --include="*.sh" \
  --include="*.py" --include="*.json" . \
  | grep -v ".ralph/plans/" | grep -v "SKILL.md" | grep -v "test" \
  | grep -v ".gitignore" && FAIL "Vault data found in tracked files" || PASS

# Test 2: .gitignore excludes vault artifacts
grep -q ".claude/vault/" .gitignore && PASS || FAIL ".claude/vault/ not in .gitignore"

# Test 3: No API keys in tracked files
grep -rn "sk-[a-zA-Z0-9]" --include="*.md" --include="*.sh" --include="*.json" . \
  | grep -v "settings.json" | grep -v "test" \
  && FAIL "API key pattern found in tracked files" || PASS

# Test 4: .claude/rules/learned/ is gitignored (personal per developer)
grep -q ".claude/rules/learned/" .gitignore && PASS || FAIL "learned rules not gitignored"

# Test 5: Vault skills only contain FRAMEWORK, not data
# /vault skill should teach HOW to create vault, not contain vault data
grep -c "~/Documents/Obsidian" .claude/skills/vault/SKILL.md | \
  xargs -I{} test {} -le 5 && PASS || FAIL "Too many personal paths in vault skill"

# Test 6: No personal paths hardcoded in public files
# Skills should use $HOME or relative paths, not /Users/alfredolopez
grep -rn "/Users/alfredolopez" --include="*.sh" --include="*.py" .claude/skills/ \
  && FAIL "Personal paths in public skills" || PASS

# Test 7: Vault repo is separate from multi-agent-ralph-loop
# Verify no .git nesting
test ! -d ".claude/vault/.git" && PASS || FAIL "Vault git nested inside repo"

# Test 8: setup-obsidian-vault.sh creates OUTSIDE of repo
grep -q 'HOME.*Obsidian\|HOME.*vault' scripts/setup-obsidian-vault.sh \
  && PASS || FAIL "Setup script should create vault outside repo"
```

**File**: `tests/security/test-no-knowledge-leak.py`

```python
class TestNoKnowledgeLeak:
    """Verify the public repo never contains private knowledge."""

    test_no_vault_data_in_git
        - Run: git ls-files
        - Assert: NO file under .claude/vault/ is tracked
        - Assert: NO file matching **/lessons/*.md is tracked
        - Assert: NO file matching **/wiki/*.md in vault paths is tracked

    test_gitignore_excludes_private_dirs
        - Read .gitignore
        - Assert contains: .claude/vault/
        - Assert contains: .claude/rules/learned/
        - Assert contains: .claude/context-payload.md
        - Assert contains: .claude/memory-context.json

    test_skills_use_variables_not_hardcoded_paths
        - For each SKILL.md in .claude/skills/:
        - Assert: NO occurrence of /Users/ (hardcoded personal path)
        - Skills should use $HOME, $VAULT_DIR, or relative paths

    test_vault_skill_is_framework_not_data
        - Read .claude/skills/vault/SKILL.md
        - Assert: Contains "how to set up" instructions
        - Assert: Does NOT contain actual vault entries/learnings
        - Assert: References $HOME/Documents/Obsidian/MiVault as EXAMPLE, not hardcoded

    test_hooks_dont_log_vault_content_to_stdout
        - Read session-accumulator.sh
        - Assert: Learnings go to vault dir, NOT to stdout
        - Assert: No echo of learning content (could be captured by other hooks)

    test_no_api_keys_in_public_files
        - Scan all tracked .md, .sh, .py, .json files
        - Assert: NO matches for sk-*, ANTHROPIC_API_KEY=*, Bearer *, etc.
        - Exclude: settings.json (local), test fixtures
```

**Arquitectura de Onboarding para Nuevos Desarrolladores**:

Cuando un nuevo desarrollador clona `multi-agent-ralph-loop`, el flujo es:

```
1. git clone multi-agent-ralph-loop   → Obtiene FRAMEWORK público
2. /vault init                        → Crea SU vault personal en ~/Documents/Obsidian/MiVault/
3. gh repo create vault-kb --private  → Crea SU repo privado de respaldo
4. Trabaja normalmente                → Los hooks capturan learnings a SU vault
5. Vault graduation                   → SUS learnings se promueven a SUS .claude/rules/learned/
6. Nunca hace push de rules/learned   → .gitignore lo previene
```

El repo público enseña el PROCESO. El vault privado acumula el CONOCIMIENTO. Cada desarrollador tiene su propia base de conocimiento que crece con su experiencia.

### Execution Strategy

1. **TDD**: Escribir tests ANTES de implementar (todos deben FALLAR inicialmente)
2. **Security first**: Tests de aislamiento se escriben PRIMERO (antes de cualquier vault code)
3. **Item by item**: Después de cada item, correr sus tests específicos
4. **Integration sweep**: `./tests/run_tests.sh hb` (herding blanket)
5. **Full regression**: `./tests/run_tests.sh all`

---

## Análisis de Duplicación con Claude Code Nativo (v2.1.84)

### Features Nativos que hacen REDUNDANTES hooks custom

| Hook Custom | Feature Nativo | Versión | Veredicto |
|---|---|---|---|
| `auto-save-context.sh` | Auto-Compact nativo (95% trigger) | v1.0+ | **ELIMINAR** — Claude ya guarda contexto antes de compactar |
| `auto-checkpoint.sh` | Auto-Compact nativo | v1.0+ | **ELIMINAR** — el checkpoint manual duplica compactación nativa |
| `context-injector.sh` | SessionStart nativo restaura contexto | v1.0+ | **ELIMINAR** — Claude restaura contexto al iniciar sesión |
| `session-start-context-visible.sh` | SessionStart nativo | v1.0+ | **ELIMINAR** — duplica restauración nativa |
| `session-start-context-zai.sh` | SessionStart nativo | v1.0+ | **ELIMINAR** — variante Zai de lo mismo |
| `validate-lsp-servers.sh` | LSP nativo con startupTimeout | v2.0.74+ | **ELIMINAR** — Claude maneja LSP discovery nativamente |
| `usage-consolidate.sh` | rate_limits nativo en statusline | v2.1.80+ | **ELIMINAR** — statusline ya muestra usage |

**Total: 7 hooks redundantes a eliminar (además de los 2 obsoletos ya identificados)**

### Features Nativos que nuestros hooks MEJORAN (mantener)

| Hook Custom | Feature Nativo | Por qué MANTENER |
|---|---|---|
| `sanitize-secrets.js` | Env scrubbing (`SUBPROCESS_ENV_SCRUB`) | Nativo solo scrubea env vars. Nuestro hook hace pattern matching en CONTENIDO (28 patterns) |
| `git-safety-guard.py` | Permission system + deny rules | Nativo bloquea por permiso. Nuestro hook bloquea patterns ESPECÍFICOS (rm -rf, reset --hard, command chaining) |
| `pre-compact-handoff.sh` | Auto-Compact | Nativo compacta. Nuestro hook SALVA estado custom (handoffs, ledgers) antes de compactar |
| `quality-gates-v2.sh` | Agent Teams events | Nativo provee los EVENTOS. Nuestro hook provee la LÓGICA de validación (lint, types, security) |
| `continuous-learning.sh` | Auto-Memory (v2.1.59+) | Auto-Memory es notas simples. Nuestro hook hace extracción de PATTERNS procedurales |
| `episodic-auto-convert.sh` | Auto-Memory | Auto-Memory no convierte episodios a reglas. Nuestro hook hace promotion episodic→procedural |
| `smart-memory-search.sh` | Auto-Memory search | Auto-Memory busca en MEMORY.md. Nuestro hook busca en 5 fuentes en paralelo |

### Impacto en el Plan

**Hooks a ELIMINAR del Item 0b** (ya contados en consolidación, ahora reclasificados como REDUNDANTES):
- `auto-save-context.sh` — ya marcado como CONSOLIDATE, ahora → ELIMINAR
- `auto-checkpoint.sh` — marcado como REGISTER, ahora → ELIMINAR (nativo lo hace)
- `context-injector.sh` — marcado como CONSOLIDATE, ahora → ELIMINAR
- `session-start-context-visible.sh` — marcado como CONSOLIDATE, ahora → ELIMINAR
- `session-start-context-zai.sh` — marcado como CONSOLIDATE, ahora → ELIMINAR
- `validate-lsp-servers.sh` — marcado como REGISTER, ahora → ELIMINAR
- `usage-consolidate.sh` — marcado como CONSOLIDATE, ahora → ELIMINAR

**Actualización de números**:
- Hooks a eliminar: 2 (obsoletos) + 7 (redundantes con nativo) = **9 total**
- Hooks a consolidar: 22 - 5 (reclasificados como eliminar) = **17 consolidaciones**
- Hooks a registrar: 23 - 2 (reclasificados como eliminar) = **21 registros nuevos**
- **Resultado final**: 106 - 9 eliminados - 17 consolidados = **~80 hooks** (24% reducción)
- Cobertura de registro: **~75%** (vs 48% actual)

### Cuidado con Auto-Memory vs Vault

Claude Code Auto-Memory (v2.1.59+) ya:
- Escribe notas a `~/.claude/projects/<project>/memory/MEMORY.md`
- Las carga automáticamente al inicio de cada sesión
- Tiene límite de 25KB + 200 líneas

**Nuestro vault system NO duplica Auto-Memory**. Son complementarios:

| Aspecto | Auto-Memory (nativo) | Vault (nuestro) |
|---|---|---|
| Scope | Per-project, ephemeral notes | Cross-project, structured wiki |
| Formato | Flat MEMORY.md (25KB limit) | Directorio de .md con backlinks |
| Clasificación | Ninguna | GREEN/YELLOW/RED |
| Graduation | No promueve a rules | Promueve a .claude/rules/learned/ |
| Compilación | No compila | LLM compila raw/ → wiki/ |
| Multi-proyecto | Aislado por proyecto | global/ + projects/ con sharing |

**Decision**: Auto-Memory sigue siendo la capa ephemeral (notas rápidas de sesión). Vault es la capa curated (knowledge compounding de Karpathy). No se duplican.

---

## Extras Descubiertos en Auditoría

### Hooks Dormantes (43 de 103)
40% de los hooks en `.claude/hooks/` NO están registrados en settings.json. Incluyen hooks potencialmente útiles como `continuous-learning.sh`, `episodic-auto-convert.sh`, `batch-progress-tracker.sh`. Se recomienda auditoría trimestral.

### Rules Thin (22 reglas en 7 categorías)
`.claude/rules/learned/` tiene solo 22 reglas auto-aprendidas. Categorías faltantes: performance, accessibility, architecture, patterns, vault. El pipeline vault→graduation expandirá esto progresivamente.

### API Key Expuesta
`settings.json` contiene API key en plaintext (`sk-cp-O39X...`). Riesgo si hooks de vault leen/logean este archivo. Mover a variable de entorno.

---

## Research Sources

- [Karpathy LLM Knowledge Bases](https://x.com/karpathy/status/2039805659525644595) — [Analysis](https://antigravity.codes/blog/karpathy-llm-knowledge-bases)
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — 19 skills, 6 phases
- [VoltAgent/awesome-design-md](https://github.com/VoltAgent/awesome-design-md) — 55+ DESIGN.md
- [godofprompt Aristotle](https://x.com/godofprompt/status/2037606967766643044) — First Principles Deconstructor
- [DataChaz tweet](https://x.com/DataChaz/status/2039963758790156555) — Agent skills ecosystem

---

## Addenda (Approved Deviations)

### Addendum A1: Statusline Plan Progress Display (2026-04-04)

**Requested by**: User
**Reason**: Visibility into which plan step is currently executing, directly in the terminal statusline.

**Implementation**:
1. Create `.claude/plan-state.json` with all Herding Blanket items as steps (0a through 15)
2. Enhance `get_ralph_progress()` in `.claude/scripts/statusline-ralph.sh` to display the **current step name** (not just `3/7 42%` but `🔄 0b Hook Audit 2/16 12%`)
3. Update `plan-state.json` as each item is completed during implementation

**New statusline format**:
```
⎇ main* │ TokenUsed: 818k │ ██████░░░░ CtxUse: 120k/200k (60%) │ 🔄 0b Hook Audit 2/16 12%
```

**No plan items are modified.** This is additive infrastructure for visibility.

### Addendum A2: MCP Global Installation Validation (2026-04-04)

**Requested by**: User
**Reason**: Ensure required MCP servers are installed globally (per-user) before skills that depend on them can function.

**Implementation**:
1. Create `scripts/validate-mcp-servers.sh` — checks that required MCP servers are configured in settings.json
2. Add validation to `project-state.sh` (SessionStart hook) — warn if critical MCPs are missing
3. Required MCPs for the plan:
   - `playwright` — browser-test, ralph-frontend (browser automation)
   - `context7` — library docs fetching
   - `chrome_devtools` — browser-test, perf (Chrome DevTools Protocol)
   - `filesystem` — vault (MCP filesystem access to vault directory)
   - `MiniMax` — image analysis, visual validation
   - `zai-mcp-server` — vision tools, web search
   - `web-search-prime` — research
   - `web-reader` — web content extraction
4. Validation output: list of installed vs missing MCPs with installation instructions
5. Run on: SessionStart (advisory, non-blocking) and `/ship` checklist (Item 11, advisory)

**No plan items are modified.** This adds infrastructure validation.

### Addendum A3: ralph-security Agent Teams Teammate (2026-04-04)

**Requested by**: User
**Reason**: Consolidate all security capabilities into a dedicated Agent Teams teammate for comprehensive security reviews of both plans and code.

**Implementation**:
1. Create `.claude/agents/ralph-security.md` — New teammate combining:
   - `/sec-context-depth` (27 security anti-patterns)
   - `/security-threat-model` (STRIDE threat modeling)
   - `/senior-secops` (SecOps operations)
   - `/senior-security` (application security)
   - `/security` (Codex + MiniMax audit)
   - `/security-loop` (iterative audit until zero vulns)
   - `/security-audit` (assessment workflow)
   - `/security-best-practices` (language-specific)
   - `/vulnerability-scanner` (OWASP 2025)
   - `/defense-profiler` (codebase defense analysis)
   - `/tap-explorer` (tree of attacks)
   - Security hooks: `git-safety-guard.py`, `sanitize-secrets.js`, `security-full-audit.sh`

2. Quality Pillars for ralph-security:
   - THREAT MODEL: STRIDE analysis grounded in repo evidence
   - CODE AUDIT: 27 sec-context anti-patterns + OWASP Top 10
   - SECRETS: Scan for plaintext credentials, API keys, tokens
   - DEPENDENCIES: CVE audit of all packages
   - PLAN REVIEW: Security implications of architectural decisions
   - HOOKS INTEGRITY: Verify security hooks are registered and functional

3. Integration:
   - Orchestrator Step 7 (VALIDATE): invoke ralph-security for complexity >= 6
   - `/ship` checklist: security audit is BLOCKING (not advisory)
   - `/adversarial`: ralph-security as Strategist for security vectors
   - Agent Teams SubagentStart matcher: `ralph-*` (existing)

4. Add to CLAUDE.md Teammate Types table
5. Create symlinks to 6 platform directories

**This is a new item for Fase Gamma (post-plan implementation).**
