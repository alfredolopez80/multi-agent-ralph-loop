# /context Command - Sources and References

**Date**: 2026-01-28
**Status**: COMPLETE
**Version**: 2.78.2

## Summary

This document contains the sources and references used to understand and implement
the `/context` command behavior in the statusline display.

## Official Documentation

### Claude Code Docs
- **Interactive Mode**: https://code.claude.com/docs/en/interactive-mode
- **Overview**: https://code.claude.com/docs/en/overview
- **Statusline Configuration**: `~/.claude-code-docs/docs/statusline.md`

### Anthropic Engineering Articles
- **Claude Code Best Practices**: https://www.anthropic.com/engineering/claude-code-best-practices
  - Context management strategies
  - Token optimization techniques
  - When to use /clear vs /compact

## Official GitHub Issues

All issues from: https://github.com/anthropics/claude-code

| Issue | Topic | Relevance |
|-------|-------|-----------|
| [#18562](https://github.com/anthropics/claude-code/issues/18562) | /context command behavior | HIGH |
| [#17022](https://github.com/anthropics/claude-code/issues/17022) | Context window tracking | HIGH |
| [#8349](https://github.com/anthropics/claude-code/issues/8349) | Token counting issues | MEDIUM |
| [#6832](https://github.com/anthropics/claude-code/issues/6832) | Statusline context display | HIGH |
| [#8401](https://github.com/anthropics/claude-code/issues/8401) | Context percentage calculation | HIGH |
| [#11430](https://github.com/anthropics/claude-code/issues/11430) | /context verbose mode | LOW |
| [#10222](https://github.com/anthropics/claude-code/issues/10222) | Auto-compact behavior | MEDIUM |
| [#13783](https://github.com/anthropics/claude-code/issues/13783) | Cumulative tokens bug | CRITICAL |

## Community Sources

### Reddit
- **How to use Claude Code - The Context Method**:
  https://www.reddit.com/r/ClaudeCode/comments/1p0tj6m/this_is_how_i_use_claude_code_the_context_method/

## Technical Details

### /context Output Format

The `/context` command displays:

1. **Visual Grid**: Color-coded usage meter (█ filled vs ░ empty)
2. **Category Breakdown**:
   - System prompt
   - System tools
   - MCP tools
   - Memory files
   - Skills
   - Messages
   - Free space
3. **Verbose Details**: MCP servers, memory files, skills

### JSON Input Structure (Statusline)

```json
{
  "context_window": {
    "total_input_tokens": 15234,
    "total_output_tokens": 4521,
    "context_window_size": 200000,
    "used_percentage": 42.5,
    "remaining_percentage": 57.5,
    "current_usage": {
      "input_tokens": 8500,
      "output_tokens": 1200,
      "cache_creation_input_tokens": 5000,
      "cache_read_input_tokens": 2000
    }
  }
}
```

### Key Fields

| Field | Type | Description |
|-------|------|-------------|
| `total_input_tokens` | Cumulative | Session-accumulated input tokens |
| `total_output_tokens` | Cumulative | Session-accumulated output tokens |
| `used_percentage` | Current | Pre-calculated % (may be 0) |
| `remaining_percentage` | Current | Pre-calculated % (100 - used) |
| `current_usage.input_tokens` | **REAL** | Current window input |
| `current_usage.cache_creation_input_tokens` | **REAL** | Cache writes |
| `current_usage.cache_read_input_tokens` | **REAL** | Cache reads |

### Calculation Formula

To match `/context` behavior:

```bash
CURRENT_TOKENS=$(echo "$current_usage" | jq -r '
    (.input_tokens // 0) +
    (.cache_creation_input_tokens // 0) +
    (.cache_read_input_tokens // 0)
')

PERCENT_USED=$((CURRENT_TOKENS * 100 / CONTEXT_SIZE))
```

## Implementation in Ralph (v2.78.2)

### Two Different Displays

1. **🤖 Progress Bar** (`get_context_usage_cumulative`)
   - Shows: Total session tokens (cumulative)
   - Formula: `total_input_tokens + total_output_tokens`
   - Example: `🤖 80k/200k (40%)`

2. **CtxUse/Free/Buff** (`get_context_usage_current`)
   - Shows: Current window usage (matches /context)
   - Formula: `input_tokens + cache_creation + cache_read`
   - Example: `CtxUse: 15k/200k (7%)`

### Why Two Displays?

- **Progress bar**: Shows how much the session has consumed over time
- **CtxUse/Free/Buff**: Shows what's actually in the current window (what /context shows)

This distinction is important because:
- Session tokens accumulate and never decrease (even after /clear)
- Current window tokens reflect the actual prompt size for the next API call

## Related Documentation

- `docs/context-monitoring/ANALYSIS.md` - Context monitoring analysis
- `docs/context-monitoring/STATUSLINE_FIX_v2.78.0.md` - Previous fix attempt
- `docs/context-monitoring/FIX_SUMMARY.md` - Complete fix summary
- `.claude/scripts/statusline-ralph.sh` - Implementation

## References

- Claude Code Documentation: https://code.claude.com/docs/en/statusline
- Statusline JSON Structure: `~/.claude-code-docs/docs/statusline.md`
- GitHub Issue #13783: https://github.com/anthropics/claude-code/issues/13783
