# Technical Debt Tracking

> This file tracks known technical debt items for future remediation.
> Each session should check this file and address items when appropriate.

---

## Priority Legend

| Priority | Description | Action |
|----------|-------------|--------|
| P0 | Critical - Fix immediately | Block release |
| P1 | High - Fix soon | Next sprint |
| P2 | Medium - Plan for later | Backlog |
| P3 | Low - Nice to have | When convenient |

---

## Open Items

### DUP-002: JSON Output Helper Duplication (P2)

**Created**: 2026-01-23 (v2.66.8 release)
**Status**: Open
**Effort**: Medium (2-4 hours)

**Problem**:
30+ hooks duplicate the `output_json()` pattern:

```bash
output_json() {
    echo '{"continue": true}'  # or {"decision": "allow"}
}
trap 'output_json' ERR
```

**Files Affected**:
- `~/.claude/hooks/procedural-inject.sh`
- `~/.claude/hooks/semantic-auto-extractor.sh`
- `~/.claude/hooks/auto-save-context.sh`
- `~/.claude/hooks/orchestrator-auto-learn.sh`
- `~/.claude/hooks/inject-session-context.sh`
- `~/.claude/hooks/curator-suggestion.sh`
- ... and 25+ more hooks

**Proposed Solution**:

1. Create shared library `~/.ralph/lib/hook-json-output.sh`:
   ```bash
   #!/bin/bash
   # Shared JSON output helpers for hooks

   # PreToolUse/PreCompact format
   output_allow() { echo '{"decision": "allow"}'; }
   output_block() { echo "{\"decision\": \"block\", \"reason\": \"$1\"}"; }

   # PostToolUse format
   output_continue() { echo '{"continue": true}'; }
   output_continue_msg() { echo "{\"continue\": true, \"systemMessage\": \"$1\"}"; }

   # Stop format
   output_approve() { echo '{"decision": "approve"}'; }

   # UserPromptSubmit format
   output_empty() { echo '{}'; }
   ```

2. Update all hooks to source the library:
   ```bash
   source "${HOME}/.ralph/lib/hook-json-output.sh" 2>/dev/null || {
       # Fallback if library not found
       output_allow() { echo '{"decision": "allow"}'; }
   }
   trap 'output_allow' ERR
   ```

**Why Deferred**:
- No functional impact (all hooks work correctly)
- Requires updating 30+ files
- Risk of introducing regressions during refactor
- Each hook has different JSON format needs

**When to Fix**:
- During a dedicated refactoring sprint
- Before adding more hooks to the system
- If a bug is found in multiple output_json implementations

---

### HIGH-002: Node.js Cross-Platform Hooks - Registration Pending (P3)

**Created**: 2026-01-23 (v2.66.8 release)
**Updated**: 2026-01-24 (v2.68.2 - files exist, registration deferred)
**Status**: Open - Deferred by Design
**Effort**: Low (1-2 hours to register)

**Current State**:
Node.js hook infrastructure **EXISTS** but is not registered:
- `~/.claude/hooks/node/context-injector.js` - SessionStart hook (cross-platform alternative)
- `~/.claude/hooks/lib/cross-platform.js` - Shared utilities library

**Why Deferred**:
- Bash hooks work on macOS/Linux (current user base)
- Node.js alternatives are for future Windows support
- No current demand for cross-platform hooks
- Risk of maintaining parallel implementations

**When to Register**:
- When Windows user requests support
- When complex async operations need Node.js
- When TypeScript type safety becomes valuable for hooks

---

### GAP-HIGH-001: Missing Tests for v2.61-v2.65 Features (P2)

**Created**: 2026-01-24 (v2.68.2 gap analysis)
**Status**: Open - Feature Not Implemented
**Effort**: High (8-16 hours)

**Missing Test Coverage**:
| Version | Feature | Test File Needed |
|---------|---------|------------------|
| v2.61 | Adversarial Council | `test_v261_adversarial_council.bats` |
| v2.63 | Dynamic Contexts | `test_v263_dynamic_contexts.bats` |
| v2.64 | EDD Framework | `test_v264_edd_framework.bats` |
| v2.65 | Cross-Platform Hooks | `test_v265_cross_platform.bats` |

**Existing Coverage**:
- `test_v268_auto_invoke_hooks.bats` (58 tests)
- `test_v256_task_primitives.bats`

**When to Implement**:
- During dedicated testing sprint
- Before major release milestones
- When regressions occur in untested features

---

### GAP-HIGH-005: EDD (Eval-Driven Development) Skill Not Implemented (DONE)

**Created**: 2026-01-24 (v2.68.2 gap analysis)
**Completed**: 2026-01-24 (v2.68.9 adversarial validation Phase 6)
**Status**: DONE

**Solution**:
- Created `~/.claude/skills/edd/skill.md` with workflow documentation
- Created `~/.claude/evals/TEMPLATE.md` with definition template
- Script `~/.ralph/scripts/edd.sh` was already functional (v1.0.0)

---

### HIGH-002: inject-session-context.sh Builds Unused Context (DONE)

**Created**: 2026-01-24 (v2.68.9 adversarial audit)
**Completed**: 2026-01-24 (v2.68.10 adversarial validation)
**Status**: DONE

**Solution**: Removed 43 lines of dead code that built context but never used it.
PreToolUse hooks can only return `{"decision": "allow/block"}`, they CANNOT inject context.

---

### HIGH-003: smart-memory-search.sh Documentation Mismatch (DONE)

**Created**: 2026-01-24 (v2.68.9 adversarial audit)
**Completed**: 2026-01-24 (v2.68.10 adversarial validation)
**Status**: DONE

**Solution**: Corrected CHANGELOG v2.57.0 documentation to accurately describe:
- Hook uses grep-based search on JSON cache files
- SQLite FTS database exists but is queried via claude-mem MCP, not the hook

---

### SEC-105: Race Condition in Checkpoint File Operations (DONE)

**Created**: 2026-01-24 (v2.68.9 security audit)
**Completed**: 2026-01-24 (v2.68.10 adversarial validation)
**Status**: DONE

**Solution**: Implemented atomic noclobber (O_EXCL) pattern:
```bash
(set -C; echo "$$" > "$EDITED_FLAG") 2>/dev/null || exit 0
```
This eliminates the TOCTOU gap - single syscall for check+create.

---

### SEC-110: Sensitive Data in Log Files (DONE)

**Created**: 2026-01-24 (v2.68.9 security audit)
**Completed**: 2026-01-24 (v2.68.10 adversarial validation)
**Status**: DONE

**Problem**: User prompts logged without redaction could expose API keys, tokens.

**Solution**: Added `redact_sensitive()` function to:
- `memory-write-trigger.sh` - Redacts user prompt excerpt before logging
- `orchestrator-auto-learn.sh` - Redacts learning output before logging

**Pattern applied**:
```bash
redact_sensitive() {
    local str="$1"
    str=$(echo "$str" | sed -E 's/(sk-|pk-|api_|key_|token_|secret_)[a-zA-Z0-9_-]{10,}/\1[REDACTED]/gi')
    str=$(echo "$str" | sed -E 's/[a-zA-Z0-9_-]{32,}/[REDACTED]/g')
    echo "$str"
}
```

---

### SEC-109: Missing Error Traps (FALSE POSITIVE)

**Created**: 2026-01-24 (v2.68.9 security audit)
**Updated**: 2026-01-24 (v2.68.11 - Verified as FALSE POSITIVE)
**Status**: FALSE POSITIVE

**Analysis**:
All 10 identified hooks were verified:
- 5 SessionStart hooks: Don't require JSON output per v2.62.3 spec
- 3 UserPromptSubmit hooks: Already have proper error traps
- 2 utility scripts: Not registered hooks (plan-state-init.sh, semantic-write-helper.sh)

---

### SEC-111: Input Length Validation (DONE)

**Created**: 2026-01-24 (v2.68.9 security audit)
**Completed**: 2026-01-24 (v2.68.11 adversarial validation)
**Status**: DONE

**Solution**: Added MAX_INPUT_LEN=100000 validation to 3 hooks:
- `curator-suggestion.sh` - Early exit if prompt too long
- `memory-write-trigger.sh` - Early exit if prompt too long
- `plan-state-lifecycle.sh` - Truncates long prompts with warning

---

### SEC-108, SEC-116: Remaining Low Priority Issues (P3)

**Created**: 2026-01-24 (v2.68.9 security audit)
**Updated**: 2026-01-24 (v2.68.11 - SEC-109/111 resolved)
**Status**: Open - Low Priority
**Effort**: Low (1-2 hours total)

| ID | Issue | Impact | Status |
|----|-------|--------|--------|
| SEC-108 | Unquoted variables in bash conditions | Word splitting | Cosmetic (all numeric) |
| SEC-116 | Missing umask 077 in 30 hooks | Permission issues | Nice to have |

**FALSE POSITIVES (verified)**:
- SEC-109: All hooks that need traps have them (SessionStart doesn't need JSON)
- SEC-112: All hooks use `mktemp` correctly with random suffixes
- SEC-113: jq handles content-type properly
- SEC-114: All loops have proper bounds (50-iter limit)
- SEC-115: No dangerous glob patterns found

**When to Fix**:
- During dedicated security hardening sprint (cosmetic only)

---

### LOW-001 to LOW-005: Minor Security Hardening (P3)

**Created**: 2026-01-24 (v2.68.4 gap analysis)
**Status**: Open - Low Priority
**Effort**: Low (1-2 hours total)

**Issues Identified by Security Auditor**:
| ID | Hook | Issue | Impact |
|----|------|-------|--------|
| LOW-001 | `skill-validator.sh` | Subprocess sourcing pollution | Minimal |
| LOW-002 | `repo-boundary-guard.sh` | Regex injection in grep | Minimal |
| LOW-003 | `decision-extractor.sh` | ReDoS potential on large files | Minimal |
| LOW-004 | `curator-suggestion.sh` | Unbounded find on corpus | Minimal |
| LOW-005 | `checkpoint-smart-save.sh` | Unbounded deletion via xargs | Minimal |

**When to Fix**:
- During dedicated security hardening sprint
- When performance issues are reported
- During v2.70+ development

---

## Completed Items (v2.68.7)

### GAP-HIGH-006: 20+ Hooks at Pre-v2.66 Versions (DONE)

**Created**: 2026-01-24 (v2.68.4 gap analysis)
**Completed**: 2026-01-24 (v2.68.6)
**Solution**: Version Consistency Audit achieved 100% compliance (67/67 hooks at v2.66+)

**Resolution**:
- v2.68.6: Updated 11 hooks with version bumps
- Hooks updated: procedural-inject.sh, sec-context-validate.sh, context-injector.sh, usage-consolidate.sh, auto-format-prettier.sh, console-log-detector.sh, project-backup-metadata.sh, smart-skill-reminder.sh, task-primitive-sync.sh, task-project-tracker.sh, typescript-quick-check.sh

---

## Completed Items (v2.68.4)

### GAP-CRIT-001: Dead Code sync_from_global() (DONE)

**Completed**: 2026-01-24 (v2.68.4)
**Solution**: Synced `global-task-sync.sh` from global (already had DEAD-001 removed in v2.66.6)

### GAP-CRIT-002: git-safety-guard.py Version Mismatch (DONE)

**Completed**: 2026-01-24 (v2.68.4)
**Solution**: Synced from global (v2.43.0 → v2.66.8, 23 version updates)

### MED-006: Command Injection in parallel-explore.sh (DONE)

**Completed**: 2026-01-24 (v2.68.4)
**Solution**: Removed spaces from sanitizer whitelist, added length limit

### MED-008: macOS-Specific stat in ai-code-audit.sh (DONE)

**Completed**: 2026-01-24 (v2.68.4)
**Solution**: Added OSTYPE detection for portable stat usage

---

## Previously Completed

### RACE-001: Checkpoint Race Condition (DONE)

**Completed**: 2026-01-23 (v2.66.5)
**Solution**: Atomic mkdir locking in `checkpoint-smart-save.sh`

### SEC-052: TOCTOU Race in Checkpoints (DONE)

**Completed**: 2026-01-23 (v2.66.8 - verified already fixed)
**Solution**: RACE-001 fix already covered this

---

## Session Reminder

When starting a new session, check this file:

```bash
# Quick check for open debt items
grep -A 3 "Status: Open" ~/.claude/TECHNICAL_DEBT.md
```

Or in Claude:
```
Read the technical debt file and summarize open items
```
