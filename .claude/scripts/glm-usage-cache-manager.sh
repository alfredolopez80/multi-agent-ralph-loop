#!/usr/bin/env bash
# VERSION: 2.1.0
# GLM Usage Cache Manager for Multi-Agent Ralph
# Direct API integration with Z.ai GLM Coding Plan
#
# CHANGELOG v2.1.0:
# - OPTIMIZATION: Single jq call to read cache (was 4 separate calls)
# - Simplified color logic with short-circuit evaluation
# - Better performance for statusline rendering
#
# DESCRIPTION:
#   This script manages a local cache of GLM Coding Plan usage data from Z.ai API.
#   It provides formatted output for the Ralph statusline showing:
#   - 5-hour token quota percentage
#   - Monthly MCP usage (web searches, readers, etc.)
#
# USAGE:
#   ./glm-usage-cache-manager.sh {refresh|get-statusline|show}
#
# INTEGRATION:
#   - Called by: .claude/scripts/statusline-ralph.sh
#   - Cache location: ~/.ralph/cache/glm-usage-cache.json
#   - API endpoint: https://api.z.ai/api/monitor/usage/quota/limit
#
# DEPENDENCIES:
#   - curl: For API requests
#   - jq: For JSON parsing
#   - Z.ai API key (from environment or hardcoded)
#
# CACHE STRUCTURE:
#   {
#     "version": "2.0.0",
#     "last_updated": 1769553115,
#     "data": {
#       "five_hour_quota": {
#         "type": "TOKENS_LIMIT",
#         "percentage": 6,
#         "resets_in": "~5h rolling"
#       },
#       "monthly_mcp": {
#         "type": "TIME_LIMIT",
#         "percentage": 3,
#         "used": 143,
#         "limit": 4000,
#         "resets_in": "~1 month"
#       }
#     }
#   }
#
# STATUSLINE OUTPUT:
#   ⏱️ 6% (~5h) │ 🔧 3% MCP (143/4000)
#
# COLOR CODING:
#   - 5-hour quota: GREEN (<75%), YELLOW (>=75%), RED (>=85%)
#   - Monthly MCP: CYAN (<75%), YELLOW (>=75%)
#
# Part of Multi-Agent Ralph v2.74.2
# See: docs/GLM_USAGE_TRACKING_v2.73.0.md

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Cache directory and file
CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/glm-usage-cache.json"

# Cache TTL (5 minutes)
CACHE_TTL=300

# Z.ai API configuration
API_URL="https://api.z.ai/api/monitor/usage/quota/limit"

# API key from environment variable
# Required: Z_AI_API_KEY must be set in environment
API_KEY="${Z_AI_API_KEY:-}"

if [[ -z "$API_KEY" ]]; then
    echo "ERROR: Z_AI_API_KEY environment variable not set" >&2
    echo "Please set: export Z_AI_API_KEY=\"your-api-key\"" >&2
    exit 1
fi

# ANSI color codes
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# ============================================================================
# FUNCTIONS
# ============================================================================

# Refresh cache from Z.ai API
# Usage: refresh_cache
# Output: Success message with percentages
# Returns: 0 on success, 1 on failure
refresh_cache() {
    # Call Z.ai API directly
    local api_response
    api_response=$(curl -s "$API_URL" -H "x-api-key: $API_KEY" 2>&1)

    # Check for API errors
    local success
    success=$(echo "$api_response" | jq -r '.success // false')

    if [[ "$success" != "true" ]]; then
        echo "ERROR: API call failed" >&2
        echo "$api_response" >&2
        return 1
    fi

    # Extract limits from API response
    #
    # API Response Structure:
    # {
    #   "data": {
    #     "limits": [
    #       {
    #         "type": "TOKENS_LIMIT",      <- 5-hour token quota
    #         "percentage": 6,
    #         "currentValue": 48858851,
    #         "usage": 800000000
    #       },
    #       {
    #         "type": "TIME_LIMIT",        <- Monthly MCP quota
    #         "percentage": 3,
    #         "currentValue": 143,
    #         "usage": 4000
    #       }
    #     ]
    #   }
    # }

    local five_hour_pct=$(echo "$api_response" | jq -r '.data.limits[] | select(.type == "TOKENS_LIMIT") | .percentage')
    local monthly_pct=$(echo "$api_response" | jq -r '.data.limits[] | select(.type == "TIME_LIMIT") | .percentage')
    local monthly_used=$(echo "$api_response" | jq -r '.data.limits[] | select(.type == "TIME_LIMIT") | .currentValue')
    local monthly_total=$(echo "$api_response" | jq -r '.data.limits[] | select(.type == "TIME_LIMIT") | .usage')

    # Build cache JSON
    local now=$(date +%s)
    jq -n \
        --arg version "2.0.0" \
        --argjson last_updated "$now" \
        --argjson five_hour_pct "$five_hour_pct" \
        --argjson monthly_pct "$monthly_pct" \
        --argjson monthly_used "$monthly_used" \
        --argjson monthly_total "$monthly_total" \
        '{
            version: $version,
            last_updated: $last_updated,
            data: {
                five_hour_quota: {
                    type: "TOKENS_LIMIT",
                    percentage: ($five_hour_pct|tonumber),
                    resets_in: "~5h rolling"
                },
                monthly_mcp: {
                    type: "TIME_LIMIT",
                    percentage: ($monthly_pct|tonumber),
                    used: ($monthly_used|tonumber),
                    limit: ($monthly_total|tonumber),
                    resets_in: "~1 month"
                }
            }
        }' > "$CACHE_FILE"

    chmod 600 "$CACHE_FILE"
    echo "✓ Cache refreshed: 5h=${five_hour_pct}%, MCP=${monthly_pct}% (${monthly_used}/${monthly_total})"
    return 0
}

# Get statusline formatted output
# Usage: get_statusline
# Output: Formatted string for statusline (e.g., "⏱️ 6% (~5h) │ 🔧 3% MCP (143/4000)")
get_statusline() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return
    fi

    # Read cache JSON once - OPTIMIZATION: Single jq call instead of 4
    local cache_data
    cache_data=$(jq -r '
        .data.five_hour_quota.percentage as $fh_pct |
        .data.monthly_mcp.percentage as $mcp_pct |
        .data.monthly_mcp.used as $mcp_used |
        .data.monthly_mcp.limit as $mcp_total |
        "\($fh_pct)|\($mcp_pct)|\($mcp_used)|\($mcp_total)"
    ' "$CACHE_FILE" 2>/dev/null)

    # Parse the pipe-delimited values
    IFS='|' read -r five_hour_pct monthly_pct monthly_used monthly_total <<< "$cache_data"

    # Skip if data is invalid
    if [[ "$five_hour_pct" == "null" ]] || [[ -z "$five_hour_pct" ]]; then
        return
    fi

    local output=""

    # 5-hour token quota (only show if > 0%)
    if [[ "$five_hour_pct" -gt 0 ]]; then
        # Determine color based on threshold
        local color="$GREEN"
        [[ "$five_hour_pct" -ge 75 ]] && color="$YELLOW"
        [[ "$five_hour_pct" -ge 85 ]] && color="$RED"
        output="${output}${color}⏱️ ${five_hour_pct}% (~5h)${RESET}"
    fi

    # Monthly MCP quota (only show if > 0%)
    if [[ "$monthly_pct" != "null" ]] && [[ -n "$monthly_pct" ]] && [[ "$monthly_pct" -gt 0 ]]; then
        local color="$CYAN"
        [[ "$monthly_pct" -ge 75 ]] && color="$YELLOW"

        [[ -n "$output" ]] && output="${output} │ "
        output="${output}${color}🔧 ${monthly_pct}% MCP (${monthly_used}/${monthly_total})${RESET}"
    fi

    echo -e "$output"
}

# Check if cache needs refresh
# Usage: needs_refresh
# Returns: 0 if refresh needed, 1 if cache is fresh
needs_refresh() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 0
    fi

    local last_update=$(jq -r '.last_updated // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
    local now=$(date +%s)
    local age=$((now - last_update))

    [[ $age -ge $CACHE_TTL ]]
}

# Show detailed cache information
# Usage: show_info
# Output: Human-readable cache details
show_info() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        echo "Cache not found. Run 'refresh' first."
        return 1
    fi

    echo "=== GLM Usage Cache ==="
    echo ""
    echo "📊 5-Hour Token Quota:"
    echo "   Percentage: $(jq -r '.data.five_hour_quota.percentage' "$CACHE_FILE")%"
    echo "   Resets: $(jq -r '.data.five_hour_quota.resets_in' "$CACHE_FILE")"
    echo ""
    echo "🔧 Monthly MCP Quota:"
    echo "   Percentage: $(jq -r '.data.monthly_mcp.percentage' "$CACHE_FILE")%"
    echo "   Used: $(jq -r '.data.monthly_mcp.used' "$CACHE_FILE") / $(jq -r '.data.monthly_mcp.limit' "$CACHE_FILE")"
    echo "   Resets: $(jq -r '.data.monthly_mcp.resets_in' "$CACHE_FILE")"
    echo ""
    echo "Last updated: $(date -r "@$(jq -r '.last_updated' "$CACHE_FILE")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "unknown")"
    echo "Cache age: $(( $(date +%s) - $(jq -r '.last_updated' "$CACHE_FILE") )) seconds"
}

# ============================================================================
# MAIN DISPATCHER
# ============================================================================

case "${1:-}" in
    refresh|--refresh|-r)
        refresh_cache
        ;;
    get-statusline|--status|-s)
        if needs_refresh; then
            refresh_cache >/dev/null 2>&1 || true
        fi
        get_statusline
        ;;
    show|--info|-i)
        show_info
        ;;
    *)
        echo "Usage: $0 {refresh|get-statusline|show}"
        echo ""
        echo "Commands:"
        echo "  refresh       - Fetch latest usage from API"
        echo "  get-statusline - Output formatted for statusline"
        echo "  show          - Show detailed cache information"
        echo ""
        echo "Environment Variables:"
        echo "  Z_AI_API_KEY  - Z.ai API key (optional, uses fallback if not set)"
        echo ""
        echo "Examples:"
        echo "  $0 refresh"
        echo "  $0 get-statusline"
        echo "  $0 show"
        exit 1
        ;;
esac

exit 0
