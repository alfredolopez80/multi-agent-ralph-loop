> Full text of the global rule ~/.claude/rules/proven/bash-pipe-and-cwd-mask-gate-results.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# bash-pipe-and-cwd-mask-gate-results

ABSOLUTE PRINCIPLE: never declare a build/test/gate green from a signal that a wrapper produced instead of the command itself. Two mechanical traps make a FAILED gate look PASSED, and both bit repeatedly in one evenfire session.

## Trap 1: a pipe masks the exit code

`make <target> | tail` (or `| grep`, `| head`) makes `$?` — and any background-task "exit code" notification — report the LAST command in the pipe (the `tail`), NOT the `make`. A `make` dying with `Error 1`/`Error 2` is reported as "exit code 0".

Observed: three separate background gate runs whose completion notification said "exit code 0" while the captured log ended in `make: *** [test-integration] Error 2`.

### Correct form

```bash
make <target> > gate.log 2>&1; echo "EXIT=$?" | tee gate.exit
# OR
set -o pipefail; make <target> | tee gate.log
# OR read ${PIPESTATUS[0]} explicitly
```

NEVER trust a background-task "exit code 0" notification: it reports the wrapper, not the inner command. Read the captured `EXIT=` file, and check the log has volume (a fixture that died early leaves a short log).

## Trap 2: the Bash tool's working directory persists

The Bash tool's cwd persists between calls. A `cd subdir` for an isolated test leaves every later command in the wrong place: `make: *** No rule to make target 'validate-all'` (a one-line log is the tell). A stray `cd ..` in a git worktree climbs into the PARENT repo and can trip a repo-boundary guard.

### Correct form

```bash
ROOT=$(git rev-parse --show-toplevel); cd "$ROOT" && make <target>
# verify the target exists before a long background run:
test -f Makefile && grep -q "^<target>:" Makefile && echo "target OK"
```

## Three signals before calling any gate green

1. Exit code of the actual command (via tee/pipefail), not the wrapper/pipe.
2. The log has volume — not a 1-line "No rule to make target" or an early abort.
3. The expected suites reported tests EXECUTED (`total > 0`), per `zero-tests-is-never-success`.

## Relationship to other rules

This is the invocation-side companion to `testing-zero-tests-is-never-success` (which guards the harness's own counter) and `testing-fail-loud-fail-fast`. Those cover a harness that lies about what it ran; this covers a shell invocation that lies about whether the harness ran at all.

**Trigger**: Running any build/test/gate via `make`/`npm`/shell, especially in background, especially piped to tail/grep/head or after a `cd`
**Domain**: testing / tooling
**Confidence**: 1.0
**Usage**: 1 (first documented: 2026-07-31, evenfire issue #223 T1/T2 gate runs)
