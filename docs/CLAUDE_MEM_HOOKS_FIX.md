# Claude-Mem Hooks Fix - CLAUDE_PLUGIN_ROOT Path Resolution

> **Issue**: Bun cannot resolve `${CLAUDE_PLUGIN_ROOT}` correctly when used as part of a path argument
> **Affected**: claude-mem plugin v9.0.10 (and likely earlier/later versions)
> **Fixed**: 2026-01-28

## Problem Description

The claude-mem plugin's `hooks.json` file contains commands that fail because Bun interprets `${CLAUDE_PLUGIN_ROOT}` incorrectly when passed as a path argument.

### Error Pattern

```json
{
  "command": "bun \"${CLAUDE_PLUGIN_ROOT}/scripts/worker-service.cjs\" start"
}
```

**Result**: `error: Module not found "/scripts/worker-service.cjs"`

The variable expands correctly, but Bun strips the base path and only sees `/scripts/...`.

### Root Cause

When Bun receives a command like:
```bash
bun "/full/path/to/plugin/scripts/worker-service.cjs" start
```

It incorrectly resolves the module path, losing the base directory context.

## Solution

### Correct Pattern

Wrap the command in a subshell that changes to the plugin directory first:

```json
{
  "command": "(cd \"${CLAUDE_PLUGIN_ROOT}\" && bun scripts/worker-service.cjs start)"
}
```

### Why This Works

1. **Subshell `(cd ...)`**: Isolates the directory change, doesn't affect parent shell
2. **Relative path**: `scripts/worker-service.cjs` resolves correctly from plugin root
3. **Bun execution**: Bun now has correct working directory for module resolution

## Applied Changes

**IMPORTANT**: Two files must be updated for the fix to persist:

1. **Cache Location** (runtime):
   `~/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/hooks/hooks.json`

2. **Marketplace Location** (source for updates):
   `~/.claude-sneakpeek/zai/config/plugins/marketplaces/thedotmack/plugin/hooks/hooks.json`

> **Why both?** When claude-mem updates or reinstalls, it copies from marketplace to cache. If only the cache is fixed, the fix is lost on update.

### Before (Incorrect)
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "bun \"${CLAUDE_PLUGIN_ROOT}/scripts/worker-service.cjs\" start",
        "timeout": 60
      }]
    }]
  }
}
```

### After (Correct)
```json
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "(cd \"${CLAUDE_PLUGIN_ROOT}\" && bun scripts/worker-service.cjs start)",
        "timeout": 60
      }]
    }]
  }
}
```

## All Affected Hooks

| Hook Event | Commands Fixed |
|------------|----------------|
| SessionStart | `start`, `hook claude-code context`, `hook claude-code user-message` |
| UserPromptSubmit | `start`, `hook claude-code session-init` |
| PostToolUse | `start`, `hook claude-code observation` |
| Stop | `start`, `hook claude-code summarize` |

**Total**: 9 commands across 4 hook events

## Verification

### Test Command
```bash
cd "${CLAUDE_PLUGIN_ROOT}" && bun scripts/worker-service.cjs start
```

### Expected Output
```json
{"continue":true,"suppressOutput":true,"status":"ready"}
```

## Auto-Detection Pattern

To help Claude Code/z.ai detect and apply this fix automatically:

### Detection Regex
```bash
# Find incorrect patterns
grep -r 'bun "\${CLAUDE_PLUGIN_ROOT}/scripts/worker-service' ~/.claude-sneakpeek/zai/config/plugins/
```

### Auto-Fix Script
```bash
#!/bin/bash
# Find and fix ALL claude-mem hooks.json files
find ~/.claude-sneakpeek/zai/config/plugins -name "hooks.json" -path "*/claude-mem/*" | while read file; do
    echo "Fixing: $file"
    cp "$file" "$file.backup"
    # Apply fix using proper JSON-aware tool or manual edit
    sed -i '' 's/bun "\${CLAUDE_PLUGIN_ROOT}\/scripts\/worker-service\.cjs"\(.*\)/(cd "\${CLAUDE_PLUGIN_ROOT}" \&\& bun scripts\/worker-service\.cjs\1)/g' "$file"
done
```

**Or use the provided script**:
```bash
./.claude/scripts/fix-claude-mem-hooks.sh
```

## Version Compatibility

| claude-mem Version | Status |
|-------------------|--------|
| v9.0.10 | ✅ Tested & Fixed (both cache + marketplace) |
| Future versions | ⚠️ May need manual re-application |

**Protection Strategy**: The marketplace file should be updated to prevent the issue from returning on updates.

## Related Issues

- Bun module resolution with absolute paths
- Plugin hook execution context
- Environment variable expansion in shell commands

## References

- **Plugin Path**: `~/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/`
- **Original Hooks File**: `hooks/hooks.json`
- **Worker Service**: `scripts/worker-service.cjs`

---

**Note for claude-mem updates**: When claude-mem updates, this fix may need to be re-applied if the update overwrites `hooks.json`.
