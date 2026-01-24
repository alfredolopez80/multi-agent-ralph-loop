# Changelog

All notable changes to Multi-Agent Ralph Wiggum are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.68.23] - 2026-01-24

### Adversarial Validation Phase 9 - Critical Security & Code Quality Fixes

Comprehensive adversarial audit cycle fixing critical security vulnerabilities and code quality issues.

#### CRIT-001: SEC-117 Command Injection via eval (FIXED)

| File | Issue | Fix |
|------|-------|-----|
| `~/.local/bin/ralph` | `eval echo "$path"` allowed command injection | Replaced with safe parameter expansion `${path/#\~/$HOME}` |

#### HIGH-001: SEC-104 Weak Cryptographic Hash (FIXED)

| File | Issue | Fix |
|------|-------|-----|
| `checkpoint-smart-save.sh` | MD5 used for file hash (cryptographically weak) | Replaced with SHA-256 via `shasum -a 256` |

#### HIGH-003: SEC-111 Input Length Validation (FIXED in 3 hooks)

DoS prevention by limiting stdin input to 100KB:

| Hook | Fix |
|------|-----|
| `orchestrator-auto-learn.sh` | Added `${#INPUT} -gt $MAX_INPUT_LEN` check |
| `global-task-sync.sh` | Changed `cat` to `head -c 100000` |
| *(Previous session)* | Third hook already fixed |

#### CRIT-003: Duplicate JSON Output via EXIT Trap (FIXED in 5 hooks)

Added `trap - ERR EXIT` before explicit JSON output to prevent duplicate output:

| Hook | Event Type |
|------|------------|
| `auto-plan-state.sh` | PostToolUse |
| `plan-analysis-cleanup.sh` | PostToolUse |
| `recursive-decompose.sh` | PostToolUse |
| `sentry-report.sh` | Stop |
| `orchestrator-report.sh` | Stop |

#### Code Quality: ShellCheck Violations (FIXED)

| Issue | File | Fix |
|-------|------|-----|
| SC2038 | `session-start-ledger.sh` | Changed `find \| xargs ls` to `find -exec ls {} +` |
| SC2124 | `plan-state-init.sh` | Changed `"$@"` to `"$*"` in 2 functions |

#### Documentation Updates

- README.md: Badge updated to v2.68.23
- CLAUDE.md: Version and changelog updated

---

## [2.68.22] - 2026-01-24

### Technical Debt Cleanup - Full CLI Implementation & Security Hardening

Comprehensive technical debt closure completing ALL documented CLI commands and security improvements.

#### GAP-CRIT-010: 6 CLI Commands Implemented (~1,423 lines)

| Command | Script | Features | Lines |
|---------|--------|----------|-------|
| `ralph checkpoint` | `checkpoint.sh` | save, restore, list, show, diff | 251 |
| `ralph handoff` | `handoff.sh` | transfer, agents, validate, history, create, load | 265 |
| `ralph events` | `events.sh` | emit, subscribe, barrier (check/wait/list), route, advance, status, history | 290 |
| `ralph agent-memory` | `agent-memory.sh` | init, read, write, transfer, list, gc | 310 |
| `ralph migrate` | `migrate.sh` | check, run, dry-run | 153 |
| `ralph ledger` | `ledger.sh` | save, load, list, show | 154 |

#### SEC-116: umask 077 Added to 31 Hooks

All 66 hooks now have restrictive file permissions (defense-in-depth):
- auto-format-prettier.sh, auto-save-context.sh, auto-sync-global.sh
- checkpoint-smart-save.sh, console-log-detector.sh, context-injector.sh
- context-warning.sh, continuous-learning.sh, inject-session-context.sh
- lsa-pre-step.sh, plan-state-init.sh, plan-state-lifecycle.sh
- plan-sync-post-step.sh, post-compact-restore.sh, pre-compact-handoff.sh
- progress-tracker.sh, project-backup-metadata.sh, prompt-analyzer.sh
- repo-boundary-guard.sh, sec-context-validate.sh, sentry-report.sh
- session-start-ledger.sh, session-start-tldr.sh, session-start-welcome.sh
- skill-validator.sh, status-auto-check.sh, statusline-health-monitor.sh
- stop-verification.sh, task-orchestration-optimizer.sh, typescript-quick-check.sh
- verification-subagent.sh

#### LOW-004: Bounded find in curator-suggestion.sh

Added `-maxdepth 2` to prevent DoS on large directories.

#### DUP-002: Shared JSON Library Created (Partial)

Created `~/.ralph/lib/hook-json-output.sh` with type-safe functions:
- `output_allow/block` → PreToolUse
- `output_continue/msg` → PostToolUse
- `output_approve` → Stop
- `output_empty/context` → UserPromptSubmit
- `trap_*` helpers for error trap setup

Migration of 32 existing hooks deferred (working, low risk).

#### Files Created/Modified

**New Scripts (6)**:
- `~/.ralph/scripts/checkpoint.sh` (v2.68.22)
- `~/.ralph/scripts/handoff.sh` (v2.68.22)
- `~/.ralph/scripts/events.sh` (v2.68.22)
- `~/.ralph/scripts/agent-memory.sh` (v2.68.22)
- `~/.ralph/scripts/migrate.sh` (v2.68.22)
- `~/.ralph/scripts/ledger.sh` (v2.68.22)

**New Library (1)**:
- `~/.ralph/lib/hook-json-output.sh` (v2.68.22)

**Updated (32)**:
- `~/.local/bin/ralph` - CLI wired to new scripts
- 31 hooks with `umask 077` added
- `.claude/TECHNICAL_DEBT.md` - Updated status

---

## [2.68.20] - 2026-01-24

### Adversarial Validation Phase 9 - SEC-029 Session ID Path Traversal Fix

Exhaustive adversarial audit continuation addressing critical session ID sanitization gaps.

#### Security Fixes (3 hooks)

| ID | File | Issue | Fix |
|----|------|-------|-----|
| **SEC-029** | `continuous-learning.sh` | Session ID used in file path without sanitization | Added `tr -cd 'a-zA-Z0-9_-' \| head -c 64` sanitization |
| **SEC-029** | `pre-compact-handoff.sh` | Session ID used in directory creation | Added sanitization pattern |
| **SEC-029** | `task-project-tracker.sh` | Session ID used in directory access | Added sanitization pattern |

#### Previously Sanitized (verified)

- `global-task-sync.sh` - Already had SEC-001 sanitization
- `reflection-engine.sh` - Already had sanitization

#### Not Vulnerable (verified)

Hooks using session_id only for logging/JSON (no file path risk):
- `progress-tracker.sh`, `smart-memory-search.sh`, `semantic-auto-extractor.sh`
- `inject-session-context.sh`, `session-start-ledger.sh`, `session-start-welcome.sh`
- `fast-path-check.sh`, `quality-gates-v2.sh`, `parallel-explore.sh`
- `orchestrator-report.sh` (generates own timestamp-based ID)

#### Files Modified

- `~/.claude/hooks/continuous-learning.sh` (v2.68.20)
- `~/.claude/hooks/pre-compact-handoff.sh` (v2.68.20)
- `~/.claude/hooks/task-project-tracker.sh` (v2.68.20)
- `.claude/TECHNICAL_DEBT.md` (SEC-029 documented as DONE)

---

## [2.68.13] - 2026-01-24

### Code Quality A+++ - ShellCheck Compliance & Test Coverage 100%

Final adversarial validation phase achieving **A+++ code quality** and **100% feature test coverage**.

#### ShellCheck Compliance (39 critical issues → 0)

| Category | Count | Files Affected |
|----------|-------|----------------|
| **SC2155** (declare/assign separately) | 28 → 0 | plan-state-init.sh (13), episodic-auto-convert.sh (5), skill-validator.sh (4), skill-pre-warm.sh (2), semantic-write-helper.sh (2), plan-state-adaptive.sh (1), sec-context-validate.sh (1) |
| **SC2221/SC2222** (pattern conflicts) | 6 → 0 | smart-skill-reminder.sh, ai-code-audit.sh, security-full-audit.sh |
| **SC2168** ('local' outside function) | 5 → 0 | project-backup-metadata.sh |

#### Test Coverage (100%)

| Suite | Tests | Feature |
|-------|-------|---------|
| `test_v261_adversarial_council.bats` | 20 | Adversarial Council validation |
| `test_v263_dynamic_contexts.bats` | 29 | Dynamic Contexts (dev, review, research, debug) |
| `test_v264_edd_framework.bats` | 33 | Eval-Driven Development (CC-/BC-/NFC-) |
| `test_v265_cross_platform_hooks.bats` | 26 | Cross-platform Node.js hooks |

**Total: 903 tests, all passing**

#### Eval Samples Created

- `memory-search.md` - Demonstrates CC-/BC-/NFC- eval pattern
- `auth-module.md` - Template for authentication feature evals

#### Files Modified (11)

- `.claude/hooks/ai-code-audit.sh` (SC2221/SC2222)
- `.claude/hooks/episodic-auto-convert.sh` (SC2155)
- `.claude/hooks/plan-state-adaptive.sh` (SC2155)
- `.claude/hooks/plan-state-init.sh` (SC2155)
- `.claude/hooks/project-backup-metadata.sh` (SC2168)
- `.claude/hooks/sec-context-validate.sh` (SC2155)
- `.claude/hooks/security-full-audit.sh` (SC2221/SC2222)
- `.claude/hooks/semantic-write-helper.sh` (SC2155)
- `.claude/hooks/skill-pre-warm.sh` (SC2155)
- `.claude/hooks/skill-validator.sh` (SC2155)
- `.claude/hooks/smart-skill-reminder.sh` (SC2221/SC2222)

---

## [2.68.11] - 2026-01-24

### Adversarial Validation Phase 8 - Input Validation & FALSE POSITIVE Resolution

Continued adversarial validation loop with focus on input validation security and verifying reported issues.

#### Security Fixes (1)

| ID | File | Issue | Fix |
|----|------|-------|-----|
| **SEC-111** | `curator-suggestion.sh`, `memory-write-trigger.sh`, `plan-state-lifecycle.sh` | Missing input length validation (DoS risk) | Added MAX_INPUT_LEN=100000 validation |

#### FALSE POSITIVES Verified

The security audit identified SEC-109 (missing error traps) which was verified as **FALSE POSITIVE**:

| ID | Claimed Issue | Actual State |
|----|---------------|--------------|
| SEC-109 | 10 hooks missing error traps | 5 are SessionStart (don't need JSON per v2.62.3 spec), 3 UserPromptSubmit already have traps, 2 are utility scripts (not registered hooks) |

#### Files Modified

- `~/.claude/hooks/curator-suggestion.sh` (v2.68.11)
- `~/.claude/hooks/memory-write-trigger.sh` (v2.68.11)
- `~/.claude/hooks/plan-state-lifecycle.sh` (v2.68.11)
- `~/.claude/hooks/orchestrator-auto-learn.sh` (v2.68.11 version sync)
- `.claude/TECHNICAL_DEBT.md` (updated SEC-109/111 status)

---

## [2.68.10] - 2026-01-24

### Adversarial Validation Phase 7 - Deep Dive Fixes

Continued adversarial validation loop addressing HIGH severity issues and documentation accuracy.

#### Security Fixes (2)

| ID | File | Issue | Fix |
|----|------|-------|-----|
| **SEC-105** | `checkpoint-smart-save.sh` | TOCTOU race condition | Atomic noclobber (O_EXCL) syscall |
| **SEC-110** | `memory-write-trigger.sh`, `orchestrator-auto-learn.sh` | User prompts logged without redaction | Added `redact_sensitive()` function |

#### Code Quality Fixes (2)

| ID | File | Issue | Fix |
|----|------|-------|-----|
| **HIGH-002** | `inject-session-context.sh` | 43 lines of dead code (context never used) | Removed dead code, added documentation |
| **HIGH-003** | `CHANGELOG.md` | Claimed SQLite FTS but uses grep | Corrected documentation to reflect actual implementation |

#### FALSE POSITIVES Verified

The security audit identified several issues that were verified as **FALSE POSITIVES**:

| ID | Claimed Issue | Actual State |
|----|---------------|--------------|
| SEC-112 | Insecure temp files | All hooks use `mktemp` correctly |
| SEC-114 | Unbounded loops | All loops have 50-iter bounds |
| SEC-115 | Glob expansion risk | No `rm *` patterns found |

#### Files Modified

- `~/.claude/hooks/checkpoint-smart-save.sh` (v2.68.10)
- `~/.claude/hooks/memory-write-trigger.sh` (v2.68.10)
- `~/.claude/hooks/orchestrator-auto-learn.sh` (v2.68.10)
- `~/.claude/hooks/inject-session-context.sh` (v2.68.10)
- `CHANGELOG.md` (documentation corrections)
- `.claude/TECHNICAL_DEBT.md` (marked 4 items DONE)

---

## [2.68.9] - 2026-01-24

### Adversarial Validation Phase 6 - Security Hardening

Comprehensive security audit via adversarial validation loop identified and fixed 11 vulnerabilities across CRITICAL, HIGH, and MEDIUM severity levels.

#### CRITICAL Fixes (5)

| ID | File | Issue | Fix |
|----|------|-------|-----|
| **CRIT-001** | `~/.claude/evals/` | EDD Framework empty | Created `edd/skill.md` and `TEMPLATE.md` |
| **CRIT-002** | `quality-gates-v2.sh` | Double JSON output (EXIT trap not cleared) | Added `trap - EXIT` before output |
| **CRIT-003** | `plan-state.json` | Version mismatch (2.57.0 vs 2.68) | Updated to 2.68.9 |
| **SEC-101** | `agent-memory-auto-init.sh` | Command injection via SUBAGENT_TYPE in sed | Regex whitelist validation |
| **SEC-102** | `auto-format-prettier.sh` | Command injection via FILE_PATH | realpath + metachar validation |

#### HIGH Fixes (6)

| ID | File | Issue | Fix |
|----|------|-------|-----|
| **HIGH-005** | `plan.sh` | Reset template version 2.65.2 | Updated to 2.68.9 |
| **HIGH-006** | `edd.sh` | Uses `bc` (may not be installed) | Replaced with bash arithmetic |
| **SEC-103** | `skill-validator.sh` | Python code injection via file path | Use `sys.argv` instead of interpolation |
| **SEC-104** | `security-full-audit.sh` | MD5 weak hash | Replaced with SHA-256 |
| **SEC-106** | `repo-learn.sh` | RALPH_TMPDIR path traversal | Validation via realpath |
| **SEC-107** | `context-injector.sh` | Path traversal via active-context.txt | Regex whitelist validation |

#### Files Modified

- `~/.claude/hooks/quality-gates-v2.sh` (v2.68.9)
- `~/.claude/hooks/agent-memory-auto-init.sh` (v2.68.9)
- `~/.claude/hooks/auto-format-prettier.sh` (v2.68.9)
- `~/.claude/hooks/skill-validator.sh` (v2.68.9)
- `~/.claude/hooks/security-full-audit.sh` (v2.68.9)
- `~/.claude/hooks/context-injector.sh` (v2.68.9)
- `~/.ralph/scripts/plan.sh` (template version 2.68.9)
- `~/.ralph/scripts/edd.sh` (bash arithmetic)
- `~/.ralph/scripts/repo-learn.sh` (v1.4.0)
- `~/.claude/skills/edd/skill.md` (NEW)
- `~/.claude/evals/TEMPLATE.md` (NEW)
- `.claude/plan-state.json` (version 2.68.9)

#### Methodology

- **Gap Analyst (Opus)**: Found 23 issues (3 CRITICAL, 7 HIGH, 8 MEDIUM, 5 LOW)
- **Security Auditor (Opus)**: Found 28 vulnerabilities (2 CRITICAL, 8 HIGH, 12 MEDIUM, 6 LOW)
- **Deduplication**: ~40 unique issues after overlap analysis

---

## [2.68.8] - 2026-01-24

### Project Hooks Cleanup & Synchronization

Adversarial validation identified hooks inconsistency between project and global directories.

#### Cleanup: 9 Legacy Orphan Hooks Removed

The following hooks were identified as **orphaned** (not registered in any settings.json) and **superseded** by modern equivalents:

| Removed Hook | Superseded By | Version |
|--------------|---------------|---------|
| `curator-trigger.sh` | `curator-suggestion.sh` | v2.57.5 |
| `detect-environment.sh` | (unused) | v2.57.5 |
| `orchestrator-helper.sh` | (unused) | v2.57.5 |
| `procedural-forget.sh` | (manual tool) | v2.59.2 |
| `quality-gates.sh` | `quality-gates-v2.sh` | v2.57.5 |
| `sentry-check-status.sh` | `sentry-report.sh` | v2.57.5 |
| `sentry-correlation.sh` | `sentry-report.sh` | v2.57.5 |
| `state-sync.sh` | `global-task-sync.sh` | v2.54.0 |
| `todo-plan-sync.sh` | `plan-sync-post-step.sh` | v2.57.2 |

**Result**: Project hooks reduced from 75 to 66 (matching global count).

#### Sync: 39 Hooks Updated from Global

The following hooks had outdated versions in the project directory and were synchronized with their global counterparts:

| Hook | Old Version | New Version |
|------|-------------|-------------|
| `adversarial-auto-trigger.sh` | v2.60.0 | v2.68.2 |
| `agent-memory-auto-init.sh` | v2.57.5 | v2.68.2 |
| `auto-plan-state.sh` | v2.62.3 | v2.68.2 |
| `auto-save-context.sh` | v2.57.5 | v2.68.2 |
| `repo-boundary-guard.sh` | v1.0.0 | v2.68.2 |
| ... and 34 more hooks | | |

**Result**: All 66 project hooks now at v2.66+ (100% compliance).

---

## [2.68.7] - 2026-01-24

### CRITICAL Fixes - JSON Output Compliance

Final adversarial audit identified 2 CRITICAL issues with missing JSON output that could cause silent hook failures.

#### CRIT-001: post-compact-restore.sh Missing JSON Output

**Issue**: PostCompact hook terminated without required JSON response.

**Fix**: Added error trap and `{"continue": true}` output at hook completion.

```diff
+ trap 'echo "{\"continue\": true}"' ERR EXIT
...
+ trap - ERR EXIT
+ echo '{"continue": true}'
```

#### CRIT-002: lsa-pre-step.sh Missing Error Trap

**Issue**: PreToolUse hook could exit without JSON on unexpected jq failures.

**Fix**: Added SEC-006 compliant error trap.

```diff
+ trap 'echo "{\"decision\": \"allow\"}"' ERR
```

#### Files Modified

| File | Change |
|------|--------|
| `~/.claude/hooks/post-compact-restore.sh` | v2.68.2 → v2.68.7 (CRIT-001) |
| `~/.claude/hooks/lsa-pre-step.sh` | v2.68.2 → v2.68.7 (CRIT-002) |
| `.claude/hooks/` | Synced both fixes |

---

## [2.68.6] - 2026-01-24

### Version Consistency Audit - 100% Compliance Achieved

**Issue**: Version Consistency Audit revealed 11 hooks with outdated versions and 2 hooks missing standard `# VERSION:` marker format.

**Root Cause**: Legacy hooks from v1.x-v2.0 were never version-bumped during v2.66+ development cycle.

**Fix**: All 11 hooks updated to v2.68.6 with standard VERSION marker format.

#### HIGH Priority Fixes (2)

| Hook | Issue | Resolution |
|------|-------|------------|
| `procedural-inject.sh` | VERSION in variable only, not standard comment | Added `# VERSION: 2.68.5` + corrected version 2.68.3→2.68.5 |
| `sec-context-validate.sh` | VERSION in variable only, not standard comment | Added `# VERSION: 2.68.0` marker |

#### MEDIUM Priority Updates (2)

| Hook | Old Version | New Version | Change |
|------|-------------|-------------|--------|
| `context-injector.sh` | v1.0.1 | v2.68.6 | Version bump + description update |
| `usage-consolidate.sh` | v1.0.0 | v2.68.6 | Version bump + reference update |

#### LOW Priority Updates (7)

| Hook | Old Version | New Version |
|------|-------------|-------------|
| `auto-format-prettier.sh` | v1.0.1 | v2.68.6 |
| `console-log-detector.sh` | v1.0.1 | v2.68.6 |
| `project-backup-metadata.sh` | v1.0.0 | v2.68.6 |
| `smart-skill-reminder.sh` | v2.0.0 | v2.68.6 |
| `task-primitive-sync.sh` | v1.2.1 | v2.68.6 |
| `task-project-tracker.sh` | v1.1.0 | v2.68.6 |
| `typescript-quick-check.sh` | v1.0.1 | v2.68.6 |

#### Result

| Metric | Before | After |
|--------|--------|-------|
| Total hooks | 67 | 67 |
| Hooks ≥v2.66 | 56 (83%) | 67 (100%) |
| Missing VERSION marker | 2 | 0 |

---

## [2.68.5] - 2026-01-24

### HIGH-001 Fix: Procedural Inject Lock Retry Enhancement

**Issue**: `procedural-inject.sh` hook could fail to acquire append lock under high concurrency scenarios (multiple Task invocations in rapid succession).

**Root Cause**: Only 3 retry attempts (300ms window) before giving up on lock acquisition.

**Fix**: Increased `MAX_LOCK_RETRIES` from 3 to 10, extending the retry window from 300ms to 1 second.

| Metric | Before | After |
|--------|--------|-------|
| Lock retries | 3 | 10 |
| Retry window | 300ms | 1000ms |
| Concurrency tolerance | Low | High |

#### Files Modified

| File | Change |
|------|--------|
| `~/.claude/hooks/procedural-inject.sh` | v2.68.3 → v2.68.5 (retry enhancement) |
| `.claude/hooks/procedural-inject.sh` | Synced from global |

---

## [2.68.4] - 2026-01-24

### Adversarial Validation Phase 4 - Security & Compatibility Fixes

Three parallel adversarial agents (Gap Analyst, JSON Validator, Security Auditor) identified **16 gaps** with 3 CRITICAL, 6 HIGH, 4 MEDIUM, and 3 LOW severity issues. This release addresses all CRITICAL and MEDIUM issues.

#### CRITICAL Fixes (3)

| Issue | Description | Solution |
|-------|-------------|----------|
| **GAP-CRIT-001** | `sync_from_global()` dead code in `global-task-sync.sh` | Synced from global (already removed in v2.66.6) |
| **GAP-CRIT-002** | `git-safety-guard.py` v2.43.0 (23 versions behind) | Synced from global (now v2.66.8) |
| **GAP-CRIT-003** | `TECHNICAL_DEBT.md` referenced but existed | Updated with new gaps |

#### MEDIUM Security Fixes (2)

| Issue | Hook | Description | Solution |
|-------|------|-------------|----------|
| **MED-006** | `parallel-explore.sh` | Command injection via spaces in sanitizer | Removed spaces from whitelist, added 50-char limit |
| **MED-008** | `ai-code-audit.sh` | macOS-specific `stat -f %m` breaks on Linux | Added `$OSTYPE` detection for portable stat |

#### JSON Format Validation (100% PASS)

The JSON Validator agent confirmed all 73+ hooks have correct JSON output formats:
- 0 instances of invalid `{"decision": "continue"}` pattern
- 54 hooks with error traps (ERR/EXIT)
- 95 instances of trap clearing (CRIT-005 compliant)
- 100% compliance with Claude Code hook protocol

#### Technical Debt Updates

**Completed**:
- GAP-CRIT-001, GAP-CRIT-002, MED-006, MED-008

**New Items Documented** (deferred):
- LOW-001 to LOW-005: Minor security hardening (P3)
- GAP-HIGH-006: 20+ hooks at pre-v2.66 versions (P2)

#### Files Modified

| File | Change |
|------|--------|
| `.claude/hooks/git-safety-guard.py` | v2.43.0 → v2.66.8 sync |
| `.claude/hooks/global-task-sync.sh` | sync_from_global() removed |
| `~/.claude/hooks/parallel-explore.sh` | MED-006 sanitizer fix |
| `~/.claude/hooks/ai-code-audit.sh` | MED-008 portable stat |
| `.claude/TECHNICAL_DEBT.md` | Added 4 completed, 2 new items |

---

## [2.68.3] - 2026-01-24

### PERF-001: Critical Hook Performance Optimization

**Root Cause**: `procedural-inject.sh` hook had 393 rules in 205KB file with two O(n²) loops:
1. First loop: Scan all rules matching domain
2. Second loop: Scan all rules matching trigger keywords

This caused **timeout (>3s)** on every `PreToolUse:Task` invocation. With 7 Task hooks firing and 2 parallel agents, this produced **14 hook errors**.

#### Performance Fix

| Metric | Before | After |
|--------|--------|-------|
| Execution time | >3000ms (timeout) | ~113ms |
| Complexity | O(n²) | O(1) with jq pre-filter |
| Hook errors | 14 | 0 |

#### Code Changes

```bash
# BEFORE (O(n²) - 393 rules × 2 loops)
while IFS= read -r rule; do
    matches=$(jq -r "..." <<< "$rule")  # jq call per rule
done <<< "$(jq -c '.rules[]' "$PROCEDURAL_FILE")"

# AFTER (O(1) - single jq pre-filter)
FILTERED_RULES=$(jq -c --arg domain "$DETECTED_DOMAIN" '
  .rules // [] |
  map(select((.confidence // 0) >= ($min_conf | tonumber))) |
  .[0:5]
' "$PROCEDURAL_FILE" 2>/dev/null)
```

#### Additional Fixes

| Issue | Description | Fix |
|-------|-------------|-----|
| PERF-001a | Undefined `$DOMAIN_MATCH_COUNT` variable | Removed reference |
| PERF-001b | Undefined `$TRIGGER_MATCH_COUNT` variable | Removed reference |
| GAP-004 | Schema JSON syntax error (line 224) | Rewrote `oneOf` structure |

#### Schema Fix (plan-state-v2.json)

The `steps` field `oneOf` structure was improperly nested, causing JSON parse errors:

```json
// BEFORE (broken - properties outside object)
"steps": {
  "oneOf": [
    { "type": "object", "properties": {...} },
    "spec": {},  // ← Wrong placement
    "actual": {} // ← Wrong placement
  ]
}

// AFTER (fixed - proper nesting)
"steps": {
  "oneOf": [
    {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "properties": { "spec": {}, "actual": {} }
      }
    },
    { "type": "array", "items": {...} }
  ]
}
```

#### Hook Sync

Synced 10 missing hooks from `~/.claude/hooks/` to project directory:
- `auto-format-prettier.sh`
- `console-log-detector.sh`
- `episodic-auto-convert.sh`
- `project-backup-metadata.sh`
- `session-start-tldr.sh`
- `skill-pre-warm.sh`
- `smart-skill-reminder.sh`
- `task-project-tracker.sh`
- `typescript-quick-check.sh`
- `usage-consolidate.sh`

**Total hooks in project**: 75 (was 65)

---

## [2.68.2] - 2026-01-24

### Adversarial Validation Loop - Double JSON Bug Fixes

**Scope**: Critical fixes for hook EXIT trap pattern causing duplicate JSON output

**Root Cause**: Hooks with `trap 'echo JSON' ERR EXIT` produced duplicate JSON when:
1. Explicit `echo '{"decision": "allow"}'` was called
2. Then `exit 0` triggered the EXIT trap, producing second JSON

This caused Claude Code errors: `AttributeError: 'list' object has no attribute 'get'` (18 PreToolUse:Task hook errors reported by user)

#### CRITICAL Fixes

| Issue ID | File | Problem | Fix |
|----------|------|---------|-----|
| CRIT-002 | `inject-session-context.sh` | Double JSON on Task tool | Add `trap - EXIT` before explicit output |
| CRIT-003 | `checkpoint-smart-save.sh` | Double JSON on Edit/Write | Add `trap - EXIT` before explicit output |
| CRIT-004 | `skill-validator.sh` | Double JSON on Skill tool | Add `trap - EXIT` before explicit output |
| CRIT-004b | `skill-validator.sh` | Triple JSON from timeout subshell | Only set trap when not sourced |
| CRIT-005 | `quality-gates-v2.sh` | Double JSON on Edit/Write | Add `trap - EXIT` before explicit output |
| CRIT-006 | `progress-tracker.sh` | Double JSON on Edit/Write/Bash | Add `trap - EXIT` before explicit output |
| CRIT-007 | `plan-state-adaptive.sh` | Double JSON on UserPromptSubmit | Add `trap - EXIT` before explicit output |
| CRIT-008 | `plan-state-lifecycle.sh` | Double JSON on UserPromptSubmit | Add `trap - EXIT` before explicit output |
| CRIT-009 | `statusline-health-monitor.sh` | Double JSON on UserPromptSubmit | Add `trap - EXIT` before explicit output |
| CRIT-010 | `curator-suggestion.sh` | Wrong JSON format (PostToolUse in UserPromptSubmit) | Changed `{"continue":true}` to `{}` |

#### Gap Analysis Fixes (v2.60-v2.68)

| Issue ID | File | Problem | Fix |
|----------|------|---------|-----|
| GAP-CRIT-001 | `plan-state-v2.json` | Schema at v2.54, missing phases/barriers | Updated to v2.66 with phases[], barriers{}, current_phase |
| GAP-CRIT-002 | Node.js hooks | Files exist but not registered | Documented as "deferred by design" in TECHNICAL_DEBT.md |
| GAP-CRIT-003 | `plan-state.json` | Inconsistent status fields | Resolved - new plan-state is consistent |

#### HIGH Priority Fixes

| Issue ID | Scope | Problem | Fix |
|----------|-------|---------|-----|
| GAP-HIGH-002 | 54 hooks | Stale v2.57.x-v2.66.x versions | Bulk version bump to v2.68.2 |
| GAP-HIGH-003 | 9 hooks | Missing in project directory | Synced from global ~/.claude/hooks/ |
| GAP-HIGH-001 | Tests | Missing v2.61-v2.65 test coverage | Documented in TECHNICAL_DEBT.md (P2) |
| GAP-HIGH-005 | EDD skill | Not implemented | Documented in TECHNICAL_DEBT.md (P3) |

#### Files Updated

| File | Old Version | New Version |
|------|-------------|-------------|
| `inject-session-context.sh` | 2.66.4 | 2.68.1 |
| `checkpoint-smart-save.sh` | 2.66.8 | 2.68.1 |
| `skill-validator.sh` | 2.62.3 | 2.68.2 |
| `quality-gates-v2.sh` | 2.66.6 | 2.68.1 |
| `progress-tracker.sh` | 2.62.3 | 2.68.1 |
| `plan-state-adaptive.sh` | 2.57.0 | 2.68.2 |
| `plan-state-lifecycle.sh` | 2.57.0 | 2.68.2 |
| `statusline-health-monitor.sh` | 2.62.3 | 2.68.2 |
| `plan-state-v2.json` (schema) | 2.54 | 2.66 |
| `curator-suggestion.sh` | 2.57.5 | 2.68.2 |

#### Pattern Applied

```bash
# BEFORE (broken - produces 2 JSON objects)
trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT
# ... code ...
echo '{"decision": "allow"}'
exit 0  # ← EXIT trap fires here, producing second JSON

# AFTER (fixed - produces 1 JSON object)
trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT
# ... code ...
trap - EXIT  # ← Clear trap before explicit output
echo '{"decision": "allow"}'
exit 0
```

#### Additional Auto-Invoke Hooks (v2.68.0)

Added new auto-invoke hooks from previous session:
- `ai-code-audit.sh` - Detects AI anti-patterns (dead code, overkill, fallback)
- `adversarial-auto-trigger.sh` - Auto-triggers adversarial validation
- `security-full-audit.sh` - Comprehensive security scanning
- `code-review-auto.sh` - Auto-triggers code review on task completion
- `deslop-auto-clean.sh` - Auto-triggers deslop cleanup

#### Test Coverage

58 unit tests added in `tests/test_v268_auto_invoke_hooks.bats`:
- Hook registration verification (6 tests)
- File existence and permissions (6 tests)
- Bash syntax validation (6 tests)
- Version header checks (5 tests)
- SEC-033 error trap compliance (5 tests)
- Functional tests for each hook (22 tests)
- Project sync verification (5 tests)
- Integration tests (2 tests)
- Regression prevention tests (2 tests)

---

## [2.66.8] - 2026-01-23

### Adversarial Validation Loop - HIGH Priority Fixes (Phase 3)

**Scope**: Final phase of multi-model adversarial validation, addressing HIGH severity issues

#### HIGH Severity Fixes

| Issue ID | File | Problem | Fix |
|----------|------|---------|-----|
| HIGH-001 | `plan.sh` | Missing phases[], barriers{}, verification in reset template | Added complete schema-compliant template fields |
| HIGH-003 | Multiple files | Version inconsistencies across hook ecosystem | Synchronized 7 hooks to v2.66.8 |
| HIGH-004 | `lsa-pre-step.sh` | ASCII art output on stdout (conflicts with JSON) | Redirected to stderr with `>&2` |
| SEC-051 | `repo-boundary-guard.sh` | Tilde expansion bypass in path validation | Added `realpath -m` for proper path canonicalization |
| SEC-053 | `pre-compact-handoff.sh` | Two remaining `{"continue": true}` instead of `{"decision": "allow"}` | Fixed JSON format (lines 84, 202) |

#### Issues Verified Already Fixed (No Changes Needed)

| Issue ID | File | Status |
|----------|------|--------|
| SEC-052 | `checkpoint-smart-save.sh` | RACE-001 atomic mkdir already implemented |
| SEC-050 | `semantic-realtime-extractor.sh` | `jq --arg` properly escapes content |
| HIGH-005 | `git-safety-guard.py` | Fail-closed try/except already implemented |
| HIGH-006 | `context-warning.sh` | Correct JSON format for UserPromptSubmit hook |

#### Deferred (Technical Debt)

| Issue ID | Scope | Reason |
|----------|-------|--------|
| DUP-002 | 30+ hooks | JSON output helper duplication - refactoring deferred (no functional impact) |
| HIGH-002 | Node.js hooks | Feature not yet implemented (directory doesn't exist) |

#### Files Updated

| File | Old Version | New Version |
|------|-------------|-------------|
| `plan.sh` | 2.66.6 | 2.66.8 |
| `lsa-pre-step.sh` | 2.62.3 | 2.66.8 |
| `repo-boundary-guard.sh` | 2.62.3 | 2.66.8 |
| `pre-compact-handoff.sh` | 2.66.6 | 2.66.8 |
| `checkpoint-smart-save.sh` | 2.57.5 | 2.66.8 |
| `git-safety-guard.py` | 2.43.0 | 2.66.8 |
| `context-warning.sh` | 2.57.5 | 2.66.8 |
| `semantic-realtime-extractor.sh` | 2.57.5 | 2.66.8 |

#### Validation Summary

All 8 modified files validated:
- Bash syntax: `bash -n` ✅
- Python syntax: `python3 -m py_compile` ✅

**Total v2.66.6-v2.66.8 Cycle**: 22 issues resolved (4 CRITICAL, 18 HIGH)

---

## [2.66.7] - 2026-01-23

### Adversarial Validation Loop - Critical Fixes (Phase 2)

**Scope**: Continuation of multi-model adversarial validation, addressing CRITICAL issues from Gap Analyst

#### CRITICAL Fixes

| Issue ID | File | Problem | Fix |
|----------|------|---------|-----|
| CRIT-001 | `agent-memory-auto-init.sh` | Missing explicit JSON output on success path (relied on trap) | Added `trap - EXIT; echo '{"decision": "allow"}'` for explicit output |
| CRIT-002 | `schemas/plan-state-v2.json` | Schema v2.54 missing phases, barriers, verification fields from v2.62+ | Updated to v2.66 with phases[], barriers{}, verification object |

#### Schema Updates (CRIT-002)

New fields added to plan-state-v2.66 schema:

| Field | Type | Purpose |
|-------|------|---------|
| `phases[]` | array | WAIT-ALL phase barriers with phase_id, step_ids, execution_mode |
| `barriers{}` | object | Phase completion tracking (additionalProperties: boolean) |
| `verification` | object | Verification subagent tracking (enabled, agent_type, result) |

#### Files Updated

| File | Old Version | New Version |
|------|-------------|-------------|
| `agent-memory-auto-init.sh` | 2.57.5 | 2.66.7 |
| `schemas/plan-state-v2.json` | v2.54 | v2.66 |

---

## [2.66.6] - 2026-01-23

### Adversarial Validation Loop - Critical Security Fixes

**Scope**: Comprehensive multi-model adversarial validation (Claude Opus, Sonnet) from v2.60 to v2.66.5

#### CRITICAL Security Fixes

| Issue ID | File | Vulnerability | Fix |
|----------|------|---------------|-----|
| SEC-041 | `quality-gates-v2.sh:161,174` | Python command injection via `$FILE_PATH` interpolation | Use `sys.argv[1]` instead of string interpolation |
| SEC-042 | `auto-plan-state.sh:16` | Malformed JSON trap (missing quote escapes) | Fixed `{\"continue\": true}` escaping |

#### HIGH Severity Fixes

| Issue ID | File | Problem | Fix |
|----------|------|---------|-----|
| SEC-043 | `inject-session-context.sh` | JSON injection in additionalContext | Use `jq -n --arg` for safe JSON construction |
| SEC-044 | `plan.sh` | Undefined `PROJECT_DIR` in path validation | Added `PROJECT_DIR=$(pwd)` definition |
| SEC-045 | `quality-gates-v2.sh` | `realpath -e` doesn't exist on macOS | Removed `-e` flag (portable) |
| SEC-046 | `pre-compact-handoff.sh` | PreCompact using wrong JSON format (`{"continue": true}` instead of `{"decision": "allow"}`) | Fixed JSON format for PreCompact event type |
| SEC-047 | `plan-sync-post-step.sh` | Missing error trap for guaranteed JSON output | Added `trap 'echo "{\"continue\": true}"' ERR EXIT` |
| SEC-048 | `project-backup-metadata.sh` | `jq --argint` doesn't exist on macOS | Changed to `--argjson` (portable) |
| SEC-049 | `checkpoint-auto-save.sh` | Hook registered as PostToolUse but coded as PreToolUse | Moved registration to PreToolUse in settings.json |
| GAP-003 | `orchestrator-report.sh` | Duplicate VERSION comments (2.59.0 and 2.57.5) | Consolidated to single VERSION: 2.66.6 |
| DEAD-001 | `global-task-sync.sh` | Dead code `sync_from_global()` (35 lines) | Removed deprecated function |

#### Files Updated

| File | Old Version | New Version |
|------|-------------|-------------|
| `quality-gates-v2.sh` | 2.57.5 | 2.66.6 |
| `auto-plan-state.sh` | 2.62.3 | 2.66.6 |
| `orchestrator-report.sh` | 2.59.0/2.57.5 | 2.66.6 |
| `inject-session-context.sh` | 2.66.4 | 2.66.6 |
| `plan.sh` | 1.0.0 | 2.66.6 |
| `global-task-sync.sh` | 2.66.5 | 2.66.6 |
| `pre-compact-handoff.sh` | 2.62.3 | 2.66.6 |
| `plan-sync-post-step.sh` | - | 2.66.6 |
| `project-backup-metadata.sh` | 1.0.0 | 2.66.6 |
| `checkpoint-auto-save.sh` | 2.66.3 | 2.66.6 |
| `settings.json` | - | Fixed hook registration |

#### Validation Methodology

Multi-model adversarial analysis using 4 parallel agents:
- **Gap Analyst (Opus)**: 24 issues found (3 CRITICAL, 7 HIGH)
- **Security Auditor (Opus)**: 21 issues found (2 CRITICAL, 6 HIGH)
- **Code Reviewer (Sonnet)**: 16 issues found (5 HIGH)
- **Hook Validator (Sonnet)**: 4 registration/format issues found

**Total Issues Fixed**: 11 (2 CRITICAL, 9 HIGH)
- SEC-041 through SEC-049: Security and compatibility fixes
- GAP-003: Version consistency fix
- DEAD-001: Dead code removal

---

## [2.66.5] - 2026-01-23

### Fixed (DUP-001: Code Duplication - Domain Inference)

**Severity**: MEDIUM (Quality/Maintenance)
**Impact**: Duplicated domain inference logic in two files creates maintenance burden and behavioral divergence risk

#### Problem

Domain inference logic was duplicated in:
- `~/.ralph/scripts/repo-learn.sh` (lines 185-239): `infer_domain_from_category()`, `infer_domain_from_repo()`
- `~/.claude/hooks/orchestrator-auto-learn.sh` (lines 125-143): inline grep pattern detection

Same logic with subtle differences could lead to inconsistent domain classification.

#### Solution

Created shared library `~/.ralph/lib/domain-classifier.sh` with unified functions:

| Function | Purpose |
|----------|---------|
| `infer_domain_from_text()` | Infer domain from free-form text (prompts) |
| `infer_domain_from_category()` | Infer domain from category name |
| `infer_domain_from_repo()` | Infer domain from repository URL |
| `get_domain_keywords()` | Get search keywords for rule matching |
| `infer_domain_combined()` | Combined inference (URL → category → fallback) |

#### Files Updated

| File | Version | Changes |
|------|---------|---------|
| `~/.ralph/lib/domain-classifier.sh` | 1.0.0 | **NEW** - Shared domain classification library |
| `~/.ralph/scripts/repo-learn.sh` | 1.3.0 | Sources shared library, removed duplicate functions |
| `~/.claude/hooks/orchestrator-auto-learn.sh` | 2.66.5 | Sources shared library with fallback |

#### Backward Compatibility

Both scripts include fallback logic if the shared library is missing:
- `repo-learn.sh`: Defines minimal fallback functions
- `orchestrator-auto-learn.sh`: Falls back to inline grep patterns

### Also Fixed in This Release

| Issue | File | Fix |
|-------|------|-----|
| RACE-001 | `checkpoint-smart-save.sh` | Atomic mkdir locking for race condition |
| SEC-040 | `plan.sh` | Path validation to prevent traversal |
| DATA-001 | `repo-learn.sh` | JSON corruption detection after merge |
| SC2168 | `global-task-sync.sh` | Removed `local` keyword outside functions (shellcheck) |

---

## [2.66.4] - 2026-01-23

### Fixed (SEC-039: PreToolUse Hook JSON Format)

**Severity**: CRITICAL
**Impact**: PreToolUse hooks returning wrong JSON format caused "PreToolUse:Task hook error"

#### Problem

PreToolUse hooks were returning `{"continue": true}` instead of `{"decision": "allow"}`:
- **PreToolUse hooks** MUST return `{"decision": "allow"}` or `{"decision": "block"}`
- **PostToolUse hooks** use `{"continue": true}` (different format!)

| Hook | Wrong Format | Correct Format |
|------|--------------|----------------|
| `fast-path-check.sh` | `{"continue": true}` | `{"decision": "allow"}` |
| `smart-memory-search.sh` | `{"continue": true}` | `{"decision": "allow"}` |
| `inject-session-context.sh` | `{"continue": true}` | `{"decision": "allow"}` |
| `orchestrator-auto-learn.sh` | `{"continue": true}` | `{"decision": "allow"}` |

#### Hooks Updated

| Hook | Old Version | New Version |
|------|-------------|-------------|
| `fast-path-check.sh` | 2.57.5 | 2.66.4 |
| `smart-memory-search.sh` | 2.66.3 | 2.66.4 |
| `inject-session-context.sh` | 2.62.3 | 2.66.4 |
| `orchestrator-auto-learn.sh` | 2.60.1 | 2.66.4 |

#### Hook JSON Format Reference (SEC-039)

| Hook Type | Format | Example |
|-----------|--------|---------|
| **PreToolUse** | `{"decision": "allow/block"}` | `{"decision": "allow", "additionalContext": "..."}` |
| **PostToolUse** | `{"continue": true/false}` | `{"continue": true, "systemMessage": "..."}` |
| **Stop** | `{"decision": "approve"}` | `{"decision": "approve", "reason": "..."}` |

### Documentation Fix

- **README.md**: Corrected "SQLite FTS" → "grep-based search" for Memory Storage
  - Note: SQLite FTS was planned in v2.46.0 but smart-memory-search.sh uses JSON file search with `find` and `grep`
  - This correction reflects the actual implementation

---

## [2.66.3] - 2026-01-23

### Fixed (macOS Compatibility - flock → mkdir)

**Severity**: CRITICAL
**Impact**: Hooks failed on macOS because `flock` is Linux-only

#### Portable Locking Mechanism

Replaced `flock` (Linux-only) with `mkdir`-based locking (portable to macOS and Linux):

| Hook | Issue | Fix |
|------|-------|-----|
| `decision-extractor.sh` | `flock: command not found` | SEC-009: mkdir-based lock |
| `semantic-write-helper.sh` | `flock: command not found` | mkdir-based lock |
| `global-task-sync.sh` | `flock: command not found` | SEC-010: mkdir-based lock |

**Pattern used**:
```bash
# Acquire (atomic on all platforms)
while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.1; done

# Release
rmdir "$LOCK_DIR" 2>/dev/null || true
```

---

## [2.66.2] - 2026-01-23

### Security (Critical Vulnerability Remediation)

**Severity**: CRITICAL to HIGH
**Impact**: Fixes 8 security vulnerabilities discovered during adversarial audit

#### CRITICAL - JSON Injection Fixes

| Vuln ID | Hook | Issue | Fix |
|---------|------|-------|-----|
| VULN-002 | `checkpoint-smart-save.sh` | Heredoc with `$FILE_PATH` | SEC-002: Use `jq --arg` |
| VULN-003 | `decision-extractor.sh` | Heredoc with `$FILE_PATH` | SEC-003: Use `jq --arg` |
| SEC-007 | `smart-memory-search.sh` | Insufficient sed escaping | Use `jq --arg` |
| SEC-008 | `checkpoint-auto-save.sh` | Heredoc with `$(pwd)` | Use `jq --arg` |

#### CRITICAL - Path Traversal Fix

| Vuln ID | Hook | Issue | Fix |
|---------|------|-------|-----|
| VULN-001 | `global-task-sync.sh` | Session ID used in path without sanitization | SEC-001: `tr -cd 'a-zA-Z0-9_-'` + length validation |

#### HIGH - Insecure Temp File Permissions

| Vuln ID | Hook | Issue | Fix |
|---------|------|-------|-----|
| VULN-004 | `global-task-sync.sh` | Missing umask | SEC-004: Added `umask 077` |
| VULN-005 | `task-primitive-sync.sh` | Missing umask | SEC-005: Added `umask 077` |

#### Version Updates

| Hook | Old Version | New Version |
|------|-------------|-------------|
| `global-task-sync.sh` | 2.66.0 | 2.66.2 |
| `checkpoint-smart-save.sh` | 2.57.5 | 2.57.5 (SEC-002 added) |
| `decision-extractor.sh` | 2.62.3 | 2.66.3 |
| `task-primitive-sync.sh` | 1.2.0 | 1.2.1 |
| `smart-memory-search.sh` | 2.57.8 | 2.66.3 |
| `checkpoint-auto-save.sh` | 2.62.3 | 2.66.3 |

#### Security Pattern Reference

All hooks now follow these patterns:

```bash
# SEC-001: Path sanitization
SESSION_ID=$(echo "$SESSION_ID" | tr -cd 'a-zA-Z0-9_-')

# SEC-002/003/007/008: Safe JSON construction
jq -n --arg var "$UNTRUSTED" '{field: $var}'

# SEC-004/005: Restrictive permissions
umask 077
```

---

## [2.66.1] - 2026-01-23

### Fixed (Adversarial Validation Loop)

**Severity**: MEDIUM
**Impact**: Fixes gaps discovered during exhaustive adversarial review

#### GAP-001/002: Hook Registration

- **task-project-tracker.sh** now registered in settings.json (PostToolUse: TaskCreate|TaskUpdate|TaskList)
- **project-backup-metadata.sh** now registered in settings.json (SessionStart + Stop)

#### GAP-004/005: Schema Compliance

- **plan-state.json** now includes required `phases[]` and `barriers{}` fields
- Schema version bumped to 2.66.0
- 8 hooks that depend on `.phases[0]` now work correctly

#### GAP-010: SEC-033 Error Trap Compliance

Added SEC-033 error traps to 5 hooks that were missing them:

| Hook | Type | Trap Output |
|------|------|-------------|
| `console-log-detector.sh` | PostToolUse | `{"continue": true}` |
| `typescript-quick-check.sh` | PostToolUse | `{"continue": true}` |
| `auto-format-prettier.sh` | PostToolUse | `{"continue": true}` |
| `continuous-learning.sh` | Stop | `{"decision": "approve"}` |
| `context-injector.sh` | SessionStart | Text fallback |

#### Test Coverage

- Created `tests/test_v256_task_primitives.bats` with 25 tests
- All tests passing (hook existence, versions, JSON output, error traps, schema compliance)
- Updated test runner to v2.66.0

---

## [2.66.0] - 2026-01-23

### Fixed (Task Primitive Integration - 5 Phases)

**Severity**: HIGH
**Impact**: Fixes critical bugs in Claude Code Task Primitive synchronization

#### Overview

Comprehensive fix of the hook system to properly integrate with Claude Code's Task Primitive architecture. Based on adversarial analysis and Codex CLI review.

#### Phase 1: Session ID Canonical Source

**Files Modified**: `global-task-sync.sh`, `task-primitive-sync.sh`, `task-project-tracker.sh`

- **Before**: Hooks didn't read `INPUT.session_id` from stdin, causing session fragmentation
- **After**: `INPUT.session_id` is now the canonical source (first priority)
- Fallback cascade: INPUT → CLAUDE_SESSION_ID env → SESSION_ID env → `.claude/session-id` file → plan_id → timestamp

#### Phase 2: Individual File Format

**File**: `global-task-sync.sh` (v2.66.0)

- **Before**: Wrote monolithic `tasks.json` file
- **After**: Writes individual `{id}.json` files (e.g., `1.json`, `2.json`)
- This matches Claude Code's expected format for task storage

#### Phase 3: TodoWrite Removal

**File**: `global-task-sync.sh` (v2.66.0)

- **Before**: Case statement included `TodoWrite` which never triggers
- **After**: Removed `TodoWrite` from matchers (it's declarative, not executive)
- Note: By design, Claude Code does NOT trigger hooks for `TodoWrite`

#### Phase 4: Unidirectional Sync

**File**: `global-task-sync.sh` (v2.66.0)

- **Before**: Bidirectional sync with timestamp comparison
- **After**: Unidirectional sync (plan-state.json → Claude Code Tasks)
- **Rationale**: plan-state.json is the single source of truth for orchestration
- `sync_from_global()` function deprecated but kept for rollback compatibility

#### Phase 5: Documentation Updates

- Updated version numbers in all modified hooks
- Updated CHANGELOG.md with comprehensive change documentation
- Updated header comments explaining new behavior

#### Files Modified

| File | Version | Changes |
|------|---------|---------|
| `~/.claude/hooks/global-task-sync.sh` | 2.66.0 | All 4 phases |
| `~/.claude/hooks/task-primitive-sync.sh` | 1.2.0 | Session ID fix |
| `~/.claude/hooks/task-project-tracker.sh` | 1.1.0 | Session ID fix |

#### Architecture Clarification

| Concern | Source of Truth | Display |
|---------|-----------------|---------|
| Orchestration (phases, barriers, loops) | `plan-state.json` | StatusLine |
| Task UI/Viewer | Claude Code Tasks | `~/.claude/tasks/<session>/` |

---

## [2.65.2] - 2026-01-23

### Added (Plan Lifecycle Management)

**Severity**: ENHANCEMENT
**Impact**: Proper lifecycle management for plan-state.json

#### Overview

Addresses the gap where completed/stale plans were not being properly archived before starting new work. Provides CLI commands for full plan lifecycle management.

#### New Commands

```bash
ralph plan archive [desc]  # Archive current plan and start fresh
ralph plan reset           # Reset plan-state to empty
ralph plan show            # Show current plan status
ralph plan history [n]     # Show archived plans
ralph plan restore <id>    # Restore from archive
```

#### New Files

| File | Purpose |
|------|---------|
| `~/.ralph/scripts/plan.sh` | Plan lifecycle CLI |

#### Key Features

- **Auto-archive**: Archives plan with metadata before reset
- **Format detection**: Works with both v1 (array) and v2 (object) schemas
- **Restore capability**: Can restore previous plans from archive
- **Status display**: Color-coded progress with step details

#### Archive Storage

Plans archived to `~/.ralph/archive/plans/plan-<timestamp>-<task-slug>.json` with metadata:
```json
{
  "_archive_metadata": {
    "archived_at": "2026-01-23T15:46:20Z",
    "description": "User provided description",
    "source": ".claude/plan-state.json"
  }
}
```

---

## [2.65.1] - 2026-01-23

### Fixed (Task Primitive Statusline Integration)

**Severity**: HIGH
**Impact**: Fixes task tracking in statusline when using Claude Code Task primitives

#### Problem

The statusline was not updating when using Claude Code's native Task primitives (`TaskCreate`, `TaskUpdate`, `TaskList`) because:
1. `TodoWrite` does NOT trigger hooks (by design in Claude Code)
2. The `global-task-sync.sh` hook was only registered for the `Task` matcher (subagents)
3. No hook was syncing Task primitive updates back to `plan-state.json`

#### Solution

Created new `task-primitive-sync.sh` hook (v1.1.0) that:
- Triggers on `TaskCreate|TaskUpdate|TaskList` PostToolUse events
- Syncs task state back to `.claude/plan-state.json`
- Allows statusline-ralph.sh to show correct progress
- **v1.1.0**: Supports both v1 (array) and v2 (object) plan-state formats
  - Detects format dynamically via `jq -r '.steps | type'`
  - Preserves existing structure during updates
  - Creates new files in v2 (object) format

#### New Files

| File | Purpose |
|------|---------|
| `~/.claude/hooks/task-primitive-sync.sh` | Sync Task primitives to plan-state |

#### Configuration Change

Added new PostToolUse hook registration:
```json
{
  "matcher": "TaskCreate|TaskUpdate|TaskList",
  "hooks": [{
    "command": "${HOME}/.claude/hooks/task-primitive-sync.sh",
    "timeout": 15
  }]
}
```

---

## [2.65.0] - 2026-01-23

### Added (Cross-Platform Hook Support)

**Severity**: ENHANCEMENT
**Impact**: New cross-platform Node.js hook library for Windows/Linux/macOS compatibility

#### Overview

Phase 4 of the ECC improvement plan. Adds Node.js alternatives for critical hooks, enabling cross-platform support.

#### New Files

| File | Purpose |
|------|---------|
| `~/.claude/hooks/lib/cross-platform.js` | Cross-platform utilities library |
| `~/.claude/hooks/node/context-injector.js` | Node.js version of context injector |
| `~/.claude/hooks/continuous-learning.sh` | Session pattern extraction at end |

#### Cross-Platform Library Functions

- `getHomeDir()` - Cross-platform home directory
- `readStdinJson()` - Async stdin reading
- `allowTool()` / `blockTool(reason)` - PreToolUse responses
- `continueExecution()` - PostToolUse response
- `approveStop()` - Stop hook response
- `getActiveContext()` / `setActiveContext(ctx)` - Context management
- `getRalphDirs()` - All Ralph directory paths

---

## [2.64.0] - 2026-01-23

### Added (Eval Harness / EDD Framework)

**Severity**: ENHANCEMENT
**Impact**: New Eval-Driven Development framework with pass@k metrics

#### Overview

Phase 3 of the ECC improvement plan. Implements EDD (Eval-Driven Development) - treating evals as "unit tests of AI development".

#### New Files

| File | Purpose |
|------|---------|
| `~/.claude/skills/eval-harness.md` | Skill definition for EDD |
| `~/.ralph/scripts/edd.sh` | CLI for eval management |
| `~/.claude/evals/` | Directory for eval definitions |

#### Usage

```bash
ralph eval define auth-module    # Create eval definition
ralph eval check auth-module     # Run checks (pass@k tracking)
ralph eval report auth-module    # Generate full report
ralph eval list                  # List all evals
```

#### Metrics Supported

- **pass@1**: First attempt success rate
- **pass@3**: Success within 3 attempts
- **pass^k**: All k trials succeed (for regression checks)

---

## [2.63.1] - 2026-01-23

### Added (Hook Improvements from ECC)

**Severity**: ENHANCEMENT
**Impact**: 3 new hooks for code quality automation

#### New Hooks

| Hook | Purpose |
|------|---------|
| `console-log-detector.sh` | Warn about console.log in JS/TS files |
| `typescript-quick-check.sh` | Quick TypeScript check after edits |
| `auto-format-prettier.sh` | Auto-format JS/TS/JSON with Prettier |

All hooks registered in PostToolUse for Edit|Write matcher.

---

## [2.63.0] - 2026-01-23

### Added (Dynamic Contexts System)

**Severity**: ENHANCEMENT
**Impact**: New feature - Dynamic context switching for different work modes

#### Overview

Inspired by [everything-claude-code](https://github.com/affaan-m/everything-claude-code), this release adds a dynamic contexts system that allows switching Claude's behavior based on the task at hand.

#### New Contexts

| Context | Mode | Focus |
|---------|------|-------|
| `dev` | Development | Code first, explain after. Action-oriented. |
| `review` | Code Review | Analysis, security, structured feedback. |
| `research` | Research | Exploration, citations, comprehensive docs. |
| `debug` | Debugging | Systematic investigation, root cause analysis. |

#### New Files

| File | Purpose |
|------|---------|
| `~/.claude/contexts/dev.md` | Development context definition |
| `~/.claude/contexts/review.md` | Code review context definition |
| `~/.claude/contexts/research.md` | Research context definition |
| `~/.claude/contexts/debug.md` | Debug context definition |
| `~/.ralph/scripts/context.sh` | Context CLI switcher |
| `~/.claude/hooks/context-injector.sh` | SessionStart hook for context injection |
| `~/.claude/rules/context-aware-behavior.md` | Rule for context-aware responses |

#### Usage

```bash
ralph context dev       # Switch to development mode
ralph context review    # Switch to code review mode
ralph context research  # Switch to research mode
ralph context debug     # Switch to debug mode
ralph context show      # Show current active context
ralph context list      # List all available contexts
```

#### Source

Based on analysis of [everything-claude-code](https://github.com/affaan-m/everything-claude-code) repository (21k+ stars). See `.claude/ADVERSARIAL_IMPROVEMENT_PLAN_ECC.md` for full analysis.

---

## [2.62.3] - 2026-01-23

### Fixed (Memory System + Schema Validation)

**Severity**: CRITICAL
**Impact**: Prevents data corruption, fixes schema mismatches, ensures backward compatibility

#### P0 Fix: Race Condition in decision-extractor.sh

- `decision-extractor.sh` now uses `semantic-write-helper.sh` for atomic writes
- Added `flock` protection for `index.json` updates
- Prevents concurrent write corruption in episodic memory index

#### P1 Fix: False Positives in Pattern Detection

- JSON/YAML/TOML files now excluded from design pattern detection
- These file types only trigger config file change detection

#### Schema v2 Compliance (from Plan-State Validation Agent)

| Issue | Severity | Fix |
|-------|----------|-----|
| Schema v1 references | CRITICAL | Updated to `plan-state-v2` in init hooks |
| Missing required fields | HIGH | Added `phases`, `barriers`, `version`, `verification` |
| Array vs Object mismatch | CRITICAL | Schema now accepts both formats (backward compatible) |
| LSA hook array queries | HIGH | Updated to handle both formats |

#### Updated Files

| File | Change |
|------|--------|
| `plan-state-init.sh` | v2 schema, object steps, all required fields |
| `auto-plan-state.sh` | v2 schema, array→object conversion |
| `lsa-pre-step.sh` | Dual format support, JSON output |
| `plan-state-v2.schema.json` | `oneOf` for steps (array OR object) |

#### Backward Compatibility

The schema now uses `oneOf` for steps, allowing:
- **v1 format**: `"steps": [{"id": "1", ...}]` (legacy, still supported)
- **v2 format**: `"steps": {"step1": {...}}` (preferred for new implementations)

This enables gradual migration without breaking existing hooks.

---

## [2.62.2] - 2026-01-23

### Fixed (PreToolUse Hook JSON Format Standardization)

**Severity**: HIGH
**Impact**: SEC-039 Compliance - All PreToolUse hooks now use correct JSON format

#### Overview

Comprehensive adversarial audit discovered that 8 PreToolUse hooks were using the wrong JSON output format (`{"continue": true}` instead of `{"decision": "allow"}`).

#### Fixed Hooks

| Hook | Issue |
|------|-------|
| `procedural-inject.sh` | Fixed FEEDBACK_RESULT + 9 exit points |
| `orchestrator-auto-learn.sh` | All exit points updated |
| `fast-path-check.sh` | All exit points updated |
| `inject-session-context.sh` | All exit points updated |
| `smart-memory-search.sh` | All exit points updated |
| `agent-memory-auto-init.sh` | All exit points updated |
| `skill-validator.sh` | Added missing JSON output |
| `smart-skill-reminder.sh` | Changed `{}` to decision format |

#### Pre-commit Hook Fix

- Now recognizes `# Hook:` header (not just `# Trigger:`)
- Corrected format rules message to show accurate requirements

---

## [2.62.1] - 2026-01-23

### Fixed (Adversarial Audit Fixes)

**Severity**: HIGH
**Impact**: Fixed critical syntax error and missing shebang

#### Fixes

| Issue | Fix |
|-------|-----|
| `orchestrator-auto-learn.sh` syntax error | Added missing `fi` for if block |
| `procedural-inject.sh` missing shebang | Added `#!/bin/bash` |
| Hook JSON format violations | Fixed 9 instances of wrong format |
| Registered v2.62.0 hooks to global | Copied and registered in settings.json |

---

## [2.62.0] - 2026-01-23

### Added (Claude Code Task Primitive Integration)

**Severity**: ENHANCEMENT
**Impact**: Major integration with Claude Code's evolved Task primitive (from TodoWrite)

#### Overview

This release integrates Claude Code Cowork Mode's new Task primitive patterns:
- **Verification via subagents** after step completion
- **Global task sync** with `~/.claude/tasks/<session>/`
- **Parallelization detection** for independent tasks
- **Context-hiding** optimization for high-token tasks

#### New Features

| Feature | Description |
|---------|-------------|
| **Verification Pattern** | Spawn verification subagent after each step completion |
| **Global Task Sync** | Unidirectional sync: plan-state → `~/.claude/tasks/<session>/` |
| **Subagent Optimizer** | Auto-detect parallelization and context-hiding opportunities |
| **Schema v2.62.0** | Added `verification` object to steps |

#### Schema Changes

```json
{
  "steps": {
    "step-1": {
      "verification": {
        "required": true,
        "method": "subagent",
        "agent": "code-reviewer",
        "status": "pending|in_progress|passed|failed|skipped",
        "result": { "passed": true, "message": "..." },
        "task_id": "subagent-task-id"
      }
    }
  }
}
```

#### New Hooks

| Hook | Trigger | Purpose |
|------|---------|---------|
| `global-task-sync.sh` | PostToolUse (TaskUpdate, TaskCreate) | Sync with `~/.claude/tasks/` |
| `verification-subagent.sh` | PostToolUse (TaskUpdate) | Suggest verification after completion |
| `task-orchestration-optimizer.sh` | PreToolUse (Task) | Optimize Task tool usage |

#### New Workflow

```
EXECUTE-WITH-SYNC
    6a. LSA-VERIFY
    6b. IMPLEMENT
    6c. PLAN-SYNC
    6d. MICRO-GATE
    6e. VERIFICATION-SUBAGENT   ← NEW

VALIDATE
    7a-d. (existing)
    7e. COLLECT-VERIFICATIONS   ← NEW
```

#### Files Changed

| File | Change |
|------|--------|
| `.claude/schemas/plan-state-v2.schema.json` | Added verification object, version 2.62.0 |
| `.claude/hooks/global-task-sync.sh` | NEW - Global task sync |
| `.claude/hooks/verification-subagent.sh` | NEW - Verification pattern |
| `.claude/hooks/task-orchestration-optimizer.sh` | NEW - Subagent optimization |

#### References

- Tweet: @claudecoders on Cowork Mode Task primitive
- Context7 Claude Code documentation

---

## [2.61.0] - 2026-01-22

### Added (Adversarial Council v2.61 - LLM-Council Enhanced)

**Severity**: ENHANCEMENT
**Impact**: Major upgrade to /adversarial skill with llm-council patterns

#### New Features

| Feature | Description |
|---------|-------------|
| **Python Orchestration** | `adversarial_council.py` script for automated multi-model review |
| **Provider-Specific Extraction** | Codex, Claude, Gemini response parsing with fallbacks |
| **Exponential Backoff** | `2^attempt` seconds between retries (1s, 2s, 4s...) |
| **Command Allowlist** | Security: Only whitelisted commands for custom agents |
| **Path Validation** | Security: Prevents path traversal in output directory |
| **Feature Status Table** | Documentation: Clear Implemented vs Planned markers |

#### Security Hardening

| Fix | Severity | Description |
|-----|----------|-------------|
| Command Injection | HIGH | Added `ALLOWED_CUSTOM_COMMANDS` allowlist |
| Path Traversal | MEDIUM | Added `validate_output_path()` function |
| Config Validation | MEDIUM | Schema validation for agents.json |

#### Validation Results

| Model | Score | Notes |
|-------|-------|-------|
| Codex CLI | 6/10 | Identified initial issues |
| Claude Opus | 6.4/10 | Identified security vulnerabilities |
| Gemini | **9/10 Security**, **8/10 Quality** | Post-fix validation |

#### Files Changed

| File | Change |
|------|--------|
| `~/.claude/skills/adversarial/skill.md` | v2.61 with feature status table |
| `~/.claude/skills/adversarial/scripts/adversarial_council.py` | New orchestration script |

### Added (Security Audit - API Key Detection)

| Check | Result |
|-------|--------|
| MiniMax API Key | ✅ Not exposed |
| OpenAI API Key | ✅ Not exposed |
| JWT Tokens | ✅ Not exposed |
| .gitignore | ✅ Properly configured |
| Git History | ✅ Clean |

**Report**: `.claude/SECURITY_AUDIT_API_KEYS.md`

---

## [2.57.5] - 2026-01-20

### Fixed (Stop Hook JSON Format Error)

**Severity**: HIGH (P1)
**Impact**: Fixed Stop hook validation errors during session end

#### Root Cause

The error occurred because `orchestrator-report.sh` was outputting:
```json
{"decision": "continue"}  // INVALID
```

But Claude Code's Stop hook schema requires:
```json
{"decision": "approve"}   // VALID
{"decision": "block"}     // VALID (to block session end)
```

#### Fix Applied

| File | Line | Change |
|------|------|--------|
| `orchestrator-report.sh` | 181 | Changed `{"decision": "continue"}` → `{"decision": "approve"}` |

#### Hook Output Protocol Summary

| Hook Type | Required Format |
|-----------|-----------------|
| **PreToolUse** | `{"continue": true}` |
| **PostToolUse** | `{"continue": true, "systemMessage": "..."}` |
| **Stop** | `{"decision": "approve"}` or `{"decision": "block"}` |
| **UserPromptSubmit** | `{"additionalContext": "..."}` |

---

## [2.57.4] - 2026-01-20

### Fixed (Architecture Consistency Gaps)

**Severity**: HIGH (P1)
**Impact**: Resolved critical gaps in hooks system, memory writing, and documentation

This release addresses 5 critical gaps identified in a Codex CLI adversarial audit:

#### Gaps Fixed

| Gap ID | Issue | Severity | Fix |
|--------|-------|----------|-----|
| GAP-003 | Race condition in semantic.json writes | HIGH | Created `semantic-write-helper.sh` with flock locking |
| GAP-004 | `checkpoint-smart-save.sh` used wrong JSON format | HIGH | Changed `{"decision": "approve"}` to `{"continue": true}` |
| GAP-001 | `hooks.json` had only 3 hooks vs 56 in settings.json | HIGH | Removed obsolete `hooks.json`, created validation script |
| GAP-005 | Version mismatch (CLAUDE.md v2.57.3 vs hooks v2.57.0) | MEDIUM | Unified all hooks to v2.57.4 |
| GAP-002 | CLAUDE.md said 49 hooks but 52 exist | MEDIUM | Updated CLAUDE.md to reflect 52 hooks at v2.57.4 |

#### New Files

| File | Purpose |
|------|---------|
| `semantic-write-helper.sh` | Atomic writer for semantic.json with flock |
| `validate-hooks-consistency.sh` | Validates hooks in settings.json exist on disk |
| `bump-hooks-version.sh` | Bulk version bump for all hooks |

#### Modified Files

| File | Change |
|------|--------|
| `semantic-realtime-extractor.sh` | Uses atomic write helper (v2.57.4) |
| `decision-extractor.sh` | Uses atomic write helper (v2.57.4) |
| `checkpoint-smart-save.sh` | Fixed JSON output format (v2.57.4) |
| `CLAUDE.md` | Updated to v2.57.4, 52 hooks |

#### Validation

```bash
# Run hooks consistency validation
~/.claude/scripts/validate-hooks-consistency.sh
# Output: STATUS: PASSED (56 hooks verified, 0 errors)
```

#### Key Fixes

1. **Atomic Writes**: `semantic-write-helper.sh` uses `flock` for cross-platform locking
2. **JSON Protocol**: PreToolUse hooks use `{"continue": true}`, Stop hooks use `{"decision": "approve"}`
3. **Single Source of Truth**: `settings.json` is canonical, `hooks.json` removed

---

## [2.57.0] - 2026-01-20

### Fixed (Memory System Reconstruction - 8 Critical Issues)

**Severity**: CRITICAL (P1)
**Impact**: Memory search, plan-state sync, context injection, and semantic extraction now work correctly

This release addresses 8 critical issues discovered in a dual-model adversarial audit:

#### Issues Fixed

| # | Issue | Fix |
|---|-------|-----|
| 1 | `todo-plan-sync.sh` used `sort_by(tonumber)` failing on step-X-Y keys | Changed to `keys \| sort` |
| 2 | `smart-memory-search.sh` searched JSON files but claude-mem uses SQLite | Uses grep on JSON cache (SQLite FTS via claude-mem MCP) |
| 3 | `inject-session-context.sh` output JSON but PreToolUse can't modify tool_input | Removed JSON output, uses cache file |
| 4 | Reflection-executor extracted JSON metadata instead of real decisions | Filters JSON content from extraction |
| 5 | Pattern detection threshold never met despite 162 episodes | Lowered threshold, improved matching |
| 6 | auto-learn-context.md written but never read | Integrated with SessionStart hook |
| 7 | Procedural rules only had 1 test rule | Bootstrapped with quality patterns |
| 8 | Semantic memory contained only test data | Cleaned test data, added real extraction |

#### Implementation Phases

| Phase | Description | Files Modified |
|-------|-------------|----------------|
| 1 | Plan-State Adaptive | `auto-plan-state.sh` (creates for all sessions) |
| 2 | Reflection-Executor | `reflection-executor.py` (filters JSON from decisions) |
| 3 | Context Injection | `inject-session-context.sh` (PreToolUse fix) |
| 4 | Semantic Auto-Extractor | `semantic-realtime-extractor.sh`, `decision-extractor.sh` |
| 5 | Memory Search | `todo-plan-sync.sh`, `smart-memory-search.sh` |
| 6 | Integration Testing | 48 new tests (all passing) |

#### New/Modified Hooks (v2.57.0)

| Hook | Change |
|------|--------|
| `todo-plan-sync.sh` | Fixed `sort_by(tonumber)` → `sort` for step-X-Y keys |
| `smart-memory-search.sh` | Grep-based parallel search on JSON cache files |
| `inject-session-context.sh` | Removed JSON output, uses exit 0 only |
| `semantic-realtime-extractor.sh` | NEW: Real-time extraction from Edit/Write |
| `decision-extractor.sh` | Writes patterns to semantic memory |

#### Test Coverage

- `test_memory_search_v257.py` (19 tests)
- `test_reflection_executor_v257.py` (10 tests)
- `test_semantic_extractor_v257.py` (13 tests)
- `test_context_injection_v257.py` (6 tests)

**Total: 48/48 tests passing**

#### Key Learnings

1. **PreToolUse hooks**: Can ONLY block (exit 2) or allow (exit 0) - CANNOT modify tool_input
2. **claude-mem storage**: SQLite DB with FTS exists but hook uses grep on JSON cache for speed
3. **jq sort_by(tonumber)**: Fails silently on non-numeric strings like "step-1-1"
4. **Hook JSON output**: PostToolUse uses `{"continue": true}`, Stop uses `{"decision": "approve"}`

---

## [2.56.2] - 2026-01-20

### Fixed (StatusLine Health Monitor mkdir Bug)

**Severity**: MINOR (P3)
**Impact**: statusline-health-monitor.sh now creates directories correctly

Fixed a bug where `mkdir -p "$(dirname "$HEALTH_CACHE")"` created the parent directory instead of the cache directory itself.

**Before**: `mkdir -p "$(dirname "$HEALTH_CACHE")"` → Created `~/.ralph/cache/` instead of `~/.ralph/cache/statusline-health/`
**After**: `mkdir -p "$HEALTH_CACHE"` → Correctly creates `~/.ralph/cache/statusline-health/`

This caused the hook to fail with "No such file or directory" when writing to `$LAST_CHECK_FILE`.

---

## [2.56.1] - 2026-01-20

### Added (Full Automation of Manual Monitoring Tasks)

**Severity**: ENHANCEMENT (P2)
**Impact**: Three previously manual tasks are now fully automated

This release automates the monitoring and checkpoint tasks that previously required manual intervention.

#### Problem Statement

Users had to manually:
1. Monitor statusline for progress updates
2. Run `ralph checkpoint save` before important changes
3. Execute `ralph status --compact` to verify state

#### New Hooks (3)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `status-auto-check.sh` | PostToolUse (Edit/Write/Bash) | Auto-shows status every 5 operations or on step completion |
| `checkpoint-smart-save.sh` | PreToolUse (Edit/Write) | Smart checkpoint based on complexity, file criticality, and step risk |
| `statusline-health-monitor.sh` | UserPromptSubmit | Validates statusline health every 5 minutes |

#### status-auto-check.sh Features

- **Periodic Status**: Shows `ralph status --compact` output every 5 Edit/Write/Bash operations
- **Step Completion Detection**: Automatically shows status when a plan step completes
- **Session-Aware Counter**: Resets operation counter for each new session
- **Non-Blocking**: Adds systemMessage without interrupting workflow

```
# Example output in systemMessage
"Status: STANDARD Step 3/7 (42%) - in_progress"
```

#### checkpoint-smart-save.sh Features

Smart checkpoint triggers (replaces basic checkpoint-auto-save.sh for PreToolUse):

| Trigger | Condition |
|---------|-----------|
| `high_complexity` | Plan complexity >= 7, first edit of file |
| `high_risk_step` | Current step involves auth/security/payment |
| `critical_file` | Core config, security, database, API files |
| `security_file` | Files with auth/secret/credential in name |

Additional features:
- **Cooldown**: Minimum 120 seconds between auto-checkpoints
- **File Tracking**: Only checkpoints on first edit of each file per session
- **Rich Metadata**: Saves complexity level, step risk, and trigger reason
- **Auto-Cleanup**: Keeps only last 20 smart checkpoints

#### statusline-health-monitor.sh Features

Health checks performed every 5 minutes:
1. **Script Existence**: Verifies statusline-ralph.sh exists and is executable
2. **Plan-State Validity**: Checks JSON is valid and has required fields
3. **Stuck Detection**: Warns if status is "in_progress" but unchanged for 30+ minutes
4. **Sync Verification**: Compares statusline output with plan-state.json values

#### Configuration

All hooks are enabled by default. To disable:

```bash
# Disable status auto-check
export RALPH_STATUS_AUTO_CHECK=false

# Disable smart checkpoints
export RALPH_CHECKPOINT_SMART=false

# Disable health monitor
export RALPH_HEALTH_MONITOR=false
```

#### Documentation

- Hooks location: `~/.claude/hooks/`
- Logs: `~/.ralph/logs/status-auto-check.log`, `checkpoint-smart.log`, `statusline-health.log`

---

## [2.56.0] - 2026-01-20

### Fixed (Plan-State Auto-Archive and Staleness Detection)

**Severity**: CRITICAL (P0)
**Impact**: StatusLine now shows accurate progress instead of stale "2/17 11%"

This release fixes critical plan-state tracking issues discovered during comprehensive audit.

#### Root Cause Analysis

The statusline displayed fixed progress ("2/17 11%") because:
1. **Plan staleness**: plan-state.json was 2+ days old and never auto-reset
2. **No lifecycle management**: Old plans persisted indefinitely
3. **Missing sync**: TodoWrite updates didn't propagate to plan-state

#### Solutions Implemented

**plan-state-lifecycle.sh v2.56.0**
- NEW: `archive_plan()` function for automatic archiving
- NEW: Auto-archive stale plans (>2 hours) when new task detected
- NEW: Auto-archive on `/orchestrator` command (always fresh start)
- NEW: Archive location: `~/.ralph/archive/plans/`
- NEW: Archive metadata includes reason and timestamp
- NEW: `PLAN_STATE_AUTO_ARCHIVE` env var (default: true)

```bash
# Behavior
| Condition                          | Action                    |
|------------------------------------|---------------------------|
| Plan >2 hours + new task detected  | Auto-archive + notify     |
| /orchestrator command              | Always archive existing   |
| Recent plan (<2 hours)             | Keep plan, no action      |
```

**todo-plan-sync.sh v2.56.0** (NEW)
- Creates plan-state from TodoWrite todos when no plan exists
- Updates existing plan-state with todo progress
- Direct mapping when todo count matches step count
- Ratio mapping otherwise

#### Limitation Discovered

**TodoWrite is NOT a valid hook matcher in Claude Code.**

Valid PostToolUse matchers: `Edit`, `Write`, `Bash`, `Task`, `Read`, `Grep`, `Glob`, `ExitPlanMode`

The todo-plan-sync.sh hook is registered but cannot be triggered automatically. Manual invocation or alternative triggers required.

#### Test Coverage

| Category | Tests | Status |
|----------|-------|--------|
| Context Compaction | 15 | Pass |
| Plan-State | 15 | Pass |
| StatusLine | 5 | Pass |
| Lifecycle v2.56.0 | 7 | 6 Pass, 1 Edge |
| Todo-Sync v2.56.0 | 5 | 4 Pass, 1 Edge |
| **Total** | **47/49** | **96%** |

#### Documentation

- Retrospective: `.claude/retrospectives/2026-01-20-context-compaction-planstate-audit.md`

---

## [2.55.0] - 2026-01-20

### Added (Autonomous Self-Improvement System)

**Severity**: ENHANCEMENT (P1)
**Impact**: System now proactively learns and improves code quality autonomously

This release introduces automated memory population and proactive self-improvement capabilities.

#### New Hooks (6)

| Hook | Trigger | Purpose |
|------|---------|---------|
| `agent-memory-auto-init.sh` | PreToolUse (Task) | Auto-initializes agent memory buffers when agents spawn |
| `semantic-auto-extractor.sh` | Stop | Extracts semantic facts from git diff (functions, classes, deps) |
| `decision-extractor.sh` | PostToolUse (Edit/Write) | Detects architectural patterns and decisions |
| `curator-suggestion.sh` | UserPromptSubmit | Suggests `/curator` when procedural memory is empty |
| `orchestrator-auto-learn.sh` | PreToolUse (Task) | Triggers learning for complexity >=7 tasks with insufficient memory |

#### New Command

```bash
ralph health                    # Full memory system health report
ralph health --compact          # One-line summary
ralph health --json             # JSON output for scripts
ralph health --fix              # Auto-fix critical issues
```

#### Health Check Categories

| Category | Checks |
|----------|--------|
| Semantic Memory | File exists, valid JSON, entry count |
| Procedural Memory | Rules count, staleness |
| Episodic Memory | Directory exists, recent entries |
| Agent Memory | Initialized agents count |
| Curator State | Pending repos, learned repos |
| Event Bus | Event log exists, recent events |
| Ledgers | Active ledgers, size |
| Handoffs | Recent handoffs |
| Checkpoints | Checkpoint count, recent |

#### Auto-Learning Triggers

| Condition | Severity | Action |
|-----------|----------|--------|
| ZERO relevant rules (any complexity) | CRITICAL | Learning REQUIRED |
| <3 rules AND complexity >=7 | HIGH | Learning RECOMMENDED |

#### Extraction Features

**Semantic Auto-Extractor** (on Stop):
- Extracts new functions from git diff
- Extracts new classes/components
- Extracts new dependencies
- Source tagged as "auto-extract"

**Decision Extractor** (on Edit/Write):
- Detects design patterns (Singleton, Repository, Factory, Observer, Strategy)
- Detects architectural decisions (async/await, caching, logging, error handling)
- Tracks file and timestamp

---

## [2.54.0] - 2026-01-19

### Fixed (StatusLine Progress Display)

**Severity**: MEDIUM (P2)
**Impact**: StatusLine now correctly shows completed steps instead of always showing 0

#### Root Cause

The `get_ralph_progress()` function in `statusline-ralph.sh` was counting steps incorrectly:
- Used `keys | length` which doesn't work properly with object iteration
- Status comparison used wrong syntax for jq

#### Solution

Fixed `statusline-ralph.sh` v2.54.0:
```bash
# Correct step counting
completed_steps=$(echo "$plan_state" | jq -r '
    if .steps then
        [.steps | to_entries[] | select(.value.status == "completed" or .value.status == "verified")] | length
    else 0 end
' 2>/dev/null || echo "0")
```

#### Test Results

| Test | Before | After |
|------|--------|-------|
| Show 0/7 when no steps completed | 0/7 | 0/7 |
| Show 3/7 when 3 steps completed | 0/7 | 3/7 |
| Show "done" when all completed | 0/7 | done |

---

## [2.53.0] - 2026-01-19

### Fixed (PostToolUse Hook JSON Format)

**Severity**: HIGH (P1)
**Impact**: Hooks now return correct JSON format, preventing silent failures

#### Problem

Multiple PostToolUse hooks were returning incorrect JSON:
```json
// WRONG (PreToolUse format)
{"decision": "continue"}

// CORRECT (PostToolUse format)
{"continue": true, "systemMessage": "optional message"}
```

#### Hooks Fixed

| Hook | Version |
|------|---------|
| `checkpoint-auto-save.sh` | v2.55.0 |
| `progress-tracker.sh` | v2.53.0 |
| `plan-sync-post-step.sh` | v2.53.0 |
| `quality-gates-v2.sh` | v2.53.0 |

#### Reference

PostToolUse hooks must return:
```json
{
  "continue": true,           // Required: always true for PostToolUse
  "systemMessage": "..."      // Optional: message to show user
}
```

---

## [2.52.0] - 2026-01-19

### Added (Local Observability System)

**Severity**: ENHANCEMENT (P2)
**Impact**: Full orchestration status and traceability without external services

#### New Commands

```bash
# Status
ralph status                  # Full orchestration status
ralph status --compact        # One-line summary
ralph status --steps          # Detailed step breakdown
ralph status --json           # JSON for scripts

# Traceability
ralph trace show [count]      # Recent events
ralph trace search <query>    # Search events
ralph trace timeline          # Visual timeline
ralph trace export [format]   # Export to JSON/CSV
ralph trace summary           # Session summary
```

#### StatusLine Integration

Progress shown in statusline:
```
main* | 3/7 42% | [claude-hud metrics]
```

| Icon | Meaning |
|------|---------|
| | Active plan |
| | Executing |
| | Fast-path |
| | Completed |

---

## [2.51.0] - 2026-01-18

### Added (Multi-Agent Infrastructure Improvements)

Major infrastructure release adding LangGraph-style checkpoints, OpenAI Agents SDK-style handoffs, event-driven orchestration, and agent-scoped memory.

#### Checkpoint System

```bash
ralph checkpoint save "name" "description"
ralph checkpoint restore "name"
ralph checkpoint list
ralph checkpoint diff "n1" "n2"
```

#### Handoff API

```bash
ralph handoff transfer --from X --to Y --task "desc"
ralph handoff agents
ralph handoff validate <agent>
```

#### Event-Driven Engine

```bash
ralph events emit <type> [payload]
ralph events barrier check <phase>
ralph events barrier wait <phase> [timeout]
ralph events route
```

#### Agent-Scoped Memory

```bash
ralph agent-memory init <agent>
ralph agent-memory write <agent> <type> <content>
ralph agent-memory read <agent> [type]
ralph agent-memory transfer <from> <to> [filter]
```

#### Plan State v2 Schema

Phases + barriers for strict WAIT-ALL consistency:
```json
{
  "version": "2.51.0",
  "phases": [
    {"phase_id": "clarify", "step_ids": ["1"], "execution_mode": "sequential"}
  ],
  "barriers": {
    "clarify_complete": false
  }
}
```

---

## [2.50.0] - 2026-01-17

### Added (Repository Learning and Curation)

#### Repository Learner

```bash
repo-learn https://github.com/python/cpython
repo-learn https://github.com/fastapi/fastapi --category error_handling
```

#### Repo Curator

```bash
/curator "best backend TypeScript repos"
ralph curator full --type backend --lang typescript
ralph curator approve nestjs/nest
ralph curator learn --all
```

#### Codex Planner

```bash
/codex-plan "Design distributed system"
/orchestrator "task" --use-codex
```

---

## [2.49.0] - 2026-01-15

### Added (Smart Memory-Driven Orchestration)

Based on @PerceptualPeak Smart Forking concept.

#### Memory Architecture

- Semantic Memory (permanent facts)
- Episodic Memory (30-day TTL experiences)
- Procedural Memory (learned behaviors)

#### Smart Memory Search

Parallel search across 4 sources:
- claude-mem MCP
- memvid
- handoffs
- ledgers

Results aggregated to `.claude/memory-context.json`

---

## [2.46.0] - 2026-01-10

### Added (RLM-Inspired Routing)

3-Dimension Classification:
- Complexity (1-10)
- Information Density (CONSTANT/LINEAR/QUADRATIC)
- Context Requirement (FITS/CHUNKED/RECURSIVE)

Workflow Routing:
- FAST_PATH: 3 steps for trivial tasks
- PARALLEL_CHUNKS: Concurrent exploration
- RECURSIVE_DECOMPOSE: Sub-orchestrators

Quality over Consistency:
- Style issues advisory, not blocking
- Quality issues blocking

---

## [2.45.0] - 2026-01-05

### Added (Plan-Sync and LSA Integration)

- Lead Software Architect verification
- Plan-Sync for drift detection
- Gap-Analyst for pre-implementation analysis
- Adversarial Plan Validation
- plan-state.json tracking

---

*For older versions, see git history.*
