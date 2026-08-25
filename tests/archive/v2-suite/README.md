# Archived v2.x test suites

**Archived on**: 2026-08-25
**Issue**: #50 (orphan test audit, part 2)
**Verdict**: REMOVED — features superadas, not broken
**Action**: archived (not deleted) per issue #50 decision

## Why they are here

These four suites test a layer of the repository that existed in v2.x but
was retired when the project reached v3.0 (Unified Herding Blanket, 498556f):
the wrapper / dispatch layer over the core commands. They are not broken
in the sense that they have a defect — they describe correctly a world
the repo left behind. The numbers below come from the mmx-2 diagnostic
and were reproduced on a clean checkout.

| Suite | PASS / FAIL | What was tested | What was retired |
|---|---:|---|---|
| `test_v2.25_search_hierarchy.sh` | 16 / 7 | v2.25 Search Hierarchy + Context7 + dev-browser | 3 slash-`.md` files + 2 version markers |
| `test_v2.26_prefix_commands.sh` | 3 / 28 | v2.26 prefix-based slash commands + Anthropic directives + task persistence | 7 `.md` commands + `.ralph/` + 5 directives + 3 markers |
| `test_v2.27_security_loop.sh` | 20 / 12 | v2.27 multi-level security loop + CLI commands + slash commands | 1 `.md` + 4 markers + 4 README sections |
| `test_v2.28_comprehensive.sh` | 20 / 12 | copy of v2.27 (identical 12 736-byte files); same retirement applies | same as v2.27 |

The 28 assertion failures and 12 failures on v2.28 are not defects in the
test scripts — they are assertions about a wrapper layer that no longer
exists.

## What still passes

The core code these suites exercise **still exists** in `scripts/ralph`:
`cmd_research`, `cmd_library`, `cmd_browse`, `cmd_security_loop`, and
related primitives. Assertions that target the core pass today; assertions
that target the retired wrapper fail. Examples of what still passes:

- `cmd_research` / `cmd_library` core entry points
- `cmd_security_loop` invocation mechanics
- internal command dispatch and exit codes

The PASS counts above (`16`, `20`, `20`) are the live assertions. The
FAIL counts are the wrapper-layer assertions that no longer apply.

## What was decided

The human, weighing the option of deleting versus archiving, chose
**archive**. Reasoning, from the audit:

> Nothing was deleted. `#42` is explicit that a missing runner does not
> prove a suite is dead, and the seven "implementation retired" entries
> are the only ones where that case is actually made — each names a file
> that is gone from the repository.
>
> — `docs/testing/ORPHAN_TEST_AUDIT.md`, top

Archiving preserves the test code for anyone who needs to understand what
the v2.x wrapper layer looked like, or to revive it under a new name.
Deleting it would erase the record.

## ⚠ Warning to anyone who resurrects these

All four files use `set -uo pipefail` (note the **missing `-e`**) and
contain `((VAR++))` 2–4 times each, in the per-test counter updates.
Under `set -e` a post-increment of a counter that is still 0 evaluates
to 0, which is exit status 1, and the script dies on its first passing
test. Today it survives because the `-e` is absent; add it and these
will silently report 0 / 0 / 0 against a green exit.

This is the exact failure the rule `testing-zero-tests-is-never-success`
documents under "Silent Cause" — `set -e` + `((VAR++))`. Two consecutive
runs that disagree are the warning sign.

For reference, the canonical fix is to replace the post-increment:

```bash
((PASSED++))        # evaluates to 0 on the first hit -> set -e aborts
```

with an arithmetic assignment that always returns 0:

```bash
PASSED=$((PASSED+1))
```

This was the fix in PR #38 across 30 files. If you re-enable any of these
suites, audit and rewrite the counters first.

## History

These files moved here with `git mv` on 2026-08-25 by `mmx-1` (task
T11-archivev2). Their git history is preserved at the new path.
