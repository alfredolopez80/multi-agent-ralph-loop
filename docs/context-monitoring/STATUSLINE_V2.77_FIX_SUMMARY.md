# Statusline v2.77.x - Context Display Fix Summary

**Date**: 2026-01-28
**Version**: 2.77.2
**Status**: RESOLVED

## Summary

Fixed critical issues preventing the statusline from displaying real context usage values from `/context` command. The statusline was showing `CtxUse: 0k/200k tokens (0%)` instead of the actual usage values like `CtxUse: 142k/200k tokens (71%)`.

## Problems Identified

### Problem 1: Cache Expiry Inconsistency

**Issue**: Two different cache expiry values in the same script
- `get_context_usage_current()` used 60 seconds
- `update_context_cache_if_needed()` used 300 seconds

**Impact**: Cache was considered expired by `get_context_usage_current()` even though it was still valid according to `update_context_cache_if_needed()`.

**Root Cause**: When `CACHE_MAX_AGE` was increased from 60s to 300s in v2.77.1, only the update function was updated, not the read function.

### Problem 2: Incorrect Fallback Logic

**Issue**: Fallback activated too early, overriding valid cache data
- Checked only `used_pct -eq 0` to trigger fallback
- Did not check if `used_tokens` was also 0
- Fallback read from `remaining_percentage: 100` in statusline JSON (which has no real data)

**Impact**: Valid cached values (e.g., 71% used) were overridden with fallback values (0% used) because the check was incomplete.

**Code Flow**:
```
1. Cache read: used_pct=71, remaining_pct=29 ✓
2. Check: used_pct -eq 0? NO
3. But check happened BEFORE assigning cache values properly
4. Fallback activated, showing 0% instead of 71%
```

### Problem 3: Session File Data Unavailable

**Issue**: Session JSONL files do not contain `context_window` data
- `.context_window.remaining_percentage` is always `null` or `100`
- `.context_window.used_percentage` is always `0`

**Impact**: Cannot automatically update cache from session files. Manual update or hook-based solution required.

## Solutions Implemented

### Solution 1: Synchronized Cache Expiry (v2.77.2)

**File**: `.claude/scripts/statusline-ralph.sh`

**Change**: Updated `get_context_usage_current()` to use 300 seconds

```bash
# Before (line ~130):
if [[ $cache_age -lt 60 ]]; then

# After:
if [[ $cache_age -lt 300 ]]; then
```

### Solution 2: Improved Fallback Logic (v2.77.2)

**File**: `.claude/scripts/statusline-ralph.sh`

**Change**: Only activate fallback when BOTH `used_pct` AND `used_tokens` are 0

```bash
# Before:
if [[ $used_pct -eq 0 ]]; then
    # Activate fallback

# After:
if [[ $used_pct -eq 0 ]] && [[ $used_tokens -eq 0 ]]; then
    # Only activate fallback if truly no cached data
```

**Why This Works**:
- Valid cache has `used_pct=71` and `used_tokens=142000`
- Fallback only activates when cache is truly empty (both values = 0)
- Prevents overriding valid cache with fallback zeros

### Solution 3: Cache Preservation Logic (v2.77.1)

**File**: `.claude/scripts/statusline-ralph.sh`, `.claude/scripts/context-usage-cache.sh`

**Change**: Don't overwrite cache with invalid data

```bash
# Only update if we have valid non-zero usage data
if [[ $used_pct -eq 0 ]]; then
    # No valid usage data - preserve existing cache
    return 1
fi
```

### Solution 4: Helper Scripts Created

**New Scripts**:
1. `update-context-cache.sh` - Manual cache update with validation
2. `force-statusline-refresh.sh` - Force statusline reload with cache update
3. `parse-context-output.sh` - Parse `/context` command output (reserved for future use)

## Technical Details

### Cache File Structure

**Location**: `~/.ralph/cache/context-usage.json`

**Schema**:
```json
{
  "timestamp": 1769613624,
  "context_size": 200000,
  "used_tokens": 142000,
  "free_tokens": 58000,
  "used_percentage": 71,
  "remaining_percentage": 29
}
```

### Cache Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                    Cache Lifecycle (v2.77.2)                  │
├─────────────────────────────────────────────────────────────┤
│  1. Statusline calls update_context_cache_if_needed()       │
│  2. Check if cache exists and is < 300s old                 │
│  3. If fresh → return success (don't update)                │
│  4. If stale → try to read from session file                │
│  5. If session file has valid data → update cache           │
│  6. If session file has null/0/100 → preserve existing       │
│  7. Statusline calls get_context_usage_current()            │
│  8. Check if cache is < 300s old                            │
│  9. If fresh → use cached values                           │
│ 10. If expired OR used_pct=0 AND used_tokens=0 → fallback   │
└─────────────────────────────────────────────────────────────┘
```

### Fallback Hierarchy

```
1. CACHE (fresh, < 300s, non-zero)
   ↓ (if unavailable or invalid)
2. SESSION FILE (remaining_percentage not 0/100/null)
   ↓ (if unavailable)
3. FALLBACK (show 0% - no data available)
```

## Validation Results

### Test Case 1: Cache with Valid Data

**Input**: Cache with `used_pct=71`, `used_tokens=142000`

**Expected**: Show cached values
```
CtxUse: 142k/200k tokens (71%) | Free: 58k (29%) | Buff 45.0k tokens (22.5%)
```

**Result**: ✓ PASS - Shows correct cached values

### Test Case 2: Cache Expired (> 300s)

**Input**: Cache timestamp > 300s ago

**Expected**: Try to read from session file, fall back to 0% if no data

**Result**: ✓ PASS - Falls back correctly (preserves old cache if session has no data)

### Test Case 3: Cache with Zero Values

**Input**: Cache with `used_pct=0`, `used_tokens=0`

**Expected**: Activate fallback

**Result**: ✓ PASS - Activates fallback, shows 0%

### Test Case 4: Invalid Session Data

**Input**: Session file with `remaining_percentage: null` or `100`

**Expected**: Preserve existing cache

**Result**: ✓ PASS - Does not overwrite valid cache with zeros

## Files Modified

| File | Version | Changes |
|------|---------|---------|
| `.claude/scripts/statusline-ralph.sh` | v2.77.2 | Cache expiry sync, fallback fix |
| `.claude/scripts/context-usage-cache.sh` | v2.77.1 | Cache preservation logic |

## Files Created

| File | Purpose |
|------|---------|
| `.claude/scripts/update-context-cache.sh` | Manual cache update helper |
| `.claude/scripts/force-statusline-refresh.sh` | Force statusline reload |
| `.claude/scripts/parse-context-output.sh` | Parse `/context` output (future) |

## Known Limitations

### Limitation 1: No Automatic Data Source

**Issue**: Session files do not contain `context_window` data

**Workaround**: Manual cache update using helper scripts

```bash
./.claude/scripts/force-statusline-refresh.sh <USED_PCT> <FREE_TOKENS>
```

**Future Solution**: Create hook that captures `/context` output automatically

### Limitation 2: Manual Update Required

**Issue**: Cache must be manually updated when context usage changes significantly

**Frequency**: Every 5 minutes (cache expiry) or when usage changes > 10%

**Automation**: Could be automated with a PostToolUse hook that detects context changes

## Migration Guide

### From v2.76.x to v2.77.2

**No breaking changes**. Follow these steps:

1. **Update scripts** (already done):
   ```bash
   git pull
   ```

2. **Verify cache directory exists**:
   ```bash
   mkdir -p ~/.ralph/cache
   ```

3. **Initial cache setup** (optional, if you want to pre-seed):
   ```bash
   ./.claude/scripts/update-context-cache.sh --force 71 58000
   ```

4. **Verify statusline displays correctly**:
   - Look for: `CtxUse: XXXk/200k tokens (XX%)`
   - Should NOT show: `CtxUse: 0k/200k tokens (0%)` when cache is valid

## Related Documentation

- **Context Monitoring**: `docs/context-monitoring/ANALYSIS.md`
- **Previous Fixes**: `docs/context-monitoring/FIX_SUMMARY.md`
- **Validation v2.75.0**: `docs/context-monitoring/VALIDATION_v2.75.0.md`
- **Fix Correction v2.75.1**: `docs/context-monitoring/FIX_CORRECTION_v2.75.1.md`

## References

- Original issue: Statusline showing `CtxUse: 0k/200k tokens (0%)` instead of real values
- `/context` command output: `Free space: 58k (29.0%)` = Used: 142k (71%)
- Claude Code session file format: `.jsonl` with `context_window` object (mostly null)

## Next Steps

1. **Create automatic update hook**: Capture `/context` output automatically
2. **Add context change detection**: Detect when usage changes > 10%
3. **Implement smart refresh**: Auto-update cache when session is idle
4. **Add metrics**: Track cache hit rate and fallback activation frequency

---

**Author**: Claude (Multi-Agent Ralph v2.77.2)
**Review Status**: Ready for merge
**Test Coverage**: Manual testing completed
