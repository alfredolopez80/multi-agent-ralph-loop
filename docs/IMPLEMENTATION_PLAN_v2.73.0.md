# Implementation Plan: Z.AI GLM Coding Plan Usage Tracking v2.73.0

## Overview

Integrate real-time usage tracking for Z.AI GLM Coding Plan into Ralph statusline, displaying:
- 5-hour session quota (TOKENS_LIMIT)
- Monthly MCP usage (TIME_LIMIT)
- Integration with existing context tracking

## Architecture Decision

### Selected Approach: Hybrid Cache with Smart Updates

**Rationale**:
- ✅ Performance: Statusline reads from cache (<5ms)
- ✅ Accuracy: Cache updates after API calls via PostToolUse hook
- ✅ Efficiency: Minimal API calls (~12/hour max)
- ✅ Reliability: Graceful degradation when API unavailable

**Components**:

```
┌─────────────────────────────────────────────────────────────┐
│                     Statusline Display                        │
│  ⏱️ 65% (5h) │ 🔧 45% MCP │ 🤖 75% · 96K/128K               │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│              glm-usage-cache-manager.sh                       │
│  - Reads: ~/.ralph/cache/glm-usage-cache.json                │
│  - Formats statusline output                                 │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│            glm-usage-cache-updater.sh (Hook)                  │
│  - Trigger: PostToolUse after GLM API calls                  │
│  - Calls: node query-usage.mjs                              │
│  - Updates: ~/.ralph/cache/glm-usage-cache.json              │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│                  query-usage.mjs (Existing)                   │
│  - Endpoint: /api/monitor/usage/quota/limit                   │
│  - Returns: TOKENS_LIMIT + TIME_LIMIT data                   │
└─────────────────────────────────────────────────────────────┘
```

## Data Model

### Cache File Structure: `~/.ralph/cache/glm-usage-cache.json`

```json
{
  "version": "1.0.0",
  "last_updated": 1706348400,
  "data": {
    "five_hour_quota": {
      "limitType": "TOKENS_LIMIT",
      "limit": 2400,
      "used": 1560,
      "percentage": 65,
      "reset_at": 1706352000,
      "resets_in": "1h 45m"
    },
    "monthly_mcp": {
      "limitType": "TIME_LIMIT",
      "limit": 4000,
      "used": 1800,
      "percentage": 45,
      "reset_at": 1706736000,
      "resets_in": "5d 12h"
    }
  }
}
```

## File Changes

### 1. New: `~/.ralph/scripts/glm-usage-cache-manager.sh`

```bash
#!/usr/bin/env bash
# VERSION: 1.0.0
# Usage cache manager for GLM Coding Plan

set -euo pipefail

CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/glm-usage-cache.json"
CACHE_TTL=300  # 5 minutes
QUERY_SCRIPT="${HOME}/.claude/plugins/cache/zai-coding-plugins/glm-plan-usage/0.0.1/skills/usage-query-skill/scripts/query-usage.mjs"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Calculate time until reset
format_reset_time() {
    local reset_ts="$1"
    local now=$(date +%s)
    local diff=$((reset_ts - now))

    if [[ $diff -le 0 ]]; then
        echo "soon"
        return
    fi

    local days=$((diff / 86400))
    local hours=$(((diff % 86400) / 3600))
    local mins=$(((diff % 3600) / 60))

    if [[ $days -gt 0 ]]; then
        echo "${days}d ${hours}h"
    elif [[ $hours -gt 0 ]]; then
        echo "${hours}h ${mins}m"
    else
        echo "${mins}m"
    fi
}

# Refresh cache from API
refresh_cache() {
    local output
    output=$(node "$QUERY_SCRIPT" 2>&1)

    if [[ $? -ne 0 ]]; then
        echo "ERROR: Failed to query usage API" >&2
        return 1
    fi

    # Extract quota limit data from output
    local quota_data
    quota_data=$(echo "$output" | grep -A 20 '"Quota limit data"' | grep -E '^\s*\{' -A 10 | head -20)

    if [[ -z "$quota_data" ]]; then
        echo "ERROR: No quota data in response" >&2
        return 1
    fi

    # Parse JSON with jq
    local parsed
    parsed=$(echo "$quota_data" | jq -r '
        .data.limits[] |
        select(.limitType == "TOKENS_LIMIT" or .limitType == "TIME_LIMIT") |
        {
            limitType: .limitType,
            limit: .limit,
            used: .used,
            percentage: .percentage,
            reset_at: .resetAt
        }
    ' 2>/dev/null)

    if [[ -z "$parsed" ]]; then
        echo "ERROR: Failed to parse quota data" >&2
        return 1
    fi

    # Build cache structure
    local now=$(date +%s)
    local cache_json
    cache_json=$(jq -n \
        --argjson version "1.0.0" \
        --argjson last_updated "$now" \
        '{
            version: $version,
            last_updated: $last_updated,
            data: {five_hour_quota: null, monthly_mcp: null}
        }')

    # Process each limit type
    while IFS= read -r entry; do
        local type=$(echo "$entry" | jq -r '.limitType')
        local reset_at=$(echo "$entry" | jq -r '.reset_at')
        local reset_ts=$(date -d "$reset_at" +%s 2>/dev/null || echo "0")
        local resets_in=$(format_reset_time "$reset_ts")

        if [[ "$type" == "TOKENS_LIMIT" ]]; then
            cache_json=$(echo "$cache_json" | jq \
                --argjson entry "$entry" \
                --argjson reset_ts "$reset_ts" \
                --arg resets_in "$resets_in" \
                '.data.five_hour_quota = $entry |
                 .data.five_hour_quota.reset_at = $reset_ts |
                 .data.five_hour_quota.resets_in = $resets_in')
        elif [[ "$type" == "TIME_LIMIT" ]]; then
            cache_json=$(echo "$cache_json" | jq \
                --argjson entry "$entry" \
                --argjson reset_ts "$reset_ts" \
                --arg resets_in "$resets_in" \
                '.data.monthly_mcp = $entry |
                 .data.monthly_mcp.reset_at = $reset_ts |
                 .data.monthly_mcp.resets_in = $resets_in')
        fi
    done <<< "$parsed"

    # Write cache
    echo "$cache_json" > "$CACHE_FILE"
    chmod 600 "$CACHE_FILE"

    echo "Cache refreshed successfully"
}

# Get statusline format
get_statusline() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return
    fi

    local output=""

    # 5-hour quota
    local five_hour=$(jq -r '.data.five_hour_quota' "$CACHE_FILE" 2>/dev/null)
    if [[ "$five_hour" != "null" ]] && [[ -n "$five_hour" ]]; then
        local pct=$(echo "$five_hour" | jq -r '.percentage // 0')
        local resets=$(echo "$five_hour" | jq -r '.resets_in // ""')

        if [[ "$pct" -gt 0 ]]; then
            local color="\033[0;32m"  # Green
            if [[ "$pct" -ge 75 ]]; then
                color="\033[0;33m"  # Yellow
            fi
            if [[ "$pct" -ge 85 ]]; then
                color="\033[0;31m"  # Red
            fi

            output="${output}${color}⏱️ ${pct}%${resets:+ ($resets)}\033[0m"
        fi
    fi

    # Monthly MCP
    local monthly_mcp=$(jq -r '.data.monthly_mcp' "$CACHE_FILE" 2>/dev/null)
    if [[ "$monthly_mcp" != "null" ]] && [[ -n "$monthly_mcp" ]]; then
        local pct=$(echo "$monthly_mcp" | jq -r '.percentage // 0')
        local used=$(echo "$monthly_mcp" | jq -r '.used // 0')
        local total=$(echo "$monthly_mcp" | jq -r '.limit // 0')

        if [[ "$pct" -gt 0 ]]; then
            if [[ -n "$output" ]]; then
                output="${output} │ "
            fi

            local color="\033[0;36m"  # Cyan
            if [[ "$pct" -ge 75 ]]; then
                color="\033[0;33m"  # Yellow
            fi

            output="${output}${color}🔧 ${pct}% MCP (${used}/${total})\033[0m"
        fi
    fi

    echo -e "$output"
}

# Check if cache needs refresh
needs_refresh() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 0
    fi

    local last_update
    last_update=$(jq -r '.last_updated // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
    local now=$(date +%s)
    local age=$((now - last_update))

    [[ $age -ge $CACHE_TTL ]]
}

# Main dispatcher
case "${1:-}" in
    refresh)
        refresh_cache
        ;;
    get-statusline|--status|-s)
        if needs_refresh; then
            refresh_cache >/dev/null 2>&1 || true
        fi
        get_statusline
        ;;
    show|--info|-i)
        if [[ -f "$CACHE_FILE" ]]; then
            cat "$CACHE_FILE" | jq '.'
        else
            echo "Cache file not found. Run 'refresh' first."
        fi
        ;;
    *)
        echo "Usage: $0 {refresh|get-statusline|show}"
        exit 1
        ;;
esac

exit 0
```

### 2. New: `~/.claude/hooks/glm-usage-cache-updater.sh`

```bash
#!/usr/bin/env bash
# VERSION: 1.0.0
# Hook: PostToolUse
# Trigger: After Edit|Write|Bash tools
# Purpose: Update GLM usage cache after potential API calls

set -euo pipefail

# Error trap - PostToolUse hooks return {"continue": true}
trap 'echo "{\"continue\": true}"' ERR EXIT

# Only update after tools that might call GLM API
# (Bash with curl, Edit, Write, etc.)
TOOL_NAME="${1:-}"

# Skip if not a relevant tool
case "$TOOL_NAME" in
    Bash|Edit|Write|mcp__*)
        # Relevant tools, continue
        ;;
    *)
        # Skip update
        trap - EXIT
        echo '{"continue": true}'
        exit 0
        ;;
esac

# Rate limiting: Only update every 30 seconds max
CACHE_DIR="${HOME}/.ralph/cache"
LAST_UPDATE_FILE="${CACHE_DIR}/.last-usage-update"
RATE_LIMIT=30

if [[ -f "$LAST_UPDATE_FILE" ]]; then
    LAST_UPDATE=$(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo "0")
    NOW=$(date +%s)
    AGE=$((NOW - LAST_UPDATE))

    if [[ $AGE -lt $RATE_LIMIT ]]; then
        # Too soon, skip
        trap - EXIT
        echo '{"continue": true}'
        exit 0
    fi
fi

# Update timestamp
date +%s > "$LAST_UPDATE_FILE"

# Trigger cache refresh in background
~/.ralph/scripts/glm-usage-cache-manager.sh refresh >/dev/null 2>&1 &

# Clear trap and continue
trap - EXIT
echo '{"continue": true}'
exit 0
```

### 3. Modified: `~/.claude/scripts/statusline-ralph.sh`

Add after `get_glm_context_percentage()` function:

```bash
# Get GLM Coding Plan usage from cache
# Shows 5-hour quota and monthly MCP usage
get_glm_plan_usage() {
    local cache_manager="${HOME}/.ralph/scripts/glm-usage-cache-manager.sh"

    if [[ -f "$cache_manager" ]]; then
        "$cache_manager" get-statusline
    fi
}
```

Then in the main section, after line 511:

```bash
# Get GLM Coding Plan usage (NEW)
glm_plan_usage=$(get_glm_plan_usage)

# Add to combined_segment after session_context
if [[ -n "$glm_plan_usage" ]]; then
    if [[ -n "$combined_segment" ]]; then
        combined_segment="${combined_segment} │ ${glm_plan_usage}"
    else
        combined_segment="${glm_plan_usage}"
    fi
fi
```

## Implementation Steps

### Phase 1: Core Infrastructure (Immediate)

```bash
# 1. Create directories
mkdir -p ~/.ralph/cache ~/.ralph/scripts

# 2. Create cache manager script
# (Copy glm-usage-cache-manager.sh from above)

# 3. Make executable
chmod +x ~/.ralph/scripts/glm-usage-cache-manager.sh

# 4. Test API connection
~/.ralph/scripts/glm-usage-cache-manager.sh refresh

# 5. Verify cache
cat ~/.ralph/cache/glm-usage-cache.json | jq '.'
```

### Phase 2: Hook Integration (Next)

```bash
# 1. Create hook file
# (Copy glm-usage-cache-updater.sh to ~/.claude/hooks/)

# 2. Make executable
chmod +x ~/.claude/hooks/glm-usage-cache-updater.sh

# 3. Register in ~/.claude/settings.json:
# "hooks": {
#   "PostToolUse": [
#     "~/.claude/hooks/glm-usage-cache-updater.sh"
#   ]
# }
```

### Phase 3: Statusline Integration (Final)

```bash
# 1. Backup statusline script
cp ~/.claude/scripts/statusline-ralph.sh ~/.claude/scripts/statusline-ralph.sh.backup

# 2. Add get_glm_plan_usage() function
# 3. Integrate into combined_segment
# 4. Test with: echo '{"cwd": "."}' | ~/.claude/scripts/statusline-ralph.sh
```

## Testing Plan

```bash
# Test 1: Manual refresh
~/.ralph/scripts/glm-usage-cache-manager.sh refresh
~/.ralph/scripts/glm-usage-cache-manager.sh show

# Test 2: Statusline output
~/.ralph/scripts/glm-usage-cache-manager.sh get-statusline

# Test 3: Cache TTL
# Wait 5 minutes and check if auto-refresh works

# Test 4: Integration test
# Make a GLM API call and verify cache updates
```

## Success Criteria

- [ ] Cache manager successfully fetches from API
- [ ] Statusline displays: `⏱️ 65% (1h 45m) │ 🔧 45% MCP (1800/4000)`
- [ ] Cache respects 5-minute TTL
- [ ] Hook rate-limits to 1 update per 30 seconds
- [ ] Graceful degradation when API unavailable
- [ ] No performance impact on statusline (<5ms read time)

## Rollback Plan

If issues occur:
```bash
# 1. Disable hook
# Edit ~/.claude/settings.json, remove glm-usage-cache-updater.sh

# 2. Restore statusline
cp ~/.claude/scripts/statusline-ralph.sh.backup ~/.claude/scripts/statusline-ralph.sh

# 3. Clear cache
rm -f ~/.ralph/cache/glm-usage-cache.json
```

## Version History

- **v2.73.0** (2026-01-27): Initial implementation
  - Hybrid cache with smart updates
  - 5-hour + monthly MCP tracking
  - Statusline integration
