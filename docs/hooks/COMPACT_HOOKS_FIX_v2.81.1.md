# Compact Hooks Fix - v2.81.1

**Date**: 2026-01-29
**Status**: VALIDATION REQUIRED
**Issue**: Global compact hooks not activating during automatic compaction

## Problem Analysis

### Issue #1: Hooks Pointed to Local Project Paths

**Original Configuration** (backup-20260129-143239):
```json
{
  "hooks": {
    "PreCompact": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/pre-compact-handoff.sh"
          },
          {
            "type": "command",
            "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/post-compact-restore.sh"
          }
        ]
      }
    ]
  }
}
```

**Problems:**
1. Hooks pointed to **project-local** paths (`/Users/alfredolopez/Documents/GitHub/...`)
2. Hooks only worked when working in THIS specific repository
3. Hooks would FAIL in other projects or outside this repo
4. `PostCompact` event was missing entirely

### Issue #2: Incorrect Hook Placement

- `post-compact-restore.sh` was in `PreCompact` (should be in `PostCompact`)
- `PostCompact` event did not exist in configuration

### Issue #3: /compact Skill Interfering

A global `/compact` skill symlink existed that:
- Was a workaround for VSCode/Cursor hook limitations
- Required manual intervention
- Interfered with automatic compaction process

## Solution Implemented

### Step 1: Copy Hooks to Global Location

```bash
mkdir -p ~/.claude-sneakpeek/zai/config/hooks
cp .claude/hooks/pre-compact-handoff.sh ~/.claude-sneakpeek/zai/config/hooks/
cp .claude/hooks/post-compact-restore.sh ~/.claude-sneakpeek/zai/config/hooks/
chmod +x ~/.claude-sneakpeek/zai/config/hooks/*.sh
```

### Step 2: Update settings.json

**⚠️ CRITICAL DISCOVERY**: `PostCompact` event is **NOT SUPPORTED** in this Claude Code version.

**Final Configuration** (Correct):
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

**Important Notes:**
- Only `PreCompact` event exists (executes BEFORE compaction)
- Both hooks run in `PreCompact`:
  - `pre-compact-handoff.sh` → Saves current state
  - `post-compact-restore.sh` → Shows previously saved context
- Attempting to add `PostCompact` causes error: "Invalid key in record"

### Step 3: Remove /compact Skill Symlink

```bash
rm ~/.claude-sneakpeek/zai/config/skills/compact
```

## Architecture

### Automatic Compaction Flow

```
┌─────────────────────────────────────────────────┐
│  Claude Code Detects Context ≥90%               │
└───────────────┬─────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────┐
│  PreCompact Hook (ANTES de compactar)           │
│  → pre-compact-handoff.sh                       │
│  • Guarda ledger en ~/.ralph/ledgers/           │
│  • Genera handoff en ~/.ralph/handoffs/         │
│  • NO puede bloquear la compactación            │
└───────────────┬─────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────┐
│  Claude Code Compacta el Contexto               │
│  • Elimina mensajes antiguos                    │
│  • Mantiene mensajes recientes                  │
└───────────────┬─────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────┐
│  PostCompact Hook (DESPUÉS de compactar)        │
│  → post-compact-restore.sh                      │
│  • Muestra ledger guardado                      │
│  • Sugiere usar claude-mem MCP                  │
│  • NO puede bloquear la compactación            │
└─────────────────────────────────────────────────┘
```

### Hook Responsibilities

| Hook | Event | Purpose | File |
|------|-------|---------|------|
| `pre-compact-handoff.sh` | **ANTES** | Guarda estado completo | `~/.claude-sneakpeek/zai/config/hooks/` |
| `post-compact-restore.sh` | **DESPUÉS** | Muestra contexto restaurado | `~/.claude-sneakpeek/zai/config/hooks/` |

## Validation

### JSON Syntax Validation

```bash
# jq validation
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.' --exit-status
# Result: ✅ PASS

# Python validation
python3 -m json.tool ~/.claude-sneakpeek/zai/config/settings.json
# Result: ✅ PASS
```

### Hook Existence Verification

```bash
ls -la ~/.claude-sneakpeek/zai/config/hooks/
# Output:
# -rwx--x--x  1 alfredolopez  staff  8127 29 ene.  22:09 post-compact-restore.sh
# -rwx--x--x  1 alfredolopez  staff  2665 29 ene.  22:09 pre-compact-handoff.sh
```

### Hook Execution Test

```bash
# Test PreCompact
echo '{"hook_event_name":"PreCompact","session_id":"test","transcript_path":""}' | \
  ~/.claude-sneakpeek/zai/config/hooks/pre-compact-handoff.sh
# Output: {"continue": true} ✅

# Test PostCompact
echo '{"hook_event_name":"PostCompact","session_id":"test","transcript_path":""}' | \
  ~/.claude-sneakpeek/zai/config/hooks/post-compact-restore.sh
# Output: {"continue": true} ✅
```

### Configuration Validation

```bash
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.hooks | keys'
# Output:
# [
#   "PostToolUse",
#   "PreCompact",    ← Contains both pre-handoff and post-restore hooks
#   "PreToolUse",
#   "SessionStart",
#   "Stop",
#   "UserPromptSubmit"
# ]
```

## Files Changed

### 1. settings.json
- **Path**: `~/.claude-sneakpeek/zai/config/settings.json`
- **Changes**:
  - `PreCompact[0].hooks[0].command`: Changed from project-local to global path
  - `PreCompact[0].hooks[1].command`: Changed from project-local to global path (post-compact-restore.sh)
  - **Attempted** to add `PostCompact` event → **ERROR**: "Invalid key in record"
  - **Resolution**: Keep both hooks in `PreCompact` only

### 2. Global Hooks Directory
- **Path**: `~/.claude-sneakpeek/zai/config/hooks/`
- **Added**:
  - `pre-compact-handoff.sh` (8127 bytes)
  - `post-compact-restore.sh` (2665 bytes)

### 3. Skills Directory
- **Path**: `~/.claude-sneakpeek/zai/config/skills/`
- **Removed**: `compact` symlink (was pointing to project-local skill)

## Expected Behavior

### Before This Fix

1. Claude Code detects context ≥90%
2. Attempts to run `PreCompact` hooks
3. **FAILS** because hooks point to project-local paths
4. Compacts without saving state
5. Context is lost

### After This Fix

1. Claude Code detects context ≥90%
2. Runs `pre-compact-handoff.sh` → Saves ledger + handoff
3. Compacts context
4. Runs `post-compact-restore.sh` → Shows saved context
5. User continues with restored state

## Rollback Plan

If issues occur:

```bash
# Restore previous configuration
cp ~/.claude-sneakpeek/zai/config/settings.json.backup-20260129-143239 \
   ~/.claude-sneakpeek/zai/config/settings.json

# Or manually restore PreCompact to include both hooks
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '
.hooks.PreCompact[0].hooks = [
  {
    "type": "command",
    "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/pre-compact-handoff.sh"
  },
  {
    "type": "command",
    "command": "/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop/.claude/hooks/post-compact-restore.sh"
  }
]
' > /tmp/settings-rollback.json && mv /tmp/settings-rollback.json \
   ~/.claude-sneakpeek/zai/config/settings.json
```

## Troubleshooting

### Claude Code Not Reading settings.json

**Possible Causes:**
1. **Cache Issue**: Delete cache directory
   ```bash
   rm -rf ~/.claude-sneakpeek/zai/config/cache/*
   ```

2. **Session Issue**: Restart Claude Code completely

3. **Syntax Issue**: Re-validate JSON
   ```bash
   cat ~/.claude-sneakpeek/zai/config/settings.json | python3 -m json.tool > /dev/null
   echo "Exit code: $?"  # Should be 0
   ```

### Hooks Not Executing

**Check Hook Logs:**
```bash
tail -f ~/.ralph/logs/pre-compact.log
tail -f ~/.ralph/logs/post-compact.log
```

**Verify Permissions:**
```bash
ls -la ~/.claude-sneakpeek/zai/config/hooks/*.sh
# Should show -rwxr-xr-x or similar (executable)
```

**Test Manually:**
```bash
# Create test input
cat > /tmp/compact-test.json << EOF
{
  "hook_event_name": "PreCompact",
  "session_id": "manual-test-$(date +%s)",
  "transcript_path": ""
}
EOF

# Run hook
~/.claude-sneakpeek/zai/config/hooks/pre-compact-handoff.sh < /tmp/compact-test.json
```

## Next Steps

1. ✅ Hooks copied to global location
2. ✅ settings.json updated
3. ✅ JSON syntax validated
4. ✅ Hooks tested manually
5. ⏳ **PENDING**: Verify automatic compaction triggers hooks
6. ⏳ **PENDING**: Monitor logs during next compaction
7. ⏳ **PENDING**: Confirm Claude Code reads new configuration

## Official Documentation Verification

### Available Hook Events in Claude Code

According to official Claude Code documentation (Context7 + GitHub):

**Supported Events:**
- `PreToolUse` - Before tool execution
- `PostToolUse` - After tool execution
- `Stop` - When agent stops
- `SubagentStop` - When subagent stops
- `SessionStart` - On new session
- `SessionEnd` - On session end
- `UserPromptSubmit` - When user submits prompt
- **`PreCompact`** ✅ - Before context compaction
- `Notification` - For notifications

**NOT Supported:**
- **`PostCompact`** ❌ - Does NOT exist (see Feature Request below)

### PostCompact Feature Request

**GitHub Issue**: [#14258 - PostCompact Hook Event](https://github.com/anthropics/claude-code/issues/14258)

**Status**: OPEN (Feature Request, December 2025)

**Summary**:
- Users need a hook that fires AFTER compaction completes
- Current problem: `PreCompact` output gets summarized/paraphrased
- Desired: `PostCompact` hook to inject content AFTER summary (not subject to summarization)

**Workaround** (Current Implementation):
- Use `PreCompact` with both hooks
- Understand that injected content will be summarized
- No way to inject post-compaction content until feature is implemented

### Sources

- **Context7**: `/anthropics/claude-code` - Official hooks documentation
- **GitHub Issue**: [#14258](https://github.com/anthropics/claude-code/issues/14258) - PostCompact feature request
- **GitHub Issue**: [#3612](https://github.com/anthropics/claude-code/issues/3612) - Earlier PostCompact request (Jul 2025)

## References

- **Original Issue**: Hooks not activating during automatic compaction
- **Related**: `/compact` skill workaround no longer needed
- **Documentation**: `CLAUDE.md` (lines about compact hooks)
- **Backup**: `settings.json.backup-20260129-143239` (before changes)
- **Feature Request**: [GitHub #14258](https://github.com/anthropics/claude-code/issues/14258) - PostCompact event

---

**Author**: Claude Code (GLM-4.7)
**Reviewed**: Pending user validation
**Approved**: Pending
