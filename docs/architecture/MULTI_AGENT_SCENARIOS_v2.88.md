# Multi-Agent Execution Scenarios v2.88.0

**Date**: 2026-02-14
**Version**: 2.88.0
**Status**: FINAL
**Related**: [Agent Teams Documentation](https://code.claude.com/docs/en/agent-teams)

## Executive Summary

The Ralph system supports three distinct execution scenarios for multi-agent coordination. This document provides a comprehensive analysis of each scenario, their trade-offs, and optimal use cases.

### Quick Reference

| Scenario | Skills | Pattern |
|----------|--------|---------|
| **C (Integrated)** | 7 | Complex, multi-phase, quality-critical |
| **B (Custom Subagents)** | 2 | Specialized, less coordination |
| **A (Pure Agent Teams)** | 3 | Simple coordination, low specialization |

---

## Scenario Definitions

### Scenario A: Pure Agent Teams

**Description**: Uses native Claude Code team coordination with built-in tools.

**Tools**:
- `TeamCreate` - Create team with shared task list
- `Task` - Spawn agents with native types
- `TaskCreate` - Create tasks for coordination
- `TaskUpdate` - Update task status
- `SendMessage` - Inter-agent communication

**Architecture**:
```
+------------------+
|   TeamCreate     |  ← Creates team structure
+------------------+
         │
         ▼
+------------------+     +------------------+
|   Task Spawn     │────▶│  Native Agents   │
+------------------+     +------------------+
         │                       │
         ▼                       ▼
+------------------+     +------------------+
|   Task List      │◀────│  Coordination    │
+------------------+     +------------------+
```

**Pros**:
- Native Claude Code integration
- Automatic task coordination via `~/.claude/tasks/{team-name}/`
- Built-in quality gates via hooks (`TeammateIdle`, `TaskCompleted`)
- Seamless message passing between agents

**Cons**:
- Limited to built-in agent types
- Less customization of agent behavior
- No tool restrictions per agent

**Best For**:
- Tasks requiring tight coordination
- Simple workflows without specialization
- Quick prototypes and testing

**Configuration**:
```yaml
# No custom agents needed
TeamCreate(team_name="my-project")
Task(subagent_type="general-purpose", team_name="my-project")
```

---

### Scenario B: Pure Custom Subagents

**Description**: Direct spawn of specialized `ralph-*` agents without team coordination overhead.

**Available Subagents**:

| Agent | Role | Tools | Max Turns |
|-------|------|-------|-----------|
| `ralph-coder` | Code implementation | Read, Edit, Write, Bash | 50 |
| `ralph-reviewer` | Code review | Read, Grep, Glob | 25 |
| `ralph-tester` | Testing & QA | Read, Edit, Write, Bash(test) | 30 |
| `ralph-researcher` | Research | Read, Grep, Glob, WebSearch, WebFetch | 20 |

**Architecture**:
```
+------------------+
|   Task Spawn     │
+------------------+
         │
         ├────────────┬────────────┬────────────┐
         ▼            ▼            ▼            ▼
+--------+----+ +-----+------+ +----+-------+ +----+-------+
| ralph-coder | | ralph-     | | ralph-     | | ralph-     |
|             | | reviewer   | | tester     | | researcher |
+-------------+ +------------+ +------------+ +------------+
      │               │              │              │
      └───────────────┴──────────────┴──────────────┘
                         │
                         ▼
                  Independent
                   Execution
```

**Pros**:
- Full customization of agent behavior via `.claude/agents/ralph-*.md`
- Tool restrictions per agent type (e.g., tester can only run test commands)
- Model-agnostic design
- Ralph quality standards built-in
- No team overhead for simple tasks

**Cons**:
- No automatic task coordination
- Manual message passing if needed
- No built-in quality gates from Agent Teams
- Requires explicit coordination logic

**Best For**:
- Specialized tasks (testing, review, coding)
- Independent execution without coordination
- Quality-focused workflows
- Scenarios where tool restrictions matter

**Configuration**:
```yaml
# Direct spawn without TeamCreate
Task(subagent_type="ralph-reviewer", prompt="Review src/auth.ts")
Task(subagent_type="ralph-tester", prompt="Run tests for auth module")
```

---

### Scenario C: Integrated (Agent Teams + Custom Subagents)

**Description**: Combines native team coordination with specialized custom agents and quality validation hooks. This is the most powerful scenario for production-grade workflows.

**Architecture**:
```
+------------------+
|   TeamCreate     │  ← Team structure
+------------------+
         │
         ▼
+------------------+     +---------------------------+
|   TaskCreate     │────▶│  Shared Task List         │
+------------------+     │  ~/.claude/tasks/{team}/  │
         │               +---------------------------+
         ▼                        ▲
+------------------+              │
|  Spawn ralph-*   │──────────────┘
+------------------+
         │
         ├────────────┬────────────┐
         ▼            ▼            ▼
+--------+----+ +-----+------+ +----+-------+
| ralph-coder | | ralph-     | | ralph-     |
|             | | reviewer   | | tester     |
+-------------+ +------------+ +------------+
         │               │              │
         └───────────────┴──────────────┘
                         │
                         ▼
+------------------+
| Quality Hooks    │  ← TeammateIdle, TaskCompleted
+------------------+
         │
         ▼
+------------------+
|  VERIFIED_DONE   │  ← Only when all gates pass
+------------------+
```

**Quality Gate Hooks**:

| Hook | Trigger | Purpose | Exit 2 Behavior |
|------|---------|---------|-----------------|
| `TeammateIdle` | Agent goes idle | Quality validation before idle | Keep working + feedback |
| `TaskCompleted` | Task marked complete | Final validation gate | Prevent completion + feedback |
| `SubagentStart` | Subagent spawns | Load Ralph context | - |
| `SubagentStop` | Subagent stops | Quality validation on stop | - |

**VERIFIED_DONE Pattern**:
```bash
# TeammateIdle hook validates work quality
if ! quality_gates_pass; then
    echo '{"decision": "block", "reason": "Fix console.log statements"}'
    exit 2  # Keep agent working with feedback
fi

# TaskCompleted hook validates completion
if ! all_requirements_met; then
    echo '{"decision": "block", "reason": "Missing test coverage"}'
    exit 2  # Prevent completion
fi

# Both gates pass
echo '{"decision": "approve"}'
exit 0  # VERIFIED_DONE
```

**Pros**:
- Native task coordination from Agent Teams
- Custom agent specialization from ralph-* subagents
- Quality gates via hooks for VERIFIED_DONE guarantee
- Tool restrictions per agent type
- Automatic message delivery
- Task list coordination for complex workflows

**Cons**:
- More complex setup
- Requires understanding both Agent Teams and Custom Subagents
- Potential configuration overhead

**Best For**:
- Production-grade workflows
- Complex multi-phase tasks
- Mission-critical operations
- Tasks requiring both coordination AND specialization

**Configuration**:
```yaml
# 1. Create team
TeamCreate(team_name="my-project", description="Feature implementation")

# 2. Create tasks
TaskCreate(subject="Implement auth", description="Add OAuth2")

# 3. Spawn specialized agents
Task(subagent_type="ralph-coder", team_name="my-project")
Task(subagent_type="ralph-reviewer", team_name="my-project")
Task(subagent_type="ralph-tester", team_name="my-project")

# 4. Hooks validate quality automatically
# 5. VERIFIED_DONE when all gates pass
```

---

## Evaluation Criteria

Each skill is evaluated against five criteria with the following weights:

| Criterion | Weight | Description |
|-----------|--------|-------------|
| **Coordination Need** | 25% | How much inter-agent coordination is required |
| **Specialization Need** | 25% | How specialized the agents need to be |
| **Quality Gate Need** | 20% | Importance of quality validation |
| **Tool Restriction Need** | 15% | Need for restricted tool access |
| **Scalability** | 15% | Ability to scale with task complexity |

---

## Skill Scenario Assignments

### Scenario C (Integrated) - 7 Skills

| Skill | Score | Rationale |
|-------|-------|-----------|
| **orchestrator** | 9.5/10 | Multi-phase workflow, VERIFIED_DONE pattern, specialized phases |
| **parallel** | 9.0/10 | Multiple files, coordinated distribution, results aggregation |
| **loop** | 8.5/10 | Iterative execution, state tracking, quality gates critical |
| **quality-gates-parallel** | 8.5/10 | Parallel execution, quality gates core functionality |
| **security** | 8.0/10 | Security scanning coordination, specialized patterns, tool restrictions |
| **gates** | 8.0/10 | Meta-validation, multiple check types, language specialization |
| **adversarial** | 8.0/10 | Multi-agent attack coordination, specialized roles, quality validation |

### Scenario B (Custom Subagents) - 2 Skills

| Skill | Score | Rationale |
|-------|-------|-----------|
| **bugs** | 7.5/10 | Independent scanning, specialization > coordination, simpler setup |
| **code-reviewer** | 7.0/10 | Single-purpose review, existing parallel pattern, less coordination |

### Scenario A (Pure Agent Teams) - 3 Skills

| Skill | Score | Rationale |
|-------|-------|-----------|
| **clarify** | 6.5/10 | Sequential questions, simple coordination, no specialization |
| **retrospective** | 6.0/10 | Single-threaded analysis, general analysis, simple workflow |
| **glm5-parallel** | 7.0/10 | Same agent type, simple parallelism, no complex quality needs |

---

## Decision Tree

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MULTI-AGENT SCENARIO DECISION TREE                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   START: What does your task require?                                        │
│                                                                              │
│   1. Does the task require tight coordination between agents?                │
│                    │                                                         │
│         ┌──────────┴──────────┐                                              │
│         ▼                     ▼                                              │
│       YES                    NO                                              │
│         │                     │                                              │
│         │                     └──► SCENARIO B (Custom Subagents)             │
│         │                           - Direct spawn of ralph-* agents         │
│         │                           - No team overhead                       │
│         │                           - Best for: bugs, code-reviewer          │
│         │                                                                     │
│   2. Does it need specialized agents?                                        │
│         │                                                                     │
│    ┌────┴────┐                                                               │
│    ▼         ▼                                                               │
│   YES       NO                                                               │
│    │         │                                                               │
│    │         └──► SCENARIO A (Pure Agent Teams)                              │
│    │              - Native coordination only                                 │
│    │              - No custom agents                                         │
│    │              - Best for: clarify, retrospective, glm5-parallel          │
│    │                                                                          │
│    ▼                                                                          │
│   SCENARIO C (Integrated)                                                    │
│   ┌────────────────────────────────────────┐                                 │
│   │ 1. TeamCreate for coordination         │                                 │
│   │ 2. ralph-* for specialization          │                                 │
│   │ 3. Hooks for quality gates             │                                 │
│   │ 4. VERIFIED_DONE guarantee             │                                 │
│   └────────────────────────────────────────┘                                 │
│   Best for: orchestrator, parallel, loop, security, gates,                   │
│             quality-gates-parallel, adversarial                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Templates

### Scenario A Template

```markdown
## Agent Teams Integration (v2.88)

**Optimal Scenario**: Pure Agent Teams

### Why This Scenario
- Simple coordination needs
- No specialized agent requirements
- Native tools sufficient

### Workflow
TeamCreate (optional) → Task → Execute → Complete

### Example
```bash
TeamCreate(team_name="clarify-questions")
Task(subagent_type="general-purpose", prompt="Ask clarifying questions")
```
```

### Scenario B Template

```markdown
## Agent Teams Integration (v2.88)

**Optimal Scenario**: Pure Custom Subagents

### Why This Scenario
- Specialized task execution
- Less coordination overhead needed
- Tool restrictions important

### Workflow
Task(subagent_type="ralph-*") → Execute → Report

### Example
```bash
Task(subagent_type="ralph-reviewer", prompt="Scan for bugs in src/auth/")
```
```

### Scenario C Template

```markdown
## Agent Teams Integration (v2.88)

**Optimal Scenario**: Integrated (Agent Teams + Custom Subagents)

### Why This Scenario
- Multi-phase workflow requires coordination
- Specialized agents needed for each phase
- Quality gates essential (TeammateIdle, TaskCompleted)
- VERIFIED_DONE pattern required

### Workflow
TeamCreate → TaskCreate → Spawn ralph-* → Hooks validate → VERIFIED_DONE

### Subagent Roles
| Subagent | Role |
|----------|------|
| `ralph-coder` | Implementation |
| `ralph-reviewer` | Code review |
| `ralph-tester` | Testing & QA |

### Example
```bash
TeamCreate(team_name="feature-auth", description="Auth implementation")
TaskCreate(subject="Implement OAuth2")
Task(subagent_type="ralph-coder", team_name="feature-auth")
Task(subagent_type="ralph-tester", team_name="feature-auth")
# Hooks validate automatically → VERIFIED_DONE
```
```

---

## Implementation Checklist

### For Skill Developers

When adding Agent Teams integration to a skill:

1. **Determine Scenario**:
   - [ ] Evaluate coordination need (25%)
   - [ ] Evaluate specialization need (25%)
   - [ ] Evaluate quality gate need (20%)
   - [ ] Evaluate tool restriction need (15%)
   - [ ] Evaluate scalability (15%)

2. **Add Documentation**:
   - [ ] Add "Agent Teams Integration (v2.88)" section to SKILL.md
   - [ ] Specify optimal scenario
   - [ ] Explain why this scenario
   - [ ] Document subagent roles (if Scenario B or C)
   - [ ] Include workflow pattern

3. **Test Integration**:
   - [ ] Verify hook registration
   - [ ] Test agent spawning
   - [ ] Validate quality gates (if Scenario C)
   - [ ] Run `scripts/validate-agent-teams-integration.sh`

### For Hook Developers

Quality gate hooks for Scenario C:

```bash
# teammate-idle-quality-gate.sh
#!/bin/bash
# Validates work quality before agent goes idle

# Check for blocking patterns
if grep -rq "console.log\|debugger\|TODO:" "$WORKING_DIR"; then
    echo '{"decision": "block", "reason": "Remove debug code"}'
    exit 2
fi

echo '{"decision": "approve"}'
exit 0
```

```bash
# task-completed-quality-gate.sh
#!/bin/bash
# Validates task completion requirements

# Check all requirements met
if ! all_requirements_satisfied; then
    echo '{"decision": "block", "reason": "Missing requirements"}'
    exit 2
fi

echo '{"decision": "approve"}'
exit 0
```

---

## References

- [Claude Code Agent Teams Docs](https://code.claude.com/docs/en/agent-teams)
- [Claude Code Subagents Docs](https://code.claude.com/docs/en/sub-agents)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [claude-sneakpeek](https://github.com/mikekelly/claude-sneakpeek) - Zai variant and swarm mode
- [SCENARIO_FINAL_DECISIONS_v2.88.md](./SCENARIO_FINAL_DECISIONS_v2.88.md) - Detailed skill decisions
- [AGENT_TEAMS_SCENARIO_ANALYSIS_v2.88.md](./AGENT_TEAMS_SCENARIO_ANALYSIS_v2.88.md) - Analysis framework
