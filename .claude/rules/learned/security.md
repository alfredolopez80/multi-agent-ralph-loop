---
paths:
  - ".claude/hooks/**/*security*"
  - "**/*auth*"
  - "**/*guard*"
---

# Security Rules (Auto-learned)

Rules from procedural memory. Confidence >= 0.7, usage >= 3.

## Critical

- Validate all inputs at API boundaries. Use parameterized queries for all database operations. Sanitize HTML output to prevent XSS. Validate file uploads with allowlist.
- Use established auth libraries (e.g., Auth0, Firebase Auth). Never implement crypto yourself. Use bcrypt for password hashing (cost >= 12). Implement rate limiting on auth endpoints.

## Rules

- Never log sensitive data (passwords, tokens, PII). Use environment variables for secrets. Encrypt sensitive data at rest. Use HTTPS for all communications.

---

*Generated: 2026-02-15 22:58. Source: procedural memory (3 rules)*
