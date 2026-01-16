---
# VERSION: 2.43.0
name: parallel
prefix: "@par"
category: review
color: red
description: "Run all 6 subagents in parallel (async)"
argument-hint: "<path>"
---

# /parallel

Same as /full-review but emphasizes async execution.

## Execution

Use Task tool for parallel async execution:
```yaml
Task:
  subagent_type: "general-purpose"
  description: "Parallel async review"
  run_in_background: true
  prompt: "Run 6 subagents in parallel (async) on: $ARGUMENTS"
```

Or via CLI: `ralph parallel "$ARGUMENTS" --async`
