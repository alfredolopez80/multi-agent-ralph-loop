# Project PIN - Multi-Agent Ralph Loop

> **Version**: v2.41
> **Purpose**: Frame de referencia para el search tool. Mas keywords = mas hits.
> **Project**: Multi-Agent Ralph Loop Orchestration System

## Lookup Table

| Area | Keywords | Archivos |
|------|----------|----------|
| Orchestration | orchestrator, workflow, steps, clarify, classify, plan, execute, validate, retrospective | scripts/ralph, .claude/skills/orchestrator/* |
| Skills | skill, command, SKILL.md, frontmatter, context fork, user-invocable | .claude/skills/*/*.md, ~/.claude/skills/*/*.md |
| Hooks | hook, PostToolUse, PreToolUse, SessionStart, PreCompact, UserPromptSubmit, Stop | .claude/hooks/*.sh, ~/.claude/hooks/*.sh |
| Agents | agent, subagent, Task tool, model sonnet, run_in_background | .claude/agents/*.md, ~/.claude/agents/*.md |
| Context | context, compaction, ledger, handoff, progress, PIN, lookup table | .claude/progress.md, .claude/pins/*, ~/.ralph/ledgers/* |
| Quality | gates, lint, format, test, type-check, quality-gates.sh | .claude/hooks/quality-gates.sh, .claude/skills/gates/* |
| Security | security, audit, adversarial, security-auditor, git-safety-guard | .claude/skills/security/*, .claude/hooks/git-safety-guard.py |
| Testing | test, pytest, integration, validate-integration, test_v2_40 | tests/*, scripts/ralph validate-integration |
| Git | git, worktree, branch, commit, PR, merge, safety | .claude/skills/using-git-worktrees/*, .claude/hooks/git-safety-guard.py |

## Quick Reference

### Core Commands
- `/orchestrator` - Full 8-step workflow
- `/gates` - Quality validation (9 languages)
- `/adversarial` - Spec refinement
- `/loop` - Ralph loop execution
- `/pin` - Lookup table management (NEW v2.41)

### Key Files
- `CLAUDE.md` - Project instructions
- `scripts/ralph` - CLI entry point
- `~/.claude/settings.json` - Global hooks config
- `.claude/settings.local.json` - Project permissions

### v2.41 Features
- `context: fork` in skills (orchestrator, bugs, refactor, prd, ast-search)
- `progress.md` auto-tracking via progress-tracker.sh
- PIN/Lookup tables for search optimization
- Session refresh hints in PreCompact

## Auto-Generated Section

```
# Last updated: 2026-01-13
# Project: multi-agent-ralph-loop
# Skills: 197+ global, 10+ project-specific
# Hooks: 23 global hooks
```
