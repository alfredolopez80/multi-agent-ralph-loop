---
# VERSION: 3.0.0
name: context-engineer
description: "Determines WHAT context an agent needs and packages it optimally. Actions: analyze (identify needed context), load (assemble from sources), prune (trim to token budget), inject (write to .claude/context-payload.md). Use when: (1) before spawning teammates, (2) context window is limited, (3) multi-source context assembly. Triggers: /context-engineer, 'prepare context', 'package context', 'context for agent'."
argument-hint: "<task description>"
user-invocable: true
---

# Context Engineer v3.0

Determine what context an agent needs and package it within token budget.

## Actions

### `/context-engineer analyze <task>`

Identify what context sources are relevant:

1. Parse task description for domain keywords
2. Check for DESIGN.md (frontend tasks)
3. Check for .spec.md files (spec-driven tasks)
4. Check memory sources (vault, handoffs, ledgers)
5. Check codebase files (Glob/Grep for related code)
6. Output: ranked list of context sources with estimated tokens

### `/context-engineer load <task>`

Assemble context from identified sources:

1. Run `analyze` if not already done
2. Read each source, extract relevant sections
3. Prioritize by relevance score
4. Output: assembled context block

### `/context-engineer prune <budget>`

Trim assembled context to fit token budget:

1. Default budget: 8000 tokens
2. Remove low-relevance sections first
3. Summarize long sections instead of including full text
4. Preserve: interfaces, invariants, design tokens (high signal)
5. Output: pruned context within budget

### `/context-engineer inject`

Write packaged context to `.claude/context-payload.md`:

1. Write pruned context to file
2. The `ralph-subagent-start.sh` hook reads this file and injects into teammate prompt
3. File is gitignored (per Item 0a)

## Context Sources (Priority Order)

| Source | When Relevant | Token Cost |
|---|---|---|
| .spec.md | Task has a spec | ~500-2000 |
| DESIGN.md | Frontend task | ~1000-3000 |
| Related code files | Always | ~500-5000 |
| Memory (vault)      | Prior work exists | ~200-500 |
| Handoffs | Cross-session | ~300-800 |
| Vault (future) | Curated knowledge | ~200-1000 |

## Integration

- **Orchestrator Step 5 (DELEGATE)**: invoke before spawning teammate
- **ralph-subagent-start.sh**: reads `.claude/context-payload.md` if exists
- **Token budget**: default 8000, adjustable per task complexity

## Anti-Rationalization

| Excuse | Rebuttal |
|---|---|
| "The agent has enough context from the prompt" | Agents lose 40% accuracy without structured context. Package it. |
| "Context engineering is overhead" | 5 seconds of packaging saves 5 minutes of wrong output. |
| "I'll just include everything" | Token flooding degrades quality. Prune to signal. |
