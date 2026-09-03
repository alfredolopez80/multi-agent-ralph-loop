# Multi-Agent Ralph - Agents Reference v2.89.2

## Overview

Ralph coordinates 46+ specialized agents across different domains. Agents inherit the session model; Agent Teams provides parallel execution.

## Changes in v2.89.2

- Hooks aligned with official Claude Code hooks guide (exit codes, field names)
- `TeammateIdle` and `TaskCompleted` hooks use exit codes + stderr instead of JSON stdout
- `SubagentStart` uses official field names (`agent_id`, `agent_type`) with fallbacks
- 29 security vulnerabilities fixed across v2.89.1 and v2.89.2
- 37 automated security tests

## Batch Task Execution (v2.88)

| Skill | Purpose |
|-------|---------|
| `/task-batch` | Execute lists of tasks autonomously until all complete |
| `/create-task-batch` | Interactive wizard for creating PRDs with mandatory criteria |

Features: multiple tasks per batch, mandatory completion criteria, VERIFIED_DONE validation, fresh context per task, auto-commit after each task, progress tracking via `batch-progress-tracker.sh`

## Model Configuration

No complexity-based routing. The authoritative policy is `~/.claude/CLAUDE.md`
-> "Model Routing": whatever model the session runs handles the task; the user decides
with `/model` or by naming a model expressly. Agents inherit it and must NOT pin a
model in their frontmatter.

Complexity thresholds drive PROCESS -- Plan Mode >= 4, Parallel-First >= 3,
Plan Mode >= 4 -- never model choice.

## Agent Teams (v2.86)

Custom subagents for Agent Teams (they inherit the session model):

| Agent | Role | Tools | Max Turns |
|-------|------|-------|-----------|
| `ralph-coder` | Code implementation | Read, Edit, Write, Bash | 50 |
| `ralph-reviewer` | Code review | Read, Grep, Glob | 25 |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) | 30 |
| `ralph-researcher` | Research | Read, Grep, Glob, WebSearch | 20 |

## Agent Directory

### Core Agents

| Agent | Role | Capabilities |
|-------|------|--------------|
| **Bash** | Command execution | Git, terminal, system commands |
| **Explore** | Code exploration | Search, glob, grep, file analysis |
| **Plan** | Architecture | Design plans, step-by-step implementation |
| **General-purpose** | Multi-task | Research, complex tasks |

### Specialist Agents

| Agent | Specialization |
|-------|----------------|
| **claude-code-guide** | Claude Code CLI documentation |
| **agent-sdk-verifier-ts** | TypeScript SDK verification |
| **agent-sdk-verifier-py** | Python SDK verification |
| **statusline-setup** | Status line configuration |

## Usage Examples

```bash
# Spawn ralph-coder teammate
Task(subagent_type="ralph-coder", team_name="my-project")

# Spawn a reviewer alongside it
Task(subagent_type="ralph-reviewer", team_name="my-project")
```

## Agent Selection Guide

- **Quick file search** → Explore (quick mode)
- **Code implementation** → ralph-coder
- **Code review** → ralph-reviewer
- **Testing** → ralph-tester
- **Architecture design** → Plan
- **Research task** → General-purpose or ralph-researcher
