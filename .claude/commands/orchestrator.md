---
name: orchestrator
prefix: "@orch"
category: orchestration
color: purple
description: "Full orchestration: clarify → classify → delegate → execute → validate → retrospective"
argument-hint: "<task description>"
---

# /orchestrator

Full orchestration with mandatory 6-step flow.

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
