---
# VERSION: 2.44.0
name: orchestrator
prefix: "@orch"
category: orchestration
color: purple
description: "Full orchestration: evaluate → clarify → classify → persist → plan mode → execute → validate → retrospective"
argument-hint: "<task description>"
---

# /orchestrator

Full orchestration with mandatory 10-step flow and Plan Mode integration (v2.44).

## v2.44 Key Change

The orchestrator's exhaustive analysis now **feeds INTO** Claude Code's native Plan Mode:

```
Steps 0-3: Orchestrator Analysis (exhaustive)
    ↓
Step 3b: Write analysis to .claude/orchestrator-analysis.md
    ↓
Step 4: EnterPlanMode → Claude Code READS file → Refines plan (not from scratch)
    ↓
Steps 5-8: Execute, Validate, Retrospect
```

## Usage
```
/orchestrator Implement OAuth2 with Google
/orchestrator Migrate database from MySQL to PostgreSQL
/orchestrator Add real-time notifications with WebSockets
```

## Flow (10 Steps)

```
0. EVALUATE     → Quick complexity assessment (trivial vs non-trivial)
1. CLARIFY      → AskUserQuestion intensively (MUST_HAVE + NICE_TO_HAVE)
2. CLASSIFY     → Complexity 1-10, model routing
2b. WORKTREE    → Ask about worktree isolation
3. PLAN         → Design detailed plan (orchestrator analysis)
3b. PERSIST     → Write to .claude/orchestrator-analysis.md ← NEW
4. PLAN MODE    → EnterPlanMode (reads analysis as foundation)
5. DELEGATE     → Route to appropriate model/agent
6. EXECUTE      → Parallel subagents
7. VALIDATE     → Quality gates + Adversarial
8. RETROSPECT   → Analyze and improve
```

## Execution

Use Task tool to invoke the orchestrator agent:
```yaml
Task:
  subagent_type: "orchestrator"
  description: "Full orchestration"
  prompt: "$ARGUMENTS"
  model: "opus"
```

Or via CLI: `ralph orch "$ARGUMENTS"`

## Plan Mode Integration

The orchestrator writes its analysis to `.claude/orchestrator-analysis.md` before calling `EnterPlanMode`. Claude Code then:

1. Reads the analysis file (via rule in `~/.claude/rules/plan-mode-orchestrator.md`)
2. Uses it as the **foundation** for the plan
3. Refines and expands (does NOT generate from scratch)
4. Maintains the orchestrator's structure and conclusions

This ensures **ONE unified plan** instead of conflicting orchestrator + Claude Code plans.
