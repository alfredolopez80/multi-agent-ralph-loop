# Context from CLI Hook - Installation Guide

**Date**: 2026-01-28
**Version**: 1.0.0
**Status**: READY

## Problem

The Zai wrapper of Claude Code does NOT provide `context_window.used_percentage` and `context_window.current_usage` fields in the statusline stdin JSON, even though `/context` command works correctly and shows real-time values.

## Solution

Created a hook that:
1. Calls `/context` command (which works correctly)
2. Parses its output to extract context usage
3. Stores in a **project-specific cache** (not global)
4. Statusline reads from this cache

## Files

| File | Purpose |
|------|---------|
| `.claude/hooks/context-from-cli.sh` | Hook that calls `/context` and updates cache |
| `.claude/scripts/statusline-ralph.sh` | Updated to v2.78.6 to read project-specific cache |

## Installation Steps

### Step 1: Add Hook to Settings

Add this to your `~/.claude-sneakpeek/zai/config/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/context-from-cli.sh"
          }
        ]
      }
    ]
  }
}
```

**Note:** Add it inside the EXISTING `UserPromptSubmit` array, don't replace it.

### Step 2: Restart Claude Code

Close and reopen Claude Code for changes to take effect.

### Step 3: Verify

After restart:
1. Send a prompt
2. The hook will call `/context` and create cache
3. Wait ~30 seconds for cache to populate
4. Check statusline shows values from `/context`

## How It Works

```
┌─────────────────┐
│ User sends prompt │
└────────┬────────┘
         │
         ▼
┌─────────────────────────┐
│ context-from-cli.sh hook  │
│ - Calls /context         │
│ - Parses output          │
│ - Writes cache:          │
│   ~/.ralph/cache/        │
│   context-{PROJECT_ID}.json│
└────────┬────────────────┘
         │
         ▼
┌�─────────────────┐
│ Statusline runs   │
│ - Reads cache     │
│ - Shows values    │
└─────────────────┘
```

## Cache File Format

```json
{
  "timestamp": 1769617452,
  "context_size": 200000,
  "used_tokens": 115600,
  "free_tokens": 84400,
  "used_percentage": 58,
  "remaining_percentage": 42
}
```

## Project ID Generation

The cache is project-specific based on:

1. **Git remote** (preferred): `owner-repo`
   - `github.com/anthropics/claude-code` → `anthropics-claude-code`

2. **Git directory hash** (fallback): `git-{hash}`
   - Used when no git remote or non-git directory

3. **Directory path hash** (last resort): `dir-{hash}`

This ensures each project has its own context cache.

## Troubleshooting

### Hook not executing

Check if hook is in settings.json:
```bash
grep "context-from-cli.sh" ~/.claude-sneakpeek/zai/config/settings.json
```

### Cache file not created

Check hook logs:
```bash
# Test hook manually
echo '{"cwd":".","hook_event_name":"UserPromptSubmit"}' | \
  .claude/hooks/context-from-cli.sh
```

### Statusline shows old values

Cache age is 60 seconds. Wait for next hook execution or manually trigger:
```bash
# Trigger hook by sending prompt
echo "test" | claude
```

### /context command not found

The hook assumes `claude context` is available. If using Zai variant, the command might be different. Update the hook:
```bash
# In context-from-cli.sh, change:
context_output=$(claude context 2>/dev/null)

# To try alternative:
context_output=$(npx -y zai-cli context 2>/dev/null)
```

## Related Documentation

- `docs/context-monitoring/CONTEXT_COMMAND_SOURCES.md` - /context command sources
- `docs/context-monitoring/STATUSLINE_FIX_v2.78.6.md` - This fix documentation
- `.claude/scripts/statusline-ralph.sh` - Statusline implementation
