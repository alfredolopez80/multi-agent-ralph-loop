# Unified Architecture v2.88

**Date**: 2026-02-14
**Version**: v2.88.0
**Status**: CANONICAL REFERENCE

## Overview

Multi-Agent Ralph v2.88 introduces a **model-agnostic architecture** and **comprehensive hook integration** that ensures continuous execution until VERIFIED_DONE. This version eliminates hardcoded model flags and adds critical quality gates for subagent lifecycle management.

## Key Changes in v2.88

### 1. Model-Agnostic Architecture

**Before v2.88**:
```bash
/orchestrator "task" --with-glm5  # Required flag
/loop "task" --mmc                # Required flag
```

**After v2.88**:
```bash
/orchestrator "task"              # Uses configured model
/loop "task"                      # Uses configured model
```

**Configuration** (in `~/.claude/settings.json`):
```json
{
  "env": {
    "ANTHROPIC_DEFAULT_MODEL": "claude-sonnet-4-20250514",
    "ANTHROPIC_DEFAULT_SMALL_MODEL": "claude-3-5-haiku",
    "ANTHROPIC_DEFAULT_LARGE_MODEL": "claude-opus-4-6-20250514"
  }
}
```

### 2. Hook Integration Fixes (5 Findings)

Based on adversarial analysis, 5 critical gaps were identified and fixed:

| Finding | Severity | Description | Fix |
|---------|----------|-------------|-----|
| #1 | CRITICAL | Missing `ralph-subagent-stop.sh` | Created new hook |
| #2 | HIGH | Stop hook missing teammate state check | Added teammate verification |
| #3 | HIGH | No state update on hook blocking | Added block state tracking |
| #4 | MEDIUM | SubagentStart doesn't register state | Added state registration |
| #5 | MEDIUM | No cross-session state isolation | Added session validation |

### 3. Agent Teams Hook Integration

```
+------------------------------------------------------------------+
|                    AGENT TEAMS HOOK FLOW v2.88                    |
+------------------------------------------------------------------+
|                                                                   |
|   [SubagentStart]                                                |
|        |                                                          |
|        v                                                          |
|   ralph-subagent-start.sh                                         |
|   - Register state in ~/.ralph/state/{session}/subagents/        |
|   - Inject Ralph context                                          |
|        |                                                          |
|        v                                                          |
|   [Subagent executes task]                                        |
|        |                                                          |
|        v                                                          |
|   [SubagentStop]                                                  |
|        |                                                          |
|        v                                                          |
|   ralph-subagent-stop.sh (NEW in v2.88)                          |
|   - Check if task completed                                       |
|   - Block if incomplete                                           |
|        |                                                          |
|        v                                                          |
|   [TeammateIdle]                                                  |
|        |                                                          |
|        v                                                          |
|   teammate-idle-quality-gate.sh                                   |
|   - Quality check before idle                                     |
|        |                                                          |
|        v                                                          |
|   [Stop]                                                          |
|        |                                                          |
|        v                                                          |
|   ralph-stop-quality-gate.sh                                      |
|   - Teammate state verification (Finding #2)                     |
|   - Block state tracking (Finding #3)                            |
|   - Session isolation (Finding #5)                               |
|        |                                                          |
|        v                                                          |
|   [VERIFIED_DONE?]                                                |
|                                                                   |
+------------------------------------------------------------------+
```

## Core Components

```
+------------------------------------------------------------------+
|                    MULTI-AGENT RALPH v2.88                        |
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

**Frontmatter Standard (v2.88)**:
```yaml
---
# VERSION: 2.88.0
name: skill-name
description: "What this skill does and when to use it."
argument-hint: "<expected arguments>"
user-invocable: true
context: fork                  # Run in subagent (optional)
agent: agent-type              # Subagent type when context: fork
allowed-tools:                 # Tools allowed without asking
  - Read
  - Edit
  - Bash
---
```

**Note**: No `model:` field - model is inherited from settings.json

### 2. Hooks

**Definition**: Event-driven scripts that automate workflows around tool events.

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
| `SubagentStart` | Subagent starts | Context injection, state registration |
| `SubagentStop` | Subagent stops | Quality gates, completion validation |

### 3. Agents (Subagents)

**Definition**: Specialized agent configurations for delegated tasks.

**Location**: `.claude/agents/<agent-name>.md`

**Custom Agent Types (Ralph)**:

| Agent | Role | Tools | Model |
|-------|------|-------|-------|
| `ralph-coder` | Code implementation | Read, Edit, Write, Bash | Inherited |
| `ralph-reviewer` | Code review | Read, Grep, Glob | Inherited |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) | Inherited |
| `ralph-researcher` | Research | Read, Grep, Glob, WebSearch | Inherited |

**Agent Configuration Example**:
```yaml
---
name: ralph-coder
description: Specialized coding teammate
tools:
  - Read
  - Edit
  - Write
  - Bash(npm:*, git:*, python:*)
# Model is inherited from ~/.claude/settings.json (ANTHROPIC_DEFAULT_*_MODEL)
permissionMode: acceptEdits
maxTurns: 50
---
```

## Hook Integration Details

### Session Lifecycle

| Hook | Event | Purpose |
|------|-------|---------|
| `orchestrator-init.sh` | SessionStart | Initialize orchestrator state |
| `post-compact-restore.sh` | SessionStart(compact) | Restore after compaction |
| `session-end-handoff.sh` | SessionEnd | Save state on termination |
| `pre-compact-handoff.sh` | PreCompact | Save state before compaction |

### Quality Gates

| Hook | Event | Purpose |
|------|-------|---------|
| `git-safety-guard.py` | PreToolUse(Bash) | Block destructive commands |
| `repo-boundary-guard.sh` | PreToolUse(Bash) | Prevent work outside repo |
| `task-completed-quality-gate.sh` | TaskCompleted | Quality before completion |
| `teammate-idle-quality-gate.sh` | TeammateIdle | Quality before idle |

### Agent Teams Hooks (v2.88)

| Hook | Event | Purpose | Finding |
|------|-------|---------|---------|
| `ralph-subagent-start.sh` | SubagentStart | Context + state registration | #4 |
| `ralph-subagent-stop.sh` | SubagentStop | Quality gate for ralph-* | #1 |
| `ralph-stop-quality-gate.sh` | Stop | Teammate check, block tracking | #2, #3, #5 |

## Ralph Core Skills

### Primary Skills (v2.88)

| Skill | Version | Hook Integration | Purpose |
|-------|---------|-----------------|---------|
| `/orchestrator` | 2.88.0 | SessionStart, Stop | Full workflow orchestration |
| `/loop` | 2.88.0 | PreToolUse, PostToolUse | Iterative execution |
| `/parallel` | 2.88.0 | Task | Parallel subagent execution |
| `/gates` | 2.87.0 | PostToolUse | Quality validation |
| `/adversarial` | 2.87.0 | SessionStart, Stop | Spec refinement |

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

### GLM-5 Specific Skills (Keep explicit model)

| Skill | Purpose |
|-------|---------|
| `/glm5` | GLM-5 agent teams with thinking mode |
| `/glm5-parallel` | GLM-5 parallel execution |

**Note**: These skills are for GLM-5 evaluation and testing, NOT for general use.

## Model Routing

| Complexity | Model | Cost | Use Case |
|------------|-------|------|----------|
| 1-4 | GLM-5 / glm-5 | ~10% | Fast execution |
| 5-6 | Claude Sonnet | 100% | Standard tasks |
| 7-10 | Claude Opus | 3x | Complex reasoning |

**Configuration via environment variables**:
```bash
export ANTHROPIC_DEFAULT_MODEL="claude-sonnet-4-20250514"
export ANTHROPIC_DEFAULT_SMALL_MODEL="claude-3-5-haiku"
export ANTHROPIC_DEFAULT_LARGE_MODEL="claude-opus-4-6-20250514"
```

## Memory System

```
~/.ralph/
├── state/                     # Session state (v2.88)
│   └── {session_id}/
│       ├── session.json       # Session metadata
│       ├── orchestrator.json  # Orchestrator state
│       ├── loop.json          # Loop state
│       ├── blocks.json        # Block tracking (Finding #3)
│       └── subagents/         # Subagent states (Finding #4)
│           └── {subagent_id}.json
├── memory/
│   └── semantic.json          # Semantic observations
├── episodes/                  # Episodic memories (24h TTL)
├── procedural/
│   └── rules.json             # Learned behaviors
├── ledgers/                   # Session continuity data
├── handoffs/                  # Session snapshots
├── plans/                     # Implementation plans
├── logs/                      # Activity logs
│   ├── stop-hook.log          # Stop hook activity
│   └── agent-teams.log        # Agent teams activity
└── teammates/                 # Agent teams status
```

## VERIFIED_DONE Conditions

The Stop hook (`ralph-stop-quality-gate.sh`) enforces:

1. **stop_hook_active check**: Prevents infinite loops
2. **Session validation**: Checks session age, cleans stale sessions
3. **Orchestrator state**: Checks `verified_done` flag
4. **Loop state**: Checks iteration status
5. **Team tasks**: Checks for pending tasks
6. **Teammate status** (Finding #2): Blocks if teammates working
7. **Quality gates**: Checks last gate result

## Test Coverage

### Hook Integration Tests

| Test File | Tests | Purpose |
|-----------|-------|---------|
| `test-hook-integration-v2.88.sh` | 15 | E2E hook integration |
| `test-model-agnostic-v2.88.sh` | 18 | Model-agnostic validation |
| `test-skills-unification-v2.87.sh` | 12 | Skills unification |

### Running Tests

```bash
# Hook integration tests
./tests/hook-integration/test-hook-integration-v2.88.sh -v

# Model-agnostic validation
./tests/unit/test-model-agnostic-v2.88.sh -v

# Pre-commit validation
.git-hooks/pre-commit
```

## File Structure (Canonical)

```
multi-agent-ralph-loop/
├── .claude/
│   ├── skills/                    # SOURCE OF TRUTH for Ralph skills
│   │   ├── orchestrator/
│   │   │   └── SKILL.md           # v2.88.0
│   │   ├── loop/
│   │   │   └── SKILL.md           # v2.88.0
│   │   ├── parallel/
│   │   │   └── SKILL.md           # v2.88.0
│   │   ├── gates/
│   │   ├── adversarial/
│   │   ├── glm5/                  # GLM-5 specific
│   │   └── ... (other skills)
│   ├── agents/                    # Subagent definitions
│   │   ├── ralph-coder.md         # Model inherited
│   │   ├── ralph-reviewer.md      # Model inherited
│   │   ├── ralph-tester.md        # Model inherited
│   │   └── ralph-researcher.md    # Model inherited
│   ├── hooks/                     # Hook scripts
│   │   ├── ralph-subagent-start.sh   # v2.88.0 (Finding #4)
│   │   ├── ralph-subagent-stop.sh    # v2.88.0 (Finding #1)
│   │   ├── ralph-stop-quality-gate.sh # v2.88.0 (Findings #2, #3, #5)
│   │   ├── git-safety-guard.py
│   │   └── ... (other hooks)
│   └── scripts/
│       └── ralph-state.sh         # State management utility
├── docs/
│   ├── architecture/              # Architecture documentation
│   │   ├── UNIFIED_ARCHITECTURE_v2.88.md
│   │   ├── ADVERSARIAL_HOOK_INTEGRATION_ANALYSIS_v2.88.md
│   │   └── ... (other docs)
│   └── analysis/
├── tests/
│   ├── hook-integration/
│   │   └── test-hook-integration-v2.88.sh
│   ├── unit/
│   │   ├── test-model-agnostic-v2.88.sh
│   │   └── test-skills-unification-v2.87.sh
│   └── stop-hook/
└── .git-hooks/
    └── pre-commit                 # v2.87.0 with Phase 7 & 8
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
| v2.87 | 2026-02 | Skills/Commands unification |
| **v2.88** | **2026-02** | **Model-agnostic, Hook Integration (5 findings)** |

## References

- [Adversarial Analysis v2.88](./ADVERSARIAL_HOOK_INTEGRATION_ANALYSIS_v2.88.md)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [Claude Code Hooks Documentation](https://code.claude.com/docs/en/hooks)
- [Claude Code Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)
- [Agent Skills Open Standard](https://github.com/anthropics/agent-skills)
