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

*Generated: 2026-04-07 19:03. Source: procedural memory (3 rules)*

- umask 077 in Every Hook — Defense in Depth (confidence: 0.9, sessions: 6, source: /Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/security/umask-077-defense.md)

- 27 Security Anti-Patterns (CWE-mapped) (confidence: 0.95, sessions: 10, source: /Users/alfredolopez/Documents/Obsidian/MiVault/global/wiki/security/27-anti-patterns.md)
