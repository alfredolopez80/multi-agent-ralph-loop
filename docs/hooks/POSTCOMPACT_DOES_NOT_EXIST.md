# PostCompact Event - DOES NOT EXIST

**Date**: 2026-01-30
**Version**: v2.81.1
**Status**: ⚠️ **CRITICAL - READ THIS BEFORE IMPLEMENTING COMPACT HOOKS**

## ⚠️ CRITICAL WARNING

**`PostCompact` is NOT a valid hook event in Claude Code as of January 2026.**

Attempting to add `PostCompact` to `settings.json` will cause:
```
Error: Invalid key in record
```

This will prevent Claude Code from loading your configuration.

## Valid Hook Events in Claude Code

According to official Claude Code documentation and source code:

| Event | Exists? | Description |
|-------|---------|-------------|
| `PreToolUse` | ✅ YES | Before tool execution |
| `PostToolUse` | ✅ YES | After tool execution |
| `SessionStart` | ✅ YES | When a new session starts |
| `SessionEnd` | ✅ YES | When a session ends |
| `UserPromptSubmit` | ✅ YES | When user submits a prompt |
| `Stop` | ✅ YES | When the agent stops |
| `SubagentStop` | ✅ YES | When a subagent stops |
| `PreCompact` | ✅ YES | **Before context compaction** |
| `Notification` | ✅ YES | For notifications |
| **`PostCompact`** | ❌ **NO** | **DOES NOT EXIST** |

## PostCompact Feature Request

**GitHub Issue**: [#14258 - PostCompact Hook Event](https://github.com/anthropics/claude-code/issues/14258)

**Status**: OPEN (Feature Request, December 2025)

**Summary**: Users are requesting a `PostCompact` hook that would fire AFTER compaction completes, but this feature has NOT been implemented yet.

**Related Issues**:
- [#3612](https://github.com/anthropics/claude-code/issues/3612) - Earlier request (July 2025)
- [#15923](https://github.com/anthropics/claude-code/issues/15923) - PreCompact request (December 2025)

## Correct Pattern for Post-Compaction Restoration

Since `PostCompact` does NOT exist, use `SessionStart` event instead:

### Architecture

```
┌─────────────────────────────────────────────────┐
│  Claude Code Detects Context ≥90%               │
└───────────────┬─────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────┐
│  PreCompact Event (ONLY compact event)          │
│  → pre-compact-handoff.sh                       │
│  • Saves ledger to ~/.ralph/ledgers/            │
│  • Saves handoff to ~/.ralph/handoffs/          │
│  • Saves plan-state.json                        │
└───────────────┬─────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────┐
│  Claude Code Compacts Context                   │
│  • Old messages are removed                     │
│  • Recent messages are kept                     │
└───────────────┬─────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────┐
│  SessionStart Event (AFTER compaction)          │
│  → session-start-restore-context.sh             │
│  • Loads most recent ledger                     │
│  • Loads handoff if exists                      │
│  • Restores plan-state.json                     │
│  • Injects context into new session             │
└─────────────────────────────────────────────────┘
```

### Implementation

**PreCompact Hook** (runs BEFORE compaction):
```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/pre-compact-handoff.sh"
          }
        ]
      }
    ]
  }
}
```

**SessionStart Hook** (runs AFTER compaction, in new session):
```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/session-start-restore-context.sh"
          }
        ]
      }
    ]
  }
}
```

## Common Mistakes

### ❌ WRONG: Adding PostCompact to settings.json

```json
{
  "hooks": {
    "PostCompact": [  // ❌ ERROR: Invalid key
      {
        "hooks": [...]
      }
    ]
  }
}
```

**Result**: Claude Code will fail to load settings with "Invalid key in record" error.

### ❌ WRONG: Documenting PostCompact as existing

Do NOT create documentation that mentions `PostCompact` as a valid event. This creates confusion and leads to implementation errors.

### ✅ CORRECT: Using SessionStart for post-compaction restoration

```json
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "command": "/path/to/pre-compact-handoff.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "hooks": [
          {
            "command": "/path/to/session-start-restore-context.sh"
          }
        ]
      }
    ]
  }
}
```

## Verification

To verify which events are valid in your Claude Code version:

```bash
# Check official docs
npx -y zai-cli search "Claude Code hooks events" --count 5

# Or check hooks documentation
/docs hooks
```

## Ralph v2.81.1 Implementation

**Current Configuration** (Correct):
```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/alfredolopez/.claude-sneakpeek/zai/config/hooks/pre-compact-handoff.sh"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/session-start-ledger.sh"
          },
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/auto-migrate-plan-state.sh"
          },
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/auto-sync-global.sh"
          },
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/session-start-restore-context.sh"
          }
        ]
      }
    ]
  }
}
```

**Key Points**:
- ✅ `PreCompact` exists and saves state before compaction
- ✅ `SessionStart` exists and restores state after compaction (new session)
- ✅ `PostCompact` does NOT exist and is NOT used
- ✅ Plan state survives compaction via PreCompact save + SessionStart restore

## Principle: "The Plan Survives Execution"

The current implementation ensures:
1. Plan state is saved in `PreCompact` (before compaction)
2. Plan state is restored in `SessionStart` (after compaction, new session)
3. Plan maintains consistency across compaction boundaries
4. NO `PostCompact` event is used (because it doesn't exist)

## Historical Context

### Session 2026-01-29: PostCompact Error Discovery

During the compact hooks fix (v2.81.1), we discovered that:
1. `PostCompact` was attempted to be added to settings.json
2. This caused "Invalid key in record" error
3. Research revealed `PostCompact` is a feature request, not implemented
4. Solution: Use `SessionStart` for post-compaction restoration

**Documentation Created**:
- `docs/hooks/COMPACT_HOOKS_FIX_v2.81.1.md` - Documents the discovery
- `docs/hooks/POSTCOMPACT_DOES_NOT_EXIST.md` - This file

### Session 2026-01-30: Orchestrator Ignored Documentation

The `/orchestrator` command INCORRECTLY created documentation mentioning `PostCompact` as valid, ignoring the previous session's findings. This led to:
1. Creation of incorrect files (since deleted)
2. Confusion about hook events
3. Need for clearer documentation

**Lesson**: Always check existing documentation before implementing hooks.

## References

- **Official Docs**: Claude Code hooks documentation (via `/docs hooks`)
- **GitHub Issue**: [#14258](https://github.com/anthropics/claude-code/issues/14258) - PostCompact feature request
- **Related**: `COMPACT_HOOKS_FIX_v2.81.1.md` - Discovery that PostCompact doesn't exist
- **Implementation**: `.claude/hooks/session-start-restore-context.sh` - Correct implementation
- **Configuration**: `~/.claude-sneakpeek/zai/config/settings.json` - Current working config

---

**IMPORTANT**: If you see ANY documentation mentioning `PostCompact` as a valid event, it is INCORRECT and should be updated or deleted.

**Last Updated**: 2026-01-30
**Validated By**: Claude Code (GLM-4.7) + Official Documentation + GitHub Issues
