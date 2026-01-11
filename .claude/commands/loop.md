---
name: loop
prefix: "@loop"
category: orchestration
color: purple
description: "Ralph Loop pattern for iterative execution until VERIFIED_DONE"
argument-hint: "<task> [--mmc]"
---

# /loop - Ralph Loop Pattern (v2.25)

Execute tasks iteratively with automatic quality validation until VERIFIED_DONE signal.

## Overview

The Ralph Loop is a **continuous execution pattern** that iterates through EXECUTE → VALIDATE → QUALITY CHECK cycles until the task passes all quality gates or reaches the iteration limit.

```
┌─────────────────────────────────────────────────────────────────┐
│                    RALPH LOOP PATTERN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌──────────┐    ┌──────────────┐    ┌─────────────────┐      │
│   │ EXECUTE  │───▶│   VALIDATE   │───▶│ Quality Passed? │      │
│   │   Task   │    │ (hooks/gates)│    └────────┬────────┘      │
│   └──────────┘    └──────────────┘             │               │
│                                          NO ◀──┴──▶ YES        │
│                                           │         │          │
│                          ┌────────────────┘         │          │
│                          ▼                          ▼          │
│                   ┌─────────────┐          ┌──────────────┐    │
│                   │  ITERATE    │          │ VERIFIED_DONE│    │
│                   │ (max 15/30) │          │   (output)   │    │
│                   └──────┬──────┘          └──────────────┘    │
│                          │                                     │
│                          └──────────▶ Back to EXECUTE          │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## When to Use

Use `/loop` when:

1. **Iterative refinement needed** - Code requires multiple passes to meet quality standards
2. **Quality gates must pass** - TypeScript, ESLint, tests, linting must all pass
3. **Automated validation** - Let the loop handle retries automatically
4. **Complex implementations** - Multi-file changes that need coordination
5. **Research tasks** - Gathering information until complete

**DO NOT use** for:
- Simple one-shot tasks (use direct claude call)
- Tasks already in orchestration flow (redundant)
- Spec refinement workflows (use /adversarial)

## Iteration Limits

Different models have different iteration capacities based on efficiency analysis:

| Model | Max Iterations | Cost vs Claude | Quality | Use Case |
|-------|----------------|----------------|---------|----------|
| Claude (Sonnet/Opus) | **15** | 100% (baseline) | 85-90% SWE-bench | Complex reasoning, high accuracy |
| MiniMax M2.1 | **30** | ~8% | 74% SWE-bench | Standard tasks (2x multiplier) |
| MiniMax-lightning | **60** | ~5% | ~65% SWE-bench | Extended tasks (4x multiplier) |

**Why different limits?**
- **Claude models** require fewer iterations due to superior reasoning per iteration
- **MiniMax models** compensate with 2-4x more iterations at drastically lower cost
- **Quality threshold** remains consistent across models

## Model Selection

### Default Mode (Claude)

```bash
ralph loop "implement OAuth2 authentication"
```

Uses Claude Sonnet with **15 iteration limit**:
- Best for: Complex features, security-critical code, architectural changes
- Cost: Standard Claude pricing
- Quality: 85%+ SWE-bench accuracy

### MiniMax Mode (--mmc flag)

```bash
ralph loop --mmc "implement OAuth2 authentication"
```

Uses MiniMax M2.1 with **30 iteration limit**:
- Best for: Standard features, refactoring, testing, documentation
- Cost: ~8% of Claude cost
- Quality: 74% SWE-bench accuracy (comparable to GPT-4)

**When to use --mmc?**
- Non-critical features
- Exploratory research (1M context window)
- Large-scale refactoring (cost-effective for many iterations)
- Second opinion validation

## CLI Execution

### Basic Usage

```bash
# Claude mode (15 iterations)
ralph loop "implement user authentication with JWT"

# MiniMax mode (30 iterations)
ralph loop --mmc "refactor database queries to use TypeORM"

# Complex task with specific requirements
ralph loop "add rate limiting to API endpoints with Redis"
```

### With Quality Gates

```bash
# Loop automatically integrates with quality gates
ralph loop "migrate from Jest to Vitest" && ralph gates

# Gates run WITHIN each iteration
# No need to call gates separately
```

### Output Location

```bash
# Logs saved to ~/.ralph/logs/
ls ~/.ralph/logs/loop-*.log

# View last loop execution
tail -f ~/.ralph/logs/loop-latest.log
```

## Task Tool Invocation

When using the Task tool directly (for advanced users):

```yaml
# Claude mode (Sonnet manages execution)
Task:
  subagent_type: "general-purpose"
  model: "sonnet"  # MANDATORY - Haiku causes infinite retries
  run_in_background: true
  max_iterations: 15  # Claude limit
  description: "Primary task execution with loop"
  prompt: |
    Execute the following task iteratively until VERIFIED_DONE:

    Task: [TASK_DESCRIPTION]

    Loop pattern:
    1. EXECUTE - Implement the task
    2. VALIDATE - Run quality gates (tsc, eslint, tests)
    3. CHECK - Did all gates pass?
       - YES → VERIFIED_DONE
       - NO → ITERATE (max 15)

    Output: Final implementation + quality report

# MiniMax mode (Sonnet manages MiniMax call)
Task:
  subagent_type: "minimax-executor"
  model: "sonnet"  # Sonnet MANAGES the mmc call
  run_in_background: true
  max_iterations: 30  # MiniMax limit
  description: "MiniMax loop execution"
  prompt: |
    Execute via MiniMax CLI with extended iterations:

    mmc --loop 30 "Task: [TASK_DESCRIPTION]

    Apply Ralph Loop pattern with 30 iteration limit.
    Run quality gates after each iteration.
    Stop at VERIFIED_DONE or max iterations."
```

## Quality Gates Integration

The loop **automatically integrates** with quality gates at each iteration:

### Per-Iteration Checks

After each EXECUTE phase, the following run automatically:

| Language | Tools | What They Check |
|----------|-------|-----------------|
| TypeScript/JavaScript | `tsc`, `eslint` | Type errors, linting violations |
| Python | `pyright`, `ruff` | Type hints, style issues |
| Go | `go build`, `staticcheck` | Compilation, static analysis |
| Rust | `cargo check` | Compilation errors |
| Solidity | `forge build`, `solhint` | Smart contract issues |
| Swift | `swiftlint` | Swift style issues |
| JSON | `jq` | JSON syntax |
| YAML | `yamllint` | YAML formatting |

### Quality Gate Hooks

```bash
# Post-Edit/Write hooks (automatic)
~/.ralph/hooks/quality-gates.sh

# Example iteration flow:
Iteration 1: EXECUTE → tsc failed (3 errors) → ITERATE
Iteration 2: EXECUTE → tsc passed, eslint failed (2 warnings) → ITERATE
Iteration 3: EXECUTE → all gates passed → VERIFIED_DONE
```

### Manual Quality Check

```bash
# Force quality gate run (diagnostic)
ralph gates

# View last gate results
cat ~/.ralph/logs/quality-gates.log
```

## Output Format

The loop produces structured output at each iteration:

### Console Output

```
╔══════════════════════════════════════════════════════════════╗
║               Ralph Loop Execution (Claude Mode)             ║
╠══════════════════════════════════════════════════════════════╣
║ Task: implement OAuth2 authentication                        ║
║ Model: claude-sonnet-4-5                                     ║
║ Max Iterations: 15                                           ║
╚══════════════════════════════════════════════════════════════╝

[Iteration 1/15]
├─ EXECUTE: Creating auth routes...
├─ VALIDATE: Running quality gates...
│  ├─ tsc: ✗ 3 type errors
│  ├─ eslint: ✗ 2 warnings
└─ STATUS: Quality gates failed, iterating...

[Iteration 2/15]
├─ EXECUTE: Fixing type errors...
├─ VALIDATE: Running quality gates...
│  ├─ tsc: ✓ passed
│  ├─ eslint: ✗ 1 warning
└─ STATUS: Quality gates failed, iterating...

[Iteration 3/15]
├─ EXECUTE: Fixing eslint warnings...
├─ VALIDATE: Running quality gates...
│  ├─ tsc: ✓ passed
│  ├─ eslint: ✓ passed
│  ├─ tests: ✓ 12/12 passed
└─ STATUS: VERIFIED_DONE ✓

╔══════════════════════════════════════════════════════════════╗
║                    Execution Summary                         ║
╠══════════════════════════════════════════════════════════════╣
║ Total Iterations: 3/15                                       ║
║ Quality Gates: PASSED                                        ║
║ Files Modified: 4                                            ║
║ Tests Added: 12                                              ║
║ Duration: 2m 34s                                             ║
╚══════════════════════════════════════════════════════════════╝
```

### Log File Format

```json
{
  "task": "implement OAuth2 authentication",
  "model": "claude-sonnet-4-5",
  "max_iterations": 15,
  "iterations": [
    {
      "number": 1,
      "execute": {
        "files_modified": ["src/auth/routes.ts", "src/auth/middleware.ts"],
        "duration_ms": 15234
      },
      "validate": {
        "tsc": {"status": "failed", "errors": 3},
        "eslint": {"status": "failed", "warnings": 2}
      },
      "status": "iterating"
    },
    {
      "number": 2,
      "execute": {
        "files_modified": ["src/auth/routes.ts"],
        "duration_ms": 8123
      },
      "validate": {
        "tsc": {"status": "passed"},
        "eslint": {"status": "failed", "warnings": 1}
      },
      "status": "iterating"
    },
    {
      "number": 3,
      "execute": {
        "files_modified": ["src/auth/middleware.ts"],
        "duration_ms": 5892
      },
      "validate": {
        "tsc": {"status": "passed"},
        "eslint": {"status": "passed"},
        "tests": {"status": "passed", "total": 12, "passed": 12}
      },
      "status": "verified_done"
    }
  ],
  "summary": {
    "total_iterations": 3,
    "max_iterations": 15,
    "final_status": "verified_done",
    "total_duration_ms": 29249,
    "files_modified": 4,
    "tests_added": 12
  }
}
```

## Advanced Usage

### Loop with Specific Model

```bash
# Force Opus for critical tasks
IMPLEMENTATION_MODEL=opus ralph loop "security audit fixes"

# Force MiniMax lightning for extended iterations
ralph loop --mmc --model lightning "large refactoring"
```

### Loop with Custom Iteration Limit

```bash
# Override default limits (use with caution)
MAX_ITERATIONS=20 ralph loop "complex feature"
```

### Loop in Orchestration Context

```bash
# Loop is Step 4 in orchestration flow
ralph orch "implement feature"
# Internally calls:
# 1. /clarify
# 2. /classify
# 3. Plan approval
# 4. /loop (automatic)
# 5. /gates (automatic within loop)
# 6. /adversarial (spec refinement if complexity >= 7)
# 7. /retrospective
```

## Integration with Worktree Workflow

```bash
# Create worktree and run loop inside it
ralph worktree "implement feature" && \
cd ~/.ralph/worktrees/feature-branch && \
ralph loop "implement feature"

# Loop respects worktree isolation
# All edits happen in worktree, not main branch
```

## Error Handling

### Max Iterations Reached

```
[Iteration 15/15]
├─ EXECUTE: Attempting final fixes...
├─ VALIDATE: Running quality gates...
│  ├─ tsc: ✗ 1 type error remaining
└─ STATUS: MAX_ITERATIONS reached

╔══════════════════════════════════════════════════════════════╗
║                      Loop Failed                             ║
╠══════════════════════════════════════════════════════════════╣
║ Reason: Max iterations (15) reached without passing gates   ║
║ Last Error: tsc - Cannot find name 'User'                   ║
║ Suggestion: Review implementation and try again              ║
╚══════════════════════════════════════════════════════════════╝
```

**Recovery options:**
1. Review the last iteration's errors manually
2. Increase iteration limit (if justified)
3. Switch to MiniMax mode for more iterations at lower cost
4. Break task into smaller subtasks

### Quality Gate Failure

```
[Iteration 8/15]
├─ EXECUTE: Implementation complete
├─ VALIDATE: Running quality gates...
│  ├─ tsc: ✓ passed
│  ├─ eslint: ✓ passed
│  ├─ tests: ✗ 2/14 failed
│  │  └─ AuthService.test.ts: "should validate JWT token" FAILED
│  │  └─ AuthService.test.ts: "should refresh expired token" FAILED
└─ STATUS: Tests failing, iterating...
```

**Loop automatically:**
1. Analyzes test failures
2. Fixes implementation
3. Re-runs tests
4. Continues until all pass

## Related Commands

### Orchestration Commands
- `/orchestrator` - Full 8-step workflow (includes loop at Step 4)
- `/adversarial` - Adversarial spec refinement (after loop completes)
- `/retrospective` - Post-loop self-improvement analysis

### Quality Commands
- `/gates` - Manual quality gate execution
- `/security` - Security-specific validation
- `/full-review` - Comprehensive code review

### Parallel Execution
- `/parallel` - Run multiple loops concurrently
- `/bugs` - Loop focused on bug hunting
- `/refactor` - Loop focused on refactoring

## CLI Alternative

```bash
# Direct CLI calls
ralph loop "task"                    # Claude mode
ralph loop --mmc "task"              # MiniMax mode
ralph loop --model opus "task"       # Force Opus
ralph loop --max-iter 20 "task"      # Custom limit

# Shorthand aliases
rhl "task"                           # ralph loop
rhl --mmc "task"                     # ralph loop --mmc
```

## Best Practices

1. **Start with Claude mode** for complex/critical tasks
2. **Use MiniMax mode** for cost-effective iterations on standard tasks
3. **Let the loop run** - don't interrupt unless necessary
4. **Review logs** if max iterations reached
5. **Break down large tasks** if loop consistently fails
6. **Trust quality gates** - they're designed to catch issues
7. **Use worktrees** for feature development to isolate changes

## Performance Tips

| Scenario | Recommendation |
|----------|----------------|
| Simple refactoring | MiniMax mode (30 iterations, 8% cost) |
| Security-critical code | Claude Opus (15 iterations, max quality) |
| Large codebase changes | MiniMax lightning (60 iterations, extended) |
| Tight deadlines | Claude Sonnet (15 iterations, balanced) |
| Exploratory research | MiniMax M2.1 (1M context, 30 iterations) |

## Troubleshooting

### Loop Gets Stuck

```bash
# Check current iteration
tail -f ~/.ralph/logs/loop-latest.log

# Kill stuck loop
pkill -f "ralph loop"

# Review what went wrong
cat ~/.ralph/logs/loop-*.log | jq '.iterations[-1]'
```

### Quality Gates Always Fail

```bash
# Run gates manually to diagnose
ralph gates

# Check specific tool
tsc --noEmit
eslint src/

# Fix configuration issues before looping
```

### Out of Memory

```bash
# Reduce iteration limit
MAX_ITERATIONS=10 ralph loop "task"

# Use MiniMax for better memory efficiency
ralph loop --mmc "task"
```

## Examples

### Example 1: Implement Feature

```bash
ralph loop "add user profile editing with validation"
```

Output:
- Iteration 1-3: Implement routes, controllers, validation
- Iteration 4-6: Fix TypeScript errors, add tests
- Iteration 7-8: Pass all quality gates
- VERIFIED_DONE at iteration 8/15

### Example 2: Large Refactoring (MiniMax)

```bash
ralph loop --mmc "refactor all API routes to use async/await"
```

Output:
- Iteration 1-10: Convert routes in batches
- Iteration 11-20: Fix type errors and linting
- Iteration 21-25: Update tests
- Iteration 26-28: All gates pass
- VERIFIED_DONE at iteration 28/30

### Example 3: Security Fix (Opus)

```bash
IMPLEMENTATION_MODEL=opus ralph loop "fix SQL injection in user search"
```

Output:
- Iteration 1-2: Implement parameterized queries
- Iteration 3-4: Add input validation
- Iteration 5-6: Security tests pass
- VERIFIED_DONE at iteration 6/15
