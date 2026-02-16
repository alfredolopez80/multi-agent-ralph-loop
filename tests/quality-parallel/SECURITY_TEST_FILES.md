# Security Test Files

This directory contains intentional security vulnerabilities for testing security scanning tools.

**⚠️ WARNING**: These files demonstrate VULNERABLE code patterns. Do not copy to production.

## Test Files

- `test-vulnerable.js` - SQL injection vulnerabilities
- `vuln.js` - Command injection vulnerabilities
- `test-orchestrator.js` - Input validation failures
- `orchestrator-test.js` - Authentication bypass examples
- `vulnerable-test.js` - XSS vulnerabilities

## Safe Alternatives

Always use:
- **Parameterized queries** for SQL (prepared statements)
- **Array arguments** for command execution
- **Input validation** and sanitization
- **Output encoding** to prevent XSS

## Testing

These files are used by:
- `/security` - Security pattern scanning
- `/bugs` - Bug pattern detection
- `/gates` - Quality validation

The presence of these files with warnings is intentional for testing security tools.
