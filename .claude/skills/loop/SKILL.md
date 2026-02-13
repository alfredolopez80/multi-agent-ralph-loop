---
# VERSION: 2.43.0
name: loop
description: "Execute task with Ralph Loop pattern: Execute -> Validate -> Iterate until VERIFIED_DONE. Enforces iteration limits per model (Claude: 25, MiniMax: 50, MiniMax-lightning: 100). Use when: (1) iterative fixes needed, (2) running until quality passes, (3) automated task completion. Triggers: /loop, 'loop until done', 'iterate', 'keep trying', 'fix until passing'."
user-invocable: true
---

# Loop - Ralph Loop Pattern

Execute -> Validate -> Iterate until VERIFIED_DONE.

## Quick Start

```bash
/loop "fix all type errors"
/loop "implement tests until 80% coverage"
ralph loop "fix lint errors"

# With GLM-5 teammates for faster execution
/loop "fix all type errors" --with-glm5
/loop "refactor auth module" --with-glm5 --teammates coder,reviewer
```

## Pattern

```
     EXECUTE
        |
        v
    +---------+
    | VALIDATE |
    +---------+
        |
   Quality    YES    +---------------+
   Passed? --------> | VERIFIED_DONE |
        |            +---------------+
        | NO
        v
    +---------+
    | ITERATE | (max iterations)
    +---------+
        |
        +-------> Back to EXECUTE
```

## Iteration Limits

| Model | Max Iterations | Use Case |
|-------|----------------|----------|
| Claude (Sonnet/Opus) | 25 | Complex reasoning |
| MiniMax M2.1 | 50 | Standard tasks |
| MiniMax-lightning | 100 | Extended loops |

## Workflow

### 1. Execute Task
```yaml
# Attempt implementation
Edit/Write/Bash as needed
```

### 2. Validate
```yaml
# Run quality gates
ralph gates
```

### 3. Check & Iterate
```yaml
# If validation fails and under limit
iteration += 1
if iteration <= MAX:
    continue  # Back to Execute
else:
    report "Max iterations reached"
```

## Loop Types

### Fix Loop
```bash
/loop "fix all type errors"
```
Repeatedly fix errors until build passes.

### Coverage Loop
```bash
/loop "increase test coverage to 80%"
```
Add tests until coverage target met.

### Lint Loop
```bash
/loop "fix all lint warnings"
```
Fix lint issues until clean.

### Build Loop
```bash
/loop "fix build errors"
```
Fix compilation errors until success.

## Exit Conditions

### Success (VERIFIED_DONE)
- Quality gates pass
- Tests pass
- No remaining errors

### Failure (MAX_ITERATIONS)
- Iteration limit reached
- Report remaining issues
- Ask user for guidance

### Manual Exit
- User interrupts
- Critical error detected
- Deadlock detected

## Integration

- Core pattern for all Ralph tasks
- Used by /orchestrator in Step 5
- Hooks enforce limits automatically

## Anti-Patterns

- Never exceed iteration limits
- Never loop without validation step
- Never ignore failing tests
- Never loop on same error repeatedly (detect deadlock)

## GLM-5 Integration (--with-glm5)

Spawn GLM-5 teammates for faster parallel execution.

### Usage

```bash
# Basic GLM-5 loop
/loop "fix all type errors" --with-glm5

# With specific teammates
/loop "refactor auth module" --with-glm5 --teammates coder,reviewer

# Extended loop with all teammates
/loop "implement full test suite" --with-glm5 --teammates coder,reviewer,tester
```

### Available Teammates

| Teammate | Role | Best For |
|----------|------|----------|
| `coder` | Implementation | Writing code, fixing bugs |
| `reviewer` | Code Review | Quality checks, patterns |
| `tester` | Test Generation | Unit tests, coverage |
| `orchestrator` | Coordination | Complex multi-step tasks |

### How It Works

1. **Spawn Teammates**: GLM-5 teammates spawned via `.claude/scripts/glm5-teammate.sh`
2. **Parallel Execution**: Each iteration uses GLM-5 for faster processing
3. **Hook Integration**: `glm5-subagent-stop.sh` handles teammate completion
4. **Storage**: Results stored in `.ralph/teammates/` and `.ralph/reasoning/`

### Benefits

- **Speed**: 2-3x faster than sequential execution
- **Thinking Mode**: GLM-5 provides reasoning for each step
- **Cost Effective**: Lower cost than Claude for repetitive tasks
- **Parallelization**: Multiple teammates work simultaneously

### Example Session

```
User: /loop "fix all lint errors" --with-glm5

[Iteration 1/25]
🤖 GLM-5 coder: Analyzing lint errors...
   Found 12 errors in 5 files
   Fixed: src/auth.ts, src/user.ts

[Iteration 2/25]
🤖 GLM-5 coder: Checking remaining errors...
   Found 3 errors in 2 files
   Fixed: src/utils.ts

[Validation]
✅ All lint errors fixed
✅ VERIFIED_DONE
```

### Bash Commands

```bash
# Spawn GLM-5 teammate
.claude/scripts/glm5-teammate.sh coder "Fix lint errors" "loop-fix-1"

# Check teammate status
cat .ralph/teammates/loop-fix-1/status.json

# View reasoning
cat .ralph/reasoning/loop-fix-1.txt
```

