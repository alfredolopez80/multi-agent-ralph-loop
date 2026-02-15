---
paths:
  - "**/migrations/**/*"
  - "**/schema*"
  - "**/models/**/*"
  - "**/*.sql"
---

# Database Rules (Auto-learned)

Rules from procedural memory. Confidence >= 0.7, usage >= 3.

## Rules

- Uses async/await for asynchronous operations. Implements rate limiting. Uses schema validation. Implements structured logging
- Use EXPLAIN ANALYZE for query planning. Avoid SELECT *. Use parameterized queries to prevent injection. Index columns used in WHERE and ORDER BY clauses.
- Uses schema validation
- Use explicit transactions for related operations. Always handle rollback for failures. Keep transactions short to avoid locks. Use savepoints for complex nested operations.
- Use migrations for schema changes. Never modify tables directly in production. Always add indexes for foreign keys. Use transactions for multi-table operations.
- Uses schema validation. Implements structured logging

---

*Generated: 2026-02-15 22:58. Source: procedural memory (6 rules)*
