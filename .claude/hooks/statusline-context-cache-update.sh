#!/bin/bash
# statusline-context-cache-update.sh - Updates context usage cache before statusline display
#
# This hook runs before statusline command to ensure the cache has fresh data
# It updates the cache from /context output if the cache is stale (> 60 seconds old)
#
# Part of Multi-Agent Ralph v2.77.0
#

CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/context-usage.json"
CACHE_MAX_AGE=60  # seconds

# Ensure cache directory exists
mkdir -p "$CACHE_DIR" 2>/dev/null

update_context_cache() {
    # Try to get real usage from the current session
    local session_file
    session_file=$(ls -t ~/.claude-sneakpeek/zai/config/projects/-Users-alfredolopez-Documents-GitHub-multi-agent-ralph-loop/*.jsonl 2>/dev/null | head -1)

    if [[ ! -f "$session_file" ]]; then
        return 0
    fi

    # Get latest context info
    local context_data
    context_data=$(tail -1 "$session_file" 2>/dev/null | jq -r '.context_window // {}')

    if [[ -z "$context_data" ]] || [[ "$context_data" == "null" ]] || [[ "$context_data" == "{}" ]]; then
        return 0
    fi

    local context_size
    context_size=$(echo "$context_data" | jq -r '.context_window_size // 200000')
    local remaining_pct
    remaining_pct=$(echo "$context_data" | jq -r '.remaining_percentage // "100"')

    # Calculate used percentage
    local used_pct=0
    if [[ -n "$remaining_pct" ]] && [[ "$remaining_pct" != "null" ]] && [[ "$remaining_pct" != "100" ]]; then
        # Use inverse of remaining_percentage
        used_pct=$((100 - ${remaining_pct%.*}))
    else
        # Estimate based on typical usage when remaining is 100%
        # If remaining is 100, it means we don't have real data, so estimate
        # We'll use a conservative estimate or leave at 0
        used_pct=0
    fi

    # Calculate tokens
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
    return 0
}

# Check if cache needs update
needs_update() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 0
    fi

    local now=$(date +%s)
    local cache_time=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
    local cache_age=$((now - cache_time))

    [[ $cache_age -gt $CACHE_MAX_AGE ]]
}

# Update cache if needed, then output the original input
if needs_update; then
    update_context_cache
fi

# Output original stdin for statusline
cat
