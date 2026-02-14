---
# VERSION: 2.88.0
name: parallel
description: "Run multiple Ralph loops concurrently for independent tasks. Manages parallel agent execution with proper isolation and result aggregation. Use when: (1) multiple independent fixes needed, (2) parallel reviews required, (3) batch processing tasks. Triggers: /parallel, 'parallel loops', 'concurrent execution', 'run in parallel', 'batch'."
context: fork
user-invocable: true
allowed-tools:
  - Task
  - TaskOutput
  - Read
  - Edit
  - Write
  - Bash
---

# Parallel - Concurrent Execution (v2.88)

Run multiple Ralph loops concurrently for independent tasks.

## v2.88 Key Changes (MODEL-AGNOSTIC)

- **Model-agnostic**: Uses model configured in `~/.claude/settings.json` or CLI/env vars
- **No flags required**: All parallel tasks use the configured default model
- **Flexible**: Works with GLM-5, Claude, Minimax, or any configured model
- **Settings-driven**: Model selection via `ANTHROPIC_DEFAULT_*_MODEL` env vars

## Agent Teams Integration (v2.88)

**Optimal Scenario**: Integrated (Agent Teams + Custom Subagents)

Parallel execution combines Agent Teams coordination with ralph-coder specialization for optimal parallel file processing.

### Why Scenario C for Parallel Execution
- Multiple files require coordinated distribution
- Quality gates essential for result validation
- Specialized ralph-coder agents for implementation
- Shared task list tracks all parallel work

### Automatic Team Creation

When the parallel skill is invoked, automatically create a team:

```yaml
# Automatically create team on skill invocation
TeamCreate:
  team_name: "parallel-execution-{timestamp}"
  description: "Parallel execution of independent tasks"
```

### Spawning Parallel Agents

Create multiple ralph-coder instances for parallel tasks:

```yaml
# Spawn 3 parallel ralph-coder agents
Task:
  subagent_type: "ralph-coder"
  team_name: "parallel-execution-{timestamp}"
  prompt: "Fix auth errors in src/auth/"

Task:
  subagent_type: "ralph-coder"
  team_name: "parallel-execution-{timestamp}"
  prompt: "Fix API errors in src/api/"

Task:
  subagent_type: "ralph-coder"
  team_name: "parallel-execution-{timestamp}"
  prompt: "Fix UI errors in src/ui/"
```

### Task Coordination Pattern

Use the shared task list for coordination:

```yaml
# Create master task list
TaskCreate:
  subject: "Parallel fixes batch"
  description: "Execute auth, API, and UI fixes in parallel"

# Create subtasks with dependencies
TaskCreate:
  subject: "Fix auth errors"
  activeForm: "Fixing auth errors"

TaskCreate:
  subject: "Fix API errors"
  activeForm: "Fixing API errors"

TaskCreate:
  subject: "Fix UI errors"
  activeForm: "Fixing UI errors"
```

### Quality Gates

Quality validation via Agent Teams hooks:

| Hook | Purpose | Behavior |
|------|---------|----------|
| `TeammateIdle` | Pre-idle validation | Keep working + feedback if issues found |
| `TaskCompleted` | Pre-completion validation | Block completion + feedback if issues found |

Quality standards enforced:
1. **CORRECTNESS**: Valid syntax, sound logic
2. **QUALITY**: No console.log, proper types, no TODOs
3. **SECURITY**: No hardcoded secrets, proper validation
4. **CONSISTENCY**: Follow project style guides

### Result Aggregation

After all parallel agents complete:

```yaml
# Aggregate results
TaskUpdate:
  taskId: "<master-task>"
  status: "completed"

# Report summary
- All subtasks completed
- Quality gates passed
- Changes ready for commit
```

## Quick Start

```bash
/parallel "fix auth errors" "fix api errors" "fix ui errors"
ralph parallel task1 task2 task3
```

## When to Use

### Good for Parallel
- Independent file changes
- Multiple module fixes
- Batch reviews
- Different analysis types

### Must Be Sequential
- Dependent changes
- Same file modifications
- Order-dependent operations
- Shared state changes

## Workflow

### 1. Create Team and Spawn Agents

```yaml
# Auto-create team for coordination
TeamCreate:
  team_name: "parallel-{task-name}"
  description: "Parallel execution of {task-name}"

# Launch multiple ralph-coder background agents
Task:
  subagent_type: "ralph-coder"
  team_name: "parallel-{task-name}"
  prompt: "Execute task 1"

Task:
  subagent_type: "ralph-coder"
  team_name: "parallel-{task-name}"
  prompt: "Execute task 2"

Task:
  subagent_type: "ralph-coder"
  team_name: "parallel-{task-name}"
  prompt: "Execute task 3"
```

### 2. Monitor Progress

```yaml
# Check task list for all subtask status
TaskList:
  # Returns all tasks with status, owner, blockedBy

# Monitor specific subtask
TaskGet:
  taskId: "<subtask-id>"
```

### 3. Aggregate Results

```yaml
# Mark master task as completed
TaskUpdate:
  taskId: "<master-task>"
  status: "completed"

# Report summary
- All subtasks completed
- Quality gates passed
- Changes ready for commit
```

## Parallel Patterns

### Review Pattern
```bash
# Parallel reviews with different focus
/parallel "security review src/" "performance review src/" "quality review src/"
```

### Fix Pattern
```bash
# Parallel fixes for different modules
/parallel "fix auth errors" "fix api errors" "fix db errors"
```

### Analysis Pattern
```bash
# Parallel analysis tasks
/parallel "analyze complexity" "analyze coverage" "analyze dependencies"
```

## Isolation

Each parallel task runs with:
- Separate context (`context: fork`)
- Independent iteration counter
- Own quality gates
- Isolated file access

## Result Aggregation

### All Succeed
- Aggregate changes
- Run global gates
- VERIFIED_DONE

### Partial Success
- Report failures
- Keep successful changes
- Retry failed tasks

### All Fail
- Report all errors
- Analyze patterns
- Sequential retry

## Integration

- Used for independent sub-tasks
- Each parallel task follows Ralph Loop
- Results feed back to orchestrator

## Anti-Patterns

- Never run parallel on same files
- Never exceed 5 concurrent agents
- Never ignore partial failures
- Never skip aggregation step
