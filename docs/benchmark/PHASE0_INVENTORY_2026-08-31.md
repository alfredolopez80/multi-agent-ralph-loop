# Phase 0 — Executable Inventory of the Real Runtime (issue #69)

Generated: 2026-08-31T12:08:16Z · Instrument: `scripts/benchmark/phase0_inventory.sh` (+ `phase0_inventory.py`)

## Acceptance (issue #69 Phase 0)

- [x] Exact starting SHA and active settings snapshot recorded in the baseline report.
- [x] Every active hook registration classified once; no `unknown` entries.
- [x] Generated/copied/symlinked installation targets identified so deletion removes both source and installed residue.
- [x] No provider-specific model ID is used to classify runtime ownership.

## Provenance

| field | value |
|---|---|
| `main` SHA at run | `7f8a962a91d19546cc0503e2f11d9deff7254076` |
| this branch / HEAD | `worktree-zc-3` @ `a14be0c3101beb99b135935cb514f157a2e99781` |
| ACTIVE settings | `/Users/alfredolopez/.claude/settings.json` |
| ACTIVE settings sha256 | `46efd9e6e67c3d4f3eae28baffe528c71d2116dea108ac0091fbcdff569d6b73` |
| ACTIVE settings snapshot | `results/phase0/settings-active.snapshot.json` (copied at run time) |
| classified rows | 372 (77 active registrations incl. statusLine) |
| UNKNOWN rows | **0** (asserted; run exits 3 otherwise) |
| security baseline | v1.2.0 (2026-08-25), controls: permission-pipeline, git-safety, repo-boundary, k8s-context, worktree-utils, skill-security |
| declared gaps (not components) | secrets-ordinary-work, red-toxic, mcp-egress, package-manager, symlink-escape |

## Method

Enumeration order: (1) ACTIVE `~/.claude/settings.json` — hook registrations per
event/matcher/command, `statusLine`, top-level keys, `env` keys; (2)
`settings.security-only.json`; (3) `SECURITY_BASELINE.json` controls+sources;
(4) installer/sync/validator artifacts (`install*.sh`, `scripts/install-*`,
`scripts/validate-*`, `.claude/scripts/{validate,sync}-*`); (5) sources under
`.claude/hooks` (incl. `lib/`, `k8s_context_guard/`), `.claude/rules-src`,
`.claude/agents`, `.claude/skills`, `.claude/commands`, `.claude/scripts`;
(6) installed residue under `~/.claude` (symlink vs copy, parity per file).

Owner semantics (from #69 keep-planes):

- **SECURITY-REQUIRED** — security plane. Membership is manifest-driven:
  `SECURITY_BASELINE.json` controls+sources (authoritative), then
  `settings.security-only.json` registrations, then one explicit name
  (`audit-secrets.js`, active secrets audit tied to gap `secrets-ordinary-work`),
  then security config records (`permissions`, `K8S_GUARD_ALLOWED_CONTEXTS`).
- **TASK-STATE-BOUNDARY** — canonical task state + Recall plane: session
  lifecycle, Q-team coordination, plan/task state, memory/vault/recall,
  statusline/state display, methodology gates, task-cycle gates. Rule table
  `STATE_RULES` in the instrument, ordered, first match wins; every active
  registration matches exactly one security rule or one state rule.
- **EXPLICIT/COLD-PATH** — invoked only explicitly: native Claude surfaces
  (skills/agents/commands), installers/sync/validators, support utilities,
  installable-profile-only hooks.
- **DELETE** — evidence-backed dead: build artifacts (`__pycache__`, untracked),
  stale residue (`.old`, stale symlinks), orphan sources (zero tracked
  references after excluding the inventory's own outputs), broken
  registrations (resolve to a missing file).

Activation: `hot` = auto-fired by the active settings; `cold` = explicit/
installable/referenced only. `DELETE` rows carry `stale`/`orphan`/`n/a`.

Fail-loud contract: an active registration matching no rule yields `UNKNOWN`
and the run exits 3 — a future hook added to settings fails this inventory
until classified. `--selftest` proves the UNKNOWN path fires (exit 4 on
failure) without touching the tree. Reference counting excludes the
inventory's own outputs, so re-runs are deterministic.

## Summary matrix

| area | total | SECURITY-REQUIRED | TASK-STATE-BOUNDARY | EXPLICIT/COLD-PATH | DELETE |
|---|---|---|---|---|---|
| active-registration | 77 | 11 | 66 | 0 | 0 |
| agents | 37 | 0 | 0 | 36 | 1 |
| artifacts | 2 | 0 | 0 | 0 | 2 |
| claude-scripts | 26 | 0 | 9 | 16 | 1 |
| commands | 1 | 0 | 0 | 1 | 0 |
| distributors | 24 | 0 | 0 | 24 | 0 |
| hooks | 93 | 13 | 73 | 7 | 0 |
| installed-residue | 7 | 0 | 3 | 3 | 1 |
| rules-src | 7 | 0 | 7 | 0 | 0 |
| security-manifest | 2 | 2 | 0 | 0 | 0 |
| settings-record | 33 | 2 | 31 | 0 | 0 |
| skills | 63 | 0 | 0 | 63 | 0 |
| **TOTAL** | **372** | **28** | **189** | **150** | **5** |

## Active registrations (the hot runtime)

| event | matcher | name | owner | plane | exists | note |
|---|---|---|---|---|---|---|
| Notification | * | qteam-blocked-notify.sh | TASK-STATE-BOUNDARY | qteam-coordination | True | active registration |
| PostToolBatch | - | react-doctor.mjs | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| PostToolUse | Task | action-report-tracker.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PostToolUse | Task | adversarial-auto-trigger.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| PostToolUse | Edit\|Write\|Bash | ai-code-audit.sh | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| PostToolUse | * | audit-secrets.js | SECURITY-REQUIRED | secrets-audit | True | active secrets audit; companion of declared gap secrets-ordinary-work |
| PostToolUse | Edit\|Write\|Bash | auto-format-prettier.sh | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| PostToolUse | Task | batch-progress-tracker.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PostToolUse | TaskUpdate | code-review-auto.sh | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| PostToolUse | Edit\|Write\|Bash | console-log-detector.sh | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| PostToolUse | Task | parallel-explore.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| PostToolUse | ExitPlanMode | plan-analysis-cleanup.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PostToolUse | Edit\|Write\|Bash | plan-sync-post-step.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PostToolUse | Edit\|Write\|Bash | progress-tracker.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PostToolUse | Edit\|Write\|Bash | quality-parallel-async.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| PostToolUse | Task | recursive-decompose.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| PostToolUse | Edit\|Write\|Bash | session-accumulator.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| PostToolUse | Edit\|Write\|Bash | status-auto-check.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PostToolUse | TodoWrite | todo-plan-sync.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PostToolUse | Edit\|Write\|Bash | vault-fact-extractor.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| PreCompact | * | pre-compact-handoff.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| PreToolUse | Edit\|Write | checkpoint-auto-save.sh | TASK-STATE-BOUNDARY | orchestrator-state | True | active registration |
| PreToolUse | Agent\|Task | checkpoint-smart-save.sh | TASK-STATE-BOUNDARY | orchestrator-state | True | active registration |
| PreToolUse | Agent\|Task | fast-path-check.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| PreToolUse | Bash | git-safety-guard.py | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Agent\|Task | inject-session-context.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| PreToolUse | Bash | k8s-context-guard-v2.py | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Agent\|Task | lsa-pre-step.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| PreToolUse | Agent\|Task | orchestrator-auto-learn.sh | TASK-STATE-BOUNDARY | orchestrator-state | True | active registration |
| PreToolUse | Edit\|Write | permission-guard.sh | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Bash | permission-guard.sh | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Agent\|Task | permission-guard.sh | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Agent\|Task | promptify-security.sh | SECURITY-REQUIRED | secrets-audit | True | active secrets audit; companion of declared gap secrets-ordinary-work |
| PreToolUse | Edit\|Write | repo-boundary-guard.sh | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Bash | repo-boundary-guard.sh | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Agent\|Task | repo-boundary-guard.sh | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Skill | skill-validator.sh | SECURITY-REQUIRED | security-baseline-control | True | named by SECURITY_BASELINE.json controls |
| PreToolUse | Agent\|Task | smart-memory-search.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| PreToolUse | * | universal-aristotle-gate.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| SessionEnd | * | memory-projection.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| SessionEnd | * | session-end-handoff.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| SessionEnd | * | vault-index-updater.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| SessionEnd | * | vault-log-writer.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| SessionEnd | * | vault-weekly-compile.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| SessionEnd | * | vault-wing-compiler.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| SessionStart | * | auto-migrate-plan-state.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| SessionStart | * | auto-sync-global.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| SessionStart | - | context-mode-cache-heal.mjs | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| SessionStart | * | orchestrator-init.sh | TASK-STATE-BOUNDARY | orchestrator-state | True | active registration |
| SessionStart | compact | post-compact-restore.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| SessionStart | * | project-backup-metadata.sh | TASK-STATE-BOUNDARY | orchestrator-state | True | active registration |
| SessionStart | * | project-state.sh | TASK-STATE-BOUNDARY | orchestrator-state | True | active registration |
| SessionStart | * | session-start-repo-summary.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| SessionStart | * | session-start-restore-context.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| SessionStart | * | vault-graduation.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| SessionStart | * | vault-promotion.sh | TASK-STATE-BOUNDARY | memory-recall | True | active registration |
| SessionStart | * | wake-up-layer-stack.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| Stop | * | anti-rationalization-gate.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| Stop | * | orchestrator-report.sh | TASK-STATE-BOUNDARY | orchestrator-state | True | active registration |
| Stop | * | ralph-stop-quality-gate.sh | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| Stop | * | sentry-report.sh | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| SubagentStart | ralph-* | ralph-subagent-start.sh | TASK-STATE-BOUNDARY | qteam-coordination | True | active registration |
| SubagentStop | ralph-* | ralph-subagent-stop.sh | TASK-STATE-BOUNDARY | qteam-coordination | True | active registration |
| SubagentStop | * | subagent-stop-universal.sh | TASK-STATE-BOUNDARY | qteam-coordination | True | active registration |
| TaskCompleted | * | task-completed-quality-gate.sh | TASK-STATE-BOUNDARY | task-cycle-gate | True | active registration |
| TaskCompleted | * | task-list-projection.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| TaskCreated | * | task-list-projection.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| TeammateIdle | * | agent-diary-writer.sh | TASK-STATE-BOUNDARY | qteam-coordination | True | active registration |
| TeammateIdle | * | teammate-idle-quality-gate.sh | TASK-STATE-BOUNDARY | qteam-coordination | True | active registration |
| UserPromptSubmit | * | aristotle-analysis-display.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| UserPromptSubmit | * | command-router.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| UserPromptSubmit | * | context-warning.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| UserPromptSubmit | * | periodic-reminder.sh | TASK-STATE-BOUNDARY | session-lifecycle | True | active registration |
| UserPromptSubmit | * | plan-state-adaptive.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| UserPromptSubmit | * | plan-state-lifecycle.sh | TASK-STATE-BOUNDARY | plan-task-state | True | active registration |
| UserPromptSubmit | * | universal-prompt-classifier.sh | TASK-STATE-BOUNDARY | methodology-gates | True | active registration |
| statusLine | - | statusline-ralph.sh | TASK-STATE-BOUNDARY | state-display | True | state machinery support script |

## ### agents (37 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/agents/AGENTES_SKILLS_AUDIT_v2.72.2.md.old | DELETE | audit-residue | stale | renamed audit artifact |
| .claude/agents/Hyperliquid-DeFi-Protocol-Specialist.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/adversarial-plan-validator.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ai-output-code-review-super-auditor.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/architecture-strategist.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/autoresearch.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/blockchain-security-auditor.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/chain-infra-specialist-blockchain.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/codex-reviewer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/debugger.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/defi-protocol-economist.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/docs-writer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/frontend-reviewer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/gap-analyst.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/kieran-python-reviewer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/kieran-typescript-reviewer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/lead-software-architect.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/liquid-staking-specialist.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/orchestrator.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/pattern-recognition-specialist.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/plan-sync.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/prompt-optimizer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/quality-auditor.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ralph-coder.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ralph-frontend.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ralph-researcher.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ralph-reviewer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ralph-security.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ralph-tester.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/refactorer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/research-blockchain.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/security-auditor.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/senior-frontend-developer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/software-architech.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/test-architect.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/ux-ui-senior-developer.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
| .claude/agents/web-scrapper.md | EXPLICIT/COLD-PATH | native-agent | cold | native Claude Task surface (spawned on demand) |
## ### artifacts (2 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/hooks/__pycache__ | DELETE | build-artifact-untracked | stale | generated bytecode cache; not tracked by git |
| .claude/hooks/k8s_context_guard/__pycache__ | DELETE | build-artifact-untracked | stale | generated bytecode cache; not tracked by git |
## ### claude-scripts (26 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/scripts/validate-all-orchestrator-skills.sh | DELETE | orphan-no-references | orphan | no tracked reference anywhere |
| .claude/scripts/backfill-domains.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 5 tracked file(s) |
| .claude/scripts/centralize-all.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 2 tracked file(s) |
| .claude/scripts/context-extractor.py | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 14 tracked file(s) |
| .claude/scripts/curator-approve.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 13 tracked file(s) |
| .claude/scripts/curator-discovery.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 24 tracked file(s) |
| .claude/scripts/curator-ingest.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 16 tracked file(s) |
| .claude/scripts/curator-learn.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 23 tracked file(s) |
| .claude/scripts/curator-queue.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 3 tracked file(s) |
| .claude/scripts/curator-rank.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 24 tracked file(s) |
| .claude/scripts/curator-reject.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 5 tracked file(s) |
| .claude/scripts/curator-scoring.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 23 tracked file(s) |
| .claude/scripts/curator.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 12 tracked file(s) |
| .claude/scripts/parse-context-output.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 6 tracked file(s) |
| .claude/scripts/quality-coordinator.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 13 tracked file(s) |
| .claude/scripts/read-quality-results.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 16 tracked file(s) |
| .claude/scripts/sync-rules-from-source.sh | EXPLICIT/COLD-PATH | support-utility | cold | referenced by 9 tracked file(s) |
| .claude/scripts/agent-memory-buffer.sh | TASK-STATE-BOUNDARY | memory-recall | cold | state machinery support script |
| .claude/scripts/checkpoint-manager.sh | TASK-STATE-BOUNDARY | orchestrator-state | cold | state machinery support script |
| .claude/scripts/event-bus.sh | TASK-STATE-BOUNDARY | memory-recall | cold | state machinery support script |
| .claude/scripts/force-statusline-refresh.sh | TASK-STATE-BOUNDARY | state-display | cold | state machinery support script |
| .claude/scripts/handoff-generator.py | TASK-STATE-BOUNDARY | memory-recall | cold | state machinery support script |
| .claude/scripts/ledger-manager.py | TASK-STATE-BOUNDARY | memory-recall | cold | state machinery support script |
| .claude/scripts/migrate-plan-state.sh | TASK-STATE-BOUNDARY | plan-task-state | cold | state machinery support script |
| .claude/scripts/ralph-state.sh | TASK-STATE-BOUNDARY | memory-recall | cold | state machinery support script |
| .claude/scripts/statusline-ralph.sh | TASK-STATE-BOUNDARY | state-display | hot | state machinery support script |
## ### commands (1 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/commands/review-pr.md | EXPLICIT/COLD-PATH | native-command | cold | native Claude slash command |
## ### distributors (24 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| scripts/install-claude-native-agents.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/install-git-hooks.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/install-k8s-context-guard.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/install-language-servers.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/install-security-tools.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| install.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| .claude/scripts/sync-rules-from-source.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-agent-teams-integration.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-agents-registration.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| .claude/scripts/validate-all-orchestrator-skills.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-directories.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-global-architecture.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-global-infrastructure.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-hooks-execution.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-hooks-registration.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-hooks-syntax.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-installation.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-integration.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-settings-structure.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-shell-config.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-skills-execution.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-skills-registration.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-skills-unification.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
| scripts/validate-system-requirements.sh | EXPLICIT/COLD-PATH | installer-validator-sync | cold | manual/CI invocation surface |
## ### hooks (93 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/hooks/k8s_context_guard/__init__.py | EXPLICIT/COLD-PATH | referenced-utility | cold | referenced by 2 tracked file(s) |
| .claude/hooks/agent-depth-soft-enforce.sh | EXPLICIT/COLD-PATH | installable-profile | cold | present in versioned install profile (settings.json.example), not active |
| .claude/hooks/agent-policy-guard.sh | EXPLICIT/COLD-PATH | installable-profile | cold | present in versioned install profile (settings.json.example), not active |
| .claude/hooks/lib/build-skill-index.sh | EXPLICIT/COLD-PATH | referenced-utility | cold | referenced by 4 tracked file(s) |
| .claude/hooks/lib/ctx-query.sh | EXPLICIT/COLD-PATH | referenced-utility | cold | referenced by 4 tracked file(s) |
| .claude/hooks/lib/daily-gate.sh | EXPLICIT/COLD-PATH | referenced-utility | cold | referenced by 7 tracked file(s) |
| .claude/hooks/session-end-extractors.sh | EXPLICIT/COLD-PATH | session-lifecycle | cold | present in versioned install profile (settings.json.example), not active |
| .claude/hooks/audit-secrets.js | SECURITY-REQUIRED | secrets-audit | hot | active secrets audit; companion of declared gap secrets-ordinary-work |
| .claude/hooks/k8s_context_guard/cloud_operation_gate.py | SECURITY-REQUIRED | security-baseline-control | cold | named by SECURITY_BASELINE.json controls |
| .claude/hooks/k8s_context_guard/context_classification.py | SECURITY-REQUIRED | security-baseline-control | cold | named by SECURITY_BASELINE.json controls |
| .claude/hooks/git-safety-guard.py | SECURITY-REQUIRED | security-baseline-control | hot | named by SECURITY_BASELINE.json controls |
| .claude/hooks/k8s-context-guard-v2.py | SECURITY-REQUIRED | security-baseline-control | hot | named by SECURITY_BASELINE.json controls |
| .claude/hooks/k8s_context_guard/minikube_context.py | SECURITY-REQUIRED | security-baseline-control | cold | named by SECURITY_BASELINE.json controls |
| .claude/hooks/permission-guard.sh | SECURITY-REQUIRED | security-baseline-control | hot | named by SECURITY_BASELINE.json controls |
| .claude/hooks/promptify-security.sh | SECURITY-REQUIRED | secrets-audit | hot | active secrets audit; companion of declared gap secrets-ordinary-work |
| .claude/hooks/repo-boundary-guard.sh | SECURITY-REQUIRED | security-baseline-control | hot | named by SECURITY_BASELINE.json controls |
| .claude/hooks/k8s_context_guard/script_operation_inspector.py | SECURITY-REQUIRED | security-baseline-control | cold | named by SECURITY_BASELINE.json controls |
| .claude/hooks/skill-validator.allowlist | SECURITY-REQUIRED | security-baseline-control | cold | named by SECURITY_BASELINE.json controls |
| .claude/hooks/skill-validator.sh | SECURITY-REQUIRED | security-baseline-control | hot | named by SECURITY_BASELINE.json controls |
| .claude/hooks/lib/worktree-utils.sh | SECURITY-REQUIRED | security-baseline-control | cold | named by SECURITY_BASELINE.json controls |
| .claude/hooks/action-report-tracker.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/adversarial-auto-trigger.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/agent-diary-writer.sh | TASK-STATE-BOUNDARY | qteam-coordination | hot | active registration |
| .claude/hooks/ai-code-audit.sh | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/anti-rationalization-gate.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/aristotle-analysis-display.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/auto-format-prettier.sh | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/auto-migrate-plan-state.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/auto-sync-global.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/batch-progress-tracker.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/checkpoint-auto-save.sh | TASK-STATE-BOUNDARY | orchestrator-state | hot | active registration |
| .claude/hooks/checkpoint-smart-save.sh | TASK-STATE-BOUNDARY | orchestrator-state | hot | active registration |
| .claude/hooks/code-review-auto.sh | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/command-router.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/console-log-detector.sh | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/context-mode-cache-heal.mjs | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/context-warning.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/continuous-learning.sh | TASK-STATE-BOUNDARY | memory-recall | cold | referenced by 33 tracked file(s) |
| .claude/hooks/decision-extractor.sh | TASK-STATE-BOUNDARY | memory-recall | cold | referenced by 40 tracked file(s) |
| .claude/hooks/dream-consolidate.sh | TASK-STATE-BOUNDARY | memory-recall | cold | referenced by 4 tracked file(s) |
| .claude/hooks/fast-path-check.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/inject-session-context.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/lsa-pre-step.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/memory-projection.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/orchestrator-auto-learn.sh | TASK-STATE-BOUNDARY | orchestrator-state | hot | active registration |
| .claude/hooks/orchestrator-init.sh | TASK-STATE-BOUNDARY | orchestrator-state | hot | active registration |
| .claude/hooks/orchestrator-report.sh | TASK-STATE-BOUNDARY | orchestrator-state | hot | active registration |
| .claude/hooks/parallel-explore.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/periodic-reminder.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/plan-analysis-cleanup.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/plan-state-adaptive.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/lib/plan-state-freshness.sh | TASK-STATE-BOUNDARY | plan-task-state | cold | referenced by 2 tracked file(s) |
| .claude/hooks/plan-state-lifecycle.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/lib/plan-state-writer.sh | TASK-STATE-BOUNDARY | plan-task-state | cold | referenced by 10 tracked file(s) |
| .claude/hooks/plan-sync-post-step.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/post-compact-restore.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/pre-compact-handoff.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/progress-tracker.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/project-backup-metadata.sh | TASK-STATE-BOUNDARY | orchestrator-state | hot | active registration |
| .claude/hooks/project-state.sh | TASK-STATE-BOUNDARY | orchestrator-state | hot | active registration |
| .claude/hooks/qteam-blocked-notify.sh | TASK-STATE-BOUNDARY | qteam-coordination | hot | active registration |
| .claude/hooks/quality-parallel-async.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/ralph-stop-quality-gate.sh | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/ralph-subagent-start.sh | TASK-STATE-BOUNDARY | qteam-coordination | hot | active registration |
| .claude/hooks/ralph-subagent-stop.sh | TASK-STATE-BOUNDARY | qteam-coordination | hot | active registration |
| .claude/hooks/react-doctor.mjs | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/recursive-decompose.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/semantic-realtime-extractor.sh | TASK-STATE-BOUNDARY | memory-recall | cold | referenced by 38 tracked file(s) |
| .claude/hooks/sentry-report.sh | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/session-accumulator.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/session-end-handoff.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/session-start-repo-summary.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/session-start-restore-context.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
| .claude/hooks/smart-memory-search.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/smart-skill-reminder.sh | TASK-STATE-BOUNDARY | methodology-gates | cold | referenced by 27 tracked file(s) |
| .claude/hooks/status-auto-check.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/stop-slop-hook.sh | TASK-STATE-BOUNDARY | methodology-gates | cold | referenced by 14 tracked file(s) |
| .claude/hooks/subagent-stop-universal.sh | TASK-STATE-BOUNDARY | qteam-coordination | hot | active registration |
| .claude/hooks/task-completed-quality-gate.sh | TASK-STATE-BOUNDARY | task-cycle-gate | hot | active registration |
| .claude/hooks/task-list-projection.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/task-orchestration-optimizer.sh | TASK-STATE-BOUNDARY | plan-task-state | cold | referenced by 34 tracked file(s) |
| .claude/hooks/teammate-idle-quality-gate.sh | TASK-STATE-BOUNDARY | qteam-coordination | hot | active registration |
| .claude/hooks/todo-plan-sync.sh | TASK-STATE-BOUNDARY | plan-task-state | hot | active registration |
| .claude/hooks/universal-aristotle-gate.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/universal-prompt-classifier.sh | TASK-STATE-BOUNDARY | methodology-gates | hot | active registration |
| .claude/hooks/vault-fact-extractor.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/vault-graduation.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/vault-index-updater.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/vault-log-writer.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/vault-promotion.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/vault-wing-compiler.sh | TASK-STATE-BOUNDARY | memory-recall | hot | active registration |
| .claude/hooks/vault-writeback.sh | TASK-STATE-BOUNDARY | memory-recall | cold | referenced by 8 tracked file(s) |
| .claude/hooks/wake-up-layer-stack.sh | TASK-STATE-BOUNDARY | session-lifecycle | hot | active registration |
## ### installed-residue (7 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| /Users/alfredolopez/.claude/rules.pre-w5-symlink | DELETE | stale-residue | stale | symlink to repo .claude/rules; global rules are now a copy |
| /Users/alfredolopez/.claude/agents | EXPLICIT/COLD-PATH | distributed-copies | cold | installed copy of native invocation surface |
| /Users/alfredolopez/.claude/commands | EXPLICIT/COLD-PATH | distributed-copies | cold | installed copy of native invocation surface |
| /Users/alfredolopez/.claude/skills | EXPLICIT/COLD-PATH | distributed-copies | cold | installed copy of native invocation surface |
| /Users/alfredolopez/.claude/hooks | TASK-STATE-BOUNDARY | activation-symlink | hot | symlink ~/.claude/hooks -> repo .claude/hooks; carries every active hook |
| /Users/alfredolopez/.claude/rules | TASK-STATE-BOUNDARY | distributed-copies | hot | header-stamped copies synced by sync-rules-from-source.sh |
| /Users/alfredolopez/.claude/scripts | TASK-STATE-BOUNDARY | distributed-copies | hot | installed copy; contains active statusline-ralph.sh |
## ### rules-src (7 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/rules-src/aristotle-methodology.md | TASK-STATE-BOUNDARY | process-rules-hot-context | hot | process rule injected every session; distributed as header-stamped copy |
| .claude/rules-src/ast-grep-usage.md | TASK-STATE-BOUNDARY | process-rules-hot-context | hot | process rule injected every session; distributed as header-stamped copy |
| .claude/rules-src/browser-automation.md | TASK-STATE-BOUNDARY | process-rules-hot-context | hot | process rule injected every session; distributed as header-stamped copy |
| .claude/rules-src/native-tools-first.md | TASK-STATE-BOUNDARY | process-rules-hot-context | hot | process rule injected every session; distributed as header-stamped copy |
| .claude/rules-src/parallel-first.md | TASK-STATE-BOUNDARY | process-rules-hot-context | hot | process rule injected every session; distributed as header-stamped copy |
| .claude/rules-src/plan-immutability.md | TASK-STATE-BOUNDARY | process-rules-hot-context | hot | process rule injected every session; distributed as header-stamped copy |
| .claude/rules-src/zai-mcp-usage.md | TASK-STATE-BOUNDARY | process-rules-hot-context | hot | process rule injected every session; distributed as header-stamped copy |
## ### security-manifest (2 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/security/SECURITY_BASELINE.json | SECURITY-REQUIRED | security-manifest | n/a | declarative security plane manifest |
| .claude/security/settings.security-only.json | SECURITY-REQUIRED | security-manifest | n/a | declarative security plane manifest |
## ### settings-record (33 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| env:K8S_GUARD_ALLOWED_CONTEXTS | SECURITY-REQUIRED | security-config | hot | permission/security configuration record |
| ~/.claude/settings.json:permissions | SECURITY-REQUIRED | security-config | hot | permission/security configuration record |
| env:CLAUDE_AUTOCOMPACT_PCT_OVERRIDE | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| env:CLAUDE_CODE_ENABLE_PROMPT_SUGGESTION | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| env:CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| env:CLAUDE_CODE_NO_FLICKER | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| env:DISABLE_ERROR_REPORTING | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| env:ENABLE_TOOL_SEARCH | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| env:RALPH_DREAM_APPLY | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:agentPushNotifEnabled | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:alwaysThinkingEnabled | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:autoDreamEnabled | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:autoUpdatesChannel | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:crossSessionInbound | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:effortLevel | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:enabledPlugins | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:env | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:extraKnownMarketplaces | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:hooks | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:inputNeededNotifEnabled | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:language | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:mcpToolSearchMode | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:model | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:outputStyle | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:plansDirectory | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:preferences | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:remoteControlAtStartup | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:skipDangerousModePermissionPrompt | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:skipWorkflowUsageWarning | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:statusLine | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:teammateMode | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:theme | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
| ~/.claude/settings.json:worktree | TASK-STATE-BOUNDARY | runtime-config | hot | active settings record; deleting the key changes runtime state |
## ### skills (63 records)

| command | owner | plane | activation | note |
|---|---|---|---|---|
| .claude/skills/.gitignore | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/.skill-lint-ignore | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/adr | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/adversarial | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/architecture-diagram | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/ask-questions-if-underspecified | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/attack-mutator | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/audit | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/autoresearch | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/browser-test | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/bugs | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/checkpoint-manager | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/clarify | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/clean-slop | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/code-reviewer | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/codex-cli | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/context-engineer | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/context7-usage | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/crafting-effective-readmes | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/create-task-batch | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/curator | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/curator-repo-learn | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/deep-clarification | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/defense-profiler | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/design-system | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/deslop | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/diagram-design | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/edd | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/ethereum-rpc | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/exit-review | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/gates | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/gemini-cli | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/iterate | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/kaizen | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/openai-docs | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/orchestrator | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/parallel | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/perf | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/plan | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/prd | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/quality-gates-parallel | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/ralph-reference | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/readme | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/research | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/research-blockchain | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/retrospective | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/sec-context-depth | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/security | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/senior-software-engineer | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/ship | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/smart-fork | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/spec | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/stop-slop | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/tap-explorer | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/task-batch | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/task-classifier | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/task-visualizer | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/testing-anti-patterns | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/vault | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/vercel-react-best-practices | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/worktree-pr | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/wt-lead | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |
| .claude/skills/wt-worker | EXPLICIT/COLD-PATH | native-skill | cold | native Claude skill (invoked explicitly) |

## Installed residue map (source -> installed, deletion must remove both)

| installed path | kind | target | owner | parity/drift |
|---|---|---|---|---|
| `/Users/alfredolopez/.claude/hooks` | SYMLINK | `/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks` | TASK-STATE-BOUNDARY | - |
| `/Users/alfredolopez/.claude/rules` | COPY-OF rules-src (header-stamped) | `-` | TASK-STATE-BOUNDARY | 7/7 in sync (modulo header); learned=13 files (no repo source); proven=15 files (no repo source) |
| `/Users/alfredolopez/.claude/agents` | COPY | `-` | EXPLICIT/COLD-PATH | 1 repo-only; 0 installed-only; DRIFT: orchestrator.md |
| `/Users/alfredolopez/.claude/skills` | COPY | `-` | EXPLICIT/COLD-PATH | 37 common skills; 24 repo-only; 25 installed-only |
| `/Users/alfredolopez/.claude/scripts` | COPY | `-` | TASK-STATE-BOUNDARY | 19 repo-only, 1 installed-only |
| `/Users/alfredolopez/.claude/commands` | COPY | `-` | EXPLICIT/COLD-PATH | 0 repo-only, 0 installed-only |
| `/Users/alfredolopez/.claude/rules.pre-w5-symlink` | SYMLINK | `/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/rules` | DELETE | - |

Note: `~/.claude/hooks` is a SYMLINK to the repo's `.claude/hooks` — every
active hook file is its own installed residue; deleting a source removes the
installed hook. `~/.claude/rules`, `agents`, `skills`, `scripts`, `commands`
are COPIES; their parity/drift is in the table above and in findings.

## Findings

- Stale installed residue: `~/.claude/rules.pre-w5-symlink` — symlink to repo .claude/rules; global rules are now a copy. Deletion PR must remove the installed path (outside this repo).
- Audit residue tracked in git: `.claude/agents/AGENTES_SKILLS_AUDIT_v2.72.2.md.old` (DELETE).
- Orphan sources (zero tracked references): `.claude/scripts/validate-all-orchestrator-skills.sh`.
- Registration swallows its own output (`>/dev/null 2>&1 &`): vault-weekly-compile.sh (SessionEnd) — failures are invisible by design of the registration, not of the hook. Noted, not fixed (out of scope).
- Installable-profile-only hooks (in settings.json.example, not active): `agent-depth-soft-enforce.sh`, `agent-policy-guard.sh`, `session-end-extractors.sh`.
- Installed-only skills (present in ~/.claude/skills, absent from the repo; installed from sources outside this repo): `ai-output-code-review-super-auditor`, `autoreview`, `bug-hunt`, `canvas`, `clerum-dev`, `docs`, `e2e-test-guardian`, `find-bugs`, `fireworks-tech-graph`, `handoff`, `human-e2e-recorder`, `impeccable`, `playwright-e2e-builder`, `security-loop`, `security-threat-model`, `senior-architect`, `senior-backend`, `senior-devops`, `senior-fullstack`, `senior-secops`, `senior-security`, `senior-software-architect`, `thermo-nuclear-code-quality-review`, `tldr`, `ui-ux-pro-max`.
- Repo-only skills (versioned but never installed to ~/.claude/skills): `adr`, `attack-mutator`, `browser-test`, `checkpoint-manager`, `clean-slop`, `codex-cli`, `context-engineer`, `context7-usage`, `crafting-effective-readmes`, `deep-clarification`, `defense-profiler`, `design-system`, `diagram-design`, `ethereum-rpc`, `gemini-cli`, `openai-docs`, `perf`, `prd`, `research`, `research-blockchain`, `ship`, `tap-explorer`, `task-visualizer`, `vercel-react-best-practices`.
- Under ~/.claude/rules, entries with NO repo source (generated/maintained globally from the vault, e.g. by vault generators — a repo-side deletion PR cannot remove them): `learned` (13 files), `proven` (15 files).
- Agent copy drift (installed ~/.claude/agents differs from repo): `orchestrator.md`.
- Command content drift (installed differs from repo): `review-pr.md`.
- audit-secrets.js is audit-only (cannot block/redact); #69 §1B `secrets-ordinary-work` covers its completion. Classified SECURITY-REQUIRED as the active secrets-audit control.
- Active security functions NOT declared in SECURITY_BASELINE.json (hence unprotected by its regression tests): `audit-secrets.js`, `promptify-security.sh`. Phase 1B (#69) should declare them or re-scope them.

## Reproduce

```bash
bash scripts/benchmark/phase0_inventory.sh          # report + TSV + snapshot
bash scripts/benchmark/phase0_inventory.sh --selftest
```
