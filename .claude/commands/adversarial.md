---
name: adversarial
description: "2/3 consensus validation (Claude + Codex + Gemini)"
argument-hint: "<path>"
---

# /adversarial

Multi-model validation requiring 2/3 consensus.

## Execution

Use Task tool for adversarial validation:
```yaml
Task:
  subagent_type: "general-purpose"
  description: "Adversarial validation"
  prompt: "Run 2/3 consensus validation (Claude+Codex+Gemini) on: $ARGUMENTS"
```

Or via CLI: `ralph adversarial "$ARGUMENTS"`
