# Hooks Inventory — 2026-04-07

**Purpose**: Audit of all hooks in `.claude/hooks/` for Wave 1.1 (MemPalace adoption) dead-hook removal.
**Branch**: `feat/mempalace-adoption`
**Wave**: W1.1 — delete-dead-hooks (`ralph-coder-alpha`)
**Total hooks found**: 87 (per prior memory entry)
**Total files in `.claude/hooks/`**: 84 (3 already removed before this wave)

---

## Classification Legend

- **active** — Registered in at least one settings.json AND/OR called by an active hook
- **dead** — Not registered in any settings.json AND not called by any active hook
- **skip-registered** — Plan listed as dead but verification found it IS registered
- **already-deleted** — File no longer exists (removed in prior wave)

---

## W1.1 Plan Hooks — Verification Results

These are the 11 hooks the plan specified for deletion. Each was verified against all 3 settings files and cross-referencing hooks.

| hook_path | registered_in | called_by | classification | reason |
|---|---|---|---|---|
| `.claude/hooks/action-report-tracker.sh` | `~/.claude/settings.json` (PostToolUse/Task), `~/.cc-mirror/zai/settings.json` (PostToolUse/Task) | none | **skip-registered** | ACTIVE — wired in 2 settings files; plan's "dead" classification was incorrect |
| `.claude/hooks/cleanup-secrets-db.js` | none | `auto-sync-global.sh` (string reference, not exec) | **already-deleted** | File does not exist on disk; removed in prior wave |
| `.claude/hooks/global-task-sync.sh` | none | Referenced in dead utility scripts only (`cleanup-obsolete-hooks.sh`, `validate-hooks-before-removal.sh`, `validate-hooks-simple.sh`) — none of which are registered | **dead** | No live registration; utility scripts that reference it are themselves unregistered |
| `.claude/hooks/pre-commit-batch-skills-test.sh` | none | none | **dead** | Pre-commit hook never wired into any settings.json event |
| `.claude/hooks/pre-commit-installer-tests.sh` | none | none | **dead** | Pre-commit hook never wired into any settings.json event |
| `.claude/hooks/ralph-subagent-stop.sh` | `~/.claude/settings.json` (SubagentStop/ralph-*), `~/.cc-mirror/zai/settings.json` (SubagentStop/ralph-*) | `subagent-stop-universal.sh` (exec delegation) | **skip-registered** | ACTIVE — wired as SubagentStop handler for ralph-* agents in 2 settings files |
| `.claude/hooks/session-start-welcome.sh` | none | none | **dead** | SessionStart welcome hook; replaced by session-start-repo-summary.sh |
| `.claude/hooks/statusline-health-monitor.sh` | none | none | **dead** | UserPromptSubmit health monitor; orphaned since statusline refactor |
| `.claude/hooks/subagent-stop-universal.sh` | `~/.claude/settings.json` (SubagentStop/*), `~/.cc-mirror/zai/settings.json` (SubagentStop/*) | `glm5-subagent-stop.sh` (exec delegation) | **skip-registered** | ACTIVE — wired as universal SubagentStop handler in 2 settings files |
| `.claude/hooks/task-primitive-sync.sh` | none | `validate-hooks-before-removal.sh` (unregistered utility script) | **dead** | Task primitive sync replaced by plan-sync-post-step.sh; no live callers |
| `.claude/hooks/verification-subagent.sh` | none | none | **dead** | Subagent spawn helper; orphaned since Agent Teams replaced pattern |

**Summary of W1.1 plan hooks**:
- 7 to DELETE (confirmed dead)
- 3 SKIPPED (found to be actively registered — plan's classification was wrong)
- 1 ALREADY DELETED (cleanup-secrets-db.js)

---

## All Hooks — Full Classification Table

| hook_path | registered_in | called_by | classification |
|---|---|---|---|
| `.claude/hooks/action-report-tracker.sh` | `~/.claude/settings.json` PostToolUse/Task, `~/.cc-mirror/zai/settings.json` PostToolUse/Task | — | active |
| `.claude/hooks/adversarial-auto-trigger.sh` | all 3 settings (PostToolUse/Task) | — | active |
| `.claude/hooks/agent-memory-auto-init.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/ai-code-audit.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/auto-background-swarm.sh` | all 3 settings (PostToolUse/Task) | — | active |
| `.claude/hooks/auto-format-prettier.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/auto-migrate-plan-state.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/auto-plan-state.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/auto-sync-global.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/batch-progress-tracker.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (PostToolUse/Task) | — | active |
| `.claude/hooks/checkpoint-auto-save.sh` | all 3 settings (PreToolUse/Edit\|Write) | — | active |
| `.claude/hooks/checkpoint-smart-save.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/code-review-auto.sh` | all 3 settings (PostToolUse/TaskUpdate or Task) | — | active |
| `.claude/hooks/command-router.sh` | all 3 settings (UserPromptSubmit/*) | — | active |
| `.claude/hooks/console-log-detector.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/context-warning.sh` | all 3 settings (UserPromptSubmit/*) | — | active |
| `.claude/hooks/continuous-learning.sh` | all 3 settings (Stop/*) | — | active |
| `.claude/hooks/decision-extractor.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/deslop-auto-clean.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/episodic-auto-convert.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/fast-path-check.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/git-safety-guard.py` | all 3 settings (PreToolUse/Bash) | — | active |
| `.claude/hooks/glm-context-update.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/glm-visual-validation.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/glm5-subagent-stop.sh` | `~/.cc-mirror/minimax/settings.json` (SubagentStop/glm5-*) | — | active |
| `.claude/hooks/global-task-sync.sh` | none | dead utility scripts only | **dead — DELETED** |
| `.claude/hooks/inject-session-context.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/lib/worktree-utils.sh` | N/A (library, sourced) | multiple hooks | active (library) |
| `.claude/hooks/lsa-pre-step.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/memory-write-trigger.sh` | all 3 settings (UserPromptSubmit/*) | — | active |
| `.claude/hooks/orchestrator-auto-learn.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/orchestrator-init.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/orchestrator-report.sh` | all 3 settings (Stop/*) | — | active |
| `.claude/hooks/parallel-explore.sh` | all 3 settings (PostToolUse/Task) | — | active |
| `.claude/hooks/periodic-reminder.sh` | all 3 settings (UserPromptSubmit/*) | — | active |
| `.claude/hooks/plan-analysis-cleanup.sh` | all 3 settings (PostToolUse/ExitPlanMode) | — | active |
| `.claude/hooks/plan-state-adaptive.sh` | all 3 settings (UserPromptSubmit/*) | — | active |
| `.claude/hooks/plan-state-lifecycle.sh` | all 3 settings (UserPromptSubmit/*) | — | active |
| `.claude/hooks/plan-sync-post-step.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/post-compact-restore.sh` | all 3 settings (SessionStart/compact) | — | active |
| `.claude/hooks/pre-commit-batch-skills-test.sh` | none | none | **dead — DELETED** |
| `.claude/hooks/pre-commit-installer-tests.sh` | none | none | **dead — DELETED** |
| `.claude/hooks/pre-compact-handoff.sh` | all 3 settings (PreCompact/*) | — | active |
| `.claude/hooks/procedural-forget.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (UserPromptSubmit/*) | — | active |
| `.claude/hooks/procedural-inject.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/progress-tracker.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/project-backup-metadata.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/project-state.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/promptify-security.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/quality-gates-v2.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/quality-parallel-async.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/ralph-stop-quality-gate.sh` | all 3 settings (Stop/*) | — | active |
| `.claude/hooks/ralph-subagent-start.sh` | all 3 settings (SubagentStart/ralph-*) | — | active |
| `.claude/hooks/ralph-subagent-stop.sh` | `~/.claude/settings.json`, `~/.cc-mirror/zai/settings.json` (SubagentStop/ralph-*) | — | **skip-registered** (plan said dead) |
| `.claude/hooks/recursive-decompose.sh` | all 3 settings (PostToolUse/Task) | — | active |
| `.claude/hooks/reflection-engine.sh` | all 3 settings (Stop/*) | — | active |
| `.claude/hooks/repo-boundary-guard.sh` | all 3 settings (PreToolUse/Bash, PreToolUse/Task) | — | active |
| `.claude/hooks/rules-injector.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/sanitize-secrets.js` | all 3 settings (PostToolUse/*) | — | active |
| `.claude/hooks/sec-context-validate.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/security-full-audit.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/semantic-realtime-extractor.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active (registered, disabled via internal flag) |
| `.claude/hooks/sentry-report.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (Stop/*) | — | active |
| `.claude/hooks/session-accumulator.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/session-end-handoff.sh` | `~/.claude/settings.json` (SessionEnd/*), `~/.cc-mirror/zai/settings.json` (SessionEnd/*), `~/.cc-mirror/minimax/settings.json` (Stop/*) | — | active |
| `.claude/hooks/session-start-repo-summary.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/session-start-restore-context.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/session-start-welcome.sh` | none | none | **dead — DELETED** |
| `.claude/hooks/skill-validator.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/smart-memory-search.sh` | all 3 settings (PreToolUse/Task) | — | active |
| `.claude/hooks/smart-skill-reminder.sh` | all 3 settings (PreToolUse/Edit\|Write) | — | active |
| `.claude/hooks/status-auto-check.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/statusline-health-monitor.sh` | none | none | **dead — DELETED** |
| `.claude/hooks/stop-slop-hook.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (Stop/*) | — | active |
| `.claude/hooks/subagent-stop-universal.sh` | `~/.claude/settings.json`, `~/.cc-mirror/zai/settings.json` (SubagentStop/*) | `glm5-subagent-stop.sh` (exec delegation) | **skip-registered** (plan said dead) |
| `.claude/hooks/task-completed-quality-gate.sh` | all 3 settings (TaskCompleted/*) | — | active |
| `.claude/hooks/task-orchestration-optimizer.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (PostToolUse/Task) | — | active |
| `.claude/hooks/task-primitive-sync.sh` | none | unregistered utility scripts only | **dead — DELETED** |
| `.claude/hooks/task-project-tracker.sh` | `~/.claude/settings.json`, `~/.cc-mirror/minimax/settings.json` (PostToolUse/Task) | — | active |
| `.claude/hooks/teammate-idle-quality-gate.sh` | all 3 settings (TeammateIdle/*) | — | active |
| `.claude/hooks/todo-plan-sync.sh` | all 3 settings (PostToolUse/TodoWrite) | — | active |
| `.claude/hooks/typescript-quick-check.sh` | all 3 settings (PostToolUse/Edit\|Write\|Bash) | — | active |
| `.claude/hooks/vault-graduation.sh` | all 3 settings (SessionStart/*) | — | active |
| `.claude/hooks/vault-index-updater.sh` | `~/.claude/settings.json` (SessionEnd/*), `~/.cc-mirror/minimax/settings.json` (Stop/*) | — | active |
| `.claude/hooks/verification-subagent.sh` | none | none | **dead — DELETED** |

---

## Deletions Performed

| File | Reason |
|---|---|
| `.claude/hooks/global-task-sync.sh` | v2.69.0 hook; replaced by plan-sync-post-step.sh; unregistered; only referenced in dead utility scripts |
| `.claude/hooks/pre-commit-batch-skills-test.sh` | Pre-commit hook type never supported in Claude Code hooks system; no registration |
| `.claude/hooks/pre-commit-installer-tests.sh` | Pre-commit hook type never supported in Claude Code hooks system; no registration |
| `.claude/hooks/session-start-welcome.sh` | Superseded by session-start-repo-summary.sh; no registration |
| `.claude/hooks/statusline-health-monitor.sh` | Orphaned since statusline architecture refactor; no registration |
| `.claude/hooks/task-primitive-sync.sh` | Replaced by plan-sync-post-step.sh; only referenced in dead utility scripts |
| `.claude/hooks/verification-subagent.sh` | Verification pattern replaced by Agent Teams; no registration |

## Skipped (Plan Said Dead, Verification Found Active)

| File | Reason |
|---|---|
| `.claude/hooks/action-report-tracker.sh` | Registered in `~/.claude/settings.json` and `~/.cc-mirror/zai/settings.json` as PostToolUse/Task handler |
| `.claude/hooks/ralph-subagent-stop.sh` | Registered in `~/.claude/settings.json` and `~/.cc-mirror/zai/settings.json` as SubagentStop/ralph-* handler |
| `.claude/hooks/subagent-stop-universal.sh` | Registered in `~/.claude/settings.json` and `~/.cc-mirror/zai/settings.json` as SubagentStop/* handler |

---

*Generated by ralph-coder-alpha, Wave 1.1, feat/mempalace-adoption*
