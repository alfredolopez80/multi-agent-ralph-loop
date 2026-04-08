# Threat Model: Claude Code Hooks -- sanitize-secrets.js & aristotle-analysis-display.sh

**Date**: 2026-04-08
**Framework**: STRIDE
**Scope**: Two Claude Code hooks in `.claude/hooks/`
**Author**: Threat modeling analysis (adversarial review)
**Related**: `docs/security/SECURITY_MODEL_v2.89.md`

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Hook Profiles](#2-hook-profiles)
3. [Trust Boundaries](#3-trust-boundaries)
4. [Data Flow Diagrams](#4-data-flow-diagrams)
5. [STRIDE Analysis: sanitize-secrets.js](#5-stride-analysis-sanitize-secretsjs)
6. [STRIDE Analysis: aristotle-analysis-display.sh](#6-stride-analysis-aristotle-analysis-displaysh)
7. [Attack Trees](#7-attack-trees)
8. [Risk Matrix](#8-risk-matrix)
9. [Mitigations Summary](#9-mitigations-summary)
10. [Residual Risks](#10-residual-risks)

---

## 1. Executive Summary

This report applies the STRIDE threat modeling framework to two Claude Code hooks that operate at different trust boundaries:

- **sanitize-secrets.js** (PostToolUse): A secret-detection hook that scans tool output for 20+ credential patterns. Despite its name, the hook **cannot modify** tool output (PostToolUse limitation) -- it logs detections to stderr and always returns `{"continue": true}`. Its security value is **audit-only**.

- **aristotle-analysis-display.sh** (UserPromptSubmit): A complexity-estimation hook that injects Aristotle First Principles reminders as `systemMessage` when user prompts score >= 3 on a heuristic scale. It **modifies the conversation** by injecting instructional content into the LLM context.

Key findings:
- sanitize-secrets.js has a false sense of security: it detects but does not block secrets (CWE-200, CWE-778)
- aristotle-analysis-display.sh is susceptible to prompt manipulation that controls which system messages get injected (CWE-94)
- Both hooks trust stdin implicitly with only size-limit guards
- Neither hook validates the integrity of its own executable (CWE-733)

---

## 2. Hook Profiles

### 2.1 sanitize-secrets.js

| Attribute | Value |
|-----------|-------|
| **Path** | `.claude/hooks/sanitize-secrets.js` |
| **Event** | `PostToolUse` |
| **Language** | Node.js (shebang: `#!/usr/bin/env node`) |
| **Permissions** | `-rwxr-xr-x` (owner: alfredolopez, group: staff) |
| **Input** | JSON via stdin (tool output from Claude Code) |
| **Output** | `{"continue": true}` to stdout; audit logs to stderr |
| **Max input** | 1 MB (1,048,576 bytes) |
| **Timeout** | 5 seconds |
| **Secret patterns** | 20+ regex patterns (GitHub PAT, OpenAI, AWS, ETH keys, JWT, etc.) |
| **umask** | `0o077` |
| **Fail mode** | Fail-open (always outputs `continue: true`) |

### 2.2 aristotle-analysis-display.sh

| Attribute | Value |
|-----------|-------|
| **Path** | `.claude/hooks/aristotle-analysis-display.sh` |
| **Event** | `UserPromptSubmit` |
| **Language** | Bash (shebang: `#!/usr/bin/env bash`) |
| **Permissions** | `-rwxr-xr-x` (owner: alfredolopez, group: staff) |
| **Input** | JSON via stdin (user prompt from Claude Code) |
| **Output** | `{"continue": true}` or `{"continue": true, "systemMessage": "..."}` |
| **Max input** | 100 KB (`head -c 100000`) |
| **Timeout** | None (relies on Claude Code's process timeout) |
| **Complexity engine** | Regex-based heuristic scoring (1-10 scale) |
| **umask** | `077` |
| **Fail mode** | Fail-open (defaults to `{"continue": true}`) |

---

## 3. Trust Boundaries

### 3.1 Trust Boundary Diagram

```
+=====================================================================+
|  CLAUDE CODE HARNESS (Trusted)                                      |
|  - Dispatches hook events via stdin                                  |
|  - Reads hook stdout as JSON                                         |
|  - Enforces hook timeout/kill                                        |
|                                                                     |
|  +---------- stdin (JSON) --------+  +------ stdout (JSON) ------+ |
|  |                                 |  |                           | |
|  v                                 |  |                           | |
+==+==================================+==+===========================+==+
   |  HOOK PROCESS (Semi-trusted)    |  |                           |
   |                                 |  |                           |
   |  +---------------------------+  |  |                           |
   |  | stdin read + size guard   |  |  |                           |
   |  +---------------------------+  |  |                           |
   |           |                     |  |                           |
   |           v                     |  |                           |
   |  +---------------------------+  |  |                           |
   |  | JSON parse (jq or JS)     |  |  |                           |
   |  +---------------------------+  |  |                           |
   |           |                     |  |                           |
   |           v                     |  |                           |
   |  +---------------------------+  |  |                           |
   |  | Processing (regex/logic)  |  |  |                           |
   |  +---------------------------+  |  |                           |
   |           |                     |  |                           |
   |           v                     |  |                           |
   |  +---------------------------+  |  |                           |
   |  | JSON output to stdout     |--+  |                           |
   |  +---------------------------+     |                           |
   |                                    |                           |
   |  +---------------------------+     |                           |
   |  | Audit logs to stderr      |-----+--> ~/.ralph/logs/         |
   |  +---------------------------+                                 |
   +==================================================================+

                    EXTERNAL TRUST BOUNDARIES

  +-------------------------------+
  |  FILESYSTEM (Semi-trusted)    |
  |  - Hook executable read       |
  |  - Log file writes            |
  |  - Git repository access      |
  +-------------------------------+

  +-------------------------------+
  |  ENVIRONMENT (Trusted)        |
  |  - PATH resolution            |
  |  - XDG_RUNTIME_DIR / HOME     |
  |  - Node.js / Bash runtime     |
  +-------------------------------+
```

### 3.2 Trust Assumptions

| Trust Relationship | Rationale |
|--------------------|-----------|
| Claude Code -> Hook stdin | Claude Code is the trusted dispatch; hook receives validated JSON |
| Hook -> stdout | Claude Code trusts hook output as valid JSON; no signature verification |
| Hook -> stderr | Logs to `~/.ralph/logs/` with `umask 077`; filesystem permissions trusted |
| Hook -> filesystem | Only write is log rotation; path uses `$HOME` or `$XDG_RUNTIME_DIR` |
| `node` / `bash` runtime | Trusted (system-installed interpreters) |
| `jq` binary | Trusted for JSON construction (aristotle hook); not used for parsing secrets |

---

## 4. Data Flow Diagrams

### 4.1 sanitize-secrets.js -- Data Flow

```
[1] Claude Code dispatch
    |
    | JSON: { tool_name, tool_output, ... }
    v
[2] stdin read (async iterator, chunks)
    |
    | Accumulate string, enforce 1MB limit
    | Timeout: 5s -> destroy stdin
    v
[3] JSON.parse(input)
    |
    | Success? -> [4a]     Fail? -> [4b]
    v                       v
[4a] sanitizeObject(data)  [4b] sanitizeText(raw input)
    |                       |
    | Walk all string       | Single-pass regex on raw text
    | values, apply 20+    | Log parse failure to file
    | regex patterns        |
    |                       |
    v                       v
[5] Update stats counters (totalRedactions, byType)
    |
    v
[6] Log to stderr (if any redactions)
    |
    v
[7] Output: {"continue": true}
```

**Data at rest**: Log file at `~/.ralph/logs/sanitize-secrets.log` (contains timestamp, error messages, but NOT secret values -- only type counts).

### 4.2 aristotle-analysis-display.sh -- Data Flow

```
[1] Claude Code dispatch
    |
    | JSON: { prompt: "user's message", ... }
    v
[2] head -c 100000 (truncate at 100KB)
    |
    v
[3] jq -r '.prompt // ""' (extract prompt text)
    |
    v
[4] estimate_complexity(prompt)
    |
    | Regex matching on lowercased prompt:
    |   - High: refactor, architecture, migrate, system...
    |   - Moderate: implement, feature, bug, test...
    |   - Low: what is, show me, quick, simple...
    |   - Clamped to [1, 10]
    v
[5] Branch on complexity score:
    |
    | >= 4 -> Full Aristotle 5-phase systemMessage
    | == 3  -> Quick Aristotle reminder
    | <= 2  -> No message (silent pass-through)
    v
[6] Construct output JSON via jq -n
    | { continue: true, systemMessage: "..." }
    | or { continue: true }
    v
[7] Output to stdout
```

**Data at rest**: None (stateless, no file writes).

---

## 5. STRIDE Analysis: sanitize-secrets.js

### S -- Spoofing

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| SS-S1 | **Forge hook input** | An attacker with filesystem access could pipe crafted JSON to the hook process to test which patterns are detected, learning the detection rules. | CWE-346 | Medium |
| SS-S2 | **Forge hook executable** | If an attacker can write to `.claude/hooks/`, they can replace sanitize-secrets.js with a trojan that exfiltrates detected secrets to an external endpoint. | CWE-733 | Critical |
| SS-S3 | **Environment variable manipulation** | The log path uses `$XDG_RUNTIME_DIR` or `$HOME`. An attacker who controls these can redirect logs to a world-readable location. | CWE-426 | Medium |

### T -- Tampering

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| SS-T1 | **Regex modification** | The `SECRET_PATTERNS` array is defined in plain JavaScript. Any write access to the file allows an attacker to remove or weaken detection patterns (e.g., remove the ETH private key pattern). | CWE-733 | High |
| SS-T2 | **Fail-open bypass** | The hook always returns `{"continue": true}` regardless of detection results. An attacker who causes the hook to crash or timeout achieves the same result -- no blocking of the operation. | CWE-778 | High |
| SS-T3 | **Log file tampering** | An attacker with write access to `~/.ralph/logs/sanitize-secrets.log` can delete or modify audit entries. No integrity protection (no hash/signature). | CWE-276 | Medium |
| SS-T4 | **Size truncation bypass** | Input beyond 1MB is truncated. An attacker can craft a 1MB+ payload where the secret is placed after the truncation point. | CWE-400 | Low |

### R -- Repudiation

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| SS-R1 | **No detection logging** | If `stats.totalRedactions == 0`, nothing is logged. A missed detection (false negative) leaves no audit trail. | CWE-778 | Medium |
| SS-R2 | **Log rotation destroys evidence** | Log rotation deletes the file when >5MB. An attacker could flood the log to trigger rotation, destroying previous forensic evidence. | CWE-780 | Medium |
| SS-R3 | **No integrity on log entries** | Log entries are plain text with timestamps. No HMAC or chain-of-custody mechanism. An attacker can insert fake entries or modify existing ones. | CWE-276 | Low |

### I -- Information Disclosure

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| SS-I1 | **Secrets NOT actually redacted** | Despite the hook name ("sanitize-secrets"), PostToolUse hooks CANNOT modify tool output. The detected secret passes through to Claude's context unmodified. The hook only logs counts to stderr. This is the most significant finding: users may believe secrets are being redacted when they are not. | CWE-200 | Critical |
| SS-I2 | **Pattern list exposure** | The 20+ regex patterns are readable in plain text. An attacker can study the patterns to craft secrets that evade detection (e.g., using base64 encoding not matching the generic pattern, or inserting invisible Unicode characters). | CWE-200 | Medium |
| SS-I3 | **Log path disclosure via error** | On parse error, the log path is constructed and written to. The error handler creates directories. An attacker who can trigger errors can verify directory structure and existence. | CWE-209 | Low |
| SS-I4 | **False negatives** | The regex patterns have known gaps: they do not detect secrets split across multiple lines, secrets in binary data, secrets using custom encoding, or secrets in non-standard formats. | CWE-200 | Medium |

### D -- Denial of Service

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| SS-D1 | **ReDoS via crafted input** | Several patterns use nested quantifiers or backtracking-heavy regex on attacker-controlled input. The 5-second timeout mitigates but does not prevent resource exhaustion. | CWE-1333 | Medium |
| SS-D2 | **Memory exhaustion** | The hook accumulates input as a string (concatenation in a for-await loop). For 1MB inputs, this creates multiple intermediate strings. The 1MB cap prevents worst case but the pattern is inefficient. | CWE-400 | Low |
| SS-D3 | **Stdin pipe hanging** | If the stdin pipe is not closed by Claude Code, the async iterator will block. The 5-second timeout guard handles this by destroying stdin, but there is a window. | CWE-400 | Low |
| SS-D4 | **Log file unbounded growth** | Although rotation occurs at 5MB, the rotation is a simple delete (not archive). During active sessions with many redactions, the log can grow to 5MB before rotation triggers. | CWE-400 | Trivial |

### E -- Elevation of Privilege

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| SS-E1 | **Code injection via prototype pollution** | The `sanitizeObject` function iterates `Object.entries(obj)` and constructs a new object. If the input JSON contains `__proto__`, `constructor`, or `prototype` keys, the resulting object could theoretically be exploited. However, the function only copies values, not executes them, making exploitation unlikely. | CWE-1321 | Low |
| SS-E2 | **File write via log path** | The error handler writes to `fs.appendFileSync`. An attacker who can control `$HOME` or `$XDG_RUNTIME_DIR` can redirect this write to an arbitrary location. The `umask 077` limits damage but does not prevent the write itself. | CWE-426 | Medium |
| SS-E3 | **No signature verification** | Claude Code does not verify the integrity of the hook executable before executing it. Any process with write access to the hooks directory can replace the hook. | CWE-733 | High |

---

## 6. STRIDE Analysis: aristotle-analysis-display.sh

### S -- Spoofing

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| AA-S1 | **Inject systemMessage content** | A user prompt crafted with specific keywords ("refactor", "architecture", "multi-agent") triggers systemMessage injection. The content is fixed (Aristotle reminder), but the act of injection itself changes LLM behavior. | CWE-94 | Medium |
| AA-S2 | **Bypass complexity estimation** | An attacker can craft prompts that look complex but are malicious, or conversely, hide complex attacks behind "simple" language to suppress the Aristotle reminder. | CWE-20 | Low |
| AA-S3 | **jq binary replacement** | If `jq` in PATH is replaced with a malicious binary, it can capture the user prompt (sent via `--arg`) or inject arbitrary content into the output JSON. | CWE-426 | High |

### T -- Tampering

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| AA-T1 | **Modify complexity rules** | The regex rules are in plain bash. An attacker with write access can add patterns that always trigger systemMessage (or never trigger it), effectively controlling which prompts get Aristotle analysis. | CWE-733 | Medium |
| AA-T2 | **jq injection** | The prompt is passed to jq via `--arg msg "$SYSTEM_MESSAGE"`. While jq handles quoting, if the bash variable expansion is flawed, special characters in the prompt could break JSON structure. However, `jq -n --arg` is the correct safe pattern. | CWE-78 | Low |
| AA-T3 | **Modify output JSON** | The complexity score determines the output. If the `estimate_complexity` function is tampered to always return 1, the hook becomes a no-op. | CWE-733 | Medium |

### R -- Repudiation

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| AA-R1 | **No logging** | The hook produces no logs. There is no record of which prompts triggered Aristotle analysis or what complexity score was computed. | CWE-778 | Low |
| AA-R2 | **Stateless execution** | Each invocation is independent. There is no way to reconstruct the history of systemMessage injections after the fact. | CWE-778 | Trivial |

### I -- Information Disclosure

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| AA-I1 | **Prompt content in process listing** | The user prompt is read from stdin, but `estimate_complexity` uses bash variables. If any subprocess or debugging tool captures the process environment, the prompt content could be visible. | CWE-200 | Trivial |
| AA-I2 | **No secrets in output** | The hook output contains only complexity scores and fixed instructional text. No user data is leaked in the output. | N/A | None |
| AA-I3 | **Timing side-channel** | The complexity estimation takes variable time depending on prompt content and regex matching. An observer who can measure execution time could infer prompt characteristics. | CWE-208 | Trivial |

### D -- Denial of Service

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| AA-D1 | **No timeout guard** | Unlike sanitize-secrets.js, this hook has NO timeout. If `jq` or bash hangs (e.g., waiting for more stdin), the hook will block indefinitely until Claude Code kills the process. | CWE-400 | Medium |
| AA-D2 | **Regex complexity in bash** | The `=~` operator with multiple regex patterns is executed sequentially. For a 100KB prompt with many regex evaluations, this could be slow. | CWE-400 | Low |
| AA-D3 | **head -c partial read** | `head -c 100000` may produce invalid JSON if truncation occurs mid-character (unlikely for ASCII, possible for multi-byte UTF-8). The `jq` parse would fail, defaulting to `{"continue": true}`. | CWE-20 | Low |

### E -- Elevation of Privilege

| ID | Threat | Description | CWE | Severity |
|----|--------|-------------|-----|----------|
| AA-E1 | **systemMessage injection into LLM context** | The `systemMessage` field is injected into Claude's context as instructional content. While the current content is fixed (Aristotle reminder), the existence of this channel represents an injection vector. If the hook is modified, arbitrary instructions could be injected. | CWE-94 | High |
| AA-E2 | **Prompt manipulation controls LLM behavior** | A user who understands the complexity scoring rules can craft prompts that deliberately trigger or suppress the Aristotle reminder, effectively controlling which guardrails the LLM applies. | CWE-20 | Medium |
| AA-E3 | **Bash glob/word splitting** | The prompt variable is properly quoted throughout ("$PROMPT", "$lower_prompt"), but if a future modification removes quoting, word splitting could cause unexpected behavior. | CWE-78 | Low |

---

## 7. Attack Trees

### 7.1 Attack Tree: sanitize-secrets.js

```
GOAL: Exfiltrate secrets past sanitize-secrets detection
|
+-- [OR] Bypass detection entirely
|   |
|   +-- [AND] Place secret after 1MB truncation point
|   |   |-- Generate 1MB+ of valid JSON payload
|   |   +-- Embed secret in the post-truncation portion
|   |       (Feasibility: LOW -- Claude Code controls input size)
|   |
|   +-- [AND] Use encoding not covered by patterns
|   |   |-- Encode secret in base85, hex, or URL encoding
|   |   +-- The "Base64 Encoded Secret" pattern requires a label
|   |       (key=, token=, secret=, credential=) to trigger
|   |       (Feasibility: MEDIUM -- unlabeled base64 not detected)
|   |
|   +-- [AND] Split secret across multiple tool outputs
|       |-- Each piece is below pattern threshold
|       +-- Reassemble outside the hook
|           (Feasibility: MEDIUM -- hook is per-tool-output)
|
+-- [OR] Disable the hook
|   |
|   +-- [AND] Replace hook executable
|       |-- Write access to .claude/hooks/
|       +-- Replace with echo '{"continue":true}'
|           (Feasibility: depends on filesystem access)
|
+-- [OR] Exploit false sense of security
    |
    +-- [AND] Rely on hook NOT actually redacting
        |-- Hook detects and logs but does not block
        +-- Secret passes through to Claude context unmodified
        +-- User believes hook provides protection
            (Feasibility: HIGH -- this is the current state)
```

### 7.2 Attack Tree: aristotle-analysis-display.sh

```
GOAL: Control Aristotle systemMessage injection
|
+-- [OR] Trigger systemMessage for prompt injection
|   |
|   +-- [AND] Include high-complexity keywords
|       |-- Use "refactor", "architecture", "migrate"
|       +-- Score reaches >= 4
|       +-- Full Aristotle 5-phase message is injected
|           (Impact: LOW -- content is fixed, not user-controlled)
|
+-- [OR] Suppress systemMessage for complex attacks
|   |
|   +-- [AND] Wrap malicious content in "simple" language
|       |-- Prefix with "just", "quick", "simple"
|       +-- Include "fix typo" or "minor edit" to reduce score
|       +-- Suppress Aristotle analysis on complex attack
|           (Feasibility: MEDIUM -- regex scoring is predictable)
|
+-- [OR] Modify hook to inject arbitrary instructions
|   |
|   +-- [AND] Write to .claude/hooks/aristotle-analysis-display.sh
|       |-- Replace SYSTEM_MESSAGE with attacker-controlled text
|       +-- systemMessage field accepts any string
|       +-- Claude treats it as system-level instruction
|           (Feasibility: depends on filesystem access)
|           (Impact: CRITICAL -- arbitrary system prompt injection)
|
+-- [OR] Exploit jq path for code execution
    |
    +-- [AND] Replace jq binary in PATH
        |-- Write access to a directory in PATH
        +-- Malicious jq captures prompt data
        +-- Or injects arbitrary JSON into output
            (Feasibility: depends on PATH integrity)
```

---

## 8. Risk Matrix

### 8.1 Risk Scoring

| Scale | Value |
|-------|-------|
| **Likelihood** | 1 (Rare) to 5 (Almost Certain) |
| **Impact** | 1 (Negligible) to 5 (Critical) |
| **Risk Score** | Likelihood x Impact |

### 8.2 sanitize-secrets.js Risk Matrix

| ID | Threat | Likelihood | Impact | Risk | Priority |
|----|--------|------------|--------|------|----------|
| SS-I1 | Secrets NOT actually redacted (audit-only) | 5 | 5 | **25** | P0 |
| SS-T2 | Fail-open bypass (always returns continue) | 4 | 4 | **16** | P1 |
| SS-E3 | No executable integrity verification | 3 | 5 | **15** | P1 |
| SS-S2 | Hook executable replacement (trojan) | 2 | 5 | **10** | P2 |
| SS-T1 | Regex pattern removal/weakening | 2 | 4 | **8** | P2 |
| SS-I4 | False negatives in detection | 3 | 3 | **9** | P2 |
| SS-S1 | Forge hook input for pattern testing | 2 | 3 | **6** | P3 |
| SS-S3 | Environment variable log path hijack | 2 | 3 | **6** | P3 |
| SS-T3 | Log file tampering | 2 | 3 | **6** | P3 |
| SS-D1 | ReDoS via crafted input | 2 | 3 | **6** | P3 |
| SS-E2 | File write via log path manipulation | 1 | 4 | **4** | P3 |
| SS-R1 | No detection logging on false negatives | 3 | 2 | **6** | P3 |
| SS-R2 | Log rotation destroys evidence | 2 | 2 | **4** | P4 |
| SS-I2 | Pattern list exposure | 2 | 2 | **4** | P4 |
| SS-T4 | Size truncation bypass | 1 | 3 | **3** | P4 |
| SS-R3 | No log entry integrity | 1 | 2 | **2** | P5 |
| SS-I3 | Log path disclosure via error | 1 | 2 | **2** | P5 |
| SS-D2 | Memory exhaustion | 1 | 2 | **2** | P5 |
| SS-D3 | Stdin pipe hanging | 1 | 2 | **2** | P5 |
| SS-D4 | Log file unbounded growth | 1 | 1 | **1** | P5 |
| SS-E1 | Prototype pollution | 1 | 2 | **2** | P5 |

### 8.3 aristotle-analysis-display.sh Risk Matrix

| ID | Threat | Likelihood | Impact | Risk | Priority |
|----|--------|------------|--------|------|----------|
| AA-E1 | systemMessage injection (arbitrary instructions if hook modified) | 2 | 5 | **10** | P2 |
| AA-S3 | jq binary replacement | 2 | 5 | **10** | P2 |
| AA-E2 | Prompt manipulation controls LLM behavior | 3 | 3 | **9** | P2 |
| AA-D1 | No timeout guard (hook can hang) | 3 | 3 | **9** | P2 |
| AA-S1 | Trigger systemMessage via keyword crafting | 3 | 2 | **6** | P3 |
| AA-T1 | Modify complexity rules | 2 | 3 | **6** | P3 |
| AA-T3 | Modify output JSON via complexity tampering | 2 | 3 | **6** | P3 |
| AA-S2 | Bypass complexity estimation | 2 | 2 | **4** | P4 |
| AA-D2 | Slow regex evaluation on large input | 2 | 2 | **4** | P4 |
| AA-T2 | jq injection via special characters | 1 | 3 | **3** | P4 |
| AA-D3 | head -c partial read (invalid JSON) | 1 | 2 | **2** | P5 |
| AA-R1 | No logging | 2 | 1 | **2** | P5 |
| AA-R2 | Stateless execution | 1 | 1 | **1** | P5 |
| AA-I1 | Prompt in process listing | 1 | 1 | **1** | P5 |
| AA-I3 | Timing side-channel | 1 | 1 | **1** | P5 |
| AA-E3 | Bash word splitting (future modification risk) | 1 | 2 | **2** | P5 |

### 8.4 Combined Risk Heat Map

```
Impact
  5 |  SS-I1(25)          |  SS-T2(16)  SS-E3(15)  |  AA-E1(10) AA-S3(10)
  4 |                      |  SS-T1(8)  SS-I4(9)    |  SS-S2(10)
  3 |  AA-E2(9) AA-D1(9)  |  SS-D1(6) SS-S1(6)     |  SS-T4(3)
    |                      |  SS-S3(6) SS-T3(6)     |
    |                      |  SS-R1(6)               |
  2 |  SS-R2(4) SS-I2(4)  |  AA-S1(6) AA-T1(6)     |  AA-D3(2) AA-E3(2)
    |  AA-S2(4) AA-D2(4)  |  AA-T3(6)              |
  1 |  SS-D4(1) AA-R2(1)  |  AA-R1(2) AA-I1(1)     |
    |  AA-I3(1)            |                         |
    +---------------------------------------------------------
       1        2         3         4         5       Likelihood
```

---

## 9. Mitigations Summary

### 9.1 sanitize-secrets.js -- Current Mitigations

| Threat | Mitigation (Current) | Effectiveness |
|--------|---------------------|---------------|
| Large input | 1MB size cap (`MAX_INPUT_SIZE`) | Good |
| Processing hang | 5-second timeout with stdin destroy | Good |
| File permission leaks | `umask 077` on process start | Good |
| Log file growth | Rotation at 5MB | Adequate |
| JSON parse failure | Fallback to text sanitization | Good |
| Crash | Top-level `.catch()` returns `continue: true` | Good (availability) |

### 9.2 sanitize-secrets.js -- Recommended Additional Mitigations

| Threat | Recommended Mitigation | Priority |
|--------|----------------------|----------|
| **SS-I1**: Secrets not actually redacted | (1) Rename hook to `audit-secrets.js` to accurately reflect audit-only purpose. (2) Add prominent comment: "DETECTION ONLY -- does NOT redact output." (3) Consider migrating to a PreToolUse hook for blocking. | P0 |
| **SS-T2**: Fail-open behavior | Add option to return `{"continue": false}` when high-confidence secrets are detected (e.g., GitHub PAT, AWS keys). Requires careful tuning to avoid blocking legitimate work. | P1 |
| **SS-E3**: No executable integrity | Compute SHA-256 of hook file at registration time and verify before each execution. Store hash in `settings.json`. | P1 |
| **SS-T1**: Regex modification | Sign the hook file with GPG or compute integrity hash. Verify at runtime. | P2 |
| **SS-I4**: False negatives | Add detection for: (1) unlabeled base64 strings >40 chars, (2) secrets split across JSON fields, (3) URL-encoded secrets, (4) hex-encoded keys without `0x` prefix. | P2 |
| **SS-D1**: ReDoS | Convert greedy patterns to possessive or atomic groups where possible. Add per-pattern timeout tracking. | P3 |
| **SS-R1**: No false-negative logging | Log the fact that scanning was performed (with zero count) so there is a record that the hook ran. | P3 |
| **SS-R2**: Log rotation destroys evidence | Archive rotated logs instead of deleting them. Use timestamped filenames. | P4 |

### 9.3 aristotle-analysis-display.sh -- Current Mitigations

| Threat | Mitigation (Current) | Effectiveness |
|--------|---------------------|---------------|
| Large input | `head -c 100000` truncation | Adequate |
| Empty prompt | Early exit with default output | Good |
| JSON safety | `jq -n --arg` for output construction | Good |
| File permission | `umask 077` | Good |
| jq parse failure | `2>/dev/null` on jq, defaults to empty string | Good |

### 9.4 aristotle-analysis-display.sh -- Recommended Additional Mitigations

| Threat | Recommended Mitigation | Priority |
|--------|----------------------|----------|
| **AA-E1**: systemMessage injection vector | Consider restricting systemMessage content to a predefined allowlist of messages, rather than free-form string construction. Add integrity check on the hook file. | P2 |
| **AA-S3**: jq binary replacement | Use full path to jq (`/opt/homebrew/bin/jq` or `/usr/local/bin/jq`) instead of relying on PATH resolution. | P2 |
| **AA-D1**: No timeout guard | Add a timeout mechanism similar to sanitize-secrets.js (e.g., `timeout 5s` wrapper or bash `SECONDS` check). | P2 |
| **AA-E2**: Prompt manipulation | Add randomness or weighted scoring to make the complexity estimation less predictable and harder to game. | P3 |
| **AA-T1**: Complexity rule modification | Add file integrity verification (SHA-256 hash). | P3 |
| **AA-R1**: No logging | Log complexity scores and systemMessage injections to `~/.ralph/logs/` for audit trail. | P5 |

### 9.5 System-Level Mitigations (Both Hooks)

| Mitigation | Description | Applicability |
|------------|-------------|---------------|
| **File permissions** | Hooks should be owned by root or immutable (`chflags uchg`). Currently owned by `alfredolopez:staff` with `755`. | Both |
| **Integrity verification** | Claude Code should verify hook file hashes before execution. Currently no verification. | Both |
| **Principle of least privilege** | Hooks should run with minimal environment (no network, restricted filesystem). Currently they inherit the full user environment. | Both |
| **Audit trail** | All hook executions should be logged with PID, timestamp, exit code. Currently only sanitize-secrets logs on detection. | Both |
| **Sandboxing** | Consider running hooks in a sandbox (e.g., macOS Seatbelt profile) that restricts filesystem and network access. | Both |

---

## 10. Residual Risks

### 10.1 Accepted Risks

| Risk | Rationale | Monitoring |
|------|-----------|------------|
| sanitize-secrets.js is audit-only, not blocking | PostToolUse hook type cannot modify output. Architectural limitation of Claude Code. Changing to PreToolUse would require significant rework. | Review quarterly. Consider PreToolUse migration when Claude Code adds output modification support. |
| No hook integrity verification | Claude Code does not currently support hash-based hook verification. | Track Claude Code releases for integrity features. |
| Pattern-based detection has inherent false negatives | Regex cannot detect all secret formats. Encoding, obfuscation, and novel formats will always evade detection. | Update patterns monthly. Consider entropy-based detection as supplement. |
| aristotle hook is stateless | No history of systemMessage injections. Design choice for simplicity. | Accept. Low-severity risk. |

### 10.2 Risks Requiring Action

| Risk | Action | Owner | Timeline |
|------|--------|-------|----------|
| sanitize-secrets naming implies redaction | Rename to accurately reflect audit-only purpose | Developer | Next release |
| aristotle hook has no timeout | Add timeout guard | Developer | Next release |
| Both hooks lack integrity checks | Add SHA-256 verification script | Developer | v3.1 |

---

## Appendix A: CWE Reference

| CWE | Name | Relevant Threats |
|-----|------|-----------------|
| CWE-20 | Improper Input Validation | AA-S2, AA-E2 |
| CWE-78 | OS Command Injection | AA-T2, AA-E3 |
| CWE-94 | Code Injection | AA-S1, AA-E1 |
| CWE-1321 | Prototype Pollution | SS-E1 |
| CWE-1333 | Inefficient Regular Expression Complexity | SS-D1 |
| CWE-200 | Exposure of Sensitive Information | SS-I1, SS-I2, SS-I4, AA-I1 |
| CWE-208 | Observable Timing Discrepancy | AA-I3 |
| CWE-209 | Generation of Error Message with Sensitive Information | SS-I3 |
| CWE-276 | Incorrect Default Permissions | SS-T3, SS-R3 |
| CWE-346 | Origin Validation Error | SS-S1 |
| CWE-400 | Uncontrolled Resource Consumption | SS-T4, SS-D2, SS-D3, SS-D4, AA-D1, AA-D2 |
| CWE-426 | Untrusted Search Path | SS-S3, AA-S3, SS-E2 |
| CWE-733 | Compiler Optimization Removal or Modification of Security-critical Code | SS-S2, SS-T1, AA-T1, AA-T3, SS-E3 |
| CWE-778 | Insufficient Logging | SS-T2, SS-R1, AA-R1 |
| CWE-780 | Use of RSA Algorithm without OAEP | SS-R2 |

---

## Appendix B: Verification Checklist

- [x] sanitize-secrets.js source code reviewed (323 lines)
- [x] aristotle-analysis-display.sh source code reviewed (90 lines)
- [x] File permissions verified (755, owner: alfredolopez)
- [x] umask 077 confirmed in both hooks
- [x] JSON output format verified against hook specification
- [x] Timeout guard verified (sanitize-secrets: 5s, aristotle: none)
- [x] Size limits verified (sanitize-secrets: 1MB, aristotle: 100KB)
- [x] Log file rotation verified (sanitize-secrets: 5MB)
- [x] Fail-open behavior verified (both hooks)
- [x] jq usage verified (safe pattern: `jq -n --arg`)
- [x] Environment variable handling verified
- [x] Regex pattern review for ReDoS potential
- [x] Cross-referenced with SECURITY_MODEL_v2.89.md
