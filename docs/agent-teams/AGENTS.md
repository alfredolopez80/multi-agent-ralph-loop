# Agent Teams - Custom Subagents

**Version**: v2.85.0
**Date**: 2026-02-14

This document describes the custom subagents available for Agent Teams in the Multi-Agent Ralph system.

## Overview

Agent Teams allows spawning multiple specialized Claude instances (teammates) that work in parallel under a Team Lead. Each teammate has specific tools and instructions tailored to their role.

## Teammate Types

### ralph-coder

**Role**: Code implementation with Ralph quality gates

**Tools**: Read, Edit, Write, Bash(npm, yarn, pnpm, bun, git, python, pytest, npx)

**Model**: glm-5

**Permission Mode**: acceptEdits

**Quality Standards**:
- CORRECTNESS: Syntax valid, logic sound
- QUALITY: No console.log, proper types
- SECURITY: No hardcoded secrets, input validation
- CONSISTENCY: Follow project style

**Usage**:
```bash
Task(subagent_type="ralph-coder", prompt="Implement user authentication")
```

---

### ralph-reviewer

**Role**: Code review with security and quality focus

**Tools**: Read, Grep, Glob

**Model**: glm-5

**Permission Mode**: default

**Review Checklist**:
- Security: OWASP Top 10, hardcoded secrets
- Quality: Error handling, type safety
- Consistency: Naming conventions, style
- Performance: Bottlenecks, efficiency

**Usage**:
```bash
Task(subagent_type="ralph-reviewer", prompt="Review src/auth/ for security issues")
```

---

### ralph-tester

**Role**: Unit and integration testing

**Tools**: Read, Edit, Write, Bash(npm test, pytest, jest, vitest, bun test)

**Model**: glm-5

**Permission Mode**: acceptEdits

**Test Standards**:
- Coverage: 80% minimum for new code
- Naming: `test_<feature>_<scenario>_<expected>`
- Structure: Arrange-Act-Assert pattern

**Usage**:
```bash
Task(subagent_type="ralph-tester", prompt="Write unit tests for UserService")
```

---

### ralph-researcher

**Role**: Codebase research and documentation fetching

**Tools**: Read, Grep, Glob, WebSearch, WebFetch

**Model**: glm-5

**Permission Mode**: default

**Research Focus**:
- Existing patterns to reuse
- Required dependencies
- System architecture
- External documentation

**Usage**:
```bash
Task(subagent_type="ralph-researcher", prompt="Research React Server Components patterns")
```

## Team Coordination

### Creating a Team

```bash
# 1. Create the team
TeamCreate(team_name="feature-auth", description="Implement authentication")

# 2. Spawn teammates
Task(subagent_type="ralph-researcher", team_name="feature-auth", prompt="Research auth patterns")
Task(subagent_type="ralph-coder", team_name="feature-auth", prompt="Implement JWT auth")
Task(subagent_type="ralph-tester", team_name="feature-auth", prompt="Write auth tests")

# 3. Review work
Task(subagent_type="ralph-reviewer", team_name="feature-auth", prompt="Review auth implementation")
```

### Task Assignment

Teammates share a task list at `~/.claude/tasks/{team-name}/`. Tasks are assigned via `TaskUpdate` with the `owner` parameter.

### Communication

Teammates communicate via the `SendMessage` tool:
```bash
SendMessage(type="message", recipient="ralph-coder", content="Found pattern in src/auth/")
```

## Quality Gates

### TeammateIdle Hook

When a teammate is about to go idle, the `teammate-idle-quality-gate.sh` hook runs:

- **Exit 0**: Allow idle
- **Exit 2**: Keep working + send feedback

Checks:
- No console.log statements
- No debugger statements

### TaskCompleted Hook

When a task is marked complete, `task-completed-quality-gate.sh` runs:

- **Exit 0**: Allow completion
- **Exit 2**: Prevent completion + send feedback

Checks:
- No TODO/FIXME comments
- No placeholder code
- No console.log
- No debugger statements

## Logs

Agent Teams activity is logged to:
```
~/.ralph/logs/agent-teams.log
```

Example:
```
[2026-02-14 10:30:00] TeammateIdle: teammate-abc123 (ralph-coder)
[2026-02-14 10:30:00] TeammateIdle BLOCKED: console.log found in auth.ts
```

## Parallel Processing Patterns

### Parallel Research

Multiple researchers exploring different aspects:
```bash
Task(subagent_type="ralph-researcher", prompt="Research database patterns")
Task(subagent_type="ralph-researcher", prompt="Research API patterns")
Task(subagent_type="ralph-researcher", prompt="Research security patterns")
```

### Full Team Deployment

All teammates working on a feature:
```bash
TeamCreate(team_name="full-feature")
# Researcher finds patterns
# Coder implements
# Tester writes tests
# Reviewer validates
```

### Cascading Subagents

A teammate spawning its own subagents:
```
ralph-coder spawns:
  - Explore (find patterns)
  - Bash (run tests)
```

## References

- [Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Subagents Documentation](https://code.claude.com/docs/en/sub-agents)
- [Plan: Agent Teams Integration v2.85](../../.ralph/plans/agent-teams-integration-v2.85.md)
