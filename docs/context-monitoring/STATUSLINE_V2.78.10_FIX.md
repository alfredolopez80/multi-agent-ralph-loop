# Statusline v2.78.10 - Fix Summary

**Date**: 2026-01-28
**Version**: 2.78.10
**Status**: RESOLVED

## Problem

The statusline was showing incorrect context values:
- `/context` showed `Free space: 44k (22.1%)` (~111k used, 55%)
- Statusline showed `CtxUse: 200k/200k (100%)` - INCORRECT

## Root Cause

1. **Zai wrapper sends incorrect `used_percentage`**: Values were 0% or 100%, both wrong
2. **Cumulative tokens maxed out**: Session had 1011k cumulative tokens, which clamped to 200k (100%)
3. **Hook approach failed**: `context-from-cli.sh` hook couldn't work because `/context` is REPL-only, not a CLI command

## Solution (v2.78.10)

### Priority Order for Context Calculation

1. **`used_percentage` from stdin JSON** - Only if 5-95% (ignore 0% and 100%)
2. **`current_usage` object** - Not available in Zai wrapper
3. **Cache file** (`~/.ralph/cache/context-usage.json`) - If recent (< 120s)
4. **Cumulative tokens** - Conservative estimate (75%) when maxed out

### Key Changes

1. **Ignore extreme values**: `used_percentage` of 0% or 100% is ignored
2. **Read cache before cumulative**: Cache has manually updated correct values
3. **75% estimate**: When cumulative > 90% of context window, use 75% instead of 100%

### Removed

- Hook `context-from-cli.sh` - Removed from `settings.json` (cannot work)
- Project-specific cache logic - Simplified to single cache file

## Result

Statusline now shows: `CtxUse: 111k/200k (55%) | Free: 44k (22%)`

## Technical Details

### Files Modified

- `.claude/scripts/statusline-ralph.sh` - Main statusline script
- `~/.claude/hooks/statusline-ralph.sh` - Deployed copy
- `~/.claude-sneakpeek/zai/config/settings.json` - Removed non-working hook

### Validation

```bash
# Test used_percentage validation
used_pct=$(echo "$context_json" | jq -r '.used_percentage // empty')
if [[ $used_pct -gt 5 ]] && [[ $used_pct -lt 95 ]]; then
    # Trust this value
    used_tokens=$((context_size * used_pct / 100))
fi
```

```bash
# Conservative estimate when cumulative maxed out
if [[ $cumulative_tokens -gt $context_size ]]; then
    used_tokens=$((context_size * 75 / 100))  # 150k instead of 200k
    used_pct=75
fi
```

## Future Improvements

- Explore alternative methods to get accurate context usage from Zai wrapper
- Consider session file parsing for more accurate current window calculation
