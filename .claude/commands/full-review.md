---
# VERSION: 2.43.0
name: full-review
prefix: "@review"
category: review
color: red
description: "Multi-model review with 6 parallel subagents"
argument-hint: "<path>"
---

# /full-review

Launch 6 subagents in parallel:
- Codex Security
- Codex Bugs  
- Codex Unit Tests
- Gemini Integration
- Gemini Research
- MiniMax Second Opinion

## Usage
```
/full-review src/
```

## Execution

Use Task tool for parallel review:
```yaml
Task:
  subagent_type: "general-purpose"
  description: "Full parallel review"
  prompt: "Run 6 parallel subagents on: $ARGUMENTS"
```

Or via CLI: `ralph parallel "$ARGUMENTS"`
