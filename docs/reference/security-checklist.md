# Security Checklist (OWASP Top 10)

## A01: Broken Access Control
- [ ] Enforce least privilege
- [ ] Deny by default (except public resources)
- [ ] Rate limit API access
- [ ] Validate JWT tokens server-side
- [ ] Log access control failures

## A02: Cryptographic Failures
- [ ] No secrets in code or git history
- [ ] Use environment variables for credentials
- [ ] TLS for all external communication
- [ ] Strong password hashing (bcrypt/argon2)

## A03: Injection
- [ ] Parameterized queries (no string concatenation)
- [ ] Input validation at API boundaries
- [ ] Output encoding for HTML context
- [ ] No eval() or dynamic code execution

## A04: Insecure Design
- [ ] Threat modeling for new features
- [ ] Security requirements in specs
- [ ] Principle of least privilege in architecture

## A05: Security Misconfiguration
- [ ] No default credentials
- [ ] Security headers (CSP, HSTS, X-Frame-Options)
- [ ] Error messages don't leak internals
- [ ] Dependencies up to date

## A06: Vulnerable Components
- [ ] Regular dependency audits (npm audit, pip-audit)
- [ ] Pin dependency versions
- [ ] Monitor CVE databases

## A07: Auth Failures
- [ ] Multi-factor authentication for admin
- [ ] Session timeout
- [ ] Password complexity requirements
- [ ] Account lockout after failed attempts

## A08: Software/Data Integrity
- [ ] Verify package integrity (checksums)
- [ ] CI/CD pipeline security
- [ ] Code review required for merges

## A09: Logging Failures
- [ ] Log authentication events
- [ ] Log access control failures
- [ ] No sensitive data in logs
- [ ] Centralized log management

## A10: SSRF
- [ ] Validate/sanitize URLs from user input
- [ ] Allowlist for external service connections
- [ ] No internal network access from user-controlled URLs
