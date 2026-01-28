# Context Monitoring Analysis - Critical Bug Found

**Date**: 2026-01-28
**Version**: Ralph v2.74.10
**Severity**: HIGH - Affects context tracking accuracy
**Status**: ANALYSIS COMPLETE - FIX REQUIRED

---

## Executive Summary

The statusline-ralph.sh script is using **cumulative session tokens** instead of **current context window usage**. This causes the context percentage to be completely inaccurate after `/clear` or auto-compact operations.

### Impact

- Statusline shows **169%** context usage when actual usage is **40%**
- After `/clear`, counters don't reset - showing impossible values (>100%)
- Context warnings trigger at wrong times
- Users cannot trust the context monitoring system

### Root Cause

GitHub Issue [#13783](https://github.com/anthropics/claude-code/issues/13783) documents this bug:

> The `context_window` data passed to custom statusline scripts contains **cumulative/accumulated tokens** from the entire session, not the **current context window usage**.

---

## The Problem in Detail

### What the script is doing WRONG (statusline-ralph.sh:~465)

```bash
# BUG: Using cumulative totals (WRONG)
total_input=$(echo "$context_info" | jq -r '.total_input_tokens // 0')
total_output=$(echo "$context_info" | jq -r '.total_output_tokens // 0')
context_size=$(echo "$context_info" | jq -r '.context_window_size // 200000')

# Calculate actual usage
if [[ "$context_size" -gt 0 ]]; then
    total_used=$((total_input + total_output))
    context_usage=$((total_used * 100 / context_size))
```

**Problem**: `total_input_tokens` and `total_output_tokens` are **session accumulators** that:
- Include ALL tokens from the ENTIRE session
- Are NOT reset by `/clear` or auto-compact
- Can exceed `context_window_size` (showing >100%)

### Example of the Bug

From `/context` command (CORRECT):
```
claude-opus-4-5-20251101 · 80k/200k tokens (40%)
```

From statusline JSON (INCORRECT):
```json
{
  "total_input_tokens": 330050,  // WRONG - session accumulator
  "total_output_tokens": 10614,  // WRONG - session accumulator
  "context_window_size": 200000
}
// Calculates: 340k/200k = 169% (IMPOSSIBLE)
```

---

## The Correct Solution

### According to Claude Code Documentation

From [statusline docs](https://code.claude.com/docs/en/statusline):

#### Option 1: Use Pre-calculated Percentage (RECOMMENDED)

```bash
# CORRECT: Use pre-calculated percentage
PERCENT_USED=$(echo "$input" | jq -r '.context_window.used_percentage // 0')

echo "[$MODEL] Context: ${PERCENT_USED}%"
```

#### Option 2: Calculate from current_usage (ADVANCED)

```bash
# CORRECT: Calculate from current_usage object
CONTEXT_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size')
USAGE=$(echo "$input" | jq '.context_window.current_usage')

if [ "$USAGE" != "null" ]; then
    # These are the ACTUAL tokens in the context window
    CURRENT_TOKENS=$(echo "$USAGE" | jq '
        .input_tokens +
        .cache_creation_input_tokens +
        .cache_read_input_tokens
    ')
    PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
    echo "[$MODEL] Context: ${PERCENT_USED}%"
else
    echo "[$MODEL] Context: 0%"
fi
```

### JSON Structure (from documentation)

```json
{
  "context_window": {
    // WRONG - Session accumulators (DO NOT USE)
    "total_input_tokens": 330050,
    "total_output_tokens": 10614,
    "context_window_size": 200000,

    // CORRECT - Pre-calculated percentages (USE THIS)
    "used_percentage": 40,
    "remaining_percentage": 60,

    // CORRECT - Current context window (USE THIS)
    "current_usage": {
      "input_tokens": 45000,           // Actual tokens in context
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  }
}
```

---

## Analysis of Current Hooks

### Hooks Reviewed

| Hook | Location | Method | Status |
|------|----------|--------|--------|
| `context-warning.sh` | Project | CLI `/context` + estimation | ✅ Uses native API |
| `glm-context-tracker.sh` | Project | Cumulative tracking | ⚠️ Designed for GLM-API |
| `unified-context-tracker.sh` | Project | Estimation fallback | ⚠️ Uses estimation when real=0 |
| `native-context-to-json.sh` | Old | Sync native to JSON | ✅ Correct approach |
| `context-real-tracker.sh` | Old | Track native API | ✅ Periodic polling |
| `statusline-ralph.sh` | Project | **Using total_* (BUG)** | ❌ **NEEDS FIX** |

### Key Findings

1. **context-warning.sh** correctly uses `claude --print "/context"` with timeout
2. **Old hooks** (native-context-to-json.sh, context-real-tracker.sh) already implemented correct tracking
3. **New unified tracker** falls back to estimation - may not be getting real values
4. **Statusline is the main offender** - using wrong fields from JSON

---

## Why the Bug Persists

### 1. Confusion about JSON fields

The statusline JSON provides BOTH:
- `total_*_tokens` - Session accumulators (misleading name)
- `current_usage` - Actual context window (correct)
- `used_percentage` - Pre-calculated (most reliable)

### 2. Documentation not clear enough

The issue was reported in December 2025 (#13783) but:
- Field names are misleading (`total_*` sounds like "current total")
- Documentation exists but not widely known
- Many example scripts use the wrong fields

### 3. No validation in hooks

Current hooks don't validate that:
- Percentage is within 0-100 range
- Token counts don't exceed context window
- Values reset after `/clear`

---

## Recommended Fix

### Fix statusline-ralph.sh (Lines ~465-495)

**Current code (WRONG)**:
```bash
# Get values
total_input=$(echo "$context_info" | jq -r '.total_input_tokens // 0')
total_output=$(echo "$context_info" | jq -r '.total_output_tokens // 0')
context_size=$(echo "$context_info" | jq -r '.context_window_size // 200000')

# Calculate actual usage
if [[ "$context_size" -gt 0 ]]; then
    total_used=$((total_input + total_output))
    context_usage=$((total_used * 100 / context_size))
```

**Fixed code (CORRECT)**:
```bash
# FIX: Use pre-calculated percentage OR current_usage
# Method 1: Use pre-calculated percentage (RECOMMENDED)
context_usage=$(echo "$context_info" | jq -r '.used_percentage // 0')

# Method 2: Calculate from current_usage (alternative)
# USAGE=$(echo "$context_info" | jq '.current_usage // empty')
# if [[ "$USAGE" != "null" ]] && [[ -n "$USAGE" ]]; then
#     CURRENT_TOKENS=$(echo "$USAGE" | jq '
#         .input_tokens +
#         .cache_creation_input_tokens +
#         .cache_read_input_tokens
#     ')
#     context_size=$(echo "$context_info" | jq -r '.context_window_size // 200000')
#     context_usage=$((CURRENT_TOKENS * 100 / context_size))
# fi

# Validate percentage is within bounds
if [[ $context_usage -lt 0 ]]; then context_usage=0; fi
if [[ $context_usage -gt 100 ]]; then context_usage=100; fi
```

### Additional Improvements

1. **Add validation** - Clamp percentage to 0-100 range
2. **Add fallback** - Use estimation if `used_percentage` is null/0
3. **Log discrepancies** - Track when cumulative vs current differ significantly
4. **Update context-warning.sh** - Add same fix for consistency

---

## Implementation Plan

### Phase 1: Fix Statusline (HIGH PRIORITY)

1. Update `statusline-ralph.sh` to use `used_percentage`
2. Add validation and fallback logic
3. Test with `/clear` and auto-compact scenarios
4. Verify percentage stays within 0-100 range

### Phase 2: Update Other Hooks (MEDIUM PRIORITY)

1. Review `unified-context-tracker.sh`
2. Review `glm-context-tracker.sh`
3. Ensure all hooks use correct fields
4. Add validation across the board

### Phase 3: Add Monitoring (LOW PRIORITY)

1. Log when `used_percentage` differs significantly from estimation
2. Track accuracy of context tracking over time
3. Alert on tracking anomalies

---

## Testing Checklist

After fix is applied, verify:

- [ ] Statusline shows correct percentage (0-100%)
- [ ] After `/clear`, percentage resets appropriately
- [ ] After auto-compact, percentage reflects actual usage
- [ ] Progress bar shows correct visual representation
- [ ] Colors change at correct thresholds (50%, 75%, 85%)
- [ ] Warning hooks trigger at correct percentages

---

## References

- [GitHub Issue #13783](https://github.com/anthropics/claude-code/issues/13783) - Statusline cumulative tokens bug
- [Statusline Documentation](https://code.claude.com/docs/en/statusline) - Official Claude Code docs
- [Context Window Usage](https://code.claude.com/docs/en/statusline#context-window-usage) - Specific section on context tracking

---

## Next Steps

1. **Immediate**: Fix `statusline-ralph.sh` with correct field usage
2. **Short-term**: Update all context-tracking hooks
3. **Long-term**: Add validation and monitoring infrastructure

**Ready to proceed with fix?** Run:
```bash
# Backup current version
cp .claude/scripts/statusline-ralph.sh .claude/scripts/statusline-ralph.sh.backup

# Apply fix (to be implemented)
# TODO: Create fix script
```
