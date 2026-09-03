# Distribution Policy — Symlink vs Copy Strategy

**Version**: 1.1.0
**Date**: 2026-08-25
**Status**: Active (revised to match measured disk state — issue #53)

## Overview

This document defines the distribution strategy for Ralph infrastructure files. The goal is to make the system work independently of the source repository location; where a component still depends on the repo checkout, this document says so explicitly (hooks currently do).

## Strategy Table

| Component | Strategy | Justification |
|-----------|----------|---------------|
| Rules (~/.claude/rules/) | **COPY** (top-level + `learned/`); `proven/` is global-only | The 7 top-level rules are header-stamped copies synced from the repo; `learned/` is copied by `rsync -a --delete`; `proven/` (15 files) exists only globally and has no repo source. |
| Hooks (~/.claude/hooks/) | **SYMLINK** (directory-level) | `~/.claude/hooks` is a symlink to the repo's `.claude/hooks`, and 73 of 79 registrations in settings.json point into the repo by absolute path — hooks therefore REQUIRE the repo checkout (measured 2026-08-25). |
| Agent Definitions (~/.claude/agents/) | **SYMLINK**, except the self-contained set → **COPY** | Symlinked by design. EXCEPTION: the review/bug agents that must not depend on any external CLI are COPIED (see below) so a stale/moved repo checkout cannot resurrect a version that did. Measured 2026-08-25: 26 symlinks + 10 copies. |
| Skills (~/.claude/skills/) | **MIXED — mostly COPY** | Key skills are copied by design (task-classifier, curator) and the self-contained `bugs`/`security` skills are COPIED (see below) — but today the majority are copies: of 61 skills in the repo, only 11 are installed as symlinks (measured 2026-08-25). The earlier "others symlinked" description was inverted. |
| Layer Files (~/.ralph/layers/) | **COPY** | Must work without repo. Updated by wake-up hook. |
| Settings.json | **SINGLE** | ~/.claude/settings.json is the ONLY config, whatever model the session runs. |

## Copy Rules

Files using COPY strategy:
1. Source of truth: `.claude/` directory in the repo
2. Target: corresponding global directory (`~/.claude/`)
3. Validation: checksum comparison via `scripts/validate-global-infrastructure.sh`
4. Sync: one-way from repo → global (never reverse)
5. Headers: each file gets an HTML-comment header — `<!-- SOURCE: multi-agent-ralph-loop/.claude/<path>` plus a `VERSION:` line (see any file in `~/.claude/rules/`)

## Symlink Rules

Files using SYMLINK strategy:
1. Must point to absolute repo path
2. Validation: `find ~/.claude -type l ! -exec test -e {} \; -print` finds broken ones
3. Acceptable breakage: agents and hooks won't work if the repo checkout is moved or removed (hooks resolve through the `~/.claude/hooks` directory symlink and via absolute paths in settings.json)
4. Recovery: re-run `scripts/validate-global-infrastructure.sh --fix`

## Validation

Run validation:
```bash
bash scripts/validate-global-infrastructure.sh
# Auto-fix broken symlinks:
bash scripts/validate-global-infrastructure.sh --fix
```

## Skills Distribution

Skills are distributed to 4 platform directories:
- ~/.claude/skills/<name>
- ~/.codex/skills/<name>
- ~/.ralph/skills/<name>
- ~/.config/agents/skills/<name>

(The two `~/.cc-mirror/` skill directories were removed on 2026-07-31.)

Key skills (task-classifier, curator, orchestrator) are COPIED to all 4.
Measured in `~/.claude/skills` (2026-08-25): of 61 repo skills, 11 are symlinks
and the rest are copies — the earlier "other skills are symlinked" description
was inverted.

## Self-contained Agents/Skills — COPY exception

**Why:** the agents symlink resolves through the repo checkout. When that checkout is behind
the merged `main` (or moved), the symlink silently serves STALE content — which for these
files means an older version that required an external CLI could come back to life. These
files are correctness-critical: they must ALWAYS be the self-contained version that runs on
the session's own model, regardless of repo state. A COPY guarantees that. To keep copies
from drifting SILENTLY (the inverse failure), a parity `--check` makes drift loud.

**Set** (from PR #31's conversion to self-contained agents):
- Agents (7): `debugger`, `docs-writer`, `frontend-reviewer`, `ralph-security`, `orchestrator`,
  `codex-reviewer`, `adversarial-plan-validator`
  (`refactorer`, `test-architect` and `security-auditor` were consolidated into the
  `ralph-coder` / `ralph-tester` / `ralph-security` teammates on 2026-09-03.)
- Skills (2): `bugs`, `security`

**Install / refresh the copies:**
```bash
bash scripts/install-claude-native-agents.sh
```

**Verify parity (drift gate — run in CI/local and by validate-global-infrastructure.sh):**
```bash
bash scripts/install-claude-native-agents.sh --check
```

`validate-global-infrastructure.sh` excludes this set from the symlink checks and delegates
their parity to the installer; its `--fix` RE-SYNCS the copies rather than reverting them to
symlinks. The opt-in external-CLI skills (`codex-cli`, `gemini-cli`, `openai-docs`) are out
of scope: they exist only to drive a named external tool the user invokes explicitly, and
are never a default or fallback route.

## Configuration

**PRIMARY SETTINGS**: `~/.claude/settings.json`
- This is the ONLY settings file, whatever model the session runs
- All hooks, agents, and configuration are registered here

---

## T40 addendum — source moved out of the auto-load path (2026-08-25)

**This section is an addendum. The text above is unchanged.**

Claude Code deduplicates instruction blocks by REALPATH. A symlink is paid
once in a session; a byte-identical COPY at a different REALPATH is paid
full-price again. Before T40, the repo carried a complete copy of every
rule and every learned/*.md under `.claude/rules/`, and Claude Code
auto-loaded that directory for THIS project. For every session of this
project, the same content was paid twice (once from the repo path,
once from `~/.claude/rules/`).

T40 moves the **source** of the rules and learned/ out of the repo's
auto-load path. The copies in `~/.claude/rules/` still exist and still
auto-load (so every project gets the rules); the repo just stops carrying
a second copy that Claude Code was paying for in full. Distribution
mechanism (the `COPY` strategy above) is unchanged — what changed is
where the SOURCE of the copy lives.

### What moved

| Was                                  | Is now                              | Notes                                                                                                                                                                  |
|--------------------------------------|-------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.claude/rules/<7 top-level>.md`     | `.claude/rules-src/<7 top-level>.md` | `git mv` preserved history. Source path is NOT auto-loaded — Claude Code only auto-loads `.claude/rules/`.                                                            |
| `.claude/rules/learned/`             | `.claude/learned-src/learned/`       | Same — directory renamed out of the auto-load path. The 11 tracked files (halls/*, rooms/*, hooks.md, security.md) moved with the directory. The 2 untracked files (agent-engineering.md, architecture.md, from feature branch `autoresearch/hook-latency` at commit `27f83f8`) were never in HEAD and are out of scope — they survived in the worktree but were not part of the dedup target. |
| `~/Documents/.claude/rules/learned/` | DELETED                             | Was a 3rd copy (4 files, 327 tokens) outside the repo. Static since Jun 9 2026. Exhaustive search across hooks, scripts, `.zshrc`, LaunchAgents, and crontab found NO generator recreating it. Deleted at user's authorization. |

### What stayed the same

- `~/.claude/rules/` (the copies that auto-load for every project):
  still 7 top-level rules + 15 learned/ + 11 proven/ files. CONTENT
  unchanged.
- `scripts/validate-global-infrastructure.sh` checks the same files
  exist and match the repo source (now at `rules-src/` instead of `rules/`).
- `.claude/scripts/sync-rules-from-source.sh` is the distribution
  mechanism — same one-way repo → global, same header-stamp logic. The
  script reads from the new source location (`rules-src/` /
  `learned-src/learned/`) and writes to the global path.
- Strategy column in the table above ("COPY") is still correct — what
  changed is the source location, not the strategy. The reason for the
  copy (avoiding stale-symlink drift, measured 2026-08-25) is unchanged.

### Measurement

Measured with tiktoken cl100k_base (Fable's measurement, validated
and refined by mmx-1 with `/tmp/t40-tiktoken-venv/`).

| Quantity                                                     | Tokens |
|--------------------------------------------------------------|-------:|
| Before F1+F2: dedup waste in this project per session         |  9,756 |
| &nbsp;&nbsp;&nbsp;7 top-level rules ×2 (GLOBAL with header = 5,991) |  5,991 |
| &nbsp;&nbsp;&nbsp;11 learned/ tracked ×2 (3,438 from Fable, 3,271 with the 2 untracked files excluded) |  3,438 |
| &nbsp;&nbsp;&nbsp;3rd copy at `~/Documents/` (single extra, 4 files) |    327 |
| After F1+F2: dedup waste                                      |      0 |

Lead's earlier measurement (Fable, tiktoken) was 9,354. The +402
delta is the seven header-stamps (`<!-- SOURCE: ... VERSION: ... SYNCED: ... -->`)
that the sync script adds on top of each repo source. They are real
tokens paid by Claude Code and were not in Fable's count.

### Verification

After F1+F2, `bash scripts/validate-global-infrastructure.sh` and
`bash tests/run-all-unit-tests.sh` both pass with exit 0. The seven
top-level rules still appear in `~/.claude/rules/` with byte-identical
content (after header-strip). The learned/ tree still has its 11 tracked
files (no headers; sync via `rsync -a --delete`).

**The decisive verification is PENDING** because the dedup effect
appears in the block of instructions Claude Code injects at session
start — and that block is only visible in a fresh session. Neither
mmx-1 nor the lead can observe it from this session. Lead has
committed to confirming in the next session he starts.

### Generator not found

Lead's framing of T40 included "hay un generador (el rsync de
auto-sync-global / wake-up) que RECREA esas copias". mmx-1 searched
exhaustively across `.claude/hooks/`, `~/.claude/hooks/`,
`.claude/scripts/`, `~/.zshrc`, `~/.zprofile`, `~/.bashrc`,
`~/Library/LaunchAgents/`, `crontab -l`, and `~/Documents/*.sh` —
zero references to `~/Documents/.claude/`. The 3rd copy is static
(mtime Jun 9 2026, unchanged in 2.5 months). Lead re-verified
independently and concurred: no generator exists.

### Follow-up (T40-extra): duplicate bullet in `learned/hooks.md`

Diff across the three copies showed `hooks.md` had one bullet rendered
twice (REPO = GLOBAL, both with duplicate; DOCS = clean). Mtime argument
(`rsync -a` preserves mtimes, so static mtimes don't prove absence of
generator) was refuted — the exhaustive search was the proof.

`security.md` was checked and is identical across all three copies
(stale claim in repo docs). Only `hooks.md` has the duplicate. The
generator for `learned/` (likely `.claude/scripts/curator-*.sh`) is
still to be located and fixed in a separate commit.

### Files touched by F1+F2

- `.claude/rules/*.md` → `.claude/rules-src/*.md` (7 files, `git mv`)
- `.claude/rules/learned/` → `.claude/learned-src/learned/` (`git mv`)
- `~/Documents/.claude/rules/` and `~/Documents/.claude/rules/learned/`
  (deleted; outside the repo)
- `.claude/scripts/sync-rules-from-source.sh` (RULES_DIR source path
  changed to `rules-src/`; LEARNED_SOURCE to `learned-src/learned/`)
- `scripts/validate-global-infrastructure.sh` (REPO_FILE source path
  changed to `rules-src/`; the validator otherwise unchanged)
- `docs/architecture/DISTRIBUTION_POLICY.md` (this addendum)

---

**Addendum 2026-09-03 — halls/ and rooms/ retired (cost-optimize, lever 3).**

A 30-day profile of session logs showed the always-loaded rule prefix at
~15K tokens, with the same rule repeated up to 9 times (`umask 077` ×9,
hook JSON format ×6, "27 anti-patterns" ×5). Every line of
`learned-src/learned/{halls,rooms}/` (9 files, 12.5 KB, static since
MemPalace v3.0 in April) restated a rule already loaded from `proven/`,
from the flat `learned/*.md` files, from L1 wake-up (`db-00x`), or from
this repo's CLAUDE.md (AAAK). The only non-duplicate line (tiktoken over
`wc -w`) moved into `learned/architecture.md`. `security.md` carried each
of its two entries twice (pre-`a964722` graduation) and was deduplicated.

Also removed: 4 untracked, gitignored files under `.claude/rules/learned/`
(auto-loaded as project rules, byte-identical to the global copies —
the T62 "stays empty" invariant had drifted).

The `halls/`/`rooms/` readers in `command-router.sh`, `ralph-subagent-start.sh`,
`orchestrator-auto-learn.sh` and `orchestrator-report.sh` are all guarded by
`[[ -d ... ]]` and only count files; they already pointed at the empty
`.claude/rules/learned/halls` path since T62. `tests/test_learned_src_dedup.py`
pins both invariants (no taxonomy dirs, no repeated bullets).

---

**Addendum 2026-09-03 — rules-to-skills conversion, evidence split, archived roster (cost-optimize, lever 4).**

Three changes, all aimed at the same target: the always-loaded prompt prefix,
which is paid on every request in every project whether or not its content is
relevant to the task.

**1. Two rules became on-demand skills.** `ast-grep-usage.md` (~5.9 KB) and
`browser-automation.md` (~1.9 KB) were reference material, not norms: rule-syntax
tables, metavariable semantics, `stopBy` options, trust zones, action allowlists.
Useful when the task involves structural code search or a browser; dead weight
otherwise. They moved from `.claude/rules-src/` to
`.claude/skills/{ast-grep-usage,browser-automation}/SKILL.md`, body preserved
verbatim, with a `description` written as trigger text.

This narrows the copy-distributed rule set to the two rules that are genuinely
always-applicable:

| Rule | Distribution | Why it stays always-loaded |
|---|---|---|
| `native-tools-first.md` | header-stamped copy | governs tool choice on every file operation |
| `plan-immutability.md` | header-stamped copy | governs behaviour whenever a plan exists |

`RULE_FILES` in `.claude/scripts/sync-rules-from-source.sh` and `RULES` in
`scripts/validate-global-infrastructure.sh` were trimmed to match. Skills are
distributed by symlink (see the mixed-distribution table above), so the two new
skills follow the symlink path, not the copy path.

**2. The global proven rules were split into norm and evidence.** The 15 files in
`~/.claude/rules/proven/` totalled ~26 KB, the bulk of it casuistry accumulated
around each norm — worked examples, observed failure transcripts, canonical bad
snippets, blast-radius counts, "where this bites" checklists. The rule files are
reduced to norm + trigger + a link; the full pre-reduction text is preserved
verbatim in `docs/rules-evidence/`, one file per rule.

This introduces a distribution shape the policy did not previously have: a
**home-side normative file backed by a repo-side evidence file**. The norm is
always loaded and lives in `~/.claude/`; the evidence is never loaded and lives
in the repo (and the vault), reached on demand by following the link or by
`scripts/memory/recall_v2.py`. Evidence bodies are byte-identical to their source
and are historical records — if a norm is revised, revise the rule file, not the
evidence.

**3. Never-invoked skills and agents were archived.** Four skills moved to
`.claude/skills/_archived/` (`diagram-design`, `research-blockchain`,
`clean-slop`, `ethereum-rpc`) and ten agents to `.claude/agents/_archived/`
(`ux-ui-senior-developer`, `blockchain-security-auditor`, `research-blockchain`,
`liquid-staking-specialist`, `chain-infra-specialist-blockchain`,
`defi-protocol-economist`, `senior-frontend-developer`, `web-scrapper`,
`software-architech`, `Hyperliquid-DeFi-Protocol-Specialist`). All had zero
invocations and no live infrastructure reference.

`lead-software-architect` was evaluated and **kept**: it is still spawned by
`orchestrator.md` and `adversarial-plan-validator.md`, so archiving it would
break two live call sites.

`_archived/` is deliberately *inside* `.claude/skills/` and `.claude/agents/`
rather than a sibling directory. Both the skill-drift loop in
`scripts/validate-global-infrastructure.sh` and the roster enumerations require a
`SKILL.md` directly under `.claude/skills/<name>/`, so a nested `_archived/`
directory is skipped naturally — the archive is invisible to the tooling without
any allowlist entry. The four archived skills' escape-hatch lines in
`.claude/.skill-drift-ignore` were therefore removed as inert; restoring a skill
means moving it back out of `_archived/`, not re-adding a line.
