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

## Marketplace Plugin Directory Structure

For the claude-mem plugin to work correctly with zai's plugin system, the marketplace directory structure must be properly set up with symlinks pointing to the cached plugin files.

### Required Directory Structure

```
~/.claude/plugins/marketplaces/thedotmack/
└── package.json -> ~/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/package.json
```

### Setup Commands

```bash
# Create the marketplace directory structure
mkdir -p "/Users/alfredolopez/.claude/plugins/marketplaces/thedotmack"

# Create symlink from cache to marketplace for package.json
ln -s "/Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/package.json" \
      "/Users/alfredolopez/.claude/plugins/marketplaces/thedotmack/package.json"
```

### CLAUDE_PLUGIN_ROOT Environment Variable

The `CLAUDE_PLUGIN_ROOT` environment variable is automatically set by zai's plugin system and points to the root directory of the currently executing plugin.

```bash
# Verify the variable is set correctly
echo $CLAUDE_PLUGIN_ROOT
# Expected output: /Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10
```

**Usage in Hooks**:
- The `${CLAUDE_PLUGIN_ROOT}` variable expands to the plugin's installation directory
- All plugin-relative paths should be referenced from this root
- **Critical**: Use the subshell pattern `(cd "${CLAUDE_PLUGIN_ROOT}" && ...)` for reliable path resolution

**Why This Matters**:
- zai automatically sets this variable when executing plugin hooks
- Different plugin versions have different `CLAUDE_PLUGIN_ROOT` values
- Hooks must use this variable rather than hardcoding paths

### Why This Structure Is Needed

1. **Plugin Discovery**: zai's plugin system looks for `package.json` in the marketplace directory to discover available plugins
2. **Version Management**: The symlink allows the marketplace to reference the specific version cached in the plugins directory
3. **Update Safety**: When claude-mem updates to a new version (e.g., 9.0.11), only the symlink target needs to be updated
4. **Environment Variable**: The correct `CLAUDE_PLUGIN_ROOT` is automatically set based on the symlinked version

### Verification

```bash
# Verify the symlink exists and points to the correct location
ls -la "/Users/alfredolopez/.claude/plugins/marketplaces/thedotmack/package.json"
# Expected output: package.json -> /Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/package.json

# Verify the target file exists
cat "/Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/package.json" | jq '.name'
# Expected output: "claude-mem"

# Verify CLAUDE_PLUGIN_ROOT is set correctly
echo $CLAUDE_PLUGIN_ROOT
# Expected output: /Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10
```

### Generic Setup Pattern

For different usernames, adjust the paths accordingly:

```bash
# Variables
USERNAME="your-username"
CACHE_DIR="/Users/${USERNAME}/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10"
MARKETPLACE_DIR="/Users/${USERNAME}/.claude/plugins/marketplaces/thedotmack"

# Create directory
mkdir -p "${MARKETPLACE_DIR}"

# Create symlink
ln -s "${CACHE_DIR}/package.json" "${MARKETPLACE_DIR}/package.json"
```

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
