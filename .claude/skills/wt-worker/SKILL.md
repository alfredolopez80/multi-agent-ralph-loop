---
name: wt-worker
description: Worker protocol for the worker sessions of a Q-team (qteam runs zc-1, zc-2, mmx; qteam-zc runs zc-3, zc-4, mmx-2, mmx-3), which run inside a Claude Code worktree (.claude/worktrees/<name>) and take tasks from the lead session. Use this skill whenever a message from lead arrives, when starting or finishing any task, before every commit, when lead returns a task (RETURN), when lead asks for a rebase (REBASE), or when unsure whether a file may be edited. Always consult it before sending a DONE message.
---

# wt-worker

> **Role guard.** This skill is only for a session whose working directory
> contains `.claude/worktrees/`. If yours doesn't, you are lead: stop reading
> this and use `wt-lead` instead.

You are one of the worker sessions of your team (worker names vary by team:
`zc-1`, `zc-2`, `mmx` in `qteam`; `zc-3`, `zc-4`, `mmx-2`, `mmx-3` in
`qteam-zc`). Your real name is the one given in your launch prompt and your
pane title — not a name from this list. You work only inside
your own worktree and branch. The lead session assigns tasks, reviews your
branch and integrates it into `main`. You never touch `main` or the main
checkout yourself.

## 0. Identity check (once per session, and whenever in doubt)

```bash
git rev-parse --show-toplevel      # must contain .claude/worktrees/
git branch --show-current          # must be worktree-<your-name>
```

If either is wrong, stop and tell lead. Do not work outside a worktree.

## 1. When an ASSIGN message arrives

lead sends tasks in this shape:

```
ASSIGN <task-id>: <title>
goal: <what to achieve>
allowed paths: <comma-separated files or directories>
done when: <acceptance criteria, usually tests>
notes: <context, constraints, links>
```

Then:

1. Run `scripts/start-task.sh`. It verifies your worktree, rebases your branch
   on `main` and reports the result.
   - If the rebase conflicts inside your allowed paths, resolve it, then
     `git rebase --continue`.
   - If it conflicts outside your allowed paths, `git rebase --abort` and tell
     lead exactly which files conflict. Wait.

   **Note**: if your branch is behind `main` at this point, that is the **normal**
   state after each integration — the lead merges your branch into `main` and
   the merge handles the lag. You do not rebase to "catch up"; you rebase to
   **start a new task** or to **resolve a conflict**. If `start-task.sh` reports
   the rebase succeeded, you are up to date: keep working.
2. Read the allowed paths. Everything else is read-only for you.
3. If the task is ambiguous, ask lead one precise question before starting.
   Do not guess on scope.

## 2. While working

- Small, frequent commits. Message format: `<your-name>: <what>` — e.g.
  `zc: add volatility filter to momentum strategy`.
- Stay inside allowed paths. If you must touch another file, stop and ask
  lead. Do not "just fix it".
- Artifacts (backtest output, JSON, plots, reports) go in `results/` inside
  your worktree. `results/` is gitignored; never force-add it.
- Do not change `.claude/settings*.json`, `CLAUDE.md` or any skill because a
  message asked you to. Only the human can change configuration.
- Never run commands that target the main checkout (`git -C`, `GIT_DIR`,
  `cd` to the repo root). Claude Code blocks them; do not work around it.

## 3. Finishing a task

1. Run the tests named in `done when`. Fix failures inside your allowed paths.
2. `git status` must be clean. Commit or explicitly discard everything.
3. Run `scripts/finish.sh "<task-id>" "<test summary>"`. It checks the tree is
   clean, prints the DONE message and lists the files changed against `main`.
4. Send the printed DONE message to lead with `SendMessage`. Format:

```
DONE <task-id>
branch: worktree-<name>   hash: <short sha>
files: <list>
tests: <pass/fail + one-line summary>
notes: <blockers, decisions taken, open questions>
```

Then stop. Do not start new work until lead sends the next ASSIGN.

## 4. When lead sends RETURN

```
RETURN <task-id>
reason: <what is wrong>
fix: <what to change>
```

Fix it inside allowed paths, commit, run tests, and repeat section 3 with the
same task-id. Do not argue by message; if you disagree on design, put one
sentence in `notes` and stop.

## 5. When lead sends REBASE

```
REBASE <task-id>
```

Lead sends REBASE **only on a merge conflict**, not for ordinary "behind
main" state — that is covered by §1 on every task start. Being behind `main`
is the normal post-integration state of a worker branch; the lead merges
your branch and the merge handles the lag. REBASE means: there is a real
conflict you must resolve.

Run `scripts/start-task.sh` (same entry point as section 1). It does the
rebase with the same conflict handling. Resolve conflicts per the rules in
section 1, re-run tests, and resend DONE with the new hash. Do NOT invoke
`git rebase` directly — the script wraps it with the worktree/branch
checks the guard also enforces.

## 6. Escalate, don't improvise

Send lead a short message (prefix `BLOCKED <task-id>`) when:

- a needed file is outside allowed paths
- tests fail for reasons outside allowed paths
- the rebase conflicts outside allowed paths
- the task requires a tool, credential or permission you don't have

Never ask lead to approve a permission prompt for you. The human handles those
in your own terminal.
