# Context Monitoring Documentation

This directory contains documentation related to the context monitoring system for Multi-Agent Ralph Loop.

## Overview

The context monitoring system tracks token usage in Claude Code sessions and displays real-time context percentage in the statusline. This documentation covers the analysis, fixes, and validation of the context tracking implementation.

## Current Status (v2.78.5)

**Active Version**: v2.78.5 (rolled back from v2.79.0)

**Behavior**:
- Progress bar shows cumulative session tokens (can exceed 100%)
- Current context uses cumulative tokens as best available approximation
- Display format: `🤖 ██████████░░ 391k/200k (195%)`

**Limitations**:
- Shows SESSION ACCUMULATED tokens, not CURRENT WINDOW usage
- To see actual current window usage, run `/context` command manually
- No project-specific differentiation in statusline

**Recent Rollback**: See [ROLLBACK_v2.79.0_TO_v2.78.5.md](ROLLBACK_v2.79.0_TO_v2.78.5.md) for details

---

## Documentation Index

### Current (Active)

| File | Description | Date |
|------|-------------|------|
| [ANALYSIS.md](ANALYSIS.md) | Initial analysis of GitHub Issue #13783 - Context tracking bug investigation | 2026-01-28 |
| [VALIDATION_v2.75.0.md](VALIDATION_v2.75.0.md) | Validation report for initial fix using `used_percentage` field | 2026-01-28 |
| [FIX_CORRECTION_v2.75.1.md](FIX_CORRECTION_v2.75.1.md) | Analysis of why initial fix failed and lessons learned | 2026-01-28 |
| [FIX_SUMMARY.md](FIX_SUMMARY.md) | Complete summary of the context monitoring fix journey through v2.75.3 | 2026-01-28 |
| [STATUSLINE_FIX_v2.78.0.md](STATUSLINE_FIX_v2.78.0.md) | Statusline v2.78.0 fix using native `used_percentage` from stdin JSON | 2026-01-26 |
| [STATUSLINE_V2.77_FIX_SUMMARY.md](STATUSLINE_V2.77_FIX_SUMMARY.md) | Statusline v2.77.x context display fixes summary | 2026-01-26 |
| [STATUSLINE_ARCHITECTURE.md](STATUSLINE_ARCHITECTURE.md) | Complete architecture documentation for context monitoring system | 2026-01-26 |
| [CONTEXT_COMMAND_SOURCES.md](CONTEXT_COMMAND_SOURCES.md) | Documentation of /context command sources and references | 2026-01-26 |

### Historical (Archived)

| File | Description | Date | Status |
|------|-------------|------|--------|
| [ROLLBACK_v2.79.0_TO_v2.78.5.md](ROLLBACK_v2.79.0_TO_v2.78.5.md) | Rollback documentation from v2.79.0 to v2.78.5 | 2026-01-28 | ✅ CURRENT |
| [STATUSLINE_V2.78.10_FIX.md](STATUSLINE_V2.78.10_FIX.md) | Statusline v2.78.10 fix with validation and fallback | 2026-01-28 | ⚠️ OBSOLETE |
| [STATUSLINE_V2.78_IMPLEMENTATION.md](STATUSLINE_V2.78_IMPLEMENTATION.md) | Statusline v2.78 implementation report | 2026-01-26 | ⚠️ OBSOLETE |
| [SYSTEM_FINDINGS.md](SYSTEM_FINDINGS.md) | Context system findings and issues | 2026-01-26 | 📚 ARCHIVE |
| [STATUS_VALIDATION.md](STATUS_VALIDATION.md) | Context status validation results | 2026-01-26 | 📚 ARCHIVE |
| [GLM_FIX_PLAN.md](GLM_FIX_PLAN.md) | GLM context monitoring fix implementation plan | 2026-01-26 | 📚 ARCHIVE |
| [GLM_FIX_SUMMARY.md](GLM_FIX_SUMMARY.md) | GLM-4.7 context monitoring fix implementation summary | 2026-01-26 | 📚 ARCHIVE |
| [GLM47_FIXED.md](GLM47_FIXED.md) | GLM-4.7 context monitoring fix confirmation | 2026-01-26 | 📚 ARCHIVE |

---

## Key Findings

1. **Original Issue**: Statusline was showing `ctx:0%` even with active context usage
2. **Root Cause**: Claude Code's `used_percentage` and `current_usage` fields were returning 0
3. **Solution**: Restored original behavior using `total_*_tokens` (cumulative session accumulators)
4. **Final Version**: v2.78.5 shows cumulative session tokens (can exceed 100%)

## Future Strategy

### Requirements

1. **Read from stdin JSON**: The `/context` information must be extracted from the stdin JSON that Claude Code CLI provides, NOT from calling `/context` as an external command.

2. **Project-specific tracking**: Use `context-project-id` or similar mechanism to differentiate between projects and maintain separate context caches.

3. **Validate available fields**: Determine which fields in the stdin JSON actually contain reliable context usage data.

### Open Questions

- What exact fields are available in stdin JSON for context tracking?
- How to extract project ID from stdin JSON?
- What is the correct `context-project-id` field name?

## Related Files

- Script: `.claude/scripts/statusline-ralph.sh` - Main statusline implementation (v2.78.5)
- Hooks: `.claude/hooks/context-warning.sh` - Context warning system
- Documentation: [../CLAUDE.md](../CLAUDE.md) - Project documentation standards

## References

- [GitHub Issue #13783](https://github.com/anthropics/claude-code/issues/13783) - Statusline cumulative tokens bug
- [Claude Code Statusline Docs](https://code.claude.com/docs/en/statusline) - Official documentation
