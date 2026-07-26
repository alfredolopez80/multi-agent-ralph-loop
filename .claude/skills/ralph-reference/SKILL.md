---
name: ralph-reference
description: Version history and reference tables for Multi-Agent Ralph (batch execution v2.88, skills/commands unification v2.87, GLM-5 flag v2.84.1, LSP integration v2.88.1, security fixes v2.89.2, test layout, docs map). Load when you need the detailed feature reference, changelog, or file-layout tables that used to live in CLAUDE.md.
---

# Ralph Reference (lazy-loaded)

Reference material moved out of the always-loaded `CLAUDE.md` to save resident context.
The operational rules (parallel-first, Aristotle, config location, security hooks, agent teams,
quality gates, repository isolation, model routing, memory system) remain in `CLAUDE.md`.

## Batch Task Execution (v2.88.0)

New skills for autonomous multi-task execution:

| Skill | Purpose | Usage |
|-------|---------|-------|
| `/task-batch` | Execute task lists autonomously | `/task-batch docs/prd/file.prq.md` |
| `/create-task-batch` | Interactive PRD creator | `/create-task-batch "Feature name"` |

**Key Features**:
- Handles MULTIPLE tasks (not single task)
- MANDATORY completion criteria per task
- VERIFIED_DONE validation guarantee
- Fresh context per task execution
- Auto-commit after each completed task

See: `docs/batch-execution/BATCH_SKILLS_v2.88.0.md`

## Skills/Commands Unification (v2.87.0)

**Unified Skills Model**: All commands now use the SKILL.md format per Claude Code best practices.

| Location | Purpose | Format |
|----------|---------|--------|
| `.claude/skills/<name>/SKILL.md` | Source of truth (repo) | Skill directory |
| `~/.claude/skills/<name>` | Symlink to repo | Symlink |

**Key Changes**:
- Removed duplicate command files from `~/.claude/commands/`
- All Ralph skills symlinked from global to repo
- Single source of truth: changes in repo reflect globally
- Version aligned to v2.87.0 across all skills

See: `docs/architecture/UNIFIED_ARCHITECTURE_v2.87.md`

### Skills Distribution (single-source)

Skills live in the repo at `.claude/skills/<name>/`. Claude Code picks them up via the `~/.claude/skills/<name>` symlink created by `auto-sync-global.sh` at SessionStart.

**Source of truth**: `.claude/skills/<name>/` in this repo.

**Create symlink** (only needed for new skills):
```bash
SKILL_NAME="my-skill"
REPO="$(git rev-parse --show-toplevel)"
mkdir -p ~/.claude/skills
ln -sfn "$REPO/.claude/skills/$SKILL_NAME" ~/.claude/skills/$SKILL_NAME
```

Legacy multi-platform distribution (cc-mirror, codex, ralph, agents) was removed in v3.x — the project is single-user, single-target (Claude Code), with model selection via CLI env var injection.

## Security Fixes (v2.89.2)

- Hooks aligned with official Claude Code hooks guide (exit codes, field names, dynamic paths)
- 15 orchestrator audit findings fixed (xargs rm -rf, eval, double shebangs, JSON injection)
- 14 security vulnerabilities remediated in v2.89.1 (command chaining, SHA-256, deny list, file locking)
- 37 automated security tests in `tests/security/`
- Threat model: `docs/security/SECURITY_MODEL_v2.89.md`

## GLM-5 Integration (v2.84.1)

All major commands support `--with-glm5` flag:
```bash
/orchestrator "task" --with-glm5
/iterate "fix errors" --with-glm5
/security src/ --with-glm5
```

## LSP Integration (v2.88.1)

Language Server Protocol for efficient code navigation:

| Skill | LSP Usage |
|-------|-----------|
| `/gates` | Type checking without reading files |
| `/security` | Navigate code during audits |
| `/code-reviewer` | Find references efficiently |
| `/lsp-explore` | Dedicated LSP navigation skill |

**Essential Language Servers:**
- `typescript-language-server` - TypeScript/JavaScript
- `pyright` - Python
- `clangd` - C/C++

**Installation:** `./scripts/install-language-servers.sh --essential`
**Validation:** `./scripts/install-language-servers.sh --check`

## Test Organization

Tests in `tests/` at project root:
```
tests/
├── layers/               # Layer stack tests (v3.0 MemPalace)
│   └── test_layer_stack.py
├── aaak/                 # AAAK codec tests (utility, not for context)
│   └── test_aaak_codec.py
├── security/             # Security validation (v2.89)
│   └── test-claude-mem-removed.sh
├── skills/               # Skill unit tests (v2.88)
│   ├── test-task-batch.sh
│   ├── test-create-task-batch.sh
│   └── test-batch-skills-integration.sh
├── quality-parallel/
├── swarm-mode/
└── unit/
```

Do not place tests in `.claude/tests/` (deprecated).

## Documentation Map

All documentation in `docs/`:
- `docs/architecture/` - Design documents (incl. AAAK_LIMITATIONS_ADR)
- `docs/audit/` - Drift audits (CLAUDE_MD_DRIFT_2026-04-07.md)
- `docs/batch-execution/` - Batch task execution (v2.88)
- `docs/benchmark/` - Memory baselines + wake-up cost metrics
- `docs/refactor/` - Taxonomy migration map + curator PRD
- `docs/security/` - Security documentation
- `docs/swarm-mode/` - Swarm mode guides
- `docs/hooks/` - Hook reference
- `docs/prd/` - Example PRD files

## References

- [Claude Code Docs](https://github.com/ericbuess/claude-code-docs) - Official docs mirror
