---
name: security
prefix: "@sec"
category: review
color: red
description: "Security audit with Codex + MiniMax"
argument-hint: "<path>"
---

# /security

Security-focused audit using Codex CLI + MiniMax.

## Execution

Use Task tool with security-auditor agent:
```yaml
Task:
  subagent_type: "security-auditor"
  description: "Security audit"
  prompt: "Audit for vulnerabilities: $ARGUMENTS"
```

Or via CLI: `ralph security "$ARGUMENTS"`
