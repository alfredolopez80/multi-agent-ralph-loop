---
# VERSION: 2.87.0
name: glm5-parallel
description: Spawn multiple GLM-5 teammates in parallel for comprehensive analysis
allowed-tools:
  - Bash
  - Read
  - Write
  - Task
---

# GLM-5 Parallel Skill

Spawn multiple GLM-5 teammates in parallel for comprehensive task execution.

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
