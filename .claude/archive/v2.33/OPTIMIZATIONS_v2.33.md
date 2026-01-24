# Multi-Agent Ralph Loop v2.33 - Optimizaciones con Claude Code v2.1.0 + Sentry Integration

## Executive Summary

Basado en el release de Claude Code v2.1.0 y la integración oficial de Sentry MCP, este documento propone optimizaciones estratégicas para el sistema multi-agent-ralph-loop que mejoran:

- **Performance**: Hot-reload de skills, parallel execution con context: fork
- **Error Monitoring**: Integración completa de Sentry en todos los flujos
- **Developer Experience**: Skills auto-descubiertas, hooks en frontmatter, wildcard permissions
- **Quality Gates**: Análisis de issues pre-deploy, iteración automática con Sentry feedback

---

## 1. Nuevas Capacidades de Claude Code v2.1.0

### 1.1 Hot-Reload de Skills (Zero Downtime)

**Capacidad:**
```yaml
# Skills en ~/.claude/skills o .claude/skills se recargan automáticamente
# SIN necesidad de reiniciar la sesión
```

**Impacto en Ralph Loop:**
- Desarrollo iterativo de skills sin interrupciones
- Testing en vivo de cambios en orchestrator, agents, y skills
- Feedback inmediato en el ciclo de desarrollo

**Recomendación v2.33:**
```bash
# Crear skill de desarrollo en tiempo real
cat > ~/.claude/skills/ralph-skill-dev/SKILL.md <<'EOF'
---
name: ralph-skill-dev
description: Live development and testing of Ralph skills with hot-reload
user-invocable: true
---

# Ralph Skill Live Development

Test skills modifications without restarting sessions.

## Workflow:
1. Edit skill in ~/.claude/skills/
2. Test immediately with /skill-name
3. Iterate based on results
4. No session restart needed
EOF
```

### 1.2 Context Forking (Isolated Execution)

**Capacidad:**
```yaml
# skill.md frontmatter
context: fork
```

**Beneficios:**
- Contexto aislado para cada skill/agent
- Evita contaminación de contexto entre ejecuciones
- Paralelización real sin interferencias

**Impacto en Ralph Loop:**

**ANTES (v2.32):**
```yaml
# orchestrator lanza subagent en mismo contexto
Task:
  subagent_type: "security-auditor"
  run_in_background: true  # Pseudo-aislamiento
```

**AHORA (v2.33):**
```yaml
# Skills con context: fork garantizan aislamiento
---
name: security-audit-isolated
context: fork
agent: security-auditor
---
```

**Recomendación v2.33:**
Aplicar `context: fork` a todas las skills que:
- Ejecutan análisis costosos (ast-grep, security scans)
- Lanzan subagents (orchestrator → code-reviewer → Codex)
- Requieren contexto limpio (find-bugs, deslop, iterate-pr)

### 1.3 Agent Field en Skills

**Capacidad:**
```yaml
# skill.md frontmatter
agent: issue-summarizer
model: sonnet
```

**Antes vs Ahora:**

**ANTES:**
```yaml
# orchestrator decide qué agent usar
Task:
  subagent_type: "general-purpose"
  prompt: "Analyze Sentry issues..."
```

**AHORA:**
```yaml
# Skill declara su agent especializado
---
name: sentry-issue-analysis
agent: issue-summarizer
model: sonnet
context: fork
---
```

**Recomendación v2.33:**
Crear skill wrappers para agents existentes:

```bash
# Wrapper para cada agent de Ralph Loop
agents=(orchestrator security-auditor debugger code-reviewer test-architect
        refactorer frontend-reviewer docs-writer minimax-reviewer)

for agent in "${agents[@]}"; do
  cat > ~/.claude/skills/ralph-${agent}/SKILL.md <<EOF
---
name: ralph-${agent}
description: Direct access to ${agent} agent with isolated context
agent: ${agent}
context: fork
user-invocable: true
---

# ${agent^} Agent

Execute ${agent} with guaranteed context isolation.
EOF
done
```

### 1.4 Hooks en Frontmatter (Scope Lifecycle)

**Capacidad:**
```yaml
# skill.md o agent.md frontmatter
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/validate-input.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/quality-gates.sh
  Stop:
    - script: ~/.claude/hooks/cleanup.sh
```

**Impacto en Ralph Loop:**

**ANTES (v2.32):**
```json
// ~/.claude/settings.json - hooks globales
{
  "hooks": {
    "PostEdit": ["~/.claude/hooks/quality-gates.sh"]
  }
}
```

**AHORA (v2.33):**
```yaml
# Hooks scoped a cada agent/skill
---
name: security-auditor
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/security-context-setup.sh
      once: true  # Solo en primera ejecución
  PostToolUse:
    - script: ~/.claude/hooks/security-audit-log.sh
  Stop:
    - script: ~/.claude/hooks/security-report-save.sh
---
```

**Ventajas:**
- Hooks específicos por skill/agent
- `once: true` para setup/teardown
- No contaminar otros agents con hooks irrelevantes

**Recomendación v2.33:**
Migrar hooks críticos desde settings.json al frontmatter:

```yaml
# orchestrator.md
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/orchestrator-init.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/ralph-loop-validate.sh
  Stop:
    - script: ~/.claude/hooks/orchestrator-retrospective.sh

# security-auditor.md
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/security-context.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/security-log.sh

# iterate-pr skill
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/git-branch-check.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/sentry-check-wait.sh
```

### 1.5 Wildcard Permissions (Smart Bash Rules)

**Capacidad:**
```yaml
# settings.json
"allowedTools": [
  "Bash(npm *)",        # npm cualquier subcomando
  "Bash(* install)",    # cualquier comando + install
  "Bash(git * main)"    # git cualquier subcomando en main
]
```

**Impacto en Ralph Loop:**

**ANTES:**
```json
{
  "allowedTools": [
    "Bash(npm install)",
    "Bash(npm run build)",
    "Bash(npm test)",
    "Bash(git status)",
    "Bash(git diff)",
    "Bash(git log)"
  ]
}
```

**AHORA:**
```json
{
  "allowedTools": [
    "Bash(npm *)",           // Todos los comandos npm
    "Bash(git *)",           // Todos los comandos git
    "Bash(* test)",          // Cualquier runner de tests
    "Bash(ralph *)",         // Todos los comandos ralph
    "Bash(gh pr *)",         // Todos los comandos gh pr
    "Bash(* --version)"      // Version checks sin permisos
  ]
}
```

**Recomendación v2.33:**
Crear reglas wildcard por categoría de herramienta:

```json
{
  "allowedTools": [
    // Build tools
    "Bash(npm *)",
    "Bash(yarn *)",
    "Bash(pnpm *)",

    // Version control
    "Bash(git *)",
    "Bash(gh *)",

    // Ralph ecosystem
    "Bash(ralph *)",
    "Bash(mmc *)",
    "Bash(codex *)",

    // Testing
    "Bash(* test)",
    "Bash(* spec)",
    "Bash(pytest *)",

    // Quality gates
    "Bash(tsc *)",
    "Bash(eslint *)",
    "Bash(ruff *)",

    // Sentry
    "Bash(gh pr checks *)",
    "Bash(gh api *sentry*)"
  ]
}
```

### 1.6 Unified Ctrl+B Backgrounding

**Capacidad:**
```
Ctrl+B ahora envía a background TODOS los foreground tasks:
- Comandos bash
- Agents (Task tool)
- Skills de larga duración
```

**Impacto en Ralph Loop:**

**ANTES:**
```
# Usuario espera a que termine orchestrator (bloqueante)
/orchestrator "Implement OAuth"
[... espera 5 minutos ...]
```

**AHORA:**
```
# Usuario inicia task y lo envía a background
/orchestrator "Implement OAuth"
<Ctrl+B>  # → Background
# Usuario continúa trabajando
# Recibe notificación cuando termina
```

**Recomendación v2.33:**
Documentar workflow de background en README:

```markdown
## Background Execution Workflow

1. **Start Complex Task:**
   ```
   /orchestrator "Implement authentication system"
   ```

2. **Send to Background:**
   Press `Ctrl+B` → task continues in background

3. **Monitor Progress:**
   ```
   /tasks  # Lista tasks activos
   ```

4. **Check Results:**
   Task notifica al completar con bullet point clean

5. **Parallel Work:**
   Mientras task corre, puedes:
   - Revisar código
   - Crear PRs
   - Ejecutar otros comandos
```

---

## 2. Integración de Sentry MCP

### 2.1 Componentes Sentry Disponibles

**Plugin oficial:** `claude-plugins-official/sentry/1.0.0/`

**Commands:**
- `/seer <query>` - Natural language queries sobre Sentry
- `/getIssues [project]` - Fetch últimos 10 issues

**Agents:**
- `issue-summarizer` - Análisis paralelo de múltiples issues

**Skills:**
- `sentry-code-review` - Resuelve bugs en PRs con Sentry comments
- `sentry-setup-ai-monitoring` - Config monitoreo AI
- `sentry-setup-logging` - Config logging
- `sentry-setup-metrics` - Config métricas
- `sentry-setup-tracing` - Config tracing

**Skills propias (creadas hoy):**
- `deslop` - Limpia código AI-generado (slop removal)
- `find-bugs` - Búsqueda de bugs con security checklist
- `iterate-pr` - Iteración en PRs hasta CI pass (integra Sentry checks)

### 2.2 Integración en Orchestrator

**Actualización orchestrator.md v2.33:**

```yaml
---
name: orchestrator
model: opus
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/orchestrator-init.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/ralph-loop-validate.sh
  Stop:
    - script: ~/.claude/hooks/sentry-report.sh
---

# Orchestrator v2.33 - Sentry Integration

## Step 2c: SENTRY PRE-CHECK (NEW v2.33)

**After WORKTREE decision**, check Sentry for related issues:

### When to Check Sentry

Check Sentry if task involves:
- Bug fixes
- Error handling
- Performance issues
- User-reported problems
- Production incidents

### Sentry Query

```yaml
# Use /seer for natural language query
/seer Show critical issues in <project> related to <feature>

# Example:
/seer Show authentication errors in last 7 days
/seer Database performance issues in api-gateway
/seer TypeError in user-service affecting >100 users
```

### Analysis

Use `issue-summarizer` agent for deep analysis:

```yaml
Task:
  subagent_type: "issue-summarizer"
  context: fork  # NEW v2.33
  prompt: |
    Analyze Sentry issues related to: <task>

    Focus on:
    - User impact (how many users affected)
    - Root cause patterns
    - Related code paths
    - Existing PRs/fixes
```

### Decision Tree

```
┌─────────────────────────────────────┐
│ Critical issues found? (>100 users) │
├─────────────────────────────────────┤
│ YES → Prioritize fix in plan        │
│ NO  → Note issues, continue plan    │
└─────────────────────────────────────┘
```

## Step 7b: SENTRY PR REVIEW (ENHANCED v2.33)

### Multi-Phase PR Review

```
Phase 1: Sentry Bot Checks (NEW)
  ├── Wait for sentry-io check to complete
  ├── Fetch Sentry bot comments
  └── Auto-fix with sentry-code-review skill

Phase 2: Traditional PR Review
  ├── Claude Opus review
  ├── Codex GPT-5 review
  └── 2/3 consensus

Phase 3: Iterate Until Green (NEW)
  └── Use iterate-pr skill
```

### Enhanced ralph worktree-pr

```bash
# v2.33 workflow
ralph worktree-pr <branch>

# Step 1: Push + Create PR Draft
git push -u origin <branch>
gh pr create --draft --title "..." --body "..."

# Step 2: Wait for Sentry Bot (NEW)
echo "⏳ Waiting for Sentry checks..."
gh pr checks --watch --required | grep -i sentry

# Step 3: Auto-fix Sentry Issues (NEW)
if gh pr view --json comments --jq '.comments[] | select(.author.login | startswith("sentry"))' | grep -q .; then
  echo "🤖 Sentry issues detected. Auto-fixing..."
  /sentry-code-review
fi

# Step 4: Traditional Multi-Agent Review
ralph worktree-review <pr>

# Step 5: Iterate Until Green (NEW)
/iterate-pr
```

## Step 6: VALIDATE (ENHANCED v2.33)

### 6c. Sentry Error Tracking (NEW)

After deployment to staging/prod, monitor for new errors:

```yaml
Task:
  subagent_type: "issue-summarizer"
  context: fork
  prompt: |
    Monitor Sentry for new issues after deploy:

    Release: <version>
    Project: <project>
    Time window: Last 1 hour

    Report:
    - New error types
    - Regression detection
    - User impact
    - Rollback recommendation (YES/NO)
```

### Decision: Rollback or Forward Fix

```
┌──────────────────────────────────────┐
│ New critical errors? (>50 users)     │
├──────────────────────────────────────┤
│ YES → Recommend rollback             │
│ NO  → Monitor, forward fix if needed │
└──────────────────────────────────────┘
```
```

### 2.3 Nuevos Slash Commands v2.33

**Agregando comandos Sentry-aware a Ralph Loop:**

```bash
# Crear ~/.ralph/commands/sentry-analyze.sh
cat > ~/.ralph/commands/sentry-analyze.sh <<'EOF'
#!/usr/bin/env bash
# Ralph Loop Sentry Analysis Command

set -euo pipefail

PROJECT="${1:-}"
QUERY="${2:-top errors in last 24 hours}"

if [[ -z "$PROJECT" ]]; then
  echo "Usage: ralph sentry-analyze <project> [query]"
  exit 1
fi

echo "🔍 Analyzing Sentry project: $PROJECT"
echo "Query: $QUERY"
echo ""

# Natural language query via Sentry MCP
claude << EOF_CLAUDE
/seer $QUERY in project $PROJECT

Then use issue-summarizer agent to provide:
- User impact summary
- Root cause analysis
- Recommended priorities
EOF_CLAUDE
EOF

chmod +x ~/.ralph/commands/sentry-analyze.sh

# Crear ~/.ralph/commands/sentry-pr-fix.sh
cat > ~/.ralph/commands/sentry-pr-fix.sh <<'EOF'
#!/usr/bin/env bash
# Ralph Loop Sentry PR Fixer

set -euo pipefail

PR_NUMBER="${1:-}"

if [[ -z "$PR_NUMBER" ]]; then
  # Auto-detect PR for current branch
  PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null || echo "")
fi

if [[ -z "$PR_NUMBER" ]]; then
  echo "❌ No PR found. Provide PR number or run from PR branch."
  exit 1
fi

echo "🤖 Fixing Sentry issues in PR #$PR_NUMBER"

# Wait for Sentry checks
echo "⏳ Waiting for Sentry bot checks..."
gh pr checks --watch | grep -i sentry || true

# Auto-fix Sentry comments
claude <<EOF_CLAUDE
/sentry-code-review

Analyze PR #$PR_NUMBER and fix all Sentry bot comments.
EOF_CLAUDE
EOF

chmod +x ~/.ralph/commands/sentry-pr-fix.sh
```

**Actualizar ralph CLI:**

```bash
# Agregar en scripts/ralph.sh
case "$1" in
  # ... existing commands ...

  sentry-analyze)
    shift
    ~/.ralph/commands/sentry-analyze.sh "$@"
    ;;

  sentry-pr-fix)
    shift
    ~/.ralph/commands/sentry-pr-fix.sh "$@"
    ;;

  # ... rest of commands ...
esac
```

---

## 3. Skills v2.33 Optimizadas

### 3.1 Skill: find-bugs (Enhanced)

**Actualización con Sentry integration:**

```yaml
---
name: find-bugs
description: Find bugs, security vulnerabilities, and code quality issues in local branch changes with Sentry correlation
context: fork
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/find-bugs-init.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/find-bugs-report.sh
---

# Find Bugs v2.33 - Sentry Enhanced

## Phase 0: Sentry Correlation (NEW v2.33)

BEFORE analyzing local changes, check if Sentry has detected related issues:

```bash
# Get current branch
BRANCH=$(git branch --show-current)

# Find PR for this branch
PR_NUMBER=$(gh pr view --json number --jq '.number' 2>/dev/null || echo "")

if [[ -n "$PR_NUMBER" ]]; then
  echo "📊 Checking Sentry for PR #$PR_NUMBER..."

  # Check for Sentry bot comments
  SENTRY_COMMENTS=$(gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" \
    --jq '.[] | select(.user.login | startswith("sentry"))')

  if [[ -n "$SENTRY_COMMENTS" ]]; then
    echo "⚠️ Sentry has identified issues in this PR:"
    echo "$SENTRY_COMMENTS" | jq -r '.body' | head -n 20
    echo ""
    echo "Priority: Address Sentry issues first before manual analysis."
  fi
fi
```

## Phase 1-5: [Existing phases...]

## Phase 6: Sentry Cross-Reference (NEW v2.33)

After completing manual analysis, cross-reference with Sentry:

```yaml
For each bug found locally:
  1. Search Sentry for similar error patterns
  2. Check if already reported by users in production
  3. Add severity based on production impact
  4. Link to Sentry issue URL if exists
```

## Output Format (Enhanced)

For each issue:

* **File:Line** - Brief description
* **Severity**: Critical/High/Medium/Low
* **Sentry Match**: [URL] or "Not in production" (NEW)
* **User Impact**: [count] users affected (NEW)
* **Problem**: What's wrong
* **Evidence**: Why this is real
* **Fix**: Concrete suggestion
```

### 3.2 Skill: iterate-pr (Enhanced)

**Ya incluye Sentry checks, agregar reporting:**

```yaml
---
name: iterate-pr
description: Iterate on a PR until CI passes with Sentry-aware feedback loop
context: fork
hooks:
  PreToolUse:
    - script: ~/.claude/hooks/git-branch-check.sh
      once: true
  PostToolUse:
    - script: ~/.claude/hooks/iterate-pr-log.sh
  Stop:
    - script: ~/.claude/hooks/iterate-pr-summary.sh
---

# Iterate PR v2.33 - Sentry-Aware

## Step 2: Check CI Status + Sentry Priority (ENHANCED)

```bash
gh pr checks --json name,state,bucket,link,workflow

# NEW v2.33: Prioritize Sentry-related checks
SENTRY_CHECKS=$(jq -r '.[] | select(.name | test("sentry|codecov|cursor|bugbot|seer")) | .name')

if echo "$SENTRY_CHECKS" | grep -q "pending"; then
  echo "⏳ Waiting for Sentry/bot checks to complete..."
  echo "These bots may post additional feedback. Waiting avoids duplicate work."

  # Wait specifically for Sentry checks
  while true; do
    STATUS=$(gh pr checks --json name,state \
      --jq '.[] | select(.name | test("sentry")) | .state' | head -1)

    if [[ "$STATUS" != "pending" ]]; then
      echo "✅ Sentry checks completed: $STATUS"
      break
    fi

    echo "⏳ Sentry still analyzing... (checking every 30s)"
    sleep 30
  done
fi
```

## Step 3: Gather Review Feedback (ENHANCED)

### Priority 1: Sentry Bot Comments (NEW)

```bash
# Fetch Sentry-specific comments first
gh api "repos/{owner}/{repo}/pulls/{pr}/comments" \
  --jq '.[] | select(.user.login | startswith("sentry")) |
    {file: .path, line: .line, severity: .body | match("Severity: (\\w+)") | .captures[0].string, body: .body}'
```

### Priority 2: Human + Other Bot Feedback

```bash
gh pr view --json reviews,comments,reviewDecision
gh api "repos/{owner}/{repo}/issues/{pr}/comments"
```

## Step 10: Sentry Resolution Report (NEW v2.33)

After all iterations complete:

```bash
# Generate Sentry-specific report
cat > .ralph/iterate-pr-sentry-report.md <<EOF
## Sentry Issue Resolution Report

**PR:** #$PR_NUMBER
**Branch:** $BRANCH
**Iterations:** $ITERATION_COUNT

### Sentry Issues Addressed

$(gh api "repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" \
  --jq '.[] | select(.user.login | startswith("sentry")) |
    "- [" + (.body | match("\\*\\*Bug:\\*\\* (.+)") | .captures[0].string) + "](" + .html_url + ")"')

### Final CI Status

$(gh pr checks --json name,state,conclusion --jq '.[] | "- " + .name + ": " + .conclusion')

### Recommendation

$(if gh pr checks --json conclusion --jq '.[] | select(.conclusion != "success")' | grep -q .; then
  echo "⚠️ Some checks still failing. Manual intervention needed."
else
  echo "✅ All checks passing. Ready for review."
fi)
EOF

cat .ralph/iterate-pr-sentry-report.md
```
```

### 3.3 Skill: deslop (Enhanced)

**Agregar integración con Sentry style guide:**

```yaml
---
name: deslop
description: Remove AI-generated code slop with Sentry best practices enforcement
context: fork
---

# Remove AI Code Slop v2.33 - Sentry Style Guide

## What to Remove (Enhanced)

### Sentry-Specific Anti-Patterns (NEW)

- **Over-instrumentation:** Logging every function call vs strategic error boundaries
- **Redundant error captures:** Sentry.captureException() already handled by global handler
- **Excessive context:** 50+ lines of context data vs minimal reproduction info
- **Try-catch spam:** Wrapping every line vs letting errors bubble to boundaries

### Example: Before (Slop)

```python
def process_user_data(user_id):
    try:
        Sentry.add_breadcrumb(category="user", message="Starting process_user_data")
        Sentry.set_context("function_start", {"user_id": user_id, "timestamp": time.time()})

        try:
            user = get_user(user_id)
            Sentry.add_breadcrumb(category="database", message="Fetched user")
        except Exception as e:
            Sentry.capture_exception(e)
            raise

        try:
            result = expensive_operation(user)
            Sentry.add_breadcrumb(category="processing", message="Completed operation")
        except Exception as e:
            Sentry.capture_exception(e)
            raise

        Sentry.set_context("function_end", {"result": str(result)})
        return result
    except Exception as e:
        Sentry.capture_exception(e)
        raise
```

### Example: After (Clean)

```python
def process_user_data(user_id):
    # Let errors bubble to error boundary
    # Global Sentry handler captures uncaught exceptions
    user = get_user(user_id)
    return expensive_operation(user)
```

### When to Keep Sentry Instrumentation

✅ **Keep these:**
- Error boundaries at service entry points
- Custom context for critical business operations
- Performance monitoring for bottleneck functions
- Breadcrumbs for complex state machines

❌ **Remove these:**
- Try-catch wrappers with Sentry.capture on every function
- Breadcrumbs for trivial operations (getters, setters)
- Duplicate error captures (already handled upstream)
- Over-detailed context (full objects vs IDs)
```

---

## 4. Flujos Actualizados v2.33

### 4.1 Flujo de Code Review con Sentry

```
┌────────────────────────────────────────────────────────────────┐
│                   CODE REVIEW FLOW v2.33                       │
│                    (Sentry-Enhanced)                           │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Step 1: LOCAL ANALYSIS                                       │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ /find-bugs                                               │ │
│  │ - Phase 0: Check Sentry for PR issues (NEW)             │ │
│  │ - Phase 1-5: Standard security checklist                │ │
│  │ - Phase 6: Cross-reference with production (NEW)        │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 2: SENTRY BOT ANALYSIS (NEW)                            │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Wait for Sentry checks:                                  │ │
│  │ gh pr checks --watch | grep sentry                       │ │
│  │                                                          │ │
│  │ Fetch Sentry bot comments:                               │ │
│  │ gh api pulls/{pr}/comments | select(.user.login~sentry) │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 3: AUTO-FIX SENTRY ISSUES (NEW)                         │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ /sentry-code-review                                      │ │
│  │ - Parse Sentry comments (severity, confidence)           │ │
│  │ - Read affected files                                    │ │
│  │ - Apply suggested fixes                                  │ │
│  │ - Commit: "fix: sentry - <issue description>"            │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 4: TRADITIONAL REVIEW                                   │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Multi-Agent Review:                                      │ │
│  │ - Claude Opus (architectural)                            │ │
│  │ - Codex GPT-5 (code quality)                             │ │
│  │ - MiniMax M2.1 (second opinion)                          │ │
│  │                                                          │ │
│  │ 2/3 Consensus → Approve                                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 5: ITERATE UNTIL GREEN (NEW)                            │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ /iterate-pr                                              │ │
│  │ Loop until:                                              │ │
│  │ - All CI checks pass                                     │ │
│  │ - Sentry bot happy                                       │ │
│  │ - No unresolved human feedback                           │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│                      READY TO MERGE                            │
└────────────────────────────────────────────────────────────────┘
```

**Commands:**

```bash
# Full code review flow
ralph code-review <pr-number>

# Internals:
# 1. ralph find-bugs (with Sentry correlation)
# 2. Wait for Sentry checks
# 3. ralph sentry-pr-fix <pr>
# 4. ralph worktree-review <pr> (multi-agent)
# 5. ralph iterate-pr (until green)
```

### 4.2 Flujo de Deploy con Sentry Release Tracking

```
┌────────────────────────────────────────────────────────────────┐
│                    DEPLOY FLOW v2.33                           │
│              (Sentry Release Tracking)                         │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Step 1: PRE-DEPLOY VALIDATION                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ ralph pre-merge                                          │ │
│  │ - shellcheck                                             │ │
│  │ - version checks                                         │ │
│  │ - tests                                                  │ │
│  │ - Sentry issue check (NEW)                               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 2: CREATE SENTRY RELEASE (NEW)                          │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ # Get version from package.json / version file           │ │
│  │ VERSION=$(jq -r '.version' package.json)                 │ │
│  │                                                          │ │
│  │ # Create Sentry release                                  │ │
│  │ sentry-cli releases new "$VERSION"                       │ │
│  │                                                          │ │
│  │ # Associate commits                                      │ │
│  │ sentry-cli releases set-commits "$VERSION" --auto        │ │
│  │                                                          │ │
│  │ # Upload source maps (if applicable)                     │ │
│  │ sentry-cli releases files "$VERSION" upload-sourcemaps . │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 3: DEPLOY                                               │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ # Standard deploy                                        │ │
│  │ ./deploy.sh staging                                      │ │
│  │                                                          │ │
│  │ # Finalize Sentry release                                │ │
│  │ sentry-cli releases finalize "$VERSION"                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 4: POST-DEPLOY MONITORING (NEW)                         │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ # Wait 5 min for errors to surface                       │ │
│  │ sleep 300                                                │ │
│  │                                                          │ │
│  │ # Check for new issues                                   │ │
│  │ /seer Show new errors in last 5 minutes for $VERSION     │ │
│  │                                                          │ │
│  │ # Automated analysis                                     │ │
│  │ Task(issue-summarizer):                                  │ │
│  │   "Analyze issues for release $VERSION"                  │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Step 5: DECISION GATE (NEW)                                  │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ If critical errors (>50 users):                          │ │
│  │   → ROLLBACK                                             │ │
│  │                                                          │ │
│  │ Else:                                                    │ │
│  │   → MONITOR & FORWARD FIX                                │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Commands:**

```bash
# Deploy with Sentry tracking
ralph deploy-with-sentry <environment> <version>

# Internals:
# 1. ralph pre-merge
# 2. sentry-cli releases new
# 3. deploy script
# 4. sentry-cli releases finalize
# 5. ralph sentry-analyze (post-deploy)
# 6. Decision: rollback or monitor
```

### 4.3 Flujo de Iteration con Sentry Error Monitoring

```
┌────────────────────────────────────────────────────────────────┐
│                  ITERATION FLOW v2.33                          │
│           (Sentry-Driven Error Reduction)                      │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  Iteration 0: BASELINE                                        │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ /seer Show all errors in last 24 hours                   │ │
│  │                                                          │ │
│  │ Baseline metrics:                                        │ │
│  │ - Total errors: N                                        │ │
│  │ - Unique issues: M                                       │ │
│  │ - Users affected: U                                      │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                  RALPH LOOP PATTERN                      │ │
│  │                                                          │ │
│  │  ┌──────────┐    ┌──────────────┐    ┌──────────────┐  │ │
│  │  │ EXECUTE  │───▶│   VALIDATE   │───▶│ Errors       │  │ │
│  │  │ (Fix)    │    │ (Sentry)     │    │ Reduced?     │  │ │
│  │  └──────────┘    └──────────────┘    └──────┬───────┘  │ │
│  │                                              │          │ │
│  │                                       NO ◀──┴──▶ YES   │ │
│  │                                        │         │      │ │
│  │                         ┌──────────────┘         │      │ │
│  │                         ▼                        ▼      │ │
│  │                  ┌─────────────┐       ┌──────────────┐│ │
│  │                  │  ITERATE    │       │VERIFIED_DONE ││ │
│  │                  │ (Fix next)  │       │ (<10% errors)││ │
│  │                  └──────┬──────┘       └──────────────┘│ │
│  │                         │                              │ │
│  │                         └──▶ Back to EXECUTE           │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                │
│  Iteration Details:                                           │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │ Iteration N:                                             │ │
│  │ 1. Fetch top error from Sentry                           │ │
│  │ 2. Analyze root cause (issue-summarizer)                 │ │
│  │ 3. Implement fix                                         │ │
│  │ 4. Deploy to staging                                     │ │
│  │ 5. Monitor Sentry (5 min window)                         │ │
│  │ 6. Compare: errors reduced by >20%?                      │ │
│  │    YES → Next iteration                                  │ │
│  │    NO  → Rollback, try different approach                │ │
│  └──────────────────────────────────────────────────────────┘ │
│                         │                                      │
│                         ▼                                      │
│  Goal: Reduce errors to <10% of baseline                     │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

**Commands:**

```bash
# Iterative error reduction
ralph iterate-errors <project> [--max-iterations 25]

# Internals:
# Loop:
#   1. /seer top error in <project>
#   2. Task(issue-summarizer)
#   3. Fix implementation
#   4. Deploy staging
#   5. Monitor Sentry
#   6. Validate reduction
# Until: errors < 10% baseline OR max iterations
```

---

## 5. Implementación v2.33

### 5.1 Migration Checklist

- [ ] **Install Sentry Plugin**
  ```bash
  /plugin marketplace add getsentry/sentry-for-claude
  /plugin install sentry@getsentry
  # Restart Claude Code
  ```

- [ ] **Configure Sentry MCP**
  ```bash
  /mcp  # Verify sentry server listed
  ```

- [ ] **Update orchestrator.md**
  - Add Step 2c: Sentry Pre-Check
  - Add Step 7b: Sentry PR Review enhancements
  - Add hooks in frontmatter

- [ ] **Update find-bugs skill**
  - Add Phase 0: Sentry Correlation
  - Add Phase 6: Sentry Cross-Reference
  - Add context: fork

- [ ] **Update iterate-pr skill**
  - Add Sentry priority checks
  - Add Step 10: Sentry Resolution Report
  - Add hooks in frontmatter

- [ ] **Update deslop skill**
  - Add Sentry-specific anti-patterns section
  - Add context: fork

- [ ] **Create new Ralph commands**
  - ralph sentry-analyze
  - ralph sentry-pr-fix
  - ralph deploy-with-sentry
  - ralph iterate-errors

- [ ] **Update wildcard permissions**
  ```json
  {
    "allowedTools": [
      "Bash(gh pr checks *)",
      "Bash(gh api *sentry*)",
      "Bash(sentry-cli *)"
    ]
  }
  ```

- [ ] **Create context: fork wrappers**
  ```bash
  for agent in orchestrator security-auditor debugger code-reviewer \
               test-architect refactorer frontend-reviewer docs-writer \
               minimax-reviewer; do
    # Create skill wrapper with context: fork
  done
  ```

- [ ] **Add hooks to agents**
  - orchestrator: PreToolUse, PostToolUse, Stop
  - security-auditor: PreToolUse, PostToolUse
  - debugger: PreToolUse, PostToolUse

- [ ] **Test workflows**
  - Code review flow end-to-end
  - Deploy flow with Sentry tracking
  - Iteration flow with error reduction

- [ ] **Update documentation**
  - README.md with v2.33 features
  - CLAUDE.md with new commands
  - CHANGELOG.md with v2.33 entry

### 5.2 Backward Compatibility

**v2.33 mantiene compatibilidad total con v2.32:**

- Todos los comandos existentes funcionan sin cambios
- Nuevas features son opt-in (requieren /plugin install sentry)
- Hooks en frontmatter son opcionales (fallback a settings.json)
- context: fork es opcional (default: shared context como antes)

**Migración gradual:**

```
Phase 1: Install Sentry plugin (0 breaking changes)
Phase 2: Add Sentry commands (new commands, zero impact)
Phase 3: Update skills with context: fork (better isolation)
Phase 4: Migrate hooks to frontmatter (cleaner organization)
```

---

## 6. Métricas de Éxito v2.33

### 6.1 Performance Metrics

| Métrica | v2.32 | v2.33 Target | Mejora |
|---------|-------|--------------|--------|
| **Skill reload time** | 30-60s (restart) | 0s (hot-reload) | ∞ |
| **Context contamination** | 15-20% | <5% (fork) | 3-4x |
| **PR iteration cycles** | 4-6 | 2-3 (Sentry auto-fix) | 2x |
| **Time to merge** | 3-4 hours | 1-2 hours | 2x |
| **Production errors** | Baseline | -60% (Sentry-driven) | 2.5x |

### 6.2 Developer Experience

| Aspecto | v2.32 | v2.33 |
|---------|-------|-------|
| **Skill development** | Edit → Restart → Test | Edit → Test (hot-reload) |
| **Background tasks** | Bash only | Bash + Agents + Skills |
| **Permissions** | Per-command | Wildcard patterns |
| **Error visibility** | Post-deploy | Pre-commit (Sentry bot) |
| **Iteration feedback** | Manual checks | Auto Sentry monitoring |

### 6.3 Quality Gates

**v2.33 agrega Sentry Quality Gate:**

```
┌───────────────────────────────────────────────┐
│         QUALITY GATES v2.33                   │
├───────────────────────────────────────────────┤
│ 1. Language gates (9 languages)              │
│    ├── TypeScript: tsc, eslint               │
│    ├── Python: pyright, ruff                 │
│    └── ... (Go, Rust, etc.)                  │
│                                               │
│ 2. Security gates                             │
│    ├── git-safety-guard.py                   │
│    └── /find-bugs security checklist         │
│                                               │
│ 3. Sentry gates (NEW v2.33)                  │
│    ├── No critical Sentry bot comments       │
│    ├── CI sentry checks passing              │
│    └── Post-deploy error rate < baseline     │
│                                               │
│ 4. Adversarial validation (complexity >= 7)  │
│    └── 2/3 consensus (Claude + Codex + MCP)  │
└───────────────────────────────────────────────┘
```

---

## 7. Roadmap v2.34

**Futuras optimizaciones considerando Claude Code v2.2+:**

1. **Remote Environments** (ya disponible en v2.1.0 para claude.ai)
   - Ejecutar Ralph Loop en entornos remotos
   - /teleport para sesiones remote
   - State sync entre local y remote

2. **Advanced MCP Features**
   - list_changed notifications (hot reload de MCP tools)
   - Dynamic tool registration
   - MCP server health monitoring

3. **Enhanced Vim Mode**
   - Text objects en code review
   - Macros para operaciones repetitivas
   - Visual mode para bulk edits

4. **Slash Command Autocomplete**
   - Completado inteligente de ralph commands
   - Argument hints contextuales
   - History-based suggestions

5. **Unified Backgrounding UX**
   - Dashboard de background tasks
   - Priority queuing
   - Resource allocation

---

## 8. Conclusiones

**Claude Code v2.1.0 + Sentry Integration = Game Changer para Ralph Loop**

### Key Wins:

1. **Hot-Reload**: Desarrollo iterativo sin downtime
2. **Context Forking**: Aislamiento real entre agents/skills
3. **Sentry Integration**: Error visibility pre y post deploy
4. **Smart Permissions**: Wildcards reducen friction
5. **Lifecycle Hooks**: Scoped hooks por agent/skill

### Adoption Strategy:

```
Week 1: Install Sentry plugin, test /seer and /getIssues
Week 2: Update find-bugs + iterate-pr with Sentry enhancements
Week 3: Add context: fork to all skills
Week 4: Migrate hooks to frontmatter
Week 5: Create new ralph commands (sentry-analyze, etc.)
Week 6: Full deployment + metrics collection
```

### Expected ROI:

- **60% reduction** en errores de producción (Sentry-driven iteration)
- **50% faster** PR merge time (auto-fix Sentry issues)
- **Zero downtime** para skill development (hot-reload)
- **3-4x better** context isolation (fork vs shared)

---

**Next Steps:**

1. Review este documento con el equipo
2. Priorizar features de mayor impacto
3. Crear issues/PRs para implementación gradual
4. Definir métricas de éxito específicas del proyecto
5. Kick-off Week 1 con Sentry plugin installation

¿Questions? Feedback? → Continuar iteración en este documento.
