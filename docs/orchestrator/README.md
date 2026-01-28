# Orchestrator Documentation

Documentation for the Multi-Agent Ralph Loop orchestrator system.

## Overview

The orchestrator is the core coordination system that manages multiple AI agents, handles task delegation, and ensures implementation quality through validation gates.

## Documents

| File | Description |
|------|-------------|
| [AUTO_VERIFICATION_FIX.md](AUTO_VERIFICATION_FIX.md) | Fix for orchestrator auto-verification system |
| [WORKFLOW_AUDIT.md](WORKFLOW_AUDIT.md) | Comprehensive audit of orchestrator workflow |
| [WORKFLOW_FIXES.md](WORKFLOW_FIXES.md) | Workflow fixes and improvements |

## Core Workflow

```
1. EVALUATE     -> Complexity assessment
2. CLARIFY      -> AskUserQuestion for requirements
3. CLASSIFY     -> 3-dimension classification
4. PLAN         -> Design detailed implementation plan
5. DELEGATE     -> Route to optimal model/agent
6. EXECUTE      -> Implement with Plan-Sync
7. VALIDATE     -> Quality gates and adversarial validation
8. RETROSPECT   -> Analyze and improve
```

## Key Concepts

- **Plan-Sync**: Automatic drift detection and downstream patching
- **Quality Gates**: Multi-stage validation (correctness, quality, consistency)
- **Agent Handoffs**: Explicit transfer between specialized agents
- **Checkpoints**: State snapshots for time-travel rollback

## Related Documentation

- [../adversarial/](../adversarial/) - Adversarial validation system
- [../quality-gates/](../quality-gates/) - Quality gates documentation
- [../plans/](../plans/) - Implementation plans
