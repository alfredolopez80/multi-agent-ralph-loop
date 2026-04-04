---
# VERSION: 3.0.0
name: exit-review
description: "End-of-session learning classification. Reviews accumulated learnings and classifies each as GREEN (generic, goes to global wiki), YELLOW (project-specific, goes to project wiki), or RED (sensitive, discarded). Triggered at session end via Stop hook. Use when: (1) session ending, (2) manual review of learnings. Triggers: /exit-review, 'review learnings', 'classify learnings'."
user-invocable: true
---

# Exit Review — Session Learning Classification v3.0

Classify accumulated learnings before session ends.

## Classification

| Color | Meaning | Destination | Example |
|---|---|---|---|
| GREEN | Generic (useful for any project) | `$VAULT_DIR/global/wiki/{category}/` | "Use zod for runtime validation" |
| YELLOW | Project-specific | `$VAULT_DIR/projects/{project}/wiki/` | "Hook sanitize-secrets.js uses 28 patterns" |
| RED | Contains secrets or sensitive info | DISCARDED (never saved) | "API key is sk-..." |

## Workflow

1. Read accumulated learnings from session buffer
2. For each learning:
   a. Classify as GREEN/YELLOW/RED
   b. If GREEN: write to `$VAULT_DIR/global/wiki/{category}/`
   c. If YELLOW: write to `$VAULT_DIR/projects/{project}/wiki/`
   d. If RED: discard with warning
3. Update vault indices

## Learning Format

```markdown
---
type: learning
classification: GREEN
source: session-2026-04-04
confidence: 0.3
sessions_confirmed: 1
category: typescript
---

# Use zod for runtime validation at API boundaries

Runtime validation with zod catches type mismatches that TypeScript alone misses at API boundaries.
Particularly useful for external API responses where the shape is not guaranteed.

## Evidence
- Used successfully in auth endpoint validation
- Caught 3 type mismatches in first session
```

## Trigger

- Automatically triggered by `Stop` event via `session-end-handoff.sh`
- Can be invoked manually: `/exit-review`

## Integration

- `session-accumulator.sh` collects learnings during session
- This skill classifies them at session end
- `vault-graduation.sh` promotes high-confidence ones to rules at next SessionStart
