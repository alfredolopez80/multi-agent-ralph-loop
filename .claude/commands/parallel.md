---
# VERSION: 2.84.1
name: parallel
prefix: "@par"
category: review
color: red
description: "Run all 6 subagents in parallel (async)"
argument-hint: "<path> [--with-glm5]"
---

# /parallel - Parallel Multi-Agent Review (v2.84.1)

Execute 6 specialized review agents in parallel with swarm mode coordination.

## v2.84.1 Key Change (GLM-5 INTEGRATION)

**`--with-glm5` flag** enables GLM-5 teammates for parallel review:

```
/parallel src/auth/ --with-glm5
```

When `--with-glm5` is set:
- Uses `glm5-reviewer` for code and security review
- Uses `glm5-tester` for coverage analysis
- Captures reasoning for each review aspect
- Runs in parallel with thinking mode

## Overview

The `/parallel` command spawns a large review team (6 agents) that work in parallel to provide comprehensive code analysis:
1. **Code Review** - Quality, patterns, best practices
2. **Security Review** - Vulnerabilities, security issues
3. **Test Coverage** - Test gaps, coverage analysis
4. **Performance Review** - Performance bottlenecks, optimization
5. **Documentation Review** - Doc coverage, clarity
6. **Architecture Review** - Design patterns, modularity

```
┌─────────────────────────────────────────────────────────────────┐
│                  PARALLEL SWARM MODE (6 agents)               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌────────┐ │
│   │  CODE   │ │SECURITY │ │  TEST   │ │ PERF   │ │ DOC   │ │
│   │ REVIEW  │ │ REVIEW  │ │ COVERAGE │ │ REVIEW  │ │ REVIEW │ │
│   └────┬────┘ └────┬────┘ └────┬────┘ └────┬────┘ └───┬───┘ │
│        │           │           │           │          │      │
│        └───────────┴───────────┴───────────┴──────────┘      │
│                            │                                 │
│                    ┌───────┴────────┐                        │
│                    │  ARCH REVIEW  │                        │
│                    └───────┬────────┘                        │
│                            │                                 │
│                            ▼                                 │
│                   ┌─────────────────┐                       │
│                   │  Parallel Lead  │                       │
│                   │  (par-lead)     │                       │
│                   └─────────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## When to Use

Use `/parallel` when:
- Comprehensive code review is needed
- Multiple analysis perspectives required
- Fast parallel execution preferred
- Large codebase needs thorough review
- Pre-commit validation for complex changes

**DO NOT use** for:
- Simple one-line fixes (use direct review)
- Single-aspect analysis (use specific reviewer)
- Quick syntax checks

---

## Swarm Mode Integration (v2.81.1)

`/parallel` uses swarm mode with **6 specialized review agents** for comprehensive parallel analysis.

### Auto-Spawn Configuration

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  team_name: "parallel-execution"
  name: "par-lead"
  mode: "delegate"
  run_in_background: true
  prompt: |
    Execute parallel multi-agent review for: $ARGUMENTS

    Parallel Pattern:
    1. DISTRIBUTE - Assign review aspects to 6 specialists
    2. EXECUTE - All agents review in parallel (async)
    3. COLLECT - Gather findings from all agents
    4. SYNTHESIZE - Merge into comprehensive report
```

### Team Composition (6 Agents)

| Role | Purpose | Specialization |
|------|---------|----------------|
| **Coordinator** | Parallel workflow orchestration | Manages 6-agent team, synthesizes findings |
| **Teammate 1** | Code Review specialist | Quality, patterns, best practices |
| **Teammate 2** | Security Review specialist | Vulnerabilities, security issues |
| **Teammate 3** | Test Coverage specialist | Test gaps, coverage analysis |
| **Teammate 4** | Performance Review specialist | Bottlenecks, optimization opportunities |
| **Teammate 5** | Documentation Review specialist | Doc coverage, clarity, completeness |
| **Teammate 6** | Architecture Review specialist | Design patterns, modularity, coupling |

### Swarm Mode Workflow

```
User invokes: /parallel src/auth/

1. Team "parallel-execution" created
2. Coordinator (par-lead) receives code path
3. 6 Teammates spawned with review specializations
4. Review aspects distributed:
   - Teammate 1 → Code quality, patterns
   - Teammate 2 → Security vulnerabilities
   - Teammate 3 → Test coverage gaps
   - Teammate 4 → Performance issues
   - Teammate 5 → Documentation review
   - Teammate 6 → Architecture assessment
5. All teammates work in parallel (background execution)
6. Coordinator monitors progress and gathers findings
7. All reviews collected and synthesized
8. Comprehensive report with 6 perspectives returned
```

### Parallel Review Pattern

Each teammate focuses on their review aspect:

```yaml
# Teammate 1: Code Review
- Quality: Code style, naming conventions
- Patterns: Design patterns usage
- Best practices: Language idioms
- Maintainability: Code complexity

# Teammate 2: Security Review
- Vulnerabilities: OWASP Top 10
- Input validation: User input handling
- Authentication: Auth implementation
- Authorization: Access control

# Teammate 3: Test Coverage
- Unit tests: Coverage percentage
- Integration tests: API coverage
- Edge cases: Boundary testing
- Test quality: meaningful assertions

# Teammate 4: Performance Review
- Bottlenecks: N+1 queries, loops
- Optimization: Caching, indexing
- Resource usage: Memory, CPU
- Scalability: Load handling

# Teammate 5: Documentation Review
- Coverage: Public API documented
- Clarity: Explanations clear
- Completeness: Examples provided
- Consistency: Format maintained

# Teammate 6: Architecture Review
- Patterns: Design pattern usage
- Modularity: Separation of concerns
- Coupling: Dependency management
- Extensibility: Future-proofing
```

### Communication Between Teammates

```yaml
# Teammate sends finding to coordinator
SendMessage:
  type: "message"
  recipient: "par-lead"
  content: "Security: SQL injection risk in auth.js:45"

# Coordinator requests cross-aspect analysis
SendMessage:
  type: "message"
  recipient: "teammate-4"
  content: "Analyze performance impact of security fix at auth.js:45"
```

### Task List Coordination

```bash
# Location: ~/.claude/tasks/parallel-execution/tasks.json

# Example tasks:
[
  {"id": "1", "subject": "Code quality review", "owner": "teammate-1"},
  {"id": "2", "subject": "Security review", "owner": "teammate-2"},
  {"id": "3", "subject": "Test coverage review", "owner": "teammate-3"},
  {"id": "4", "subject": "Performance review", "owner": "teammate-4"},
  {"id": "5", "subject": "Documentation review", "owner": "teammate-5"},
  {"id": "6", "subject": "Architecture review", "owner": "teammate-6"},
  {"id": "7", "subject": "Synthesize all findings", "owner": "par-lead"}
]
```

## Execution

### Basic Usage

```bash
# Parallel review with swarm mode (default)
/parallel src/auth/

# Review specific file
/parallel src/auth/middleware.js

# Review with custom agent count
/parallel src/ --agents 8
```

### Async Mode

```bash
# Explicit async mode (swarm mode is inherently async)
/parallel src/ --async

# Run in background, get results later
/parallel src/ --background && cat ~/.ralph/parallel/latest.md
```

### CLI Wrapper

```bash
ralph parallel "$ARGUMENTS" --async
ralph parallel "src/auth/" --background
```

### Manual Override

```bash
# Disable swarm mode (sequential instead of parallel)
/parallel "src/" --no-swarm

# Custom teammate count (default: 6)
/parallel "src/" --teammates 10
```

## Output Format

### Console Output

```
╔══════════════════════════════════════════════════════════════╗
║           Parallel Multi-Agent Review (Swarm Mode)          ║
╠══════════════════════════════════════════════════════════════╣
║ Target: src/auth/                                           ║
║ Team: parallel-execution (6 agents)                         ║
╚══════════════════════════════════════════════════════════════╝

[Parallel Execution Started]
├─ Teammate 1: Code Review → RUNNING
├─ Teammate 2: Security Review → RUNNING
├─ Teammate 3: Test Coverage → RUNNING
├─ Teammate 4: Performance Review → RUNNING
├─ Teammate 5: Documentation Review → RUNNING
└─ Teammate 6: Architecture Review → RUNNING

[Results - 6/6 COMPLETE]
├─ Code Review: 3 findings (style, patterns, complexity)
├─ Security Review: 2 findings (SQL injection, XSS risk)
├─ Test Coverage: 4 findings (missing unit tests, edge cases)
├─ Performance Review: 2 findings (N+1 query, missing index)
├─ Documentation Review: 3 findings (missing JSDoc, outdated examples)
└─ Architecture Review: 2 findings (tight coupling, missing abstraction)

[Synthesis]
├─ Critical Issues: 2 (SQL injection, XSS risk)
├─ High Priority: 5 (N+1 query, test gaps, coupling)
├─ Medium Priority: 7 (style, docs, patterns)
└─ Low Priority: 0

╔══════════════════════════════════════════════════════════════╗
║                    Review Summary                           ║
╠══════════════════════════════════════════════════════════════╣
║ Total Findings: 16                                          ║
║ Critical Issues: 2                                          ║
║ Files Reviewed: 12                                          ║
║ Duration: 5m 42s (6 agents in parallel)                     ║
╚══════════════════════════════════════════════════════════════╝
```

## Output Location

```bash
# Review reports saved to ~/.ralph/parallel/
ls ~/.ralph/parallel/

# View last review
cat ~/.ralph/parallel/latest.md

# Logs saved to ~/.ralph/logs/parallel-*.log
tail -f ~/.ralph/logs/parallel-latest.log
```

## Related Commands

### Orchestration Commands
- `/orchestrator` - Full workflow (includes parallel review)
- `/loop` - Iterative execution until VERIFIED_DONE
- `/adversarial` - Adversarial validation

### Review Commands
- `/code-reviewer` - Single code reviewer
- `/security` - Security-only review
- `/gates` - Quality gate validation

## Examples

### Example 1: Module Review

```bash
/parallel src/auth/
```

**Output**:
- 6 agents review in parallel
- 16 total findings across all aspects
- Completed in 5m 42s (vs ~30m sequential)

### Example 2: Single File

```bash
/parallel src/auth/middleware.js
```

**Output**:
- Deep dive on single file
- All 6 aspects analyzed
- Comprehensive findings list

### Example 3: Large Codebase

```bash
/parallel src/ --agents 10
```

**Output**:
- 10 agents for larger codebase
- Additional specialists added (UX, i18n, a11y)
- Scalable parallel execution

## Best Practices

1. **Use for complex reviews**: 6-agent review is thorough but slower
2. **Trust the parallelism**: Agents work simultaneously, not sequentially
3. **Review synthesis**: Coordinator merges all perspectives
4. **Prioritize findings**: Critical > High > Medium > Low
5. **Iterate if needed**: Run again after fixing critical issues

---

**Version**: 2.81.1 | **Status**: SWARM MODE ENABLED | **Team Size**: 7 agents (1 lead + 6 specialists)

## GLM-5 Integration (v2.84.1)

When `$ARGUMENTS` contains `--with-glm5`:

**Parse Arguments:**
```
TARGET=<path before --with-glm5>
USE_GLM5=true
```

**Execution Pattern:**
```bash
# Spawn GLM-5 teammate with thinking mode
.claude/scripts/glm5-teammate.sh "glm5-reviewer" "$TASK" "${TASK_ID}"

# View reasoning
cat .ralph/reasoning/${TASK_ID}.txt

# Check status
cat .ralph/teammates/${TASK_ID}/status.json
```

**Output Files:**
- `.ralph/teammates/{task_id}/status.json` - Review status
- `.ralph/reasoning/{task_id}.txt` - GLM-5 thinking process
