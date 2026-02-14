# Unified Architecture v2.87

**Date**: 2026-02-14
**Version**: v2.87.0
**Status**: CANONICAL REFERENCE

## Overview

Multi-Agent Ralph v2.87 introduces a **unified skills model** that consolidates hooks, agents, and skills/commands into a coherent system following Claude Code best practices.

## Core Components

```
+------------------------------------------------------------------+
|                    MULTI-AGENT RALPH v2.87                        |
+------------------------------------------------------------------+
|                                                                   |
|  +-------------+     +-------------+     +------------------+    |
|  |   HOOKS     |---->|   SKILLS    |---->|     AGENTS       |    |
|  |  (Events)   |     | (Commands)  |     |  (Subagents)     |    |
|  +-------------+     +-------------+     +------------------+    |
|        |                   |                      |               |
|        v                   v                      v               |
|  +----------------------------------------------------------+    |
|  |                    ORCHESTRATION                          |    |
|  |  evaluate -> clarify -> classify -> plan -> execute ->   |    |
|  |                    validate -> retrospective              |    |
|  +----------------------------------------------------------+    |
|                                                                   |
+------------------------------------------------------------------+
```

## Component Definitions

### 1. Skills (formerly Commands)

**Definition**: Reusable instruction sets that extend Claude's capabilities.

**Location**:
- **Project (repo)**: `.claude/skills/<skill-name>/SKILL.md`
- **Personal (global)**: `~/.claude/skills/<skill-name>/SKILL.md`

**Structure**:
```
skill-name/
├── SKILL.md           # Required: Main instructions with frontmatter
├── references/        # Optional: Reference documentation
├── examples/          # Optional: Example files
└── scripts/           # Optional: Utility scripts
```

**Frontmatter Standard**:
```yaml
---
# VERSION: 2.87.0
name: skill-name
description: "What this skill does and when to use it."
argument-hint: "<expected arguments>"
user-invocable: true           # Show in / menu
disable-model-invocation: false # Claude can auto-invoke
context: fork                  # Run in subagent (optional)
agent: agent-type              # Subagent type when context: fork
allowed-tools:                 # Tools allowed without asking
  - Read
  - Edit
  - Bash(safe-command *)
---
```

**Priority**: enterprise > personal > project

### 2. Hooks

**Definition**: Event-driven scripts that automate workflows around tool events.

**Location**: `.claude/hooks/<hook-name>.sh` or `.js`

**Event Types**:

| Event | When | Use Case |
|-------|------|----------|
| `SessionStart` | Session begins | Initialize state, load context |
| `PreToolUse` | Before tool call | Validation, safety checks |
| `PostToolUse` | After tool call | Status updates, logging |
| `UserPromptSubmit` | User submits prompt | Periodic tasks |
| `Stop` | Session ends | Cleanup, reporting |
| `TeammateIdle` | Teammate goes idle | Quality gates |
| `TaskCompleted` | Task marked complete | Quality gates |
| `SubagentStart` | Subagent starts | Context injection |
| `SubagentStop` | Subagent stops | Quality gates |

**Hook Registration** (in `~/.claude/settings.json`):
```json
{
  "hooks": {
    "SessionStart": [
      { "path": "~/.claude/hooks/orchestrator-init.sh", "once": true }
    ],
    "PreToolUse": [
      { "event": "Bash", "path": "~/.claude/hooks/git-safety-guard.py" }
    ]
  }
}
```

### 3. Agents (Subagents)

**Definition**: Specialized agent configurations for delegated tasks.

**Location**: `.claude/agents/<agent-name>.md`

**Structure**:
```markdown
# Agent Name

## Role
Description of what this agent does.

## Tools
- Read
- Edit
- Bash

## Model
sonnet

## Skills
- skill-1
- skill-2
```

**Built-in Agent Types**:
- `general-purpose`: Default subagent
- `Explore`: Read-only codebase exploration
- `Plan`: Planning and architecture

**Custom Agent Types** (Ralph):
- `ralph-coder`: Code implementation with quality gates
- `ralph-reviewer`: Code review (security, quality)
- `ralph-tester`: Unit and integration testing
- `ralph-researcher`: Codebase research

## Integration Flow

### Skill with Hooks Integration

```
User invokes /orchestrator "task"
         |
         v
+------------------+
| SKILL.md loaded  |  <-- description determines auto-invoke
+------------------+
         |
         v
+------------------+     +------------------+
| PreToolUse hooks |---->| Smart memory     |
| (if context:fork)|     | search, etc.     |
+------------------+     +------------------+
         |
         v
+------------------+
| Skill executes   |  <-- Instructions from SKILL.md
| with allowed     |
| tools            |
+------------------+
         |
         v
+------------------+     +------------------+
| PostToolUse hooks|---->| Status updates,  |
|                  |     | pattern capture  |
+------------------+     +------------------+
         |
         v
+------------------+
| Stop hooks       |  <-- Session/report generation
+------------------+
```

### Agent Teams Workflow

```
/orchestrator "complex task" --with-glm5
         |
         v
+------------------+
| TeamCreate       |  <-- Creates "orchestration-team"
+------------------+
         |
         v
+------------------+
| TaskCreate       |  <-- Creates task list
| (multiple tasks) |
+------------------+
         |
    +----+----+----+
    |    |    |    |
    v    v    v    v
+-----+ +-----+ +-----+
|coder| |revwr| |tester|
| GLM | | GLM | | GLM |
+-----+ +-----+ +-----+
    |    |    |    |
    +----+----+----+
         |
         v
+------------------+
| TaskUpdate       |  <-- Mark completed
+------------------+
         |
         v
+------------------+
| TeamDelete       |  <-- Cleanup
+------------------+
```

## Ralph Core Skills

### Primary Skills

| Skill | Hook Integration | Agent Type | Purpose |
|-------|-----------------|------------|---------|
| `/orchestrator` | SessionStart, PreToolUse, PostToolUse, Stop | orchestrator | Full workflow orchestration |
| `/loop` | PreToolUse, PostToolUse | general-purpose | Iterative execution |
| `/gates` | PostToolUse | - | Quality validation |
| `/adversarial` | SessionStart, Stop | - | Spec refinement |
| `/parallel` | PreToolUse | - | Parallel subagent execution |

### Secondary Skills

| Skill | Purpose |
|-------|---------|
| `/clarify` | Requirement clarification |
| `/security` | Security audit with CodeQL/Semgrep |
| `/bugs` | Bug hunting with Codex CLI |
| `/smart-fork` | Find relevant past sessions |
| `/task-classifier` | 3D complexity classification |
| `/curator` | Repository curation |
| `/retrospective` | Post-task analysis |

### Integration Skills

| Skill | Purpose |
|-------|---------|
| `/glm5` | GLM-5 agent integration |
| `/glm5-parallel` | GLM-5 parallel execution |
| `/codex-cli` | OpenAI Codex CLI orchestration |
| `/minimax` | MiniMax M2.1 integration |

## Critical Hooks

### Session Lifecycle

| Hook | Event | Purpose |
|------|-------|---------|
| `orchestrator-init.sh` | SessionStart | Initialize orchestrator state |
| `session-start-auto-learn.sh` | SessionStart | Trigger learning if needed |
| `post-compact-restore.sh` | SessionStart(compact) | Restore after compaction |
| `session-end-handoff.sh` | SessionEnd | Save state on termination |
| `pre-compact-handoff.sh` | PreCompact | Save state before compaction |

### Quality Gates

| Hook | Event | Purpose |
|------|-------|---------|
| `git-safety-guard.py` | PreToolUse(Bash) | Block destructive commands |
| `repo-boundary-guard.sh` | PreToolUse(Bash) | Prevent work outside repo |
| `learning-gate.sh` | PreToolUse(Task) | Auto-learning trigger |
| `task-completed-quality-gate.sh` | TaskCompleted | Quality before completion |
| `teammate-idle-quality-gate.sh` | TeammateIdle | Quality before idle |

### Agent Teams

| Hook | Event | Purpose |
|------|-------|---------|
| `ralph-subagent-start.sh` | SubagentStart | Initialize ralph-* subagents |
| `glm5-subagent-stop.sh` | SubagentStop | Quality gate for glm5-* |

## Model Routing

| Complexity | Model | Use Case |
|------------|-------|----------|
| 1-4 | GLM-4.7 / glm-5 | Fast execution |
| 5-6 | Claude Sonnet | Standard tasks |
| 7-10 | Claude Opus | Complex reasoning |

## Memory System

```
~/.ralph/
├── memory/
│   └── semantic.json        # Semantic observations
├── episodes/                 # Episodic memories (24h TTL)
├── procedural/
│   └── rules.json           # Learned behaviors
├── ledgers/                  # Session continuity data
├── handoffs/                 # Session snapshots
├── plans/                    # Implementation plans
├── checkpoints/              # Smart checkpoints
└── teammates/                # Agent teams status
```

## File Structure (Canonical)

```
multi-agent-ralph-loop/
├── .claude/
│   ├── skills/                    # SOURCE OF TRUTH for Ralph skills
│   │   ├── orchestrator/
│   │   │   ├── SKILL.md           # v2.87.0
│   │   │   └── references/
│   │   ├── loop/
│   │   │   └── SKILL.md
│   │   ├── gates/
│   │   ├── adversarial/
│   │   └── ... (other skills)
│   ├── agents/                    # Subagent definitions
│   │   ├── ralph-coder.md
│   │   ├── ralph-reviewer.md
│   │   ├── ralph-tester.md
│   │   └── ralph-researcher.md
│   ├── hooks/                     # Hook scripts
│   │   ├── orchestrator-init.sh
│   │   ├── git-safety-guard.py
│   │   └── ... (other hooks)
│   └── commands/                  # DEPRECATED: Use skills/
│       └── (empty or symlinks)
├── docs/
│   └── architecture/              # Architecture documentation
├── tests/
│   └── ...                        # Test files
└── CLAUDE.md                      # Project instructions

~/.claude/
├── skills/
│   ├── orchestrator -> /path/to/repo/.claude/skills/orchestrator
│   ├── loop -> /path/to/repo/.claude/skills/loop
│   └── ... (symlinks to repo skills)
├── commands/                      # Optional backward compat
│   └── ... (symlinks or empty)
└── settings.json                  # Hook and agent registration
```

## Symlink Strategy

### Why Symlinks?

1. **Single source of truth**: Changes in repo automatically reflect globally
2. **Version control**: Skills are tracked in git
3. **Portability**: Other machines can clone and use immediately
4. **No duplication**: Avoid version drift between locations

### Symlink Commands

```bash
# Create symlinks for Ralph skills
REPO_PATH="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"

for skill in orchestrator loop gates adversarial parallel retrospective clarify security bugs smart-fork task-classifier curator glm5 glm5-parallel; do
    ln -sf "$REPO_PATH/.claude/skills/$skill" "$HOME/.claude/skills/$skill"
done
```

## Version History

| Version | Date | Key Changes |
|---------|------|-------------|
| v2.45 | 2025-12 | Initial hooks integration |
| v2.46 | 2025-12 | RLM-inspired routing |
| v2.47 | 2025-12 | Smart memory search |
| v2.50 | 2026-01 | Repo learning |
| v2.51 | 2026-01 | Checkpoint system, event engine |
| v2.52 | 2026-01 | Status auto-check |
| v2.55 | 2026-01 | Auto-learning, curator |
| v2.56 | 2026-01 | Smart checkpoint |
| v2.57 | 2026-01 | Memory reconstruction |
| v2.81 | 2026-01 | Swarm mode integration |
| v2.84 | 2026-02 | GLM-5 Agent Teams |
| v2.86 | 2026-02 | Security hooks, Agent Teams hooks |
| v2.87 | 2026-02 | **Skills/Commands unification, canonical architecture** |

## References

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
- [Claude Code Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Agent Skills Open Standard](https://github.com/anthropics/agent-skills)
