# Remediation Plan v2.87.0

**Date**: 2026-02-14
**Status**: IN PROGRESS
**Version**: 2.87.0

## Executive Summary

This plan addresses all findings from the comprehensive validation against Claude Code documentation for skills, hooks, agent teams, and sub-agents.

## Phase 1: Critical Fixes (Immediate)

### 1.1 Standardize SKILL.md Filename Case
- [ ] Rename `adversarial/skill.md` → `adversarial/SKILL.md` (if exists)
- [ ] Verify all skills use uppercase `SKILL.md`

### 1.2 Update Skill Versions to v2.87.0
Skills requiring version updates:

| Skill | Current | Target |
|-------|---------|--------|
| gates | v2.43.0 | v2.87.0 |
| clarify | v2.43.0 | v2.87.0 |
| security | v2.43.0 | v2.87.0 |
| bugs | v2.43.0 | v2.87.0 |
| parallel | unknown | v2.87.0 |
| smart-fork | unknown | v2.87.0 |
| task-classifier | unknown | v2.87.0 |
| glm5 | unknown | v2.87.0 |
| glm5-parallel | unknown | v2.87.0 |
| kaizen | unknown | v2.87.0 |
| readme | unknown | v2.87.0 |
| quality-gates-parallel | unknown | v2.87.0 |
| code-reviewer | unknown | v2.87.0 |
| sec-context-depth | unknown | v2.87.0 |
| audit | unknown | v2.87.0 |
| deslop | unknown | v2.87.0 |
| edd | unknown | v2.87.0 |

### 1.3 Add Missing Frontmatter Fields
Each skill must have:
```yaml
---
name: <skill-name>
description: "<clear description>"
user-invocable: true
---
```

## Phase 2: Agent Teams Integration

### 2.1 Verify Agent Teams Configuration
- [ ] Check `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings
- [ ] Verify subagent types are configured correctly
- [ ] Validate hooks for SubagentStart/SubagentStop events

### 2.2 Add context: fork Configuration
Skills that spawn subagents need:
```yaml
context: fork
agent: <subagent-type>
```

## Phase 3: Hooks Integration

### 3.1 Verify Hook Registration
All hooks from Phase 1 must be registered in `~/.claude/settings.json`

### 3.2 Add Skill-Scoped Hooks
Use `hooks:` frontmatter field for skill-specific hooks

## Phase 4: Unit Test Enhancement

### 4.1 Add Version Validation Tests
- [ ] All core skills at v2.87.0
- [ ] All optional skills have version field
- [ ] Warning for outdated versions

### 4.2 Add Frontmatter Compliance Tests
- [ ] Required fields present
- [ ] Field values valid

### 4.3 Add Agent Teams Integration Tests
- [ ] Environment variable set
- [ ] Subagent types configured

## Phase 5: Documentation Update

### 5.1 Update Architecture Docs
- [ ] Add Agent Teams section
- [ ] Add Sub-agents section
- [ ] Reference official Claude Code docs

### 5.2 Update CLAUDE.md
- [ ] Add Agent Teams integration
- [ ] Add hooks best practices

## Validation Commands

```bash
# Run all unit tests
./tests/run-all-unit-tests.sh --verbose

# Run skills validation
./tests/unit/test-skills-unification-v2.87.sh --verbose

# Run pre-commit validation
.git/hooks/pre-commit
```

## Success Criteria

1. All 328+ tests pass with 100% pass rate
2. All core skills at v2.87.0
3. All frontmatter compliant
4. No duplicate commands
5. Agent Teams fully integrated
