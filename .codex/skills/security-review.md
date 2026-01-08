# Skill: Security Review

## Purpose
Deep security analysis using gpt-5.2-codex.

## Capabilities
- Injection detection (SQL, NoSQL, Command, LDAP, XPath, Template)
- Authentication/Authorization bypass
- Data exposure and secrets
- SSRF and path traversal
- Race conditions
- Cryptographic weaknesses

## Invocation
```bash
codex exec --profile security-audit \
  "Use security-review skill. Analyze: $FILES"
```

## Output Format
```json
{
  "vulnerabilities": [
    {
      "severity": "CRITICAL|HIGH|MEDIUM|LOW",
      "type": "injection|auth|exposure|ssrf|race|crypto",
      "file": "path/to/file",
      "line": 123,
      "description": "...",
      "cwe": "CWE-XXX",
      "fix": "recommended fix"
    }
  ],
  "summary": {
    "critical": 0,
    "high": 0,
    "medium": 0,
    "low": 0,
    "approved": true|false
  }
}
```
