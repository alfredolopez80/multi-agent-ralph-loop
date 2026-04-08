# Security Context-Depth Analysis

**Date**: 2026-04-08
**Methodology**: 5-Depth Context-Depth Analysis (Surface, Logic, Context, Supply Chain, Temporal)
**Auditor**: ralph-adversarial
**Scope**: Two Claude Code hooks

| File | Event Type | Lines | Purpose |
|------|------------|-------|---------|
| `.claude/hooks/sanitize-secrets.js` | PostToolUse | 323 | Detect and log secrets in tool outputs |
| `.claude/hooks/aristotle-analysis-display.sh` | UserPromptSubmit | 90 | Estimate prompt complexity and inject Aristotle reminder |

---

## Executive Summary

| Depth | sanitize-secrets.js | aristotle-analysis-display.sh | Total Findings |
|-------|---------------------|-------------------------------|----------------|
| D1 - Surface | 2 findings | 1 finding | 3 |
| D2 - Logic | 3 findings | 2 findings | 5 |
| D3 - Context | 3 findings | 2 findings | 5 |
| D4 - Supply Chain | 2 findings | 2 findings | 4 |
| D5 - Temporal | 2 findings | 2 findings | 4 |
| **Total** | **12** | **9** | **21** |

| Severity | Count | Files |
|----------|-------|-------|
| CRITICAL | 0 | -- |
| HIGH | 2 | sanitize-secrets.js (2) |
| MEDIUM | 4 | Both (2 each) |
| LOW | 7 | Both |
| PASS | 8 | Both |

**Overall Verdict**: PASS with recommendations. No CRITICAL findings. Two HIGH findings in sanitize-secrets.js are architectural limitations (not exploitable bugs) documented in the codebase's own threat model.

---

## DEPTH 1 -- Surface: Obvious Vulnerabilities, Misconfigurations

### sanitize-secrets.js

#### D1-SS-01 | PASS | File Permissions
- **CWE**: --
- **Check**: File permissions `rwxr-xr-x`, ownership `alfredolopez:staff`.
- **Assessment**: Executable bit is set (necessary for `#!/usr/bin/env node` shebang). No group/other write. Acceptable.

#### D1-SS-02 | PASS | umask 077 Defense
- **CWE**: CWE-732 (Incorrect Permission Assignment for Critical Resource)
- **Code**: `process.umask(0o077)` at line 25.
- **Assessment**: Restricts any files created during execution to owner-only. Aligned with established pattern from `rooms/hooks.md`.

#### D1-SS-03 | PASS | No Hardcoded Secrets
- **CWE**: CWE-798 (Use of Hard-coded Credentials)
- **Assessment**: No secrets, tokens, API keys, or credentials in source code. Pattern definitions are regex, not actual values.

#### D1-SS-04 | LOW | Log Path Derivation Uses $HOME Fallback
- **CWE**: CWE-362 (Concurrent Execution with Improper Synchronization)
- **Code**: Line 302: `const logDir = '${process.env.XDG_RUNTIME_DIR || process.env.HOME}/.ralph/logs'`
- **Assessment**: On macOS, `XDG_RUNTIME_DIR` is typically unset, so `$HOME` is used. The path is predictable (`~/.ralph/logs/sanitize-secrets.log`). Any local process can predict and potentially pre-create this path with wider permissions (TOCTOU between `mkdirSync` and `appendFileSync`). Mitigated by `recursive: true, mode: 0o700` and umask 077. Risk is theoretical on single-user macOS.
- **Recommendation**: None required. Acceptable for current deployment.

### aristotle-analysis-display.sh

#### D1-AA-01 | PASS | umask 077
- **CWE**: CWE-732
- **Code**: Line 2: `umask 077`
- **Assessment**: Correctly set before any file or process operations.

#### D1-AA-02 | PASS | No eval/exec/rm/curl/wget
- **CWE**: CWE-78 (OS Command Injection)
- **Assessment**: Script uses only `jq`, bash builtins (`[[`, `((`, `${,,}`), and `echo`. No external command execution vectors.

#### D1-AA-03 | LOW | Input Read via head -c Without Pipe Closure
- **CWE**: CWE-400 (Uncontrolled Resource Consumption)
- **Code**: Line 5: `INPUT=$(head -c 100000)`
- **Assessment**: 100KB limit is reasonable. However, `head -c` will block until stdin closes or 100KB is read. If Claude Code does not close stdin promptly, the hook process blocks. In practice, Claude Code's hook runner provides input and closes stdin. Not a vulnerability in normal operation.

---

## DEPTH 2 -- Logic: Business Logic Flaws, Race Conditions, State Issues

### sanitize-secrets.js

#### D2-SS-01 | HIGH | Detection Without Redaction (Architectural Limitation)
- **CWE**: CWE-312 (Cleartext Storage of Sensitive Information), CWE-532 (Insertion of Sensitive Information into Log File)
- **Code**: Lines 7-9 (architecture note), line 286 (`sanitizeObject(data)` result is discarded), line 298 (`{ continue: true }`).
- **Analysis**: The hook explicitly documents that PostToolUse hooks **cannot modify tool output**. The `sanitizeObject()` function produces a sanitized copy of the data, but this copy is **never emitted**. The hook outputs only `{"continue": true}`. The original tool output with any secrets passes through to Claude unchanged.
- **Impact**: The hook provides **audit logging only** (counts and types via stderr). It does **not** prevent secrets from reaching Claude's context window. The threat model at `multi-agent-ralph-loop-threat-model.md:111` documents this: "keys can be read in-flight before sanitization."
- **Severity Justification**: HIGH because the hook name (`sanitize-secrets`) implies active sanitization, but the actual behavior is detection-only. Misplaced trust in this hook could lead to complacency.
- **Recommendation**: Rename to `detect-secrets.js` or `audit-secrets.js` to accurately reflect behavior. Document the limitation prominently in the hook's help text and README.

#### D2-SS-02 | MEDIUM | Regex Pattern Ordering Can Misclassify
- **CWE**: CWE-185 (Incorrect Regular Expression)
- **Code**: Lines 42-52 (BUG-008 fix note: "Most specific patterns FIRST")
- **Analysis**: The BUG-008 fix correctly orders `sk-proj-` before generic `sk-`. However, the `Twilio API Key` pattern (`SK[a-f0-9]{32}`) at line 148 could match substrings of other tokens that happen to start with "SK" and contain hex characters. The Stripe `sk_live_*` pattern (line 136) is ordered before Twilio, but a hypothetical token starting with `SK` followed by 32 hex chars but NOT matching Stripe's format would be misclassified as "Twilio" rather than its actual type.
- **Impact**: Misclassification affects only the audit log label (`stats.byType`), not detection. Secrets are still detected regardless of label accuracy.
- **Severity Justification**: MEDIUM because the label is cosmetic, not functional.

#### D2-SS-03 | LOW | Sanitized Object Garbage-Collected Without Use
- **CWE**: CWE-312 (related to D2-SS-01)
- **Code**: Line 286: `sanitizeObject(data)` -- return value unused.
- **Analysis**: The function iterates the entire data tree and counts matches as a side effect (via the `stats` global). The sanitized result is thrown away. This is by design given the PostToolUse limitation, but it means CPU cycles are spent constructing strings that are immediately discarded.
- **Recommendation**: Consider a two-pass approach: first pass counts matches without building replacements, second pass (only if needed) builds replacements. Or, since replacements are never used, use `match()` instead of `replace()` for pure counting.

### aristotle-analysis-display.sh

#### D2-AA-01 | MEDIUM | Complexity Score Can Be Gamed by Prompt Engineering
- **CWE**: CWE-20 (Improper Input Validation)
- **Code**: Lines 20-63 (`estimate_complexity()` function).
- **Analysis**: The complexity estimator uses keyword matching against the user's prompt text. A user or adversarial prompt can:
  - Inflate complexity by including words like "refactor", "architecture", "team", "parallel" without actual complex intent
  - Deflate complexity by prepending "quick" or "just" to complex requests
  - Achieve a complexity of 1 (no Aristotle reminder) by avoiding trigger words while issuing complex instructions (e.g., "modify the authentication middleware to add rate limiting and audit logging" scores complexity 1-2 because it contains no high-complexity keywords)
- **Impact**: The systemMessage injection is informational (reminding the agent about Aristotle methodology). Gaming it merely suppresses or triggers a reminder -- it does not bypass any security control. The `continue: true` output always allows the prompt through regardless.
- **Severity Justification**: MEDIUM because complexity estimation is the hook's core purpose and it has systematic blind spots. LOW operational impact since the hook is advisory only.

#### D2-AA-02 | LOW | Overlapping Patterns Cause Double-Counting
- **CWE**: CWE-185
- **Code**: Lines 33-34: `"implement.*system"` (+3) and line 42: `"implement"` (+2, conditionally).
- **Analysis**: The conditional on line 42 (`[[ ! "$lower_prompt" =~ implement.*system ]]`) prevents double-counting when both patterns match. This is a correct fix. However, "create.*system" (+3, line 34) and "design.*system" (+2, line 38) can both match "create a design system" giving +5 instead of the intended +3 or +2.
- **Impact**: Complexity score of 6 instead of 3-4 for edge cases. Still within the 1-10 range and still triggers the Aristotle reminder.
- **Recommendation**: Consider using elif chains or a priority system to prevent additive overlap.

---

## DEPTH 3 -- Context: Hook System Interaction, Data Flows

### sanitize-secrets.js

#### D3-SS-01 | HIGH | Secrets Visible in Claude's Context Window Before Hook Fires
- **CWE**: CWE-200 (Exposure of Sensitive Information to an Unauthorized Actor)
- **Analysis**: Claude Code's hook execution model:
  1. Tool executes (e.g., `Read .env`)
  2. Tool output returned to Claude's context
  3. PostToolUse hooks fire after tool output is available
  4. Hook receives the tool output JSON on stdin
  5. Hook outputs `{"continue": true}` or `{"continue": false}`

  The hook fires **after** the tool output has been generated. By the time `sanitize-secrets.js` scans the output, Claude has already seen the raw tool result. Even if the hook could modify output (which it cannot per PostToolUse API), the secret has already been ingested.
- **Impact**: This is a fundamental limitation of the PostToolUse hook timing, not a bug in the code. The hook provides defense-in-depth audit logging but cannot prevent secret exposure to the LLM.
- **Recommendation**: For actual secret blocking, use a PreToolUse hook that prevents reading files matching secret patterns (e.g., `.env`, `*.pem`, `credentials.json`). The existing `git-safety-guard.py` and `repo-boundary-guard.sh` hooks operate at the PreToolUse stage and could be extended.

#### D3-SS-02 | MEDIUM | stderr Output May Leak Secret Type Information
- **CWE**: CWE-200
- **Code**: Lines 290-293:
  ```javascript
  console.error(`[sanitize-secrets] Redacted ${stats.totalRedactions} secret(s):`);
  for (const [type, count] of Object.entries(stats.byType)) {
    console.error(`  - ${type}: ${count}`);
  }
  ```
- **Analysis**: The hook emits secret type counts to stderr (e.g., "GitHub PAT: 1, OpenAI Key: 2"). Claude Code captures stderr and may display it in the transcript. This reveals:
  - That secrets were present in the tool output
  - The specific types of secrets detected
  - The count of each type
- **Impact**: An attacker who can observe the transcript (or a compromised Claude context) learns which secret types exist in the project. For example, knowing "AWS Access Key: 1" tells an attacker to search for `AKIA` patterns in the codebase.
- **Recommendation**: Consider logging only the total count, not per-type breakdowns, to stderr. Full per-type details can go to the file log at `~/.ralph/logs/sanitize-secrets.log` which is protected by umask 077.

#### D3-SS-03 | PASS | Correct PostToolUse JSON Format
- **CWE**: CWE-20
- **Code**: All output paths emit `{"continue": true}` (lines 278, 298, 314, 322).
- **Analysis**: Verified against `tests/HOOK_FORMAT_REFERENCE.md`. PostToolUse hooks must use `{"continue": true/false}`. No `decision` field is emitted anywhere. The hook correctly never uses `process.exit(1)`.

### aristotle-analysis-display.sh

#### D3-AA-01 | PASS | systemMessage is Hook-Controlled, Not User-Injectable
- **CWE**: CWE-79 (Cross-site Scripting), CWE-94 (Code Injection)
- **Code**: Lines 71-85: `SYSTEM_MESSAGE` is constructed from hardcoded strings plus the numeric complexity value. The user's prompt text is never included in the systemMessage.
- **Analysis**: The `jq -n --arg msg "$SYSTEM_MESSAGE"` construction safely encodes the message. Even if `$COMPLEXITY` were manipulated (it is derived from a `echo` of an integer), it would only appear as part of the complexity label string. No injection vector exists.
- **Assessment**: PASS. The systemMessage is entirely controlled by the hook's own logic.

#### D3-AA-02 | MEDIUM | Prompt Text Flows Through jq via stdin (Safe but Worth Noting)
- **CWE**: CWE-78
- **Code**: Line 8: `PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null)`
- **Analysis**: The user's raw prompt text is extracted via `jq -r`. If the prompt contains JSON-special characters, `jq -r` handles them correctly (it is a proper JSON parser). The prompt is then used only in bash regex matching (`=~`), never in command substitution or eval. The final output uses `jq -n --arg msg` for safe re-encoding.
- **Assessment**: The data flow is safe. However, the prompt text is stored in the `PROMPT` variable which persists for the lifetime of the hook process. If the process were to core dump (extremely unlikely for a bash script), the prompt could be visible in core. This is theoretical.

---

## DEPTH 4 -- Supply Chain: Dependencies, Environment Assumptions

### sanitize-secrets.js

#### D4-SS-01 | LOW | Node.js fs Module Available (No Sandboxing)
- **CWE**: CWE-829 (Inclusion of Functionality from Untrusted Control Sphere)
- **Code**: Line 22: `const fs = require('fs');`
- **Analysis**: The hook has access to the full Node.js `fs` module. In the error handler (lines 302-308), it:
  1. Constructs a directory path from environment variables
  2. Creates the directory with `mkdirSync`
  3. Writes to a log file with `appendFileSync`

  A compromised Node.js runtime or a prototype pollution attack on the environment variables could redirect log writes. The `XDG_RUNTIME_DIR` or `HOME` environment variables are trusted inputs.
- **Assessment**: LOW because the hook does not use `child_process`, `net`, `http`, or `https`. The attack surface is limited to filesystem operations within a predictable path.

#### D4-SS-02 | LOW | No Integrity Check on Input
- **CWE**: CWE-345 (Insufficient Verification of Data Authenticity)
- **Code**: Line 283: `const data = JSON.parse(input);`
- **Analysis**: The hook trusts that stdin contains well-formed JSON from Claude Code's hook runner. There is no verification that the input actually came from Claude Code vs. a process that somehow injected data into stdin. In practice, Claude Code's process model ensures stdin is connected to the hook runner, not an arbitrary source.
- **Assessment**: LOW. The process model provides implicit authenticity.

### aristotle-analysis-display.sh

#### D4-AA-01 | PASS | jq Dependency is Minimal and Well-Scoped
- **Version**: jq-1.8.1 (installed)
- **Usage**: `jq -r` for extraction (line 8), `jq -n --arg` for construction (lines 80, 85).
- **Assessment**: jq is used only for JSON parsing and safe encoding. No `-f` (file input), no `--rawfile`, no module loading. The jq usage is minimal and follows security best practices.

#### D4-AA-02 | LOW | Bash Version Dependency (4+)
- **CWE**: CWE-1104 (Use of Unmaintained Third Party Components)
- **Code**: Line 26: `lower_prompt="${prompt,,}"` (Bash 4+ feature)
- **Analysis**: The script requires Bash 4+ for the `${var,,}` lowercase syntax. On macOS, the default shell is now zsh, but `/usr/bin/env bash` resolves to GNU bash 5.2.37 (verified). If this hook were run on a system with Bash 3.x (older macOS), the `${var,,}` syntax would fail silently (treated as literal text with trailing commas), producing incorrect complexity estimates.
- **Assessment**: LOW. All target environments have Bash 5.x. The shebang `#!/usr/bin/env bash` correctly invokes the system bash.

---

## DEPTH 5 -- Temporal: Time-Based Attacks, Versioning, Deprecation Risks

### sanitize-secrets.js

#### D5-SS-01 | MEDIUM | Secret Pattern Catalog Will Lag Behind New Providers
- **CWE**: CWE-327 (Use of a Broken or Risky Cryptographic Algorithm) -- conceptual
- **Analysis**: The 20+ patterns are hardcoded for specific providers (GitHub, OpenAI, AWS, Anthropic, Stripe, Slack, Discord, SendGrid, Twilio, Infura, Alchemy). New providers and new key formats are introduced regularly:
  - Google Gemini keys (`AIza...`)
  - Cohere keys
  - Mistral keys
  - Groq keys
  - Together AI keys
  - Replicate tokens
  - Hugging Face tokens (`hf_...`)

  The hook has no mechanism for pattern updates without code changes. A new provider's key format would be invisible to the hook until manually added.
- **Impact**: The `Generic API Key` pattern (line 94) provides a catch-all for `api_key=VALUE` and `api_token=VALUE` patterns, which catches most new providers. However, keys passed as bare values or in non-standard parameter names would be missed.
- **Recommendation**: Consider extracting patterns into a separate JSON/YAML configuration file that can be updated independently of the hook code. This would also enable pattern updates via the auto-learning pipeline.

#### D5-SS-02 | LOW | Log Rotation is Size-Based Only
- **CWE**: CWE-400
- **Code**: Line 306: `const st = fs.statSync(logPath); if (st.size > 5 * 1024 * 1024) fs.unlinkSync(logPath);`
- **Analysis**: Log rotation deletes the entire log when it exceeds 5MB. This means:
  - No retention guarantee (logs can be lost)
  - No backup before deletion
  - A burst of errors could fill and rotate the log multiple times in quick succession, losing all history
  - The rotation check and write are not atomic (TOCTOU between `statSync` check and `appendFileSync` write)
- **Assessment**: LOW. The log is for anomaly detection, not forensics. Loss of log history is acceptable for the current use case.

### aristotle-analysis-display.sh

#### D5-AA-01 | LOW | Complexity Scoring Model Has No Calibration Mechanism
- **CWE**: CWE-345
- **Analysis**: The complexity weights (e.g., "refactor" = +4, "architecture" = +3, "team" = +2) are hardcoded constants with no calibration against actual task complexity. As the agent system evolves and new task types emerge, these weights may become inaccurate. There is no feedback loop to adjust weights based on actual task difficulty vs. estimated difficulty.
- **Impact**: Inaccurate complexity estimates lead to either unnecessary Aristotle reminders (noise) or missing reminders when they would be helpful. No security impact.
- **Recommendation**: Consider logging complexity estimates and actual task outcomes for future calibration.

#### D5-AA-02 | PASS | No Temporal State or Caching
- **Analysis**: The script is stateless -- each invocation reads fresh input, computes complexity, and outputs JSON. There is no caching, no state file, no session persistence. This means:
  - No temporal attack surface
  - No session fixation risk
  - No state corruption risk
  - Clean behavior across Claude Code sessions and restarts

---

## Findings Summary

### By Severity

| ID | File | Depth | Severity | CWE | Title |
|----|------|-------|----------|-----|-------|
| D2-SS-01 | sanitize-secrets.js | Logic | **HIGH** | CWE-312 | Detection-only (no actual redaction) despite name implying sanitization |
| D3-SS-01 | sanitize-secrets.js | Context | **HIGH** | CWE-200 | Secrets visible to Claude before hook fires (PostToolUse timing) |
| D2-SS-02 | sanitize-secrets.js | Logic | MEDIUM | CWE-185 | Pattern ordering can misclassify secret types in audit log |
| D2-AA-01 | aristotle-analysis-display.sh | Logic | MEDIUM | CWE-20 | Complexity scoring gameable by prompt keyword manipulation |
| D3-SS-02 | sanitize-secrets.js | Context | MEDIUM | CWE-200 | stderr reveals secret type counts to transcript |
| D3-AA-02 | aristotle-analysis-display.sh | Context | MEDIUM | CWE-78 | Prompt text in variable (safe flow but worth noting) |
| D1-SS-04 | sanitize-secrets.js | Surface | LOW | CWE-362 | Log path predictable via $HOME fallback |
| D1-AA-03 | aristotle-analysis-display.sh | Surface | LOW | CWE-400 | head -c blocks until stdin closes |
| D2-SS-03 | sanitize-secrets.js | Logic | LOW | CWE-312 | Sanitized result garbage-collected (CPU waste) |
| D2-AA-02 | aristotle-analysis-display.sh | Logic | LOW | CWE-185 | Overlapping patterns can double-count in edge cases |
| D4-SS-01 | sanitize-secrets.js | Supply | LOW | CWE-829 | fs module access (no sandboxing) |
| D4-SS-02 | sanitize-secrets.js | Supply | LOW | CWE-345 | No integrity check on stdin input |
| D4-AA-02 | aristotle-analysis-display.sh | Supply | LOW | CWE-1104 | Bash 4+ dependency |
| D5-SS-02 | sanitize-secrets.js | Temporal | LOW | CWE-400 | Log rotation is size-based only (no retention) |
| D5-AA-01 | aristotle-analysis-display.sh | Temporal | LOW | CWE-345 | Complexity weights hardcoded without calibration |
| D5-SS-01 | sanitize-secrets.js | Temporal | MEDIUM | CWE-327 | Pattern catalog lags behind new key providers |
| D1-SS-01 | sanitize-secrets.js | Surface | PASS | -- | File permissions correct |
| D1-SS-02 | sanitize-secrets.js | Surface | PASS | CWE-732 | umask 077 properly set |
| D1-SS-03 | sanitize-secrets.js | Surface | PASS | CWE-798 | No hardcoded secrets |
| D3-SS-03 | sanitize-secrets.js | Context | PASS | CWE-20 | Correct PostToolUse JSON format |
| D3-AA-01 | aristotle-analysis-display.sh | Context | PASS | CWE-79 | systemMessage not user-injectable |
| D4-AA-01 | aristotle-analysis-display.sh | Supply | PASS | -- | jq usage minimal and safe |
| D5-AA-02 | aristotle-analysis-display.sh | Temporal | PASS | -- | Stateless (no temporal attack surface) |
| D1-AA-01 | aristotle-analysis-display.sh | Surface | PASS | CWE-732 | umask 077 correctly set |
| D1-AA-02 | aristotle-analysis-display.sh | Surface | PASS | CWE-78 | No dangerous commands |

### By CWE Frequency

| CWE | Count | Severity Range |
|-----|-------|---------------|
| CWE-312 (Cleartext Storage) | 2 | HIGH, LOW |
| CWE-200 (Information Exposure) | 2 | HIGH, MEDIUM |
| CWE-20 (Improper Input Validation) | 2 | MEDIUM, PASS |
| CWE-185 (Incorrect Regex) | 2 | MEDIUM, LOW |
| CWE-400 (Resource Consumption) | 2 | LOW |
| CWE-732 (Permission Assignment) | 2 | PASS |
| CWE-78 (Command Injection) | 2 | PASS, MEDIUM |
| CWE-345 (Data Authenticity) | 2 | LOW |
| CWE-362 (Race Condition) | 1 | LOW |
| CWE-798 (Hardcoded Credentials) | 1 | PASS |
| CWE-79 (XSS/Injection) | 1 | PASS |
| CWE-829 (Untrusted Functionality) | 1 | LOW |
| CWE-94 (Code Injection) | 1 | PASS |
| CWE-1104 (Unmaintained Component) | 1 | LOW |
| CWE-327 (Broken Crypto/Algorithm) | 1 | MEDIUM |

---

## Recommendations Summary

### Priority 1 (Should Do)

| ID | Action | Effort |
|----|--------|--------|
| D2-SS-01 | Rename `sanitize-secrets.js` to `detect-secrets.js` or `audit-secrets.js` to match actual behavior | 15 min |
| D3-SS-02 | Remove per-type breakdowns from stderr; log details only to file | 10 min |

### Priority 2 (Nice to Have)

| ID | Action | Effort |
|----|--------|--------|
| D5-SS-01 | Extract secret patterns to external JSON config for independent updates | 1 hour |
| D2-SS-03 | Use `match()` for counting instead of `replace()` (avoid building discarded strings) | 30 min |
| D2-AA-01 | Add keyword-neutral heuristic (e.g., prompt length > 500 chars = at least complexity 3) | 30 min |

### Priority 3 (Low Priority / Accept Risk)

| ID | Action | Effort |
|----|--------|--------|
| D1-SS-04 | Accept $HOME fallback (theoretical TOCTOU on single-user macOS) | -- |
| D2-AA-02 | Accept overlap edge cases (impact is +1-2 complexity points) | -- |
| D5-SS-02 | Accept size-based rotation (log is advisory, not forensic) | -- |
| D5-AA-01 | Accept hardcoded weights (no security impact) | -- |
