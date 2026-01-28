#!/bin/bash
# parse-context-output.sh - Parses /context command output to extract real usage
#
# This script executes /context and parses its output to extract:
# - Free space percentage
# - Used percentage (calculated as 100 - free)
# - Used tokens (calculated from percentage)
#
# Output format: JSON with timestamp, used_percentage, remaining_percentage, used_tokens, free_tokens

# Run /context and capture output
context_output=$(/context 2>/dev/null)

# Extract free space percentage (format: "Free space: 22k (10.9%)")
free_space_pct=$(echo "$context_output" | grep -oE 'Free space: [0-9.]+k \(([0-9.]+)%\)' | grep -oE '\([0-9.]+%' | tr -d '()%')

# Extract autocompact buffer (format: "Autocompact buffer: 45.0k tokens (22.5%)")
buffer_pct=$(echo "$context_output" | grep -oE 'Autocompact buffer: [0-9.]+k tokens \(([0-9.]+)%\)' | grep -oE '\([0-9.]+%' | tr -d '()%')

# Default values
context_size=200000
remaining_pct=100

if [[ -n "$free_space_pct" ]]; then
    remaining_pct=$(echo "$free_space_pct" | LC_NUMERIC=C awk '{printf "%d", $1}')
fi

# Calculate used percentage
used_pct=$((100 - remaining_pct))

# Calculate tokens
used_tokens=$((context_size * used_pct / 100))
free_tokens=$((context_size - used_tokens))

# Output JSON
jq -n \
    --argjson timestamp "$(date +%s)" \
    --argjson context_size "$context_size" \
    --argjson used_tokens "$used_tokens" \
    --argjson free_tokens "$free_tokens" \
    --argjson used_percentage "$used_pct" \
    --argjson remaining_percentage "$remaining_pct" \
    --argjson buffer_percentage "${buffer_pct:-22.5}" \
    '{
        timestamp: $timestamp,
        context_size: $context_size,
        used_tokens: $used_tokens,
        free_tokens: $free_tokens,
        used_percentage: $used_percentage,
        remaining_percentage: $remaining_percentage,
        buffer_percentage: $buffer_percentage
    }'
