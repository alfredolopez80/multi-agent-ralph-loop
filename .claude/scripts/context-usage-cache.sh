#!/bin/bash
# context-usage-cache.sh - Caches real context usage from /context command
#
# This script captures the actual context usage that /context displays
# since the statusline JSON input doesn't contain this information.
#
# Usage:
#   context-usage-cache.sh update    # Update cache from /context
#   context-usage-cache.sh get       # Get cached JSON values

CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/context-usage.json"
CACHE_MAX_AGE=300  # seconds - cache expires after 5 minutes

# Create cache directory
mkdir -p "$CACHE_DIR" 2>/dev/null

update_cache() {
    # Calculate actual usage from /context output
    # We need to extract this from the session or estimate it

    # For now, let's try to get it from the current session file
    local session_file
    session_file=$(ls -t ~/.claude-sneakpeek/zai/config/projects/-Users-alfredolopez-Documents-GitHub-multi-agent-ralph-loop/*.jsonl 2>/dev/null | head -1)

    if [[ -f "$session_file" ]]; then
        # Get latest context info
        local context_data=$(tail -1 "$session_file" 2>/dev/null | jq -r '.context_window // {}' 2>/dev/null)

        if [[ -n "$context_data" ]] && [[ "$context_data" != "null" ]] && [[ "$context_data" != "{}" ]]; then
            local context_size=$(echo "$context_data" | jq -r '.context_window_size // 200000')

            # Try to get the real used percentage from remaining_percentage
            local remaining_pct=$(echo "$context_data" | jq -r '.remaining_percentage // ""')
            local used_pct=0

            if [[ -n "$remaining_pct" ]] && [[ "$remaining_pct" != "null" ]] && [[ "$remaining_pct" != "100" ]] && [[ "$remaining_pct" != "0" ]]; then
                # Use the inverse of remaining_percentage
                used_pct=$((100 - ${remaining_pct%.*}))
            else
                # No valid data - preserve existing cache instead of overwriting with zeros
                echo "No valid context data available - preserving existing cache" >&2
                return 1
            fi

            # Only update if we have valid non-zero usage data
            if [[ $used_pct -eq 0 ]]; then
                echo "No valid usage data (0%) - preserving existing cache" >&2
                return 1
            fi

            # Calculate used tokens
            local used_tokens=$((context_size * used_pct / 100))
            local free_tokens=$((context_size - used_tokens))

            # Create cache JSON
            local cache_json=$(jq -n \
                --argjson timestamp "$(date +%s)" \
                --argjson context_size "$context_size" \
                --argjson used_tokens "$used_tokens" \
                --argjson free_tokens "$free_tokens" \
                --argjson used_percentage "$used_pct" \
                --argjson remaining_percentage "$((100 - used_pct))" \
                '{
                    timestamp: $timestamp,
                    context_size: $context_size,
                    used_tokens: $used_tokens,
                    free_tokens: $free_tokens,
                    used_percentage: $used_percentage,
                    remaining_percentage: (100 - $used_percentage)
                }')

            echo "$cache_json" > "$CACHE_FILE"
            echo "Cache updated: ${used_pct}% used (${used_tokens}k/${context_size}k)" >&2
            return 0
        fi
    fi

    return 1
}

get_cache() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi

    # Check cache age
    local now=$(date +%s)
    local cache_time=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
    local cache_age=$((now - cache_time))

    if [[ $cache_age -gt $CACHE_MAX_AGE ]]; then
        return 1
    fi

    cat "$CACHE_FILE"
    return 0
}

# Main dispatcher
case "${1:-}" in
    update)
        update_cache
        ;;
    get)
        get_cache
        ;;
    *)
        echo "Usage: $0 {update|get}" >&2
        exit 1
        ;;
esac
