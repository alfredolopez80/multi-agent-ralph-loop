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

### GAP-HIGH-005: EDD (Eval-Driven Development) Skill Not Implemented (P3)

**Created**: 2026-01-24 (v2.68.2 gap analysis)
**Status**: Open - Feature Not Implemented
**Effort**: High (16-24 hours)

**Problem**:
EDD skill referenced in documentation but infrastructure not created:
- `~/.claude/skills/edd/` - Directory not found
- `~/.claude/evals/` - Directory not found

**Purpose**:
Eval-Driven Development framework for:
- Defining success criteria as evaluations
- Running evals before/after implementation
- Tracking eval pass rates over time

**When to Implement**:
- When eval-driven workflow is prioritized
- When team requests structured validation framework
- During v2.70+ feature development

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

### GAP-HIGH-006: 20+ Hooks at Pre-v2.66 Versions (P2)

**Created**: 2026-01-24 (v2.68.4 gap analysis)
**Status**: Open - Version Drift
**Effort**: Medium (2-4 hours)

**Problem**:
20+ hooks remain at v2.57.5 while system is at v2.68.4. Missing 11 versions of security fixes and improvements.

**Affected Hooks** (sample):
- `agent-memory-auto-init.sh` (v2.57.5)
- `auto-save-context.sh` (v2.57.5)
- `context-warning.sh` (v2.57.5)
- `fast-path-check.sh` (v2.57.5)
- `quality-gates.sh` (v2.57.5)
- ... and 15+ more

**Why Deferred**:
- No functional regressions reported
- Version number is documentation, not behavior
- Risk of regression during mass update

**When to Fix**:
- During version synchronization sprint
- When specific hook needs update for new feature

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
