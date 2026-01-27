# Context Window Statusline Bug - Claude Code 2.1.19

**Date**: 2026-01-27
**Affected Version**: Claude Code 2.1.19 (via Zai/claude-sneakpeek)
**Status**: FIXED in statusline-ralph.sh v2.74.3
**Severity**: Medium (feature shows incorrect data)

---

## Executive Summary

The `context_window.used_percentage` and `context_window.remaining_percentage` fields in Claude Code 2.1.19's statusline JSON input are unreliable and frequently show incorrect values (0% used / 100% remaining) even when the context window is partially filled.

### Root Cause

The `current_usage` object is not being populated correctly, causing the pre-calculated percentage fields to be inaccurate.

### Solution Implemented

Calculate context usage from `total_input_tokens` + `total_output_tokens` instead of relying on `used_percentage`/`remaining_percentage`.

---

## Problem Description

### Expected Behavior

According to [Claude Code official documentation](https://code.claude.com/docs/en/statusline), the statusline JSON should include:

```json
{
  "context_window": {
    "total_input_tokens": 118396,
    "total_output_tokens": 16370,
    "context_window_size": 200000,
    "used_percentage": 67.38,
    "remaining_percentage": 32.62,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  }
}
```

### Actual Behavior (Claude Code 2.1.19 via Zai)

```json
{
  "context_window": {
    "total_input_tokens": 118396,
    "total_output_tokens": 16370,
    "context_window_size": 200000,
    "current_usage": {
      "input_tokens": 0,
      "output_tokens": 0,
      "cache_creation_input_tokens": 0,
      "cache_read_input_tokens": 0
    },
    "used_percentage": 0,
    "remaining_percentage": 100
  }
}
```

### Impact

| Field | Expected | Actual | Status |
|-------|----------|--------|--------|
| `total_input_tokens` | 118396 | 118396 | ✅ Correct |
| `total_output_tokens` | 16370 | 16370 | ✅ Correct |
| `current_usage.input_tokens` | ~8500 | 0 | ❌ Incorrect |
| `used_percentage` | ~67% | 0 | ❌ Incorrect |
| `remaining_percentage` | ~33% | 100 | ❌ Incorrect |

**Real usage**: 134,766 tokens / 200,000 = **67.38% used**

**Displayed**: 0% used, 100% remaining

---

## Investigation Timeline

### 1. Initial Hypothesis: Zai Variant Incompatibility

**Hypothesis**: Zai (claude-sneakpeek) was using an old version of Claude Code that didn't support `context_window` fields.

**Investigation**:
- Searched for when `context_window` was added to Claude Code
- Found it was added in version 2.1.6

**Result**: ❌ Hypothesis rejected. Zai variant uses Claude Code 2.1.19, which should support this feature.

### 2. Verification: Field Existence

Created diagnostic script to capture actual statusline JSON input.

**Command**:
```bash
# Added to settings.json temporarily
"statusLine": {
  "type": "command",
  "command": "bash /path/to/debug-stdin.sh"
}
```

**Result**: ✅ Field exists but contains incorrect data.

### 3. Root Cause Analysis

Compared `total_*_tokens` (correct) vs `current_usage` (empty) vs `used_percentage` (incorrect).

**Conclusion**: The `current_usage` object is not being populated, which causes the pre-calculated percentage fields to be wrong.

---

## Solution Implemented

### Code Changes (statusline-ralph.sh v2.74.3)

#### Before (Buggy - used pre-calculated percentages)

```bash
# TEMPORAL: Extract context window remaining percentage (PRUEBA)
context_remaining=$(echo "$stdin_data" | jq -r '.context_window.remaining_percentage // ""' 2>/dev/null || echo "")
if [[ -n "$context_remaining" ]] && [[ "$context_remaining" != "null" ]]; then
    context_usage=$((100 - context_remaining))
    context_display="${CYAN}ctx:${context_usage}%${RESET}"
else
    context_display=""
fi
```

**Problem**: Relied on `remaining_percentage` which was always 100.

#### After (Fixed - calculates from totals)

```bash
# Extract context window usage - FIX v2.74.3: Calculate from total_*_tokens instead of used_percentage
# The used_percentage field is unreliable (often shows 0% even when context is used)
context_info=$(echo "$stdin_data" | jq -r '.context_window // "{}"' 2>/dev/null)
if [[ -n "$context_info" ]] && [[ "$context_info" != "null" ]]; then
    # Get values
    total_input=$(echo "$context_info" | jq -r '.total_input_tokens // 0')
    total_output=$(echo "$context_info" | jq -r '.total_output_tokens // 0')
    context_size=$(echo "$context_info" | jq -r '.context_window.context_window_size // 200000')

    # Calculate actual usage
    if [[ "$context_size" -gt 0 ]]; then
        total_used=$((total_input + total_output))
        context_usage=$((total_used * 100 / context_size))

        # Color coding based on usage
        if [[ $context_usage -lt 50 ]]; then
            context_color="$CYAN"
        elif [[ $context_usage -lt 75 ]]; then
            context_color="$GREEN"
        elif [[ $context_usage -lt 85 ]]; then
            context_color="$YELLOW"
        else
            context_color="$RED"
        fi

        # Format: ctx:67% (134K/200K)
        context_display="${context_color}ctx:${context_usage}%${RESET}"
    else
        context_display=""
    fi
else
    context_display=""
fi
```

**Benefits**:
- ✅ Calculates from reliable `total_*_tokens` fields
- ✅ Adds color coding (CYAN < 50%, GREEN < 75%, YELLOW < 85%, RED >= 85%)
- ✅ Graceful fallback if `context_window` is missing

---

## Verification

### Test Data

From actual debug session (2026-01-27):

```json
{
  "total_input_tokens": 118396,
  "total_output_tokens": 16370,
  "context_window_size": 200000
}
```

### Calculation

```
total_used = 118396 + 16370 = 134766
context_usage = 134766 / 200000 * 100 = 67.38%
```

### Expected Statusline Output

```
ctx:67%
```

With color: **GREEN** (between 50-74%)

---

## Related Issues

### Claude Code Changelog

From [CHANGELOG.md](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md):

> Added `context_window.used_percentage` and `context_window.remaining_percentage` fields to status line input for easier context window display.

Added in version **2.1.6**.

### Community Reports

1. [Reddit: Claude status line can now show actual context after 2.1.6](https://www.reddit.com/r/ClaudeAI/comments/1qbmrc7/)
2. [GitHub Issue #17959: context_window.used_percentage doesn't match internal](https://github.com/anthropics/claude-code/issues/17959)
3. [GitHub Issue #18241: Context percentage displays are inconsistent](https://github.com/anthropics/claude-code/issues/18241)

---

## Environment Details

| Component | Version |
|-----------|---------|
| Claude Code | 2.1.19 |
| claude-sneakpeek | 1.6.9 |
| Provider | Z.ai (GLM-4.7) |
| OS | macOS (darwin 25.2.0) |
| Config location | `~/.claude-sneakpeek/zai/config/` |

---

## Workaround Summary

### If You Need Reliable Context Percentage

**Option 1**: Use the fixed script (statusline-ralph.sh v2.74.3)

```bash
# Clone or copy the fixed script
cp /path/to/statusline-ralph.sh ~/.claude/scripts/
```

**Option 2**: Calculate manually

```bash
# From statusline JSON
total_input=$(jq '.context_window.total_input_tokens')
total_output=$(jq '.context_window.total_output_tokens')
context_size=$(jq '.context_window.context_window_size')
usage=$(( (total_input + total_output) * 100 / context_size ))
```

**Option 3**: Wait for Claude Code fix

Monitor [Claude Code releases](https://github.com/anthropics/claude-code/releases) for updates to 2.1.19+.

---

## References

- [Claude Code Statusline Documentation](https://code.claude.com/docs/en/statusline)
- [claude-sneakpeek Repository](https://github.com/mikekelly/claude-sneakpeek)
- [Context7 MCP Documentation](https://context7.com/)

---

## Changelog

### 2026-01-27
- **21:30** - Initial investigation started
- **21:34** - Diagnostic script created and executed
- **21:35** - Bug identified: `used_percentage` always 0, `remaining_percentage` always 100
- **21:36** - Fix implemented in statusline-ralph.sh v2.74.3
- **21:40** - Documentation created

---

*Document created during investigation of context window tracking in Multi-Agent Ralph Loop project.*
