---
# VERSION: 2.88.0
name: loop
description: "Ralph Loop pattern with swarm mode: iterative execution until VERIFIED_DONE with multi-agent coordination. Use when: (1) iterative refinement needed, (2) quality gates must pass, (3) automated validation required. Triggers: /loop, 'loop until done', 'iterate', 'keep trying', 'fix until passing'."
argument-hint: "<task>"
user-invocable: true
context: fork
agent: general-purpose
allowed-tools:
  - Task
  - Read
  - Edit
  - Write
  - Bash
  - Glob
  - Grep
---

# /loop - Ralph Loop Pattern (v2.88)

Execute tasks iteratively with automatic quality validation until VERIFIED_DONE signal.

## v2.88 Key Changes (MODEL-AGNOSTIC)

- **Model-agnostic**: Uses model configured in `~/.claude/settings.json` or CLI/env vars
- **No flags required**: Iterations use the configured default model
- **Flexible**: Works with GLM-5, Claude, Minimax, or any configured model
- **Settings-driven**: Model selection via `ANTHROPIC_DEFAULT_*_MODEL` env vars

## v2.87 Key Changes (UNIFIED SKILLS MODEL)

- **Skills/Commands unification**: All commands now use SKILL.md format
- **Single source of truth**: Skills live in repo, symlinked globally
- **Version alignment**: All skills updated to v2.87.0
- **Documentation consolidated**: Architecture docs in `docs/architecture/`

## Overview

The Ralph Loop is a **continuous execution pattern** that iterates through EXECUTE -> VALIDATE -> QUALITY CHECK cycles until the task passes all quality gates or reaches the iteration limit.

```
+------------------------------------------------------------------+
|                    RALPH LOOP PATTERN                             |
+------------------------------------------------------------------+
|                                                                   |
|   +----------+    +--------------+    +-----------------+         |
|   | EXECUTE  |--->|   VALIDATE   |--->| Quality Passed? |         |
|   |   Task   |    | (hooks/gates)|    +--------+--------+         |
|   +----------+    +--------------+             |                  |
|                                          NO <--+--> YES           |
|                                           |         |             |
|                          +----------------+         |             |
|                          v                          v             |
|                   +------------+          +---------------+       |
|                   |  ITERATE   |          | VERIFIED_DONE |       |
|                   | (max 15/30)|          |   (output)    |       |
|                   +-----+------+          +---------------+       |
|                         |                                         |
|                         +----------> Back to EXECUTE              |
|                                                                   |
+------------------------------------------------------------------+
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

| Model | Max Iterations | Cost vs Claude | Quality | Use Case |
|-------|----------------|----------------|---------|----------|
| Claude (Sonnet/Opus) | **15** | 100% (baseline) | 85-90% SWE-bench | Complex reasoning, high accuracy |
| GLM-5 | **30** | ~10% | 80%+ SWE-bench | Standard tasks (2x multiplier) |
| MiniMax M2.1 | **30** | ~8% | 74% SWE-bench | Standard tasks (2x multiplier) |

## Model Selection

### Default Mode (Claude)

```bash
ralph loop "implement OAuth2 authentication"
```

Uses Claude Sonnet with **15 iteration limit**:
- Best for: Complex features, security-critical code, architectural changes
- Cost: Standard Claude pricing
- Quality: 85%+ SWE-bench accuracy

### GLM-5 Mode (--with-glm5 flag)

```bash
ralph loop "implement OAuth2 authentication" --with-glm5
```

Uses GLM-5 with **30 iteration limit**:
- Best for: Standard features, refactoring, testing, documentation
- Cost: ~10% of Claude cost
- Quality: 80%+ SWE-bench accuracy

### MiniMax Mode (--mmc flag)

```bash
ralph loop --mmc "implement OAuth2 authentication"
```

Uses MiniMax M2.1 with **30 iteration limit**:
- Best for: Non-critical features, exploratory research
- Cost: ~8% of Claude cost
- Quality: 74% SWE-bench accuracy

## CLI Execution

```bash
# Claude mode (15 iterations)
ralph loop "implement user authentication with JWT"

# GLM-5 mode (30 iterations)
ralph loop "refactor database queries" --with-glm5

# MiniMax mode (30 iterations)
ralph loop --mmc "refactor database queries to use TypeORM"

# Complex task with specific requirements
ralph loop "add rate limiting to API endpoints with Redis"
```

## Task Tool Invocation (Swarm Mode)

**IMPORTANT**: /loop uses swarm mode by default with full multi-agent coordination.

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  run_in_background: true
  max_iterations: 15
  description: "Loop execution with swarm mode"
  team_name: "loop-execution-team"
  name: "loop-lead"
  mode: "delegate"
  prompt: |
    Execute the following task iteratively until VERIFIED_DONE:

    Task: $ARGUMENTS

    Ralph Loop pattern:
    1. EXECUTE - Implement the task
    2. VALIDATE - Run quality gates (tsc, eslint, tests)
    3. CHECK - Did all gates pass?
       - YES -> VERIFIED_DONE
       - NO -> ITERATE (max 15)

    Output: Final implementation + quality report
```

## Team Composition (Auto-Spawned)

When /loop is invoked, it automatically spawns:

| Role | Purpose | Count |
|------|---------|-------|
| **Leader** | Loop coordinator | 1 |
| **Teammate 1** | Implementation specialist | 1 |
| **Teammate 2** | Quality validation specialist | 1 |
| **Teammate 3** | Test verification specialist | 1 |

**Total**: 4 agents working in parallel (1 leader + 3 teammates)

## Output Location

```bash
# Logs saved to ~/.ralph/logs/
ls ~/.ralph/logs/loop-*.log

# View last loop execution
tail -f ~/.ralph/logs/loop-latest.log
```

## Pattern Details

### Loop Structure

```bash
iteration=0
max_iterations=15  # or 30 for GLM-5/MiniMax

while [[ $iteration -lt $max_iterations ]]; do
    # Step 1: EXECUTE
    implement_task

    # Step 2: VALIDATE
    run_quality_gates  # tsc, eslint, tests, semgrep

    # Step 3: CHECK
    if all_gates_passed; then
        echo "VERIFIED_DONE"
        exit 0
    fi

    # Step 4: ITERATE
    ((iteration++))
    analyze_failures
    apply_fixes
done

# Max iterations reached without VERIFIED_DONE
exit 1
```

### Quality Gates Integration

Each iteration runs quality gates:

1. **TypeScript**: `tsc --noEmit`
2. **ESLint**: `eslint .`
3. **Tests**: `npm test` or `pytest`
4. **Security**: `semgrep --config=auto`
5. **Custom**: Project-specific gates

### Stop Hook Integration

The loop integrates with the Stop hook:

```bash
# Initialize state
.claude/scripts/ralph-state.sh init "$SESSION_ID" loop "$TASK"

# On VERIFIED_DONE
.claude/scripts/ralph-state.sh complete "$SESSION_ID" loop

# On failure
.claude/scripts/ralph-state.sh fail "$SESSION_ID" loop "$ERROR"
```

## Anti-Patterns

- Never use infinite loops (always set max_iterations)
- Never skip quality gates (defeats the purpose)
- Never use for one-shot tasks (use direct execution)
- Never nest loops (causes exponential iterations)

## Completion Criteria

`VERIFIED_DONE` requires ALL:
1. All quality gates passed
2. No TypeScript errors
3. No ESLint errors
4. Tests passing
5. Security scan clean (no P0/P1 findings)

## Related Skills

- `/orchestrator` - Full orchestration workflow
- `/gates` - Quality validation gates
- `/adversarial` - Spec refinement
- `/parallel` - Parallel subagent execution
- `/retrospective` - Post-task analysis

## References

- [Unified Architecture v2.87](docs/architecture/UNIFIED_ARCHITECTURE_v2.87.md)
- [Skills/Commands Unification](docs/architecture/SKILLS_COMMANDS_UNIFICATION_v2.87.md)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
