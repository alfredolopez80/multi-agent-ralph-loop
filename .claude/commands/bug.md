---
# VERSION: 2.81.1
name: bug
prefix: "@bug"
category: debugging
color: red
description: "Debugging with swarm mode: analyze → reproduce → fix → validate systematically"
argument-hint: "<bug description> [--swarm] [--no-swarm]"
---

# /bug - Swarm Mode Debugging (v2.81.1)

Systematic debugging with multi-agent coordination and parallel analysis.

## Overview

The `/bug` command spawns a specialized debugging team that works in parallel to:
1. **Analyze** the error (symptoms, stack traces, logs)
2. **Reproduce** the issue (determine conditions, create minimal case)
3. **Locate** root cause (code archaeology, trace execution path)
4. **Fix** and validate (patch without breaking other functionality)

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEBUGGING SWARM MODE                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌────────────┐   ┌─────────────┐   ┌──────────┐   ┌────────┐ │
│   │   ANALYZE  │──▶│  REPRODUCE  │──▶│ LOCATE   │──▶│  FIX   │ │
│   │   Error    │   │   Issue     │   │   Root   │   │Validate│ │
│   └────────────┘   └─────────────┘   └──────────┘   └────────┘ │
│         │                │               │              │       │
│         └────────────────┴───────────────┴──────────────┘       │
│                            │                                   │
│                            ▼                                   │
│                   ┌─────────────────┐                         │
│                   │ Bug Coordinator │                         │
│                   │  (bug-lead)     │                         │
│                   └─────────────────┘                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## When to Use

Use `/bug` when:
- Systematic bug analysis is needed
- Error requires multiple investigation angles
- Root cause is unclear or complex
- Fix needs validation to prevent regressions
- Logs and stack traces need parallel analysis

**DO NOT use** for:
- Simple syntax errors (use direct fix)
- Feature requests (use /orchestrator)
- Known issues with documented fixes

## Swarm Mode Integration (v2.81.1)

`/bug` uses swarm mode by default with specialized debugging teammates.

### Auto-Spawn Configuration

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  team_name: "bug-analysis-team"
  name: "bug-lead"
  mode: "delegate"
  run_in_background: true
  prompt: |
    Execute systematic debugging workflow for: $ARGUMENTS

    Debug Pattern:
    1. ANALYZE - Examine error symptoms, logs, stack traces
    2. DISTRIBUTE - Assign analysis tasks to specialists
    3. REPRODUCE - Determine conditions to reproduce issue
    4. LOCATE - Trace root cause through code
    5. FIX - Implement minimal patch
    6. VALIDATE - Ensure fix works and no regressions
```

### Team Composition

| Role | Purpose | Specialization |
|------|---------|----------------|
| **Coordinator** | Debug workflow orchestration | Manages bug lifecycle, synthesizes findings |
| **Teammate 1** | Error Analysis specialist | Stack traces, error messages, log patterns specialist |
| **Teammate 2** | Code Archaeologist specialist | Root cause location, code path tracing specialist |
| **Teammate 3** | Fix Validator specialist | Patch validation, regression prevention specialist |

### Swarm Mode Workflow

```
User invokes: /bug "Authentication fails after 30 minutes"

1. Team "bug-analysis-team" created
2. Coordinator (bug-lead) receives bug description
3. 3 Teammates spawned with debugging specializations
4. Analysis tasks distributed:
   - Teammate 1 → Error Analysis (symptoms, logs)
   - Teammate 2 → Root Cause (token expiration logic)
   - Teammate 3 → Fix Validation (test coverage)
5. Teammates work in parallel (background execution)
6. Coordinator monitors progress and gathers findings
7. Root cause identified + fix proposed + validation tests created
8. Final bug report + patch + tests returned
```

### Parallel Debugging Pattern

Each teammate focuses on their analysis aspect:

```yaml
# Teammate 1: Error Analysis
- Extract stack trace
- Identify error type (TypeError, AuthError, etc.)
- Analyze log patterns around error
- Document symptoms and conditions

# Teammate 2: Root Cause Archaeology
- Trace execution path leading to error
- Identify where token validation occurs
- Find JWT expiration check logic
- Determine why 30-minute timeout fails

# Teammate 3: Fix Validation
- Design test to reproduce issue
- Validate fix resolves issue
- Check for regressions in related code
- Ensure test coverage is adequate
```

### Communication Between Teammates

```yaml
# Teammate sends finding to coordinator
SendMessage:
  type: "message"
  recipient: "bug-lead"
  content: "Root cause found: JWT refresh not triggering at 25min"

# Coordinator assigns task
SendMessage:
  type: "message"
  recipient: "teammate-3"
  content: "Create test case for JWT refresh at 25min boundary"
```

### Task List Coordination

```bash
# Location: ~/.claude/tasks/bug-analysis-team/tasks.json

# Example tasks:
[
  {"id": "1", "subject": "Analyze error symptoms", "owner": "teammate-1"},
  {"id": "2", "subject": "Locate root cause", "owner": "teammate-2"},
  {"id": "3", "subject": "Design fix validation", "owner": "teammate-3"},
  {"id": "4", "subject": "Implement patch", "owner": "bug-lead"},
  {"id": "5", "subject": "Run validation tests", "owner": "teammate-3"}
]
```

## CLI Execution

### Basic Usage

```bash
# Analyze bug with swarm mode (default)
/bug "Authentication fails after 30 minutes"

# Specify component
/bug "Memory leak in websocket handler" --component server

# Include stack trace
/bug "TypeError: Cannot read property 'user' of undefined" --stack-trace "at auth.js:42"
```

### With Context

```bash
# Include error log
/bug "Database connection timeout" --log-file /var/log/app-error.log

# Specify git commit (regression)
/bug "Tests failing after refactor" --since abc123

# Include reproduction steps
/bug "UI freezes when loading large dataset" --steps "1. Open dashboard 2. Load 10k rows"
```

### Manual Override

```bash
# Disable swarm mode
/bug "Simple syntax error" --no-swarm

# Increase teammate count
/bug "Complex race condition" --teammates 5
```

## Output Format

### Console Output

```
╔══════════════════════════════════════════════════════════════╗
║               Bug Analysis (Swarm Mode)                      ║
╠══════════════════════════════════════════════════════════════╣
║ Bug: Authentication fails after 30 minutes                   ║
║ Team: bug-analysis-team                                       ║
╚══════════════════════════════════════════════════════════════╝

[Phase 1: ANALYZE]
├─ Teammate 1: Error symptoms identified
│  └─ TypeError at auth.js:42 (token refresh failed)
├─ Teammate 2: Execution path traced
│  └─ Token expiration check: 30min hard-coded
└─ Teammate 3: Test case designed
   └─ Reproducible at exactly 30min boundary

[Phase 2: LOCATE ROOT CAUSE]
├─ Root cause: JWT refresh logic not triggering
├─ Location: src/auth/middleware.js:145-150
└─ Issue: refreshAt calculation uses wrong timestamp

[Phase 3: FIX]
├─ Patch: Use Date.now() instead of token.iat
├─ File: src/auth/middleware.js
└─ Lines changed: 2

[Phase 4: VALIDATE]
├─ Test created: tests/auth/jwt-refresh.test.js
├─ Regression check: PASSED
└─ All tests: 42/42 PASSED

╔══════════════════════════════════════════════════════════════╗
║                    Bug Report Summary                       ║
╠══════════════════════════════════════════════════════════════╣
║ Status: FIXED                                               ║
║ Root Cause: JWT refresh timestamp calculation               ║
║ Files Modified: 1                                           ║
║ Tests Added: 1                                              ║
║ Duration: 3m 15s                                            ║
╚══════════════════════════════════════════════════════════════╝
```

### Log File Format

```json
{
  "bug_description": "Authentication fails after 30 minutes",
  "team_name": "bug-analysis-team",
  "phases": [
    {
      "phase": "ANALYZE",
      "teammate_1": {
        "role": "Error Analysis",
        "findings": ["TypeError at auth.js:42", "Token refresh failed"]
      },
      "teammate_2": {
        "role": "Root Cause Archaeology",
        "findings": ["Token expiration: 30min hard-coded", "Refresh not triggering"]
      },
      "teammate_3": {
        "role": "Fix Validation",
        "findings": ["Test case designed for 30min boundary"]
      }
    },
    {
      "phase": "LOCATE",
      "root_cause": "JWT refresh logic not triggering",
      "location": "src/auth/middleware.js:145-150",
      "issue": "refreshAt calculation uses wrong timestamp"
    },
    {
      "phase": "FIX",
      "patch": "Use Date.now() instead of token.iat",
      "file": "src/auth/middleware.js",
      "lines_changed": 2
    },
    {
      "phase": "VALIDATE",
      "test_created": "tests/auth/jwt-refresh.test.js",
      "regression_check": "PASSED",
      "all_tests": "42/42 PASSED"
    }
  ],
  "summary": {
    "status": "FIXED",
    "files_modified": 1,
    "tests_added": 1,
    "duration_ms": 195000
  }
}
```

## Output Location

```bash
# Logs saved to ~/.ralph/logs/bug-*.log
ls ~/.ralph/logs/bug-*.log

# View last bug analysis
tail -f ~/.ralph/logs/bug-latest.log

# Bug reports saved to ~/.ralph/bugs/
ls ~/.ralph/bugs/
```

## Advanced Usage

### Bug Categories

```bash
# Security bug
/bug "SQL injection in user search" --category security

# Performance bug
/bug "Response time > 5s for dashboard" --category performance

# Regression bug
/bug "Tests failing after commit abc123" --category regression
```

### With Quality Gates

```bash
# Run quality gates after fix
/bug "Fix type errors" && ralph gates

# Gates run automatically within validation phase
```

## Related Commands

### Orchestration Commands
- `/orchestrator` - Full workflow (includes bug analysis)
- `/loop` - Iterative execution until VERIFIED_DONE
- `/gates` - Quality gate validation

### Analysis Commands
- `/adversarial` - Security-focused validation
- `/security` - Security audit
- `/codex` - Codex CLI for complex debugging

## Examples

### Example 1: Authentication Bug

```bash
/bug "Authentication fails after 30 minutes"
```

**Output**:
- Teammate 1 identifies: TypeError at auth.js:42
- Teammate 2 locates: JWT refresh not triggering
- Teammate 3 validates: Fix + test + no regressions
- FIXED in 3m 15s

### Example 2: Memory Leak

```bash
/bug "Memory leak in websocket handler" --component server
```

**Output**:
- Teammate 1: Heap analysis shows growing array
- Teammate 2: Unclosed connections in event handler
- Teammate 3: Connection pool fix + leak test
- FIXED in 5m 42s

### Example 3: Race Condition

```bash
/bug "Race condition in payment processing" --teammates 5
```

**Output**:
- Multiple teammates analyze different code paths
- Parallel reproduction attempts
- Distributed lock fix + comprehensive tests
- FIXED in 8m 30s

## Troubleshooting

### Bug Not Reproducible

```
[Phase 2: REPRODUCE]
├─ Teammate 1: Unable to reproduce locally
├─ Teammate 2: Needs production environment data
└─ STATUS: INSUFFICIENT INFORMATION

Suggestions:
- Add more context: logs, stack traces, reproduction steps
- Specify environment: browser, Node version, OS
- Include error frequency: always, intermittent, rare
```

### Multiple Root Causes

```
[Phase 2: LOCATE]
├─ Teammate 1: Found issue in auth middleware
├─ Teammate 2: Also found issue in token refresh
└─ Teammate 3: Both contribute to the failure

Coordinator: Multiple root causes identified
Recommendation: Fix in priority order (middleware → refresh)
```

## Best Practices

1. **Provide context**: Include logs, stack traces, reproduction steps
2. **Be specific**: "Fails after 30 minutes" > "Auth doesn't work"
3. **Specify component**: Help teammates narrow search
4. **Use swarm mode**: Let specialists work in parallel
5. **Review findings**: Coordinator synthesizes all perspectives
6. **Validate fixes**: Ensure no regressions before merging

---

**Version**: 2.81.1 | **Status**: SWARM MODE ENABLED | **Team Size**: 4 agents
