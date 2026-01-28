#!/bin/bash
# update-context-cache.sh - Update context cache with /context values
#
# This script helps update the context cache when you want to refresh
# the values shown in the statusline.
#
# Usage:
#   ./update-context-cache.sh [--force] [USED_PCT] [FREE_TOKENS]
#
# Examples:
#   ./update-context-cache.sh                    # Show current cache
#   ./update-context-cache.sh --force 89 22000   # Force update with 89% used, 22k free
#   ./update-context-cache.sh --update           # Try to update from session file
#
# Part of Multi-Agent Ralph v2.77.1

CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/context-usage.json"
CONTEXT_SIZE=200000

show_cache() {
    if [[ -f "$CACHE_FILE" ]]; then
        echo "=== Current Cache ==="
        jq '.' "$CACHE_file" 2>/dev/null || cat "$CACHE_FILE"

        # Calculate age
        now=$(date +%s)
        cache_time=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null)
        cache_age=$((now - cache_time))
        cache_age_min=$((cache_age / 60))

        echo ""
        echo "Cache age: ${cache_age_min} minutes (max: 5 minutes)"
    else
        echo "No cache file found at: $CACHE_FILE"
    fi
}

update_from_session() {
    echo "Attempting to update from session file..."

    local session_file
    session_file=$(ls -t ~/.claude-sneakpeek/zai/config/projects/-Users-alfredolopez-Documents-GitHub-multi-agent-ralph-loop/*.jsonl 2>/dev/null | head -1)

    if [[ ! -f "$session_file" ]]; then
        echo "✗ No session file found"
        return 1
    fi

    echo "Session file: $session_file"

    local context_data
    context_data=$(tail -1 "$session_file" 2>/dev/null | jq -r '.context_window // {}')

    if [[ "$context_data" == "null" ]] || [[ "$context_data" == "{}" ]]; then
        echo "✗ No context_window data in session file"
        echo ""
        echo "The session file doesn't contain context usage data."
        echo "You can manually update the cache using:"
        echo "  $0 --force <USED_PCT> <FREE_TOKENS>"
        echo ""
        echo "Example:"
        echo "  $0 --force 89 22000  # 89% used, 22k free"
        return 1
    fi

    local remaining_pct
    remaining_pct=$(echo "$context_data" | jq -r '.remaining_percentage // ""')

    if [[ -z "$remaining_pct" ]] || [[ "$remaining_pct" == "null" ]] || [[ "$remaining_pct" == "100" ]] || [[ "$remaining_pct" == "0" ]]; then
        echo "✗ Invalid remaining_percentage: $remaining_pct"
        return 1
    fi

    local used_pct=$((100 - ${remaining_pct%.*}))
    local used_tokens=$((CONTEXT_SIZE * used_pct / 100))
    local free_tokens=$((CONTEXT_SIZE - used_tokens))

    # Create cache JSON
    local cache_json=$(jq -n \
        --argjson timestamp "$(date +%s)" \
        --argjson context_size "$CONTEXT_SIZE" \
        --argjson used_tokens "$used_tokens" \
        --argjson free_tokens "$free_tokens" \
        --argjson used_percentage "$used_pct" \
        --argjson remaining_percentage "$remaining_pct" \
        '{
            timestamp: $timestamp,
            context_size: $context_size,
            used_tokens: $used_tokens,
            free_tokens: $free_tokens,
            used_percentage: $used_percentage,
            remaining_percentage: $remaining_percentage
        }')

    mkdir -p "$CACHE_DIR"
    echo "$cache_json" > "$CACHE_FILE"

    echo "✓ Cache updated: ${used_pct}% used (${used_tokens}k/${CONTEXT_SIZE}k)"
    show_cache
}

force_update() {
    local used_pct=$1
    local free_tokens=$2

    if [[ -z "$used_pct" ]] || [[ -z "$free_tokens" ]]; then
        echo "Usage: $0 --force <USED_PCT> <FREE_TOKENS>"
        echo ""
        echo "Example: $0 --force 89 22000"
        echo "  This means: 89% used, 22000 tokens free"
        return 1
    fi

    local used_tokens=$((CONTEXT_SIZE - free_tokens))
    local remaining_pct=$((100 - used_pct))

    # Create cache JSON
    local cache_json=$(jq -n \
        --argjson timestamp "$(date +%s)" \
        --argjson context_size "$CONTEXT_SIZE" \
        --argjson used_tokens "$used_tokens" \
        --argjson free_tokens "$free_tokens" \
        --argjson used_percentage "$used_pct" \
        --argjson remaining_percentage "$remaining_pct" \
        '{
            timestamp: $timestamp,
            context_size: $context_size,
            used_tokens: $used_tokens,
            free_tokens: $free_tokens,
            used_percentage: $used_percentage,
            remaining_percentage: $remaining_percentage
        }')

    mkdir -p "$CACHE_DIR"
    echo "$cache_json" > "$CACHE_FILE"

    echo "✓ Cache force updated: ${used_pct}% used (${used_tokens}k/${CONTEXT_SIZE}k)"
    show_cache
}

# Main dispatcher
case "${1:-}" in
    --update)
        update_from_session
        ;;
    --force)
        force_update "$2" "$3"
        ;;
    *)
        show_cache
        ;;
esac
