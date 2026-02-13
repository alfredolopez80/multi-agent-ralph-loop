---
name: glm5
prefix: "@glm5"
category: orchestration
color: purple
description: GLM-5 Agent Teams - Spawn teammates with thinking mode
---

# GLM-5 Agent Teams

<!-- VERSION: 2.84.0 -->

Spawn GLM-5 powered teammates with native thinking mode for parallel execution.

## Usage

```bash
/glm5 <role> <task>
/glm5 coder "Implement authentication"
/glm5 reviewer "Review auth.ts"
/glm5 tester "Generate tests for login"
```

## Roles

| Role | Description |
|------|-------------|
| `coder` | Implementation, refactoring, bug fixes |
| `reviewer` | Code review, security analysis |
| `tester` | Test generation, coverage |
| `planner` | Architecture, design |
| `researcher` | Documentation, exploration |

## Examples

### Spawn Single Teammate
```
/glm5 coder "Implement JWT authentication with refresh tokens"
```

### Spawn Multiple Teammates
```
/glm5 parallel "Implement OAuth2" --teammates coder,reviewer,tester
```

### Check Team Status
```
/glm5 status
```

## Execution Pattern

1. Initialize team with unique ID
2. Call GLM-5 API with thinking enabled
3. Capture reasoning to `.ralph/reasoning/`
4. Write status to `.ralph/teammates/`
5. Fire native hooks (SubagentStop)

## Files Created

- `.ralph/teammates/{task_id}/status.json` - Teammate status
- `.ralph/reasoning/{task_id}.txt` - GLM-5 reasoning
- `.ralph/logs/teammates.log` - Activity log

## Integration

This command integrates with:
- `/orchestrator` - For complex multi-step tasks
- `/parallel` - For parallel teammate execution
- `/gates` - For quality validation

---

## Implementation

Execute the following based on arguments:

**Arguments**: $ARGUMENTS

**If ARGUMENTS contains "status":**
```bash
cat .ralph/team-status.json
tail -20 .ralph/logs/teammates.log
```

**If ARGUMENTS contains "parallel":**
- Parse teammates from `--teammates` flag
- Spawn each teammate in parallel using Bash &
- Wait for all to complete
- Aggregate results

**Otherwise (single teammate):**
```bash
# Parse role and task from ARGUMENTS
ROLE=<first word of ARGUMENTS>
TASK=<rest of ARGUMENTS>
TASK_ID="task-$(date +%s)"

# Execute teammate
.claude/scripts/glm5-teammate.sh "$ROLE" "$TASK" "$TASK_ID"

# Show result location
echo ""
echo "Status: .ralph/teammates/${TASK_ID}/status.json"
echo "Reasoning: .ralph/reasoning/${TASK_ID}.txt"
```
