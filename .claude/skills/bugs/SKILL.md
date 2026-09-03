---
# VERSION: 3.1.0
name: bugs
description: "Evidence-first bug hunting driven by Claude subagents. Use when: (1) /bugs is invoked, (2) task relates to finding bugs in code, a diff, or a failing behavior."
context: fork
user-invocable: true
allowed-tools:
  - Agent
  - Task
  - LSP
  - Read
  - Bash
  - Grep
  - Glob
---

# /bugs (v3.1)

Deep, evidence-first bug analysis. **The engine is Claude subagents** spawned via the
Agent/Task tool — the skill works whenever Claude does, with no dependency on any external
CLI. TLDR context optimization keeps token cost low.

## Engine

- **Engine: subagents.** Bug hunting runs through the Agent/Task tool with a bug-hunter
  prompt and the evidence-first contract below.
- **Model**: whatever the session runs. Spawned subagents inherit it. This skill never
  selects a model and never routes to an external provider.

## Evidence-First Contract (non-negotiable)

Bug hunting is evidence work, not a confidence exercise. Report ONLY issues grounded in
changed code, reachable paths, a test failure, runtime evidence, or a clear invariant
violation. If a suspected issue cannot be verified from the available context, label it an
**unverified risk** and state the fastest way to prove it — do not report it as a confirmed
bug. Prefer a small number of high-conviction findings over a long list of speculation.

## Agent Teams Integration (v2.88)

**Optimal Scenario**: Pure Custom Subagents

This skill uses Pure Custom Subagents (no Agent Teams) for specialized, focused bug analysis.

### Why Scenario B for Bug Hunting
- **Specialized task**: Bug analysis is a focused, single-purpose operation
- **Less coordination needed**: Direct spawn faster than team creation for single-file analysis
- **Tool restrictions important**: ralph-reviewer restricted to Read/Grep/Glob prevents accidental modifications
- **Scalable pattern**: For large codebases, spawn multiple reviewers directly without team overhead

### Configuration
1. **No TeamCreate**: Skip team creation overhead for faster execution
2. **Direct Task**: Spawn ralph-reviewer agents directly with analysis prompts
3. **Tool Restrictions**: Leverage per-agent tool limits (Read/Grep/Glob only for reviewers)
4. **Model Inheritance**: Use model configured in settings.json

### Workflow Pattern
```
Task(subagent_type="ralph-reviewer", prompt="Analyze $TARGET for bugs...")
  → Agent executes with restricted tools (no Write/Edit)
  → Returns structured bug findings
  → Complete (no team cleanup needed)
```

### For Large Codebases (Parallel Scanning)
When analyzing directories with many files:
```bash
# Spawn multiple reviewers in parallel (no team needed)
Task(subagent_type="ralph-reviewer", prompt="Analyze files 1-10...")
Task(subagent_type="ralph-reviewer", prompt="Analyze files 11-20...")
Task(subagent_type="ralph-reviewer", prompt="Analyze files 21-30...")

# Aggregate results manually or via simple script
```

### When NOT to Use Agent Teams
- Single-file bug analysis (most common case)
- Quick scans without multi-phase coordination
- When tool restrictions (no Write/Edit) are more important than coordination
- When team creation overhead exceeds analysis time

## Pre-Bugs: TLDR Context Preparation (v2.37)

**AUTOMATIC** - Before bug hunting, gather context with 95% token savings:

```bash
# Get function signatures and call flow
tldr context "$TARGET_FILE" . > /tmp/bugs-context.md

# Get dependency graph for tracking bug propagation
tldr deps "$TARGET_FILE" . > /tmp/bugs-deps.md

# Get codebase structure for understanding module relationships
tldr structure . > /tmp/bugs-structure.md

# Semantic search for error handling patterns
tldr semantic "try catch error exception throw" .
```

## Overview

The `/bugs` command performs comprehensive analysis using **TLDR-compressed context** to identify bugs, logic errors, race conditions, edge cases, and other issues that could cause runtime failures. It runs **Claude bug-hunter subagents** that read the target, trace reachable code paths, and report findings grounded in evidence.

Unlike traditional linters, this performs deep semantic analysis:
- **Context-aware**: Understands code intent and business logic
- **Multi-file analysis**: Traces bugs across module boundaries
- **Pattern recognition**: Identifies common bug patterns and anti-patterns
- **Fix suggestions**: Provides actionable remediation steps

## When to Use

Use `/bugs` when:
- Investigating mysterious test failures or production issues
- Auditing newly merged code for potential issues
- Debugging complex interactions between modules
- Preparing critical code paths for production deployment
- Reviewing legacy code for modernization
- Searching for edge cases before stress testing
- Performing pre-merge quality checks (complexity >= 7)

## Analysis Methodology

The bug-hunter subagent follows a systematic approach:

1. **Static Analysis**: Parse AST and control flow graphs
2. **Pattern Matching**: Compare against known bug patterns database
3. **Semantic Understanding**: Analyze code intent and data flow
4. **Edge Case Detection**: Identify boundary conditions and error paths
5. **Severity Assessment**: Classify bugs by impact and probability
6. **Fix Generation**: Propose concrete remediation steps

### Bug Categories

| Category | Examples | Severity |
|----------|----------|----------|
| **Logic Errors** | Off-by-one, incorrect conditions, wrong operators | HIGH |
| **Race Conditions** | Unprotected shared state, TOCTOU bugs | HIGH |
| **Memory Issues** | Leaks, use-after-free, buffer overflows | CRITICAL |
| **Type Errors** | Implicit conversions, type coercion bugs | MEDIUM |
| **Error Handling** | Uncaught exceptions, missing null checks | HIGH |
| **Edge Cases** | Empty arrays, boundary values, overflow | MEDIUM |
| **Async Issues** | Unhandled promises, callback hell, deadlocks | HIGH |
| **Security Bugs** | Injection, XSS, CSRF (see /security for full audit) | CRITICAL |

## Execution — Claude subagents (primary path)

Spawn one or more Claude bug-hunter subagents through the Agent/Task tool. Pass the
target and the TLDR context; require the evidence-first contract and the JSON output
below. The subagents inherit the session's configured model.

```yaml
Agent:
  subagent_type: "general-purpose"   # or a code-review agent if available
  description: "Bug hunt: $ARGUMENTS"
  prompt: |
    Evidence-first bug hunt on: $ARGUMENTS

    # Context (token-optimized via tldr, when available)
    Structure:    $(tldr structure . 2>/dev/null)
    File context: $(tldr context $ARGUMENTS . 2>/dev/null)
    Dependencies: $(tldr deps $ARGUMENTS . 2>/dev/null)

    Rules:
    - Report ONLY bugs grounded in reachable code, a failing test, runtime evidence,
      or a clear invariant violation. Verify each finding by reading the real code
      (and, where safe, by running a throwaway repro). Anything you cannot verify is an
      "unverified risk" with the fastest proof named — not a confirmed bug.
    - Do NOT modify code. Report only.

    Output JSON:
    {
      "bugs": [
        {
          "severity": "CRITICAL|HIGH|MEDIUM|LOW",
          "type": "logic|race|memory|type|error-handling|edge-case|async|security",
          "file": "path/to/file.ts",
          "line": 42,
          "description": "Clear bug description",
          "fix": "Concrete remediation steps",
          "evidence": "How it was verified, or the proof that would confirm it"
        }
      ],
      "summary": { "total": 0, "high": 0, "medium": 0, "low": 0, "approved": false }
    }
```

For a large target, fan out several subagents over disjoint file ranges in a single
message (they run concurrently), then merge and dedupe their JSON — deduped findings that
several agents raise independently are the strongest.

## Output Format

The bug hunting analysis returns structured JSON:

```json
{
  "bugs": [
    {
      "severity": "HIGH",
      "type": "race",
      "file": "src/auth/session.ts",
      "line": 87,
      "description": "Race condition: session.user accessed before async initialization completes",
      "fix": "Add await before accessing session.user, or use Promise.all() to ensure initialization"
    },
    {
      "severity": "MEDIUM",
      "type": "edge-case",
      "file": "src/utils/parser.ts",
      "line": 23,
      "description": "Empty array not handled: arr[0] will throw if arr is empty",
      "fix": "Add guard: if (arr.length === 0) return null; before accessing arr[0]"
    }
  ],
  "summary": {
    "total": 2,
    "high": 1,
    "medium": 1,
    "low": 0,
    "approved": false
  }
}
```

### Severity Levels

| Severity | Meaning | Action |
|----------|---------|--------|
| **CRITICAL** | Production-breaking, security issues | MUST FIX before merge |
| **HIGH** | Likely to cause failures, data corruption | SHOULD FIX before merge |
| **MEDIUM** | Edge cases, potential issues under load | Review and decide |
| **LOW** | Code smells, minor improvements | Optional fix |

## Integration

The `/bugs` command integrates with other Ralph workflows:

### With @debugger Agent

```yaml
Task:
  subagent_type: "debugger"
  description: "Full debugging workflow"
  prompt: |
    1. Run /bugs on $TARGET
    2. Analyze top 5 HIGH severity bugs
    3. Trace execution paths to root cause
    4. Propose fixes with test cases
    5. Validate fixes pass quality gates
```

### With /adversarial

When a bug fix needs a clarified spec:

```bash
# Step 1: Bug hunting
ralph bugs src/payment/

# Step 2: Draft a short spec for the fix
ralph adversarial "Draft: Fix payment retry logic with idempotency"
```

### With /unit-tests

Generate tests that specifically target discovered bugs:

```yaml
Task:
  subagent_type: "ralph-tester"
  prompt: |
    Read bugs-report.json
    For each HIGH/CRITICAL bug:
    - Write failing test that reproduces bug
    - Verify test fails before fix
    - Apply fix from bug report
    - Verify test passes after fix

    Use TDD pattern: RED → FIX → GREEN
```

## Related Commands

| Command | Purpose | When to Use |
|---------|---------|-------------|
| `/security` | Security-focused audit (CWE checks) | Before production deploy |
| `/unit-tests` | Generate test coverage | After bug fixes |
| `/refactor` | Improve code structure | After identifying patterns |
| `/adversarial` | Adversarial spec refinement | Critical code paths |
| `/full-review` | Comprehensive analysis (6 agents) | Major features/releases |

## Ralph Loop Integration

The `/bugs` command follows the Ralph Loop pattern with these hooks:

```
┌─────────────────────────────────────────────────────────┐
│ RALPH LOOP: Bug Hunting                                 │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 1. EXECUTE   → Claude bug-hunter subagent(s)            │
│ 2. VALIDATE  → Check severity counts                    │
│ 3. ITERATE   → Fix HIGH+ bugs                           │
│ 4. VERIFY    → Re-run until summary.approved = true     │
│                                                         │
│ Quality Gate: No HIGH+ bugs OR all explicitly approved  │
│ Max Iterations: 15                                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Approval Criteria

The bug hunting loop continues until:
- **Zero HIGH+ bugs** detected, OR
- **All HIGH+ bugs** explicitly approved by user with justification
- **Quality gates** pass (no new bugs introduced by fixes)

## Example Workflow

Full bug hunting and remediation workflow:

```bash
# 1. Initial bug scan
ralph bugs src/

# 2. Review report
cat .claude/tmp/bugs_report.json | jq '.summary'

# 3. Fix HIGH severity bugs
# (manual or via /refactor)

# 4. Verify fixes
ralph bugs src/  # Should show reduced bug count

# 5. Generate regression tests
ralph unit-tests src/

# 6. Run quality gates
ralph gates

# 7. Final approval (if LOW bugs remain)
# Add to bugs-report.json: "approved": true, "justification": "Low risk edge cases"
```

## Best Practices

1. **Run before merge**: Always scan critical paths before PR approval
2. **Prioritize HIGH+**: Focus on CRITICAL and HIGH severity first
3. **Fix root causes**: Don't just patch symptoms
4. **Add tests**: Every fixed bug needs a regression test
5. **Track patterns**: If same bug type appears multiple times, refactor pattern
6. **Combine with /security**: Bug hunting finds logic errors, security finds vulnerabilities
7. **Scale effort, not models**: for payment/auth/crypto code, fan out more subagents over
   narrower file ranges and demand stronger evidence — do not switch models.

## Model

The bug-hunter subagents inherit the session's model. Choosing a model is the user's call
(`/model`, or naming one in the request); this skill never makes it.


## Action Reporting (v2.93.0)

**Esta skill genera reportes automáticos completos** para trazabilidad:

### Reporte Automático

Cuando esta skill completa, se genera automáticamente:

1. **En la conversación de Claude**: Resultados visibles
2. **En el repositorio**: `docs/actions/bugs/{timestamp}.md`
3. **Metadatos JSON**: `.claude/metadata/actions/bugs/{timestamp}.json`

### Contenido del Reporte

Cada reporte incluye:
- ✅ **Summary**: Descripción de la tarea ejecutada
- ✅ **Execution Details**: Duración, iteraciones, archivos modificados
- ✅ **Results**: Errores encontrados, recomendaciones
- ✅ **Next Steps**: Próximas acciones sugeridas

### Ver Reportes Anteriores

```bash
# Listar todos los reportes de esta skill
ls -lt docs/actions/bugs/

# Ver el reporte más reciente
cat $(ls -t docs/actions/bugs/*.md | head -1)

# Buscar reportes fallidos
grep -l "Status: FAILED" docs/actions/bugs/*.md
```

### Generación Manual (Opcional)

```bash
source .claude/lib/action-report-lib.sh
start_action_report "bugs" "Task description"
# ... ejecución ...
complete_action_report "success" "Summary" "Recommendations"
```

### Referencias del Sistema

- [Action Reports System](docs/actions/README.md) - Documentación completa
- [action-report-lib.sh](.claude/lib/action-report-lib.sh) - Librería helper
- [action-report-generator.sh](.claude/lib/action-report-generator.sh) - Generador
