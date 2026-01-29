# Plugin Discrepancy Analysis - v2.80.9

**Date**: 2026-01-29
**Status**: **CRITICAL ISSUE FOUND**
**Issue**: 75 "ghost plugins" enabled but not installed after rollback

## Summary

After the rollback in `/Users/alfredolopez/.claude-sneakpeek/zai`, there's a **critical discrepancy** between enabled plugins and actually installed plugins:

| Metric | Count |
|--------|-------|
| **Plugins habilitados** en `settings.json` | 101 |
| **Plugins instalados** en el sistema | 26 |
| **Plugins "fantasmas"** (habilitados pero NO instalados) | **75** |

## Impact

**Critical**: These 75 ghost plugins can cause:
1. **Errors** when Claude Code tries to use non-existent plugins
2. **Confusion** in `/mcp` command output
3. **Performance degradation** from trying to load missing plugins
4. **Inconsistent state** between UI and filesystem

## Plugins INSTALADOS (26) ✅

These plugins are **actually installed** and working:

| Plugin | Version | Installed Date | Source |
|--------|---------|----------------|--------|
| agent-sdk-dev | e30768372b41 | 2026-01-29 | claude-plugins-official |
| atlassian | 7caef65e1070 | 2026-01-29 | claude-plugins-official |
| clangd-lsp | 1.0.0 | 2026-01-29 | claude-plugins-official |
| claude-hud | 0.0.6 | 2026-01-27 | claude-hud |
| claude-mem | 9.0.10 | 2026-01-27 | thedotmack |
| code-review | e30768372b41 | 2026-01-29 | claude-plugins-official |
| commit-commands | e30768372b41 | 2026-01-29 | claude-plugins-official |
| context7 | e30768372b41 | 2026-01-29 | claude-plugins-official |
| csharp-lsp | 1.0.0 | 2026-01-29 | claude-plugins-official |
| frontend-design | e30768372b41 | 2026-01-29 | claude-plugins-official |
| github | e30768372b41 | 2026-01-29 | claude-plugins-official |
| glm-plan-bug | 0.0.1 | 2026-01-28 | zai-coding-plugins |
| glm-plan-usage | 0.0.1 | 2026-01-28 | zai-coding-plugins |
| gopls-lsp | 1.0.0 | 2026-01-29 | claude-plugins-official |
| hookify | e30768372b41 | 2026-01-29 | claude-plugins-official |
| lua-lsp | 1.0.0 | 2026-01-29 | claude-plugins-official |
| Notion | 0.1.0 | 2026-01-29 | claude-plugins-official |
| playwright | e30768372b41 | 2026-01-29 | claude-plugins-official |
| plugin-dev | e30768372b41 | 2026-01-29 | claude-plugins-official |
| pr-review-toolkit | e30768372b41 | 2026-01-29 | claude-plugins-official |
| pyright-lsp | 1.0.0 | 2026-01-27 | claude-plugins-official |
| security-guidance | e30768372b41 | 2026-01-29 | claude-plugins-official |
| sentry | 1.0.0 | 2026-01-29 | claude-plugins-official |
| supabase | e30768372b41 | 2026-01-29 | claude-plugins-official |
| swift-lsp | 1.0.0 | 2026-01-29 | claude-plugins-official |
| typescript-lsp | 1.0.0 | 2026-01-27 | claude-plugins-official |

## Plugins FANTASMAS (75) ⚠️

These plugins are **enabled in settings.json** but **NOT installed**:

### claude-code-workflows (30 plugins)
- api-testing-observability
- application-performance
- backend-api-security
- backend-development
- blockchain-web3
- business-analytics
- cicd-automation
- code-documentation
- code-refactoring
- code-review-ai
- codebase-cleanup
- comprehensive-review
- deployment-strategies
- deployment-validation
- developer-essentials
- documentation-generation
- error-debugging
- error-diagnostics
- feature-dev
- frontend-mobile-development
- frontend-mobile-security
- full-stack-orchestration
- framework-migration
- hr-legal-compliance
- javascript-typescript
- kubernetes-operations

### claude-code-plugins-plus (28 plugins)
- arbitrage-opportunity-finder
- bottleneck-detector
- blockchain-explorer-cli
- browser-compatibility-tester
- capacity-planning-analyzer
- contract-test-validator
- crypto-news-aggregator
- crypto-signal-generator
- deep-learning-optimizer
- defi-yield-optimizer
- devops-automation-pack
- dex-aggregator-router
- docker-compose-generator
- e2e-test-framework
- error-rate-monitor
- formatter
- gas-fee-optimizer
- gdpr-compliance-scanner
- graphql-server-builder
- hipaa-compliance-checker
- hyperparameter-tuner
- liquidity-pool-analyzer
- log-analysis-tool
- market-movers-scanner
- market-price-tracker
- market-sentiment-analyzer
- mempool-analyzer
- metrics-aggregator
- monitoring-stack-deployer
- nft-rarity-analyzer
- on-chain-analytics
- options-flow-analyzer
- owasp-compliance-checker
- project-health-auditor

### trailofbits (13 plugins)
- ask-questions-if-underspecified
- audit-context-building
- building-secure-contracts
- burpsuite-project-parser
- constant-time-analysis
- culture-index
- differential-review
- dwarf-expert
- entry-point-analyzer
- fix-review
- property-based-testing

### Other Marketplaces (4 plugins)
- claude-mermaid (claude-mermaid marketplace)
- context7-plugin (context7-marketplace)
- dev-browser (dev-browser-marketplace)
- polymarket (polymarket-mcp)

### Duplicates/Inconsistent Names (4 plugins)
- code-review@claude-code-plugins (not installed, only @claude-plugins-official)
- commit-commands@claude-code-plugins (not installed, only @claude-plugins-official)
- frontend-design@claude-code-plugins (not installed, only @claude-plugins-official)
- pr-review-toolkit@claude-code-plugins (not installed, only @claude-plugins-official)
- notion (lowercase, but installed as Notion@claude-plugins-official)

## Solution

### Clean Up enabledPlugins Section

Remove the 75 ghost plugins from `~/.claude-sneakpeek/zai/config/settings.json`:

```json
{
  "enabledPlugins": {
    "agent-sdk-dev@claude-plugins-official": true,
    "atlassian@claude-plugins-official": true,
    "clangd-lsp@claude-plugins-official": true,
    "claude-hud@claude-hud": true,
    "claude-mem@thedotmack": true,
    "code-review@claude-plugins-official": true,
    "commit-commands@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "csharp-lsp@claude-plugins-official": true,
    "frontend-design@claude-plugins-official": true,
    "github@claude-plugins-official": true,
    "glm-plan-bug@zai-coding-plugins": true,
    "glm-plan-usage@zai-coding-plugins": true,
    "gopls-lsp@claude-plugins-official": true,
    "hookify@claude-plugins-official": true,
    "lua-lsp@claude-plugins-official": true,
    "Notion@claude-plugins-official": true,
    "playwright@claude-plugins-official": true,
    "plugin-dev@claude-plugins-official": true,
    "pr-review-toolkit@claude-plugins-official": true,
    "pyright-lsp@claude-plugins-official": true,
    "security-guidance@claude-plugins-official": true,
    "sentry@claude-plugins-official": true,
    "supabase@claude-plugins-official": true,
    "swift-lsp@claude-plugins-official": true,
    "typescript-lsp@claude-plugins-official": true
  }
}
```

## Automated Cleanup Script

```bash
#!/bin/bash
# Cleanup ghost plugins from settings.json

SETTINGS_FILE="/Users/alfredolopez/.claude-sneakpeek/zai/config/settings.json"
INSTALLED_PLUGINS="/Users/alfredolopez/.claude-sneakpeek/zai/config/plugins/installed_plugins.json"

# Backup
cp "$SETTINGS_FILE" "$SETTINGS_FILE.backup-$(date +%Y%m%d_%H%M%S)"

# Get list of installed plugins
INSTALLED=$(jq -r '.plugins | keys[]' "$INSTALLED_PLUGINS" | sort)

# Build new enabledPlugins object
jq --argjson installed "$(jq -n '[$(echo "$INSTALLED" | jq -R . | jq -s .)]' | jq 'unique | map({key: ., value: true}) | add')" \
   '.enabledPlugins = $installed' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp" && \
mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

echo "Cleanup complete. Removed 75 ghost plugins."
```

## Verification

After cleanup, verify:

```bash
# Count should match
cat ~/.claude-sneakpeek/zai/config/settings.json | jq '.enabledPlugins | keys | length'
# Expected: 26

cat ~/.claude-sneakpeek/zai/config/plugins/installed_plugins.json | jq '.plugins | keys | length'
# Expected: 26
```

## Related Issues

1. **Post-rollback plugin state**: enabledPlugins not cleaned up after rollback
2. **Ghost plugin references**: May cause errors when trying to load non-existent plugins
3. **Marketplace sync**: Some marketplaces may not be properly synchronized

## References

- Settings file: `~/.claude-sneakpeek/zai/config/settings.json`
- Installed plugins: `~/.claude-sneakpeek/zai/config/plugins/installed_plugins.json`
- Plugin cache: `~/.claude-sneakpeek/zai/config/plugins/cache/`
