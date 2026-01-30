# PostCompact Does NOT Exist - Session Summary

**Date**: 2026-01-30
**Session**: Post-Compaction Context Restoration Fix
**Status**: RESOLVED

## Problem Statement

The `/orchestrator` command from the previous session created INCORRECT documentation that mentioned `PostCompact` as a valid hook event, when in fact:

1. **`PostCompact` does NOT exist in Claude Code** (as of January 2026)
2. This was already discovered and documented in `COMPACT_HOOKS_FIX_v2.81.1.md`
3. The orchestrator ignored existing documentation and created incorrect files

## Errors Found

### Error 1: Incorrect Documentation Created

The orchestrator created these files (all now deleted):
- `docs/context-management/COMPACTION_FIX_SUMMARY_v2.81.0.md` ❌
- `docs/context-management/COMPACTION_PROCESS_ANALYSIS.md` ❌
- `tests/test-compaction-process.sh` ❌
- `tests/validate-compaction-fix.sh` ❌

These files incorrectly mentioned `PostCompact` as a valid hook event.

### Error 2: SessionStart Hook Failure

**Error Message**:
```
SessionStart:startup hook error: Failed with non-blocking status code: No stderr output
```

**Root Cause**: The `auto-sync-global.sh` hook had a bug where glob patterns like `*.md` that don't match any files would cause the script to fail with `set -e`.

**Location**: `.claude/hooks/auto-sync-global.sh`

**Problematic Code**:
```bash
for cmd in "$GLOBAL_DIR/commands"/*.md; do
    if [ -f "$cmd" ]; then
        # ...
    fi
done
```

When no `.md` files exist, the glob doesn't expand and the loop tries to use the literal string `*.md`, causing an error.

**Fix Applied**:
```bash
for cmd in "$GLOBAL_DIR/commands"/*.md; do
    [ -f "$cmd" ] || continue  # Skip if glob didn't match
    # ...
done
```

## Correct Implementation

### Post-Compaction Restoration Pattern

Since `PostCompact` does NOT exist, the correct pattern is:

```
PreCompact Event → Saves state before compaction
    ↓
Compaction Happens → Old messages removed
    ↓
SessionStart Event → Restores state in new session ✅
```

### SessionStart Hooks Configuration

**Current Configuration** (Correct):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "command": ".../session-start-ledger.sh"
      },
      {
        "command": ".../auto-migrate-plan-state.sh"
      },
      {
        "command": ".../auto-sync-global.sh" (FIXED)
      },
      {
        "command": ".../session-start-restore-context.sh"
      }
    ]
  }
}
```

### PreCompact Hooks Configuration

**Current Configuration** (Correct):
```json
{
  "hooks": {
    "PreCompact": [
      {
        "command": "~/.claude-sneakpeek/zai/config/hooks/pre-compact-handoff.sh"
      }
    ]
  }
}
```

## Documentation Created

### New Files

1. **`docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md`** ✅
   - Comprehensive documentation that PostCompact does NOT exist
   - Lists all valid hook events in Claude Code
   - Explains correct pattern for post-compaction restoration
   - Links to GitHub feature request #14258

### Files Deleted (Incorrect)

1. `docs/context-management/COMPACTION_FIX_SUMMARY_v2.81.0.md`
2. `docs/context-management/COMPACTION_PROCESS_ANALYSIS.md`
3. `tests/test-compaction-process.sh`
4. `tests/validate-compaction-fix.sh`

## Files Modified

1. **`.claude/hooks/auto-sync-global.sh`** ✅
   - Fixed glob pattern handling in for loops
   - Added `[ -f "$file" ] || continue` to skip non-matching globs
   - Hook now exits with code 0 instead of failing

## Validation

### auto-sync-global.sh Validation

```bash
# Before fix: Failed with non-zero exit code
echo '{"hook_event_name":"SessionStart","session_id":"test"}' | \
  .claude/hooks/auto-sync-global.sh
# Exit code: 1 (FAILED)

# After fix: Exits successfully
echo '{"hook_event_name":"SessionStart","session_id":"test"}' | \
  .claude/hooks/auto-sync-global.sh
# Exit code: 0 (SUCCESS) ✅
```

### session-start-restore-context.sh Validation

```bash
echo '{"hook_event_name":"SessionStart","session_id":"test"}' | \
  .claude/hooks/session-start-restore-context.sh
# Output: Valid JSON with hookSpecificOutput ✅
```

## Lessons Learned

### 1. Always Check Existing Documentation First

Before implementing hooks, check:
- `docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md`
- `docs/hooks/COMPACT_HOOKS_FIX_v2.81.1.md`
- Official Claude Code documentation (`/docs hooks`)

### 2. Use Safe Glob Patterns in Bash

When using `set -e` (exit on error), always check if glob matched:

```bash
# WRONG
for file in *.md; do
    if [ -f "$file" ]; then  # Too late! Already failed on literal "*.md"
        ...
    fi
done

# CORRECT
for file in *.md; do
    [ -f "$file" ] || continue  # Skip early if glob didn't match
    ...
done
```

### 3. SessionStart Hooks Must Exit with Code 0

All SessionStart hooks should:
- Use `|| true` or `|| continue` for non-critical operations
- Always `exit 0` (explicit or implicit)
- Never use `set -e` without proper error handling

## References

- **Main Doc**: `docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md`
- **Related**: `docs/hooks/COMPACT_HOOKS_FIX_v2.81.1.md`
- **GitHub**: [#14258](https://github.com/anthropics/claude-code/issues/14258) - PostCompact feature request
- **Fixed File**: `.claude/hooks/auto-sync-global.sh`

## Principle: "The Plan Survives Execution"

The current implementation ensures:
1. ✅ Plan state saved in PreCompact (before compaction)
2. ✅ Plan state restored in SessionStart (after compaction, new session)
3. ✅ Plan maintains consistency across compaction boundaries
4. ✅ NO invalid `PostCompact` event used
5. ✅ All SessionStart hooks exit successfully

---

**Status**: RESOLVED
**Validated**: 2026-01-30
**Next Steps**: Monitor for any further SessionStart hook errors
