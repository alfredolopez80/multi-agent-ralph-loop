#!/bin/bash
# statusline-git.sh - Enhanced StatusLine with Git Branch/Worktree Info
#
# VERSION: 2.43.0
#
# Wraps claude-hud output and prepends git branch/worktree information.
# Designed to be resilient to plugin updates.
#
# Usage: Called by settings.json statusLine.command
#
# Part of Multi-Agent Ralph v2.43

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
DIM='\033[2m'
RESET='\033[0m'

# Get git branch/worktree info
get_git_info() {
    local cwd="${1:-.}"

    # Check if in a git repository
    if ! git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
        return
    fi

    local branch=""
    local worktree_info=""
    local is_worktree=false

    # Get current branch name
    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [[ -z "$branch" ]]; then
        # Detached HEAD - show short commit hash
        branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
        branch="($branch)"
    fi

    # Check if this is a worktree (not the main repo)
    local git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    if [[ "$git_dir" == *".git/worktrees/"* ]]; then
        is_worktree=true
        # Extract worktree name from path
        local wt_name=$(basename "$(dirname "$git_dir")" 2>/dev/null)
        worktree_info=" 🌳${wt_name}"
    fi

    # Check for uncommitted changes
    local status_icon=""
    if ! git -C "$cwd" diff --quiet HEAD &>/dev/null; then
        status_icon="*"
    fi

    # Check for unpushed commits
    local ahead=$(git -C "$cwd" rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
    local push_icon=""
    if [[ "$ahead" -gt 0 ]]; then
        push_icon="↑${ahead}"
    fi

    # Build output
    local git_output=""
    if [[ "$is_worktree" == true ]]; then
        git_output="${MAGENTA}⎇ ${branch}${status_icon}${worktree_info}${RESET}"
    else
        git_output="${GREEN}⎇ ${branch}${status_icon}${RESET}"
    fi

    if [[ -n "$push_icon" ]]; then
        git_output="${git_output} ${DIM}${push_icon}${RESET}"
    fi

    echo -e "$git_output"
}

# Read stdin to pass to claude-hud
stdin_data=$(cat)

# Extract cwd from stdin JSON
cwd=$(echo "$stdin_data" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

# Get git info
git_info=$(get_git_info "$cwd")

# Find and run claude-hud
claude_hud_dir=$(ls -td ~/.claude/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | head -1)

if [[ -n "$claude_hud_dir" ]] && [[ -f "${claude_hud_dir}dist/index.js" ]]; then
    # Run claude-hud and capture output
    hud_output=$(echo "$stdin_data" | node "${claude_hud_dir}dist/index.js" 2>/dev/null)

    if [[ -n "$git_info" ]]; then
        # Prepend git info to first line of hud output
        first_line=$(echo "$hud_output" | head -1)
        rest=$(echo "$hud_output" | tail -n +2)

        # Use non-breaking spaces for proper display
        git_segment="${git_info} │ "
        git_segment="${git_segment// / }"  # Replace spaces with non-breaking spaces

        echo -e "${git_segment}${first_line}"
        if [[ -n "$rest" ]]; then
            echo "$rest"
        fi
    else
        echo "$hud_output"
    fi
else
    # Fallback: just show git info if claude-hud is not available
    if [[ -n "$git_info" ]]; then
        echo -e "$git_info"
    else
        echo "[statusline] Initializing..."
    fi
fi
