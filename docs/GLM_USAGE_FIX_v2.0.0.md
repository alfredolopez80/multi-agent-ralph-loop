# GLM Usage Tracking Fix v2.0.0 - Complete Documentation

> **Status**: ✅ Implemented and Working
> **Date**: 2026-01-27
> **Author**: Claude Code + User Collaboration
> **Affected Component**: Statusline GLM Usage Display

## Executive Summary

Fixed incorrect GLM usage percentages in the Ralph statusline by replacing a broken dependency on a non-existent script with direct API integration to Z.ai.

### Problem Identified

The statusline was showing incorrect usage data:
- **5-hour quota**: Showing `1%` instead of actual `6%`
- **Monthly MCP**: Showing `1% (60/4000)` instead of actual `3% (143/4000)`

### Root Cause

The `glm-usage-cache-manager.sh` script (v1.0.0) was trying to call a non-existent script:
```bash
QUERY_SCRIPT="${HOME}/.claude/plugins/cache/zai-coding-plugins/glm-plan-usage/0.0.1/skills/usage-query-skill/scripts/query-usage.mjs"
```

This script path was from a deprecated/removed Z.ai plugin, causing the cache to never update.

### Solution Implemented

Updated `glm-usage-cache-manager.sh` to v2.0.0 with:
1. **Direct API Integration**: Removed dependency on missing script
2. **Correct API Endpoint**: Using `https://api.z.ai/api/monitor/usage/quota/limit`
3. **Proper Authentication**: Using `x-api-key` header with API key from environment or fallback
4. **Extensive Documentation**: Added inline comments and help text

---

## Technical Details

### API Endpoint

**URL**: `https://api.z.ai/api/monitor/usage/quota/limit`

**Method**: `GET`

**Headers**:
```
x-api-key: <your-api-key>
```

**Response Structure**:
```json
{
  "code": 200,
  "msg": "Operation successful",
  "data": {
    "limits": [
      {
        "type": "TOKENS_LIMIT",
        "unit": 3,
        "number": 5,
        "usage": 800000000,
        "currentValue": 48858851,
        "remaining": 751141149,
        "percentage": 6,
        "nextResetTime": 1769563775988
      },
      {
        "type": "TIME_LIMIT",
        "unit": 5,
        "number": 1,
        "usage": 4000,
        "currentValue": 143,
        "remaining": 3857,
        "percentage": 3,
        "usageDetails": [
          {
            "modelCode": "search-prime",
            "usage": 63
          },
          {
            "modelCode": "web-reader",
            "usage": 53
          },
          {
            "modelCode": "zread",
            "usage": 27
          }
        ]
      }
    ]
  },
  "success": true
}
```

### Field Mappings

| API Field | Meaning | Cache Field |
|-----------|---------|-------------|
| `limits[].type == "TOKENS_LIMIT"` | 5-hour token quota | `five_hour_quota` |
| `limits[].type == "TIME_LIMIT"` | Monthly MCP quota | `monthly_mcp` |
| `limits[].percentage` | Usage percentage | `percentage` |
| `limits[].currentValue` | Current usage | `used` (MCP only) |
| `limits[].usage` | Total limit | `limit` (MCP only) |

### Cache Structure

**Location**: `~/.ralph/cache/glm-usage-cache.json`

**Schema**:
```json
{
  "version": "2.0.0",
  "last_updated": 1769553115,
  "data": {
    "five_hour_quota": {
      "type": "TOKENS_LIMIT",
      "percentage": 6,
      "resets_in": "~5h rolling"
    },
    "monthly_mcp": {
      "type": "TIME_LIMIT",
      "percentage": 3,
      "used": 143,
      "limit": 4000,
      "resets_in": "~1 month"
    }
  }
}
```

### Statusline Integration

**Script**: `.claude/scripts/statusline-ralph.sh`

**Function**: `get_glm_plan_usage()`

**Output Format**: `⏱️ 6% (~5h) │ 🔧 3% MCP (143/4000)`

**Color Coding**:
- 5-hour quota: GREEN (<75%), YELLOW (≥75%), RED (≥85%)
- Monthly MCP: CYAN (<75%), YELLOW (≥75%)

---

## Installation Guide

### Step 1: Verify Dependencies

Ensure you have the required tools installed:

```bash
# Check curl
curl --version
# Expected: curl 7.x.x or higher

# Check jq
jq --version
# Expected: jq-1.x or higher

# If jq is missing, install it:
# macOS
brew install jq

# Linux (Ubuntu/Debian)
sudo apt-get install jq

# Linux (Fedora/RHEL)
sudo dnf install jq
```

### Step 2: Copy Script to Repository

The script has been updated in the repository at:
```
.claude/scripts/glm-usage-cache-manager.sh
```

### Step 3: Set Up API Key

The script uses the API key from:
1. Environment variable `Z_AI_API_KEY` (priority)
2. Hardcoded fallback in script (should match `settings.json`)

**Current API key in settings.json**:
```
YOUR_API_KEY
```

**To update the API key in the script**:
```bash
# Edit the script
nano .claude/scripts/glm-usage-cache-manager.sh

# Find this line and update the fallback key:
API_KEY="${Z_AI_API_KEY:-YOUR_API_KEY}"
```

### Step 4: Make Script Executable

```bash
chmod +x .claude/scripts/glm-usage-cache-manager.sh
```

### Step 5: Test the Script

```bash
# Test refresh
./.claude/scripts/glm-usage-cache-manager.sh refresh

# Expected output:
# ✓ Cache refreshed: 5h=6%, MCP=3% (143/4000)

# Test statusline output
./.claude/scripts/glm-usage-cache-manager.sh get-statusline

# Expected output:
# ⏱️ 6% (~5h) │ 🔧 3% MCP (143/4000)

# Test detailed info
./.claude/scripts/glm-usage-cache-manager.sh show

# Expected output: Detailed cache information
```

### Step 6: Verify Statusline Integration

```bash
# Test the full statusline
echo '{"cwd": "/path/to/your/repo"}' | bash .claude/scripts/statusline-ralph.sh

# Look for the GLM usage section in the output
# Should show: ⏱️ 6% (~5h) │ 🔧 3% MCP (143/4000)
```

---

## File Changes Summary

### Modified Files

| File | Change | Version |
|------|--------|---------|
| `.claude/scripts/glm-usage-cache-manager.sh` | Updated to v2.0.0 with direct API | 2.0.0 |

### Key Changes in v2.0.0

1. **Removed**: Dependency on non-existent `query-usage.mjs` script
2. **Added**: Direct curl call to Z.ai API
3. **Added**: Proper error handling for API failures
4. **Added**: Extensive inline documentation
5. **Added**: Environment variable support for API key
6. **Added**: Detailed help text with examples
7. **Improved**: Cache structure with version tracking

---

## Troubleshooting

### Issue: "curl: option : blank argument where content is expected"

**Cause**: Invalid curl command with empty header value

**Solution**: Use single quotes for the curl command:
```bash
curl -s 'https://api.z.ai/api/monitor/usage/quota/limit' -H 'x-api-key: YOUR_KEY'
```

### Issue: "ERROR: API call failed"

**Cause**: Invalid API key or network issue

**Solution**:
1. Verify API key is correct
2. Check network connectivity
3. Test API manually:
```bash
curl -s 'https://api.z.ai/api/monitor/usage/quota/limit' -H 'x-api-key: YOUR_KEY' | jq '.'
```

### Issue: Statusline shows old values

**Cause**: Cache hasn't refreshed

**Solution**:
```bash
# Manually refresh the cache
./.claude/scripts/glm-usage-cache-manager.sh refresh

# Verify cache was updated
cat ~/.ralph/cache/glm-usage-cache.json | jq '.'
```

### Issue: "jq: command not found"

**Cause**: jq is not installed

**Solution**: Install jq using your package manager (see Step 1)

### Issue: Permission denied

**Cause**: Script is not executable

**Solution**:
```bash
chmod +x .claude/scripts/glm-usage-cache-manager.sh
```

---

## Usage Examples

### Basic Commands

```bash
# Refresh cache from API
./.claude/scripts/glm-usage-cache-manager.sh refresh

# Get statusline formatted output
./.claude/scripts/glm-usage-cache-manager.sh get-statusline

# Show detailed cache information
./.claude/scripts/glm-usage-cache-manager.sh show
```

### With Environment Variable

```bash
# Use custom API key from environment
export Z_AI_API_KEY="your-api-key-here"
./.claude/scripts/glm-usage-cache-manager.sh refresh
```

### Programmatic Usage

```bash
# In your scripts
GLM_CACHE=$(~/.ralph/scripts/glm-usage-cache-manager.sh get-statusline)
echo "Current GLM usage: $GLM_CACHE"

# Check if 5-hour quota is above threshold
FIVE_HOUR_PCT=$(jq -r '.data.five_hour_quota.percentage' ~/.ralph/cache/glm-usage-cache.json)
if [[ $FIVE_HOUR_PCT -gt 75 ]]; then
    echo "WARNING: 5-hour quota above 75%"
fi
```

---

## API Reference

### Z.ai Quota Limit API

**Endpoint**: `GET /api/monitor/usage/quota/limit`

**Base URL**: `https://api.z.ai`

**Authentication**: Bearer token via `x-api-key` header

**Rate Limits**: Unknown (cache for 5 minutes to be safe)

**Response Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `code` | number | HTTP status code (200 = success) |
| `msg` | string | Response message |
| `success` | boolean | True if request succeeded |
| `data.limits[]` | array | Array of quota limits |
| `data.limits[].type` | string | "TOKENS_LIMIT" or "TIME_LIMIT" |
| `data.limits[].percentage` | number | Usage percentage (0-100) |
| `data.limits[].currentValue` | number | Current usage amount |
| `data.limits[].usage` | number | Total limit amount |
| `data.limits[].remaining` | number | Remaining amount |
| `data.limits[].nextResetTime` | number | Unix timestamp of reset |

---

## Testing Checklist

- [x] Script executes without errors
- [x] API call returns valid JSON
- [x] Cache file is created with correct structure
- [x] Cache refreshes correctly (5-minute TTL)
- [x] Statusline output is formatted correctly
- [x] Colors change at thresholds (75%, 85%)
- [x] Environment variable `Z_AI_API_KEY` works
- [x] Fallback API key works
- [x] Error handling for API failures
- [x] Help text displays correctly
- [x] Show command displays cache details

---

## Future Improvements

1. **Add warning hooks**: Alert when approaching limits
2. **Add webhook support**: Send notifications on threshold breaches
3. **Add historical tracking**: Store usage history for analytics
4. **Add multi-user support**: Track usage across team accounts
5. **Add configuration file**: Support for custom thresholds and settings

---

## References

- **Z.ai GLM Coding Plan**: https://docs.z.ai/devpack/faq
- **Ralph Documentation**: docs/GLM_USAGE_TRACKING_v2.73.0.md
- **Statusline Integration**: .claude/scripts/statusline-ralph.sh
- **API Testing**: `curl -s 'https://api.z.ai/api/monitor/usage/quota/limit' -H 'x-api-key: KEY' | jq .`

---

## Changelog

### v2.0.0 (2026-01-27)

**Changed**:
- Replaced dependency on non-existent `query-usage.mjs` script
- Added direct API integration with Z.ai quota endpoint
- Added extensive inline documentation
- Added environment variable support for API key
- Improved error handling and validation
- Updated cache schema to v2.0.0

**Fixed**:
- Fixed incorrect percentage calculations
- Fixed stale cache issues
- Fixed API authentication

**Added**:
- Added detailed help text
- Added API response structure documentation
- Added troubleshooting guide
- Added testing checklist

### v1.0.0 (Original)

**Added**:
- Initial implementation with dependency on `query-usage.mjs`
- Basic cache management
- Statusline formatting

---

**Document Version**: 1.0.0
**Last Updated**: 2026-01-27
**Status**: ✅ Complete and Working
