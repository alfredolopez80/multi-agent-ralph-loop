---
name: security
prefix: "@sec"
category: review
color: red
description: "Security audit with Codex + MiniMax second opinion"
argument-hint: "<path>"
---

# /security - Multi-Agent Security Audit (v2.24)

Comprehensive security audit using Codex GPT-5 for primary analysis and MiniMax for second opinion validation.

## Overview

The `/security` command performs a thorough security audit of your codebase, checking for:
- CWE (Common Weakness Enumeration) vulnerabilities
- OWASP Top 10 security risks
- Input validation and sanitization issues
- Authentication and authorization flaws
- Cryptographic weaknesses
- Injection vulnerabilities (SQL, Command, XSS, etc.)
- Path traversal and file handling risks
- Race conditions and TOCTOU bugs
- Insecure defaults and misconfigurations

Results are returned in structured JSON format with severity ratings, CWE references, and remediation guidance.

## When to Use

Trigger `/security` when:
- Adding new features that handle user input
- Before merging security-critical changes
- After dependency updates that may introduce vulnerabilities
- Implementing authentication or authorization logic
- Working with file operations, shell commands, or network requests
- Preparing for production deployment
- Conducting periodic security reviews

## Workflow

```
┌────────────────────────────────────────────────────────┐
│                  Security Audit Flow                   │
├────────────────────────────────────────────────────────┤
│                                                        │
│  1. CODEX PRIMARY AUDIT                                │
│     ├─ CWE vulnerability scan                          │
│     ├─ OWASP Top 10 check                              │
│     ├─ Input validation review                         │
│     ├─ Authentication/authorization audit              │
│     └─ Generate findings (JSON)                        │
│                                                        │
│  2. MINIMAX SECOND OPINION                             │
│     ├─ Independent vulnerability review                │
│     ├─ Cross-validate Codex findings                   │
│     ├─ Catch additional issues                         │
│     └─ Consensus report                                │
│                                                        │
│  3. QUALITY GATES INTEGRATION                          │
│     └─ Findings feed into ralph gates                  │
│                                                        │
│  4. STRUCTURED REPORT                                  │
│     ├─ Severity: CRITICAL/HIGH/MEDIUM/LOW              │
│     ├─ CWE references                                  │
│     ├─ OWASP categories                                │
│     ├─ Code snippets                                   │
│     └─ Remediation steps                               │
│                                                        │
└────────────────────────────────────────────────────────┘
```

## CLI Execution

```bash
# Audit entire project
ralph security .

# Audit specific directory
ralph security src/

# Audit single file
ralph security src/auth/login.ts

# Audit with verbose output
ralph security src/ --verbose

# Audit and save JSON report
ralph security src/ --output security-report.json
```

## Task Tool Invocation

### Primary Security Audit (Codex GPT-5)

```yaml
Task:
  subagent_type: "security-auditor"
  model: "sonnet"  # Sonnet manages the Codex CLI call
  run_in_background: true
  description: "Codex: Primary security audit"
  prompt: |
    Execute via Codex CLI for security analysis:
    cd /absolute/path/to/project && codex exec -m gpt-5.2-codex "
    Perform comprehensive security audit on: <path>

    Check for:
    1. CWE vulnerabilities (prioritize High/Critical)
    2. OWASP Top 10 risks
    3. Input validation issues
    4. Authentication/authorization flaws
    5. SQL/Command/XSS injection vectors
    6. Path traversal (CWE-22, CWE-59)
    7. Command injection (CWE-78)
    8. Insecure crypto (CWE-327, CWE-338)
    9. Race conditions (CWE-362, CWE-367)
    10. Information disclosure (CWE-200, CWE-209)

    Output format: JSON with structure:
    {
      'findings': [
        {
          'severity': 'CRITICAL|HIGH|MEDIUM|LOW',
          'cwe': 'CWE-XXX',
          'owasp': 'A01:2021-Broken Access Control',
          'title': 'Brief description',
          'file': 'path/to/file.ext',
          'line': 42,
          'code': 'vulnerable code snippet',
          'description': 'Detailed explanation',
          'remediation': 'How to fix',
          'references': ['URL1', 'URL2']
        }
      ],
      'summary': {
        'total': 10,
        'critical': 2,
        'high': 3,
        'medium': 4,
        'low': 1
      }
    }
    "

    Apply Ralph Loop: iterate until audit complete and all findings validated.
```

### Secondary Validation (MiniMax Second Opinion)

```yaml
Task:
  subagent_type: "minimax-reviewer"
  model: "sonnet"  # Sonnet manages the mmc CLI call
  run_in_background: true
  description: "MiniMax: Security second opinion"
  prompt: |
    Execute via MiniMax CLI for independent security validation:
    mmc --query "
    Perform independent security review on: <path>

    Focus on vulnerabilities Codex might have missed:
    1. Subtle logic flaws in authentication
    2. Business logic vulnerabilities
    3. Race conditions in concurrent code
    4. Insecure defaults and misconfigurations
    5. Complex injection chains

    Cross-validate Codex findings and identify additional issues.
    Use same JSON format as Codex for consistency.
    "

    MiniMax provides Opus-level quality at 8% cost for second opinion.
```

## Output Format

### JSON Structure

```json
{
  "findings": [
    {
      "severity": "CRITICAL",
      "cwe": "CWE-78",
      "owasp": "A03:2021-Injection",
      "title": "Command Injection in file upload handler",
      "file": "src/upload/handler.ts",
      "line": 145,
      "code": "execSync(`convert ${filename} output.png`)",
      "description": "User-supplied filename passed to shell without sanitization",
      "remediation": "Use execFile with array arguments instead of shell interpolation. Import execFileNoThrow from utils.",
      "references": [
        "https://cwe.mitre.org/data/definitions/78.html",
        "https://owasp.org/Top10/A03_2021-Injection/"
      ]
    },
    {
      "severity": "HIGH",
      "cwe": "CWE-22",
      "owasp": "A01:2021-Broken Access Control",
      "title": "Path Traversal in file download",
      "file": "src/api/download.ts",
      "line": 67,
      "code": "readFile(path.join('/uploads', req.query.file))",
      "description": "User-controlled file parameter allows access to arbitrary files via '../' sequences",
      "remediation": "Validate path is within allowed directory using realpath and startsWith check",
      "references": [
        "https://cwe.mitre.org/data/definitions/22.html"
      ]
    }
  ],
  "summary": {
    "total": 2,
    "critical": 1,
    "high": 1,
    "medium": 0,
    "low": 0,
    "files_scanned": 45,
    "scan_duration": "12.3s",
    "tools": ["codex-gpt5", "minimax-m2.1"]
  }
}
```

### Markdown Report

```markdown
# Security Audit Report

**Date:** 2025-01-04
**Target:** src/
**Tools:** Codex GPT-5 + MiniMax M2.1

## Summary

- **Total Findings:** 2
- **Critical:** 1
- **High:** 1
- **Medium:** 0
- **Low:** 0

## Findings

### [CRITICAL] Command Injection in file upload handler

**CWE:** CWE-78
**OWASP:** A03:2021-Injection
**File:** src/upload/handler.ts:145

**Vulnerable Code:**
```typescript
// UNSAFE - allows command injection
execSync(`convert ${filename} output.png`)
```

**Description:** User-supplied filename passed to shell without sanitization, allowing arbitrary command execution.

**Remediation:** Use execFile with array arguments:
```typescript
// SAFE - no shell interpolation
import { execFileNoThrow } from '../utils/execFileNoThrow.js'
await execFileNoThrow('convert', [filename, 'output.png'])
```

**References:**
- https://cwe.mitre.org/data/definitions/78.html
- https://owasp.org/Top10/A03_2021-Injection/
```

## Security Considerations

### For the Security Command Itself

1. **Safe Code Analysis** - The security audit reads code but never executes it
2. **Sensitive Data Handling** - Reports may contain code snippets with secrets; handle with care
3. **False Positives** - Manual review required; automated tools may flag benign patterns
4. **Scope Limitation** - Static analysis only; cannot detect runtime vulnerabilities
5. **Tool Trust** - Codex and MiniMax are third-party services; do not send proprietary code if restricted

### CWE Categories Checked

| Category | CWEs | Description |
|----------|------|-------------|
| **Injection** | CWE-78, CWE-89, CWE-79 | Command, SQL, XSS injection |
| **Path Traversal** | CWE-22, CWE-59 | File access outside allowed directories |
| **Input Validation** | CWE-20, CWE-116 | Improper input sanitization |
| **Authentication** | CWE-287, CWE-307 | Broken authentication, brute force |
| **Authorization** | CWE-284, CWE-862 | Missing access controls |
| **Cryptography** | CWE-327, CWE-338 | Weak crypto, insecure RNG |
| **Race Conditions** | CWE-362, CWE-367 | TOCTOU, concurrent access |
| **Information Disclosure** | CWE-200, CWE-209 | Leaking sensitive data |
| **Resource Management** | CWE-400, CWE-770 | DoS, resource exhaustion |

### OWASP Top 10 Mapping

| OWASP Category | CWE Examples | Priority |
|----------------|--------------|----------|
| A01:2021-Broken Access Control | CWE-22, CWE-862 | High |
| A02:2021-Cryptographic Failures | CWE-327, CWE-338 | High |
| A03:2021-Injection | CWE-78, CWE-89, CWE-79 | Critical |
| A04:2021-Insecure Design | CWE-840 | Medium |
| A05:2021-Security Misconfiguration | CWE-16 | Medium |
| A06:2021-Vulnerable Components | CVE references | High |
| A07:2021-Authentication Failures | CWE-287, CWE-307 | Critical |
| A08:2021-Data Integrity Failures | CWE-502 | High |
| A09:2021-Logging Failures | CWE-778 | Low |
| A10:2021-SSRF | CWE-918 | Medium |

## Integration with Quality Gates

The security audit integrates with `ralph gates`:

```bash
# Run security audit as part of quality gates
ralph gates

# Quality gates automatically include:
# 1. Language-specific linting (9 languages)
# 2. Security audit (if security-critical files changed)
# 3. Test coverage validation
# 4. Git safety checks
```

**Gate Failure Criteria:**
- Any CRITICAL severity finding → BLOCK merge
- 2+ HIGH severity findings → BLOCK merge
- MEDIUM findings → Warning (review required)
- LOW findings → Info only

## Related Commands

| Command | Purpose | Use Case |
|---------|---------|----------|
| `/security` | Full security audit | Pre-merge security review |
| `/adversarial` | 2/3 consensus validation | Critical features (complexity >= 7) |
| `/bugs` | Bug hunting | Functional issues, not security |
| `/security-loop` | Iterative security fixes | Apply fixes until audit passes |
| `/code-review` | General code review | Quality, not security-focused |
| `ralph gates` | Quality gates | Pre-commit validation |

## Examples

### Example 1: Pre-Merge Security Review

```bash
# Scenario: About to merge authentication feature
ralph security src/auth/

# Output: JSON report with 3 findings
# - CRITICAL: Hardcoded JWT secret (CWE-798)
# - HIGH: Missing rate limiting (CWE-307)
# - MEDIUM: Weak password requirements (CWE-521)
```

### Example 2: Dependency Update Review

```bash
# Scenario: Updated Express from 4.17 to 4.18
ralph security src/api/

# Output: No new vulnerabilities introduced
# - Validates middleware security
# - Checks request parsing
# - Reviews error handling
```

### Example 3: File Upload Security

```bash
# Scenario: Implementing file upload feature
ralph security src/upload/

# Output: 2 CRITICAL findings
# - Command injection in filename handling (CWE-78)
# - Path traversal in storage location (CWE-22)
```

### Example 4: Task Tool Invocation with Second Opinion

```yaml
# Primary audit
Task:
  subagent_type: "security-auditor"
  model: "sonnet"
  run_in_background: true
  description: "Codex: Security audit of auth module"
  prompt: |
    codex exec -m gpt-5.2-codex "
    Security audit: src/auth/
    Focus on authentication bypasses, session hijacking, and credential storage.
    JSON output with CWE/OWASP references.
    "

# Second opinion
Task:
  subagent_type: "minimax-reviewer"
  model: "sonnet"
  run_in_background: true
  description: "MiniMax: Validate Codex findings"
  prompt: |
    mmc --query "
    Independent security review: src/auth/
    Cross-validate Codex findings and find missed issues.
    Same JSON format.
    "
```

### Example 5: Integration with Worktree Workflow

```bash
# Create isolated worktree for security fixes
ralph worktree "fix-security-findings"

# Run security audit in worktree
cd ~/worktrees/fix-security-findings
ralph security src/

# Fix findings, then PR review with multi-agent validation
ralph worktree-pr fix-security-findings
```

## Anti-Patterns

- **Don't skip security audits for "quick fixes"** - Small changes can introduce big vulnerabilities
- **Don't ignore LOW severity findings** - Multiple LOW can combine to HIGH impact
- **Don't trust static analysis alone** - Manual review + penetration testing required
- **Don't audit third-party code** - Focus on your code; use dependency scanners for libraries
- **Don't send proprietary code to external services** - Check company policies first

## Advanced Usage

### Custom Security Rules

```bash
# Audit with custom CWE focus
ralph security src/ --cwe CWE-78,CWE-89,CWE-79

# Audit with severity threshold
ralph security src/ --min-severity HIGH

# Audit with specific OWASP category
ralph security src/ --owasp A03:2021-Injection
```

### Continuous Security Monitoring

```bash
# Add to CI/CD pipeline
name: Security Audit
on: [push, pull_request]
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: ralph security . --output security-report.json
      - run: |
          if jq -e '.summary.critical > 0 or .summary.high > 1' security-report.json; then
            echo "Security audit failed"
            exit 1
          fi
```

### Security Loop Pattern

```bash
# Iterate until all findings resolved
ralph loop --security "Fix security findings in src/auth/"

# The loop will:
# 1. Run security audit
# 2. Apply fixes
# 3. Re-audit
# 4. Repeat until clean (max 15 iterations)
```
