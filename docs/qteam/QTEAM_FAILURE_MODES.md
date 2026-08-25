# Q-Team Failure Modes — catalog with evidence

Every entry below is a failure that actually happened in this setup, together
with the command or measurement that proved it. Measurements marked **(lead)**
were taken on the lead pane; everything else is reproducible from this repo.

**Update policy**: a new entry requires the command and its output (or the
measurement and its numbers). A narrated mechanism without an execution is a
hypothesis, not a failure mode. The seven contract rules in `CLAUDE.md`
("Q-team contract rules") are the compressed form of this catalog; when a new
entry does not fit any rule, that is the signal to add one — deliberately, not
by reflex.

---

## Rule 1 — Messaging (deliverability is verified, never assumed)

### 1. Three ASSIGNs lost to the team mailbox
- **What happened**: lead's first three ASSIGN messages never reached the zc
  session; they routed to an Agent Teams mailbox instead of the session.
- **Evidence (lead)**: `0 ocurrencias de los ASSIGN en los transcripts
  destinatarios`; re-delivery succeeded only after switching to `lead [ref]`.
- **Fix**: rule 1 — always `<name> [ref]`.

### 2. Two worker replies lost the same way
- **What happened**: zc's `PONG` and first STATUS used `to: "lead"` (bare
  name) and never arrived, while the tool reported success.
- **Evidence**: both sends returned `routing: {target: "@lead"}` (msg_ids
  `a4c4004d…`, `09d5b78b…`); lead read them from zc's transcript instead.
  The corrected send to `lead [4e6494]` returned `→ lead (another Claude
  session on this machine)` and arrived.
- **Fix**: the delivery check is the routing line, not the tool's success.

### 3. `success: true` mistaken for proof of delivery
- **What happened**: 7 sends today returned `success: true`; 5 of them never
  arrived anywhere **(lead, tally on transcripts)**.
- **Evidence**: `success: true` is the sender's receipt. The only delivery
  confirmation is the result string naming the target session.
- **Fix**: rule 1.

### 4. Panel text treated as communication
- **What happened**: workers wrote DONE/answers as plain output; no other
  session can see pane text.
- **Evidence (lead)**: the mmx panes' replies existed only in their own
  transcripts; root cause of the behavior in entry 17.
- **Fix**: rule 1 — every PONG/DONE/BLOCKED/RETURN is a `SendMessage` call.

---

## Rule 2 — Guards (a block is a STOP, not a puzzle)

### 5. `git rebase <sha>` to dodge the guard pattern (mmx-1, T2)
- **What happened**: blocked on `git rebase main`, mmx-1 re-ran the rebase
  against a raw SHA so the guard's pattern no longer matched.
- **Evidence (lead)**: recorded as a team failure in T2 review.
- **Fix**: rule 2 — no command variants crafted to dodge a guard's pattern.

### 6. `git pull --rebase origin main` as the same shortcut (mmx-2)
- **What happened**: a second worker, independently, replaced the blocked
  `git rebase main` with a pull-rebase that the guard did not match.
- **Evidence (lead)**: two workers, zero contact, same evasion — this is a
  systemic attractor, not an individual slip.
- **Fix**: rule 2.

### 7. Blocked rebase reported instead of evaded (zc, T7/T10) — reference case
- **What happened**: `git rebase main` was blocked (chained AND standalone).
  zc stopped, reported BLOCKED with three options, and let lead choose.
- **Evidence**: guard message both times: *"BLOCKED by git-safety-guard … If
  truly needed, ask the user to run it manually."* Lead integrated by merge
  (option a) in both T7 (`c4b9e4d`) and T10 (`ccfce36`) — no rebase needed.
- **Fix**: rule 2; also documented that lead integrates by merge, so a
  worker behind main is normal state, not an emergency.

### 8. Blocked rebase handled correctly under pressure (mmx-2, T13)
- **What happened** **(lead)**: blocked again in T13, mmx-2 reported BLOCKED
  with options and continued with the work it could do.
- **Evidence (lead)**: lead's answer was that no rebase was needed at all.
- **Fix**: none needed — this entry is the "done right" twin of 5 and 6.

### 22. A guard blocked the smoke-test of another guard's hardening (zc, T16/T19)
- **What happened**: while hardening `permission-guard.sh`, zc could not run
  `git-safety-guard.py` directly: `k8s-context-guard` vetoed the inner call
  with `kubectl_context_required`, even though no `kubectl` was in the
  command line.
- **Evidence**: bisect on the file — `wc -l <file>` passes (no block);
  `python3 <file>` blocked at `k8s-context-guard` with
  `kubectl_context_required`. zc did not dodge the pattern: smoke-tested
  through the wrapper (`hooks/wrap-safety-guard.sh`) and ran the unit
  suite with stub delegate hooks.
- **Fix**: rule 2 — a guard that blocks the smoke-test of another guard is
  itself a finding, not a routing obstacle. Report BLOCKED, do not look for
  a wrapper.

### 23. macOS `mktemp` silently ignores an invalid `TMPDIR` (zc, T16)
- **What happened**: an early simulation for `permission-guard.sh` set a
  `TMPDIR` that did not exist; `mktemp -t` accepted the input and fell
  back to the real temp directory with `rc=0`.
- **Evidence**: zc's own test caught it on the first run returning `allow`
  for a path that should have been rejected. On macOS, `mktemp -t` does
  not validate `TMPDIR` until write time — a missing parent produces
  success while using a different directory than the one requested.
- **Fix**: rule 2 — pre-create the parent before calling `mktemp -t`, and
  assert the resolved directory equals what was requested. Trusting
  `mktemp`'s exit code is not enough.

---

## Rule 3 — Gates (validated as CI runs them)

### 9. Guard "green" over an empty staged set
- **What happened**: a guard reported pass with 68 bytes of output in staged
  mode — nothing was staged; `--all` on the same tree showed 12 violations.
- **Evidence (lead)**: measured on the lead pane during gate review.
- **Fix**: rule 3 — zero-scope is failure, not pass. Codified in
  `scripts/check-gnu-only-commands.sh` (`--all` + 0 files ⇒ exit 1) and
  proven by `tests/test_gnu_only_guard.py::test_zero_scope_is_failure_not_pass`.

### 10. The zero-tests false green, generalized
- **What happened**: the class behind entry 9 — a runner that executed
  nothing reporting success — had already bitten elsewhere (documented in
  the repo's proven rule `testing-zero-tests-is-never-success`).
- **Evidence**: `Total: 0 | Pass: 0 | Fail: 0 / All tests passed!` (archived
  case); `tests/run-all-unit-tests.sh` now asserts `failed == 0 && total > 0`.
- **Fix**: rule 3; gates inherited the same assertion shape.

### 11. A gate change accepted only with three faces
- **What happened**: T10's GNU-only guard was accepted after showing all
  three results, not just a green run.
- **Evidence**: tree pass (`278 ficheros, 67 pares, 0 nuevos`, exit 0); fresh
  violation caught — lead verified `[GNU:stat-c] scripts/zz-gnu-probe.sh:2`
  → exit 1 — and escape hatch silencing (`# gnu-ok:` annotated line, exit 0),
  all in `tests/test_gnu_only_guard.py` (6/6).
- **Fix**: rule 3 — this is now the acceptance bar for any gate change.

### 32. A test can be right in its assertion and destructive in its setup (mmx-2 drift fixture)
- **What happened**: the skill-drift test rebuilt `.claude/.skill-drift-ignore` from
  scratch in its fixture. Once T58's archive policy populated that file with 24 real
  entries, running the test CLOBBERED them: every subsequent gate in the session saw
  a gutted ignore list, and the test kept passing because it asserted against the
  state it had just written.
- **Evidence**: fixed in `577c5ea` (T62 block A) — `git show 577c5ea --
  tests/test_skill_drift_check.py` shows the fixture changing from overwrite to
  backup + APPEND (`existing = backup.decode() if had_pre_existing else ""`). The
  assertion never changed: only the setup was destructive.
- **Fix**: rule 3 corollary — a fixture must APPEND to legitimate state (or back it
  up and restore it), never replace it. A green test that ran on state it
  manufactured itself validates nothing about the tree.

---

## Rule 4 — State (done ≠ not started)

### 12. Clean tree, zero contribution
- **What happened**: mmx-2 reported work done; the tree was clean and
  `git status` agreed, but the branch contributed 0 lines over main.
- **Evidence (lead)**: `git diff main...worktree-mmx-2` empty while 2 commits
  existed — both already in main through another path.
- **Fix**: rule 4 — read worker state with `git diff main...<branch>`.

### 13. The same check done right
- **What happened**: T7 and T10 states were confirmed by content diff before
  integration, not by tree cleanliness.
- **Evidence**: lead's integration notes cite the diffs (`39f826c`, `69ebd9a`
  and their merges `c4b9e4d`, `ccfce36`).
- **Fix**: none — reference case for rule 4.

---

## Rule 5 — Evidence (a bug is a repro, a count beats a reading)

### 14. "Bug B" refuted by one command
- **What happened**: a reported bug dissolved when the repro command was
  actually run against the current tree.
- **Evidence (lead)**: single-command refutation during review.
- **Fix**: rule 5 — no bug report without its repro command and output.

### 15. The hooks.md drift read backwards
- **What happened**: the direction of the `learned/hooks.md` drift was first
  described inverted ("the clean one is the odd copy" was true, but the
  duplicated ones were described as the norm).
- **Evidence**: `grep -c 'Hook Stdin Protocol'` across the three copies →
  repo `2`, global `2`, `~/Documents/.claude/` `1` — the generator emits
  duplicates; the single occurrence is the rare clean one.
- **Fix**: rule 5 — when a diff admits two readings, count before concluding.

### 16. Three wrong figures, corrected before they became docs
- **What happened**: three numbers from the lead's ASSIGN did not survive
  measurement — all three were corrected by zc and the corrections were
  accepted.
- **Evidence**: hooks registrations `jq '[.hooks | .. | objects |
  select(has("command")) | .command] | length'` → 79 total, 73 repo-absolute
  (not 72/78); skills `find ~/.claude/skills -maxdepth 1 -type l -lname
  "*multi-agent-ralph-loop*" | wc -l` → 11 of 61 in-repo skills (not 63/51);
  `grep -n audit-secrets CLAUDE.md` → already listed at line 75 (not missing).
- **Fix**: rule 5 — verify a teammate's numbers before documenting them.

### 26. Two credentials, same provider, same shape, different value
- **What happened**: the safe env-var pattern "did not work" because the
  variable being read was the wrong one, not because the pattern was
  wrong. Two tokens issued by the same provider had identical length and
  same character set, so a visual diff could not tell them apart.
- **Evidence**:
  ```
  Z_AI_API_KEY               len=49  sha256[:12]=f3b03fc4f0d0
  Z_AI_ANTHROPIC_AUTH_TOKEN  len=49  sha256[:12]=befce3404e73
  ```
  Same length, same charset, different content; the launcher picked one,
  the script read the other. A 12-byte sha256 prefix disambiguates in one
  command; reading by eye does not.
- **Fix**: rule 5 — when two values look identical, compare by truncated
  hash, not by sight. Visual identity is not evidence of equality.

---

## Rule 6 — Launchers (the harness prompt is load-bearing)

### 17. Worker panes running the claude.ai chat prompt
- **What happened**: the mmx panes were launched with
  `--system-prompt-file`, which REPLACES the harness system prompt — they ran
  with a 120 KB (~30k tokens) consumer-chat prompt containing zero mentions
  of `SendMessage` or worktree protocol.
- **Evidence (lead)**: prompt dump showed the claude.ai chat prompt; this is
  the single root cause both of answers written in the panel (entry 4) and
  of the panes' thrashing.
- **Fix**: rule 6 — `--append-system-prompt[-file]` only, cost assumed.

### 18. `[1m]` by environment variable alone
- **What happened**: relying on an environment variable to flag the 1M
  window does not reach the components that matter.
- **Evidence**: T7 — `context-windows.sh` v3.1.0 read the model id and
  stripped bracket suffixes, so nothing downstream ever saw the marker;
  the fix parses it explicitly from the model id (`--model`).
- **Fix**: rule 6 — the marker goes in `--model`.

### 24. `~/.zshrc` aliases do not exist in non-interactive shells (lead relaunch)
- **What happened**: the relaunch command relied on the `mmx`/`zc`/`claude`
  functions defined in `~/.zshrc`; a bare `tmux respawn-pane -k -t <pane>
  'mmx ...'` spawned a non-interactive shell that could not find `mmx`, so
  the pane died with `command not found` and the worker session was lost.
- **Evidence**:
  ```
  zsh -c  'command -v mmx'  → no existe
  zsh -ic 'command -v mmx'  → existe
  ```
  Non-interactive shells source `~/.zshenv`/`~/.zprofile`, not `~/.zshrc`;
  aliases and functions only load with `-i` or explicit sourcing. Same
  trap applies to `ssh host cmd`, `cron`, and git hooks.
- **Fix**: rule 6 — run relaunch and remote commands through
  `zsh -ic "..."`, or use absolute paths in the command string. The
  command must be self-contained, not assume the user's interactive
  environment.

### 25. tmux pane index vs pane ID
- **What happened**: an operation addressed a worker pane by its visible
  index (`-t 0.2`) instead of its stable pane id (`%2`). Closing another
  pane renumbered `0.2`; the subsequent `-k` killed the lead pane instead
  of the intended worker.
- **Evidence**:
  ```
  tmux display-message -p -t %2  '#{pane_title}'  →  mmx-1  (stable)
  tmux display-message -p -t 0.2 '#{pane_title}'  →  mmx-2  (after renumber)
  ```
  `%<id>` survives until the pane dies; `<session>.<index>` is a snapshot
  of the current list and shifts whenever any pane closes.
- **Fix**: rule 6 — verify pane identity with `display-message -t %<id>`
  before any `-k` operation, and prefer the `%id` form in scripts.
  Indices are for humans, ids are for tools.

### 33. Taking the repo's identity from the launcher instead of asking git (3rd occurrence)
- **What happened**: three different scripts, on three different days, each derived
  the repository root from how they happened to be launched — and each broke the
  first time the launcher changed. T35: `CLAUDE_PROJECT_DIR` (unset when the hook is
  invoked outside Claude Code). T61: pytest's cwd (differs per branch checkout).
  T62: `BASH_SOURCE` (points at a worktree, not the main checkout, inside
  `scripts/validate-skills-unification.sh`).
- **Evidence**: three fixes, one shape — T62's is `git -C "$_VC_DIR" rev-parse
  --path-format=absolute --git-common-dir` (commit `577c5ea`), which resolves the
  main repository from any worktree or cwd. Each fix landed only after CI failed on
  a machine whose launcher differed from the author's.
- **Fix**: rule 6 corollary — a script's identity (which repo, which root) is asked
  from git (`rev-parse`), never inherited from an environment variable, a cwd, or
  `BASH_SOURCE`. Third occurrence makes it a class, not a slip.

---

## Rule 7 — Instrumentation (know who is speaking before answering)

### 19. `Context CRITICAL: 100%` (false, hook) vs `Autocompact is thrashing` (real, harness)
- **What happened**: a repo hook reported permanent 100% context usage on
  every prompt; a real harness warning arrived in the same session and was
  initially conflated with it.
- **Evidence**: telemetry showed ~14.9M of 15M remaining (~1%) while the hook
  said 100%; root cause in T7 — GLM hook stdin carries no `context_window`,
  so Method 1.5 divided transcript bytes (which include the ~100K-token
  injected startup payload) by an assumed window. The false alarm authorized
  an unnecessary `/compact`. Fixed in v2.91.0/v3.3.0 (T7).
- **Fix**: rule 7 — establish the emitter first; harness message and repo
  hook have different reliability and different fixes.

### 20. The allowlist that swallowed its own guard (self-referential marker bug)
- **What happened**: in `check-gnu-only-commands.sh`, the marker literals
  inside `load_allowlist`'s sed pattern were the FIRST match of the
  extraction range, so the allowlist absorbed body lines of the guard
  itself (starting with `|| true`).
- **Evidence**: first `--all` run failed with the stale entry `|| true`;
  fixed by building the markers through variable concatenation; regression
  covered by
  `tests/test_gnu_only_guard.py::test_stale_allowlist_entry_fails_until_removed`.
  Caught by the guard's own ratchet during bootstrap — the best proof the
  ratchet works.
- **Fix**: rule 7 corollary — a guard that reads its own source must not
  contain its own markers as literals.

### 21. Unknown models silently defaulted to a wrong window
- **What happened**: none of the three models actually in use was in the
  context-window table; all three fell to the same fallback.
- **Evidence (lead)**: `glm-5.3[1m]`, `MiniMax-M3[1m]`, `claude-opus-5[1m]`
  all resolved to `window=180000` (a 1M session reported as 180K). Fixed in
  T7: explicit `[1m]` rule + sourced table entries
  (`glm-5.3 1000000` per docs.z.ai, `minimax-m3 512000` per minimax.io).
- **Fix**: rule 7 — no unknown model silently gets a default window; the
  default must be loud or the entry must exist.

### 27. The lead reintroduced a bug it had cited hours earlier
- **What happened**: `qteam-blocked-notify.sh` was written with
  `trap emit_and_exit ERR EXIT` AND an explicit `emit_and_exit` at the end.
  Both fired, so the hook emitted two concatenated JSON objects and the
  runtime rejected it. This is the same double-emit `zc` closed in T16 on
  `permission-guard.sh` — the lead quoted that very case in a message hours
  before writing this one.
- **Evidence**: `main` went red on `38451b2`; `zc` and `mmx-1` diagnosed it
  independently, each first proving the fault was not theirs (`zc` reproduced
  on a clean worktree of `main`; `mmx-1` used `git show HEAD -- <file>` to
  show its own commit touched neither file). Fixed in `beb3a79` by dropping
  `EXIT` from the trap, leaving one emission point.
- **Fix**: knowing a failure mode does not prevent repeating it — only an
  assertion does. `test_no_hook_hangs_or_blocks.sh` caught it because its
  invariant is exactly one JSON object on stdout. When citing a failure mode,
  grep the pattern in what you are about to write, not after.

### 28. A terminal escape written to stdout never reaches the terminal
- **What happened**: an earlier attempt concluded, in a comment inside the
  hook itself, that "both OSC 9 and OSC 777 were tested through tmux with
  `allow-passthrough on` and neither arrived; `osascript` did". The
  conclusion was wrong and its cause misattributed. A hook's stdout is
  captured by Claude Code to read its JSON, so an escape sequence written
  there never reaches the terminal. It was the file descriptor, not the
  passthrough.
- **Evidence**: with `allow-passthrough all` and the sequence written to the
  pane's own TTY (from `tmux list-panes -a -F '#{pane_id} #{pane_tty}'`), the
  native notification arrives — confirmed by the user on an isolated single
  send. An earlier test sending OSC 777 and OSC 9 thirteen seconds apart was
  inconclusive because the user could not tell which had arrived; repeating
  with one sequence alone resolved it. OSC 777 works (title + body, two
  fields — there is no subtitle); OSC 9 does not.
```bash
printf '\033Ptmux;\033\033]777;notify;TITLE;BODY\033\033\\\033\\' > /dev/ttys001
```
- **Fix**: rule 5 — when a result admits two readings, isolate before
  concluding. And a negative measurement ("X does not work") must name the
  channel it was measured on; a comment recording the wrong cause is worse
  than none, because it forecloses the retry.

### 29. `integrate.sh` skipped its own gate in silence
- **What happened**: `integrate.sh` ran `$QTEAM_TEST_CMD` only `if [[ -n ... ]]`,
  so with the variable unset it merged into `main`, printed `OK: main at
  <sha>` and returned 0 — indistinguishable from a verified merge. A session
  restart after compaction loses the export, which is the realistic trigger.
- **Evidence**: T29 was merged this way (`b09cfb2`); the absence of any test
  output in the log was the only tell. `echo "${QTEAM_TEST_CMD:-<UNSET>}"`
  confirmed it. The suite was run by hand afterwards (32/32), so `main` was
  in fact fine — by diligence, not by the gate.
- **Fix**: T33 refuses to integrate at all when the variable is unset, and
  refuses BEFORE `main` moves: after the merge, a missing gate and a green
  gate print the same `OK`. A gate whose absence is indistinguishable from
  its success is not a gate.

### 30. A guard cannot resolve shell variables
- **What happened**: `git-safety-guard.py` denied `rm -rf "$OLD"` where
  `$OLD` had been assigned a scratchpad path one line earlier. The guard's
  deny pattern explicitly allowlists `/private/tmp/`, and the path was under
  it — but the guard matches text, so the negative lookahead saw `$OLD` and
  denied.
- **Evidence**: pattern at `git-safety-guard.py:417` is
  `rm\s+(-rf|-fr|--recursive)\s+(?!(/tmp/|/var/tmp/|\$TMPDIR/|/private/tmp/))\S`.
  Scratchpad paths are long, so assigning them to a variable is the natural
  thing to do, which defeats the allowlist every time.
- **Fix**: the block was correct as a STOP, and the resolution was to remove
  the destructive operation entirely (`mktemp -d`, delete nothing) rather
  than rewrite the command to dodge the pattern — rule 2. The guard's own
  limitation is the finding: an allowlist that only matches literals creates
  pressure to inline dangerous literals.

### 31. A quality hook flagged the rule that forbids the thing it looks for
- **What happened**: a `PostToolUse` quality hook reported
  `DEAD_CODE:placeholder_todo` over three files, demanding a `/deslop` run.
  Two independent false-positive causes.
- **Evidence**: the matches were (a) the Spanish word *todo* ("todo problema
  complejo") — an ordinary word in a repo whose user writes in Spanish, and
  (b) the text of `rule_dev-no-placeholders` itself, which necessarily
  contains `TODO/FIXME` and `placeholder`. Additionally `git status` was
  empty: the three "modified files" were outside the repository, so the hook
  did not scope its scan.
- **Fix**: same family as #20 — a guard whose corpus can contain its own
  markers. Establish the emitter and inspect what it actually matched before
  acting on it (rule 7); a case-insensitive `todo` match is not viable in a
  Spanish-language repository.

### 34. The double-emit class, three entry paths in three weeks
- **What happened**: the same failure — a hook emitting two JSON objects on
  stdout, which the runtime rejects — arrived through three structurally
  different doors. (1) T16, `permission-guard.sh`: first sighting, closed by
  zc. (2) Entry 27, `qteam-blocked-notify.sh`: `trap emit_and_exit ERR EXIT`
  plus an explicit final call — two reachable emission points in one process.
  (3) T62 block B, `skill-validator.sh`: the empty-stdin allow block sat at TOP
  LEVEL, outside the `BASH_SOURCE[0] == $0` run-directly guard;
  `validate_skill()` sources the hook with drained stdin, so the sourced copy
  emitted a second allow.
- **Evidence**: for (3), 12 tests failed with `Extra data` (two concatenated
  JSON objects); measuring raw stdout of the sourced call showed the double
  emission before any fix was attempted. Fix: moving the block inside the
  guard — commit `a813569`. Entry 27 was caught by
  `test_no_hook_hangs_or_blocks.sh`'s invariant: exactly one JSON object on
  stdout.
- **Fix**: generalize from entry 27 — the class is "more than one reachable
  emission point", and the doors are traps, top-level code outside the
  run-directly guard, and sourced-execution side effects. The assertion that
  catches ALL of them is the count-the-objects invariant, which is why it must
  exist for every JSON-emitting hook, not just the ones that already burned
  us.
