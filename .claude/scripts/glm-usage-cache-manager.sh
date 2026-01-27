#!/usr/bin/env bash
# VERSION: 1.0.0
# Usage cache manager for GLM Coding Plan
# Simplified implementation

set -euo pipefail

# Configuration
CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/glm-usage-cache.json"
CACHE_TTL=300  # 5 minutes
QUERY_SCRIPT="${HOME}/.claude/plugins/cache/zai-coding-plugins/glm-plan-usage/0.0.1/skills/usage-query-skill/scripts/query-usage.mjs"
# API_TOKEN should be sourced from environment variable ANTHROPIC_AUTH_TOKEN
# DO NOT hardcode API keys in this file for security reasons

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

mkdir -p "$CACHE_DIR"

# Refresh cache from API
refresh_cache() {
    # Call query script - uses ANTHROPIC_AUTH_TOKEN from environment
    local output
    output=$(bash -c "export ANTHROPIC_BASE_URL=\"https://api.z.ai/api/anthropic\" && node \"$QUERY_SCRIPT\"" 2>&1)

    # Extract quota JSON
    local quota_json
    quota_json=$(echo "$output" | sed -n '/^Quota limit data:/,$p' | tail -1)

    if [[ -z "$quota_json" ]]; then
        echo "ERROR: No quota data found in response" >&2
        return 1
    fi

    # Parse limits
    local five_hour_pct=$(echo "$quota_json" | jq -r '.limits[] | select(.type == "Token usage(5 Hour)") | .percentage')
    local monthly_pct=$(echo "$quota_json" | jq -r '.limits[] | select(.type == "MCP usage(1 Month)") | .percentage')
    local monthly_used=$(echo "$quota_json" | jq -r '.limits[] | select(.type == "MCP usage(1 Month)") | .currentUsage')
    local monthly_total=$(echo "$quota_json" | jq -r '.limits[] | select(.type == "MCP usage(1 Month)") | .totol')  # Note: API typo

    # Build cache JSON
    local now=$(date +%s)
    jq -n \
        --arg version "1.0.0" \
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

# Get statusline format
get_statusline() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return
    fi

    local output=""

    # 5-hour quota
    local five_hour_pct=$(jq -r '.data.five_hour_quota.percentage' "$CACHE_FILE")
    if [[ "$five_hour_pct" != "null" ]] && [[ -n "$five_hour_pct" ]]; then
        if [[ "$five_hour_pct" -gt 0 ]]; then
            local color="$GREEN"
            if [[ "$five_hour_pct" -ge 75 ]]; then
                color="$YELLOW"
            fi
            if [[ "$five_hour_pct" -ge 85 ]]; then
                color="$RED"
            fi

            if [[ -n "$output" ]]; then
                output="${output} │ "
            fi

            output="${output}${color}⏱️ ${five_hour_pct}% (~5h)${RESET}"
        fi
    fi

    # Monthly MCP
    local monthly_pct=$(jq -r '.data.monthly_mcp.percentage' "$CACHE_FILE")
    local monthly_used=$(jq -r '.data.monthly_mcp.used' "$CACHE_FILE")
    local monthly_total=$(jq -r '.data.monthly_mcp.limit' "$CACHE_FILE")

    if [[ "$monthly_pct" != "null" ]] && [[ -n "$monthly_pct" ]]; then
        if [[ "$monthly_pct" -gt 0 ]]; then
            local color="$CYAN"
            if [[ "$monthly_pct" -ge 75 ]]; then
                color="$YELLOW"
            fi

            if [[ -n "$output" ]]; then
                output="${output} │ "
            fi

            output="${output}${color}🔧 ${monthly_pct}% MCP (${monthly_used}/${monthly_total})${RESET}"
        fi
    fi

    echo -e "$output"
}

# Check if cache needs refresh
needs_refresh() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 0
    fi

    local last_update=$(jq -r '.last_updated // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
    local now=$(date +%s)
    local age=$((now - last_update))

    [[ $age -ge $CACHE_TTL ]]
}

# Show detailed info
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

# Main dispatcher
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
        exit 1
        ;;
esac

exit 0
