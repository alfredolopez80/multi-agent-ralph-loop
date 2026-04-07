# Room: Security

**Topic**: Security practices — input validation, auth, secrets, anti-patterns.
**Wing**: _global + multi-agent-ralph-loop
**Sources**: security.md (all 5 items actionable — no noise excluded)

---

## Input Validation at API Boundaries (CRITICAL)

- Validate all inputs at API boundaries
- Use parameterized queries for all database operations
- Sanitize HTML output to prevent XSS
- Validate file uploads with allowlist

---

## Auth Library Standard (CRITICAL)

- Use established auth libraries (Auth0, Firebase Auth)
- Never implement crypto yourself
- Use bcrypt for password hashing (cost >= 12)
- Implement rate limiting on auth endpoints

---

## Secret Handling

- Never log sensitive data (passwords, tokens, PII)
- Use environment variables for secrets
- Encrypt sensitive data at rest
- Use HTTPS for all communications

---

## umask 077 in Every Hook

Set `umask 077` at the top of every hook script.

**Source**: (confidence: 0.9, sessions: 6)
**Vault**: `~/Documents/Obsidian/MiVault/global/wiki/security/umask-077-defense.md`
**Wing**: multi-agent-ralph-loop (hook system specific)

---

## 27 Security Anti-Patterns (CWE-mapped)

Reference library of 27 security anti-patterns with CWE mappings.

**Source**: (confidence: 0.95, sessions: 10)
**Vault**: `~/Documents/Obsidian/MiVault/global/wiki/security/27-anti-patterns.md`
