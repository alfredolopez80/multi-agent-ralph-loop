# Aristotle First Principles Deconstructor

Foundational methodology for Multi-Agent Ralph. Every problem, task, or decision passes through these 5 phases before execution.

Source: [godofprompt](https://x.com/godofprompt/status/2037606967766643044)

## The 5 Phases

### Phase 1: Assumption Autopsy

Identify ALL inherited assumptions in how the problem was framed.

> "80% of your 'problem' is inherited assumptions you never questioned."

**Questions to ask:**
- What are we assuming about the problem domain?
- What constraints did we inherit without validating?
- What prior solutions are we unconsciously replicating?
- What would a complete outsider find strange about our framing?

### Phase 2: Irreducible Truths

Only what remains when ALL assumptions are removed. Numbered list of fundamental, irrefutable truths.

**Criteria for an irreducible truth:**
- Survives "but why?" asked 5 times
- Cannot be decomposed further
- Is measurable or directly observable
- Is true independent of implementation choice

### Phase 3: Reconstruction from Zero

Using ONLY the irreducible truths, reconstruct the solution as if no prior approach existed. Generate 3 distinct approaches.

**Each approach must:**
- Start from irreducible truths, not from existing code
- Be independently viable
- Differ meaningfully in trade-offs

### Phase 4: Assumption vs Truth Map

Clear comparison showing where conventional thinking deceived vs where the new base leads.

| Assumption (what we believed) | Truth (what's actually true) | Impact |
|---|---|---|
| ... | ... | ... |

### Phase 5: The Aristotelian Move

Identify the SINGLE action of maximum leverage that emerges from first principles thinking.

**Characteristics of a good Aristotelian Move:**
- Addresses the root cause, not symptoms
- Has outsized impact relative to effort
- Would not have been obvious without phases 1-4
- Can be validated quickly

## Application by Task Type

### Bug Fix

| Phase | Focus |
|---|---|
| 1. Assumption Autopsy | "We assume the bug is in X" — but is it? What if the real issue is the API contract, not the implementation? |
| 2. Irreducible Truths | What does the error message actually say? What does the failing test assert? What changed recently? |
| 3. Reconstruction | 3 hypotheses for root cause, each from different angles |
| 4. Map | Assumptions about where the bug is vs evidence-based location |
| 5. Aristotelian Move | The single diagnostic step that confirms/denies the root cause |

### New Feature

| Phase | Focus |
|---|---|
| 1. Assumption Autopsy | "Users need X" — do they? What problem are we actually solving? Are we copying a competitor's approach? |
| 2. Irreducible Truths | What is the user's actual workflow? What data exists? What are the hard constraints (time, API limits, browser support)? |
| 3. Reconstruction | 3 feature designs from different angles (minimal, data-driven, UX-driven) |
| 4. Map | Feature bloat assumptions vs actual user needs |
| 5. Aristotelian Move | The minimal feature that delivers 80% of the value |

### Refactoring

| Phase | Focus |
|---|---|
| 1. Assumption Autopsy | "This code needs refactoring" — does it? Is the pain real or aesthetic? Are we refactoring for hypothetical future needs? |
| 2. Irreducible Truths | What are the actual maintenance costs? What bugs does the current structure cause? What are the measurable pain points? |
| 3. Reconstruction | 3 restructuring approaches (incremental, module boundary, full rewrite of just the hot path) |
| 4. Map | "Clean code" assumptions vs actual cost/benefit |
| 5. Aristotelian Move | The single structural change that eliminates the most pain |

### Architecture Decision

| Phase | Focus |
|---|---|
| 1. Assumption Autopsy | "We need microservices / monolith / serverless" — why? What scaling assumptions are we making? Are we designing for a scale we don't have? |
| 2. Irreducible Truths | Current request volume. Team size. Deployment frequency. Actual (not projected) growth rate. |
| 3. Reconstruction | 3 architectures from different trade-off points (simplicity, scalability, team autonomy) |
| 4. Map | Architecture astronaut assumptions vs current reality |
| 5. Aristotelian Move | The architectural boundary that matters most right now |

## Complexity-Based Application

| Complexity | Phases Applied | Duration |
|---|---|---|
| 1-3 (simple) | Phase 1 + Phase 5 only | 30 seconds |
| 4-6 (standard) | All 5 phases, concise | 2-3 minutes |
| 7-10 (complex) | All 5 phases, thorough with documented artifacts | 5-10 minutes |

## Integration with Orchestrator

Aristotle phases are integrated WITHIN the orchestrator's Step 0 (EVALUATE), not as a separate pre-step:

```
USER INPUT
    |
    v
STEP 0: EVALUATE
    |
    +-- Classify complexity (1-10)
    |
    +-- IF complexity <= 3:
    |     Phase 1 (Assumption Autopsy) - quick
    |     Phase 5 (Aristotelian Move) - identify action
    |
    +-- IF complexity >= 4:
    |     Phase 1 (Assumption Autopsy)
    |     Phase 2 (Irreducible Truths)
    |     Phase 3 (Reconstruction from Zero)
    |     Phase 4 (Assumption vs Truth Map)
    |     Phase 5 (Aristotelian Move)
    |
    v
STEP 1: CLARIFY (informed by Aristotle analysis)
    |
    v
STEP 2-8: (normal orchestrator flow)
```
