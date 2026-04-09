---
name: task-classifier
version: 3.1.0
description: Classifies task complexity (1-10) for model and agent routing
user_invocable: false
---

# Task Classifier

Classifies task complexity (1-10) to route to the correct model and agent.

## Complexity Scale

| Level | Description | Model | Agent |
|-------|-------------|-------|-------|
| 1-2 | Trivial (typos, renames, single-line fixes) | GLM-4.7 | Direct (no team) |
| 3-4 | Simple (single function, known pattern) | GLM-5 | ralph-coder |
| 5-6 | Moderate (multi-file, some unknowns) | Claude Sonnet | ralph-coder + ralph-tester |
| 7-8 | Complex (architecture, security-sensitive) | Claude Opus | ralph-coder + ralph-reviewer + ralph-security |
| 9-10 | Critical (system redesign, multi-agent coordination) | Claude Opus | Full team (6 agents) |

## Classification Criteria

### Complexity 1-2 (Trivial)
- Single file change
- Known pattern with no unknowns
- No tests needed
- No security implications

### Complexity 3-4 (Simple)
- 1-2 files to modify
- Standard patterns apply
- Tests recommended but not required
- No architectural decisions

### Complexity 5-6 (Moderate)
- 3+ files to modify
- Some unknown patterns
- Tests required
- Minor architectural decisions
- Frontend OR backend (not both)

### Complexity 7-8 (Complex)
- 5+ files across multiple domains
- Significant unknowns
- Security-sensitive code
- Architectural decisions required
- Frontend AND backend changes

### Complexity 9-10 (Critical)
- System-wide changes
- Multi-agent coordination needed
- Security architecture decisions
- Breaking changes
- Performance-critical paths

## Model Routing

| Complexity | Default Model | Fallback |
|-----------|---------------|----------|
| 1-4 | GLM-4.7 / GLM-5 | Claude Haiku |
| 5-6 | Claude Sonnet | GLM-5 |
| 7-10 | Claude Opus | Claude Sonnet |

## Agent Routing

| Complexity | Required Agents | Optional |
|-----------|----------------|----------|
| 1-2 | None (direct execution) | - |
| 3-4 | ralph-coder | ralph-tester |
| 5-6 | ralph-coder + ralph-tester | ralph-reviewer |
| 7-8 | ralph-coder + ralph-tester + ralph-security | ralph-frontend |
| 9-10 | All 6 agents (coder, reviewer, tester, researcher, frontend, security) | - |

## Execution Mode

| Complexity | Plan Mode | Agent Teams | Aristotle |
|-----------|-----------|-------------|-----------|
| 1-3 | No | No | Quick |
| 4-6 | Recommended | Yes | Quick |
| 7-10 | Mandatory | Mandatory | Full 5-phase |

## Usage

Invoke this skill to classify a task before execution:

```
/task-classifier "Add user authentication to the API"
```

The skill will output:
- Complexity level (1-10)
- Recommended model
- Required agents
- Execution mode

## Integration

This skill integrates with:
- `/orchestrator` - Uses classification for routing
- Agent Teams - Spawns appropriate teammates
- Model routing - Selects correct model per complexity
