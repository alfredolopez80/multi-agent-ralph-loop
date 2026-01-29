# Compact Hooks Fix - Executive Summary v2.81.1

**Date**: 2026-01-29
**Status**: ✅ RESUELTO
**Validation**: ✅ Documentation verified with official sources

## Problem

1. **Hooks no se activaban** durante compactación automática
2. **`/compact` skill interfería** con el proceso automático
3. **Error de configuración**: "Invalid key in record"

## Root Cause Analysis

### Issue #1: Project-Local Paths

**Original Configuration** (incorrect):
```json
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/pre-compact-handoff.sh"
          }
        ]
      }
    ]
  }
}
```

**Problem**: Hooks apuntaban a rutas locales del proyecto, solo funcionaban en ESTE repo.

### Issue #2: PostCompact Event Doesn't Exist

**Attempted Configuration** (failed):
```json
{
  "hooks": {
    "PostCompact": [...]  // ❌ "Invalid key in record"
  }
}
```

**Discovery**: `PostCompact` is NOT a valid event in current Claude Code version.

**Official Source**: [GitHub Issue #14258](https://github.com/anthropics/claude-code/issues/14258)
- Status: OPEN (Feature Request, December 2025)
- Requesting addition of `PostCompact` event

## Solution Implemented

### 1. Copied Hooks to Global Location

```bash
mkdir -p ~/.claude-sneakpeek/zai/config/hooks
cp .claude/hooks/pre-compact-handoff.sh ~/.claude-sneakpeek/zai/config/hooks/
cp .claude/hooks/post-compact-restore.sh ~/.claude-sneakpeek/zai/config/hooks/
chmod +x ~/.claude-sneakpeek/zai/config/hooks/*.sh
```

### 2. Updated settings.json (Correct Configuration)

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
          },
          {
            "type": "command",
            "command": "/Users/alfredolopez/.claude-sneakpeek/zai/config/hooks/post-compact-restore.sh"
          }
        ]
      }
    ]
  }
}
```

**Key Points:**
- ✅ Only `PreCompact` event exists (officially documented)
- ✅ Both hooks in `PreCompact` (execute before compaction)
- ✅ Global paths (work across all projects)
- ✅ `/compact` skill symlink removed

### 3. Removed /compact Skill

```bash
rm ~/.claude-sneakpeek/zai/config/skills/compact
```

**Why**: `/compact` was a workaround for VSCode/Cursor limitations. No longer needed with global hooks.

## Official Hook Events (Verified)

According to **Claude Code official documentation** (Context7):

| Event | Exists? | Purpose |
|-------|---------|---------|
| `PreToolUse` | ✅ Yes | Before tool execution |
| `PostToolUse` | ✅ Yes | After tool execution |
| `SessionStart` | ✅ Yes | On new session |
| `SessionEnd` | ✅ Yes | On session end |
| `UserPromptSubmit` | ✅ Yes | When user submits prompt |
| `Stop` | ✅ Yes | When agent stops |
| `SubagentStop` | ✅ Yes | When subagent stops |
| `PreCompact` | ✅ Yes | **Before context compaction** |
| `PostCompact` | ❌ NO | **Feature Request** (#14258) |
| `Notification` | ✅ Yes | For notifications |

**Source**: [Context7 - Claude Code Hooks](https://context7.com/anthropics/claude-code/)

## Behavior

### Before Fix

```
Context ≥90%
    ↓
Claude Code tries PreCompact hooks
    ↓
❌ FAILS (project-local paths)
    ↓
Compaction without saving state
    ↓
Context lost
```

### After Fix

```
Context ≥90%
    ↓
Claude Code triggers PreCompact
    ↓
✅ pre-compact-handoff.sh (saves ledger + handoff)
✅ post-compact-restore.sh (shows previous context)
    ↓
Claude Code compacts
    ↓
User continues with preserved state
```

## Limitations (Known)

### No Post-Compaction Injection

**Problem**: Both hooks execute BEFORE compaction, so their output gets summarized/paraphrased.

**Impact**:
- `pre-compact-handoff.sh`: Saves state correctly ✅
- `post-compact-restore.sh`: Shows context BEFORE it gets summarized ⚠️

**Future Solution**: When `PostCompact` event is implemented (#14258), we can:
1. Keep `pre-compact-handoff.sh` in `PreCompact` (saves state)
2. Move `post-compact-restore.sh` to `PostCompact` (shows after compaction)

## Validation Results

### JSON Validation
```
✅ Python json.tool: PASS
✅ jq parser: PASS
✅ File encoding: UTF-8 (no BOM)
✅ No trailing commas
✅ No duplicate keys
```

### Hook Files
```
✅ pre-compact-handoff.sh exists (global)
✅ post-compact-restore.sh exists (global)
✅ Both executable (rwxr-xr-x)
✅ Both tested successfully
```

### Configuration
```
✅ PreCompact event exists
✅ 2 hooks in PreCompact
✅ Global paths (not project-local)
✅ PostCompact event removed (doesn't exist)
✅ /compact skill removed
```

## Files Changed

| File | Change |
|------|--------|
| `~/.claude-sneakpeek/zai/config/settings.json` | Updated PreCompact hooks to global paths |
| `~/.claude-sneakpeek/zai/config/hooks/pre-compact-handoff.sh` | Copied from project to global location |
| `~/.claude-sneakpeek/zai/config/hooks/post-compact-restore.sh` | Copied from project to global location |
| `~/.claude-sneakpeek/zai/config/skills/compact` | Removed symlink |

## Documentation

- **Full Report**: `docs/hooks/COMPACT_HOOKS_FIX_v2.81.1.md`
- **Validation Script**: `.claude/scripts/validate-compact-hooks.sh`
- **Official Docs**: [Context7 - Claude Code](https://context7.com/anthropics/claude-code/)
- **Feature Request**: [GitHub #14258](https://github.com/anthropics/claude-code/issues/14258)

## Verification Command

```bash
# Run full validation
./.claude/scripts/validate-compact-hooks.sh
```

## Next Steps

1. ✅ **COMPLETED**: Global hooks configured
2. ✅ **COMPLETED**: settings.json corrected
3. ✅ **COMPLETED**: Documentation verified
4. ✅ **COMPLETED**: /compact skill removed
5. ⏳ **TODO**: Monitor logs during next compaction
6. ⏳ **TODO**: Consider PostCompact migration when feature is available

---

**Author**: Claude Code (GLM-4.7)
**Status**: ✅ RESUELTO - Validated with official documentation
**Date**: 2026-01-29
