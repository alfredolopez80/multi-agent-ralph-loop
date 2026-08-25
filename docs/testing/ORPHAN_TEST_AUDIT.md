# Orphan test audit (issue #42, item 4)

## What was measured

`#42` reported "~45 test files with no runner" and made the key point that absence of
a runner is not evidence of obsolescence. This is the measurement that had been
missing: every shell and bats suite under `tests/` that no runner referenced was
executed, and classified by what actually happened.

Scope: 81 shell/bats suites under `tests/`, excluding `tests/installer/` (already
covered by the Installer Tests workflow). Of those, **62 were invoked by nothing** —
not CI, not pre-commit, not any aggregate runner.

Method: each was run with a 90s timeout on a bare checkout (no global `~/.claude`
install, no vault). Passing suites were re-run a second time to rule out flakes.

## Results

| Outcome | Count | Action taken in this PR |
|---|---:|---|
| Passes on a bare checkout | 23 | Wired into `tests/run-all-unit-tests.sh` and into CI |
| Passes but needs `bats` | 1 | Left out — `ci.yml` does not provision bats (see below) |
| Fails: needs a provisioned machine | 12 | The 10 shell suites moved to the opt-in `--with-install` bucket; the 2 bats suites left out, since the runner invokes suites with `bash` |
| Fails: tests an implementation that no longer exists | 7 | Documented below; **not deleted** |
| Fails: not root-caused | 15 | Documented below; **not deleted** |
| Timed out | 0 | — |

Nothing was deleted. `#42` is explicit that a missing runner does not prove a suite is
dead, and the seven "implementation retired" entries are the only ones where that case
is actually made — each names a file that is gone from the repository.

## Now running in CI (23)

See the `TEST_SUITES` array in `tests/run-all-unit-tests.sh`. These cover hook
behaviour (single JSON emission, no-hang guarantees, plan-state writes, task-list
projection, dedup keys), the promptify integration, five security suites, the stop-hook
pair, and the `validation-common` library.

## Left out: needs bats

`tests/test_worktree_workflow.bats` passes, but `ci.yml` installs no bats and Ubuntu's
packaged version lags the 1.11 the installer workflow pins. Adding a second bats
provisioning path to get one suite was not worth the risk of a red gate; it belongs
with the installer workflow's bats setup whenever that is consolidated.

## Per-suite verdicts for the 34 that fail

"Needs provisioned machine" means the suite asserts against `$HOME/.claude`,
`$HOME/.ralph`, `$HOME/.codex` or an Obsidian vault, and therefore fails on any clean
runner by construction rather than because of a defect.

"Implementation retired" was verified by searching the tree for the named file.

"Not root-caused" means exactly that: it fails on a bare checkout, the first diagnostic
line is recorded below, and nobody has yet established whether the test or the code is
wrong. These are the candidates for the next pass — several look like they may be real
findings rather than stale tests.

| Suite (under `tests/`) | Verdict | Evidence |
|---|---|---|
| `hooks/test-worktree-utils.sh` | Implementation retired | `.claude/hooks/auto-plan-state.sh` — archived (19 of its 20 assertions still pass) |
| `learning-system/test-learning-complete-v2.88.sh` | Implementation retired | `learning-gate-enforce.sh` — archived |
| `learning-system/test-learning-system-v2.88.sh` | Implementation retired | `learning-gate-enforce.sh` — archived |
| `promptify-integration/test-phase3-ralph-integration.sh` | Implementation retired | `ralph-context-injector.sh` — no longer in the repo |
| `security/test_security_hooks.sh` | Implementation retired | `sanitize-secrets.js` — archived |
| `test_cli_commands.bats` | Implementation retired | `cmd_minimax` — MiniMax surface retired in dc926fe |
| `unit/test-convert-rules-v2.89.sh` | Implementation retired | `.claude/scripts/convert-rules-to-claude.sh` — no longer in the repo (not even archived) |
| `orchestrator-validation/test-suite.sh` | Needs provisioned machine | ~/.claude/agents/orchestrator.md |
| `security/test-security-hardening-v2.89.bats` | Needs provisioned machine | ~/.claude/settings.json |
| `session-lifecycle/test_skills_centralization.sh` | Needs provisioned machine | ~/.claude/skills/*/SKILL.md |
| `skills/test-autoresearch-integrations.sh` | Needs provisioned machine | ~/.claude/skills/autoresearch symlink |
| `skills/test-autoresearch.sh` | Needs provisioned machine | ~/.claude/skills/autoresearch symlink |
| `skills/test-batch-skills-integration.sh` | Needs provisioned machine | ~/.claude/skills symlinks |
| `skills/test-create-task-batch.sh` | Needs provisioned machine | ~/.claude/skills symlinks |
| `skills/test-iterate.sh` | Needs provisioned machine | ~/.claude, ~/.codex, ~/.ralph, ~/.config/agents symlinks |
| `skills/test-task-batch.sh` | Needs provisioned machine | ~/.claude/skills symlinks |
| `test_v2.33_sentry_integration.sh` | Needs provisioned machine | global config plus a CLAUDE.md pinned to the v2.33 title |
| `test_v261_adversarial_council.bats` | Needs provisioned machine | HOOKS_DIR="${HOME}/.claude/hooks" (the hook itself is present and executable in the repo) |
| `vault/test-vault-health.sh` | Needs provisioned machine | Obsidian vault (global wiki, root index, templates) |
| `hooks/test_anti_rationalization_gate.sh` | Not root-caused | (no diagnostic line) |
| `quality-parallel/test-quality-parallel-v4-final.sh` | Not root-caused | ❌ FAIL: Expected findings, got 0 |
| `security/test-bug-fixes-v2.90.bats` | Not root-caused | not ok 1 BUG-001a: ralph-subagent-stop.sh uses head -c 100000 |
| `security/test-sql-injection-blocking.sh` | Not root-caused | ❌ FAIL: Test files not marked with warnings |
| `test-command-router-quick.sh` | Not root-caused | "additionalContext": "[Command Router] Detecte una tarea de debugging. Considera usar `/bug` pa |
| `test_all_integration.sh` | Not root-caused | ✗ FAILED |
| `test_v2.25_search_hierarchy.sh` | Not root-caused | (no diagnostic line) |
| `test_v2.26_prefix_commands.sh` | Not root-caused | (no diagnostic line) |
| `test_v2.27_security_loop.sh` | Not root-caused | (no diagnostic line) |
| `test_v2.28_comprehensive.sh` | Not root-caused | (no diagnostic line) |
| `test_v2_68_22_cli_commands.bats` | Not root-caused | not ok 1 ralph CLI command exists and is executable |
| `unit/test-action-report-generator-v2.93.sh` | Not root-caused | ✗ FAIL JSON missing or incorrect skill_name: |
| `unit/test-action-report-integration-v2.93.sh` | Not root-caused | ✗ FAIL adr missing Action Reporting section |
| `unit/test-action-report-lib-v2.93.sh` | Not root-caused | ✗ FAIL Failed report does not show FAILED status |
| `unit/test-action-report-tracker-v2.93.sh` | Not root-caused | ✗ FAIL Background flag not recorded correctly: |
## Two side effects found while running them

Worth recording, because both are reasons a suite should not be wired into a gate
casually:

1. **`quality-parallel/test-quality-parallel-v4-final.sh` mutates tracked fixtures.**
   Running it empties 17 lines out of each of `tests/quality-parallel/orch.js` and
   `tests/quality-parallel/vuln.js`, which are committed files. Its own reported
   failure ("Expected findings, got 0") is consistent with it having eaten the very
   fixtures it then scans. It is not in the CI set, and should not be until it stops
   writing to the working tree.

2. **The v2.93 action-report tracker writes into the repo on every run**, under
   `.claude/metadata/actions/` and `docs/actions/orchestrator/`. Neither path had any
   tracked file, so both are now gitignored; without that, running the suites leaves a
   dirty `git status` every time.

The 23 suites in the CI set were checked for this specifically: two consecutive runs
leave the working tree byte-identical.

## Follow-up

The 15 "not root-caused" suites are the remaining work from `#42` item 4. Four of them
are the `action-report-v2.93` family and two are security assertions
(`test-bug-fixes-v2.90`, `test-sql-injection-blocking`) — those two should be looked at
first, since a security test failing on current code is either a real finding or a test
that has been lying.
