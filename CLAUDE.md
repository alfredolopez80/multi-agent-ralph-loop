# Multi-Agent Ralph v3.0.0

Orchestration system: memory-driven planning, multi-agent coordination, quality validation.

## Analysis Methodology

First-principles analysis = on-demand `/aristotle` skill (`.claude/skills/aristotle/`) for ambiguous/high-impact decisions; it never selects provider/model (#45). Ref: `docs/reference/aristotle-first-principles.md`.

## Configuration Location

Global `~/.claude/` gets a **mixed** distribution: rules + `learned/` as header-stamped COPIES, `hooks/` as a directory symlink, agents/skills mixed. Strategy: `docs/architecture/DISTRIBUTION_POLICY.md`.

```bash
bash ./scripts/validate-global-infrastructure.sh        # check
bash ./scripts/validate-global-infrastructure.sh --fix  # auto-fix broken symlinks
```

## Browser Automation (v3.0)

Primary tool: `agent-browser` (isolated Chrome). Config: `agent-browser.json` (allowlist) + `agent-browser-policy.json` (deny rules). Rule: `.claude/rules/browser-automation.md`.

## Security Hooks

git-safety-guard.py (PreToolUse Bash), repo-boundary-guard.sh (PreToolUse Bash), audit-secrets.js (PostToolUse). Purposes: each hook's header.

## Session Lifecycle

Surviving: session-end-handoff.sh (SessionEnd, #47 writer); session-start-restore-context.sh reduced to exact-task resume (#69 Slice E), opt-in. PostCompact does NOT exist — use SessionStart matcher "compact".

## Agent Teams (v2.86)

Agents live in `.claude/agents/`: ralph-coder, ralph-reviewer, ralph-tester, ralph-researcher, ralph-frontend, ralph-security — roles in frontmatter. Enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`; workflow: `orchestrator` / `parallel` skills.

## Language Policy

Code, docs, commit messages: English. Chat: match the user's language.

## Commands

Commands: `.claude/commands/`; catalog in lazy-loaded `ralph-reference`.

## Critical Hooks

The authoritative registration lists are `.claude/settings.json.example` and `scripts/validate-hooks-registration.sh` — not duplicated here (they rotted once).

## Memory System (MemPalace v3.0)

Layers: L0 identity (`~/.ralph/layers/`) · L1 top rules (`L1_essential.md`) · L2 graduated rules (`.claude/learned-src/learned/*.md`, flat; the `halls/`/`rooms/` taxonomy was retired 2026-09-03 as a verbatim duplicate of `proven/` + L1) · L3 vault grep (on demand). Wake-up injects ~2000 tokens — count all of it.
Recall on demand, never a hook (T73): `python3 scripts/memory/recall_v2.py --query "<terms>" --limit 3`.
Storage: KG `~/Documents/Obsidian/MiVault/` · `~/.ralph/{layers,ledgers,handoffs}/`.
Key decisions: AAAK rejected (+19.8% tokens; selection beats encoding — `docs/architecture/AAAK_LIMITATIONS_ADR_2026-04-07.md`) · dedup is by REALPATH: `learned/` ships as COPIES · strategy: `docs/architecture/DISTRIBUTION_POLICY.md`.

## Quality Gates

CORRECTNESS (syntax, blocking) → QUALITY (types, blocking) → SECURITY (semgrep + gitleaks, blocking) → CONSISTENCY (advisory). 3-Fix Rule: 3 attempts max, then escalate.

## Repository Isolation

Do not edit, run git on, or test in external repositories. Use `/repo-learn` for external patterns. No tests in `.claude/tests/` (deprecated).

## Reference

Test layout, docs map, version history, external links: lazy-loaded `ralph-reference` skill.

## Session coordination (lead + worktree workers)

Applies ONLY inside a Q-team (`qteam`/`qteam-zc` tmux functions); otherwise no lead/worker split, no ASSIGN/DONE protocol. The working directory decides; a contradicting launch prompt means stop and tell the human.

**Role detection (before anything else)**: path contains `.claude/worktrees/<name>` → you are worker `<name>`, use only the `wt-worker` skill; otherwise you are lead, use only the `wt-lead` skill. If unsure, `git rev-parse --show-toplevel`.

Roles: lead assigns and integrates in the main checkout (never edits `.claude/worktrees/`); workers run on `worktree-<name>` branches. Protocol and failure modes: `wt-lead` / `wt-worker` skills + `docs/qteam/QTEAM_FAILURE_MODES.md`.

Invariants: never end a task with uncommitted changes · every task names allowed paths, nothing outside them is edited · artifacts go in the worker's `results/` · messages use the ASSIGN/DONE/RETURN/REBASE/BLOCKED/MERGED formats — the work lives in git.

Required settings: `~/.claude/settings.json` needs `{"crossSessionInbound": "accept", "worktree": {"baseRef": "head"}}`. This repo ships no `.claude/settings.json` (`install.sh:114` copies the example verbatim over a MISSING user settings).

Gate (T33): integrate.sh runs `$QTEAM_TEST_CMD` after every merge, refuses when unset. Export:
`export QTEAM_TEST_CMD="bash tests/run-all-unit-tests.sh"` — runner asserts `failed == 0` AND `total > 0`, and since 2026-09-01 also runs the full `pytest tests/` sweep, making it a superset of CI's "Run Tests" job (they diverged silently for 30+ runs before that; local green no longer means CI green by accident).
