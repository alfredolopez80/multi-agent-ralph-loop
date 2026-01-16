---
# VERSION: 2.43.0
name: orchestrator
prefix: "@orch"
category: orchestration
color: purple
description: "Full orchestration: clarify → classify → delegate → execute → validate → retrospective"
argument-hint: "<task description>"
---

# /orchestrator

Full orchestration with mandatory 8-step flow and adversarial-spec refinement.

Adversarial step generates a baseline spec and refines it via adversarial-spec when complexity >= 7.

## Usage
```
/orchestrator Implement OAuth2 with Google
/orchestrator Migrate database from MySQL to PostgreSQL
```

## Execution

Use Task tool to invoke the orchestrator agent:
```yaml
Task:
  subagent_type: "orchestrator"
  description: "Full orchestration"
  prompt: "$ARGUMENTS"
```

Or via CLI: `ralph orch "$ARGUMENTS"`
