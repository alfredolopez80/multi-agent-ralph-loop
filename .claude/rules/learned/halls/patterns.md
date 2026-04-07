# Hall: Patterns

**Type**: Positive patterns — things that work well.
**Wing**: multi-agent-ralph-loop + _global
**Sources**: backend.md, database.md, hooks.md, security.md (noise-excluded)

---

## Async/Await for Asynchronous Operations

Use async/await consistently for all asynchronous operations.

**Source**: backend.md (confidence >= 0.7, usage >= 3)
**Wing**: _global

---

## Observability / Metrics

Implement metrics/observability alongside core logic.

**Source**: backend.md
**Wing**: _global

---

## Caching Strategy

Implement a caching strategy for frequently-read data.

**Source**: backend.md
**Wing**: _global

---

## Schema Validation at Boundaries

Use schema validation at API/data entry boundaries.

**Source**: backend.md, database.md
**Wing**: _global

---

## Database: Query Optimization

- Use `EXPLAIN ANALYZE` for query planning
- Avoid `SELECT *` — select only needed columns
- Use parameterized queries to prevent injection
- Index columns used in `WHERE` and `ORDER BY` clauses

**Source**: database.md
**Wing**: _global

---

## Database: Transactions

- Use explicit transactions for related operations
- Always handle rollback for failures
- Keep transactions short to avoid locks
- Use savepoints for complex nested operations

**Source**: database.md
**Wing**: _global

---

## Database: Migrations

- Use migrations for schema changes
- Never modify tables directly in production
- Always add indexes for foreign keys
- Use transactions for multi-table operations

**Source**: database.md
**Wing**: _global

---

## Hook Stdin Protocol

Hooks read stdin with `INPUT=$(cat)` then parse with `jq`.

```bash
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
```

**Source**: hooks.md (confidence: 0.9, sessions: 8)
**Vault**: `~/Documents/Obsidian/MiVault/global/wiki/hooks/stdin-protocol-pattern.md`
**Wing**: multi-agent-ralph-loop

---

## umask 077 in Every Hook

Set `umask 077` at the top of every hook script as defense in depth.

**Source**: security.md (confidence: 0.9, sessions: 6)
**Vault**: `~/Documents/Obsidian/MiVault/global/wiki/security/umask-077-defense.md`
**Wing**: multi-agent-ralph-loop

---

## Kaizen 4 Pillars for AI Agent Development

Continuous improvement framework for AI agent systems. Apply all 4 pillars to agent design decisions.

**Source**: agent-engineering.md (confidence: 0.85, sessions: 5)
**Vault**: `~/Documents/Obsidian/MiVault/global/wiki/agent-engineering/kaizen-4-pillars.md`
**Wing**: _global
