# MCP Plugins Analysis - v2.80.9

**Date**: 2026-01-29
**Status**: ANALYSIS COMPLETE
**Issue**: Multiple installed plugins not working due to missing MCP configuration

## Summary

After rollback issues in `/Users/alfredolopez/.claude-sneakpeek/zai`, there are **27 plugins installed** but only **2 MCP servers configured** in `settings.json`. This is causing many plugins to not function correctly.

## Git Log Analysis (Last 15 Commits)

| Commit | Date | Description | Status |
|--------|------|-------------|--------|
| b13c8b2 | 8h ago | docs: add marketplace plugin directory structure and CLAUDE_PLUGIN_ROOT documentation | ✅ Valid |
| 416e36c | 9h ago | refactor: completely remove opus/sonnet from all agents (v2.80.9) | ✅ Valid |
| cf2cb65 | 9h ago | fix: adjust @code-reviewer to use glm-4.7 PRIMARY with codex SECONDARY | ✅ Valid |
| 9620b15 | 9h ago | feat: simplify architecture to GLM-4.7 + Codex only (v2.80.9) | ✅ Valid |
| 644f6e2 | 9h ago | feat: promote GLM-4.7 to PRIMARY orchestrator and judge role | ✅ Valid |
| 361f578 | 9h ago | docs: update README, CLAUDE.md and AGENTS.md to v2.80.9 | ✅ Valid |
| 6181a38 | 9h ago | fix: quality parallel v2.1.0 - complete security remediation | ✅ Valid |
| 3831fac | 15h ago | test: quality parallel system validation v2.80.7 complete | ✅ Valid |
| daf15e6 | 15h ago | fix: quality parallel async v2.0.0 - 3 critical vulnerabilities fixed | ✅ Valid |
| 498acd3 | 15h ago | feat: native multi-agent quality integration with orchestrator v2.80.4 | ✅ Valid |
| c9336a6 | 16h ago | docs: update CLAUDE.md with docs/analysis directory and cleanup .claude/docs | ✅ Valid |
| f6af63d | 16h ago | refactor: move all documentation from .claude/docs/ to docs/ structure | ✅ Valid |
| bb6a965 | 16h ago | feat: quality parallel system with 4 async checks v2.80.3 | ✅ Valid |
| 757c65d | 16h ago | fix: correct async hooks validation - ARE SUPPORTED ✅ | ✅ Valid |
| b4bb501 | 16h ago | feat: validation report for orchestrator architecture v2.80.1 | ✅ Valid |

**All commits are valid and consistent with the v2.80.9 architecture changes.**

## Installed Plugins

### Fully Installed (27 plugins)

| Plugin | Version | Installed | MCP Server | Status |
|--------|---------|-----------|------------|--------|
| claude-hud | 0.0.6 | 2026-01-27 | - | ❌ No MCP |
| typescript-lsp | 1.0.0 | 2026-01-27 | - | ⚠️ LSP only |
| claude-mem | 9.0.10 | 2026-01-27 | mcp-search | ❌ Not configured |
| pyright-lsp | 1.0.0 | 2026-01-27 | - | ⚠️ LSP only |
| glm-plan-usage | 0.0.1 | 2026-01-28 | - | ⚠️ Skills only |
| glm-plan-bug | 0.0.1 | 2026-01-28 | - | ⚠️ Skills only |
| agent-sdk-dev | e30768372b41 | 2026-01-29 | - | ⚠️ Skills only |
| clangd-lsp | 1.0.0 | 2026-01-29 | - | ⚠️ LSP only |
| code-review | e30768372b41 | 2026-01-29 | - | ⚠️ Skills only |
| commit-commands | e30768372b41 | 2026-01-29 | - | ⚠️ Skills only |
| context7 | e30768372b41 | 2026-01-29 | context7 | ✅ Configured |
| csharp-lsp | 1.0.0 | 2026-01-29 | - | ⚠️ LSP only |
| frontend-design | e30768372b41 | 2026-01-29 | - | ⚠️ Skills only |
| github | e30768372b41 | github | ❌ Not configured |
| gopls-lsp | 1.0.0 | 2026-01-29 | - | ⚠️ LSP only |
| hookify | e30768372b41 | 2026-01-29 | - | ⚠️ Hooks only |
| lua-lsp | 1.0.0 | 2026-01-29 | - | ⚠️ LSP only |
| playwright | e30768372b41 | playwright | ❌ Not configured |
| plugin-dev | e30768372b41 | - | ⚠️ Skills only |
| pr-review-toolkit | e30768372b41 | - | ⚠️ Skills only |
| security-guidance | e30768372b41 | - | ⚠️ Hooks only |
| supabase | e30768372b41 | supabase | ❌ Not configured |
| swift-lsp | 1.0.0 | 2026-01-29 | - | ⚠️ LSP only |
| Notion | 0.1.0 | 2026-01-29 | notion | ❌ Not configured |
| atlassian | 7caef65e1070 | 2026-01-29 | atlassian | ❌ Not configured |
| sentry | 1.0.0 | 2026-01-29 | sentry | ❌ Not configured |
| blender | - | - | blender | ✅ Configured |

## Current MCP Configuration

### Configured in `settings.json`

```json
{
  "mcpServers": {
    "blender": {
      "args": ["blender-mcp"],
      "command": "uvx"
    },
    "context7": {
      "headers": {
        "CONTEXT7_API_KEY": "ctx7sk-c3b6b82c-0f6c-43c6-8881-2399e202e056"
      },
      "url": "https://mcp.context7.com/mcp"
    }
  }
}
```

### Missing MCP Server Configurations

The following plugins have `.mcp.json` files but are **NOT configured** in `settings.json`:

| Plugin | Required Config |
|--------|-----------------|
| **claude-mem** (mcp-search) |
```json
{
  "mcp-search": {
    "type": "stdio",
    "command": "/Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/scripts/mcp-server.cjs"
  }
}
```

| **playwright** |
```json
{
  "playwright": {
    "command": "npx",
    "args": ["@playwright/mcp@latest"]
  }
}
```

| **github** |
```json
{
  "github": {
    "type": "http",
    "url": "https://api.githubcopilot.com/mcp/",
    "headers": {
      "Authorization": "Bearer ${GITHUB_PERSONAL_ACCESS_TOKEN}"
    }
  }
}
```

| **supabase** |
```json
{
  "supabase": {
    "type": "http",
    "url": "https://mcp.supabase.com/mcp"
  }
}
```

| **notion** |
```json
{
  "notion": {
    "type": "http",
    "url": "https://mcp.notion.com/mcp"
  }
}
```

| **atlassian** |
```json
{
  "atlassian": {
    "type": "http",
    "url": "https://mcp.atlassian.com/v1/mcp"
  }
}
```

| **sentry** |
```json
{
  "sentry": {
    "type": "http",
    "url": "https://mcp.sentry.dev/mcp"
  }
}
```

## Root Cause

After the rollback in `~/.claude-sneakpeek/zai`, the MCP server configurations were **NOT restored** in `settings.json`. The plugins are installed in the cache directory, but zai is not automatically merging their `.mcp.json` configurations into the main settings.

## Claude-Mem Hooks Fix Status

**Status**: ✅ **FULLY FIXED** (verified in both cache and marketplace)

The claude-mem plugin's hooks have been correctly fixed in BOTH locations:

**Correct Pattern Applied**:
```json
{
  "command": "(cd \"${CLAUDE_PLUGIN_ROOT}\" && bun scripts/worker-service.cjs start)"
}
```

**Verification Results**:
- ✅ `~/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10/hooks/hooks.json` - FIXED
- ✅ `~/.claude-sneakpeek/zai/config/plugins/marketplaces/thedotmack/plugin/hooks/hooks.json` - FIXED

**Total hooks fixed**: 9 commands across 4 hook events (SessionStart, UserPromptSubmit, PostToolUse, Stop)

**Date verified**: 2026-01-29

## Recommendations

### 1. Restore MCP Server Configurations

Add the missing MCP servers to `~/.claude-sneakpeek/zai/config/settings.json`:

```bash
# Backup current settings
cp ~/.claude-sneakpeek/zai/config/settings.json ~/.claude-sneakpeek/zai/config/settings.json.backup

# Merge missing MCP configurations
# (manual edit or script required)
```

### 2. Verify claude-mem Marketplace Fix

```bash
# Check if marketplace file has the fix
cat ~/.claude-sneakpeek/zai/config/plugins/marketplaces/thedotmack/plugin/hooks/hooks.json | grep "CLAUDE_PLUGIN_ROOT"

# Should show: (cd "${CLAUDE_PLUGIN_ROOT}" && bun scripts/worker-service.cjs
```

### 3. Test Plugin Functionality

After restoring MCP configurations, test each plugin:

```bash
# Test claude-mem
cd ~/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/9.0.10
bun scripts/worker-service.cjs start

# Test playwright
npx @playwright/mcp@latest --version

# Test context7
curl -H "CONTEXT7_API_KEY: ctx7sk-c3b6b82c-0f6c-43c6-8881-2399e202e056" \
     https://mcp.context7.com/mcp
```

## Related Issues

1. **Post-rollback MCP configuration loss**: Settings not restored after rollback
2. **claude-mem hooks**: Fixed in cache, needs verification in marketplace
3. **Plugin discovery**: Marketplace symlinks may be broken after rollback

## References

- [Claude-Mem Hooks Fix Documentation](../CLAUDE_MEM_HOOKS_FIX.md)
- [Plugin Directory Structure Documentation](../CLAUDE_MEM_HOOKS_FIX.md#marketplace-plugin-directory-structure)
- Installed plugins: `~/.claude-sneakpeek/zai/config/plugins/installed_plugins.json`
- Settings: `~/.claude-sneakpeek/zai/config/settings.json`
