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

### HIGH-002: Node.js Cross-Platform Hooks (P3)

**Created**: 2026-01-23 (v2.66.8 release)
**Status**: Open - Feature Not Implemented
**Effort**: High (8-16 hours)

**Problem**:
Node.js hook library was planned but directory doesn't exist.

**Proposed Location**: `~/.claude/hooks/node/`

**Purpose**:
- Better Windows compatibility
- Type-safe hook implementations
- Async/await support for complex hooks
- Shared utilities across hooks

**When to Implement**:
- When Windows support is needed
- When hooks become complex enough to benefit from TypeScript
- When async operations in hooks become common

---

## Completed Items

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
