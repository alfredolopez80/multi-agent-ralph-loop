# Skills/Commands Unification Analysis v2.87

**Date**: 2026-02-14
**Version**: v2.88.0
**Status**: ANALYSIS COMPLETE

## Executive Summary

Two critical problems were identified in the current multi-agent-ralph-loop implementation:

1. **Duplication between repo and global**: Skills and commands exist in both the repository (`~/.claude/skills/` and `~/.claude/commands/`) and the repo (`.claude/skills/` and `.claude/commands/`), causing confusion and version drift.

2. **Model inconsistency**: Skills use an older model structure (v2.43-2.57) while commands use newer versions (v2.84), violating Claude Code's unified skills model.

## Claude Code Official Model (from docs)

According to [Claude Code documentation](https://code.claude.com/docs/en/skills):

> **Custom slash commands have been merged into skills.** A file at `.claude/commands/review.md` and a skill at `.claude/skills/review/SKILL.md` both create `/review` and work the same way. Your existing `.claude/commands/` files keep working. Skills add optional features: a directory for supporting files, frontmatter to control whether you or Claude invokes them, and the ability for Claude to load them automatically when relevant.

### Key Points:
1. **Skills are the preferred model** - commands are legacy but still work
2. **Skills take precedence** - if skill and command share same name, skill wins
3. **Skill structure**: `.claude/skills/<skill-name>/SKILL.md` (directory with SKILL.md)
4. **Command structure**: `.claude/commands/<name>.md` (single file)
5. **Priority**: enterprise > personal > project

## Current State Analysis

### Version Drift

| Component | Location | Version | Issue |
|-----------|----------|---------|-------|
| orchestrator SKILL.md | repo/.claude/skills/ | 2.47.2 | **OUTDATED** |
| orchestrator.md | global commands | 2.84.1 | Current |
| orchestrator SKILL.md | global backup | 2.57.3 | Old backup |
| loop SKILL.md | repo/.claude/skills/ | 2.43.0 | **OUTDATED** |
| loop.md | global commands | 2.84.1 | Current |

### File Counts

| Location | Type | Count |
|----------|------|-------|
| repo/.claude/skills/ | Skills (actual) | 42 |
| ~/.claude/skills/ | Skills (mostly symlinks) | 1858 |
| repo/.claude/commands/ | Commands (actual) | 41 |
| ~/.claude/commands/ | Commands (duplicates) | 41 |

### Duplication Issues

1. **Commands duplicated**: All 41 commands exist as actual files in BOTH repo and global
2. **Skills have symlinks**: Ralph skills correctly symlink from global to repo
3. **Backup skills outdated**: 6 backup.* folders in global skills with old versions
4. **Mixed model**: Using both commands/ and skills/ for same functionality

### Symlink Structure (Current - Correct for Skills)

```
~/.claude/skills/orchestrator -> /path/to/repo/.claude/skills/orchestrator
~/.claude/skills/loop -> /path/to/repo/.claude/skills/loop
~/.claude/skills/gates -> /path/to/repo/.claude/skills/gates
...
```

### Command Duplication (Current - Problem)

```
repo/.claude/commands/loop.md (v2.84.1) <-- DIFFERENT FROM
~/.claude/commands/loop.md (v2.84.1)     <-- Both are actual files
```

## Recommended Unified Model

### Principle: Skills-Only with Symlinks

Following Claude Code best practices, we should:

1. **Use SKILL.md format for all Ralph commands** (preferred over commands/)
2. **Keep source of truth in repo** (`.claude/skills/<name>/SKILL.md`)
3. **Symlink from global to repo** (single source of truth)
4. **Remove command duplicates** (or convert to symlinks)
5. **Delete backup.* folders** (outdated)

### Directory Structure (Target)

```
multi-agent-ralph-loop/
├── .claude/
│   ├── skills/                    # Source of truth for Ralph skills
│   │   ├── orchestrator/
│   │   │   ├── SKILL.md           # v2.87.0 unified
│   │   │   └── references/        # Supporting files
│   │   ├── loop/
│   │   │   └── SKILL.md           # v2.87.0 unified
│   │   ├── gates/
│   │   ├── adversarial/
│   │   ├── parallel/
│   │   ├── retrospective/
│   │   ├── clarify/
│   │   ├── security/
│   │   ├── bugs/
│   │   ├── smart-fork/
│   │   ├── task-classifier/
│   │   ├── curator/
│   │   ├── glm5/
│   │   └── glm5-parallel/
│   ├── commands/                  # Optional: legacy or non-skill commands
│   │   └── (empty or symlinks)
│   ├── agents/                    # Subagent definitions
│   └── hooks/                     # Hook scripts

~/.claude/
├── skills/
│   ├── orchestrator -> /path/to/repo/.claude/skills/orchestrator
│   ├── loop -> /path/to/repo/.claude/skills/loop
│   └── ... (other Ralph skills as symlinks)
└── commands/
    ├── orchestrator.md -> /path/to/repo/.claude/skills/orchestrator/SKILL.md
    ├── loop.md -> /path/to/repo/.claude/skills/loop/SKILL.md
    └── ... (optional, for backward compatibility)
```

### Skill Frontmatter Standard (v2.87)

```yaml
---
# VERSION: 2.87.0
name: orchestrator
description: "Full orchestration workflow with swarm mode: evaluate -> clarify -> classify -> persist -> plan mode -> spawn teammates -> execute -> validate -> retrospective. Use when: (1) implementing features, (2) complex refactoring, (3) multi-file changes, (4) tasks requiring coordination."
argument-hint: "<task description>"
user-invocable: true
context: fork
agent: orchestrator
allowed-tools:
  - Task
  - AskUserQuestion
  - EnterPlanMode
  - ExitPlanMode
  - TodoWrite
  - Read
  - Edit
  - Write
  - Bash
  - Glob
  - Grep
---
```

## Ralph Core Skills List

These skills should be unified and maintained in the repo:

| Skill | Purpose | Type |
|-------|---------|------|
| `/orchestrator` | Full orchestration workflow | Primary |
| `/loop` | Iterative execution until VERIFIED_DONE | Primary |
| `/gates` | Quality validation gates | Primary |
| `/adversarial` | Spec refinement and review | Primary |
| `/parallel` | Parallel subagent execution | Primary |
| `/retrospective` | Post-task analysis | Primary |
| `/clarify` | Requirement clarification | Secondary |
| `/security` | Security audit | Secondary |
| `/bugs` | Bug hunting with Codex CLI | Secondary |
| `/smart-fork` | Find relevant past sessions | Secondary |
| `/task-classifier` | 3D complexity classification | Secondary |
| `/curator` | Repository curation | Secondary |
| `/glm5` | GLM-5 agent integration | Integration |
| `/glm5-parallel` | GLM-5 parallel execution | Integration |

## Implementation Plan

### Phase 1: Cleanup (Manual)
1. Delete backup.* folders from ~/.claude/skills/
2. Remove duplicate commands from ~/.claude/commands/
3. Update repo skill versions to v2.87.0

### Phase 2: Unification
1. Merge command content into skill SKILL.md files
2. Update all frontmatter to standard format
3. Create symlinks from global commands to repo skills (optional)

### Phase 3: Validation
1. Test all skill invocations
2. Verify no duplication in `/` menu
3. Create validation script

## Version History Reference

| Version | Key Changes |
|---------|-------------|
| v2.45 | Initial hooks integration |
| v2.46 | RLM-inspired routing |
| v2.47 | Smart memory search |
| v2.50 | Repo learning |
| v2.51 | Checkpoint system, event engine |
| v2.52 | Status auto-check |
| v2.55 | Auto-learning, curator |
| v2.56 | Smart checkpoint |
| v2.57 | Memory reconstruction |
| v2.81 | Swarm mode integration |
| v2.84 | GLM-5 Agent Teams |
| v2.86 | Security hooks, Agent Teams hooks |
| v2.87 | Skills/Commands unification |
| v2.88 | **Model-agnostic architecture** - No flags required, uses configured default model |

## Next Steps

1. Execute Phase 1 cleanup
2. Create unified SKILL.md files for all Ralph skills
3. Set up proper symlinks
4. Document in `docs/architecture/UNIFIED_ARCHITECTURE_v2.87.md`
5. Create validation script `scripts/validate-skills-unification.sh`

## References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Agent Skills Open Standard](https://github.com/anthropics/agent-skills)
- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
