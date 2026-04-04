# Anti-Rationalization Master Table

Excuses agents make to cut corners, and why they must not.

## Master Table (30+ entries)

### General

| # | Excuse | Rebuttal | Affected Skills | Severity |
|---|--------|----------|-----------------|----------|
| 1 | "This is trivial, no plan needed" | Triviality is subjective. Follow the workflow. | orchestrator | HIGH |
| 2 | "I already know the answer" | Memory is unreliable across sessions. Verify. | orchestrator, clarify | HIGH |
| 3 | "The user didn't ask for tests" | Tests are mandatory, not optional. | gates, task-batch | CRITICAL |
| 4 | "I'll fix it in the next iteration" | Fix it now. Next iteration may never come. | iterate, task-batch | HIGH |
| 5 | "The existing code doesn't have tests" | That's technical debt, not a license to add more. | gates | HIGH |
| 6 | "This edge case is unlikely" | Unlikely edge cases cause production incidents. | spec, adversarial | HIGH |
| 7 | "I'll add documentation later" | Documentation is part of the deliverable. | orchestrator | MEDIUM |

### Orchestrator-Specific

| # | Excuse | Rebuttal | Severity |
|---|--------|----------|----------|
| 8 | "Step 0 is just classification, I can skip it" | Step 0 includes Aristotle analysis. Never skip. | CRITICAL |
| 9 | "Memory search is slow, I'll skip it" | Memory prevents repeated mistakes. Worth the wait. | HIGH |
| 10 | "Complexity is 2, no need for full workflow" | FAST_PATH still has 3 steps. Follow them. | HIGH |
| 11 | "I know which model to route to" | Classification determines routing, not intuition. | MEDIUM |
| 12 | "The plan is obvious, no need for EnterPlanMode" | Plans catch assumptions you didn't question. | HIGH |

### Iterate/Loop-Specific

| # | Excuse | Rebuttal | Severity |
|---|--------|----------|----------|
| 13 | "VERIFIED_DONE — all tests pass" | Did you run ALL tests or just the new ones? | CRITICAL |
| 14 | "The error is unrelated to my change" | Prove it. Run the full test suite. | HIGH |
| 15 | "3 iterations is enough" | Iteration count doesn't determine quality. Exit criteria do. | HIGH |
| 16 | "The fix works locally" | Local works is not verified. Run exit criteria. | HIGH |
| 17 | "I'm stuck, marking as done with notes" | Stuck means escalate, not declare victory. | CRITICAL |

### Task-Batch-Specific

| # | Excuse | Rebuttal | Severity |
|---|--------|----------|----------|
| 18 | "Partial success is acceptable" | Each task has completion criteria. Meet them. | CRITICAL |
| 19 | "This task depends on another, skipping" | Document the dependency, don't skip. | HIGH |
| 20 | "The PRD doesn't have completion criteria" | No criteria = task rejected. Ask for them. | CRITICAL |
| 21 | "I'll batch-commit at the end" | Auto-commit after EACH completed task. | HIGH |
| 22 | "The context is too stale, starting fresh" | Fresh context per task is built in. Use it. | MEDIUM |

### Quality Gates-Specific

| # | Excuse | Rebuttal | Severity |
|---|--------|----------|----------|
| 23 | "It's just a warning, not an error" | Warnings become errors in production. Fix them. | HIGH |
| 24 | "Security scan is too strict" | Security scan catches what you missed. | CRITICAL |
| 25 | "Type errors are false positives" | Type errors are real until proven false. Investigate. | HIGH |
| 26 | "Linting is style, not substance" | Consistency IS substance in team projects. | MEDIUM |
| 27 | "I'll pass gates after the PR" | Gates run BEFORE completion, not after. | HIGH |

### Autoresearch-Specific

| # | Excuse | Rebuttal | Severity |
|---|--------|----------|----------|
| 28 | "First experiment worked, stopping" | N=1 is not evidence. Run 3+ experiments. | HIGH |
| 29 | "The metric improved slightly, good enough" | Slight improvement may be noise. Validate. | HIGH |
| 30 | "I can't reproduce the improvement" | Non-reproducible results are not results. | CRITICAL |
| 31 | "The experiment takes too long" | Budget management, not experiment cancellation. | MEDIUM |
| 32 | "I modified too many variables" | One variable per experiment. Start over. | HIGH |

### Frontend-Specific

| # | Excuse | Rebuttal | Severity |
|---|--------|----------|----------|
| 33 | "The design system doesn't cover this case" | Ask before inventing. The system is the contract. | HIGH |
| 34 | "Accessibility is for a later phase" | Accessibility is not optional. WCAG 2.1 AA always. | CRITICAL |
| 35 | "It looks right on my screen size" | Test all 3 breakpoints. Your screen is not universal. | HIGH |
| 36 | "Hardcoded colors are faster" | Use design tokens. Consistency > speed. | MEDIUM |
| 37 | "I only need to handle the happy path" | 8 states: default, hover, focus, active, disabled, loading, error, success. | HIGH |

## Usage

Each SKILL.md should reference this table and include skill-specific entries.
Skills should add a section: `## Anti-Rationalization` with entries relevant to that skill.
