# Statusline Architecture - Context Monitoring System

**Date**: 2026-01-28
**Version**: 2.77.2
**Status**: ACTIVE

## Overview

The statusline provides real-time context monitoring by displaying usage information from the `/context` command. This document explains where files are located, how values are obtained, and how tracking works.

## File Locations

### Repository Files (Version Controlled)

All scripts are stored in the repository at:

```
multi-agent-ralph-loop/.claude/scripts/
├── statusline-ralph.sh          (v2.77.2) - Main statusline script
├── context-usage-cache.sh       (v2.77.1) - Cache management
├── update-context-cache.sh       (NEW)      - Manual update helper
├── force-statusline-refresh.sh   (NEW)      - Force reload helper
└── parse-context-output.sh       (NEW)      - Parse /context output
```

### Global Symlinks (Runtime)

Scripts are symlinked to global location for persistence:

```
~/.claude-sneakpeek/zai/config/hooks/
├── statusline-ralph.sh → /path/to/repo/.claude/scripts/statusline-ralph.sh
├── context-usage-cache.sh → /path/to/repo/.claude/scripts/context-usage-cache.sh
├── update-context-cache.sh → /path/to/repo/.claude/scripts/update-context-cache.sh
�── force-statusline-refresh.sh → /path/to/repo/.claude/scripts/force-statusline-refresh.sh
└── parse-context-output.sh → /path/to/repo/.claude/scripts/parse-context-output.sh
```

### Cache File (Runtime Data)

```
~/.ralph/cache/context-usage.json
```

**Format**:
```json
{
  "timestamp": 1769614425,
  "context_size": 200000,
  "used_tokens": 168000,
  "free_tokens": 32000,
  "used_percentage": 84,
  "remaining_percentage": 16
}
```

## How Values Are Obtained

### Data Source

The `/context` command provides real-time context usage:

```
glm-4.7 · 0k/200k tokens (0%)           # Header (always shows 0)
Estimated usage by category:
  System prompt: 3.2k tokens (1.6%)
  System tools: 20.8k tokens (10.4%)
  MCP tools: 795 tokens (0.4%)
  Custom agents: 1.2k tokens (0.6%)
  Memory files: 14.4k tokens (7.2%)
  Skills: 1.5k tokens (0.7%)
  Messages: 80.9k tokens (40.4%)
  ------------------------------------------
  Total categories: ~97k tokens (48.5%)
  Plus overhead/uncategorized: ~71k tokens (35.5%)
  ==========================================
  Total used: ~168k tokens (84%)
  Free space: 32k (16%)
  Autocompact buffer: 45.0k tokens (22.5%)
```

### Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    Data Flow Architecture                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. User runs /context command                                    │
│     ↓                                                               │
│  2. User sees: Free space: 32k (16.1%)                          │
│     ↓                                                               │
│  3. User updates cache (manual):                                    │
│     ./.claude/scripts/force-statusline-refresh.sh 84 32000          │
│     ↓                                                               │
│  4. Cache file updated: ~/.ralph/cache/context-usage.json          │
│     {                                                             │
│       "used_percentage": 84,                                      │
│       "remaining_percentage": 16,                                  │
│       "used_tokens": 168000,                                     │
│       "free_tokens": 32000                                        │
│     }                                                             │
│     ↓                                                               │
│  5. Statusline runs (every prompt):                                 │
│     settings.json → bash statusline-ralph.sh                      │
│     ↓                                                               │
│  6. statusline-ralph.sh reads cache:                                │
│     get_context_usage_current() → reads ~/.ralph/cache/...        │
│     ↓                                                               │
│  7. Display formatted:                                             │
│     CtxUse: 168k/200k tokens (84%) | Free: 32k (16%) | ...     │
│                                                                     │
└─────────────────────────────────────────────────────────────────┘
```

## How Tracking Works

### Automatic Components

1. **Statusline Execution** (Automatic)
   - Runs on every prompt via settings.json
   - Calls `update_context_cache_if_needed()` in background
   - Reads cache via `get_context_usage_current()`

2. **Background Cache Update** (Automatic)
   - Runs `update_context_cache_if_needed &` (background)
   - Checks if cache is stale (> 300 seconds)
   - Attempts to read from session file
   - Preserves existing cache if session has no data

### Manual Components

1. **Manual Cache Update** (User-triggered)
   ```bash
   # Update cache with current /context values
   ./.claude/scripts/update-context-cache.sh --force <USED_PCT> <FREE_TOKENS>

   # Example: Free space: 32k (16%)
   ./.claude/scripts/update-context-cache.sh --force 84 32000
   ```

2. **Force Statusline Refresh** (User-triggered)
   ```bash
   # Update cache and refresh statusline
   ./.claude/scripts/force-statusline-refresh.sh 84 32000
   ```

### Cache Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│                  Cache Lifecycle (300s = 5 minutes)            │
├─────────────────────────────────────────────────────────────┤
│                                                                     │
│  T=0s: Cache created/updated                                    │
│       ├─ timestamp: now                                       │
│       ├─ used_pct: 84                                          │
│       ├─ used_tokens: 168000                                   │
│       └─ expires_at: now + 300s                                │
│                                                                     │
│  T=0s to T=300s: CACHE VALID                                     │
│       ├─ Statusline reads cache directly                         │
│       ├─ Shows: CtxUse: 168k/200k (84%)                         │
│       └─ No session file reads                                  │
│                                                                     │
│  T=300s: CACHE EXPIRES                                            │
│       ├─ Next statusline run triggers update                     │
│       ├─ update_context_cache_if_needed() executes               │
│       ├─ Attempts to read from session file                     │
│       ├─ If session has data → update cache                     │
│       ├─ If session has no data → preserve existing              │
│       └─ Statusline shows last known valid values              │
│                                                                     │
│  User Manual Update (anytime):                                   │
│       ├─ force-statusline-refresh.sh 84 32000                   │
│       ├─ Cache updated with new values                          │
│ ├─ timestamp refreshed                                        │
│       └─ Cycle repeats from T=0                                │
│                                                                     │
└─────────────────────────────────────────────────────────────┘
```

## Display Format

### Statusline Components

```
⎇ main* ↑5 │                                    # Git info
🤖 ██████████░░ 837k/200k (418%) │          # Cumulative (claude-hud style)
CtxUse: 168k/200k tokens (84%) │                # Current (/context style)
Free: 32k (16%) │                           # Free space
Buff 45.0k tokens (22.5%) │                   # Autocompact buffer
⏱️ 14% (~5h) │                              # GLM usage
🔧 4% MCP (178/4000) │                       # MCP usage
🔄 3/7 42%                                  # Ralph progress
```

### Color Coding

| Percentage | Color | Example |
|------------|-------|---------|
| 1-49% | CYAN | `CtxUse: 50k/200k tokens (25%)` |
| 50-74% | GREEN | `CtxUse: 120k/200k tokens (60%)` |
| 75-84% | YELLOW | `CtxUse: 160k/200k tokens (80%)` |
| 85-100% | RED | `CtxUse: 180k/200k tokens (90%)` |

## Calculation Methods

### Method 1: Cumulative (claude-hud style)

Shows total tokens used in the entire session:

```bash
total_input_tokens + total_output_tokens = cumulative_usage
cumulative_usage / context_size × 100 = percentage
```

**Display**: `🤖 ██████████░░ 837k/200k (418%)`

### Method 2: Current Window (/context style)

Shows actual current usage from `/context` command:

```bash
# From /context command output:
Free space: 32k (16.1%)

# Calculate:
remaining_pct = 16
used_pct = 100 - 16 = 84
used_tokens = 200000 × 0.84 = 168000
free_tokens = 32000
```

**Display**: `CtxUse: 168k/200k tokens (84%) | Free: 32k (16%)`

## Maintenance

### Regular Maintenance Tasks

**Daily** (as needed):
```bash
# Update cache when context usage changes significantly
./.claude/scripts/force-statusline-refresh.sh <USED_PCT> <FREE_TOKENS>
```

**Weekly** (optional):
```bash
# Verify all symlinks are correct
ls -la ~/.claude-sneakpeek/zai/config/hooks/statusline*.sh

# Verify cache is being used
cat ~/.ralph/cache/context-usage.json | jq '.'
```

### Troubleshooting

**Problem**: Statusline shows `CtxUse: 0k/200k tokens (0%)`

**Solution**:
```bash
# 1. Check cache exists and has valid data
cat ~/.ralph/cache/context-usage.json | jq '.'

# 2. If cache is old or has zeros, update it
./.claude/scripts/force-statusline-refresh.sh <USED_PCT> <FREE_TOKENS>

# 3. Verify symlinks are correct
ls -la ~/.claude-sneakpeek/zai/config/hooks/statusline-ralph.sh

# 4. Test statusline function directly
source ./.claude/scripts/statusline-ralph.sh
# (function testing requires context JSON input)
```

**Problem**: Values don't match `/context` output

**Solution**:
```bash
# Run /context to see current values
/context

# Update cache with exact values from output
# Example: if Free space: 32k (16.1%)
./.claude/scripts/force-statusline-refresh.sh 84 32000
```

## API Reference

### update-context-cache.sh

```bash
./.claude/scripts/update-context-cache.sh [--update|--force|--show] [USED_PCT] [FREE_TOKENS]

# Show current cache
./.claude/scripts/update-context-cache.sh

# Try to update from session file
./.claude/scripts/update-context-cache.sh --update

# Force update with specific values
./.claude/scripts/update-context-cache.sh --force 84 32000
```

### force-statusline-refresh.sh

```bash
./.claude/scripts/force-statusline-refresh.sh [USED_PCT] [FREE_TOKENS]

# Auto-detect from cache (if values provided, update cache)
./.claude/scripts/force-statusline-refresh.sh

# Force update with specific values
./.claude/scripts/force-statusline-refresh.sh 84 32000
```

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v2.77.2 | 2026-01-28 | Fixed cache expiry sync, improved fallback logic |
| v2.77.1 | 2026-01-28 | Cache preservation, increased expiry to 300s |
| v2.77.0 | 2026-01-28 | Added context display matching /context format |
| v2.76.x | 2026-01-27 | Previous versions with cumulative tracking |

## Related Documentation

- **Fix Summary**: `docs/context-monitoring/STATUSLINE_V2.77_FIX_SUMMARY.md`
- **Previous Analysis**: `docs/context-monitoring/ANALYSIS.md`
- **Validation Report**: `docs/context-monitoring/VALIDATION_v2.75.0.md`

---

**Last Updated**: 2026-01-28
**Maintained By**: Multi-Agent Ralph v2.77.2
**Questions?** See `docs/context-monitoring/CLAUDE.md` or `README.md`
