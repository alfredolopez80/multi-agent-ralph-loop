---
name: wt-lead
description: Lead protocol for the session running in the main checkout that delegates write tasks to its team's worker sessions (qteam runs zc-1, zc-2, mmx; qteam-zc runs zc-3, zc-4, mmx-2, mmx-3 — each in its own worktree and worktree-<name> branch) and integrates their branches into main. Use this skill whenever delegating work to another session, composing an ASSIGN message, receiving a DONE or BLOCKED message, reviewing or merging any worktree-* branch, resolving conflicts between worker branches, resyncing workers after an integration, or reading worker results under .claude/worktrees/. Always consult it before running git merge or git cherry-pick.
---

# wt-lead

> **Role guard.** This skill is only for the session in the main checkout.
> If your working directory contains `.claude/worktrees/`, you are a worker:
> stop reading this and use `wt-worker` instead.

You are the lead session. You run in the main checkout on `main`. You do not
implement delegated tasks yourself; you split work, assign it, review the
resulting branches and integrate them. Workers cannot write to `main`; you
are the only session that does.

## 0. Preconditions (check before every integration)

```bash
git branch --show-current    # must be main
git status --porcelain       # must be empty
```

Never merge with a dirty `main`. Never edit files under `.claude/worktrees/`.

## 1. Splitting work

Partition by directory, not by topic. Each worker owns disjoint paths for the
duration of a task. Overlaps are the only source of merge conflicts, so:

- Assign to the workers YOUR team actually has (discover them with
  `ListAgents` — never a name from a doc): `zc-*` panes take the paths
  needing real reasoning, `mmx-*` panes the wide-but-shallow sweeps.
  Example: `zc-3` → `src/core/`, `zc-4` → `src/api/`, `mmx-2` → `tests/`,
  `mmx-3` → `docs/`.
- If two tasks must touch the same file, sequence them: assign the first,
  integrate it, then assign the second (the worker rebases automatically
  via `start-task.sh`).
- Keep tasks small enough to review in one sitting. If a task needs more
  than ~10 files, split it.

## 2. Assigning (ASSIGN)

Send with `SendMessage` to the worker by name. Exact shape:

```
ASSIGN <task-id>: <title>
goal: <what to achieve, one or two sentences>
allowed paths: <comma-separated files or directories>
done when: <acceptance criteria, name the test command>
notes: <context, constraints, related task-ids>
```

Rules:
- `task-id` is short and unique (e.g. `T12-volfilter`). Reuse it in every
  message about that task.
- `allowed paths` is mandatory. A task without it is not sent.
- `done when` names a concrete command the worker can run.
- One task per worker at a time. Do not queue.
- **Plan before execution**: every ASSIGN states, in one line inside `notes`,
  the plan behind it — which issue criterion it serves, why this worker, and
  which gate the result must pass. No assignment without a stated plan.
  The multi-task plan of record lives in the epic issue (a comment on the
  parent issue), not in the lead's context — context is lost to compaction,
  the issue comment is not.

If you want a notice when the worker goes idle, attach `notify_when_idle`
to the ASSIGN send.

## 3. Receiving DONE

```
DONE <task-id>
branch: worktree-<name>   hash: <sha>
files: <list>
tests: <summary>
notes: <...>
```

Then run `scripts/review.sh worktree-<name>`. It prints ahead/behind counts,
the commit log, the file list and flags any file outside the task's allowed
paths if you pass them:

```bash
scripts/review.sh worktree-zc "strategies/vol_filter.py,tests/test_vol_filter.py"
```

(The scripts live at `.claude/skills/wt-lead/scripts/` in this repo —
`review.sh` and `integrate.sh` — not at `scripts/` from the repo root.)

Read the full diff (`git diff main...worktree-<name>`) and decide:

| Situation | Action |
|---|---|
| Files outside allowed paths | RETURN — worker must revert them |
| Tests not run or failing | RETURN with the failing command |
| Branch behind `main` | **Nothing.** Integrate — the merge handles it |
| Merge conflict on integrate | REBASE (section 5) |
| Design or quality problem | RETURN with a precise fix |
| Good | integrate (section 4) |

**Mandatory strict review before every merge — automatic, not on request.**
After the scope check and reading the full diff, run the full review stack
over the branch BEFORE integrating:
1. `code-reviewer` skill (repo wrapper, 4-agent: CLAUDE.md compliance ×2,
   bug detection, git blame/history) — primary engine, high effort.
2. `code-review` native skill (official plugin, high effort) — second
   correctness pass when the primary leaves doubt or the diff touches
   production hooks.
3. `simplify` skill in REPORT mode (no `--post` pre-merge) — reuse,
   simplification, altitude findings.

`review.sh` checks scope only and the test runner checks behavior — neither
reads the code. In Q-teams without a Claude seat for the lead (qteam-zc),
run every review layer INLINE from the lead's own context — never spawn
Claude subagents: they bill a seat the team exists to conserve, and without
valid credentials they die with `API Error: 401` (observed 2026-08-28: four
`simplify` subagents spawned straight from the skill text, all 401). Findings:
- Behavioral defect → RETURN with `file:line` and the failure scenario.
- Reuse/simplification findings → include in the same RETURN as
  recommendations; the worker applies them (the lead never edits worker code
  directly).
- Clean verdict on all layers → integrate (section 4).

A merge to `main` that skipped this step is a protocol breach even if the
runner is green — the runner cannot see what the reviewer sees (T92: runner
green, strict review found 2 behavioral defects; T95: runner green, review
found the extraction wrapper to be a structural no-op).

A branch behind `main` is the **normal** state after every integration, not a
condition to correct: you merged the previous one and `main` moved. Sending
REBASE for mere behind-ness sends the worker into `git rebase main`, which for
a long time this repo's own `git-safety-guard` denied — the single most blocked
command of any session, ×16 in one day, and the reason two workers independently
improvised a way around it. The guard is now context-aware, but the instruction
was wrong on its own terms: a `--no-ff` merge resolves a behind branch without
the worker doing anything.

## 4. Integrating

```bash
scripts/integrate.sh worktree-<name>              # merge --no-ff
scripts/integrate.sh worktree-<name> <sha> [<sha>...]   # cherry-pick only these
```

The script refuses on dirty `main` or wrong branch, merges, and runs
`$QTEAM_TEST_CMD` if set (e.g. `export QTEAM_TEST_CMD="pytest -q"`). On merge
conflict it aborts and prints the conflicting files; do not resolve by hand
unless the conflict is trivial and inside one worker's paths. Otherwise send
REBASE to the worker (section 5).

After a successful merge, tell the worker:

```
MERGED <task-id> into main at <sha>
```

## 5. Conflicts between workers

Integrate the first branch. Then send the second worker:

```
REBASE <task-id>
```

The worker rebases on the updated `main`, resolves inside its own paths and
resends DONE. Review again from section 3. The worker who knows the change
resolves the conflict; you don't.

## 6. Returning work (RETURN)

```
RETURN <task-id>
reason: <what is wrong, specific>
fix: <what to change, specific>
```

One RETURN should be enough. If a second one is needed, reconsider the task
split or the allowed paths — the problem is usually upstream.

## 7. Resync after integration

Workers' branches are behind `main` after every merge. They rebase
automatically when they start the next task via `start-task.sh`, so you only
need to send REBASE explicitly when a worker is mid-task and needs your merge.

## 8. Reading worker artifacts

Unversioned results live in each worker's worktree:

```
.claude/worktrees/<name>/results/
```

Read them directly. Never write there.

## 9. BLOCKED messages

```
BLOCKED <task-id>
<reason>
```

Answer with one of: an updated ASSIGN (wider paths), a RETURN, or a note that
you'll handle it in `main` yourself. Never ask a worker to run something its
own permissions deny, and never ask it to approve a permission prompt.

## 10. Tracking

Keep a short live table in your own context (not in a file) of
`task-id | worker | status | branch@hash`. Update it on every ASSIGN, DONE,
RETURN and MERGED so you can answer "where are we" without re-reading messages.
