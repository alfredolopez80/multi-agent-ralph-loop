# Multi-Agent Ralph - Agents Reference v2.84.3

## Overview

Ralph coordinates 14 specialized agents across different domains. Uses GLM-4.7 as primary model, GLM-5 for teammates, and supports multiprocessing for stability.

## Model Configuration

| Role | Model | Usage |
|------|-------|-------|
| Primary | GLM-4.7 | Main orchestration, code tasks |
| Teammate | GLM-5 | Parallel subtasks |
| Fallback | Claude | Complex reasoning |

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

## Tool Access

All agents have access to:
- Read/Write/Edit files
- Bash commands
- Glob/Grep search
- WebFetch/WebSearch
- NotebookEdit (for Jupyter)

Restricted tools (main agent only):
- Task (spawning agents)
- ExitPlanMode

## Usage Examples

```python
# Spawn a Bash agent
Task("git commit", agent="Bash")

# Spawn an Explore agent for quick search
Task("find API endpoints", agent="Explore", mode="quick")

# Spawn Plan agent for architecture
Task("design auth system", agent="Plan")
```

## Spawn Parameters

| Parameter | Values | Description |
|-----------|--------|-------------|
| `mode` | quick, medium, thorough | Search depth for Explore |
| `resume` | agent_id | Resume interrupted agent |

## Agent Selection Guide

- **Quick file search** → Explore (quick mode)
- **Code change** → Bash or Edit directly
- **Architecture design** → Plan
- **Research task** → General-purpose
- **SDK verification** → agent-sdk-verifier-*
