---
# VERSION: 2.88.0
name: glm5-parallel
description: Model-agnostic parallel execution with Agent Teams coordination
allowed-tools:
  - Bash
  - Read
  - Write
  - Task
  - TaskCreate
  - TaskList
  - TaskGet
  - TaskUpdate
  - TeamCreate
  - SendMessage
---

# GLM-5 Parallel Skill

Model-agnostic parallel execution with Agent Teams coordination for comprehensive task execution.

> **Note**: Despite the name, this skill is model-agnostic as of v2.88.0. It works with any model configured in Agent Teams.

## Usage

```
/glm5-parallel <task> [--roles coder,reviewer,tester]
```

## Example

```
/glm5-parallel "Implement OAuth2 authentication" --roles coder,reviewer,tester
```

This spawns 3 teammates:
1. **coder** - Implements OAuth2
2. **reviewer** - Reviews the implementation
3. **tester** - Generates tests

## Execution Pattern

```bash
# Generate task ID
TASK_ID="parallel-$(date +%s)"

# Parse roles
ROLES="coder,reviewer,tester"

# Spawn in parallel
for ROLE in $(echo $ROLES | tr ',' ' '); do
    .claude/scripts/glm5-teammate.sh "$ROLE" "<task>" "${TASK_ID}-${ROLE}" &
done

# Wait for all
wait

# Aggregate results
for ROLE in $(echo $ROLES | tr ',' ' '); do
    echo "=== $ROLE ==="
    cat .ralph/teammates/${TASK_ID}-${ROLE}/status.json | jq '.output_summary'
done
```

## Default Roles

If no `--roles` specified:
- `coder` - Implementation
- `reviewer` - Code review
- `tester` - Test generation

## Output

Creates parallel status files:
- `.ralph/teammates/{task_id}-coder/status.json`
- `.ralph/teammates/{task_id}-reviewer/status.json`
- `.ralph/teammates/{task_id}-tester/status.json`

Aggregated in `.ralph/team-status.json`

## Agent Teams Integration (v2.88)

As of v2.88.0, this skill integrates with Claude Code's Agent Teams system for robust parallel execution.

### Team Creation

Automatically creates an Agent Team at skill invocation:

```bash
TeamCreate(team_name="glm5-parallel-{timestamp}", description="Parallel GLM-5 execution for: {task}")
```

### Teammate Spawning

Spawns multiple `ralph-coder` instances configured for parallel work:

```javascript
// For each file or subtask
Task(
  subagent_type="ralph-coder",
  team_name="glm5-parallel-{timestamp}",
  input={
    task: "Specific subtask for this teammate",
    files: ["list_of_files_for_this_teammate"]
  }
)
```

### Task Coordination

Uses shared task list for coordination:

```javascript
// Create master task
TaskCreate({
  subject: "Parallel execution: {task}",
  description: "Full task description"
})

// Create subtasks for each teammate
TaskCreate({
  subject: "Subtask 1: {specific_task}",
  description: "Detailed subtask",
  metadata: { assigned_to: "teammate_1", files: [...] }
})

// Track completion via TaskList
TaskList()
```

### Quality Gates

Leverages Agent Teams hooks for quality validation:

| Hook | Purpose |
|------|---------|
| `TeammateIdle` | Runs quality gates when each teammate finishes |
| `TaskCompleted` | Final validation before marking subtask complete |
| `SubagentStop` | Quality check when teammate terminates |

### VERIFIED_DONE Guarantee

Each parallel task achieves VERIFIED_DONE status through:

1. **CORRECTNESS**: Syntax validation via teammate-idle-quality-gate.sh
2. **QUALITY**: Type checking and console.log detection
3. **SECURITY**: Secret scanning via sanitize-secrets hook
4. **CONSISTENCY**: Linting and format validation

### Multi-File Parallel Pattern

For tasks involving multiple files:

```javascript
// File groupings for parallel execution
const fileGroups = [
  ["src/auth/*.ts"],           // Group 1: Auth files
  ["src/api/*.ts"],            // Group 2: API files
  ["src/utils/*.ts"]           // Group 3: Utils
];

// Spawn teammate per group
fileGroups.forEach((group, index) => {
  Task(
    subagent_type="ralph-coder",
    team_name=`glm5-parallel-${Date.now()}`,
    input={
      task: "Apply changes to: " + group.join(", "),
      files: group
    }
  );
});
```

### Model Configuration

While named `glm5-parallel`, the skill is model-agnostic:

- Uses `ralph-coder` subagent type
- Actual model determined by Agent Teams routing
- Default: GLM-4.7 / glm-5 (complexity 1-4)
- Fallback: Claude Sonnet (complexity 5-6), Opus (7-10)

### Completion Signal

Team lead waits for all teammates to signal completion:

```javascript
// Via SendMessage for coordination
SendMessage({
  type: "message",
  recipient: "team-lead",
  content: "VERIFIED_DONE: Subtask {n} completed with all quality gates passed"
});
```
