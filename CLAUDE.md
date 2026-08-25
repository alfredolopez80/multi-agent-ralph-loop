# Multi-Agent Ralph v3.0.0

Orchestration system with memory-driven planning, multi-agent coordination, automatic learning, and quality validation.

## Parallel-First Execution (MANDATORY)

**All independent tasks MUST be executed in parallel using Agent Teams.** This is the #1 operational priority.

| Complexity | Execution Mode | Agent Teams |
|---|---|---|
| 1-2 | Direct execution (no team) | Optional |
| 3+ | **Parallel with Agent Teams** | **REQUIRED** |

**6 Ralph Teammates available for parallel spawning:**

| Teammate | Role | Spawn When |
|---|---|---|
| `ralph-coder` | Implementation | Code changes needed |
| `ralph-reviewer` | Code review | Post-implementation |
| `ralph-tester` | Testing & QA | Tests needed (always with coder) |
| `ralph-researcher` | Research | Unknown patterns |
| `ralph-frontend` | Frontend (WCAG 2.1 AA) | UI/component changes |
| `ralph-security` | Security (6 pillars) | Auth, crypto, user input |

**Rule**: `.claude/rules/parallel-first.md`
**Anti-rationalization**: entries #38-#46 in `docs/reference/anti-rationalization.md`

## Analysis Methodology

**Aristotle First Principles** is the foundational methodology. Every task passes through these phases before execution:

| Complexity | Phases | Duration |
|---|---|---|
| 1-3 | Phase 1 (Assumption Autopsy) + Phase 5 (Aristotelian Move) | 30s |
| 4+ | All 5 phases (Autopsy, Truths, Reconstruction, Map, Move) | 2-10 min |

**"Task" means a change of direction, not the arrival of text.** The analysis runs when
the user opens or redirects work, and when another agent's report can invalidate the
plan's premise. It does NOT run on a worker's routine `DONE`/`ACK`/`PONG`/`MERGED`, nor
on the lead's own reasoning inside a task that is already framed. The test is whether
the input can change what you do — a status message confirming the expected reframes
nothing. This bounds the trigger; when it fires, it fires in full. Measured cost is
~0 tokens per prompt and 36 ms per tool-call, so the scoping buys latency and
signal-to-noise, never token savings. Full table in `~/.claude/CLAUDE.md`.

Reference: `docs/reference/aristotle-first-principles.md`
Rule: `.claude/rules-src/aristotle-methodology.md` (source; the copy that
applies is `~/.claude/rules/aristotle-methodology.md`, written by
`.claude/scripts/sync-rules-from-source.sh`)

## Configuration Location

**PRIMARY SETTINGS**: `~/.claude/settings.json`

This is the ONLY configuration file for Claude Code (all models: Claude, Zai, Minimax). All hooks, agents, and settings are configured here.

> **Reference material** (batch execution v2.88, skills/commands unification v2.87, GLM-5 flag, LSP integration, security fixes v2.89.2, test layout, docs map) moved to the lazy-loaded `ralph-reference` skill — invoke it when you need those detail tables.

### Global Infrastructure Validation

Global directories (`~/.claude/`) receive a **mixed** distribution from this repo: the 7 top-level rules and the `learned/` taxonomy are header-stamped COPIES, `hooks/` is a directory symlink, and agents/skills are a mix of symlinks and copies. Per-component strategy: `docs/architecture/DISTRIBUTION_POLICY.md`. Validate/repair:
```bash
bash ./scripts/validate-global-infrastructure.sh        # check
bash ./scripts/validate-global-infrastructure.sh --fix  # auto-fix broken symlinks
```

## Browser Automation (v3.0)

**Primary tool**: `agent-browser` (Vercel Labs) — isolated Chrome for Testing with domain allowlist and action policies.

| Config File | Purpose |
|---|---|
| `agent-browser.json` | Domain allowlist (localhost only by default) |
| `agent-browser-policy.json` | Action deny rules (passwords, wallets, seed phrases) |

Rule: `.claude/rules/browser-automation.md`

## Security (v3.0)

### Security Hooks

| Hook | Purpose | Trigger |
|------|---------|---------|
| `git-safety-guard.py` | Blocks rm -rf, git reset --hard, command chaining, and destructive aws/gcloud/gsutil/kubectl ops (deny + ask tiers, v2.70.0) | PreToolUse (Bash) |
| `repo-boundary-guard.sh` | Prevents operations outside current repo | PreToolUse (Bash) |
| `audit-secrets.js` | Audit logging for 20+ secret patterns | PostToolUse |
| `teammate-idle-quality-gate.sh` | Blocks idle with secrets/debug code (CWE-798, CWE-321) | TeammateIdle |
| `task-completed-quality-gate.sh` | 7 quality gates including hardcoded secrets + SQL injection | TaskCompleted |

## Session Lifecycle Hooks (v2.86)

| Event | Hook | Purpose |
|-------|------|---------|
| `PreCompact` | pre-compact-handoff.sh | Save state BEFORE compaction |
| `SessionStart(compact)` | post-compact-restore.sh | Restore context AFTER compaction |
| `SessionEnd` | session-end-handoff.sh | Save state when session TERMINATES |

> **Note**: `PostCompact` event does NOT exist in Claude Code. Use `SessionStart(matcher="compact")` instead.

## Agent Teams (v2.86)

Agent Teams permite múltiples Claude Code instances trabajando en paralelo con un team lead coordinando.

### Nuevos Hooks

| Event | Purpose | Exit 2 Behavior |
|-------|---------|-----------------|
| `TeammateIdle` | Quality gate when teammate goes idle | Keep working + feedback |
| `TaskCompleted` | Quality gate before task completion | Prevent completion + feedback |
| `SubagentStart` | Load Ralph context into subagents | - |
| `SubagentStop` | Quality gates when subagent stops | - |

### Teammate Types

| Type | Role | Tools |
|------|------|-------|
| `ralph-coder` | Code implementation | Read, Edit, Write, Bash |
| `ralph-reviewer` | Code review | Read, Grep, Glob |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) |
| `ralph-researcher` | Research & exploration | Read, Grep, Glob, WebSearch |
| `ralph-frontend` | Frontend with DESIGN.md | LSP, Read, Edit, Write, Bash(npm/npx/bun/git) |
| `ralph-security` | Security specialist (6 pillars) | LSP, Read, Grep, Glob, Bash(audit/semgrep/gitleaks/git) |

### Crear Team

```bash
# Usando TeamCreate tool en Claude Code
TeamCreate(team_name="my-project", description="Working on feature X")

# Spawn teammates
Task(subagent_type="ralph-coder", team_name="my-project")
Task(subagent_type="ralph-reviewer", team_name="my-project")
```

### Agent Teams Configuration

Agent Teams está habilitado en `~/.claude/settings.json`:
```json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## Language Policy

| Content Type | Language |
|--------------|----------|
| Code | English |
| Documentation | English |
| Commit messages | English |
| Chat responses | Match user's language |

## Commands

```bash
# Orchestration
/orchestrator "task"           # Full workflow
/iterate "task"                # Iterative execution (renamed from /loop v2.94)
/task-batch <prd-file>         # Batch task execution (v2.88)
/create-task-batch "feature"   # Create PRD interactively (v2.88)
/gates                         # Quality validation
/autoresearch <target> <metric> # Autonomous experimentation (v2.94)
/adversarial                   # Spec refinement

# Debugging
/bug "issue description"
/bugs src/

# Security
/security src/

# Learning
/curator full --type backend --lang typescript
/repo-learn https://github.com/owner/repo

# Context
/docs hooks                    # Hooks documentation
/docs mcp                      # MCP documentation
```

## Critical Hooks

These hooks must be registered in settings.json:

| Hook | Event | Purpose |
|------|-------|---------|
| `git-safety-guard.py` | PreToolUse (Bash) | Blocks rm -rf, git reset --hard, destructive aws/gcloud/kubectl |
| `repo-boundary-guard.sh` | PreToolUse (Bash) | Prevents work outside repo |
| `learning-gate.sh` | PreToolUse (Task) | Auto-learning trigger |
| `status-auto-check.sh` | PostToolUse | Status updates |
| `batch-progress-tracker.sh` | PostToolUse | Batch progress tracking (v2.88) |
| `teammate-idle-quality-gate.sh` | TeammateIdle | Quality checks before idle |
| `task-completed-quality-gate.sh` | TaskCompleted | Validation before completion |

Validation: `./scripts/validate-hooks-registration.sh`

### Hook Events (12 configured)

`SessionStart`, `SessionEnd`, `Stop`, `PreToolUse`, `PostToolUse`, `PreCompact`, `UserPromptSubmit`, `TeammateIdle`, `TaskCompleted`, `SubagentStart`, `SubagentStop`, `TaskCreated`

## Model Routing

No complexity-based model routing exists. The authoritative policy is
`~/.claude/CLAUDE.md` -> "Model Routing": the task is handled by the active
session model (Opus by default; the user decides with `/model`). Complexity
thresholds trigger PROCESS (Plan Mode >= 4, Parallel-First >= 3, Aristotle >= 4),
never model choice.

## Memory System (MemPalace v3.0)

### Layer Stack (SessionStart wake-up)

| Layer | File | Tokens (cl100k) | Purpose |
|-------|------|-----------------|---------|
| L0 | `~/.ralph/layers/L0_identity.md` | ~239 | Agent identity + principles |
| L1 | `~/.ralph/layers/L1_essential.md` | ~579 | 9 actionable rules (filtered from 1003) |
| L2 | `.claude/rules/learned/{halls,rooms}/` | on-demand | Project-specific taxonomy |
| L3 | Obsidian vault grep | on-demand | Full knowledge base queries |

**Wake-up hook**: `.claude/hooks/wake-up-layer-stack.sh` runs at SessionStart and injects
**~1950-2000 tokens** (tiktoken cl100k_base, 2026-08-23): ~818 are L0+L1; the rest is
recall_v2 top rules, Vault Stats and the project Wing (L2) — count ALL of it, not just L0+L1.

### Learned Rules Taxonomy

Rules organized in 3 dimensions for flexible retrieval:

| Dimension | Directory | Organization |
|-----------|-----------|--------------|
| **Halls** (by type) | `.claude/rules/learned/halls/` | decisions, patterns, anti-patterns, fixes |
| **Rooms** (by topic) | `.claude/rules/learned/rooms/` | hooks, memory, agents, security, testing |
| **Wings** (by scope) | no directory — compiled at session start | Wing (L2) content is generated from the Obsidian vault by the wake-up hook (`vault-wing-compiler.sh`); `.claude/rules/learned/wings/` does not exist |

**L1 Filter**: Mechanical noise excluded (`ep-auto-*`, `ep-rule-*`), substantive filter (behavior >= 20 chars), criticality bonus (1.5x for CRITICAL/MUST/NEVER).

### Agent Diaries

Each ralph agent has a diary in Obsidian vault:
- Location: `~/Documents/Obsidian/MiVault/agents/{agent-name}/diary/`
- 6 agents: ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher, ralph-frontend, ralph-security

### Storage Locations

- Knowledge graph: `~/Documents/Obsidian/MiVault/` (primary)
- Layer files: `~/.ralph/layers/`
- Session ledgers: `~/.ralph/ledgers/`
- Session handoffs: `~/.ralph/handoffs/`

### Key Decisions

- **AAAK rejected** for LLM context (see `docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md`): PUA encoding increases cl100k_base tokens by +19.8%. Selection beats encoding.
- **claude-mem removed**: Full forensic removal (Wave 0). Data migrated to Obsidian vault.
- **Drift audit**: 18 findings documented in `docs/audit/CLAUDE_MD_DRIFT_2026-04-07.md`
- **Context deduplication**: Claude Code deduplicates instruction blocks by REALPATH, not by content:
  a symlink loads once, a copy is paid for again in full. The `learned/` taxonomy is distributed as a
  COPY (rsync `-a --delete`), not a symlink. The seven top-level rules in `~/.claude/rules/` are
  header-stamped COPIES, synced by `.claude/scripts/sync-rules-from-source.sh` and verified by
  `scripts/validate-global-infrastructure.sh` (which strips the header before comparing). The previous
  claim that all global rules were symlinks was false on disk, and a second symlink-based mechanism was
  competing with the copies — it has been retired. Known drift (2026-08-25): the rsync'd `learned/`
  copies have diverged — the repo and global `learned/hooks.md` both carry a duplicated "Hook Stdin
  Protocol" bullet (the generator emits duplicates); the `~/Documents/.claude/` copy, which has it
  once, is the rare clean one.
- **Distribution policy**: See `docs/architecture/DISTRIBUTION_POLICY.md` for symlink vs copy strategy per component type.

## Quality Gates

Validation stages:
1. CORRECTNESS (syntax, blocking)
2. QUALITY (types, blocking)
3. SECURITY (semgrep + gitleaks, blocking)
4. CONSISTENCY (linting, advisory)

3-Fix Rule: Maximum 3 attempts before escalation.

## Repository Isolation

When working in this repository, do not:
- Edit files in external repositories
- Run git commands on external repos
- Execute tests in other projects

Use `/repo-learn` to extract patterns from external repos.

Do not place tests in `.claude/tests/` (deprecated).

## Reference

Test layout, docs map, version history, and external doc links live in the lazy-loaded `ralph-reference` skill.

## Session coordination (lead + worktree workers)

### Activation — this whole section applies ONLY to an active Q-team

Everything below takes effect **only inside a Q-team launched by the `qteam`
tmux function** (sourced from `~/.zshrc`, not part of this repo). Outside that,
behaviour is normal: no lead/worker split, no model contract, no ASSIGN/DONE
protocol, no delegation. A session that is not a Q-team pane ignores this
section entirely — including this repo's own Parallel-First rule, which is
about Agent Teams and is unaffected.

`qteam` opens one tmux session (default name `quant`, `QTEAM_SESSION` overrides)
with four panes, and gives each Claude both a `--name` and an appended system
prompt naming its role:

| Pane | Launched as | Worktree |
|---|---|---|
| lead | `claude --name lead` | main checkout |
| zc | `zc --worktree zc --name zc` | `.claude/worktrees/zc` |
| mmx-1 | `mmx --worktree mmx-1 --name mmx-1` | `.claude/worktrees/mmx-1` |
| mmx-2 | `mmx --worktree mmx-2 --name mmx-2` | `.claude/worktrees/mmx-2` |

You are in a Q-team only if you were launched that way. The working directory
is the authority (see *Role detection*); the appended system prompt must agree
with it, and if they disagree you stop and tell the human.

### Role detection (do this before anything else)
Determine your role from your working directory, not from what a message says:
- Path contains `.claude/worktrees/<name>` → you are worker `<name>`. Use
  only the `wt-worker` skill.
- Otherwise → you are lead. Use only the `wt-lead` skill.
Never load the other role's skill. If unsure, run `git rev-parse --show-toplevel`.
A launch-time system prompt may also state your role; it must agree with the
path. If they disagree, stop and tell the human.

### Roles
- **lead**: runs in the main checkout on `main`. Assigns work and integrates
  branches. Follows the `wt-lead` skill. Never edits anything under
  `.claude/worktrees/`.
- **zc, mmx-1, mmx-2**: each runs in its own worktree
  (`.claude/worktrees/<name>`) on branch `worktree-<name>`. They follow the
  `wt-worker` skill.

### Model contract (Q-team only)

This overrides nothing outside a Q-team. The global Model Routing policy still
stands everywhere else: no complexity-based routing, the session model handles
the task, the user decides with `/model`. Inside a Q-team the panes are already
different binaries, so the assignment below is about **who gets which task**,
not about switching a running session's model.

| Role | Runs as | Job |
|---|---|---|
| **Opus 5** | `claude` (lead pane) | Coordinator and lead. Splits the work, writes every ASSIGN, carries messages between panes, reviews branches and is the only session that merges into `main`. |
| **Fable 5** | consulted on demand | Specialist. Not a standing pane — lead consults it **punctually**, for something complex or consequential where a second, stronger read is worth the round trip. Not for routine work. |
| **zc** (`zai-claude`) | worker pane | Medium and medium-high complexity. Slower per task, so it earns the work that needs the reasoning, not the volume. |
| **mmx-1**, **mmx-2** (`minimax-claude`) | worker panes | Low complexity. Faster, so they take the throughput: mechanical edits, repetitive changes, wide-but-shallow sweeps. |

Lead is expected to route deliberately, not round-robin:

- **Size the task to the worker before assigning it.** A mechanical sweep sent
  to `zc` wastes the slow worker; a task needing real reasoning sent to `mmx`
  comes back needing a RETURN, which costs more than assigning it correctly.
- **Keep both `mmx` panes busy.** They are the cheap parallelism. Two shallow
  tasks running beside one deep `zc` task is the shape to aim for.
- **Split by directory, never by topic** (see *Splitting work* in `wt-lead`),
  so the three workers never contend for the same file.
- **One task per worker at a time.** Do not queue; queueing hides idle panes.
- **Consult Fable 5 before committing to an expensive split**, not after a
  worker has already produced the wrong thing.
- **Research and web search go to a worker, never to a Claude subagent.** A
  subagent spawned by lead bills against the Claude MAX subscription; `zc` and
  the two `mmx` panes do not, and they carry the z.ai MCP servers
  (`web-search-prime`, `web-reader`, `zread`) for exactly this. Reading docs,
  surveying a library, checking what a flag does, sweeping an unfamiliar
  codebase — all of it is worker work. Spawning a Claude subagent to search is
  spending the subscription this whole team exists to conserve.
- Lead does not implement delegated work itself. If lead is coding, the split
  was wrong.

### Invariants
- A worker never ends a task with uncommitted changes.
- Every task names its **allowed paths**. Nothing outside them is edited.
- Unversioned artifacts (backtests, JSON, reports) go in `results/` inside the
  worker's own worktree. lead reads them at `.claude/worktrees/<name>/results/`.
- Messages between sessions use the ASSIGN / DONE / RETURN / REBASE / BLOCKED /
  MERGED formats defined in the skills. Keep them short; the work lives in git.

### Q-team contract rules

Each rule condenses real failures from this setup; the evidence (commands and
measurements) lives in `docs/qteam/QTEAM_FAILURE_MODES.md`.

1. Address `SendMessage` to `<name> [ref]` (ref from `ListAgents`). Delivered
   only if the result says "another Claude session on this machine" —
   `success: true` is the sender's receipt, never proof of delivery. Panel
   text is invisible to other sessions: every PONG/DONE/BLOCKED/RETURN is a
   tool call.
2. A blocked guard is a STOP: report BLOCKED and wait. Never craft a command
   variant that dodges the guard's pattern. If the guard is wrong, fix the guard.
3. Validate a gate exactly as CI invokes it. Accepting a gate change requires
   three results: passes over the tree, FAILS on a fresh violation, and the
   escape hatch silences. Zero-scope is failure, not pass.
4. A worker's real state is `git diff main...<branch>`, never `git status`:
   a clean tree is as compatible with "never started" as with "done".
5. Every reported bug carries a repro command and its output. When a diff
   admits two readings, count before concluding. Verify a teammate's numbers
   before they become documentation.
6. Worker panes never use `--system-prompt-file` (it REPLACES the harness
   prompt): use `--append-system-prompt[-file]`. The `[1m]` marker goes in
   `--model`; the environment variable alone is not enough.
7. Before acting on a warning, establish who emits it: a harness message and
   a repo hook have different reliability and different fixes. No unknown
   model silently gets a default context window.
8. When in doubt, ask — always through `AskUserQuestion`, never as prose at
   the end of a reply. In a Q-team, notify first and ask second: lead emits
   an OSC 777 to its own pane TTY, then calls the tool. The escape must be
   wrapped in tmux's DCS passthrough with every inner ESC doubled, and
   written to the TTY — a hook's stdout is captured for its JSON and never
   reaches the terminal (failure mode 28). Requires `allow-passthrough all`.
   OSC 9 does not work here; OSC 777 carries a title and a body, no subtitle.
```bash
printf '\033Ptmux;\033\033]777;notify;TITLE;BODY\033\033\\\033\\' > "$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}')"
```
   Ask only what you cannot measure: if git, the tests or the code answer it,
   answering it yourself is the job. The universal half of this rule lives in
   `~/.claude/CLAUDE.md`; what is Q-team-specific is the notification.

### Required settings

Cross-session messaging and worktree creation need two keys in
`~/.claude/settings.json`:

```json
{ "crossSessionInbound": "accept", "worktree": { "baseRef": "head" } }
```

They are recorded in `.claude/settings.json.example` alongside the rest of the
Ralph configuration. **This repository deliberately ships no
`.claude/settings.json`**: `install.sh` treats that path as the complete
settings payload and copies it verbatim over `~/.claude/settings.json` when the
user has none (`install.sh:114`). A partial file there would install a settings
file with no hooks at all. Add the two keys to your global settings, or install
from the example — never by committing a trimmed `.claude/settings.json`.

### Test command for integration

`wt-lead`'s `integrate.sh` runs `$QTEAM_TEST_CMD` after every merge into `main`,
and **refuses to integrate at all** when it is unset — before `main` moves, so a
missing gate can never be mistaken for a passing one (T33). Export it once per
shell; a session restart after compaction loses it, which is exactly how a merge
once landed stamped `OK` with no test ever run. For this repository:

```bash
export QTEAM_TEST_CMD="bash tests/run-all-unit-tests.sh"
```

That is the same command CI runs (`.github/workflows/ci.yml`, job *Run Tests*),
so a merge that goes green locally goes green there. The runner asserts both
`failed == 0` and `total > 0`, so an empty run fails instead of reporting a
false pass.
