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
