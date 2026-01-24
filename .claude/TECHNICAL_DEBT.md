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

### GAP-CRIT-010: 6 Documented Commands Need Full Implementation (DONE)

**Created**: 2026-01-24 (v2.68.18 exhaustive audit)
**Completed**: 2026-01-24 (v2.68.22 technical debt cleanup)
**Status**: DONE

**Original Problem**:
CLAUDE.md documented 7 commands that returned "Unknown command".

**Solution (v2.68.22)**:
All 7 commands now fully implemented:
| Command | Script | Features |
|---------|--------|----------|
| `ralph context` | `context.sh` | dev/review/research/debug modes |
| `ralph checkpoint` | `checkpoint.sh` | save/restore/list/show/diff |
| `ralph handoff` | `handoff.sh` | transfer/agents/validate/history |
| `ralph events` | `events.sh` | emit/subscribe/barrier/route/advance |
| `ralph agent-memory` | `agent-memory.sh` | init/read/write/transfer/list/gc |
| `ralph migrate` | `migrate.sh` | check/run/dry-run |
| `ralph ledger` | `ledger.sh` | save/load/list/show |

**Files Created** (v2.68.22):
- `~/.ralph/scripts/checkpoint.sh` (251 lines)
- `~/.ralph/scripts/handoff.sh` (265 lines)
- `~/.ralph/scripts/events.sh` (290 lines)
- `~/.ralph/scripts/agent-memory.sh` (310 lines)
- `~/.ralph/scripts/migrate.sh` (153 lines)
- `~/.ralph/scripts/ledger.sh` (154 lines)

**Total**: ~1,423 lines of CLI implementation

---

### DUP-002: JSON Output Helper Duplication (PARTIAL)

**Created**: 2026-01-23 (v2.66.8 release)
**Updated**: 2026-01-24 (v2.68.22 - Library created)
**Status**: PARTIAL - Library created, migration deferred
**Effort**: Medium (2-4 hours for full migration)

**Progress (v2.68.22)**:
✅ **Library Created**: `~/.ralph/lib/hook-json-output.sh`
- Type-safe functions for each hook event type
- `output_allow/block` → PreToolUse
- `output_continue/msg` → PostToolUse
- `output_approve` → Stop
- `output_empty/context` → UserPromptSubmit
- `trap_*` helpers for error trap setup

⏸️ **Migration Deferred**:
32 existing hooks still use inline `output_json()`:
- 19 PostToolUse hooks
- 5 PreToolUse hooks
- 3 Stop hooks
- 5 UserPromptSubmit hooks (3 with custom logic)

**Why Migration Deferred**:
- All hooks work correctly (no functional impact)
- High regression risk from mass-refactoring 32 hooks
- Some hooks have custom output_json logic
- Library available for new hooks

**Usage for New Hooks**:
```bash
source "${HOME}/.ralph/lib/hook-json-output.sh"
trap_continue  # For PostToolUse hooks

# ... hook logic ...

trap_clear
output_continue_msg "Hook completed successfully"
```

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

### GAP-HIGH-001: Missing Tests for v2.61-v2.65 Features (DONE)

**Created**: 2026-01-24 (v2.68.2 gap analysis)
**Completed**: 2026-01-24 (v2.68.13 - All tests created and passing)
**Status**: DONE

**Test Coverage Implemented**:
| Version | Feature | Test File | Tests |
|---------|---------|-----------|-------|
| v2.61 | Adversarial Council | `test_v261_adversarial_council.bats` | 20 ✅ |
| v2.63 | Dynamic Contexts | `test_v263_dynamic_contexts.bats` | 29 ✅ |
| v2.64 | EDD Framework | `test_v264_edd_framework.bats` | 33 ✅ |
| v2.65 | Cross-Platform Hooks | `test_v265_cross_platform_hooks.bats` | 26 ✅ |

**Total Coverage**: 903 tests, all passing (verified 2026-01-24)

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

### SEC-108: Unquoted Variables (FALSE POSITIVE)

**Created**: 2026-01-24 (v2.68.9 security audit)
**Updated**: 2026-01-24 (v2.68.11 adversarial validation)
**Status**: FALSE POSITIVE - Closed

**Analysis** (verified by Security Auditor v2.68.11):
- Both instances are in numeric contexts (arithmetic `$(())` or array length `${#arr[@]}`)
- Word splitting is **impossible** in these contexts
- Example: `if [ $((COUNT % INTERVAL)) -eq 0 ]` - result is always numeric

---

### SEC-029: Session ID Path Traversal (DONE)

**Created**: 2026-01-24 (v2.68.20 adversarial audit)
**Completed**: 2026-01-24 (v2.68.20 adversarial validation)
**Status**: DONE

**Problem**: Multiple hooks extracted `session_id` from input and used it in file paths without sanitization, enabling potential path traversal attacks.

**Hooks Fixed (v2.68.20)**:
| Hook | Risk | Fix Applied |
|------|------|-------------|
| `continuous-learning.sh` | File path construction | `tr -cd 'a-zA-Z0-9_-' \| head -c 64` |
| `pre-compact-handoff.sh` | Directory creation | `tr -cd 'a-zA-Z0-9_-' \| head -c 64` |
| `task-project-tracker.sh` | Directory access | `tr -cd 'a-zA-Z0-9_-' \| head -c 64` |

**Already Sanitized**:
- `global-task-sync.sh` - Had SEC-001 sanitization
- `reflection-engine.sh` - Had sanitization

**Not Vulnerable** (session_id used only for logging/JSON):
- `progress-tracker.sh`, `smart-memory-search.sh`, `semantic-auto-extractor.sh`
- `inject-session-context.sh`, `session-start-ledger.sh`, `session-start-welcome.sh`
- `fast-path-check.sh`, `quality-gates-v2.sh`, `parallel-explore.sh`
- `orchestrator-report.sh` (generates own timestamp-based ID)

---

### SEC-116: Missing umask 077 (DONE)

**Created**: 2026-01-24 (v2.68.9 security audit)
**Completed**: 2026-01-24 (v2.68.22 technical debt cleanup)
**Status**: DONE

**Solution**: Added `umask 077` to all 31 hooks that were missing it.
Now 66/66 hooks have restrictive file permissions (defense-in-depth).

**Files Updated** (v2.68.22):
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

---

### FALSE POSITIVES Summary (v2.68.11 Verified)

| ID | Claimed Issue | Why FALSE POSITIVE |
|----|---------------|-------------------|
| SEC-108 | Unquoted variables | Variables in numeric contexts (arithmetic/array length) |
| SEC-109 | Missing error traps | SessionStart hooks don't need JSON, others have traps |
| SEC-112 | Insecure temp files | All hooks use `mktemp` correctly |
| SEC-113 | jq content-type issues | jq handles content properly |
| SEC-114 | Unbounded loops | All loops have 50-iter bounds |
| SEC-115 | Dangerous glob patterns | No `rm *` patterns found |
| LOW-001 | Subprocess sourcing | Runs in isolated subprocess with timeout |
| LOW-002 | Regex injection | GITHUB_DIR is script-controlled, not user input |
| LOW-003 | ReDoS potential | Patterns are simple, content bounded at 50 chars |
| LOW-005 | Unbounded deletion | Bounded by MAX_SMART_CHECKPOINTS=20 |

---

### LOW-004: Unbounded find (DONE)

**Created**: 2026-01-24 (v2.68.4 gap analysis)
**Completed**: 2026-01-24 (v2.68.21 technical debt cleanup)
**Status**: DONE

**Solution**: Added `-maxdepth 2` to find command in `curator-suggestion.sh`:
```bash
CORPUS_COUNT=$(find "$CORPUS_DIR" -maxdepth 2 -type f -name "*.json" 2>/dev/null | wc -l | tr -d ' ')
```

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
