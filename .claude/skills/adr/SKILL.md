---
# VERSION: 3.0.0
name: adr
description: "Architecture Decision Records management. Actions: create (new ADR), list (show all), search (find by keyword). Use when: (1) making architecture decisions, (2) choosing between technologies, (3) documenting trade-offs. Triggers: /adr, 'architecture decision', 'decision record', 'document decision'."
argument-hint: "<action: create|list|search> [title or query]"
user-invocable: true
---

# ADR — Architecture Decision Records v3.0

Document architecture decisions with context, options, and rationale.

## Actions

### `/adr create <title>`

1. Create numbered ADR file: `docs/decisions/NNNN-<slug>.md`
2. Fill template with: Status, Context, Decision, Consequences
3. Link to related ADRs if they exist

### `/adr list`

List all ADRs with status (proposed, accepted, deprecated, superseded).

### `/adr search <query>`

Search ADR titles and content for relevant decisions.

## Template

```markdown
# ADR-NNNN: <Title>

**Status**: Proposed | Accepted | Deprecated | Superseded by ADR-XXXX
**Date**: YYYY-MM-DD
**Deciders**: <who was involved>

## Context

What is the issue that we're seeing that is motivating this decision?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

### Positive
- ...

### Negative
- ...

### Neutral
- ...

## Alternatives Considered

| Option | Pros | Cons | Why Not |
|---|---|---|---|
```

## Integration

- Orchestrator Step 3 (PLAN): for complexity >= 7, suggest creating an ADR
- Vault (Item 8): ADRs feed into vault/projects/{project}/decisions/
