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
| Passes on a bare checkout | 28 | Wired into `tests/run-all-unit-tests.sh` and into CI (23 shell + 5 bats) |
| Fails: needs a provisioned machine | 12 | The 10 shell suites moved to the opt-in `--with-install` bucket; the 2 bats suites left out, since that bucket is invoked with `bash` |
| Fails: tests an implementation that no longer exists | 7 | Documented below; **not deleted** |
| Fails: not root-caused | 15 | Documented below; **not deleted** |
| Timed out | 0 | — |

28 + 12 + 7 + 15 = 62. Every orphan is accounted for.

> **The first version of this table did not add up, and the reason belongs in the
> record.** It reported 23 passing and totalled 58 against a stated 62. Four suites had
> silently vanished from the measurement: the classification loop was
> `while read -r f; do bats "$f"; done < list`, and `bats` reads stdin — so it consumed
> four lines of the very list driving it. A document arguing "nothing was deleted
> because everything was measured" had four suites nobody measured. They are
> `test_cross_platform.bats`, `test_quality_gates.bats`, `test_security_functions.bats`
> and `test_settings_merge.bats`; all four pass, and all four are now in CI. The
> `< /dev/null` in the runner's bats loop is what stops this recurring.

Nothing was deleted. `#42` is explicit that a missing runner does not prove a suite is
dead, and the seven "implementation retired" entries are the only ones where that case
is actually made — each names a file that is gone from the repository.

## Now running in CI (28)

`TEST_SUITES` (23 shell suites) covers hook behaviour — single JSON emission, no-hang
guarantees, plan-state writes, task-list projection, dedup keys — plus the promptify
integration, five security suites, the stop-hook pair, and the `validation-common`
library.

`BATS_SUITES` (5) adds cross-platform portability, quality gates, security functions,
settings merge and the worktree workflow: 157 assertions.

**`test_cross_platform.bats` is the one that matters most.** Its 30 tests cover portable
`stat`, portable `date`, `realpath` fallback and `mktemp` permissions — precisely the
GNU-vs-BSD class that produced #43 (`stat -f`), #44 (`declare -A`, then `timeout`), and
the `cat -A` debug step that was itself too GNU-specific to diagnose #44. The repo
already owned a guard against its own most recurrent bug, and nothing ran it. Ubuntu's
packaged bats 1.10 is sufficient; none of the five suites needs `bats-support` or
`bats-assert`.

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

1. **Both `quality-parallel` suites mutate tracked fixtures.**
   `test-quality-parallel-v4-final.sh` empties 17 lines out of each of
   `tests/quality-parallel/orch.js` and `vuln.js`; `test-quality-parallel-v3-robust.sh`
   does the same to `orchestrator-test.js` and `vulnerable-test.js`. All four are
   committed files. Their reported failures ("Expected findings, got 0") are consistent
   with each having eaten the very fixtures it then scans — which also means a second
   run can never reproduce the first. Neither is in the CI set, and neither should be
   until it stops writing to the working tree.

2. **The v2.93 action-report tracker writes into the repo on every run**, under
   `.claude/metadata/actions/` and `docs/actions/orchestrator/`. Neither path had any
   tracked file, so both are now gitignored; without that, running the suites leaves a
   dirty `git status` every time.

The 23 suites in the CI set were checked for this specifically: two consecutive runs
leave the working tree byte-identical.

## Evaluated and declined: giving `tests/run_tests.sh` a CI gate

A reviewer noted that the fail-open fixes in `run_tests.sh` cannot turn any gate red,
because nothing invokes it. That is true. The question is whether it should be wired
into CI, and the answer — from measurement, not preference — is **not yet**.

What it uniquely covers, versus what CI already runs directly:

| Suite it alone invokes | Exists? | Result on a bare checkout |
|---|---|---|
| `end-to-end/test-e2e-learning-complete-v1.sh` | yes | exit 1 |
| `integration/test-learning-integration-v1.sh` | yes | exit 1 |
| `quality-parallel/test-quality-parallel-v3-robust.sh` | yes | exit 1 |
| `test_v2.36_skills_unification.sh` | yes | exit 1 |
| `unit/test-statusline-context.sh` | yes | exit 1 |
| `hooks/test-k8s-context-guard.sh` | **no** | — |
| `swarm-mode/test-swarm-mode-config.sh` | **no** | — |
| `test_v2.37_tldr_integration.sh` | **no** | — |

Everything else it runs — `pytest tests/`, `bats tests/*.bats` — CI already runs more
directly. So wiring it would add five suites that are red today and three references to
files that do not exist. It would turn CI red on the first push and teach the next
contributor that red is normal, which is the failure mode this whole PR is about.

Those five belong with the 15 "not root-caused" orphans below: diagnose first, wire
after. The runner's own three dangling references should be repaired or removed in the
same pass.

**The fail-open fix was still worth making**, and not as consolation. `TESTING.md` opens
with `./tests/run_tests.sh` as the project's documented way to run the suite — it is the
human entry point even though no machine calls it. A contributor following the
documentation was told "Test run complete" no matter what happened, including when the
four bash security suites failed. That lie is worth removing whether or not a gate ever
consumes the exit code.

## `.claude/` carried the same hazard — now fixed, and pinned

Four files outside `scripts/` used bash-4-only syntax. Three were pinned to
`#!/bin/bash`, which on macOS is bash 3.2 no matter how PATH is set, so they were
**more** exposed than any validator this PR fixed and could not be helped by the
re-exec guard at all. What they produced under bash 3.2 was not a crash but plausible,
wrong data:

| File | Under bash 3.2 it produced | Fix |
|---|---|---|
| `.claude/hooks/action-report-tracker.sh` | every subagent type mapped to the last table entry, filing every action report under the wrong skill | `case` |
| `.claude/hooks/vault-promotion.sh` | one shared counter for all categories, so three *unrelated* tasks tripped the `>= 3` rule and appended a fabricated "Specialization detected" line to the user's Obsidian vault | `sort \| uniq -c` |
| `.claude/scripts/curator-learn.sh` | `detect_domain` iterating the single key `0` and returning the literal string `"0"` as a domain tag | table + `while read` |
| `.claude/lib/context-windows.sh` | wrong context window for every model, so compaction warnings fired at the wrong point on every prompt — #43's defect, still live | lookup table |

None of them needs associative arrays: three are static key→value tables and one is a
counter. So the requirement was **removed** rather than guarded — no `VC_REQUIRE_BASH4`,
no re-exec, no exit 78. That matters for hooks specifically: a hook that exits non-zero
blocks the tool, so "refuse to run" is not an option the way it is for a validator.

Behaviour was verified unchanged: all 18 model lookups in `context-windows.sh` return
byte-identical values, all 10 subagent mappings match the original table, `detect_domain`
returns the correct domain for four sample repositories, and the rewritten counter trips
on three identical categories while three distinct ones leave it alone.

`tests/installer/test-bash-version-guard.bats` now enforces a **stricter** rule for
`.claude/` than for `scripts/`: no bash-4-only syntax at all, since neither escape hatch
is available there.

## Follow-up

The 15 "not root-caused" suites are the remaining work from `#42` item 4. Four of them
are the `action-report-v2.93` family and two are security assertions
(`test-bug-fixes-v2.90`, `test-sql-injection-blocking`) — those two should be looked at
first, since a security test failing on current code is either a real finding or a test
that has been lying.
