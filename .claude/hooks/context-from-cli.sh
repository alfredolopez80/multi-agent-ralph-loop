#!/bin/bash
# context-from-cli.sh - Extract context usage from /context command
# VERSION: 1.1.0
# Hook: UserPromptSubmit (runs before each prompt)
# Purpose: Parse /context output and update cache
#
# CHANGELOG v1.1.0:
# - Removed background execution (causes stuck processes)
# - Write to generic context-usage.json (simpler, works with statusline v2.78.7)
# - Only update if cache is older than 30 seconds
#
# Output: {"continue": true} (UserPromptSubmit JSON format)

set -euo pipefail

# Error trap: Always output valid JSON for UserPromptSubmit
trap 'echo "{\"continue\": true}"' ERR EXIT

# Configuration
CACHE_FILE="${HOME}/.ralph/cache/context-usage.json"
LOCK_FILE="${HOME}/.ralph/cache/context-update.lock"

# Create cache directory
mkdir -p "$(dirname "$CACHE_FILE")" 2>/dev/null

# Check if update is needed (every 30 seconds)
update_cache_if_needed() {
    local now=$(date +%s)
    local cache_age=9999999

    if [[ -f "$CACHE_FILE" ]]; then
        local cache_time=$(jq -r '.timestamp // 0' "$CACHE_FILE" 2>/dev/null || echo "0")
        cache_age=$((now - cache_time))
    fi

    # Only update every 30 seconds
    if [[ $cache_age -lt 30 ]]; then
        return 0
    fi

    # Prevent concurrent updates
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_time=$(stat -f "%m" "$LOCK_FILE" 2>/dev/null || stat -c "%Y" "$LOCK_FILE" 2>/dev/null || echo "0")
        local lock_age=$((now - lock_time))
        # Remove stale lock (> 60 seconds)
        if [[ $lock_age -gt 60 ]]; then
            rm -f "$LOCK_FILE" 2>/dev/null || true
        else
            return 0
        fi
    fi

    # Create lock file
    touch "$LOCK_FILE"

    # Call /context and parse output
    local context_output
    if context_output=$(claude context 2>/dev/null); then
        # Parse Free space line (shows CORRECT values even when first line is buggy)
        local free_line=$(echo "$context_output" | grep -o "Free space: [0-9k]* ([0-9.]*)" | head -1)

        local used_tokens=0
        local used_pct=0
        local size_tokens=200000

        if [[ -n "$free_line" ]]; then
            # Parse free space values
            local free_display=$(echo "$free_line" | grep -o "[0-9.]*" | sed 's/k//')
            local free_pct=$(echo "$free_line" | grep -o "([0-9.]*)" | sed 's/%//')

            # Calculate used tokens from free space
            local free_tokens=$((free_display * 1000))
            used_tokens=$((size_tokens - free_tokens))
            used_pct=$((used_tokens * 100 / size_tokens))

            # Clamp to valid range
            if [[ $used_tokens -lt 0 ]]; then used_tokens=0; fi
            if [[ $used_tokens -gt $size_tokens ]]; then used_tokens=$size_tokens; fi
            if [[ $used_pct -lt 0 ]]; then used_pct=0; fi
            if [[ $used_pct -gt 100 ]]; then used_pct=100; fi
        fi

        # Calculate remaining
        local remaining_tokens=$((size_tokens - used_tokens))
        local remaining_pct=$((100 - used_pct))

        # Create cache JSON
        jq -n \
            --argjson timestamp "$(date +%s)" \
            --argjson context_size "$size_tokens" \
            --argjson used_tokens "$used_tokens" \
            --argjson free_tokens "$remaining_tokens" \
            --argjson used_percentage "$used_pct" \
            --argjson remaining_percentage "$remaining_pct" \
            '{
                timestamp: $timestamp,
                context_size: $context_size,
                used_tokens: $used_tokens,
                free_tokens: $free_tokens,
                used_percentage: $used_percentage,
                remaining_percentage: $remaining_percentage
            }' > "$CACHE_FILE"
    fi

    # Remove lock file
    rm -f "$LOCK_FILE" 2>/dev/null || true
}

# Update cache (synchronously, no background)
update_cache_if_needed

# Clear trap and output success
trap - ERR EXIT
echo '{"continue": true}'
