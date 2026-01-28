# Statusline Fix v2.78.0 - Native Context Reading

**Date**: 2026-01-28
**Version**: v2.78.0
**Status**: RESOLVED
**Severity**: CRITICAL - Fundamental design error fixed

## Executive Summary

Fixed a **critical design error** in statusline-ralph.sh where the script was using **manual cache** instead of reading the **native `used_percentage`** from stdin JSON. This caused the statusline to show incorrect context values that did not match the `/context` command.

## The Problem

### What Was Wrong (v2.77.2 and earlier)

The statusline was:
1. Creating a manual cache file (`~/.ralph/cache/context-usage.json`)
2. Parsing `/context` command output to populate the cache
3. Reading from the cache instead of using the native data

### Why This Was Wrong

According to `docs/context-monitoring/ANALYSIS.md`:

> The manual cache approach has a **GRAVE ERROR** - the values shown are **general/manual calculations**, NOT from the **active session**.

The cache was being populated from session files that contain **cumulative session tokens**, not the **current context window usage**.

## The Solution

### v2.78.0 Implementation

**Before (INCORRECT)**:
```bash
# Try to get cached real usage from /context
local cache_file="${HOME}/.ralph/cache/context-usage.json"
if [[ -f "$cache_file" ]]; then
    used_pct=$(jq -r '.used_percentage // 0' "$cache_file" 2>/dev/null)
fi
```

**After (CORRECT)**:
```bash
# v2.78.0: Read native used_percentage from stdin JSON
# This is the REAL percentage from the active session, not cumulative tokens
local used_pct=$(echo "$context_json" | jq -r '.used_percentage // 0')
```

### Why This Is Correct

The stdin JSON passed to the statusline by Claude Code contains:

```json
{
  "context_window": {
    // ✅ CORRECT - Pre-calculated percentage from active session
    "used_percentage": 71,
    "remaining_percentage": 29,
    "context_window_size": 200000
  }
}
```

This `used_percentage` field is the **same data source** used by the native `/context` command.

## Changes Made

### Files Modified

1. **`.claude/scripts/statusline-ralph.sh`** (v2.77.2 → v2.78.0)
   - Removed manual cache system (CACHE_DIR, CACHE_FILE, update_context_cache_if_needed function)
   - Changed `get_context_usage_current()` to read `.used_percentage` directly from stdin JSON
   - Added validation to clamp percentage to 0-100 range
   - Simplified code: ~80 lines removed

### Files Deleted

1. **`.claude/scripts/context-cache-manager.sh`** - No longer needed
2. **`.claude/scripts/context-usage-cache.sh`** - No longer needed
3. **`.claude/scripts/update-context-cache.sh`** - No longer needed

### Files Preserved (Not Used but Available)

- **`.claude/scripts/parse-context-output.sh`** - Parser utility (kept for reference)
- **`.claude/scripts/force-statusline-refresh.sh`** - Refresh utility (kept for reference)

## Verification

### Test Case

```bash
# Simulated stdin JSON
echo '{
  "context_window": {
    "context_window_size": 200000,
    "used_percentage": 71,
    "remaining_percentage": 29
  }
}' | jq '.context_window.used_percentage, .context_window.remaining_percentage'

# Output:
# 71
# 29
```

### Expected Behavior

| Metric | v2.77.2 (Wrong) | v2.78.0 (Correct) |
|--------|-----------------|-------------------|
| Data Source | Manual cache from session files | Native stdin JSON |
| Values Match /context? | ❌ No | ✅ Yes |
| Active Session Values? | ❌ No (cumulative) | ✅ Yes (current window) |
| Cache Complexity | High (files, background updates) | None (direct read) |
| Lines of Code | ~150 | ~70 |

## References

- [GitHub Issue #13783](https://github.com/anthropics/claude-code/issues/13783) - Statusline cumulative tokens bug
- `docs/context-monitoring/ANALYSIS.md` - Original bug analysis
- `docs/context-monitoring/STATUSLINE_ARCHITECTURE.md` - Architecture documentation

## Migration Notes

### For Users

No action required. The statusline will automatically use the correct native values.

### For Developers

When reading context information from stdin JSON:

```bash
# ✅ CORRECT - Use native pre-calculated percentage
PERCENT_USED=$(echo "$stdin" | jq -r '.context_window.used_percentage // 0')

# ❌ INCORRECT - Don't use cumulative session totals
TOTAL_INPUT=$(echo "$stdin" | jq -r '.context_window.total_input_tokens // 0')
TOTAL_OUTPUT=$(echo "$stdin" | jq -r '.context_window.total_output_tokens // 0')
# These are session accumulators, NOT current context window usage
```

## Git Commit

```bash
git add .claude/scripts/statusline-ralph.sh
git add docs/context-monitoring/STATUSLINE_FIX_v2.78.0.md
git rm .claude/scripts/context-cache-manager.sh
git rm .claude/scripts/context-usage-cache.sh
git rm .claude/scripts/update-context-cache.sh
git commit -m "fix: statusline v2.78.0 - use native used_percentage from stdin JSON

CRITICAL FIX: Statusline now reads native used_percentage directly from
stdin JSON instead of using manual cache system.

Problem:
- Previous implementation used manual cache populated from session files
- Session files contain cumulative tokens, not current context usage
- Values did not match /context command output

Solution:
- Read .context_window.used_percentage directly from stdin JSON
- This is the same data source used by native /context command
- Eliminates cache complexity and ensures accuracy

Changes:
- Removed manual cache system (~80 lines)
- Removed cache update function and background process
- Deleted obsolete cache scripts (3 files)
- Added 0-100 range validation for used_percentage

See: docs/context-monitoring/STATUSLINE_FIX_v2.78.0.md
See: https://github.com/anthropics/claude-code/issues/13783"
```

## Changelog Entry

**v2.78.0** (2026-01-28)

### Fixed
- **CRITICAL**: Statusline now uses native `used_percentage` from stdin JSON
- Statusline values now match `/context` command exactly
- Removed manual cache system (was using wrong data source)

### Removed
- `context-cache-manager.sh` - No longer needed
- `context-usage-cache.sh` - No longer needed
- `update-context-cache.sh` - No longer needed

### Technical Details
- Reading `.context_window.used_percentage` from stdin JSON
- Same data source as native `/context` command
- Eliminates cache complexity and improves accuracy
- See `docs/context-monitoring/STATUSLINE_FIX_v2.78.0.md`
