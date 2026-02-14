# Agent Teams vs Custom Subagents vs Integrated: Scenario Analysis v2.88.0

**Date**: 2026-02-14
**Version**: 2.88.0
**Status**: ANALYSIS IN PROGRESS

## Executive Summary

This document analyzes three scenarios for multi-agent execution in the Ralph system:
1. **Scenario A**: Pure Agent Teams (native Claude Code teams)
2. **Scenario B**: Pure Custom Subagents (ralph-* agents)
3. **Scenario C**: Integrated (Agent Teams + Custom Subagents combined)

## Scenario Definitions

### Scenario A: Pure Agent Teams

**Characteristics**:
- Uses native `TeamCreate`, `Task`, `TaskCreate`, `TaskUpdate`, `SendMessage` tools
- Team coordination via shared task list at `~/.claude/tasks/{team-name}/`
- Built-in hooks: `TeammateIdle`, `TaskCompleted`, `SubagentStart`, `SubagentStop`
- Automatic message delivery between agents
- No custom subagent types - uses built-in agent types

**Pros**:
- Native Claude Code integration
- Automatic task coordination
- Built-in quality gates via hooks
- Seamless message passing

**Cons**:
- Limited to available built-in agent types
- Less customization of agent behavior
- Shared model selection for all agents

**Best For**:
- Tasks requiring tight coordination
- Scenarios needing quality gates
- Complex multi-step workflows

### Scenario B: Pure Custom Subagents

**Characteristics**:
- Uses `Task` tool with `subagent_type="ralph-*"`
- Custom agent definitions in `.claude/agents/ralph-*.md`
- Model inheritance from settings.json
- Custom tool restrictions per agent type
- Manual coordination required

**Pros**:
- Full customization of agent behavior
- Model-agnostic design
- Tool restriction per agent type
- Ralph quality standards built-in

**Cons**:
- No automatic task coordination
- Manual message passing
- No built-in quality gates
- Requires explicit coordination

**Best For**:
- Specialized tasks (testing, review, coding)
- When tool restrictions matter
- Quality-focused workflows

### Scenario C: Integrated (Agent Teams + Custom Subagents)

**Characteristics**:
- Uses `TeamCreate` for team structure
- Spawns `ralph-*` subagents within team
- Combines native coordination with custom agents
- Best of both worlds: coordination + specialization

**Pros**:
- Native task coordination
- Custom agent specialization
- Quality gates via TeammateIdle/TaskCompleted
- Tool restrictions per agent type
- Model inheritance support

**Cons**:
- More complex setup
- Requires understanding both systems
- Potential configuration overhead

**Best For**:
- Production-grade workflows
- Complex multi-phase tasks
- Mission-critical operations

## Evaluation Criteria

For each skill, we evaluate:

| Criterion | Weight | Description |
|-----------|--------|-------------|
| **Coordination Need** | 25% | How much inter-agent coordination is required |
| **Specialization Need** | 25% | How specialized the agents need to be |
| **Quality Gate Need** | 20% | Importance of quality validation |
| **Tool Restriction Need** | 15% | Need for restricted tool access |
| **Scalability** | 15% | Ability to scale with task complexity |

## Skills Analysis Matrix

### Priority Order (by importance)

1. **orchestrator** - Master workflow coordinator
2. **parallel** - Parallel execution engine
3. **loop** - Iterative execution
4. **security** - Security analysis
5. **bugs** - Bug detection
6. **gates** - Quality validation
7. **code-reviewer** - Code review
8. **quality-gates-parallel** - Parallel quality checks
9. **adversarial** - Attack analysis
10. **clarify** - Requirement gathering
11. **retrospective** - Post-task analysis
12. **glm5-parallel** - GLM-5 parallel execution

## Test Scenarios

### Test 1: Single Agent Task
- Spawn 1 agent
- Execute simple task
- Measure: latency, accuracy, resource usage

### Test 2: Multi-Agent Coordination
- Spawn 3+ agents
- Require coordination via task list
- Measure: coordination overhead, completion time

### Test 3: Quality Gate Validation
- Execute task with quality requirements
- Trigger TeammateIdle and TaskCompleted hooks
- Measure: quality enforcement effectiveness

### Test 4: Tool Restriction Enforcement
- Spawn agent with restricted tools
- Attempt restricted operation
- Measure: restriction enforcement

### Test 5: Scalability Test
- Increase task complexity
- Measure: performance degradation

## Results (To Be Populated)

### orchestrator
- **Best Scenario**: TBD
- **Rationale**: TBD
- **Configuration**: TBD

### parallel
- **Best Scenario**: TBD
- **Rationale**: TBD
- **Configuration**: TBD

[... remaining skills ...]

## Recommendations

[To be populated after testing]

## Implementation Plan

[To be populated after analysis]

---

**Next Steps**:
1. Execute test scenarios for each skill
2. Measure and record results
3. Determine optimal scenario per skill
4. Update skill configurations
5. Document final recommendations
