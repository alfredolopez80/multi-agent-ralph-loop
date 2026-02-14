---
# VERSION: 2.87.0
name: orchestrator
description: "Full orchestration workflow with swarm mode: evaluate -> clarify -> classify -> persist -> plan mode -> spawn teammates -> execute -> validate -> retrospective. Use when: (1) implementing features, (2) complex refactoring, (3) multi-file changes, (4) tasks requiring coordination. Triggers: /orchestrator, /orch, 'orchestrate', 'full workflow', 'implement feature'."
argument-hint: "<task description> [--with-glm5]"
user-invocable: true
context: fork
agent: orchestrator
allowed-tools:
  - Task
  - AskUserQuestion
  - EnterPlanMode
  - ExitPlanMode
  - TodoWrite
  - Read
  - Edit
  - Write
  - Bash
  - Glob
  - Grep
  - mcp__plugin_claude-mem_*
---

# Orchestrator - Multi-Agent Ralph v2.87

**Smart Memory-Driven Orchestration** with swarm mode, parallel memory search, RLM-inspired routing, and quality-first validation.

Based on @PerceptualPeak Smart Forking concept:
> "Why not utilize the knowledge gained from your hundreds/thousands of other Claude code sessions? Don't let that valuable context go to waste!!"

## Quick Start

```bash
# Via skill invocation
/orchestrator Implement OAuth2 authentication with Google

# Via CLI
ralph orch "Migrate database from MySQL to PostgreSQL"

# With GLM-5 teammates for faster parallel execution
/orchestrator "Implement auth system" --with-glm5
/orchestrator "Refactor database layer" --with-glm5 --teammates coder,reviewer
```

## v2.87 Key Changes (UNIFIED SKILLS MODEL)

- **Skills/Commands unification**: All commands now use SKILL.md format
- **Single source of truth**: Skills live in repo, symlinked globally
- **Version alignment**: All skills updated to v2.87.0
- **Documentation consolidated**: Architecture docs in `docs/architecture/`

## v2.84 Key Changes (GLM-5 TEAMS)

**`--with-glm5` flag** enables GLM-5 teammates with thinking mode:

```
/orchestrator Implement OAuth2 --with-glm5
/orchestrator Fix auth bugs --with-glm5
```

When `--with-glm5` is set:
- Spawns `glm5-coder`, `glm5-reviewer`, `glm5-tester` teammates
- Each teammate uses GLM-5 API with thinking mode enabled
- Reasoning captured to `.ralph/reasoning/{task_id}.txt`
- Status tracked in `.ralph/teammates/{task_id}/status.json`

## v2.81 Key Changes (SWARM MODE)

**Swarm mode is now ENABLED by default** using native Claude Code multi-agent features:

1. **Team Creation**: Orchestrator creates team "orchestration-team" with identity
2. **Teammate Spawning**: ExitPlanMode spawns 3 teammates (code-reviewer, test-architect, security-auditor)
3. **Shared Task List**: All teammates see same tasks via TeammateTool
4. **Inter-Agent Messaging**: Teammates can communicate via mailbox
5. **Plan Approval**: Leader can approve/reject teammate plans

## Core Workflow (10 Steps)

```
0. EVALUATE     -> Quick complexity assessment (trivial vs non-trivial)
1. CLARIFY      -> AskUserQuestion intensively (MUST_HAVE + NICE_TO_HAVE)
2. CLASSIFY     -> Complexity 1-10, model routing
2b. WORKTREE    -> Ask about worktree isolation
3. PLAN         -> Design detailed plan (orchestrator analysis)
3b. PERSIST     -> Write to .claude/orchestrator-analysis.md
4. PLAN MODE    -> EnterPlanMode (reads analysis as foundation)
5. DELEGATE     -> Route to appropriate model/agent
6. EXECUTE      -> Parallel subagents
7. VALIDATE     -> Quality gates + Adversarial
8. RETROSPECT   -> Analyze and improve
```

## Step 0: EVALUATE (3-Dimension Classification)

**Classification (RLM-inspired)**:
| Dimension | Values | Purpose |
|-----------|--------|---------|
| Complexity | 1-10 | Scope, risk, ambiguity |
| Information Density | CONSTANT / LINEAR / QUADRATIC | How answer scales |
| Context Requirement | FITS / CHUNKED / RECURSIVE | Decomposition needs |

**Workflow Routing**:
| Density | Context | Complexity | Route |
|---------|---------|------------|-------|
| CONSTANT | FITS | 1-3 | **FAST_PATH** (3 steps) |
| CONSTANT | FITS | 4-10 | STANDARD |
| LINEAR | CHUNKED | ANY | PARALLEL_CHUNKS |
| QUADRATIC | ANY | ANY | RECURSIVE_DECOMPOSE |

## Step 1: CLARIFY (Memory-Enhanced)

**MUST_HAVE Questions** (Blocking):
```yaml
AskUserQuestion:
  questions:
    - question: "What is the primary goal?"
      header: "Goal"
      options:
        - label: "New feature"
        - label: "Bug fix"
        - label: "Refactoring"
        - label: "Performance"
```

## Step 2: CLASSIFY (Model Routing)

| Score | Complexity | Model | Adversarial |
|-------|------------|-------|-------------|
| 1-2 | Trivial | GLM-4.7 / glm-5 | No |
| 3-4 | Simple | GLM-4.7 / glm-5 | No |
| 5-6 | Medium | Sonnet | Optional |
| 7-8 | Complex | Opus | Yes |
| 9-10 | Critical | Opus (thinking) | Yes |

## Step 3: PLAN + PERSIST

Write plan to `.claude/orchestrator-analysis.md` with:
- Summary (informed by memory)
- Files to modify/create
- Dependencies
- Testing strategy
- Risks (include known issues from memory)

## Step 4: PLAN MODE

```yaml
EnterPlanMode: {}  # Claude Code reads orchestrator-analysis.md
```

Exit with `ExitPlanMode` when approved.

## Step 5: DELEGATE (Parallel-First with Swarm)

**PRIORITY: Parallel execution when possible**

```yaml
# With swarm mode (v2.81+)
Task:
  subagent_type: "orchestrator"
  description: "Full orchestration with swarm"
  prompt: "$ARGUMENTS"
  model: "sonnet"
  team_name: "orchestration-team"
  name: "orchestrator-lead"
  mode: "delegate"

# ExitPlanMode with swarm launch:
ExitPlanMode:
  launchSwarm: true
  teammateCount: 3
```

## Step 6: EXECUTE-WITH-SYNC

Nested loop with parallel substeps:

```
EXTERNAL RALPH LOOP (max 25)
└── For EACH step:
    ├── LSA-VERIFY (architecture check)
    ├── IMPLEMENT (parallel if independent)
    ├── PLAN-SYNC (drift detection)
    └── MICRO-GATE (max 3 retries)
```

**CRITICAL: model: "sonnet" for all subagents**

## Step 7: VALIDATE (Quality-First)

**Stage 1: CORRECTNESS (BLOCKING)**
- Meets requirements?
- Edge cases handled?

**Stage 2: QUALITY (BLOCKING)**
- Security verified? (semgrep + gitleaks)
- Performance OK?
- Tests adequate?

**Stage 3: CONSISTENCY (ADVISORY - not blocking)**
- Follows patterns?
- Style matches?

**Stage 4: ADVERSARIAL (if complexity >= 7)**
```bash
ralph adversarial "Design review"
```

## Step 8: RETROSPECTIVE (Mandatory)

```bash
ralph retrospective
```

**Save learnings to memory**:
```bash
ralph memvid save "Implemented OAuth2 successfully: [pattern details]"
ralph memvid save "AVOID: [error pattern] caused [issue]"
```

-> **VERIFIED_DONE**

## Model Routing

| Route | Primary | Secondary | Max Iter |
|-------|---------|-----------|----------|
| FAST_PATH | sonnet | - | 3 |
| STANDARD (1-4) | glm-5 | sonnet | 25 |
| STANDARD (5-6) | sonnet | opus | 25 |
| STANDARD (7-10) | opus | sonnet | 25 |
| PARALLEL_CHUNKS | sonnet (chunks) | opus (aggregate) | 15/chunk |
| RECURSIVE | opus (root) | sonnet (sub) | 15/sub |

## GLM-5 Teams Integration (--with-glm5)

When `$ARGUMENTS` contains `--with-glm5`:

**Step 1: Parse Arguments**
```
TASK=<everything before --with-glm5>
USE_GLM5=true
```

**Step 2: Spawn GLM-5 Teammates**
```bash
# GLM-5 Coder
.claude/scripts/glm5-teammate.sh "glm5-coder" "$CODER_TASK" "$TASK_ID-coder"

# GLM-5 Reviewer
.claude/scripts/glm5-teammate.sh "glm5-reviewer" "$REVIEW_TASK" "$TASK_ID-reviewer"

# GLM-5 Tester
.claude/scripts/glm5-teammate.sh "glm5-tester" "$TEST_TASK" "$TASK_ID-tester"
```

**Step 3: Wait for Completion**
```bash
cat .ralph/teammates/$TASK_ID-*/status.json
```

**Step 4: Aggregate Results**
- Collect outputs from `.ralph/reasoning/`
- Show thinking process for transparency
- Apply quality gates

## Available Teammates

| Teammate | Role | Best For |
|----------|------|----------|
| `coder` | Implementation | Writing code, fixing bugs |
| `reviewer` | Code Review | Quality checks, security |
| `tester` | Test Generation | Unit tests, coverage |
| `orchestrator` | Coordination | Complex multi-step tasks |

## Anti-Patterns

- Never start without smart memory search
- Never skip clarification
- Never use model: "haiku" for subagents
- Never skip retrospective
- Never attempt more than 3 fixes (3-Fix Rule)
- **Never block on consistency issues** (quality over consistency)
- **Never ignore memory context** (learn from history)

## Completion Criteria

`VERIFIED_DONE` requires ALL:
1. Smart Memory Search complete
2. Task classified (3 dimensions)
3. MUST_HAVE questions answered
4. Plan approved
5. Implementation complete
6. CORRECTNESS passed (blocking)
7. QUALITY passed (blocking)
8. Adversarial passed (if complexity >= 7)
9. Retrospective done + learnings saved to memory

## CLI Commands

```bash
# Standard orchestration
ralph orch "task description"

# With GLM-5 teammates
ralph orch "task description" --with-glm5
ralph orch "complex feature" --with-glm5 --teammates coder,reviewer,tester

# Quality gates
ralph gates
ralph adversarial "spec"

# Memory
ralph memory-search "query"
ralph fork-suggest "Add authentication"
```

## Related Skills

- `/loop` - Iterative execution until VERIFIED_DONE
- `/gates` - Quality validation gates
- `/adversarial` - Spec refinement
- `/parallel` - Parallel subagent execution
- `/retrospective` - Post-task analysis
- `/clarify` - Requirement clarification

## References

- [Unified Architecture v2.87](docs/architecture/UNIFIED_ARCHITECTURE_v2.87.md)
- [Skills/Commands Unification](docs/architecture/SKILLS_COMMANDS_UNIFICATION_v2.87.md)
- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
