# Ralph Loop v2.33 - Sentry Skills Integration

## Executive Summary

Integración completa de **Sentry Skills** en multi-agent-ralph-loop aprovechando las capacidades de Claude Code v2.1.0 (context: fork, hooks en frontmatter, hot-reload) para:

- **Pre-Deployment**: Detección temprana de bugs vía sentry-code-review skill
- **Development**: Auto-instrumentación con AI monitoring, logging, metrics, tracing
- **Post-Deployment**: Iteración automática basada en feedback de Sentry
- **Quality Loop**: Ralph Loop pattern reforzado con validación de Sentry

---

## 1. Sentry Skills Disponibles

### 1.1 Skills Oficiales de Sentry (Plugin)

| Skill | Propósito | Cuándo Usar |
|-------|-----------|-------------|
| **sentry-code-review** | Resuelve bugs en PRs basándose en comentarios de Sentry bot | Code review, iterate-pr, pre-merge |
| **sentry-setup-ai-monitoring** | Instrumenta llamadas LLM (OpenAI, Anthropic, etc.) | Setup inicial, nuevos proyectos AI |
| **sentry-setup-logging** | Configura captura de logs estructurados | Setup inicial, debugging |
| **sentry-setup-metrics** | Configura métricas custom (counters, gauges, distributions) | Setup inicial, KPIs |
| **sentry-setup-tracing** | Configura performance monitoring y distributed tracing | Setup inicial, performance |

### 1.2 Skills Propias (Creadas Hoy)

| Skill | Propósito | Integración Sentry |
|-------|-----------|-------------------|
| **deslop** | Limpia código AI-generado (slop removal) | Aplica style guide de Sentry |
| **find-bugs** | Búsqueda de bugs con security checklist | Correlaciona con issues de Sentry |
| **iterate-pr** | Iteración hasta que CI pase | Espera y procesa checks de Sentry |

---

## 2. Integración en Orchestrator v2.33

### 2.1 Nuevos Steps en Mandatory Flow

**Actualización orchestrator.md:**

```markdown
## Mandatory Flow (Enhanced v2.33)

0. AUTO-PLAN    → EnterPlanMode (automatic for non-trivial)
1. /clarify     → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
2. /classify    → Complexity 1-10
2b. WORKTREE    → Ask user: "¿Requiere worktree aislado?"
**2c. SENTRY SETUP (NEW) → Si es proyecto nuevo, configurar observability**
3. PLAN         → Write plan, get user approval
4. @orchestrator → Delegate to subagents (in worktree if selected)
5. ralph gates  → Quality gates (9 languages + Sentry)
**5b. SENTRY VALIDATION (NEW) → Validar con sentry-code-review**
6. /adversarial → 2/3 consensus (complexity >= 7)
7. /retrospective → Propose improvements
**7b. SENTRY PR REVIEW (ENHANCED) → iterate-pr con Sentry feedback**
→ VERIFIED_DONE
```

### 2.2 Step 2c: SENTRY SETUP (Proyectos Nuevos)

**Cuando crear proyecto nuevo o agregar features AI/API:**

```yaml
# Orchestrator invoca skills de setup según tipo de proyecto
Task:
  subagent_type: "general-purpose"
  context: fork  # NEW v2.1.0
  prompt: |
    Analyze project type and setup Sentry observability.

    If project uses AI/LLM (OpenAI, Anthropic, LangChain, etc.):
      → Use skill: sentry-setup-ai-monitoring

    If project needs structured logging:
      → Use skill: sentry-setup-logging

    If project tracks custom metrics/KPIs:
      → Use skill: sentry-setup-metrics

    If project needs performance monitoring:
      → Use skill: sentry-setup-tracing

    Setup order:
    1. Tracing (base requirement)
    2. Logging (depends on tracing)
    3. AI Monitoring (depends on tracing)
    4. Metrics (optional)
```

**Decision Tree:**

```
┌────────────────────────────────────────┐
│ ¿Proyecto nuevo o feature inicial?    │
├────────────────────────────────────────┤
│ YES → Detectar tipo y setup Sentry    │
│  ├─ AI/LLM? → sentry-setup-ai-mon...  │
│  ├─ API/Backend? → sentry-setup-tra... │
│  ├─ Debugging? → sentry-setup-logging  │
│  └─ KPIs? → sentry-setup-metrics       │
│                                        │
│ NO → Skip (Sentry ya configurado)     │
└────────────────────────────────────────┘
```

### 2.3 Step 5b: SENTRY VALIDATION (Pre-Merge)

**Antes de adversarial review, validar con Sentry:**

```yaml
# Orchestrator invoca sentry-code-review skill
Task:
  subagent_type: "general-purpose"
  context: fork
  prompt: |
    Use skill: sentry-code-review

    Analyze PR changes and detect issues that Sentry would catch:
    - TypeError risks (None/null handling)
    - Missing error boundaries
    - Over-instrumentation (slop)
    - Missing validation

    Report:
    - Issues found (with severity)
    - Fixes applied
    - Manual review needed
```

**Integration con find-bugs:**

```yaml
# find-bugs skill actualizado
---
name: find-bugs
context: fork  # NEW v2.1.0
hooks:
  PostToolUse:
    - script: ~/.claude/hooks/sentry-correlation.sh
---

## Phase 6: Sentry Correlation (NEW v2.33)

After manual analysis, cross-reference with Sentry:

For each bug found locally:
  1. Check if Sentry would catch it
     → TypeError/ValidationError patterns
     → Error handling gaps
  2. Use sentry-code-review skill for validation
  3. Add Sentry context to bug report
```

### 2.4 Step 7b: SENTRY PR REVIEW (Enhanced)

**iterate-pr skill mejorado con Sentry-first approach:**

```yaml
---
name: iterate-pr
context: fork  # NEW v2.1.0
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/git-branch-check.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/sentry-check-status.sh
---

# Iterate PR v2.33 - Sentry-First

## Step 2: Sentry Checks Priority (ENHANCED)

```bash
# Wait specifically for Sentry checks FIRST
gh pr checks --watch --json name,state \
  --jq '.[] | select(.name | test("sentry|seer|bugbot"))'

echo "⏳ Waiting for Sentry analysis..."
# Sentry bot puede tardar 2-5 min en analizar y comentar

while true; do
  SENTRY_STATUS=$(gh pr checks --json name,state \
    --jq '.[] | select(.name == "sentry-io") | .state')

  if [[ "$SENTRY_STATUS" != "pending" ]]; then
    break
  fi

  sleep 30
done

echo "✅ Sentry checks completed"
```

## Step 3: Sentry-First Feedback (NEW)

### Priority 1: Sentry Bot Comments

```bash
# Fetch Sentry bot comments
gh api "repos/{owner}/{repo}/pulls/{pr}/comments" \
  --jq '.[] | select(.user.login | startswith("sentry"))'
```

**If Sentry comments exist:**

```yaml
Task:
  subagent_type: "general-purpose"
  context: fork
  prompt: |
    Use skill: sentry-code-review

    Fix all Sentry bot comments in PR #{pr}

    Process:
    1. Parse Sentry comments (severity, confidence)
    2. Read affected files
    3. Apply fixes
    4. Commit: "fix(sentry): <issue description>"
```

### Priority 2: Human + Other Bot Feedback

Only after Sentry issues fixed:
```bash
gh pr view --json reviews,comments
gh api "repos/{owner}/{repo}/issues/{pr}/comments"
```

## Step 10: Sentry Resolution Report (NEW)

```bash
cat > .ralph/sentry-pr-report.md <<EOF
## Sentry PR Analysis

**PR:** #$PR_NUMBER
**Iterations:** $ITERATIONS

### Sentry Issues Addressed

$(# List Sentry comments and their resolution status)

### Sentry Checks Status

$(gh pr checks --json name,conclusion \
  --jq '.[] | select(.name | test("sentry")) | "- \(.name): \(.conclusion)"')

### Recommendation

$(if [[ all_sentry_checks_pass ]]; then
  echo "✅ All Sentry validations passed. Safe to merge."
else
  echo "⚠️ Some Sentry checks failing. Manual review needed."
fi)
EOF
```
```

---

## 3. Flujos Optimizados v2.33

### 3.1 Flujo de Code Review (Sentry-Enhanced)

```
┌──────────────────────────────────────────────────────────────┐
│           CODE REVIEW FLOW v2.33 - SENTRY SKILLS             │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Phase 1: LOCAL ANALYSIS                                    │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Skill: find-bugs (context: fork)                       │ │
│  │ ├─ Security checklist                                  │ │
│  │ └─ Hook: sentry-correlation.sh                         │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Phase 2: WAIT FOR SENTRY BOT (NEW)                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ gh pr checks --watch | grep sentry-io                  │ │
│  │ Wait 2-5 min for Sentry analysis                       │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Phase 3: SENTRY SKILL AUTO-FIX (NEW)                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Skill: sentry-code-review (context: fork)              │ │
│  │ ├─ Parse Sentry bot comments                           │ │
│  │ ├─ Apply fixes (high confidence)                       │ │
│  │ ├─ Ask user (low confidence)                           │ │
│  │ └─ Commit fixes                                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Phase 4: DESLOP (Clean AI Artifacts)                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Skill: deslop (context: fork)                          │ │
│  │ ├─ Remove over-instrumentation                         │ │
│  │ ├─ Remove redundant Sentry.capture*                    │ │
│  │ └─ Follow Sentry best practices                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Phase 5: TRADITIONAL REVIEW                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Multi-Agent (Claude Opus + Codex + MiniMax)            │ │
│  │ 2/3 Consensus → Approve                                │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Phase 6: ITERATE UNTIL GREEN                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Skill: iterate-pr (context: fork)                      │ │
│  │ Loop until all Sentry checks pass                      │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│                    READY TO MERGE                            │
└──────────────────────────────────────────────────────────────┘
```

**Commands:**

```bash
# Full Sentry-aware code review
ralph code-review-sentry <pr-number>

# Internals:
# 1. Skill: find-bugs (local analysis + hook)
# 2. Wait for Sentry bot (gh pr checks --watch)
# 3. Skill: sentry-code-review (auto-fix)
# 4. Skill: deslop (clean slop)
# 5. Multi-agent review (Opus + Codex + MiniMax)
# 6. Skill: iterate-pr (until green)
```

### 3.2 Flujo de Setup (Nuevo Proyecto)

```
┌──────────────────────────────────────────────────────────────┐
│          NEW PROJECT SETUP v2.33 - SENTRY SKILLS             │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 1: DETECT PROJECT TYPE                                │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Orchestrator analyzes:                                 │ │
│  │ ├─ AI/LLM? (package.json: openai, anthropic, etc.)    │ │
│  │ ├─ API/Backend? (Express, FastAPI, Django, etc.)      │ │
│  │ ├─ Frontend? (React, Next.js, Vue, etc.)              │ │
│  │ └─ Full-stack? (Multiple of above)                    │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Step 2: SENTRY TRACING (Base Requirement)                  │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Skill: sentry-setup-tracing (context: fork)            │ │
│  │ ├─ Detect platform (JS/Python/Ruby)                   │ │
│  │ ├─ Configure Sentry.init() with tracesSampleRate      │ │
│  │ ├─ Add integrations (browserTracing, etc.)            │ │
│  │ └─ Test: Send test transaction                        │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Step 3: SPECIALIZED OBSERVABILITY (Based on Type)          │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ If AI/LLM Project:                                     │ │
│  │   Skill: sentry-setup-ai-monitoring (context: fork)   │ │
│  │   ├─ Detect AI SDKs (OpenAI, Anthropic, etc.)         │ │
│  │   ├─ Add AI integrations (openAIIntegration, etc.)    │ │
│  │   ├─ Configure token tracking                         │ │
│  │   └─ Test: Send test LLM call                         │ │
│  │                                                        │ │
│  │ If API/Backend Project:                               │ │
│  │   Skill: sentry-setup-logging (context: fork)         │ │
│  │   ├─ Enable enableLogs: true                          │ │
│  │   ├─ Configure log levels                             │ │
│  │   └─ Test: Send test log                              │ │
│  │                                                        │ │
│  │ If KPI Tracking Needed:                               │ │
│  │   Skill: sentry-setup-metrics (context: fork)         │ │
│  │   ├─ Verify SDK version (10.25.0+)                    │ │
│  │   ├─ Instrument metrics (counters, gauges, etc.)      │ │
│  │   └─ Test: Send test metric                           │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Step 4: VALIDATION                                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ├─ Check Sentry dashboard for test data               │ │
│  │ ├─ Verify all integrations active                     │ │
│  │ └─ Document setup in README                           │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│                  SENTRY FULLY CONFIGURED                     │
└──────────────────────────────────────────────────────────────┘
```

**Commands:**

```bash
# Auto-setup Sentry based on project type
ralph sentry-init

# Internals:
# 1. Detect project type (AI, API, Frontend, Full-stack)
# 2. Skill: sentry-setup-tracing (base)
# 3. Skill: sentry-setup-ai-monitoring (if AI)
# 4. Skill: sentry-setup-logging (if API)
# 5. Skill: sentry-setup-metrics (if KPIs needed)
# 6. Validate + document
```

### 3.3 Flujo de Deploy (Sentry Release Tracking)

```
┌──────────────────────────────────────────────────────────────┐
│        DEPLOY FLOW v2.33 - SENTRY RELEASE TRACKING           │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 1: PRE-DEPLOY VALIDATION                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ralph pre-merge (existing)                             │ │
│  │ + Skill: sentry-code-review (validation)               │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Step 2: CREATE SENTRY RELEASE                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ VERSION=$(jq -r '.version' package.json)               │ │
│  │ sentry-cli releases new "$VERSION"                     │ │
│  │ sentry-cli releases set-commits "$VERSION" --auto      │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Step 3: DEPLOY                                             │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ ./deploy.sh <environment>                              │ │
│  │ sentry-cli releases finalize "$VERSION"                │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Step 4: POST-DEPLOY MONITORING (NEW)                       │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ # Wait 5 min for errors to surface                     │ │
│  │ sleep 300                                              │ │
│  │                                                        │ │
│  │ # Check Sentry for new issues via skill               │ │
│  │ Task:                                                  │ │
│  │   context: fork                                        │ │
│  │   prompt: |                                            │ │
│  │     Query Sentry for issues in last 5 min             │ │
│  │     Release: $VERSION                                  │ │
│  │     Report: New errors, user impact, rollback rec     │ │
│  └────────────────────────────────────────────────────────┘ │
│                          │                                   │
│                          ▼                                   │
│  Step 5: DECISION GATE                                      │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ Critical errors (>50 users)?                           │ │
│  │ YES → ROLLBACK                                         │ │
│  │ NO  → MONITOR & FORWARD FIX                            │ │
│  └────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 4. Skills Integration Matrix v2.33

### 4.1 Cuándo Usar Cada Skill

| Fase | Skill | Triggered By | Output |
|------|-------|--------------|--------|
| **Setup** | sentry-setup-tracing | Proyecto nuevo / feature inicial | Sentry.init() configurado |
| **Setup** | sentry-setup-ai-monitoring | Detecta OpenAI/Anthropic/etc. | AI integrations + token tracking |
| **Setup** | sentry-setup-logging | API/Backend project | enableLogs: true, structured logs |
| **Setup** | sentry-setup-metrics | KPI tracking needed | Metrics API configured |
| **Dev** | find-bugs | Code review request | Bug report + Sentry correlation |
| **Dev** | deslop | Post-implementation cleanup | Clean code, Sentry best practices |
| **Pre-Merge** | sentry-code-review | PR created, Sentry bot comments | Auto-fixes for Sentry issues |
| **Iteration** | iterate-pr | CI failures or review feedback | Loop until all checks pass |

### 4.2 Skills con context: fork (v2.1.0)

**Todas las skills deben usar `context: fork` para aislamiento:**

```yaml
# find-bugs
---
name: find-bugs
context: fork  # Contexto limpio para análisis
hooks:
  PostToolUse:
    - script: ~/.claude/hooks/sentry-correlation.sh
---

# deslop
---
name: deslop
context: fork  # No contaminar con slop analysis
---

# iterate-pr
---
name: iterate-pr
context: fork  # Aislamiento para cada iteración
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/git-branch-check.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/sentry-status.sh
---

# sentry-code-review (plugin)
---
name: sentry-code-review
context: fork  # Análisis aislado de Sentry comments
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, AskUserQuestion
---
```

### 4.3 Hooks Personalizados para Sentry

**Crear hooks en ~/.claude/hooks/ para automatización:**

```bash
# ~/.claude/hooks/sentry-correlation.sh
#!/usr/bin/env bash
# Correlaciona bugs locales con issues de Sentry
# Triggered PostToolUse en find-bugs skill

BUGS_FILE=".ralph/find-bugs-output.md"

if [[ ! -f "$BUGS_FILE" ]]; then
  exit 0
fi

echo "🔍 Correlacionando con Sentry..."

# Extract bug patterns and query Sentry
# (usa MCP internally si es necesario, pero desde el punto de vista
#  del hook, solo procesa output de find-bugs)

# Add Sentry correlation section to report
cat >> "$BUGS_FILE" <<EOF

## Sentry Correlation

$(# Aquí iría lógica de correlation con Sentry data)
EOF
```

```bash
# ~/.claude/hooks/sentry-check-status.sh
#!/usr/bin/env bash
# Verifica status de Sentry checks en PR
# Triggered PostToolUse en iterate-pr skill

echo "📊 Checking Sentry status..."

if ! command -v gh &>/dev/null; then
  echo "⚠️ gh CLI not available, skipping Sentry check"
  exit 0
fi

# Check if we're in a PR context
PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null || echo "")

if [[ -z "$PR_NUMBER" ]]; then
  echo "ℹ️ Not in PR context, skipping"
  exit 0
fi

# Check Sentry-related checks
SENTRY_CHECKS=$(gh pr checks --json name,state,conclusion \
  --jq '.[] | select(.name | test("sentry|seer")) |
    "\(.name): \(.conclusion)"')

if [[ -n "$SENTRY_CHECKS" ]]; then
  echo "Sentry Checks:"
  echo "$SENTRY_CHECKS"
else
  echo "✅ No Sentry checks found or all passing"
fi
```

---

## 5. Implementación v2.33

### 5.1 Migration Checklist

- [ ] **Install Sentry Plugin**
  ```bash
  /plugin marketplace add getsentry/sentry-for-claude
  /plugin install sentry@getsentry
  # Restart Claude Code
  /help  # Verify sentry-* skills available
  ```

- [ ] **Add context: fork to Existing Skills**
  ```bash
  # Update find-bugs
  echo "context: fork" >> ~/.claude/skills/find-bugs/skill.md

  # Update deslop
  echo "context: fork" >> ~/.claude/skills/deslop/SKILL.md

  # Update iterate-pr
  echo "context: fork" >> ~/.claude/skills/iterate-pr/SKILL.md
  ```

- [ ] **Create Sentry Hooks**
  ```bash
  # Create hooks directory if not exists
  mkdir -p ~/.claude/hooks

  # Create sentry-correlation.sh
  # Create sentry-check-status.sh
  # Create sentry-setup-validation.sh

  chmod +x ~/.claude/hooks/sentry-*.sh
  ```

- [ ] **Update orchestrator.md**
  - Add Step 2c: SENTRY SETUP
  - Add Step 5b: SENTRY VALIDATION
  - Enhance Step 7b: SENTRY PR REVIEW
  - Add hooks in frontmatter:
    ```yaml
    hooks:
      PreToolUse:
        - script: ~/.claude/hooks/orchestrator-init.sh
          once: true
      Stop:
        - script: ~/.claude/hooks/sentry-report.sh
    ```

- [ ] **Update find-bugs Skill**
  - Add Phase 0: Sentry Pre-Check (opcional)
  - Add Phase 6: Sentry Correlation
  - Add hook: sentry-correlation.sh (PostToolUse)

- [ ] **Update iterate-pr Skill**
  - Add Sentry priority in Step 2
  - Add Sentry-first feedback in Step 3
  - Add Step 10: Sentry Resolution Report
  - Add hook: sentry-check-status.sh (PostToolUse)

- [ ] **Update deslop Skill**
  - Add Sentry-specific anti-patterns section
  - Add examples of over-instrumentation to remove

- [ ] **Create New Ralph Commands**
  ```bash
  # ralph sentry-init → Skill: sentry-setup-* (auto-detect)
  # ralph sentry-validate → Skill: sentry-code-review
  # ralph code-review-sentry → Full flow with Sentry skills
  ```

- [ ] **Update Wildcard Permissions**
  ```json
  {
    "allowedTools": [
      "Bash(gh pr *)",
      "Bash(gh api *)",
      "Bash(sentry-cli *)",
      "Bash(npm *)",
      "Bash(git *)"
    ]
  }
  ```

- [ ] **Test Workflows**
  - Test: Setup nuevo proyecto con sentry-init
  - Test: Code review con sentry-code-review
  - Test: Iterate PR con Sentry checks
  - Test: Deploy con release tracking

- [ ] **Documentation**
  - Update README.md con Sentry skills
  - Update CLAUDE.md con nuevos commands
  - Create SENTRY_SKILLS_GUIDE.md (usage examples)

### 5.2 Backward Compatibility

✅ **v2.33 es 100% compatible con v2.32:**

- Todos los comandos existentes funcionan sin cambios
- Sentry skills son **opt-in** (requieren plugin install)
- context: fork es opcional (default: shared context)
- Hooks en frontmatter son opcionales (fallback: settings.json)

**Migración gradual:**

```
Week 1: Install Sentry plugin → Test skills manualmente
Week 2: Add context: fork → Mejor aislamiento
Week 3: Create hooks → Automatización
Week 4: Update orchestrator → Flujo completo integrado
Week 5: Deploy to production → Métricas de éxito
```

---

## 6. Métricas de Éxito v2.33

### 6.1 Developer Experience

| Métrica | v2.32 | v2.33 Target | Mejora |
|---------|-------|--------------|--------|
| **Time to detect bug** | Post-deploy | Pre-commit (Sentry bot) | 100x |
| **PR iteration cycles** | 4-6 | 2-3 (auto-fix) | 2x |
| **Setup observability** | 2-3 hours manual | 10 min (skills) | 12x |
| **False positive rate** | 20-30% | <10% (Sentry confidence) | 2-3x |

### 6.2 Code Quality

| Aspecto | v2.32 | v2.33 |
|---------|-------|-------|
| **Bug detection** | Local analysis | Local + Sentry production data |
| **Instrumentation** | Manual | Automated (sentry-setup-* skills) |
| **AI monitoring** | Not available | Auto-configured (AI projects) |
| **Code slop** | Manual cleanup | Automated (deslop + Sentry style) |

### 6.3 Quality Gates

**v2.33 agrega Sentry Quality Gate:**

```
┌───────────────────────────────────────────────┐
│         QUALITY GATES v2.33                   │
├───────────────────────────────────────────────┤
│ 1. Language gates (9 languages)              │
│    ├── TypeScript: tsc, eslint               │
│    ├── Python: pyright, ruff                 │
│    └── ... (Go, Rust, Solidity, etc.)        │
│                                               │
│ 2. Security gates                             │
│    ├── git-safety-guard.py                   │
│    └── Skill: find-bugs (checklist)          │
│                                               │
│ 3. Sentry gates (NEW v2.33)                  │
│    ├── Skill: sentry-code-review ✅           │
│    ├── CI sentry checks passing ✅            │
│    └── No critical Sentry bot comments ✅     │
│                                               │
│ 4. Slop gates (NEW v2.33)                    │
│    └── Skill: deslop (Sentry style) ✅        │
│                                               │
│ 5. Adversarial validation (complexity >= 7)  │
│    └── 2/3 consensus (Claude + Codex + MCP)  │
└───────────────────────────────────────────────┘
```

---

## 7. Skills vs MCP: Cuando Usar Cada Uno

### 7.1 Hierarchy

```
┌──────────────────────────────────────────┐
│          USER / ORCHESTRATOR             │
├──────────────────────────────────────────┤
│ Invoca SKILLS (high-level abstractions)  │
│                                          │
│ ┌─────────────────────────────────────┐  │
│ │ Skill: sentry-code-review           │  │
│ │ Skill: sentry-setup-ai-monitoring   │  │
│ │ Skill: find-bugs                    │  │
│ │ Skill: iterate-pr                   │  │
│ └─────────────┬───────────────────────┘  │
│               │                           │
│               ▼                           │
│ Skills internamente usan:                 │
│ ┌─────────────────────────────────────┐  │
│ │ MCP Tools (low-level primitives)    │  │
│ │ - mcp__sentry__getIssues            │  │
│ │ - mcp__sentry__analyze               │  │
│ │ - Read, Edit, Write, Bash           │  │
│ └─────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

### 7.2 Decision Matrix

| Escenario | Use | Reason |
|-----------|-----|--------|
| **Análisis de issues en PR** | Skill: sentry-code-review | Workflow completo (parse, fix, commit) |
| **Setup inicial de tracing** | Skill: sentry-setup-tracing | Detecta platform, configura correctamente |
| **Cleanup de código AI** | Skill: deslop | Context sobre Sentry best practices |
| **Iteración en PR con CI** | Skill: iterate-pr | Workflow completo con Sentry checks |
| **Query simple a Sentry** | MCP: /seer | Quick query, no workflow needed |
| **Fetch issues directamente** | MCP: /getIssues | Simple data retrieval |

**Regla general:**

- **Skills** = Workflows complejos, multi-step, domain knowledge
- **MCP** = Primitivas simples, single operation, data retrieval

---

## 8. Ejemplo Completo: Feature con Sentry v2.33

### Scenario: "Implementar sistema de rate limiting con observability"

```bash
# 1. Usuario inicia tarea
/orchestrator "Implement rate limiting with Sentry observability"

# Orchestrator internals:

# Step 0: AUTO-PLAN
EnterPlanMode

# Step 1: CLARIFY
AskUserQuestion:
  - Rate limiting strategy? (Token bucket, Fixed window, Sliding window)
  - Observability level? (Metrics + Logging + Tracing)
  - Backend framework? (Express, FastAPI, Django)

# User answers: Token bucket, Full observability, Express

# Step 2: CLASSIFY
Complexity: 7 (multi-component, observability setup, testing)

# Step 2b: WORKTREE
AskUserQuestion: "¿Requiere worktree aislado?"
User: Sí

ralph worktree "rate-limiting"
cd .worktrees/ai-ralph-20260108-rate-limiting/

# Step 2c: SENTRY SETUP (NEW v2.33)
# Orchestrator detecta: Express backend, necesita metrics + tracing

Task:
  context: fork
  prompt: |
    Skill: sentry-setup-tracing
    Configure performance monitoring for Express

Task:
  context: fork
  prompt: |
    Skill: sentry-setup-metrics
    Setup rate limit metrics:
    - Counter: rate_limit_hits
    - Counter: rate_limit_exceeded
    - Distribution: request_processing_time

Task:
  context: fork
  prompt: |
    Skill: sentry-setup-logging
    Setup structured logging for rate limit events

# Step 3: PLAN
# Orchestrator escribe plan detallado y pide aprobación
ExitPlanMode

# Step 4: DELEGATE
# Subagents implementan rate limiting + instrumentación

Task(code-reviewer): "Implement token bucket algorithm"
Task(test-architect): "Write tests for rate limiting"
Task(docs-writer): "Document rate limit configuration"

# Step 5: VALIDATE
ralph gates  # Language gates pass

# Step 5b: SENTRY VALIDATION (NEW v2.33)
Task:
  context: fork
  prompt: |
    Skill: sentry-code-review
    Validate implementation:
    - Are metrics instrumented correctly?
    - Is logging structured?
    - Are edge cases handled?

# Step 6: ADVERSARIAL (Complexity 7)
ralph adversarial src/rate-limit/
# 2/3 consensus → Approve

# Step 7: RETROSPECTIVE
ralph retrospective

# Step 7b: SENTRY PR REVIEW (NEW v2.33)
ralph worktree-pr ai/ralph/20260108-rate-limiting

# Wait for Sentry bot...
gh pr checks --watch | grep sentry

# Sentry bot comments: "Missing error handling in rate limit exceeded case"

# Auto-fix with skill
Task:
  context: fork
  prompt: |
    Skill: sentry-code-review
    Fix Sentry issues in PR

# Iterate until green
Task:
  context: fork
  prompt: |
    Skill: iterate-pr
    Loop until all Sentry checks pass

# VERIFIED_DONE ✅
```

**Result:**
- Rate limiting implementado ✅
- Sentry tracing configured ✅
- Metrics instrumentados (counters + distributions) ✅
- Logging estructurado ✅
- All Sentry checks passing ✅
- Ready to merge ✅

---

## 9. Conclusiones

### Key Wins v2.33:

1. **Skills-First Approach**: Workflows complejos encapsulados en skills reutilizables
2. **Context Isolation**: `context: fork` garantiza análisis limpio sin contaminación
3. **Sentry Integration**: Observability desde desarrollo hasta producción
4. **Auto-Instrumentation**: Skills de setup reducen time-to-observability de horas a minutos
5. **Pre-Commit Validation**: Sentry bot detecta issues antes de merge

### Adoption Path:

```
Week 1: Install plugin + test skills manualmente
Week 2: Add context: fork a skills existentes
Week 3: Create custom hooks para automation
Week 4: Integrate en orchestrator (2c, 5b, 7b)
Week 5: Deploy + collect metrics
```

### Expected ROI:

- **100x faster** bug detection (pre-commit vs post-deploy)
- **12x faster** observability setup (10 min vs 2-3 hours)
- **50% fewer** PR iteration cycles (Sentry auto-fix)
- **2-3x reduction** en false positives (Sentry confidence scores)

---

## 10. Next Steps

1. ✅ Review este documento con el equipo
2. ⏳ Priorizar skills de mayor impacto (sentry-code-review + iterate-pr)
3. ⏳ Install Sentry plugin y test workflows
4. ⏳ Create custom hooks para automation
5. ⏳ Update orchestrator con nuevos steps
6. ⏳ Collect metrics y iterar

**¿Questions? Feedback?** → Este documento es living doc, seguir iterando.
