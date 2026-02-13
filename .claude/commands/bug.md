---
name: bug
prefix: "@bug"
category: review
color: red
description: "Debugging with swarm mode: analyze, reproduce, fix, validate systematically"
argument-hint: "<bug description> [--swarm] [--no-swarm]"
version: 2.81.1
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
+-------------------------------------------------------------------+
|                    DEBUGGING SWARM MODE                           |
+-------------------------------------------------------------------+
|                                                                   |
|   +-------------+   +--------------+   +-----------+   +--------+ |
|   |   ANALYZE   |-->|  REPRODUCE   |-->|  LOCATE   |-->|  FIX   | |
|   |   Error     |   |   Issue      |   |   Root    |   |Validate| |
|   +-------------+   +--------------+   +-----------+   +--------+ |
|         |                 |                  |             |      |
|         +-----------------+------------------+-------------+      |
|                            |                                      |
|                            v                                      |
|                   +------------------+                            |
|                   | Bug Coordinator  |                            |
|                   |  (bug-lead)      |                            |
|                   +------------------+                            |
|                                                                   |
+-------------------------------------------------------------------+
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

### Team Composition

| Role | Purpose | Specialization |
|------|---------|----------------|
| **Coordinator** | Debug workflow orchestration | Manages bug lifecycle, synthesizes findings |
| **Teammate 1** | Error Analysis specialist | Stack traces, error messages, log patterns |
| **Teammate 2** | Code Archaeologist | Root cause location, code path tracing |
| **Teammate 3** | Fix Validator | Patch validation, regression prevention |

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

## Output Location

```bash
# Logs saved to ~/.ralph/logs/bug-*.log
ls ~/.ralph/logs/bug-*.log

# Bug reports saved to ~/.ralph/bugs/
ls ~/.ralph/bugs/
```

## Related Commands

- `/orchestrator` - Full workflow (includes bug analysis)
- `/loop` - Iterative execution until VERIFIED_DONE
- `/gates` - Quality gate validation
- `/adversarial` - Security-focused validation
- `/security` - Security audit

---

**Version**: 2.81.1 | **Status**: SWARM MODE ENABLED | **Team Size**: 4 agents
