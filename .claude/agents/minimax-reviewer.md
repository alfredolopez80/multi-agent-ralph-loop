---
name: minimax-reviewer
description: "Universal fallback reviewer using MiniMax M2.1 (~8% cost of Claude)."
tools: Bash, Read
model: sonnet
---

# 💰 MiniMax Reviewer (Universal Fallback)

## Use Cases

- Second opinion on any task
- Extended loops (30-60 iterations vs Claude's 15)
- Cost-effective validation
- Parallel review alongside other models

## Invocation

Use Task tool for MiniMax queries:

### Standard Query (via Task)
```yaml
Task:
  subagent_type: "general-purpose"
  description: "MiniMax review"
  prompt: |
    Run MiniMax CLI for review:
    mmc --query "Review/analyze: $TASK"
```

### Extended Loop (via Task)
```yaml
Task:
  subagent_type: "general-purpose"
  description: "MiniMax extended loop"
  prompt: |
    Run MiniMax extended loop:
    mmc --loop 30 "$TASK"  # M2.1: 30 iterations
    # Or for lightning: mmc --lightning --loop 60 "$TASK"
```

### Second Opinion (via Task)
```yaml
Task:
  subagent_type: "general-purpose"
  description: "MiniMax second opinion"
  prompt: |
    Get second opinion via MiniMax:
    mmc --second-opinion "$PREVIOUS_RESULT"
```

## Cost Comparison

| Model | Cost | Max Iterations |
|-------|------|----------------|
| Claude Sonnet | $3/$15 M | 15 |
| MiniMax M2.1 | $0.30/$1.20 M | 30 |
| MiniMax-lightning | $0.15/$0.60 M | 60 |
