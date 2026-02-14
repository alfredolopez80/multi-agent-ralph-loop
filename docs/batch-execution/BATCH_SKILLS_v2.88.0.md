# Batch Task Execution System v2.88.0

**Date**: 2026-02-15
**Version**: 2.88.0
**Status**: IMPLEMENTED

## Overview

The Batch Task Execution System provides autonomous execution of multiple tasks with PRD parsing, automatic task decomposition, and completion validation. It consists of two complementary skills:

1. **`/task-batch`** - Autonomous executor for task lists
2. **`/create-task-batch`** - Interactive wizard for creating PRDs

## Architecture

```
+------------------------------------------------------------------+
|                    BATCH EXECUTION SYSTEM                         |
+------------------------------------------------------------------+
|                                                                   |
|   /create-task-batch           →           /task-batch            |
|   (Interactive Wizard)                     (Autonomous Executor)  |
|                                                                   |
|   ┌─────────────────┐           ┌─────────────────────────────┐  |
|   │ 1. Gather       │           │ 1. Parse Input              │  |
|   │ 2. Decompose    │  ──────►  │ 2. Prioritize               │  |
|   │ 3. Prioritize   │   PRD     │ 3. Execute Loop             │  |
|   │ 4. Validate     │   File    │ 4. Validate Each Task       │  |
|   │ 5. Output PRD   │           │ 5. Auto-commit              │  |
|   └─────────────────┘           └─────────────────────────────┘  |
|                                                                   |
+------------------------------------------------------------------+
```

## Skills

### /task-batch

**Purpose**: Execute lists of tasks autonomously until ALL complete or critical failure.

**Key Features**:
- Handles MULTIPLE tasks (not single task)
- Fresh context per task execution
- VERIFIED_DONE validation per task
- Auto-commit after each completed task
- Intelligent rate limit handling
- Agent Teams integration (ralph-coder, ralph-reviewer, ralph-tester)

**Usage**:
```bash
# From PRD file
/task-batch docs/prd/feature-x.prq.md

# From task list
/task-batch tasks/sprint-backlog.md

# Inline tasks
/task-batch "Add auth; Implement profile; Add password reset"

# With priority ordering
/task-batch tasks/features.md --priority
```

**Stop Conditions**:
| Condition | Action |
|-----------|--------|
| All tasks VERIFIED_DONE | STOP - Output summary |
| No internet | STOP - Save state |
| Token limit reached | STOP - Report position |
| System crash | STOP - Emergency save |
| Max iterations | STOP - Safety limit |
| Normal questions | CONTINUE - Queue for later |

### /create-task-batch

**Purpose**: Interactive wizard to create PRDs with MANDATORY completion criteria per task.

**Key Features**:
- Uses /clarify and AskUserQuestion for precision
- MANDATORY completion criteria for each task
- Automatic task decomposition
- Priority and dependency identification
- Multiple output formats (PRD, tasks.md, JSON)

**Questioning Phases**:
1. **PROJECT CONTEXT** - Goal, area, timeframe
2. **FEATURE DETAILS** - Description, must-haves, nice-to-haves
3. **TASK DECOMPOSITION** - Break into atomic tasks
4. **PRIORITY & DEPENDENCIES** - Order and relationships
5. **ACCEPTANCE CRITERIA** - MANDATORY validation per task

**Usage**:
```bash
# Interactive mode
/create-task-batch

# With initial description
/create-task-batch "User authentication feature"

# Output format selection
/create-task-batch --format json
```

## Task Completion Criteria

**CRITICAL**: Every task MUST have explicit completion validation criteria.

### Criteria Template

```yaml
task:
  id: "task-001"
  description: "Create OAuth2 service module"
  priority: 1
  completion_criteria:  # MANDATORY
    - criteria: "File src/auth/oauth2.service.ts exists"
      verification: "file_exists"
    - criteria: "Google OAuth client configured"
      verification: "code_contains"
      pattern: "GoogleAuthProvider"
    - criteria: "Unit tests pass"
      verification: "command"
      command: "npm test -- oauth2.service.spec.ts"
```

### Verification Types

| Type | Description | Example |
|------|-------------|---------|
| `file_exists` | File/directory exists | `src/auth/oauth2.ts` |
| `code_contains` | Code contains pattern | `GoogleAuthProvider` |
| `command` | Command succeeds | `npm test` |
| `manual_review` | Human approval required | Code review |

## PRD File Format

```markdown
# Feature: {FEATURE_NAME}

**Created**: {TIMESTAMP}
**Version**: 2.88
**Timeframe**: {TIMEFRAME}

## Priority: {HIGH|MEDIUM|LOW}

## Overview
{DESCRIPTION}

## Tasks

- [ ] P1: {task_description}
- [ ] P1: {task_description}
- [ ] P2: {task_description}
- [ ] P3: {task_description}

## Dependencies
- P2 tasks depend on P1 tasks completion

## Acceptance Criteria

### {Task Name}
- Criteria 1
- Criteria 2
- Criteria 3

## Technical Notes
{NOTES}

## Risks
- Risk 1
- Risk 2

## Config
```yaml
stop_on_failure: false
auto_commit: true
teammates: [coder, reviewer, tester]
```
```

## Agent Teams Integration

### Team Creation

```yaml
# Automatic on /task-batch invocation
TeamCreate:
  team_name: "task-batch-{timestamp}"
  description: "Batch execution: {batch_name}"
```

### Teammate Spawning

```yaml
# Spawn specialized teammates
Task:
  subagent_type: "ralph-coder"
  team_name: "task-batch-{timestamp}"

Task:
  subagent_type: "ralph-reviewer"
  team_name: "task-batch-{timestamp}"
```

### Quality Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `teammate-idle-quality-gate.sh` | TeammateIdle | Quality check before idle |
| `task-completed-quality-gate.sh` | TaskCompleted | Validate before completion |
| `batch-progress-tracker.sh` | PostToolUse | Track progress + Exit 2 if tasks remain |

## Hook: batch-progress-tracker.sh

**Purpose**: Track batch execution progress and force continuation when tasks remain.

**Exit Codes**:
- `0` - All tasks complete, allow idle
- `2` - Tasks remain, force continuation

**Progress File**: `~/.ralph/batch/{batch_id}/progress.json`

```json
{
  "batch_id": "batch-20260215-123456",
  "total_tasks": 10,
  "completed": 5,
  "failed": 1,
  "current_task": "task-006",
  "tasks": [
    {"id": "task-001", "status": "completed"},
    {"id": "task-002", "status": "completed"}
  ]
}
```

## Test Suite

### Unit Tests

| Test File | Tests | Purpose |
|-----------|-------|---------|
| `test-task-batch.sh` | 12 | Validate /task-batch skill |
| `test-create-task-batch.sh` | 13 | Validate /create-task-batch skill |

### Integration Tests

| Test File | Tests | Purpose |
|-----------|-------|---------|
| `test-batch-skills-integration.sh` | 10 | Cross-skill validation |

### Pre-Commit Hook

File: `.claude/hooks/pre-commit-batch-skills-test.sh`

Runs all batch skill tests automatically before commit when skills are modified.

## Example PRD

See: `docs/prd/example-feature.prq.md`

## Research Sources

This implementation is based on research from:

| Source | Pattern Incorporated |
|--------|---------------------|
| [Sugar](https://github.com/roboticforce/sugar) | 24/7 autonomous operation, task queue |
| [Daedalus/Talos](https://github.com/internet-development/daedalus) | Dependency resolution, daemon pattern |
| [Continuous Autonomous Task Loop](https://agentic-patterns.com/patterns/continuous-autonomous-task-loop-pattern/) | Fresh context per iteration, rate limit handling |
| [claude-queue](https://github.com/vasiliyk/claude-queue) | Priority-based scheduling |

## Files Created

| File | Purpose |
|------|---------|
| `.claude/skills/task-batch/SKILL.md` | /task-batch skill definition |
| `.claude/skills/create-task-batch/SKILL.md` | /create-task-batch skill definition |
| `.claude/hooks/batch-progress-tracker.sh` | Progress tracking hook |
| `.claude/hooks/pre-commit-batch-skills-test.sh` | Pre-commit validation |
| `tests/skills/test-task-batch.sh` | Unit tests for /task-batch |
| `tests/skills/test-create-task-batch.sh` | Unit tests for /create-task-batch |
| `tests/skills/test-batch-skills-integration.sh` | Integration tests |
| `docs/prd/example-feature.prq.md` | Example PRD file |

## Workflow

```bash
# 1. Create batch with wizard
/create-task-batch "User Authentication Feature"

# 2. Answer questions for each task
# - Criteria, verification, files affected

# 3. Review generated PRD
cat docs/prd/user-authentication-feature.prq.md

# 4. Execute batch
/task-batch docs/prd/user-authentication-feature.prq.md --priority

# 5. Monitor progress
# Automatic via batch-progress-tracker.sh hook

# 6. All tasks complete → VERIFIED_DONE
```

## References

- [Unified Architecture v2.88](../architecture/UNIFIED_ARCHITECTURE_v2.88.md)
- [Agent Teams Documentation](../agent-teams/)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
