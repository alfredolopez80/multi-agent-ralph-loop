# Sentry: Skills vs MCP - Clarificación

## TL;DR

**NO todas las skills de Sentry usan MCP.** Hay 3 tipos de componentes:

| Componente | USA MCP? | Qué Hace |
|------------|----------|----------|
| **Skills de Setup** | ❌ NO | Editan código para configurar Sentry SDK |
| **Skill sentry-code-review** | ❌ NO | Lee comentarios de Sentry bot vía GitHub API |
| **Agent issue-summarizer** | ✅ SÍ | Analiza issues de Sentry vía MCP tools |
| **Commands** (/seer, /getIssues) | ✅ SÍ | Queries a Sentry API vía MCP |

---

## 1. Skills de Setup (NO usan MCP)

### ¿Qué hacen?

Estas skills **editan tu código fuente** para agregar configuración de Sentry SDK:

**Skills:**
- `sentry-setup-tracing`
- `sentry-setup-logging`
- `sentry-setup-metrics`
- `sentry-setup-ai-monitoring`

**allowed-tools:** (según frontmatter)
```yaml
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, AskUserQuestion
```

**Ejemplo - sentry-setup-tracing:**

```javascript
// ANTES (tu código)
import express from 'express';
const app = express();

// DESPUÉS (skill edita tu código)
import * as Sentry from "@sentry/node";
import express from 'express';

Sentry.init({
  dsn: "YOUR_DSN_HERE",
  tracesSampleRate: 1.0,  // ← Agregado por skill
});

const app = express();
```

**NO usa MCP porque:**
- No necesita consultar Sentry API
- Solo modifica archivos locales (Read, Edit, Write)
- Detecta platform (package.json, requirements.txt) con Bash/Grep

---

## 2. Skill sentry-code-review (NO usa MCP)

### ¿Qué hace?

Lee **comentarios de Sentry bot en GitHub PRs** y aplica fixes.

**allowed-tools:**
```yaml
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, WebFetch, AskUserQuestion
```

**Cómo funciona:**

```bash
# 1. Fetch comments de Sentry bot via GitHub API (NO Sentry MCP)
gh api repos/{owner}/{repo}/pulls/<PR>/comments \
  --jq '.[] | select(.user.login | startswith("sentry"))'

# 2. Parse comment body (markdown/HTML)
# Extrae: severity, confidence, fix suggestion

# 3. Read archivo afectado
Read: src/auth/login.py

# 4. Apply fix
Edit: src/auth/login.py

# 5. Commit
Bash: git commit -m "fix(sentry): handle None in get_user"
```

**NO usa MCP porque:**
- Comentarios están en GitHub, no en Sentry API
- Usa `gh` CLI (GitHub API) en lugar de Sentry MCP
- Solo edita código local basándose en comentarios

---

## 3. Agent issue-summarizer (SÍ usa MCP)

### ¿Qué hace?

Analiza múltiples issues de Sentry para generar reportes.

**Frontmatter:**
```yaml
name: issue-summarizer
tools: Read, Grep, Glob, Bash, WebFetch
model: sonnet
```

**Documentación explícita:**
```
## Step 1: Fetch issues using Sentry MCP tools
   - Request issue details including events, stack traces, and metadata
   - Gather data for all issues in parallel for efficiency
```

**Cómo funciona:**

```yaml
# 1. Query Sentry API vía MCP
mcp__sentry__list_issues:
  project: "my-app"
  status: "unresolved"
  limit: 20

# 2. Fetch details para cada issue
mcp__sentry__get_issue_details:
  issue_id: "ISSUE-123"

# 3. Analiza patterns, user impact, root cause
# 4. Genera reporte
```

**SÍ usa MCP porque:**
- Necesita data de Sentry (issues, events, stack traces)
- MCP proporciona acceso a Sentry API
- No solo lee comentarios, sino data completa de issues

---

## 4. Commands /seer y /getIssues (SÍ usan MCP)

### /seer (Natural Language Query)

**Documentación:**
```
### Step 2: Use Sentry MCP Tools

Query the Sentry MCP server using the appropriate tools:
- Fetch issues, projects, events, or statistics
```

**Ejemplo:**
```bash
/seer What are the top errors in last 24 hours?

# Internamente:
mcp__sentry__search_issues:
  query: "is:unresolved"
  time_range: "24h"
  sort: "event_count"
  limit: 10
```

### /getIssues

**Ejemplo:**
```bash
/getIssues my-project

# Internamente:
mcp__sentry__list_issues:
  project: "my-project"
  limit: 10
  sort: "recent"
```

---

## 5. ¿Cuándo se Necesita Sentry MCP?

### MCP Requerido:

✅ **issue-summarizer agent** → Análisis de issues
✅ **/seer command** → Natural language queries
✅ **/getIssues command** → Fetch issues directos

### MCP NO Requerido:

❌ **sentry-setup-*** skills → Solo editan código
❌ **sentry-code-review** skill → Usa GitHub API

---

## 6. Arquitectura Completa

```
┌────────────────────────────────────────────────────────┐
│                 SENTRY PLUGIN ECOSYSTEM                │
├────────────────────────────────────────────────────────┤
│                                                        │
│  ┌──────────────────────────────────────────────┐     │
│  │ SKILLS (NO usan MCP)                         │     │
│  │                                              │     │
│  │ ┌────────────────────────────────────────┐  │     │
│  │ │ sentry-setup-tracing                   │  │     │
│  │ │ sentry-setup-logging                   │  │     │
│  │ │ sentry-setup-metrics                   │  │     │
│  │ │ sentry-setup-ai-monitoring             │  │     │
│  │ │                                        │  │     │
│  │ │ Tools: Read, Edit, Write, Bash         │  │     │
│  │ │ ↓                                      │  │     │
│  │ │ Editan package.json, src/*.{ts,py}    │  │     │
│  │ └────────────────────────────────────────┘  │     │
│  │                                              │     │
│  │ ┌────────────────────────────────────────┐  │     │
│  │ │ sentry-code-review                     │  │     │
│  │ │                                        │  │     │
│  │ │ Tools: Read, Edit, Bash (gh api)       │  │     │
│  │ │ ↓                                      │  │     │
│  │ │ GitHub API (no Sentry API)             │  │     │
│  │ └────────────────────────────────────────┘  │     │
│  └──────────────────────────────────────────────┘     │
│                                                        │
│  ┌──────────────────────────────────────────────┐     │
│  │ AGENT (USA MCP)                              │     │
│  │                                              │     │
│  │ ┌────────────────────────────────────────┐  │     │
│  │ │ issue-summarizer                       │  │     │
│  │ │                                        │  │     │
│  │ │ Tools: Read, Bash, WebFetch            │  │     │
│  │ │ + Sentry MCP tools                     │  │     │
│  │ │ ↓                                      │  │     │
│  │ │ mcp__sentry__list_issues               │  │     │
│  │ │ mcp__sentry__get_issue_details         │  │     │
│  │ └────────────────────────────────────────┘  │     │
│  └──────────────────────────────────────────────┘     │
│                                                        │
│  ┌──────────────────────────────────────────────┐     │
│  │ COMMANDS (USAN MCP)                          │     │
│  │                                              │     │
│  │ /seer → Sentry MCP tools                     │     │
│  │ /getIssues → Sentry MCP tools                │     │
│  └──────────────────────────────────────────────┘     │
│                                                        │
│  ┌──────────────────────────────────────────────┐     │
│  │ SENTRY MCP SERVER                            │     │
│  │ (https://mcp.sentry.dev/mcp)                 │     │
│  │                                              │     │
│  │ Tools:                                       │     │
│  │ - list_issues                                │     │
│  │ - get_issue_details                          │     │
│  │ - search_issues                              │     │
│  │ - list_projects                              │     │
│  │ - get_events                                 │     │
│  └──────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────┘
```

---

## 7. Implicaciones para Ralph Loop v2.33

### Escenario 1: Setup Inicial (NO necesita MCP)

```bash
# Usuario quiere configurar Sentry en proyecto nuevo
/orchestrator "Setup Sentry observability"

# Orchestrator invoca:
Task:
  context: fork
  prompt: |
    Skill: sentry-setup-tracing
    # Skill edita código, NO usa MCP ✅

Task:
  context: fork
  prompt: |
    Skill: sentry-setup-ai-monitoring
    # Skill edita código, NO usa MCP ✅
```

**Resultado:** Sentry configurado SIN necesitar MCP.

### Escenario 2: Code Review (NO necesita MCP)

```bash
# PR tiene comentarios de Sentry bot
ralph worktree-pr ai/ralph/feature

# Internamente:
Task:
  context: fork
  prompt: |
    Skill: sentry-code-review
    # Usa gh CLI (GitHub API), NO Sentry MCP ✅
```

**Resultado:** Fixes aplicados SIN necesitar MCP.

### Escenario 3: Post-Deploy Analysis (SÍ necesita MCP)

```bash
# Después de deploy, analizar issues
ralph deploy-analysis

# Internamente:
Task:
  subagent_type: "issue-summarizer"
  context: fork
  prompt: |
    Analyze issues from last 5 min
    # NECESITA Sentry MCP ⚠️
```

**Resultado:** REQUIERE Sentry MCP configurado.

### Escenario 4: Natural Language Query (SÍ necesita MCP)

```bash
/seer Show critical errors in last 24h
# NECESITA Sentry MCP ⚠️
```

---

## 8. ¿Necesito Configurar Sentry MCP?

### Depende de qué features uses:

| Feature | Necesita MCP? |
|---------|---------------|
| **Setup inicial** (sentry-setup-*) | ❌ NO |
| **Code review** (sentry-code-review) | ❌ NO |
| **Deslop** (cleanup código) | ❌ NO |
| **Iterate PR** (esperar checks) | ❌ NO |
| **Post-deploy analysis** (issue-summarizer) | ✅ SÍ |
| **Natural language queries** (/seer) | ✅ SÍ |
| **/getIssues command** | ✅ SÍ |

### Configuración MCP (opcional para mayoría de casos):

```bash
# Solo si necesitas issue-summarizer o /seer
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp
```

**En la práctica:**
- 80% de uso de Ralph Loop → **NO necesita MCP**
- 20% (análisis post-deploy) → **Sí necesita MCP**

---

## 9. Recomendación v2.33

### Phase 1: Core Features (SIN MCP)

```bash
# Week 1-2: Setup + Code Review (NO MCP needed)
/plugin install sentry@getsentry

# Usa:
- sentry-setup-* (configurar proyectos)
- sentry-code-review (fix PRs)
- iterate-pr (CI loops)
- deslop (cleanup)
```

**Beneficio:** 80% del valor SIN configurar MCP.

### Phase 2: Advanced Analytics (CON MCP)

```bash
# Week 3-4: Post-deploy analysis
claude mcp add --transport http sentry https://mcp.sentry.dev/mcp

# Usa:
- issue-summarizer (análisis profundo)
- /seer (queries naturales)
- /getIssues (fetch rápido)
```

**Beneficio:** 100% del valor con MCP configurado.

---

## 10. Conclusión

**La mayoría de las skills de Sentry NO usan MCP:**

✅ **sentry-setup-*** → Editan código (Read, Edit, Write)
✅ **sentry-code-review** → Usa GitHub API (gh CLI)
❌ **issue-summarizer** → USA Sentry MCP
❌ **/seer, /getIssues** → USAN Sentry MCP

**Para Ralph Loop v2.33:**
- Empieza con skills SIN MCP (setup + code review)
- Agrega MCP después si necesitas análisis profundo

**MCP = Nice to have, NOT required para core workflow.**
