---
# VERSION: 2.43.0
name: adversarial
prefix: "@adv"
category: review
color: red
description: "Adversarial spec refinement via adversarial-spec"
argument-hint: "<spec text|file>"
---

# /adversarial

Iteratively refines a PRD or technical spec using the adversarial-spec plugin.

## Runtime Detection

- **Claude Code**: command file under `~/.claude/` → models: `claude-4.5-opus`, `claude-4.5-sonnet`, `openai/gpt-5.2-codex`, `minimax/minimax-m2.1`.
- **OpenCode**: command file under `~/.config/opencode/` → models: `openai/gpt-5.2-codex`, `minimax/minimax-m2.1`.

When invoking the CLI, set `RALPH_COMMAND_PATH` to the full path of this command file so runtime detection is accurate.

## Execution

Use the CLI wrapper:

```bash
ralph adversarial "Design a rate limiter service"
ralph adversarial docs/spec.md
```
