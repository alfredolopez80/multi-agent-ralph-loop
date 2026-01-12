# Skill: Security Review

**ultrathink** - Take a deep breath. We're not here to write code. We're here to make a dent in the universe.

## The Vision
Security findings must be undeniable, actionable, and minimal-risk.

## Your Work, Step by Step
1. **Define scope**: Identify assets, entry points, and trust boundaries.
2. **Scan for vulnerabilities**: Apply threat patterns systematically.
3. **Classify severity**: Impact, likelihood, exploitability.
4. **Recommend fixes**: Minimal diffs with clear remediation.

## Ultrathink Principles in Practice
- **Think Different**: Assume the attacker is creative.
- **Obsess Over Details**: Validate every boundary and input path.
- **Plan Like Da Vinci**: Outline audit coverage before scanning.
- **Craft, Don't Code**: Fixes should reduce surface area.
- **Iterate Relentlessly**: Re-audit after mitigation.
- **Simplify Ruthlessly**: Remove risky complexity.

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
