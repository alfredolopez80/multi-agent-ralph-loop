# Context Window Bug Documentation Index

**Bug ID**: BUG-006
**Date Discovered**: 2026-01-27
**Version Fixed**: v2.74.3
**Affected Component**: `statusline-ralph.sh`

---

## Quick Links

| Document | Purpose |
|----------|---------|
| [Full Technical Report](context-window-bug-2026-01-27.md) | Complete investigation, root cause analysis, and fix details |
| [Diagnostic Script](../.claude/scripts/diagnose-context-window.sh) | Tool to diagnose context window issues in any Claude Code installation |
| [CHANGELOG Entry](../CHANGELOG.md) | Official changelog entry for v2.74.3 |
| [README Section](../README.md) | User-facing summary of the fix |

---

## Summary

### Problem
The `context_window.used_percentage` and `context_window.remaining_percentage` fields in Claude Code 2.1.19's statusline JSON input show incorrect values (0% used / 100% remaining) even when the context window is partially filled.

### Root Cause
The `current_usage` object is not being populated correctly, causing the pre-calculated percentage fields to be inaccurate.

### Solution
Calculate context usage from `total_input_tokens` + `total_output_tokens` instead of relying on `used_percentage`/`remaining_percentage`.

---

## Files Modified

### Core Fix
- **File**: `.claude/scripts/statusline-ralph.sh`
- **Version**: v2.74.3
- **Changes**: Replaced reliance on `used_percentage`/`remaining_percentage` with calculation from `total_*_tokens`

### Documentation
- `docs/context-window-bug-2026-01-27.md` - Full technical report
- `docs/context-window-bug-index.md` - This file
- `CHANGELOG.md` - Added v2.74.3 entry
- `README.md` - Added bug fix summary

### Tools
- `.claude/scripts/diagnose-context-window.sh` - Diagnostic tool
- `.claude/scripts/debug-stdin.sh` - Debug tool (used during investigation)

---

## Using the Diagnostic Tool

### Quick Diagnosis

1. **Temporarily modify `settings.json`**:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /path/to/multi-agent-ralph-loop/.claude/scripts/diagnose-context-window.sh"
  }
}
```

2. **Send a message in Claude Code**

3. **Check the output**:
   - Statusline will show diagnosis
   - Full report saved to `~/.ralph/logs/context-window-diagnosis-*.json`
   - Summary saved to `~/.ralph/logs/context-window-summary-*.txt`

4. **Restore original settings**:
```bash
# Restore from backup
cp ~/.claude-sneakpeek/zai/config/settings-backup-*.json \
   ~/.claude-sneakpeek/zai/config/settings.json
```

### Expected Output

**If bug is present**:
```
🔍 ctx:67% ❌ BUG: used_percentage is 0 but total_used is 134766
📁 context-window-summary-20260127-213456.txt
```

**If working correctly**:
```
🔍 ctx:67% ✅ OK: Percentages appear accurate
📁 context-window-summary-20260127-213456.txt
```

---

## Related Issues

- [GitHub Issue #17959](https://github.com/anthropics/claude-code/issues/17959) - context_window.used_percentage doesn't match internal
- [GitHub Issue #18241](https://github.com/anthropics/claude-code/issues/18241) - Context percentage displays are inconsistent
- [Reddit Discussion](https://www.reddit.com/r/ClaudeAI/comments/1qbmrc7/) - Claude status line can now show actual context after 2.1.6

---

## Testing

### Manual Test

```bash
# Run the diagnostic script manually with test data
echo '{"context_window":{"total_input_tokens":118396,"total_output_tokens":16370,"context_window_size":200000,"used_percentage":0,"remaining_percentage":100}}' | \
  bash .claude/scripts/diagnose-context-window.sh
```

Expected output:
```
🔍 ctx:67% ❌ BUG: used_percentage is 0 but total_used is 134766
```

### Automated Test

```bash
# Test with actual Claude Code statusline JSON
cat ~/.ralph/logs/statusline-stdin-debug.json | \
  bash .claude/scripts/diagnose-context-window.sh
```

---

## Version Compatibility

| Claude Code Version | Status | Notes |
|---------------------|--------|-------|
| 2.1.0 - 2.1.5 | ⚪ No `context_window` field | Feature not yet added |
| 2.1.6 - 2.1.18 | 🟡 Has field | May have the bug |
| 2.1.19 | 🔴 Confirmed bug | `current_usage` not populated |
| 2.1.20+ | ⏳ Unknown | Needs verification |

**Workaround**: The fix in statusline-ralph.sh v2.74.3 works for all versions that have the `context_window` field (2.1.6+).

---

## Maintenance

### To Re-Diagnose After Claude Code Updates

1. Update Claude Code:
```bash
claude-sneakpeek update zai
```

2. Run diagnostic:
```bash
# Use diagnose-context-window.sh as statusline temporarily
```

3. If bug is fixed in new version, consider reverting to use `used_percentage` directly.

---

*Last Updated: 2026-01-27*
