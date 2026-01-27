# Claude HUD MCP Detection Fix

## Problem

Claude HUD was not detecting MCP servers, showing `0 MCPs` in the statusline despite having multiple MCPs configured.

## Root Cause

Claude HUD's `config-reader.ts` searches for MCP configuration in specific locations:

```typescript
// ~/.claude.json (user scope)
function getMcpServerNames(filePath: string): Set<string> {
  const config = JSON.parse(content);
  if (config.mcpServers && typeof config.mcpServers === 'object') {
    return new Set(Object.keys(config.mcpServers));
  }
}
```

**Search locations:**
- `~/.claude/settings.json` → `config.mcpServers`
- `~/.claude.json` → `config.mcpServers`
- `{project}/.mcp.json` → `config.mcpServers`
- `{project}/.claude/settings.json` → `config.mcpServers`

**The issue:** Zai variant stores MCP config in:
- `~/.claude-sneakpeek/zai/config/.claude.json` ✅ (contains `mcpServers`)
- `~/.claude.json` ❌ (only contains user config: features flags, userID)

## Solution

Create a symlink from the expected location to the actual Zai config file:

```bash
# Backup existing file
mv ~/.claude.json ~/.claude.json.backup-before-zai-symlink

# Create symlink
ln -s ~/.claude-sneakpeek/zai/config/.claude.json ~/.claude.json
```

## Verification

After symlink creation, Claude HUD can now detect **11 MCP servers**:

| MCP Server | Type |
|------------|------|
| context7 | stdio |
| filesystem | stdio |
| gordon | stdio (docker) |
| mermaid | stdio |
| nanobanana | stdio |
| playwright | stdio |
| web-reader | http (Z.ai) |
| web-search | stdio |
| web-search-prime | http (Z.ai) |
| zai-mcp-server | stdio |
| zread | http (Z.ai) |

## Related Files

- Claude HUD config reader: `~/.claude-sneakpeek/zai/config/plugins/marketplaces/claude-hud/src/config-reader.ts`
- Zai MCP config: `~/.claude-sneakpeek/zai/config/.claude.json`

## Date Fixed

2026-01-27
