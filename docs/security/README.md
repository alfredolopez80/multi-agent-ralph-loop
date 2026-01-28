# Security Documentation

Security-related documentation including audits, fixes, and best practices for Multi-Agent Ralph Loop.

## Overview

This directory contains security audit reports, vulnerability fixes, and security-related documentation for the project.

## Documents

| File | Description |
|------|-------------|
| [API_KEYS_AUDIT.md](API_KEYS_AUDIT.md) | Security audit for API keys management |
| [HANDOFF_FIXES.md](HANDOFF_FIXES.md) | Handoff security fixes |

## Security Practices

### API Key Management
- Never commit API keys to repository
- Use environment variables for sensitive configuration
- Rotate keys regularly
- Audit key access logs

### Handoff Security
- Validate all handoff transfers
- Sanitize handoff data
- Log all handoff operations
- Verify agent identities

### Hook Security
- Validate all inputs
- Use absolute paths
- Escape shell arguments
- Run with minimal privileges

## Related Documentation

- [../audits/](../audits/) - Security audit reports
- [../../.claude/audits/](../../.claude/audits/) - Detailed security audits
