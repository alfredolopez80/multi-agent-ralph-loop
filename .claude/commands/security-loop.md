---
name: security-loop
prefix: "@secloop"
category: review
color: red
description: "Multi-level iterative security audit until zero vulnerabilities"
argument-hint: "<path> [--max-rounds N] [--yolo|--strict|--hybrid]"
---

# /security-loop - Multi-Level Iterative Security Audit (v2.27)

Runs security audit → fixes issues → re-audits iteratively until zero vulnerabilities or max rounds reached.

## Usage

```bash
/security-loop <path>
/security-loop src/ --max-rounds 5
@secloop . --yolo
@secloop src/auth/ --strict
```

## Execution

When `/security-loop` is invoked:

### Step 1: Validate Requirements

```yaml
require_tool: "codex"
required_for: "multi-level security loop"
```

### Step 2: Initialize Loop

```yaml
config:
  target: $PATH
  max_rounds: 10  # Default, configurable
  approval_mode: hybrid  # Default
  total_fixed: 0
```

### Step 3: Execute Loop (per round)

```
┌─────────────────────────────────────────────────────────────────┐
│  ROUND N                                                        │
│                                                                 │
│  [1/3] AUDIT                                                    │
│  codex exec --yolo --enable-skills -m gpt-5.2-codex            │
│  "Perform comprehensive security audit..."                      │
│  Output: JSON with vulnerabilities array + summary              │
│                                                                 │
│  [2/3] PARSE                                                    │
│  Extract: critical, high, medium, low counts                    │
│  If total == 0: EXIT SUCCESS                                    │
│                                                                 │
│  [3/3] FIX (based on approval_mode)                            │
│  • hybrid: Auto-fix MEDIUM/LOW, ask for CRITICAL/HIGH          │
│  • yolo: Auto-fix ALL                                          │
│  • strict: Ask approval for EVERY fix                          │
│                                                                 │
│  VALIDATE: Run syntax checks on modified files                  │
│  LOOP: Continue to next round                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Approval Modes

| Mode | Flag | Behavior | Use Case |
|------|------|----------|----------|
| **Hybrid** | (default) | Auto-fix LOW/MEDIUM, ask for HIGH/CRITICAL | Production code |
| YOLO | `--yolo` | Auto-approve ALL fixes | CI/CD, trusted codebase |
| Strict | `--strict` | Ask approval for EVERY fix | Critical systems |

## Hybrid Mode User Interaction

When CRITICAL or HIGH vulnerabilities are found in hybrid mode, the user is prompted:

```
CRITICAL: SQL Injection in users.py:45
┌─────────────────────────────────────────────────────────────────┐
│ Proposed fix:                                                   │
│ - query = f"SELECT * FROM users WHERE id = {user_id}"          │
│ + query = "SELECT * FROM users WHERE id = ?"                   │
│ + cursor.execute(query, (user_id,))                            │
└─────────────────────────────────────────────────────────────────┘
Apply this fix? [Yes / No / Edit]
```

## Security Checks (CWEs)

| Check | CWE | Description |
|-------|-----|-------------|
| Command Injection | CWE-78 | Shell command construction with user input |
| SQL Injection | CWE-89 | Database queries with unsanitized input |
| Path Traversal | CWE-22 | File paths with `..` or absolute paths |
| XSS | CWE-79 | HTML/JS output without encoding |
| Auth Bypass | CWE-287 | Missing or weak authentication |
| Sensitive Data | CWE-200 | Exposed secrets, tokens, credentials |
| Weak Crypto | CWE-327 | MD5, SHA1, weak encryption |

## Examples

### Basic Usage

```bash
# Audit entire project (default: 10 rounds, hybrid mode)
/security-loop src/

# Same with prefix shortcut
@secloop src/
```

### Custom Configuration

```bash
# Quick audit with 3 rounds max
/security-loop . --max-rounds 3

# Full auto mode for CI/CD
@secloop . --yolo --max-rounds 5

# Careful mode for sensitive code
@secloop src/auth/ --strict
```

### CLI Alternative

```bash
ralph security-loop src/
ralph security-loop . --max-rounds 5
ralph secloop src/ --yolo
```

## Output Format

### Success (0 vulnerabilities)

```
╔═══════════════════════════════════════════════════════════════╗
║  SECURITY LOOP COMPLETED SUCCESSFULLY                         ║
╠═══════════════════════════════════════════════════════════════╣
║  Rounds:       3                                              ║
║  Total Fixed:  12 vulnerabilities                             ║
║  Duration:     45 seconds                                     ║
║                                                               ║
║  Result: NO VULNERABILITIES REMAINING                         ║
╚═══════════════════════════════════════════════════════════════╝
```

### Max Rounds Reached

```
╔═══════════════════════════════════════════════════════════════╗
║  SECURITY LOOP: MAX ROUNDS REACHED                            ║
╠═══════════════════════════════════════════════════════════════╣
║  Rounds:       10/10                                          ║
║  Total Fixed:  8 vulnerabilities                              ║
║  Duration:     120 seconds                                    ║
║                                                               ║
║  MANUAL REVIEW REQUIRED                                       ║
║  Some vulnerabilities may remain. Check:                      ║
║    /tmp/ralph.xxx/security_audit_round_10.json                ║
╚═══════════════════════════════════════════════════════════════╝
```

## Integration with Ralph Loop

The security loop follows the Ralph Loop pattern:

```
EXECUTE → VALIDATE → Quality Passed? → ITERATE (max rounds)
                            ↓
                     VERIFIED_DONE (0 vulns)
```

## Related Commands

- `/security` - Single-pass security audit
- `/adversarial` - 2/3 consensus validation
- `/gates` - Quality gates validation
