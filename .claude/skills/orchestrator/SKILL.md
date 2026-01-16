---
# VERSION: 2.43.0
name: orchestrator
description: "Full 8-step orchestration workflow for complex software tasks: clarify requirements, classify complexity, create worktree isolation, plan implementation, delegate to specialized agents, execute with quality gates, validate with adversarial review, and retrospective analysis. Use when: (1) implementing new features, (2) complex refactoring, (3) multi-file changes, (4) tasks requiring planning and coordination, (5) any task with complexity >= 5. Triggers include: /orchestrator, /orch, 'orchestrate', 'full workflow', 'implement feature', 'coordinate task'."
context: fork
user-invocable: true
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
hooks:
  SessionStart:
    - path: ~/.claude/hooks/orchestrator-init.sh
      once: true
  Stop:
    - path: ~/.claude/hooks/orchestrator-report.sh
---

# Orchestrator - Multi-Agent Ralph v2.43

Coordinates complex software tasks through an 8-step mandatory workflow with quality gates, **two-stage adversarial validation**, automatic context preservation, **LLM-TLDR token optimization**, and **Socratic design exploration**.

## Quick Start

```bash
# Via skill invocation
/orchestrator Implement OAuth2 authentication with Google

# Via CLI
ralph orch "Migrate database from MySQL to PostgreSQL"
```

## Core Workflow (8 Steps)

### Step 0: AUTO-PLAN
**AUTOMATIC** - Enter Plan Mode unless task is trivial (single-line fix)

```yaml
EnterPlanMode: {}  # Non-trivial tasks ALWAYS enter plan mode
```

### Step 0b: AUTO-INDEX (v2.37 - LLM-TLDR)
**AUTOMATIC** - Before any code exploration, check/build tldr index:

```bash
# Check if index exists, warm if needed (runs once per project)
if command -v tldr &>/dev/null && [ ! -d ".tldr" ]; then
    tldr warm .  # Build semantic index (~2 min)
fi
```

This enables 95% token savings for all subsequent code analysis.

### Step 1: CLARIFY (Intensive + TLDR)
**AUTOMATIC TLDR**: Before asking questions, use semantic search to understand existing code:

```bash
# Find existing related functionality (95% token savings)
tldr semantic "$USER_TASK_KEYWORDS" .
```

Then use AskUserQuestion for ALL necessary clarifications:

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

**Categories to cover**:
1. Functional requirements
2. Technical constraints
3. Integration points
4. Testing strategy
5. Deployment considerations

### Step 1b: SOCRATIC DESIGN (v2.42)
**For architectural decisions**, present 2-3 alternatives with trade-offs:

```yaml
AskUserQuestion:
  questions:
    - question: "Multiple approaches identified. Which direction?"
      header: "Design"
      options:
        - label: "Option A (Recommended)"
          description: "[Approach] - Trade-off: [pros/cons]"
        - label: "Option B"
          description: "[Approach] - Trade-off: [pros/cons]"
        - label: "Option C"
          description: "[Approach] - Trade-off: [pros/cons]"
```

**MANDATORY when**: architectural patterns, library choices, data models, cross-cutting changes (3+ modules)

### Step 2: CLASSIFY
Determine complexity (1-10):

| Score | Complexity | Model | Adversarial |
|-------|------------|-------|-------------|
| 1-2 | Trivial | MiniMax-lightning | No |
| 3-4 | Simple | MiniMax M2.1 | No |
| 5-6 | Medium | Sonnet | Optional |
| 7-8 | Complex | Opus | Yes |
| 9-10 | Critical | Opus (thinking) | Yes (adversarial-spec) |

### Step 2b: WORKTREE DECISION
Ask user about isolation:

```yaml
AskUserQuestion:
  questions:
    - question: "Requires isolated worktree?"
      header: "Isolation"
      options:
        - label: "Yes, create worktree"
          description: "New feature, easy rollback"
        - label: "No, current branch"
          description: "Hotfix, minor change"
```

If yes: `ralph worktree "feature-name"`

### Step 3: PLAN (TLDR-Enhanced)
**AUTOMATIC TLDR**: Analyze impact before writing plan:

```bash
# Analyze files that will be affected (95% token savings)
tldr impact "$PLANNED_FILES" .

# Get dependency graph for affected modules
tldr deps "$PRIMARY_FILE" .
```

Write detailed plan with:
- Summary
- Files to modify/create (informed by `tldr impact`)
- Dependencies (informed by `tldr deps`)
- Testing strategy
- Risks

Exit with `ExitPlanMode` when approved.

### Step 4: DELEGATE
Route to specialized agents:

```yaml
# Security-critical
Task:
  subagent_type: "security-auditor"
  model: "opus"
  prompt: "Audit: $FILES"

# Standard review
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  run_in_background: true
  prompt: "Review: $FILES"
```

### Step 5: EXECUTE (Parallel + TLDR Context)
**AUTOMATIC TLDR**: Prepare focused context for subagents:

```bash
# Generate focused context for each file being modified (95% token savings)
tldr context "$FILE_TO_MODIFY" . > /tmp/context-for-subagent.md

# For code review, get structure summary instead of full file
tldr structure . --lang "$LANGUAGE" > /tmp/structure-summary.md
```

Launch multiple agents with TLDR-optimized context:

```yaml
# CRITICAL: Always use model: "sonnet" for subagents
# Include TLDR context in prompt for token efficiency
Task:
  subagent_type: "code-reviewer"
  model: "sonnet"
  run_in_background: true
  prompt: "Review changes. Context: $(tldr context $FILE .)"

Task:
  subagent_type: "test-architect"
  model: "sonnet"
  run_in_background: true
  prompt: "Generate tests. Structure: $(tldr structure . --lang $LANG)"
```

**Ralph Loop**: Execute -> Validate -> Iterate (max 25) -> VERIFIED_DONE

### Step 6: VALIDATE (Two-Stage Review v2.42)

**Stage 1: Spec Compliance** (Run first)
```bash
# Quality gates (9 languages)
ralph gates
```

Verify WHAT was built:
- [ ] Meets all stated requirements
- [ ] Covers all use cases
- [ ] Respects constraints
- [ ] Handles edge cases

**Exit Stage 1 before Stage 2. If compliance fails, fix before quality review.**

**Stage 2: Code Quality** (Run after Stage 1 passes)
```bash
# Adversarial spec refinement (complexity >= 7)
ralph adversarial "Draft: Design a rate limiter service"
```

Verify HOW it was built:
- [ ] Follows codebase patterns
- [ ] Performance OK
- [ ] Security applied
- [ ] Tests adequate

### Step 7: RETROSPECTIVE (Mandatory)
```bash
ralph retrospective
```

Analyze and propose improvements.

## Integration Points

| Skill/Agent | Role | Invocation |
|-------------|------|------------|
| **LLM-TLDR** | **Token optimization (95% savings)** | **Steps 0b, 1, 3, 5** |
| /clarify | Intensive questioning | Step 1 |
| /gates | Quality validation | Step 6 Stage 1 |
| /adversarial | Two-stage review (v2.42) | Step 6 Stage 2 |
| /systematic-debugging | 3-Fix Rule enforcement (v2.42) | Step 5 (on bugs) |
| /retrospective | Post-analysis | Step 7 |
| @code-reviewer | Code review | Step 5 |
| @security-auditor | Security audit | Step 5 |
| @test-architect | Test generation | Step 5 |

## TLDR Integration (v2.37)

| Command | Purpose | Savings |
|---------|---------|---------|
| `tldr warm .` | Build semantic index (once per project) | - |
| `tldr semantic "query" .` | Find related code semantically | 95% |
| `tldr structure .` | Get codebase structure summary | 80% |
| `tldr context file.py .` | Get focused context for a file | 93% |
| `tldr impact files .` | Analyze change impact | 85% |
| `tldr deps file.py .` | Get dependency graph | 90% |

## Model Routing

| Task Type | Primary | Secondary |
|-----------|---------|-----------|
| Security | Claude Opus | Codex |
| Frontend | Gemini | Claude |
| Review | Codex | MiniMax (8%) |
| Docs | MiniMax | Claude |

## Examples

<Good>
User: "Add user authentication"
1. [EnterPlanMode] ✓
2. [AskUserQuestion] "OAuth providers?" "Token storage?"
3. [Classify] Complexity: 8
4. [Worktree] "Yes" -> ralph worktree "auth-feature"
5. [Plan] Detailed implementation plan
6. [Delegate] Opus -> security-auditor
7. [Execute] Parallel agents in worktree
8. [Validate] Gates + Adversarial-spec
9. [Retrospective] Document learnings
10. VERIFIED_DONE
</Good>

<Bad>
User: "Add user authentication"
1. Start coding immediately
2. No clarification
3. No plan
4. Skip validation

Why: Security-critical task requires full workflow.
</Bad>

## Anti-Patterns

- Never start coding without clarification
- Never skip Plan Mode for non-trivial tasks
- Never use model: "haiku" for subagents (causes infinite retries)
- Never skip retrospective
- **Never attempt more than 3 fixes for the same issue** (3-Fix Rule v2.42 - escalate to user after 3 failed attempts, see `/systematic-debugging`)

## Completion Criteria

`VERIFIED_DONE` requires ALL:
1. Plan Mode entered (or confirmed trivial)
2. MUST_HAVE questions answered
3. Task classified
4. Plan approved
5. Implementation complete
6. Quality gates passed
7. Adversarial passed (if complexity >= 7)
8. Retrospective done
