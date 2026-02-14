# Scenario Preliminary Analysis v2.88.0

**Date**: 2026-02-14
**Status**: PRELIMINARY (pending test results)

## Quick Reference: Scenario Characteristics

| Feature | Scenario A (Agent Teams) | Scenario B (Custom Subagents) | Scenario C (Integrated) |
|---------|-------------------------|------------------------------|------------------------|
| **Coordination** | ✅ Native (TeamCreate, Task) | ❌ Manual | ✅ Native |
| **Task List** | ✅ Automatic | ❌ Manual | ✅ Automatic |
| **Message Passing** | ✅ Automatic | ❌ Manual | ✅ Automatic |
| **Quality Gates** | ✅ TeammateIdle, TaskCompleted | ❌ None | ✅ TeammateIdle, TaskCompleted |
| **Tool Restrictions** | ❌ Limited | ✅ Per-agent | ✅ Per-agent |
| **Specialization** | ❌ Generic types | ✅ ralph-* types | ✅ ralph-* types |
| **Model Selection** | ❌ Shared | ✅ Inherited | ✅ Inherited |
| **Setup Complexity** | ⭐ Low | ⭐⭐ Medium | ⭐⭐⭐ Higher |

## Skill-by-Skill Preliminary Analysis

### 1. orchestrator (CRITICAL)

**Requirements**:
- High coordination: Multi-phase workflow (clarify → classify → plan → implement → validate)
- High quality gates: VERIFIED_DONE pattern requires strict validation
- High specialization: Different agents for different phases
- High scalability: Must handle complexity 1-10

**Preliminary Recommendation**: **Scenario C (Integrated)**
- Coordination is critical for multi-phase workflow
- Quality gates essential for VERIFIED_DONE
- Specialization needed for each phase (coder, reviewer, tester)
- Score Estimate: 9.5/10

### 2. parallel (HIGH)

**Requirements**:
- High coordination: Multiple agents working on different files
- Medium quality gates: Results need validation
- High specialization: Coders for implementation
- High scalability: More files = more agents

**Preliminary Recommendation**: **Scenario C (Integrated)**
- Coordination essential for file distribution
- Specialization for coding tasks
- Quality gates for result validation
- Score Estimate: 9.0/10

### 3. loop (HIGH)

**Requirements**:
- High coordination: Iterative phases need state tracking
- High quality gates: Loop until VERIFIED_DONE
- Medium specialization: Coder + Tester alternating
- Medium scalability: Complexity determines iterations

**Preliminary Recommendation**: **Scenario C (Integrated)**
- Quality gates critical for loop termination
- Coordination for state tracking
- Score Estimate: 8.5/10

### 4. security (HIGH)

**Requirements**:
- Medium coordination: Scanners work independently
- High quality gates: Security findings must be validated
- High specialization: Security-focused analysis
- High scalability: More code = more scanning

**Preliminary Recommendation**: **Scenario C (Integrated)** or **Scenario B**
- Specialization critical for security analysis
- Quality gates for finding validation
- Could work with Scenario B if coordination minimal
- Score Estimate: 8.0/10

### 5. bugs (HIGH)

**Requirements**:
- Low-Medium coordination: Scanners work independently
- Medium quality gates: Bug findings need validation
- High specialization: Bug detection patterns
- Medium scalability: Depends on codebase size

**Preliminary Recommendation**: **Scenario B (Custom Subagents)**
- Specialization is key
- Less coordination needed
- Could be simpler with pure subagents
- Score Estimate: 7.5/10

### 6. gates (MEDIUM)

**Requirements**:
- Low coordination: Quality checks are independent
- High quality gates: This IS the quality gate
- High specialization: Different tools for different languages
- Medium scalability: Depends on languages

**Preliminary Recommendation**: **Scenario C (Integrated)**
- Quality gates meta-pattern (hooks)
- Specialization for language-specific tools
- Score Estimate: 8.0/10

### 7. code-reviewer (MEDIUM)

**Requirements**:
- Low coordination: Review is single-threaded
- Medium quality gates: Review quality matters
- High specialization: Review patterns
- Low scalability: Single PR review

**Preliminary Recommendation**: **Scenario B (Custom Subagents)**
- Already uses 4 parallel agents natively
- Less coordination needed
- Specialization more important
- Score Estimate: 7.0/10

### 8. quality-gates-parallel (MEDIUM)

**Requirements**:
- High coordination: 4 parallel quality checks
- High quality gates: This IS the quality system
- Medium specialization: Test, lint, type, security
- High scalability: More checks = more agents

**Preliminary Recommendation**: **Scenario C (Integrated)**
- Designed for parallel execution
- Quality gates essential
- Score Estimate: 8.5/10

### 9. adversarial (MEDIUM)

**Requirements**:
- High coordination: Multi-agent attack analysis
- Medium quality gates: Findings need validation
- High specialization: Attacker, Evaluator, Mutator roles
- Medium scalability: Depends on attack surface

**Preliminary Recommendation**: **Scenario C (Integrated)**
- Multi-agent coordination essential
- Specialized roles needed
- Score Estimate: 8.0/10

### 10. clarify (MEDIUM)

**Requirements**:
- Low coordination: Sequential questions
- Low quality gates: Information gathering
- Medium specialization: Research + question patterns
- Low scalability: Usually single-pass

**Preliminary Recommendation**: **Scenario A (Agent Teams)** or **Scenario B**
- Simple coordination needs
- Could work with native teams
- Less complexity needed
- Score Estimate: 6.5/10

### 11. retrospective (LOW)

**Requirements**:
- Low coordination: Sequential analysis
- Low quality gates: Information gathering
- Low specialization: General analysis
- Low scalability: Single task analysis

**Preliminary Recommendation**: **Scenario A (Agent Teams)**
- Simple task
- No complex coordination
- Native teams sufficient
- Score Estimate: 6.0/10

### 12. glm5-parallel (LOW)

**Requirements**:
- High coordination: Parallel GLM-5 execution
- Low quality gates: Just execution
- Low specialization: Same agent type
- High scalability: More files = more agents

**Preliminary Recommendation**: **Scenario A (Agent Teams)**
- Same agent type (no specialization needed)
- Coordination for parallel execution
- Simple quality needs
- Score Estimate: 7.0/10

## Summary Table

| Skill | Priority | Recommended Scenario | Score Est. |
|-------|----------|---------------------|------------|
| orchestrator | CRITICAL | C (Integrated) | 9.5/10 |
| parallel | HIGH | C (Integrated) | 9.0/10 |
| loop | HIGH | C (Integrated) | 8.5/10 |
| security | HIGH | C/B (Integrated/Custom) | 8.0/10 |
| bugs | HIGH | B (Custom Subagents) | 7.5/10 |
| gates | MEDIUM | C (Integrated) | 8.0/10 |
| code-reviewer | MEDIUM | B (Custom Subagents) | 7.0/10 |
| quality-gates-parallel | MEDIUM | C (Integrated) | 8.5/10 |
| adversarial | MEDIUM | C (Integrated) | 8.0/10 |
| clarify | MEDIUM | A (Agent Teams) | 6.5/10 |
| retrospective | LOW | A (Agent Teams) | 6.0/10 |
| glm5-parallel | LOW | A (Agent Teams) | 7.0/10 |

## Pattern Recognition

### Scenario C (Integrated) - 6 skills
**Best for**: Complex, multi-phase, quality-critical tasks
- orchestrator, parallel, loop, security, gates, quality-gates-parallel, adversarial

### Scenario B (Custom Subagents) - 2 skills
**Best for**: Specialized, less coordination, tool-restriction critical
- bugs, code-reviewer

### Scenario A (Pure Agent Teams) - 3 skills
**Best for**: Simple coordination, low specialization needs
- clarify, retrospective, glm5-parallel

---

**NEXT**: Validate with test results from agents
