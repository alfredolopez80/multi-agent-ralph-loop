# Security Model - Multi-Agent Ralph Loop v2.89

**Date**: 2026-02-15
**Version**: v2.89.1
**Status**: COMPLETE

## Threat Model

### What We Protect Against

| Threat | Attack Vector | Mitigation |
|--------|---------------|------------|
| **Settings hijacking** | Agent modifies `settings.json` to escalate permissions | Deny list: `Write/Edit(**/.claude/settings.json)` |
| **Secret exfiltration** | Agent reads `.env`, SSH keys, credentials | Deny list: `Read(**/.env)`, `Read(**/.ssh/**)`, etc. |
| **Destructive commands** | `rm -rf /`, `git reset --hard` | `git-safety-guard.py` PreToolUse hook (fail-closed) |
| **Command chaining bypass** | `echo safe && rm -rf /` | `split_chained_commands()` validates each subcommand |
| **Repository escape** | Agent edits files outside current repo | `repo-boundary-guard.sh` with `realpath` canonicalization |
| **Plugin supply chain** | Compromised plugin injects malicious hooks | `auto-sync-global.sh` whitelist, plugin cache read denied |
| **State tampering** | Modified ledgers/handoffs inject prompt injection | SHA-256 checksums via `handoff-integrity.sh` |
| **Race conditions** | Parallel agents corrupt plan-state.json | `mkdir`-based atomic locking in plan-state hooks |
| **Docker privilege escalation** | `docker run --privileged` via Gordon MCP | Restricted to safe Gordon tools only |
| **Credential leakage** | Realistic credentials in test files | FAKE/TESTONLY markers, no `sk-live-*` patterns |

### Trust Boundaries

```
+------------------------------------------------------------------+
|  USER TRUST ZONE                                                  |
|  - User runs Claude Code CLI directly                             |
|  - User approves dangerous operations (skipDangerous=false)       |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|  CLAUDE CODE TRUST ZONE                                           |
|  - PreToolUse hooks validate BEFORE execution                     |
|  - PostToolUse hooks validate AFTER execution                     |
|  - Deny list blocks sensitive file access                         |
|  - Sandbox mode for risky operations                              |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|  AGENT TEAMS ZONE (Semi-trusted)                                  |
|  - ralph-* subagents execute with tool restrictions               |
|  - TeammateIdle quality gates validate work                       |
|  - TaskCompleted gates verify acceptance criteria                 |
|  - SubagentStart injects verified context only                    |
+------------------------------------------------------------------+
         |
         v
+------------------------------------------------------------------+
|  FILESYSTEM ZONE (Protected)                                      |
|  - ~/.ralph/ state files (checksums required)                     |
|  - .claude/hooks/ (whitelisted sync only)                         |
|  - .env, .ssh, .aws, .kube (read denied)                         |
|  - settings.json (write/edit denied)                              |
+------------------------------------------------------------------+
```

## Security Controls

### 1. Permission System (`settings.json`)

**Allow List** (explicit permissions):
- `Bash(git:*)` - Git operations only
- `Bash(ralph:*)` - Ralph CLI only
- `Bash(gh pr:*)`, `Bash(gh api:*)` - GitHub CLI

**Deny List** (28 patterns blocking):

| Category | Patterns | Count |
|----------|----------|-------|
| Cloud credentials | `.ssh`, `.gnupg`, `.aws`, `.azure`, `.kube` | 5 |
| App credentials | `.npmrc`, `.pypirc`, `.gem/credentials`, `.git-credentials` | 4 |
| Environment | `.env`, `.env.*`, `.netrc` | 3 |
| SSH keys | `id_rsa`, `id_ed25519` | 2 |
| System | `Library/Keychains`, `.docker/config.json`, `.config/gh` | 3 |
| Shell config | `.bashrc`, `.zshrc`, `.bash_profile`, `.profile` | 4 |
| Self-protection | `.claude/settings.json` (Write + Edit) | 2 |
| Plugin isolation | `.claude/plugins/cache/**` | 1 |
| MCP restrictions | Specific MCP tools | 3 |

### 2. PreToolUse Hooks (Block Before Execution)

| Hook | Matcher | Purpose |
|------|---------|---------|
| `git-safety-guard.py` | Bash | Block destructive git/filesystem commands |
| `repo-boundary-guard.sh` | Bash | Prevent work outside repository |
| `checkpoint-auto-save.sh` | Edit\|Write | Auto-save before file changes |
| `skill-validator.sh` | Task | Validate skill invocations |
| `promptify-security.sh` | Task | Redact credentials from prompts |

### 3. PostToolUse Hooks (Validate After Execution)

| Hook | Matcher | Purpose |
|------|---------|---------|
| `quality-gates-v2.sh` | Edit\|Write\|Bash | Multi-stage quality validation |
| `security-full-audit.sh` | Edit\|Write\|Bash | Security scanning |
| `console-log-detector.sh` | Edit\|Write\|Bash | Debug statement detection |
| `ai-code-audit.sh` | Edit\|Write\|Bash | AI-assisted code review |

### 4. Agent Teams Security

| Event | Hook | Security Function |
|-------|------|-------------------|
| `TeammateIdle` | `teammate-idle-quality-gate.sh` | Verify work quality before idle |
| `TaskCompleted` | `task-completed-quality-gate.sh` | Verify acceptance criteria met |
| `SubagentStart` | `ralph-subagent-start.sh` | Inject verified context only |
| `SubagentStop` | `glm5-subagent-stop.sh` | Quality gate on stop |

**Agent Teams Implications**:
- `defaultMode: delegate` enables autonomous execution without confirmation
- Subagents inherit parent permissions but have restricted tool access
- Quality gates (Exit 2) can prevent premature task completion
- Context injection via `SubagentStart` must be integrity-verified

### 5. State Integrity

| Mechanism | Purpose |
|-----------|---------|
| SHA-256 checksums | Verify handoff/ledger integrity on restore |
| Content sanitization | Filter control chars and prompt injection from state |
| File locking | Prevent race conditions in plan-state.json |
| Umask 077 | Restrict file permissions on state files |

## Audit History

| Date | Version | Findings | Fixed |
|------|---------|----------|-------|
| 2026-01-22 | v2.60.0 | Hook system audit | Smart-skill-reminder fix |
| 2026-02-04 | v2.83.1 | rm -rf bypass | git-safety-guard registration |
| 2026-02-15 | v2.89.0 | Validation audit | 102 hooks cataloged, 5 fixes |
| 2026-02-15 | v2.89.1 | Security hardening | 14 findings, all remediated |

## Security Best Practices for Users

1. **Keep `skipDangerousModePermissionPrompt: false`** - Always require confirmation for dangerous operations
2. **Review deny list periodically** - Ensure new sensitive paths are blocked
3. **Run `validate-hooks-registration.sh`** - Verify critical hooks remain registered
4. **Monitor `~/.ralph/logs/`** - Review security event logs
5. **Use `suggest` mode for production** - Only use `delegate` during supervised Agent Teams sessions
6. **Run security tests regularly** - `bats tests/security/test-security-hardening-v2.89.bats`

## Verification Commands

```bash
# Full security test suite
bats tests/security/test-security-hardening-v2.89.bats

# Verify settings valid
python3 -c "import json; json.load(open('$HOME/.claude/settings.json'))"

# Verify deny list
grep -c 'deny' ~/.claude/settings.json

# Verify hooks registered
python3 -c "
import json
cfg=json.load(open('$HOME/.claude/settings.json'))
hooks=cfg['hooks']
total=sum(len(h.get('hooks',[])) for entries in hooks.values() for h in entries)
print(f'Events: {len(hooks)}, Hooks: {total}')
"

# Scan for leaked credentials
grep -r 'sk-live\|AKIA\|ghp_' tests/ && echo 'FAIL' || echo 'CLEAN'
```

## References

- [Security Hardening PRD](../prd/security-hardening-v2.89.prq.md)
- [Hook Registration Fix v2.83.1](../bugs/HOOK_REGISTRATION_FIX_v2.83.1.md)
- [Validation Audit v2.89](../prd/ralph-validation-audit-v2.89.prq.md)
- [CWE-269](https://cwe.mitre.org/data/definitions/269.html) - Improper Privilege Management
- [CWE-345](https://cwe.mitre.org/data/definitions/345.html) - Insufficient Data Verification
- [CWE-367](https://cwe.mitre.org/data/definitions/367.html) - TOCTOU Race Condition
- [CWE-78](https://cwe.mitre.org/data/definitions/78.html) - OS Command Injection
