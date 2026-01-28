# GLM Usage Tracking - Quick Start Guide

> **Automated Installation**: Run `./install-glm-usage-tracking.sh --test` to install and verify

## Overview

This component provides real-time GLM Coding Plan usage tracking in the Ralph statusline, showing:
- **5-hour token quota**: Rolling window token usage percentage
- **Monthly MCP quota**: Web searches, readers, and other MCP tool usage

## Quick Start

### Automated Installation (Recommended)

```bash
# Navigate to the scripts directory
cd .claude/scripts

# Run installation with tests
./install-glm-usage-tracking.sh --test

# Verify statusline integration
echo '{"cwd": "."}' | bash statusline-ralph.sh
```

### Manual Installation

```bash
# 1. Copy script to ~/.ralph/scripts/
cp .claude/scripts/glm-usage-cache-manager.sh ~/.ralph/scripts/

# 2. Make executable
chmod +x ~/.ralph/scripts/glm-usage-cache-manager.sh

# 3. Refresh cache
~/.ralph/scripts/glm-usage-cache-manager.sh refresh

# 4. Verify
~/.ralph/scripts/glm-usage-cache-manager.sh show
```

## Statusline Output

```
⎇ main* │ [glm-4.7] ████████░░ ctx:69% │ ⏱️ 6% (~5h) │ 🔧 3% MCP (143/4000) │ 📊 3/7 42%
                                       └─────────────────┘ └──────────────────────┘
                                       5-hour Token        Monthly MCP Usage
                                       Quota                (searches, readers)
```

## Color Coding

| Metric | < 75% | ≥ 75% | ≥ 85% |
|--------|-------|-------|-------|
| 5-hour quota | 🟢 GREEN | 🟡 YELLOW | 🔴 RED |
| Monthly MCP | 🔵 CYAN | 🟡 YELLOW | 🔴 RED |

## Commands

```bash
# Refresh cache from API
~/.ralph/scripts/glm-usage-cache-manager.sh refresh

# Get statusline formatted output
~/.ralph/scripts/glm-usage-cache-manager.sh get-statusline

# Show detailed information
~/.ralph/scripts/glm-usage-cache-manager.sh show
```

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Script | `.claude/scripts/glm-usage-cache-manager.sh` | Source script |
| Installed | `~/.ralph/scripts/glm-usage-cache-manager.sh` | Active installation |
| Cache | `~/.ralph/cache/glm-usage-cache.json` | Cached usage data |
| Docs | `docs/GLM_USAGE_FIX_v2.0.0.md` | Complete documentation |
| Installer | `.claude/scripts/install-glm-usage-tracking.sh` | Automated setup |

## Troubleshooting

### Issue: Incorrect percentages shown

**Solution**: Manually refresh the cache
```bash
~/.ralph/scripts/glm-usage-cache-manager.sh refresh
```

### Issue: "API call failed"

**Solution**: Verify API key in settings.json
```bash
# Check your API key
cat ~/.claude-sneakpeek/zai/config/settings.json | jq -r '.env.Z_AI_API_KEY'

# Test API manually
curl -s 'https://api.z.ai/api/monitor/usage/quota/limit' \
  -H "x-api-key: YOUR_KEY" | jq '.'
```

### Issue: Statusline doesn't show GLM usage

**Solution**: Check statusline integration
```bash
# Test statusline directly
echo '{"cwd": "."}' | bash .claude/scripts/statusline-ralph.sh

# Verify get_glm_plan_usage function
grep -A 10 "get_glm_plan_usage" .claude/scripts/statusline-ralph.sh
```

## API Details

**Endpoint**: `GET https://api.z.ai/api/monitor/usage/quota/limit`

**Authentication**: `x-api-key: YOUR_API_KEY`

**Response**: See `docs/GLM_USAGE_FIX_v2.0.0.md` for full schema

## Documentation

- **Complete Guide**: `docs/GLM_USAGE_FIX_v2.0.0.md`
- **Tracking Overview**: `docs/GLM_USAGE_TRACKING_v2.73.0.md`
- **Statusline Integration**: `.claude/scripts/statusline-ralph.sh`

## Version History

- **v2.0.0** (2026-01-27): Direct API integration, fixed incorrect percentages
- **v1.0.0**: Initial implementation with deprecated dependency

## Support

For issues or questions:
1. Check `docs/GLM_USAGE_FIX_v2.0.0.md` troubleshooting section
2. Run `./install-glm-usage-tracking.sh --test` to verify setup
3. Check cache: `cat ~/.ralph/cache/glm-usage-cache.json | jq .`
