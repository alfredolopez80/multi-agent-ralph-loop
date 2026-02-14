# Multi-Agent Ralph - Agents Reference v2.88.0

## Overview

Ralph coordinates 46+ specialized agents across different domains. Uses GLM-5 as primary model for all tasks, with Agent Teams support for parallel execution.

## New in v2.88.0

### Batch Task Execution

New skills for autonomous multi-task execution:

| Skill | Purpose |
|-------|---------|
| `/task-batch` | Execute lists of tasks autonomously until all complete |
| `/create-task-batch` | Interactive wizard for creating PRDs with mandatory criteria |

**Key Features**:
- Handles MULTIPLE tasks per batch
- MANDATORY completion criteria per task
- VERIFIED_DONE validation guarantee
- Fresh context per task (avoids contamination)
- Auto-commit after each completed task
- Progress tracking via `batch-progress-tracker.sh` hook

## Model Configuration

| Role | Model | Usage |
|------|-------|-------|
| Primary | GLM-5 | Main orchestration, code tasks |
| Teammates | GLM-5 | Parallel subtasks via Agent Teams |
| Fallback | Claude | Complex reasoning (optional) |

## Agent Teams (v2.86)

Custom subagents for Agent Teams with GLM-5:

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

### GLM-5 Teammates

| Agent | Purpose |
|-------|---------|
| `glm5-coder` | Code implementation with thinking mode |
| `glm5-reviewer` | Code review with thinking mode |
| `glm5-tester` | Test generation with thinking mode |
| `glm5-orchestrator` | Task coordination |

## Usage Examples

```bash
# Spawn ralph-coder teammate
Task(subagent_type="ralph-coder", team_name="my-project")

# Spawn GLM-5 teammate for code
Task(subagent_type="glm5-coder", prompt="Implement feature X")
```

## Agent Selection Guide

- **Quick file search** → Explore (quick mode)
- **Code implementation** → ralph-coder or glm5-coder
- **Code review** → ralph-reviewer or glm5-reviewer
- **Testing** → ralph-tester or glm5-tester
- **Architecture design** → Plan
- **Research task** → General-purpose or ralph-researcher
