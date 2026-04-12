# Hook Census — Wave H1

**Generated**: 2026-04-12
**Source**: `~/.claude/settings.json` cross-referenced against `.claude/hooks/` on disk

---

## Summary

| Metric | Count |
|--------|-------|
| Total files on disk (`.claude/hooks/`, excl. `lib/`, `__pycache__`) | 83 |
| WIRED (registered in settings.json, repo path) | 68 unique files (69 refs, `repo-boundary-guard.sh` wired twice) |
| WIRED (registered in settings.json, `~/.claude/hooks/` path) | 2 (universal-aristotle-gate.sh, universal-prompt-classifier.sh) |
| WIRED (external, non-repo) | 2 (context-mode plugin hooks) |
| ORPHANED (on disk, NOT wired) | 11 (original) + 3 (H1.6) = 14 |
| DEAD (.bak, .ARCHIVED) | 4 |
| **Total wired** | **72 (68 repo + 2 global + 2 external)** |

---

## Wired Hooks by Event Type

| Event | Count | Target |
|-------|-------|--------|
| PostToolUse | 20 repo + 0 global | <=4 |
| PreToolUse | 13 repo + 1 global + 1 external | <=3 |
| SessionStart | 10 repo + 1 external | <=2 |
| UserPromptSubmit | 6 repo + 1 global | <=3 |
| Stop | 6 | <=2 |
| SessionEnd | 4 | <=2 |
| SubagentStop | 2 | 2 |
| TeammateIdle | 2 | 2 |
| SubagentStart | 1 | 1 |
| TaskCompleted | 1 | 1 |
| TaskCreated | 1 | 1 |
| PreCompact | 1 | 1 |
| **TOTAL** | **71 repo + 3 global + 2 external = 76** | — |

---

## Full File Census

### PostToolUse — 20 wired (20 repo + 0 global)

| # | File | Status | Matcher | Async | Timestamp Output |
|---|------|--------|---------|-------|-----------------|
| 1 | `audit-secrets.js` | WIRED | `*` | no (timeout:30) | unknown |
| 2 | `vault-fact-extractor.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 3 | `plan-sync-post-step.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 4 | `glm-context-update.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 5 | `progress-tracker.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 6 | `quality-parallel-async.sh` | WIRED | `Edit\|Write\|Bash` | yes (timeout:60) | unknown |
| 7 | `status-auto-check.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 8 | `console-log-detector.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 9 | `ai-code-audit.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 10 | `auto-format-prettier.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 11 | `session-accumulator.sh` | WIRED | `Edit\|Write\|Bash` | yes | unknown |
| 12 | `parallel-explore.sh` | WIRED | `Task` | no | unknown |
| 13 | `recursive-decompose.sh` | WIRED | `Task` | no | unknown |
| 14 | `adversarial-auto-trigger.sh` | WIRED | `Task` | no | unknown |
| 15 | `action-report-tracker.sh` | WIRED | `Task` | no | unknown |
| 16 | `batch-progress-tracker.sh` | WIRED | `Task` | no | unknown |
| 17 | `task-orchestration-optimizer.sh` | WIRED | `Task` | no | unknown |
| 18 | `code-review-auto.sh` | WIRED | `TaskUpdate` | no | unknown |
| 19 | `plan-analysis-cleanup.sh` | WIRED | `ExitPlanMode` | no | unknown |
| 20 | `todo-plan-sync.sh` | WIRED | `TodoWrite` | no | unknown |

**H1.6 Changes**: `decision-extractor.sh` + `semantic-realtime-extractor.sh` → merged into `vault-fact-extractor.sh` (thin wrapper). `auto-background-swarm.sh` + `task-project-tracker.sh` → archived. `universal-step-tracker.sh` (global) → archived.

### PreToolUse — 14 wired (12 repo + 1 global + 1 external)

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `checkpoint-auto-save.sh` | WIRED | `Edit\|Write` |
| 2 | `smart-skill-reminder.sh` | WIRED | `Edit\|Write` |
| 3 | `git-safety-guard.py` | WIRED | `Bash` |
| 4 | `repo-boundary-guard.sh` | WIRED | `Bash` + `Agent\|Task` (2 refs) |
| 5 | `lsa-pre-step.sh` | WIRED | `Agent\|Task` |
| 6 | `fast-path-check.sh` | WIRED | `Agent\|Task` |
| 7 | `smart-memory-search.sh` | WIRED | `Agent\|Task` |
| 8 | `skill-validator.sh` | WIRED | `Agent\|Task` |
| 9 | `checkpoint-smart-save.sh` | WIRED | `Agent\|Task` |
| 10 | `orchestrator-auto-learn.sh` | WIRED | `Agent\|Task` |
| 11 | `promptify-security.sh` | WIRED | `Agent\|Task` |
| 12 | `inject-session-context.sh` | WIRED | `Agent\|Task` |
| 13 | `auto-plan-state.sh` | WIRED | `Agent\|Task` |
| G1 | `~/.claude/hooks/universal-aristotle-gate.sh` | WIRED (global) | `*` |
| E1 | context-mode plugin pretooluse.mjs | WIRED (external) | `Bash\|WebFetch\|Read\|...` |

### SessionStart — 11 wired (10 repo + 1 external)

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `post-compact-restore.sh` | WIRED | `compact` |
| 2 | `wake-up-layer-stack.sh` | WIRED | `*` |
| 3 | `project-state.sh` | WIRED | `*` |
| 4 | `vault-graduation.sh` | WIRED | `*` |
| 5 | `vault-promotion.sh` | WIRED | `*` |
| 6 | `auto-migrate-plan-state.sh` | WIRED | `*` |
| 7 | `auto-sync-global.sh` | WIRED | `*` |
| 8 | `session-start-restore-context.sh` | WIRED | `*` |
| 9 | `orchestrator-init.sh` | WIRED | `*` |
| 10 | `project-backup-metadata.sh` | WIRED | `*` |
| 11 | `session-start-repo-summary.sh` | WIRED | `*` |
| E1 | context-mode plugin sessionstart.mjs | WIRED (external) | `""` |

### UserPromptSubmit — 7 wired (6 repo + 1 global)

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `context-warning.sh` | WIRED | `*` |
| 2 | `command-router.sh` | WIRED | `*` |
| 3 | `periodic-reminder.sh` | WIRED | `*` |
| 4 | `plan-state-adaptive.sh` | WIRED | `*` |
| 5 | `plan-state-lifecycle.sh` | WIRED | `*` |
| 6 | `aristotle-analysis-display.sh` | WIRED | `*` |
| G1 | `~/.claude/hooks/universal-prompt-classifier.sh` | WIRED (global) | `*` |

### Stop — 6 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `orchestrator-report.sh` | WIRED | `*` |
| 2 | `continuous-learning.sh` | WIRED | `*` |
| 3 | `ralph-stop-quality-gate.sh` | WIRED | `*` |
| 4 | `sentry-report.sh` | WIRED | `*` |
| 5 | `stop-slop-hook.sh` | WIRED | `*` |
| 6 | `vault-writeback.sh` | WIRED | `*` |

### SessionEnd — 4 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `session-end-handoff.sh` | WIRED | `*` |
| 2 | `vault-index-updater.sh` | WIRED | `*` |
| 3 | `vault-wing-compiler.sh` | WIRED | `*` |
| 4 | `vault-log-writer.sh` | WIRED | `*` |

### SubagentStop — 2 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `subagent-stop-universal.sh` | WIRED | `*` |
| 2 | `ralph-subagent-stop.sh` | WIRED | `ralph-*` |

### TeammateIdle — 2 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `teammate-idle-quality-gate.sh` | WIRED | `*` |
| 2 | `agent-diary-writer.sh` | WIRED | `*` |

### SubagentStart — 1 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `ralph-subagent-start.sh` | WIRED | `ralph-*` |

### TaskCompleted — 1 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `task-completed-quality-gate.sh` | WIRED | `*` |

### TaskCreated — 1 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `task-plan-sync.sh` | WIRED | `*` |

### PreCompact — 1 wired

| # | File | Status | Matcher |
|---|------|--------|---------|
| 1 | `pre-compact-handoff.sh` | WIRED | `*` |

---

## DEAD Files (4)

| File | Reason |
|------|--------|
| `post-compact-restore.sh.ARCHIVED` | Archived backup |
| `session-start-repo-summary.sh.pre-claude-mem-removal.20260407.bak` | Pre-claude-mem-removal backup |
| `session-start-restore-context.sh.pre-claude-mem-removal.20260407.bak` | Pre-claude-mem-removal backup |
| `smart-memory-search.sh.pre-claude-mem-removal.20260407.bak` | Pre-claude-mem-removal backup |

---

## ORPHANED Files (14) — ARCHIVED

All orphaned files have been moved to `.claude/archive/` via `git mv`.

| # | File | Notes | Disposition |
|---|------|-------|-------------|
| 1 | `deslop-auto-clean.sh` | Deslop functionality — not wired | Archived |
| 2 | `glm-visual-validation.sh` | GLM visual validation — not wired | Archived |
| 3 | `glm5-subagent-stop.sh` | Superseded by subagent-stop-universal.sh | Archived |
| 4 | `quality-gates-v2.sh` | Superseded by quality-parallel-async.sh | Archived |
| 5 | `sec-context-validate.sh` | Security context validation — not wired | Archived |
| 6 | `security-full-audit.sh` | Full security audit — not wired | Archived |
| 7 | `typescript-quick-check.sh` | TypeScript quick check — not wired | Archived |
| 8 | `vault-lint.sh` | Vault linting — not wired | Archived |
| 9 | `universal-aristotle-gate.sh` | Repo copy — global `~/.claude/hooks/` copy is wired | Archived |
| 10 | `universal-prompt-classifier.sh` | Repo copy — global `~/.claude/hooks/` copy is wired | Archived |
| 11 | `universal-step-tracker.sh` | Global copy removed in H1.6 — was PostToolUse(*) | Archived (H1.6) |
| 12 | `auto-background-swarm.sh` | Broken $1 args — was PostToolUse(Task) | Archived (H1.6) |
| 13 | `task-project-tracker.sh` | Matcher mismatch — was PostToolUse(Task) | Archived (H1.6) |
| 14 | `decision-extractor.sh` + `semantic-realtime-extractor.sh` | Merged into vault-fact-extractor.sh — kept on disk as internal modules | Preserved (H1.6) |

---

## Consolidation Plan

### Current vs Target Wired Count

| Event | Current (repo) | Current (total) | Target | Reduction Needed |
|-------|---------------|-----------------|--------|-----------------|
| PostToolUse | 20 | 20 | <=4 | -16 |
| PreToolUse | 13 | 15 | <=3 | -12 |
| SessionStart | 10 | 11 | <=2 | -9 |
| UserPromptSubmit | 6 | 7 | <=3 | -4 |
| Stop | 6 | 6 | <=2 | -4 |
| SessionEnd | 4 | 4 | <=2 | -2 |
| SubagentStop | 2 | 2 | 2 | 0 |
| TeammateIdle | 2 | 2 | 2 | 0 |
| SubagentStart | 1 | 1 | 1 | 0 |
| TaskCompleted | 1 | 1 | 1 | 0 |
| TaskCreated | 1 | 1 | 1 | 0 |
| PreCompact | 1 | 1 | 1 | 0 |

### Proposed Merges

#### PostToolUse: 20 -> 4

1. **`post-quality-gate.sh`** (merge of: quality-parallel-async, ai-code-audit, console-log-detector, auto-format-prettier, status-auto-check)
   - Unified quality/lint/format gate, async, runs on `Edit|Write|Bash`
2. **`post-memory-sync.sh`** (merge of: vault-fact-extractor, plan-sync-post-step, glm-context-update, session-accumulator, progress-tracker)
   - Unified memory/context/plan synchronization, async, runs on `Edit|Write|Bash`
3. **`post-task-orchestration.sh`** (merge of: parallel-explore, recursive-decompose, adversarial-auto-trigger, action-report-tracker, batch-progress-tracker, task-orchestration-optimizer, code-review-auto, plan-analysis-cleanup, todo-plan-sync)
   - Unified task orchestration/tracking, runs on `Task|TaskUpdate|ExitPlanMode|TodoWrite`
4. **`audit-secrets.js`** (keep as-is)
   - Security audit must remain isolated, runs on `*`

#### PreToolUse: 14 -> 3

1. **`pre-safety-gate.sh`** (merge of: git-safety-guard.py, repo-boundary-guard, promptify-security)
   - Unified safety/security gate for `Bash` and `Agent|Task`
2. **`pre-context-loader.sh`** (merge of: smart-memory-search, inject-session-context, auto-plan-state, lsa-pre-step, fast-path-check, skill-validator, orchestrator-auto-learn, checkpoint-auto-save, checkpoint-smart-save)
   - Unified context/memory/checkpoint loader for `Agent|Task` and `Edit|Write`
3. **`smart-skill-reminder.sh`** (keep as-is or merge into pre-context-loader)
   - Skill reminder for `Edit|Write`

#### SessionStart: 11 -> 2

1. **`session-init.sh`** (merge of: wake-up-layer-stack, project-state, vault-graduation, vault-promotion, auto-migrate-plan-state, auto-sync-global, session-start-restore-context, orchestrator-init, project-backup-metadata, session-start-repo-summary)
   - Unified session initialization, runs on `*`
2. **`post-compact-restore.sh`** (keep as-is)
   - Compact-specific restore, runs on `compact` matcher

#### UserPromptSubmit: 7 -> 3

1. **`prompt-gate.sh`** (merge of: context-warning, command-router, periodic-reminder)
   - Unified prompt routing/warnings
2. **`plan-state-manager.sh`** (merge of: plan-state-adaptive, plan-state-lifecycle)
   - Unified plan state management
3. **`aristotle-analysis-display.sh`** (keep as-is)
   - Aristotle methodology display

#### Stop: 6 -> 2

1. **`stop-quality-report.sh`** (merge of: orchestrator-report, continuous-learning, ralph-stop-quality-gate, stop-slop-hook)
   - Unified stop quality gate + reporting
2. **`stop-vault-sync.sh`** (merge of: sentry-report, vault-writeback)
   - Unified vault/external sync on stop

#### SessionEnd: 4 -> 2

1. **`session-end-save.sh`** (merge of: session-end-handoff, vault-log-writer)
   - Unified session save + logging
2. **`session-end-index.sh`** (merge of: vault-index-updater, vault-wing-compiler)
   - Unified vault index compilation
