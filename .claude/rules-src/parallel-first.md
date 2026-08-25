# Parallel-First Execution Rule

## Mandate

**All independent tasks MUST be executed in parallel using Agent Teams.** Sequential execution of independent work requires explicit justification.

## When Parallelism is REQUIRED

| Scenario | Action | Example |
|---|---|---|
| 2+ independent files to modify | Spawn parallel ralph-coder agents | Feature touching auth + UI |
| Code + tests needed | ralph-coder + ralph-tester in parallel | Any implementation task |
| Review + security audit | ralph-reviewer + ralph-security in parallel | Pre-merge validation |
| Research + implementation | ralph-researcher + ralph-coder in parallel | New feature with unknowns |
| Frontend + backend changes | ralph-frontend + ralph-coder in parallel | Full-stack features |
| Multiple quality checks | quality-gates-parallel (4 agents) | Post-implementation |

## When Sequential is ALLOWED

Only when tasks have **true data dependencies**:

- Step B reads output of Step A (not just "related to" — actually reads the output)
- Same file must be modified by both tasks (conflict risk)
- Order-dependent operations (migrations, schema changes)
- Shared mutable state with no isolation mechanism

## Agent Teams Usage Priority

**Every task with complexity >= 3 MUST use Agent Teams:**

```yaml
# REQUIRED pattern for non-trivial tasks
TeamCreate:
  team_name: "{skill}-{task-hash}"
  description: "{task description}"

# Spawn teammates in PARALLEL (not sequential)
Task:
  subagent_type: "ralph-coder"
  team_name: "{team}"
  run_in_background: true

Task:
  subagent_type: "ralph-tester"
  team_name: "{team}"
  run_in_background: true
```

**Complexity 1-2 (trivial)**: Direct execution without Agent Teams is acceptable.
**Complexity 3+**: Agent Teams with parallel teammates is MANDATORY.

## Teammate Selection Matrix

| Task Contains | MUST Spawn | In Parallel With |
|---|---|---|
| Code changes | ralph-coder | ralph-tester |
| UI/frontend | ralph-frontend | ralph-coder |
| Security-sensitive code | ralph-security | ralph-coder |
| Unknown patterns | ralph-researcher | ralph-coder (after research) |
| Review needed | ralph-reviewer | ralph-tester |

## Anti-Rationalization

| Agent Excuse | Rebuttal |
|---|---|
| "Sequential is simpler to implement" | Simplicity is not a license to ignore parallelization. Agent Teams handles coordination. |
| "These tasks might have hidden dependencies" | Prove the dependency exists. Run dependency analysis before claiming sequential is needed. |
| "I'll parallelize in the next iteration" | Next iteration may never come. Parallelize NOW. |
| "Parallel adds coordination overhead" | Agent Teams hooks (TeammateIdle, TaskCompleted) handle coordination automatically. Overhead < sequential delay. |
| "It's faster to do it myself sequentially" | Faster for you != faster for the user. Parallel execution reduces wall-clock time. |
| "The task is too small for parallelism" | If complexity >= 3, it's not too small. Use Agent Teams. |
| "I already started sequentially" | Stop. Create the team. Spawn teammates. Resume in parallel. |
| "Only one file needs changing" | Check: does the task also need tests? Review? Security check? Those are parallel opportunities. |

## Validation

VERIFIED_DONE for any task with complexity >= 3 requires:
1. Agent Teams was used (TeamCreate invoked)
2. At least 2 teammates were spawned
3. Independent work was executed in parallel (not sequential)
4. Results were aggregated from all teammates
5. Quality gates passed for all parallel outputs

## Exceptions

The ONLY valid exception is when the user explicitly requests sequential execution. Document the exception as:
```
PARALLEL_EXCEPTION: User requested sequential execution for [reason]
```
