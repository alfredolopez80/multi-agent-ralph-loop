# Vault System Implementation Plan -- Architecture Audit

**Auditor**: Claude Opus (senior architecture review)
**Date**: 2026-03-21
**Plan Version Audited**: v1.0.0-draft
**Status**: COMPLETE
**Verdict**: CONDITIONALLY APPROVED -- 7 BLOCKING issues, 11 IMPORTANT, 6 NICE-TO-HAVE

---

## Table of Contents

1. [Architecture Review](#1-architecture-review)
2. [Security Review](#2-security-review)
3. [Implementation Gaps](#3-implementation-gaps)
4. [Integration Risks](#4-integration-risks)
5. [Open Questions Assessment](#5-open-questions-assessment)
6. [Completeness Check](#6-completeness-check)
7. [Recommended Changes](#7-recommended-changes)

---

## 1. Architecture Review

### 1.1 Three-Layer Design Assessment

The three-layer architecture (global vault / ~/.claude/ / per-repo) is **sound in principle** and well-aligned with the research source (sections 3, 15 of `context-memory-mcp-jarvis.md`). However, several issues:

**GOOD:**
- Clear separation of concerns: cross-repo patterns (global) vs. project-specific (local) vs. session lifecycle (~/.claude/).
- The classification model (GREEN/YELLOW/RED) maps cleanly to the three layers.
- Read-heavy / write-controlled design matches the research source's recommendation ("the agent does NOT write to the vault" -- section 7 of research). The plan appropriately relaxes this to "write with user approval," which is a pragmatic adaptation.

**ISSUES:**

| ID | Severity | Issue |
|----|----------|-------|
| ARCH-01 | BLOCKING | **MCP filesystem path is too broad.** Section 3.3 and 4.3 configure the MCP server with `/Users/alfredolopez/Documents/GitHub` as a path. This grants MCP read/write access to ALL repos under `Documents/GitHub`, not just the current repo. The stated security note ("The MCP no tiene acceso fuera de estos dos paths") is misleading -- it has access to every sibling repo. Must restrict to the specific repo path or use a dynamic per-repo approach. |
| ARCH-02 | IMPORTANT | **Inconsistent Obsidian path references.** The plan uses both `~/Obsidian/MiVault/` (section 5.1, line 387) and `~/Documents/Obsidian/MiVault/` (section 2.1, line 78). The correct path per section 3.2 is `~/Documents/Obsidian/MiVault/`. All references must be consistent. |
| ARCH-03 | IMPORTANT | **Layer 2 (~/.claude/) is conflated with Layer 3 (.claude/vault/).** The architecture diagram says Layer 2 is "skills de ciclo de sesion, hooks globales" but the hooks (session-learning-accumulator.sh, vault-classifier.sh) are created in `.claude/hooks/` (Layer 3, per-repo). The plan should clarify that hooks live in the repo but are registered globally in `~/.claude/settings.json`. |

### 1.2 Dependency Analysis

The dependency diagram (section 11, lines 1066-1073) has issues:

| ID | Severity | Issue |
|----|----------|-------|
| ARCH-04 | BLOCKING | **Phase 6 (Classification) should block Phase 4 (/exit-review), not the reverse.** The plan says Phase 4 is blocked by Phases 1 and 3, but Phase 4's SKILL.md explicitly references classification rules ("Apply classification rules -- see Knowledge Classification System"). Phase 6 implements `vault-classifier.sh` and `sanitize-for-global.sh` which Phase 4 depends on. Either: (a) move the classifier into Phase 4, or (b) reorder so Phase 6 comes before Phase 4. |
| ARCH-05 | NICE-TO-HAVE | **Phase 5 (PreCompact) dependency is incomplete.** It says "Bloqueado por: Phases 3, 4" but it also depends on the CLAUDE.md instruction from Phase 2 (the vault context awareness). Should note Phase 2 as soft dependency. |

### 1.3 MCP Configuration Assessment

| ID | Severity | Issue |
|----|----------|-------|
| ARCH-06 | BLOCKING | **Missing `-y` flag in section 3.3 but present in section 4.3.** Section 3.3 (line 179) omits the `-y` flag for npx, while section 4.3 (line 349) includes it. Without `-y`, npx will prompt interactively and hang Claude Code. The section 3.3 version must include `-y`. |
| ARCH-07 | IMPORTANT | **Duplicate MCP config sections create confusion.** Section 3.3 and section 4.3 both define the MCP config but differ slightly. Only one canonical definition should exist to avoid implementer confusion. |

---

## 2. Security Review

### 2.1 RED Detection Patterns Assessment

The RED patterns in `vault-classifier.sh` (section 9.1, lines 837-853) are **incomplete** compared to the existing `sanitize-secrets.js` which handles 20+ pattern types.

**Missing RED patterns (present in sanitize-secrets.js but absent from vault-classifier.sh):**

| Pattern | Risk |
|---------|------|
| JWT tokens (`eyJ...`) | Auth tokens leak |
| Database connection strings (`mongodb://user:pass@...`) | Full DB credentials |
| SSH private keys (`-----BEGIN...PRIVATE KEY-----`) | Infrastructure access |
| Slack tokens (`xox[baprs]-...`) | Workspace access |
| Discord tokens | Bot/user credentials |
| Stripe keys (`sk_live_...`, `pk_live_...`) | Payment credentials |
| Anthropic keys (`sk-ant-...`) | API credentials |
| Seed/mnemonic phrases | Crypto wallet access |
| Base64-encoded secrets | Obfuscated credentials |

| ID | Severity | Issue |
|----|----------|-------|
| SEC-01 | BLOCKING | **RED patterns are far weaker than existing sanitize-secrets.js.** The vault-classifier.sh has ~15 patterns; sanitize-secrets.js has 20+. The classifier must import or reference the same pattern set to avoid creating a weaker secondary gate. Recommendation: extract a shared pattern file or have the classifier call sanitize-secrets.js as a dependency. |
| SEC-02 | BLOCKING | **IP address regex matches version numbers.** The pattern `[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}` in vault-classifier.sh (line 848) will match version strings like `1.0.0.0`, Node.js versions, and similar. This will cause false REDs on legitimate technical content. Need anchoring or context-aware matching (e.g., require non-digit boundaries). |

### 2.2 Bypass Vectors

| ID | Severity | Issue |
|----|----------|-------|
| SEC-03 | IMPORTANT | **RED check order in accumulator is wrong.** In `session-learning-accumulator.sh` (lines 546-568), the error/installation detection runs BEFORE the RED check. If an error message contains both an error pattern AND a secret pattern, the LEARNING_TEXT variable is populated with error content (potentially containing the secret) before the RED check can discard it. If the RED check somehow fails (grep returns non-zero for non-match reasons), the secret-containing text would be written. Fix: move the RED check to execute FIRST, before any pattern detection. |
| SEC-04 | IMPORTANT | **Sanitizer can be bypassed with Unicode homoglyphs.** The `sanitize-for-global.sh` uses simple `sed` replacements. A string like "alfredol\u00F3pez" (with accented o) or repo names with zero-width characters would bypass sanitization. This is a low-probability but real vector. |
| SEC-05 | IMPORTANT | **`echo "$TEXT"` in sanitizer is unsafe with special characters.** In `sanitize-for-global.sh` (line 903), `echo "$TEXT"` can interpret escape sequences (e.g., `\n`, `\t`) depending on the shell. Use `printf '%s\n' "$TEXT"` instead. Same issue in `vault-classifier.sh` (lines 856, 903). |

### 2.3 Audit Log Security

| ID | Severity | Issue |
|----|----------|-------|
| SEC-06 | IMPORTANT | **Audit log hash implementation is unspecified.** Section 10.2 says "hash_of_content" with `sha256:abc123...` format but no code produces this hash. The accumulator hook (section 6.2) logs `RED_DISCARDED: Secret pattern detected` without a hash. The exit-review skill mentions no audit logging at all. The audit trail is conceptual, not implemented. |
| SEC-07 | NICE-TO-HAVE | **Audit log file permissions are not set.** `~/.ralph/logs/vault-audit.log` should be created with mode 0600 to prevent other users from reading discard records. |

### 2.4 Shell Injection Risks

| ID | Severity | Issue |
|----|----------|-------|
| SEC-08 | BLOCKING | **REPO_NAME and USERNAME are used unsanitized in sed patterns.** In `sanitize-for-global.sh` (lines 899-909), `$REPO_NAME` and `$USERNAME` are injected directly into `sed` replacement patterns. If the repo name or username contains sed metacharacters (`/`, `&`, `\`), the sed command will break or produce unexpected output. Example: a repo named `foo/bar` would corrupt the sed command. Use a sed-safe escaping function or use `awk` instead. |

---

## 3. Implementation Gaps

### 3.1 Underspecified Steps

| ID | Severity | Section | Gap |
|----|----------|---------|-----|
| GAP-01 | BLOCKING | Phase 4 (7.2) | **The /exit-review SKILL.md describes a dialog-driven process but provides no implementation.** Unlike Phase 3 (which has a complete bash script), Phase 4 only has a SKILL.md with natural language instructions. How does the skill read current.md, call the classifier, call the sanitizer, present the AskUserQuestion, and write to the vault? This needs either: (a) a companion shell script orchestrating the pieces, or (b) explicit instructions that Claude itself performs these steps using MCP tools. The SKILL.md as written is a specification, not an implementation. |
| GAP-02 | IMPORTANT | Phase 2 (5.2) | **The /context SKILL.md says "Load in parallel" but provides no mechanism.** Skills are markdown instructions, not executable code. Claude cannot literally parallelize MCP reads from a SKILL.md instruction. The plan should specify that Claude should issue multiple parallel MCP read_file calls (which it already can do). The "timing < 2s" acceptance criterion (line 475) is not measurable in a SKILL.md-based approach. |
| GAP-03 | IMPORTANT | Phase 6 (9.3) | **Category-to-file mapping is a flat table with no implementation.** The table at lines 914-922 maps keywords to destination files, but no code implements this routing. The /exit-review skill needs a routing mechanism (script or SKILL.md instructions) to determine which file a GREEN item should be appended to. |
| GAP-04 | IMPORTANT | Phase 4 (7.1) | **"Also read claude-mem (observaciones recientes)" is unspecified.** Step 2 says to read claude-mem observations but provides no MCP tool call, query parameters, or integration details. How does /exit-review access claude-mem? Via `mcp__plugin_claude-mem_mcp-search__get_observations`? What time range? What filters? |

### 3.2 Missing Error Handling

| ID | Severity | Issue |
|----|----------|-------|
| ERR-01 | IMPORTANT | **No error handling for MCP filesystem server being unavailable.** If the vault-filesystem MCP server is not running or crashes, the /context skill will fail silently. The SKILL.md should instruct Claude to gracefully degrade (report what could not be loaded). |
| ERR-02 | IMPORTANT | **No error handling for malformed current.md.** The accumulator appends to current.md, but if the file is corrupted (truncated write, encoding issues), the /exit-review skill will fail to parse it. Need a format validation step. |
| ERR-03 | NICE-TO-HAVE | **No error handling for vault global directory not existing.** If `~/Documents/Obsidian/MiVault/` is deleted or moved, all GREEN writes will fail. The /exit-review should check directory existence before attempting writes. |

### 3.3 Concurrency Issues

| ID | Severity | Issue |
|----|----------|-------|
| CONC-01 | IMPORTANT | **Concurrent sessions writing to current.md.** If Agent Teams spawns multiple teammates (ralph-coder, ralph-tester) working in the same repo, they will all trigger the PostToolUse accumulator hook and append to the same `current.md` concurrently. Without file locking, writes will interleave and corrupt the file. The accumulator should use `flock` or atomic append (which `>>` is on most POSIX systems for small writes, but not guaranteed for large ones). |
| CONC-02 | NICE-TO-HAVE | **Race condition on current.md during /exit-review.** If the accumulator hook fires while /exit-review is reading current.md, the review may miss or double-count items. The /exit-review should either rename/move current.md before processing or use flock. |

### 3.4 File Existence / Corruption / Locking

| ID | Severity | Issue |
|----|----------|-------|
| FILE-01 | IMPORTANT | **Accumulator creates current.md with hardcoded header but does not check for stale headers.** If a session crashes and a new session starts, the stale current.md from the previous session will be appended to, mixing items from different sessions. The /context skill detects this ("interrupted session"), but the accumulator should also log a warning when it finds a current.md with a different session ID. |

---

## 4. Integration Risks

### 4.1 pre-compact-handoff.sh Integration

| ID | Severity | Issue |
|----|----------|-------|
| INT-01 | IMPORTANT | **The plan says "agregar al final" of pre-compact-handoff.sh but the hook already outputs JSON at the end (line 242).** The vault notice code (section 8.2) must be inserted BEFORE the final `echo '{"continue": true}'` and `trap - ERR` lines. Inserting "at the end" would place code after the JSON output, which would never execute (the script exits after echo). The exact insertion point must be specified: before line 238 (`log "INFO" "PreCompact hook completed successfully"`). |
| INT-02 | IMPORTANT | **The plan says hooks cannot call AskUserQuestion.** This is correct. However, the plan's proposed solution (outputting `VAULT_COMPACT_NOTICE` to stdout, then adding a CLAUDE.md rule) relies on Claude reading hook stdout. In the current hook, stdout is reserved for JSON output (`{"continue": true}`). The notice would need to go into the JSON output as `additionalContext` or into stderr. The plan should specify the exact mechanism. For PreCompact hooks, stdout IS the JSON response. The notice should be embedded in the JSON: `{"continue": true, "hookSpecificOutput": {"additionalContext": "VAULT_COMPACT_NOTICE: N learnings pending"}}`. Note: verify whether PreCompact supports `hookSpecificOutput`; only PreToolUse, PostToolUse, and UserPromptSubmit are confirmed to support it. |

### 4.2 claude-mem MCP Integration

| ID | Severity | Issue |
|----|----------|-------|
| INT-03 | IMPORTANT | **The relationship between claude-mem and the vault system is described as "complementary" but the boundary is vague.** claude-mem stores observations (via `save_memory` and `get_observations`). The vault stores patterns. But the /exit-review reads both (section 7.1, step 2). What happens if the same learning exists in both systems? Who is the source of truth? The plan should define a clear boundary: claude-mem = ephemeral session observations, vault = curated persistent patterns. And /exit-review should deduplicate. |

### 4.3 Symlink Instructions

| ID | Severity | Issue |
|----|----------|-------|
| INT-04 | IMPORTANT | **Symlinks for /exit-review are mentioned in section 13 (line 1178) but the actual symlink creation script is missing.** Section 5.3 provides the symlink script for /context but no equivalent exists for /exit-review. The implementer must create symlinks for both skills across all 6 platforms. |

### 4.4 settings.json Conflicts

| ID | Severity | Issue |
|----|----------|-------|
| INT-05 | IMPORTANT | **The plan adds a new PostToolUse hook (session-learning-accumulator.sh) with matcher `Bash|Edit|Write`.** The existing settings.json already has PostToolUse hooks (sanitize-secrets.js, status-auto-check.sh, batch-progress-tracker.sh). The plan must specify whether the new hook should be added as a new entry in the PostToolUse array or merged with existing entries. Multiple PostToolUse hooks with different matchers are valid, but the execution order matters. The accumulator should run AFTER sanitize-secrets.js so that sanitized output is what gets classified. |
| INT-06 | NICE-TO-HAVE | **The plan references a `/update-config` skill (section 4.3, line 359) that does not exist.** No such skill is found in `.claude/skills/`. Either create it or remove the reference and provide manual instructions. |

---

## 5. Open Questions Assessment

### Question 1: Vault global en git?

**Recommendation: NO git repo; use iCloud/Dropbox sync.**

Rationale: The vault global is designed to be a personal knowledge base. Git adds friction (commit messages, merge conflicts on concurrent edits from multiple sessions). iCloud sync (which Obsidian supports natively) provides automatic backup without workflow overhead. If backup redundancy is needed, add a cron job that tars the vault to a backup location weekly.

### Question 2: Granularidad del accumulator?

**Recommendation: Keep conservative (errors + installations) for v1. Add a feature flag for expansion.**

Rationale: The current conservative approach (only errors and installations) avoids current.md spam. Add a feature flag `RALPH_VAULT_ACCUMULATOR_EXTENDED=false` in `~/.ralph/config/features.json`. When enabled, add detection for: (a) configuration changes, (b) permission fixes, (c) environment workarounds. Never auto-detect "patterns" -- that is too subjective for a shell script. Let /exit-review and Claude's judgment handle pattern extraction.

### Question 3: Formato de items en vault global?

**Recommendation: Markdown with YAML frontmatter.**

Rationale: Obsidian natively supports YAML frontmatter for properties (tags, dates, sources). This enables Obsidian's Dataview plugin for querying patterns. Format:

```yaml
---
tags: [pattern, python, venv]
source: multi-agent-ralph-loop
date: 2026-03-21
confidence: verified
---
```

### Question 4: Retencion de sesiones archivadas?

**Recommendation: 30-day retention with auto-cleanup.**

Rationale: Aligns with the existing episodic memory cleanup in `session-end-handoff.sh` (line 284-292) which already deletes episodes older than 30 days. Add a similar cleanup to the SessionEnd hook for `.claude/vault/sessions/`. This maintains consistency across the Ralph system.

### Question 5: Multi-repo vault sharing?

**Recommendation: Deduplication by content hash at write time.**

Rationale: Before appending a GREEN item to the vault global, compute its SHA-256 hash (after sanitization). Maintain a simple hash index file (`~/Documents/Obsidian/MiVault/.hashes`). If the hash already exists, skip the write and log a dedup event. This is simple, reliable, and does not require complex search.

### Question 6: claude-mem integration?

**Recommendation: Keep separate for v1. Add a bridge in v2.**

Rationale: claude-mem and the vault serve different purposes (ephemeral observations vs. curated patterns). Merging them increases complexity without clear benefit in v1. In v2, consider a `/consolidate` skill that reviews claude-mem observations weekly and promotes worthy ones to vault items.

### Question 7: Vault encryption?

**Recommendation: No encryption for v1. Use filesystem permissions.**

Rationale: YELLOW items are project-specific decisions (e.g., "we chose semver for this repo"). These are not secrets. If truly sensitive data is involved, it should be classified RED and discarded. Adding encryption introduces key management complexity that is not justified for architectural decision records. Use `chmod 700 .claude/vault/` for basic access control.

---

## 6. Completeness Check

### 6.1 Test Suite Assessment

The test suite is **insufficient** for a security-critical system.

**Missing test cases:**

| Category | Missing Test |
|----------|-------------|
| Classifier | Test with text containing BOTH GREEN and RED patterns (RED must win) |
| Classifier | Test with empty input |
| Classifier | Test with binary/non-UTF8 input |
| Classifier | Test with very long input (>1MB) |
| Classifier | Test with unicode homoglyphs of sensitive words |
| Sanitizer | Test with repo name containing sed metacharacters (`/`, `&`, `\`) |
| Sanitizer | Test with username containing special characters |
| Sanitizer | Test that sanitization preserves markdown formatting |
| Sanitizer | Test with input containing `[PATH]` or `[REPO]` literals (no double-sanitization) |
| Accumulator | Test concurrent writes from 2 processes |
| Accumulator | Test with missing .claude/vault/ directory |
| Accumulator | Test with read-only .claude/vault/current.md |
| Accumulator | Test hook timing (must complete in <100ms) |
| /exit-review | Test with empty current.md |
| /exit-review | Test with current.md containing only RED items |
| /exit-review | Test user responding with invalid input (e.g., "1,2,banana") |
| /exit-review | Test --quick flag approves GREEN and only asks for YELLOW |
| /exit-review | Test --skip flag clears without saving |
| Integration | Test full cycle: accumulate -> review -> write -> verify in vault |
| Integration | Test that GREEN items in vault do not contain any YELLOW/RED patterns |
| Privacy | Test with real-world tool output containing accidental secrets |
| Privacy | Test vault global after 10 sessions (cumulative leak check) |

### 6.2 Acceptance Criteria Assessment

Most acceptance criteria are measurable. Issues:

| Criterion | Issue |
|-----------|-------|
| "Carga en paralelo los archivos (verificar con timing < 2s total)" (line 475) | Not measurable -- skills are instructions, not timed executables |
| "Timing: hook completa en < 100ms" (line 624) | Measurable but no test implements this |
| "Sanitizado no cambia el significado tecnico del aprendizaje" (line 931) | Subjective -- not automatable. Rewrite as "sanitized output contains the same technical keywords as input minus project-specific terms" |

### 6.3 File Path Consistency

| Inconsistency | Locations |
|---------------|-----------|
| `~/Obsidian/MiVault/` vs `~/Documents/Obsidian/MiVault/` | Section 5.1 (line 387) vs Section 2.1 (line 78) |
| `.claude/vault/context/architecture.md` vs `.claude/vault/architecture.md` | Section 4.2 (line 296) uses `context/` subdirectory; Section 2.2 (line 104) uses `.claude/vault/context/architecture.md`; but Section 2.1 (line 93) lists it as just `architecture.md` without `context/` |
| `sanitize-for-global.sh` location is unspecified | Section 9.2 provides the script but no file path. Section 13 (line 1153) says `.claude/hooks/sanitize-for-global.sh` but it is not a hook -- it is a utility. Should be `.claude/scripts/` or `.claude/hooks/lib/`. |

---

## 7. Recommended Changes

### BLOCKING (must fix before implementation)

| ID | Change | Section |
|----|--------|---------|
| B-01 | **Restrict MCP path.** Change `/Users/alfredolopez/Documents/GitHub` to the specific repo path `/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop`. For multi-repo support, add each repo path individually or use a wrapper script. (ARCH-01) | 3.3, 4.3 |
| B-02 | **Reorder phases: Phase 6 must come before Phase 4.** The classifier and sanitizer are dependencies of /exit-review, not the other way around. New order: 1 -> 2, 1 -> 3, 1 -> 6, 3+6 -> 4, 4 -> 5, 6 -> 7. (ARCH-04) | 11 |
| B-03 | **Add `-y` flag to npx in section 3.3.** Without it, npx hangs waiting for user confirmation. (ARCH-06) | 3.3 |
| B-04 | **Align RED patterns with sanitize-secrets.js.** Add all patterns from the existing JS hook to vault-classifier.sh, or refactor to share a pattern definition file. At minimum add: JWT, DB connection strings, SSH keys, Slack/Discord/Stripe tokens, Anthropic keys, seed phrases. (SEC-01) | 9.1 |
| B-05 | **Fix IP address regex.** Add word boundaries: `\b[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\b` and exclude common version patterns. Or remove the IP pattern entirely since IP addresses in technical patterns are rare and the false positive rate is high. (SEC-02) | 9.1 |
| B-06 | **Move RED check before pattern detection in accumulator.** The RED discard block (lines 562-568) must be the FIRST check after tool filtering, before any LEARNING_TEXT is populated. (SEC-03) | 6.2 |
| B-07 | **Sanitize REPO_NAME and USERNAME for sed injection.** Escape sed metacharacters in variables before using them in sed patterns. Use `sed_escape() { printf '%s\n' "$1" | sed 's/[&/\]/\\&/g'; }` or switch to `awk`. (SEC-08) | 9.2 |

### IMPORTANT (should fix)

| ID | Change | Section |
|----|--------|---------|
| I-01 | **Normalize all Obsidian vault paths to `~/Documents/Obsidian/MiVault/`.** Fix the `~/Obsidian/MiVault/` reference in section 5.1. (ARCH-02) | 5.1 |
| I-02 | **Remove duplicate MCP config.** Keep only section 4.3's version (with `-y`); section 3.3 should reference it. (ARCH-07) | 3.3 |
| I-03 | **Replace `echo "$TEXT"` with `printf '%s\n' "$TEXT"`** in vault-classifier.sh and sanitize-for-global.sh to avoid escape sequence interpretation. (SEC-05) | 9.1, 9.2 |
| I-04 | **Specify /exit-review implementation mechanism.** Add explicit instructions: "Claude performs these steps using MCP filesystem tools when the skill is invoked. The SKILL.md serves as the instruction set; no separate script is needed. Claude reads current.md via MCP, pipes each item through vault-classifier.sh via Bash, applies sanitize-for-global.sh to GREEN items via Bash, then presents the AskUserQuestion." (GAP-01) | 7.2 |
| I-05 | **Add flock to accumulator for concurrent safety.** Wrap the append operation in `flock -n "$CURRENT_FILE.lock" ...` to prevent interleaved writes from Agent Teams teammates. (CONC-01) | 6.2 |
| I-06 | **Specify PreCompact insertion point.** The vault notice must be inserted before line 238 of pre-compact-handoff.sh, not "at the end." Output via log message, not stdout (stdout is reserved for JSON). (INT-01) | 8.2 |
| I-07 | **Specify PostToolUse hook ordering.** The accumulator must run AFTER sanitize-secrets.js in the PostToolUse hook array. (INT-05) | 6.3 |
| I-08 | **Add symlink creation script for /exit-review.** Copy the pattern from section 5.3 with SKILL_NAME="exit-review". (INT-04) | 7 (new subsection) |
| I-09 | **Specify claude-mem integration details.** Either provide the MCP tool calls for reading observations or remove "Also lee claude-mem" from /exit-review's process. (GAP-04) | 7.1 |
| I-10 | **Add feature flag for accumulator.** Wrap accumulator logic in a feature flag check (`RALPH_VAULT_ACCUMULATOR=true`) consistent with the existing features.json pattern used in pre-compact-handoff.sh. (Question 2) | 6.2 |
| I-11 | **Clarify sanitize-for-global.sh file location.** It is a utility, not a hook. Place in `.claude/scripts/sanitize-for-global.sh` or `.claude/hooks/lib/sanitize-for-global.sh`. Update File Reference Map accordingly. (Path consistency) | 9.2, 13 |

### NICE-TO-HAVE

| ID | Change | Section |
|----|--------|---------|
| N-01 | Set audit log file permissions to 0600. (SEC-07) | 10.2 |
| N-02 | Add YAML frontmatter format to vault global items. (Question 3) | 4.1, 7.2 |
| N-03 | Add 30-day auto-cleanup for `.claude/vault/sessions/`. (Question 4) | 7 |
| N-04 | Add content hash deduplication for GREEN items. (Question 5) | 7.2 |
| N-05 | Remove reference to non-existent `/update-config` skill. (INT-06) | 4.3 |
| N-06 | Add stale session detection in accumulator (warn if current.md has different session ID). (FILE-01) | 6.2 |

---

## Summary

The vault system implementation plan is **architecturally sound** and addresses a real problem (session statelessness) with a well-researched solution. The three-layer model, GREEN/YELLOW/RED classification, and session learning loop are all well-designed.

The primary risks are:

1. **Security gaps** in RED pattern detection relative to the existing sanitize-secrets.js (7 BLOCKING fixes required).
2. **Phase ordering** that would cause the implementer to build /exit-review before the tools it depends on exist.
3. **MCP path scope** that is dangerously broad.
4. **Underspecified implementation** of the /exit-review skill (the most complex component).

After applying the 7 BLOCKING changes, this plan is ready for phased implementation.

---

*Audit completed: 2026-03-21 | Auditor: Claude Opus*
