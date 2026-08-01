# Distribution Policy — Symlink vs Copy Strategy

**Version**: 1.0.0
**Date**: 2026-04-09
**Status**: Active

## Overview

This document defines the definitive distribution strategy for Ralph infrastructure files. The goal is to make the system work independently of the source repository location.

## Strategy Table

| Component | Strategy | Justification |
|-----------|----------|---------------|
| Rules (~/.claude/rules/) | **COPY** | Must work without repo. Checksum-validated for drift detection. |
| Universal Hooks (~/.claude/hooks/) | **COPY** | Must work without repo. Registered in settings.json with absolute paths. |
| Agent Definitions (~/.claude/agents/) | **SYMLINK**, except the Claude-native set → **COPY** | Symlinked by design. EXCEPTION: the Codex→Claude review/bug agents are COPIED (see below) so a stale/moved repo checkout cannot resurrect their old Codex-dependent version. |
| Skills (~/.claude/skills/) | **MIXED** | Key skills copied (task-classifier, curator); the Codex→Claude `bugs`/`security` skills are COPIED (see below); others symlinked. |
| Layer Files (~/.ralph/layers/) | **COPY** | Must work without repo. Updated by wake-up hook. |
| Settings.json | **SINGLE** | ~/.claude/settings.json is the ONLY config. All models use this. |

## Copy Rules

Files using COPY strategy:
1. Source of truth: `.claude/` directory in the repo
2. Target: corresponding global directory (`~/.claude/`)
3. Validation: checksum comparison via `scripts/validate-global-infrastructure.sh`
4. Sync: one-way from repo → global (never reverse)
5. Headers: each file gets `# Source: multi-agent-ralph-loop` comment

## Symlink Rules

Files using SYMLINK strategy:
1. Must point to absolute repo path
2. Validation: `find ~/.claude -type l ! -exec test -e {} \; -print` finds broken ones
3. Acceptable breakage: agents won't work if repo is moved
4. Recovery: re-run `scripts/validate-global-infrastructure.sh --fix`

## Validation

Run validation:
```bash
bash scripts/validate-global-infrastructure.sh
# Auto-fix broken symlinks:
bash scripts/validate-global-infrastructure.sh --fix
```

## Skills Distribution

Skills are distributed to 6 platform directories:
- ~/.claude/skills/<name>
- ~/.codex/skills/<name>
- ~/.ralph/skills/<name>
- ~/.cc-mirror/zai/config/skills/<name>
- ~/.cc-mirror/minimax/config/skills/<name>
- ~/.config/agents/skills/<name>

Key skills (task-classifier, curator, orchestrator) are COPIED to all 6.
Other skills are symlinked to repo source.

## Claude-native Agents/Skills — COPY exception (Codex→Claude set)

**Why:** the agents symlink resolves through the repo checkout. When that checkout is behind
the merged `main` (or moved), the symlink silently serves STALE content — which for these
files means the OLD Codex-dependent version could come back to life. These files are
correctness-critical: they must ALWAYS be the Claude-native version regardless of repo state.
A COPY guarantees that. To keep copies from drifting SILENTLY (the inverse failure), a parity
`--check` makes drift loud.

**Set** (from PR #31's Codex→Claude conversion):
- Agents (10): `debugger`, `refactorer`, `docs-writer`, `test-architect`, `frontend-reviewer`,
  `security-auditor`, `ralph-security`, `orchestrator`, `codex-reviewer`, `adversarial-plan-validator`
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
symlinks. `codex-cli` / `openai-docs` are out of scope (Codex by nature).

## Configuration

**PRIMARY SETTINGS**: `~/.claude/settings.json`
- This is the ONLY settings file for all models (Claude, Zai, Minimax)
- All hooks, agents, and configuration are registered here
