# Fix Correction - v2.75.1

**Date**: 2026-01-28
**Issue**: statusline showing 0% after initial fix

## Root Cause Analysis

The original comment in the code was CORRECT:
> The used_percentage field is unreliable (often shows 0% even when context is used)

**Problem**: `used_percentage` comes as 0 from Claude Code's statusline JSON.

## Correct Solution

### Priority Order (v2.75.1)

1. **PRIORITY 1**: Use `current_usage` (actual tokens in context window)
   - `current_usage.input_tokens` = real tokens in current context
   - `current_usage.cache_creation_input_tokens` = cache writes
   - `current_usage.cache_read_input_tokens` = cache reads

2. **PRIORITY 2**: Use `used_percentage` if current_usage unavailable
   - May come as 0, but better than nothing

3. **PRIORITY 3**: Use `total_*_tokens` as last resort
   - Session accumulators (don't reset after /clear)
   - But better than showing 0%

## Code Changes

### v2.75.0 (WRONG - caused 0% issue)
```bash
# Used used_percentage first (WRONG - it comes as 0!)
context_usage=$(echo "$context_info" | jq -r '.used_percentage // 0')

# Fallback to current_usage only if used_percentage is 0
if [[ "$context_usage" == "0" ]]; then
    CURRENT_USAGE=$(echo "$context_info" | jq '.current_usage // empty')
    # ... calculate from current_usage ...
fi
```

### v2.75.1 (CORRECT)
```bash
# PRIORITY 1: Try current_usage first (CORRECT)
CURRENT_USAGE=$(echo "$context_info" | jq '.current_usage // empty')

if [[ "$CURRENT_USAGE" != "null" ]] && [[ -n "$CURRENT_USAGE" ]]; then
    # Calculate from actual tokens in context
    CURRENT_TOKENS=$(echo "$CURRENT_USAGE" | jq '
        .input_tokens +
        (.cache_creation_input_tokens // 0) +
        (.cache_read_input_tokens // 0)
    ')
    context_usage=$((CURRENT_TOKENS * 100 / context_size))
else
    # PRIORITY 2: Fallback to used_percentage
    context_usage=$(echo "$context_info" | jq -r '.used_percentage // 0')

    # PRIORITY 3: Last resort - total_*_tokens
    if [[ "$context_usage" == "0" ]]; then
        total_input=$(echo "$context_info" | jq -r '.total_input_tokens // 0')
        total_output=$(echo "$context_info" | jq -r '.total_output_tokens // 0')
        context_usage=$((total_used * 100 / context_size))
    fi
fi
```

## Lessons Learned

1. **Trust the original code comments** - they said used_percentage was unreliable
2. **current_usage is the CORRECT field** - represents actual tokens in context
3. **Priority order matters** - should try best option first, not last
4. **Test with REAL data** - our mock tests didn't catch that used_percentage comes as 0

## Status

✅ Fixed in v2.75.1
✅ Uses current_usage as PRIMARY method
✅ Falls back to used_percentage then total_*_tokens
