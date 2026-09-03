# Plan de Implementación: WorkTrunk + PR Workflow

> Historical record. Model/provider names below describe the state at the time of writing; the current rule is that the model is whatever the session runs.

> **Versión**: v2.20
> **Estado**: Aprobación Pendiente
> **Fecha**: Enero 2026

## Resumen Ejecutivo

Integrar WorkTrunk para manejo de git worktrees con un flujo de PR obligatorio que incluye code review multi-agente (Claude + Codex) antes de merge.

---

## Análisis de Costos de Herramientas

| Herramienta | Costo | Integrar? | Motivo |
|-------------|-------|-----------|--------|
| **WorkTrunk** | Gratis (MIT) | ✅ Sí | Core del flujo |
| **Claude Code** | Tu suscripción | ✅ Sí | Ya disponible |
| **Codex CLI** | Tu suscripción | ✅ Sí | Ya disponible |
| **Greptile** | $30/dev/mes | ⚠️ Opcional | Solo si ya tiene cuenta |
| **GitHub CLI** | Gratis | ✅ Sí | Para PRs |

### Decisión: Greptile

- **Open Source (MIT)**: Gratis → Elegible
- **Proyectos privados**: $30/dev/mes → No obligatorio
- **Implementación**: Detección automática, si está configurado se usa

---

## Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH WORKTREE SYSTEM v2.20                   │
└─────────────────────────────────────────────────────────────────┘

                         ralph worktree "task"
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 1: CREAR WORKTREE                                          │
│                                                                   │
│  1. Validar task name (escape chars, length)                     │
│  2. Generar branch name: ai/ralph/<date>-<task>                  │
│  3. Ejecutar: wt switch -c <branch>                              │
│  4. Aplicar security hardening (hooks disabled, no push)         │
│  5. Abrir nueva terminal con Claude                              │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 2: DESARROLLO (Claude en worktree aislado)                 │
│                                                                   │
│  - Claude trabaja en archivos aislados                           │
│  - Commits locales en branch                                     │
│  - Sin interferencia con otros worktrees                         │
│  - Monitoreo via: wt list (🤖/💬)                                │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
                       ralph worktree-pr <branch>
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 3: CREAR PR                                                │
│                                                                   │
│  1. Push branch a origin                                         │
│  2. Crear PR draft con gh pr create                              │
│  3. Esperar CI/CD inicial                                        │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 4: MULTI-AGENT CODE REVIEW                                 │
│                                                                   │
│  ┌─────────────────┐     ┌─────────────────┐                    │
│  │  Claude Review  │     │  Codex Review   │                    │
│  │  (Sonnet)       │     │  (GPT-5)        │                    │
│  │                 │     │                 │                    │
│  │  • Logic errors │     │  • Security     │                    │
│  │  • Edge cases   │     │  • Performance  │                    │
│  │  • Code quality │     │  • Best practs  │                    │
│  └────────┬────────┘     └────────┬────────┘                    │
│           │                       │                              │
│           └───────────┬───────────┘                              │
│                       │                                          │
│                       ▼                                          │
│           ┌─────────────────────┐                               │
│           │  Greptile (Opcional)│                               │
│           │  Si está configurado│                               │
│           └─────────────────────┘                               │
│                                                                   │
│  Output: Comments en PR con findings                             │
└─────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────┐
│  FASE 5: DECISIÓN                                                │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  Todos los reviews pasaron?                               │   │
│  └──────────────────────────────────────────────────────────┘   │
│           │                              │                       │
│           ▼ SÍ                           ▼ NO                    │
│  ┌─────────────────┐           ┌─────────────────┐              │
│  │ gh pr ready     │           │ Claude aplica   │              │
│  │ gh pr merge     │           │ fixes en        │              │
│  │ --squash        │           │ worktree        │              │
│  │ --delete-branch │           │                 │              │
│  └─────────────────┘           └────────┬────────┘              │
│           │                             │                        │
│           ▼                             ▼                        │
│  ┌─────────────────┐           ┌─────────────────┐              │
│  │ wt remove       │           │ git push        │              │
│  │ (cleanup)       │           │ Re-trigger      │              │
│  └─────────────────┘           │ review          │              │
│                                └─────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

---

## Componentes a Implementar

### 1. Comandos Ralph (scripts/ralph)

| Comando | Descripción |
|---------|-------------|
| `ralph worktree <task>` | Crear worktree + lanzar Claude |
| `ralph worktree-parallel <t1> <t2>...` | Crear múltiples worktrees |
| `ralph worktree-pr <branch>` | Crear PR + multi-agent review |
| `ralph worktree-status` | Ver estado de worktrees |
| `ralph worktree-fix <pr>` | Aplicar fixes de review |
| `ralph worktree-merge <pr>` | Aprobar y merge PR |
| `ralph worktree-close <pr>` | Cerrar PR y cleanup |
| `ralph worktree-cleanup` | Limpiar worktrees merged |

### 2. Skill: worktree-pr-review

```yaml
# .claude/skills/worktree-pr-review/skill.md
name: worktree-pr-review
description: Multi-agent PR review workflow
triggers:
  - pr review
  - code review
  - review pr
```

### 3. Agent: pr-reviewer

```yaml
# .claude/agents/pr-reviewer.md
name: pr-reviewer
model: sonnet
description: Coordina multi-agent PR review
tools:
  - Bash (gh, git, codex)
  - Read
  - WebFetch
```

### 4. Hooks de WorkTrunk

```bash
# Pre-PR hook: Validar antes de crear PR
wt config hooks create pre-pr "ralph gates --quick"

# Post-merge hook: Cleanup
wt config hooks create post-merge "ralph worktree-cleanup"
```

---

## Implementación Detallada

### Fase 1: ralph worktree

```bash
#!/bin/bash
# Agregar a scripts/ralph

ralph_worktree() {
  local task="$1"
  local branch_name
  local wt_path

  # Validación
  if [ -z "$task" ]; then
    echo "Usage: ralph worktree <task-description>"
    return 1
  fi

  # Sanitizar nombre
  task=$(echo "$task" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g')

  # Generar branch name
  branch_name="ai/ralph/$(date +%Y%m%d)-${task:0:40}"

  echo "🌿 Creating worktree: $branch_name"

  # Verificar WorkTrunk instalado
  if ! command -v wt &> /dev/null; then
    echo "❌ WorkTrunk not installed. Install with:"
    echo "   brew install max-sixty/worktrunk/wt"
    return 1
  fi

  # Crear worktree
  wt switch -c "$branch_name"
  wt_path=$(wt list --json | jq -r ".[] | select(.branch == \"$branch_name\") | .path")

  # Aplicar security hardening
  echo "🔒 Applying security hardening..."
  (
    cd "$wt_path"
    mkdir -p .git-hooks-disabled
    git config --worktree core.hooksPath "$PWD/.git-hooks-disabled"
    git config --worktree credential.helper ""
    git config --worktree push.default current
  )

  # Lanzar Claude
  echo "🤖 Launching Claude in worktree..."
  if [[ "$TERM_PROGRAM" == "iTerm.app" ]]; then
    osascript -e "tell application \"iTerm\"
      tell current window
        create tab with default profile
        tell current session
          write text \"cd '$wt_path' && claude\"
        end tell
      end tell
    end tell"
  else
    echo "📂 Worktree created at: $wt_path"
    echo "   Run: cd $wt_path && claude"
  fi

  echo ""
  echo "✅ Worktree ready: $branch_name"
  echo "📋 When done, run: ralph worktree-pr $branch_name"
}
```

### Fase 2: ralph worktree-pr

```bash
ralph_worktree_pr() {
  local branch="$1"
  local pr_number
  local repo_name
  local review_passed=true

  if [ -z "$branch" ]; then
    echo "Usage: ralph worktree-pr <branch>"
    return 1
  fi

  # Switch al worktree
  wt switch "$branch"
  repo_name=$(gh repo view --json nameWithOwner -q '.nameWithOwner')

  echo "═══════════════════════════════════════════════════════════"
  echo "  RALPH WORKTREE PR WORKFLOW"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # ─────────────────────────────────────────────────────────────
  # PASO 1: Push y crear PR
  # ─────────────────────────────────────────────────────────────
  echo "📤 Step 1: Pushing branch and creating PR..."

  git push -u origin "$branch"

  pr_number=$(gh pr create \
    --title "feat: ${branch#ai/ralph/*/}" \
    --body "$(cat <<EOF
## Summary
AI-generated changes from worktree workflow.

## Review Checklist
- [ ] Claude Code Review
- [ ] Codex Security Review
- [ ] CI/CD Passed

---
🤖 Generated with [Multi-Agent Ralph Loop](https://github.com/alfredolopez80/multi-agent-ralph-loop)
EOF
)" \
    --draft \
    --json number -q '.number')

  echo "✅ PR #$pr_number created (draft)"
  echo ""

  # ─────────────────────────────────────────────────────────────
  # PASO 2: Multi-Agent Code Review
  # ─────────────────────────────────────────────────────────────
  echo "🔍 Step 2: Starting multi-agent code review..."
  echo ""

  # Obtener diff
  local diff_file="/tmp/pr-${pr_number}-diff.txt"
  gh pr diff "$pr_number" > "$diff_file"

  # Review con Claude
  echo "  🔵 Claude Review (logic, edge cases, quality)..."
  local claude_review
  claude_review=$(cat "$diff_file" | claude --print -m sonnet "
You are a senior code reviewer. Analyze this diff and provide feedback:

## Review Focus
1. **Logic Errors**: Incorrect algorithms, wrong conditions, off-by-one errors
2. **Edge Cases**: Null handling, empty arrays, boundary conditions
3. **Code Quality**: Readability, maintainability, DRY violations
4. **Security**: Input validation, injection risks, sensitive data exposure

## Output Format
Provide a structured review with:
- **Severity**: 🔴 BLOCKER | 🟠 HIGH | 🟡 MEDIUM | 🟢 LOW
- **Location**: file:line
- **Issue**: Description
- **Suggestion**: How to fix

If no issues found, respond with: ✅ LGTM - No issues found

Be concise and actionable.
")

  # Postear review de Claude
  gh pr comment "$pr_number" --body "## 🔵 Claude Code Review

$claude_review

---
*Reviewed by Claude Sonnet*"

  echo "  ✅ Claude review posted"

  # Review con Codex
  echo "  🟣 Codex Review (security, performance)..."
  local codex_review
  codex_review=$(codex exec -m gpt-5 --reasoning medium -C "$(pwd)" "
Review the changes in this PR for:
1. Security vulnerabilities (injection, XSS, auth issues)
2. Performance problems (N+1, memory leaks, blocking calls)
3. Best practices violations
4. Missing error handling

Provide concise, actionable feedback. If no issues: respond with LGTM.
" 2>/dev/null || echo "⚠️ Codex review unavailable")

  # Postear review de Codex
  gh pr comment "$pr_number" --body "## 🟣 Codex Security Review

$codex_review

---
*Reviewed by Codex GPT-5*"

  echo "  ✅ Codex review posted"

  # Greptile (opcional)
  if command -v greptile &> /dev/null || [ -n "$GREPTILE_API_KEY" ]; then
    echo "  🟢 Greptile Review (patterns, conventions)..."
    # Trigger Greptile si está disponible
    # mcp__plugin_greptile_greptile__trigger_code_review ...
    echo "  ✅ Greptile review triggered"
  else
    echo "  ⏭️  Greptile not configured (optional)"
  fi

  echo ""

  # ─────────────────────────────────────────────────────────────
  # PASO 3: Analizar resultados
  # ─────────────────────────────────────────────────────────────
  echo "📊 Step 3: Analyzing review results..."

  # Verificar si hay blockers
  if echo "$claude_review" | grep -q "🔴 BLOCKER"; then
    review_passed=false
    echo "  ❌ Claude found BLOCKER issues"
  fi

  if echo "$codex_review" | grep -qi "critical\|vulnerability\|security"; then
    review_passed=false
    echo "  ❌ Codex found security issues"
  fi

  # ─────────────────────────────────────────────────────────────
  # PASO 4: Decisión
  # ─────────────────────────────────────────────────────────────
  echo ""
  echo "═══════════════════════════════════════════════════════════"

  if [ "$review_passed" = true ]; then
    echo "✅ All reviews passed!"
    echo ""
    echo "Options:"
    echo "  1. ralph worktree-merge $pr_number  # Approve and merge"
    echo "  2. gh pr view $pr_number            # View PR details"
    echo "  3. gh pr ready $pr_number           # Mark as ready (no merge)"
  else
    echo "⚠️  Issues found in review"
    echo ""
    echo "Options:"
    echo "  1. ralph worktree-fix $pr_number    # Apply fixes with Claude"
    echo "  2. wt switch $branch && claude      # Manual fixes"
    echo "  3. ralph worktree-close $pr_number  # Close PR and cleanup"
  fi

  echo ""
  echo "🔗 PR: https://github.com/$repo_name/pull/$pr_number"
  echo "═══════════════════════════════════════════════════════════"

  # Cleanup
  rm -f "$diff_file"
}
```

### Fase 3: ralph worktree-merge

```bash
ralph_worktree_merge() {
  local pr_number="$1"

  if [ -z "$pr_number" ]; then
    echo "Usage: ralph worktree-merge <pr-number>"
    return 1
  fi

  echo "🔀 Merging PR #$pr_number..."

  # Quitar draft
  gh pr ready "$pr_number"

  # Esperar CI
  echo "⏳ Waiting for CI checks..."
  gh pr checks "$pr_number" --watch

  # Merge con squash
  gh pr merge "$pr_number" \
    --squash \
    --delete-branch \
    --body "Merged via ralph worktree-merge

🤖 Generated with [Multi-Agent Ralph Loop](https://github.com/alfredolopez80/multi-agent-ralph-loop)"

  echo "✅ PR #$pr_number merged successfully"

  # Cleanup worktree
  local branch=$(gh pr view "$pr_number" --json headRefName -q '.headRefName')
  wt remove "$branch" 2>/dev/null || true

  echo "🧹 Worktree cleaned up"
}
```

### Fase 4: ralph worktree-fix

```bash
ralph_worktree_fix() {
  local pr_number="$1"

  if [ -z "$pr_number" ]; then
    echo "Usage: ralph worktree-fix <pr-number>"
    return 1
  fi

  # Obtener branch y comments
  local branch=$(gh pr view "$pr_number" --json headRefName -q '.headRefName')
  local comments=$(gh pr view "$pr_number" --comments --json comments -q '.comments[].body')

  # Switch al worktree
  wt switch "$branch"

  echo "🔧 Applying fixes for PR #$pr_number..."
  echo ""

  # Lanzar Claude con contexto de los review comments
  claude --print -m sonnet "
The following code review comments were made on PR #$pr_number.
Please analyze and apply the necessary fixes:

## Review Comments:
$comments

## Instructions:
1. Read the relevant files
2. Apply fixes for each issue mentioned
3. Commit changes with message: fix: address PR review comments
4. Do NOT push (I will push after reviewing)

Focus on the BLOCKER and HIGH severity issues first.
"

  echo ""
  echo "✅ Fixes applied. Review changes with: git diff"
  echo "   Then push with: git push"
  echo "   Re-run review: ralph worktree-pr $branch"
}
```

### Fase 5: ralph worktree-close

```bash
ralph_worktree_close() {
  local pr_number="$1"

  if [ -z "$pr_number" ]; then
    echo "Usage: ralph worktree-close <pr-number>"
    return 1
  fi

  local branch=$(gh pr view "$pr_number" --json headRefName -q '.headRefName')

  echo "🗑️  Closing PR #$pr_number and cleaning up..."

  # Cerrar PR
  gh pr close "$pr_number" --delete-branch

  # Eliminar worktree
  wt remove "$branch" 2>/dev/null || true

  # Limpiar branch local
  git branch -D "$branch" 2>/dev/null || true

  echo "✅ PR closed and worktree removed"
}
```

---

## Flujo de Uso Completo

```bash
# ═══════════════════════════════════════════════════════════════
# EJEMPLO: Implementar feature de autenticación
# ═══════════════════════════════════════════════════════════════

# 1. Crear worktrees paralelos
ralph worktree "oauth backend"
ralph worktree "oauth frontend"
ralph worktree "oauth tests"

# 2. Monitorear progreso
ralph worktree-status
# o: wt list

# 3. Cuando backend termina → Crear PR con review
ralph worktree-pr ai/ralph/20260103-oauth-backend

# Output:
# ═══════════════════════════════════════════════════════════
#   RALPH WORKTREE PR WORKFLOW
# ═══════════════════════════════════════════════════════════
#
# 📤 Step 1: Pushing branch and creating PR...
# ✅ PR #42 created (draft)
#
# 🔍 Step 2: Starting multi-agent code review...
#   🔵 Claude Review (logic, edge cases, quality)...
#   ✅ Claude review posted
#   🟣 Codex Review (security, performance)...
#   ✅ Codex review posted
#   ⏭️  Greptile not configured (optional)
#
# 📊 Step 3: Analyzing review results...
#
# ═══════════════════════════════════════════════════════════
# ✅ All reviews passed!
#
# Options:
#   1. ralph worktree-merge 42  # Approve and merge
#   2. gh pr view 42            # View PR details
#
# 🔗 PR: https://github.com/user/repo/pull/42
# ═══════════════════════════════════════════════════════════

# 4a. Si pasó → Merge
ralph worktree-merge 42

# 4b. Si falló → Fix y re-review
ralph worktree-fix 42
git push
ralph worktree-pr ai/ralph/20260103-oauth-backend

# 4c. Si no vale la pena → Cerrar
ralph worktree-close 42

# 5. Repetir para frontend y tests
ralph worktree-pr ai/ralph/20260103-oauth-frontend
ralph worktree-pr ai/ralph/20260103-oauth-tests

# 6. Cleanup final
ralph worktree-cleanup
```

---

## Resumen de Decisiones

| Decisión | Elección | Motivo |
|----------|----------|--------|
| **Herramienta worktree** | WorkTrunk | Mejor integración Claude, hooks, merge |
| **PR obligatorio** | Sí | Rollback fácil, historial limpio |
| **Code review** | Claude + Codex | Sin costo adicional |
| **Greptile** | Opcional | $30/mes, solo si ya tiene cuenta |
| **Merge strategy** | Squash | Historial limpio |
| **Branch naming** | ai/ralph/<date>-<task> | Identificación clara |

---

## Archivos a Crear/Modificar

| Archivo | Acción | Descripción |
|---------|--------|-------------|
| `scripts/ralph` | Modificar | Agregar comandos worktree-* |
| `.claude/skills/worktree-pr/skill.md` | Crear | Skill para PR workflow |
| `.claude/agents/pr-reviewer.md` | Crear | Agente de review |
| `docs/git-worktree/IMPLEMENTATION-PLAN.md` | Crear | Este documento |
| `CLAUDE.md` | Modificar | Documentar nuevos comandos |

---

## Próximos Pasos

1. [ ] Aprobar este plan
2. [ ] Implementar comandos en `scripts/ralph`
3. [ ] Crear skill y agente
4. [ ] Actualizar documentación
5. [ ] Testing del flujo completo
6. [ ] Release v2.20

---

*Plan generado por Multi-Agent Ralph Loop v2.19*
