---
# VERSION: 2.43.0
name: retrospective
prefix: "@retro"
category: tools
color: green
description: "Post-task analysis and improvement proposals for continuous system evolution"
---

# /retrospective

Post-task analysis that identifies what went well, what could improve, and proposes concrete action items for system evolution.

## Overview

The retrospective skill performs systematic analysis after task completion to:
- Identify successes and areas for improvement
- Propose concrete action items
- Feed learnings back into the system
- Maintain continuous improvement cycle

## When to Use

**MANDATORY after every task completion** (Step 7 in the 8-step orchestrator flow):

```
6. /adversarial → adversarial-spec refinement (complexity >= 7)
7. /retrospective → Propose improvements ← YOU ARE HERE
→ VERIFIED_DONE
```

Run retrospective when:
- Task is complete and gates passed
- Before marking task as VERIFIED_DONE
- After adversarial spec refinement (if applicable)
- When analyzing workflow effectiveness

## Analysis Categories

The retrospective analyzes three key areas:

### 1. What Went Well
- Effective tools and techniques used
- Successful patterns and approaches
- Time-saving optimizations
- Quality gate passes
- Subagent coordination successes

### 2. What Could Improve
- Bottlenecks or inefficiencies
- Tools that underperformed
- Communication gaps
- Quality gate failures
- Iteration waste

### 3. Action Items
- Concrete improvements to implement
- Documentation updates needed
- Skill modifications
- Workflow optimizations
- Tool configuration changes

## Integration with Orchestrator

The retrospective is Step 7 in the mandatory 8-step flow:

```
0. AUTO-PLAN    → EnterPlanMode (automatic for non-trivial)
1. /clarify     → AskUserQuestion (MUST_HAVE + NICE_TO_HAVE)
2. /classify    → Complexity 1-10
2b. WORKTREE    → Ask user: "¿Requiere worktree aislado?"
3. PLAN         → Write plan, get user approval
4. @orchestrator → Delegate to subagents
5. ralph gates  → Quality gates (9 languages)
6. /adversarial → adversarial-spec refinement (complexity >= 7)
7. /retrospective → Propose improvements ← MANDATORY
→ VERIFIED_DONE
```

## CLI Execution

```bash
# Basic retrospective
ralph retrospective

# After specific task type
ralph retrospective --context "security audit"

# Generate improvement proposals
ralph retrospective --output improvements.md
```

## Task Tool Invocation

```yaml
Task:
  subagent_type: "general-purpose"
  model: "sonnet"
  run_in_background: true
  description: "Retrospective analysis"
  prompt: |
    Execute retrospective analysis via CLI:
    cd /Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop && ralph retrospective

    Analyze:
    1. What went well (tools, patterns, successes)
    2. What could improve (bottlenecks, failures, inefficiencies)
    3. Action items (concrete improvements to implement)

    Apply Ralph Loop: iterate until analysis is complete and actionable.
```

## Output Format

Structured retrospective report:

```markdown
# Retrospective: [Task Name]

## What Went Well
- Quality gates passed on first attempt (tsc, eslint, pyright)
- Effective use of MiniMax for cost-effective validation
- Clear MUST_HAVE clarification prevented rework

## What Could Improve
- Initial complexity estimate was too low (5 vs actual 7)
- Worktree isolation would have prevented conflicts
- Missing edge case in test coverage

## Action Items
1. Update task-classifier skill with better heuristics
2. Add worktree prompt to orchestrator for complexity >= 6
3. Enhance test-architect to check edge cases systematically
4. Document pattern: "Always use MiniMax for validation"

## Metrics
- Total iterations: 8/15
- Quality gate failures: 0
- Rework cycles: 1
- Cost efficiency: 92% (MiniMax validation saved 40%)
```

## Self-Improvement Loop

Retrospective findings feed back into the system:

```
┌─────────────────────────────────────────────────┐
│         SELF-IMPROVEMENT LOOP                   │
├─────────────────────────────────────────────────┤
│                                                 │
│  ┌──────────────┐    ┌────────────────────┐    │
│  │ Task         │───▶│ Retrospective      │    │
│  │ Completion   │    │ Analysis           │    │
│  └──────────────┘    └─────────┬──────────┘    │
│                                 │               │
│                                 ▼               │
│                    ┌────────────────────┐       │
│                    │ Action Items       │       │
│                    │ Identified         │       │
│                    └─────────┬──────────┘       │
│                              │                  │
│                              ▼                  │
│              ┌───────────────────────────┐      │
│              │ System Updates:           │      │
│              │ - Skills modified         │      │
│              │ - Docs updated            │      │
│              │ - Workflows optimized     │      │
│              └───────────┬───────────────┘      │
│                          │                      │
│                          ▼                      │
│                 ┌─────────────────┐             │
│                 │ Next Task       │             │
│                 │ (Improved)      │             │
│                 └─────────────────┘             │
│                                                 │
└─────────────────────────────────────────────────┘
```

## Related Commands

- `/orchestrator` - Full 8-step flow (includes retrospective)
- `/improvements` - View proposed system improvements
- `/adversarial` - Pre-retrospective spec refinement
- `/gates` - Quality gates that feed into retrospective

## Best Practices

1. Be specific in "What Could Improve" - vague feedback doesn't drive change
2. Make action items concrete and actionable
3. Include metrics when available (iterations, cost, time)
4. Distinguish between one-time issues and systemic problems
5. Propose improvements that can be automated or codified
6. Link retrospective findings to documentation updates
7. Track recurring issues across multiple retrospectives
