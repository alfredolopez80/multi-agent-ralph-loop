# Rollback v2.79.0 → v2.78.5 - Context Monitoring System

**Date**: 2026-01-28
**Action**: ROLLBACK
**Status**: ✅ COMPLETED
**Previous Version**: v2.79.0 (simplification) → v2.78.10 (validation fallback) → v2.78.6 (project-specific cache)
**Target Version**: v2.78.5 (cumulative tokens)

---

## Executive Summary

Rolled back the context monitoring system from v2.79.0 to v2.78.5 due to fundamental architectural issues with the `context-from-cli.sh` approach that did not properly differentiate projects by `context-project-id`.

---

## Problem Statement

### Root Issues

1. **`/context` command is REPL-only**: The `context-from-cli.sh` hook attempted to call `/context` from bash, but this command is **internal to Claude Code CLI** and cannot be executed from external bash scripts.

2. **No project-specific differentiation**: The system was not using `context-project-id` correctly to maintain separate context tracking per project, leading to unified/generic cache instead of project-specific data.

3. **Invalid approach**: The entire premise of calling `/context` from a UserPromptSubmit hook was flawed because:
   - `/context` is not a CLI command
   - It cannot be executed from bash
   - It must be read from **stdin JSON** provided by Claude Code CLI

---

## Files Removed

| File | Purpose | Reason |
|------|---------|--------|
| `.claude/hooks/context-from-cli.sh` | Hook to call `/context` command | Cannot work - `/context` is REPL-only |
| `.claude/hooks/statusline-context-cache-update.sh` | Cache update hook | Part of invalid approach |
| `.claude/hooks/context-cache-updater.sh` | Cache updater hook | Part of invalid approach |
| `docs/context-monitoring/CONTEXT_FROM_CLI_FIX.md` | Documentation | Documents invalid approach |

---

## Files Restored

| File | From | To | Commit Reference |
|------|------|-----|------------------|
| `.claude/scripts/statusline-ralph.sh` | v2.79.0 | v2.78.5 | `201bc44` (pre-2553e99) |

**Backup created**: `.claude/scripts/statusline-ralph.sh.backup_v2.79.0`

---

## Documentation Marked as Obsolete

| File | Status | Note |
|------|--------|------|
| `STATUSLINE_V2.78.10_FIX.md` | ⚠️ OBSOLETE | Describes reverted validation/fallback approach |
| `STATUSLINE_V2.78_IMPLEMENTATION.md` | ⚠️ OBSOLETE | Describes reverted project-specific cache approach |

---

## Current State (v2.78.5)

### Behavior

- **Progress bar**: Shows cumulative session tokens (can exceed 100%)
- **Current context**: Uses cumulative tokens as best available approximation
- **Display format**: `🤖 ██████████░░ 391k/200k (195%)`

### Limitations

- Shows SESSION ACCUMULATED tokens, not CURRENT WINDOW usage
- To see actual current window usage, run `/context` command manually
- No project-specific differentiation in statusline

---

## Future Strategy (TBD)

### Requirements

1. **Read from stdin JSON**: The `/context` information must be extracted from the stdin JSON that Claude Code CLI provides, NOT from calling `/context` as an external command.

2. **Project-specific tracking**: Use `context-project-id` or similar mechanism to differentiate between projects and maintain separate context caches.

3. **Validate available fields**: Determine which fields in the stdin JSON actually contain reliable context usage data.

### Open Questions

- What exact fields are available in stdin JSON for context tracking?
- How to extract project ID from stdin JSON?
- What is the correct `context-project-id` field name?

---

## Commits Reverted

| Commit | Title | Date |
|--------|-------|------|
| `154f09d` | feat: statusline simplification v2.79.0 | 2026-01-28 |
| `6f54b2e` | fix: statusline v2.78.10 - correct context display with validation and cache fallback | 2026-01-28 |
| `2553e99` | feat: context-from-cli hook v1.0.0 - workaround for Zai wrapper | 2026-01-28 |

---

## Verification

### Files Verified
- [x] `context-from-cli.sh` deleted
- [x] `statusline-context-cache-update.sh` deleted
- [x] `context-cache-updater.sh` deleted
- [x] `CONTEXT_FROM_CLI_FIX.md` deleted
- [x] `statusline-ralph.sh` restored to v2.78.5
- [x] No references to removed hooks in `settings.json`

### Git Status
```bash
# Modified files
M .claude/scripts/statusline-ralph.sh

# Deleted files
D .claude/hooks/context-from-cli.sh
D .claude/hooks/statusline-context-cache-update.sh
D .claude/hooks/context-cache-updater.sh
D docs/context-monitoring/CONTEXT_FROM_CLI_FIX.md
```

---

## References

- [Issue discussion](../) - Project issue tracker
- [ANALYSIS.md](ANALYSIS.md) - Original context monitoring analysis
- [FIX_SUMMARY.md](FIX_SUMMARY.md) - Previous fix attempts
