# Agent Teams Scenario Final Decisions v2.88.0

**Date**: 2026-02-14
**Version**: 2.88.0
**Status**: FINAL

## Executive Decision Summary

After analyzing the three scenarios across 12 skills, the following pattern emerges:

### Scenario Distribution

| Scenario | Skills | Pattern |
|----------|--------|---------|
| **C (Integrated)** | 7 | Complex, multi-phase, quality-critical |
| **B (Custom Subagents)** | 2 | Specialized, less coordination |
| **A (Pure Agent Teams)** | 3 | Simple coordination, low specialization |

## Final Decisions by Skill

### 1. orchestrator → **SCENARIO C (Integrated)**

**Rationale**:
- Multi-phase workflow requires tight coordination
- VERIFIED_DONE pattern needs quality gates (TeammateIdle, TaskCompleted)
- Each phase benefits from specialized agents (coder, reviewer, tester)
- Task list coordination essential for phase tracking

**Implementation**:
```
TeamCreate → TaskCreate (phases) → Spawn ralph-* → Hooks validate → VERIFIED_DONE
```

**Score**: 9.5/10

---

### 2. parallel → **SCENARIO C (Integrated)**

**Rationale**:
- Multiple files require coordinated distribution
- Results need quality validation
- Specialization for different file types
- Scalability with task complexity

**Implementation**:
```
TeamCreate → TaskCreate (files) → Spawn ralph-coder (multiple) → Task coordination → Hooks validate
```

**Score**: 9.0/10

---

### 3. loop → **SCENARIO C (Integrated)**

**Rationale**:
- Iterative execution requires state tracking
- Quality gates critical for loop termination
- Alternating between coder and tester
- Coordination for iteration state

**Implementation**:
```
TeamCreate → Loop: Spawn ralph-coder → Spawn ralph-tester → Hooks validate → Continue/Done
```

**Score**: 8.5/10

---

### 4. security → **SCENARIO C (Integrated)**

**Rationale**:
- Security scanning needs coordination for coverage
- Findings require quality validation
- Specialized security patterns
- Tool restrictions important

**Implementation**:
```
TeamCreate → Spawn ralph-reviewer (security focus) → Hooks validate findings → Report
```

**Score**: 8.0/10

---

### 5. bugs → **SCENARIO B (Custom Subagents)**

**Rationale**:
- Bug scanning is mostly independent
- Less coordination overhead needed
- Specialization more important than coordination
- Simpler setup without team overhead

**Implementation**:
```
Task(subagent_type="ralph-reviewer") → Scan → Report
No TeamCreate needed for single-purpose tasks
```

**Score**: 7.5/10

---

### 6. gates → **SCENARIO C (Integrated)**

**Rationale**:
- Quality gates are meta-validation
- Multiple check types need coordination
- Quality hooks essential (this IS the quality system)
- Language-specific specialization

**Implementation**:
```
TeamCreate → Spawn ralph-tester (per language) → Hooks validate → Aggregate results
```

**Score**: 8.0/10

---

### 7. code-reviewer → **SCENARIO B (Custom Subagents)**

**Rationale**:
- Already uses 4 parallel agents natively
- Single-purpose: review code
- Less coordination needed
- Specialization more important

**Implementation**:
```
Task(subagent_type="ralph-reviewer") × 4 → Parallel review → Aggregate
Works with existing parallel pattern
```

**Score**: 7.0/10

---

### 8. quality-gates-parallel → **SCENARIO C (Integrated)**

**Rationale**:
- Designed for parallel execution
- Quality gates are core functionality
- 4 different check types need coordination
- Hooks for validation

**Implementation**:
```
TeamCreate → TaskCreate (4 checks) → Spawn agents → Hooks validate → Aggregate
```

**Score**: 8.5/10

---

### 9. adversarial → **SCENARIO C (Integrated)**

**Rationale**:
- Multi-agent attack coordination
- Specialized roles (Attacker, Evaluator, Mutator)
- Quality gates for finding validation
- Coordination for attack strategy

**Implementation**:
```
TeamCreate → Spawn ralph-reviewer (attacker) → Spawn ralph-researcher (strategist) → Hooks validate
```

**Score**: 8.0/10

---

### 10. clarify → **SCENARIO A (Pure Agent Teams)**

**Rationale**:
- Sequential question flow
- Simple coordination needs
- No specialized tools required
- Lower complexity

**Implementation**:
```
TeamCreate → AskUserQuestion → Process response → Complete
Native teams sufficient
```

**Score**: 6.5/10

---

### 11. retrospective → **SCENARIO A (Pure Agent Teams)**

**Rationale**:
- Single-threaded analysis
- No complex coordination
- General analysis, no specialization
- Simple workflow

**Implementation**:
```
TeamCreate (optional) → Analyze session → Generate recommendations
Could even work without teams
```

**Score**: 6.0/10

---

### 12. glm5-parallel → **SCENARIO A (Pure Agent Teams)**

**Rationale**:
- Same agent type (no specialization variance)
- Simple parallel execution
- Coordination for distribution
- No complex quality needs

**Implementation**:
```
TeamCreate → Spawn multiple agents (same type) → Parallel execute → Aggregate
Native teams sufficient for same-type parallelism
```

**Score**: 7.0/10

---

## Implementation Matrix

| Skill | Scenario | TeamCreate | Custom Agents | Hooks | Priority |
|-------|----------|------------|---------------|-------|----------|
| orchestrator | C | ✅ | ralph-* | ✅ | CRITICAL |
| parallel | C | ✅ | ralph-coder | ✅ | HIGH |
| loop | C | ✅ | ralph-coder/tester | ✅ | HIGH |
| security | C | ✅ | ralph-reviewer | ✅ | HIGH |
| bugs | B | ❌ | ralph-reviewer | ❌ | HIGH |
| gates | C | ✅ | ralph-tester | ✅ | MEDIUM |
| code-reviewer | B | ❌ | ralph-reviewer | ❌ | MEDIUM |
| quality-gates-parallel | C | ✅ | ralph-* | ✅ | MEDIUM |
| adversarial | C | ✅ | ralph-* | ✅ | MEDIUM |
| clarify | A | ✅ | native | ✅ | MEDIUM |
| retrospective | A | ✅ | native | ✅ | LOW |
| glm5-parallel | A | ✅ | native | ✅ | LOW |

## Configuration Templates

### Scenario C (Integrated) Template
```markdown
## Agent Teams Integration (v2.88)

**Optimal Scenario**: Integrated (Agent Teams + Custom Subagents)

### Configuration
1. **TeamCreate**: Create team on skill invocation
2. **TaskCreate**: Create tasks for each phase/file
3. **Spawn**: Use ralph-* subagent types
4. **Hooks**: TeammateIdle + TaskCompleted for quality gates
5. **Coordination**: Shared task list + SendMessage

### Workflow
TeamCreate → TaskCreate → Task(ralph-*) → Hooks validate → VERIFIED_DONE
```

### Scenario B (Custom Subagents) Template
```markdown
## Agent Teams Integration (v2.88)

**Optimal Scenario**: Pure Custom Subagents

### Configuration
1. **No TeamCreate**: Direct Task spawn
2. **Task**: Use ralph-* subagent types
3. **No Hooks**: Rely on agent quality standards
4. **Simpler**: Less overhead for specialized tasks

### Workflow
Task(subagent_type="ralph-*") → Execute → Report
```

### Scenario A (Pure Agent Teams) Template
```markdown
## Agent Teams Integration (v2.88)

**Optimal Scenario**: Pure Agent Teams

### Configuration
1. **TeamCreate**: Optional team for coordination
2. **Task**: Use native agent types
3. **Hooks**: TeammateIdle + TaskCompleted available
4. **Simple**: Native coordination sufficient

### Workflow
TeamCreate (optional) → Task → Execute → Complete
```

---

## Validation Checklist

- [ ] Update orchestrator skill with Scenario C
- [ ] Update parallel skill with Scenario C
- [ ] Update loop skill with Scenario C
- [ ] Update security skill with Scenario C
- [ ] Update bugs skill with Scenario B
- [ ] Update gates skill with Scenario C
- [ ] Update code-reviewer skill with Scenario B
- [ ] Update quality-gates-parallel skill with Scenario C
- [ ] Update adversarial skill with Scenario C
- [ ] Update clarify skill with Scenario A
- [ ] Update retrospective skill with Scenario A
- [ ] Update glm5-parallel skill with Scenario A
- [ ] Run test suite to validate
- [ ] Commit and push changes
