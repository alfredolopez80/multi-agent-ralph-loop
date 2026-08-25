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
| Passes on a bare checkout | 30 | Wired into `tests/run-all-unit-tests.sh` and into CI (24 shell + 6 bats; the two security suites were repaired into green by #50 — see below) |
| Fails: needs a provisioned machine | 12 | The 10 shell suites moved to the opt-in `--with-install` bucket; the 2 bats suites left out, since that bucket is invoked with `bash` |
| Fails: tests an implementation that no longer exists | 11 | Documented below; **archived (not deleted)** — 7 originally, plus 4 v2.2x shell suites moved to `tests/archive/v2-suite/` by #50 part 2 |
| Fails: not root-caused | 9 | Documented below; **not deleted** (15 before #50 reclassified the two security suites and 4 v2.2x were archived as superseded-wrapper, not root-cause) |
| Timed out | 0 | — |

28 + 12 + 11 + 11 = 62. Every orphan is accounted for.

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
| `test_v2.25_search_hierarchy.sh` | Implementation retired | v2.25 wrapper layer (3 `.md` + 2 markers) — archived in `tests/archive/v2-suite/`; 16/23 assertions still pass against live `cmd_research` core |
| `test_v2.26_prefix_commands.sh` | Implementation retired | v2.26 prefix commands (7 `.md` + `.ralph/` + 5 directives + 3 markers) — archived; 3/31 against live core |
| `test_v2.27_security_loop.sh` | Implementation retired | v2.27 security-loop wrapper (1 `.md` + 4 markers + 4 README sections) — archived; 20/32 against live `cmd_security_loop` core |
| `test_v2.28_comprehensive.sh` | Implementation retired | byte-identical copy of v2.27 (12 736 bytes) — archived with the same justification |
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
| `security/test-bug-fixes-v2.90.bats` | **Wired (repaired)** — issue #50 | The test lied, in five ways; the code is alive. Root cause below |
| `security/test-sql-injection-blocking.sh` | **Wired (repaired)** — issue #50 | grep exit code poisoned by a dead path; markers exist. Root cause below |
| `test-command-router-quick.sh` | Not root-caused | "additionalContext": "[Command Router] Detecte una tarea de debugging. Considera usar `/bug` pa |
| `test_all_integration.sh` | Not root-caused | ✗ FAILED |
| `test_v2_68_22_cli_commands.bats` | Not root-caused | not ok 1 ralph CLI command exists and is executable |
| `unit/test-action-report-generator-v2.93.sh` | Not root-caused | ✗ FAIL JSON missing or incorrect skill_name: |
| `unit/test-action-report-integration-v2.93.sh` | Not root-caused | ✗ FAIL adr missing Action Reporting section |
| `unit/test-action-report-lib-v2.93.sh` | Not root-caused | ✗ FAIL Failed report does not show FAILED status |
| `unit/test-action-report-tracker-v2.93.sh` | Not root-caused | ✗ FAIL Background flag not recorded correctly: |

## The two security suites: root cause (issue #50)

Both were classified "Not root-caused" above. The verdict for both is the same:
**the test was wrong, the code is right.** No production file was touched. The
evidence, per suite:

### `security/test-sql-injection-blocking.sh` — grep exit code poisoned by a dead path

The failing assertion (line 26 before the repair):

```bash
if ! grep -r "INTENTIONAL SECURITY VULNERABILITIES" tests/ .claude/tests/ 2>/dev/null; then
  echo "❌ FAIL: Test files not marked with warnings"
```

Reproduce with: `bash tests/security/test-sql-injection-blocking.sh` — the
suite printed the marked files (`tests/quality-parallel/vuln.js`,
`test-vulnerable.js`, … all carrying the `INTENTIONAL SECURITY VULNERABILITIES`
banner added in 7675ae7) and still failed. The reason: `.claude/tests/` is a
directory that no longer exists (deprecated), and `grep` treats a missing
operand as an error, so it exits non-zero **even though it found matches in
`tests/`**. The test reported "not marked" about files it had just printed.
The markers exist; the expectation was correct; the operand list was not.
Repaired by scanning `tests/` only, with `-q`.

### `security/test-bug-fixes-v2.90.bats` — five distinct defects, zero production bugs

The suite was written right after the v2.90.1 audit (e29eaca) and never
followed the tree. 22 of 35 assertions still passed; every failure was the
test, each for a different reason:

| Defect | Evidence |
|---|---|
| **Absolute REPO_ROOT** (line 7) | `REPO_ROOT="/Users/alfredolopez/..."` — on any other machine (including CI) every assertion fails with "No such file or directory". This alone explains the original `not ok 1 BUG-001a` diagnostic. Repair note: the usual `BASH_SOURCE` pattern does **not** work under bats-core (it runs each test from a generated script in `$TMPDIR`, so `BASH_SOURCE[0]` resolves to `/var/folders/...`); the bats-canonical `$BATS_TEST_DIRNAME` does. |
| **Retired implementation: `promptify-auto-detect.sh`** | Deleted in 498556f (Unified Herding Blanket v3.0, −218 lines). Its live successor is `run_promptify_auto_detect()` in `.claude/hooks/command-router.sh:377`. BUG-001c removed; BUG-001f loop no longer lists it. |
| **Renamed implementation: `sanitize-secrets.js`** | Renamed to `audit-secrets.js` in 5ac3547. BUG-008a/b and two STRUCT assertions now target the new name. The `sk-proj-` ordering survives (line 46 before line 52). |
| **Moved implementation: `handoff-integrity.sh`** | Moved from `.claude/hooks/` to `.claude/lib/` in 498556f. `umask 077` and `chmod 600` survived the move (`.claude/lib/handoff-integrity.sh:22-23`) — verified by BUG-009c, which sources the lib and checks the created sidecar is mode 600. BUG-009a/b/c retargeted to `$LIB_DIR`. |
| **Retired implementation: `cleanup-secrets-db.js`** | Deleted in e580a8b (MemPalace v3.0, claude-mem forensic removal); only an archived copy remains under `.claude/archive/`. BUG-011 removed. **Drift note:** the root `CLAUDE.md` still lists `cleanup-secrets-db.js` as a live manual hook — that table is stale and needs its own pass. |
| **Obsolete output format (BUG-007b/c/d)** | The assertions grepped for `'"block"'`, a value `permissionDecision` never had (see `tests/HOOK_FORMAT_REFERENCE.md`; PreToolUse uses allow/deny). The live guard emits `{"hookSpecificOutput": {..., "permissionDecision": "deny", ...}}` for `$(rm -rf …)` and backticks, `permissionDecision: "allow"` for `$(date)` — verified by direct invocation. The semantics (block destructive substitution, allow safe substitution) are unchanged and still asserted. |
| **stderr discarded (BUG-008b)** | `audit-secrets.js` prints the classification ("OpenAI Project Key: 1") to **stderr** and the hook JSON to stdout; the old assertion piped through `2>/dev/null` and grepped the stream it had thrown away. |

After repair: 32/32 pass in a worktree checkout (a path the old hardcoded
`REPO_ROOT` could never have reached). Both suites are wired into
`tests/run-all-unit-tests.sh` — the shell suite into `TEST_SUITES`, the bats
suite into `BATS_SUITES`.

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

The 13 remaining "not root-caused" suites are the remaining work from `#42` item 4,
tracked in #50. The two security suites (`test-bug-fixes-v2.90`,
`test-sql-injection-blocking`) were resolved first — both were lying tests over live
code, both repaired and wired (see "The two security suites: root cause" above). The
four `action-report-v2.93` suites and `quality-parallel/test-quality-parallel-v4-final.sh`
(tied to the fixture-destruction side effect) are the natural next targets.
