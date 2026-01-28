#!/bin/bash
# context-from-cli.sh - Extract context usage from /context command
# VERSION: 1.0.0
# Hook: UserPromptSubmit (runs before each prompt)
# Purpose: Parse /context output and update project-specific cache
#
# This hook works around the Zai wrapper not providing context_window fields
# by calling /context directly and parsing its output
#
# Output: {"continue": true} (UserPromptSubmit JSON format)

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

set -euo pipefail

# Error trap: Always output valid JSON for UserPromptSubmit
trap 'echo "{\"continue\": true}"' ERR EXIT

# Configuration
CACHE_DIR="${HOME}/.ralph/cache"
PROJECT_CACHE_FILE="${CACHE_DIR}/context-$PROJECT_ID.json"

# Create cache directory
mkdir -p "$CACHE_DIR" 2>/dev/null

# Get project ID from git remote or path
get_project_id() {
    local cwd="$1"

    # Try git remote first
    if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
        local remote
        remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote" ]]; then
            # Extract owner/repo from git@github.com:owner/repo.git or https://github.com/owner/repo.git
            if [[ "$remote" =~ github\.com[\/:]([^\/]+)\/([^\/\.]+) ]]; then
                echo "${BASH_REMATCH[1]}-${BASH_REMATCH[2]}"
                return 0
            fi
        fi

        # Fallback to git directory hash
        local git_dir
        git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
        if [[ -n "$git_dir" ]]; then
            echo "git-$(echo "$git_dir" | md5sum | cut -d' ' -f1)"
            return 0
        fi
    fi

    # Fallback to directory hash
    echo "dir-$(echo "$cwd" | md5sum | cut -d' ' -f1)"
}

# Get current directory
CWD=$(echo "$INPUT" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

# Generate project ID
PROJECT_ID=$(get_project_id "$CWD")
PROJECT_CACHE_FILE="${CACHE_DIR}/context-$PROJECT_ID.json"

# Only update if cache is older than 30 seconds
update_cache_if_needed() {
    local now=$(date +%s)
    local cache_age=9999999

    if [[ -f "$PROJECT_CACHE_FILE" ]]; then
        local cache_time=$(jq -r '.timestamp // 0' "$PROJECT_CACHE_FILE" 2>/dev/null || echo "0")
        cache_age=$((now - cache_time))
    fi

    # Only update every 30 seconds
    if [[ $cache_age -lt 30 ]]; then
        return 0
    fi

    # Call /context and parse output
    # This assumes /context is available in the PATH
    local context_output
    if context_output=$(claude context 2>/dev/null); then
        # Extract the usage line from /context output
        # Format: "glm-4.7 · Xk/200k tokens (Y%)"
        local usage_line=$(echo "$context_output" | grep -o "glm-4\.7 · [0-9k]*/[0-9k]* tokens ([0-9]%*)" | head -1)

        if [[ -n "$usage_line" ]]; then
            # Parse the values using regex
            local used_display=$(echo "$usage_line" | grep -o "[0-9k]*/[0-9k]*" | cut -d'/' -f1)
            local size_display=$(echo "$usage_line" | grep -o "[0-9k]*/[0-9k]*" | cut -d'/' -f2)
            local used_pct=$(echo "$usage_line" | grep -o "([0-9]%)" | grep -o "[0-9]*")

            # Convert k suffix to actual numbers
            local used_tokens=0
            local size_tokens=200000

            if [[ "$used_display" =~ ([0-9]+)k ]]; then
                used_tokens=${BASH_REMATCH[1]}000
            else
                used_tokens=${used_display:-0}
            fi

            if [[ "$size_display" =~ ([0-9]+)k ]]; then
                size_tokens=${BASH_REMATCH[1]}000
            else
                size_tokens=${size_display:-200000}
            fi

            # Calculate remaining
            local remaining_tokens=$((size_tokens - used_tokens))
            local remaining_pct=$((100 - ${used_pct:-0}))

            # Create cache JSON
            local cache_json=$(jq -n \
                --argjson timestamp "$(date +%s)" \
                --argjson context_size "$size_tokens" \
                --argjson used_tokens "$used_tokens" \
                --argjson free_tokens "$remaining_tokens" \
                --argjson used_percentage "${used_pct:-0}" \
                --argjson remaining_percentage "$remaining_pct" \
                '{
                    timestamp: $timestamp,
                    context_size: $context_size,
                    used_tokens: $used_tokens,
                    free_tokens: $free_tokens,
                    used_percentage: $used_percentage,
                    remaining_percentage: $remaining_percentage
                }')

            echo "$cache_json" > "$PROJECT_CACHE_FILE"
        fi
    fi
}

# Update cache in background (don't block)
update_cache_if_needed &

# Clear trap and output success
trap - ERR EXIT
echo '{"continue": true}'
