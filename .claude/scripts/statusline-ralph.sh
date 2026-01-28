#!/bin/bash
# statusline-ralph.sh - Enhanced StatusLine with Git + Ralph Progress + GLM Usage + Context Info
#
# VERSION: 2.80.0
#
# CHANGELOG v2.80.0:
# - Simplified context display to show only CtxUse (removed Free and Buff)
#
# CHANGELOG v2.78.5:
#
# CHANGELOG v2.78.4:
# - CRITICAL FIX: Removed global cache dependency (was sharing data across projects)
#
# CHANGELOG v2.78.2:
# - FIX: get_context_usage_current() now uses current_usage object for REAL window usage
# - This matches /context command by calculating: input_tokens + cache_creation + cache_read
#
# CHANGELOG v2.78.1:
# - ROLLBACK: get_context_usage_cumulative() now uses total_input_tokens + total_output_tokens again
# - This restores the progress bar showing session-accumulated tokens (e.g., 🤖 391k/200k)
#
# CHANGELOG v2.77.1:
# - FIXED: Cache preservation - won't overwrite valid data with zeros
# - INCREASED: Cache expiry from 60s to 300s (5 minutes)
# - Cache now preserves last known valid context values when session file is empty
#
# CHANGELOG v2.77.0:
# - ADDED: Context display matching /context format exactly
# - Shows: | CtxUse: 178k/200k tokens (89%) | Free: 22k (11%) | Buff 45.0k tokens (22.5%) |
# - Uses cached real values from /context command output
# - Preserves claude-hud's 🤖 progress bar based on cumulative tokens
#
# Extends statusline-git.sh with orchestration progress tracking.
# Reads plan-state.json to show current phase and step completion.
# Shows GLM Coding Plan usage (5-hour + monthly MCP).
#
# Format: ⎇ branch* │ [claude-hud 🤖 ████░░░░░ cumulative] │ CtxUse: 0k/200k (0%) │ ⏱️ 1% (~5h) │ 📊 3/7 42%
#
# Usage: Called by settings.json statusLine.command
#
# Part of Multi-Agent Ralph v2.77.2

# BUG-002 FIX: Define log function (was calling macOS system log command)
# StatusLine should be silent - log to file only if DEBUG is set
log() {
    if [[ -n "${STATUSLINE_DEBUG:-}" ]]; then
        echo "[statusline] $*" >> "${HOME}/.ralph/logs/statusline.log" 2>/dev/null || true
    fi
}

# Colors - Functions that generate ANSI codes for subshell compatibility
ansi_cyan() { printf '\033[0;36m'; }
ansi_green() { printf '\033[0;32m'; }
ansi_yellow() { printf '\033[0;33m'; }
ansi_red() { printf '\033[0;31m'; }
ansi_magenta() { printf '\033[0;35m'; }
ansi_blue() { printf '\033[0;34m'; }
ansi_dim() { printf '\033[2m'; }
ansi_reset() { printf '\033[0m'; }

# Cache the codes as variables for convenience
CYAN=$(ansi_cyan)
GREEN=$(ansi_green)
YELLOW=$(ansi_yellow)
RED=$(ansi_red)
MAGENTA=$(ansi_magenta)
BLUE=$(ansi_blue)
DIM=$(ansi_dim)
RESET=$(ansi_reset)

# ============================================
# Context Display Functions (v2.77.0)
# ============================================

# Helper function: format tokens with K suffix
# For buffer, use decimals (e.g., 45.0k) to match /context format
format_tokens() {
    local val=$1
    local is_buffer="${2:-false}"
    if [[ $val -ge 1000 ]]; then
        if [[ "$is_buffer" == "true" ]]; then
            # Buffer shows decimals (e.g., 45.0k) - force LC_NUMERIC=C for dot separator
            local k_val=$(LC_NUMERIC=C awk "BEGIN {printf \"%.1f\", $val/1000}")
            echo "${k_val}k"
        else
            echo "$((val / 1000))k"
        fi
    elif [[ $val -eq 0 ]]; then
        echo "0k"
    else
        echo "${val}"
    fi
}

# Get cumulative context usage (for claude-hud style progress bar)
# Shows: 🤖 ██████████░░ 391k/200k (195%)
# Uses total_input_tokens + total_output_tokens to show SESSION ACCUMULATED usage
# This shows total tokens used in the session, NOT current window percentage
get_context_usage_cumulative() {
    local context_json="$1"

    local context_size=$(echo "$context_json" | jq -r '.context_window_size // 200000')
    local total_input=$(echo "$context_json" | jq -r '.total_input_tokens // 0')
    local total_output=$(echo "$context_json" | jq -r '.total_output_tokens // 0')

    local total_used=$((total_input + total_output))
    local used_pct=$((total_used * 100 / context_size))

    local used_display=$(format_tokens "$total_used")
    local size_display=$(format_tokens "$context_size")

    # Color coding
    local color="$CYAN"
    if [[ $used_pct -ge 85 ]]; then
        color="$RED"
    elif [[ $used_pct -ge 75 ]]; then
        color="$YELLOW"
    elif [[ $used_pct -ge 50 ]]; then
        color="$GREEN"
    fi

    # Build progress bar (10 blocks)
    local filled_blocks=$((used_pct / 10))
    [[ $filled_blocks -gt 10 ]] && filled_blocks=10
    [[ $filled_blocks -lt 0 ]] && filled_blocks=0
    local progress_bar=$(printf '█%.0s' $(seq 1 $filled_blocks))$(printf '░%.0s' $(seq 1 $((10 - filled_blocks))))

    # Format: 🤖 ██████████░░ 391k/200k (195%)
    printf '%b' "${color}🤖 ${progress_bar}${RESET} ${color}${used_display}/${size_display} (${used_pct}%)${RESET}"
}

# Get current context usage matching /context format exactly
# Shows: | CtxUse: 133k/200k tokens (66.6%) | Free: 22k (10.9%) | Buff 45.0k tokens (22.5%) |
# v2.78.5: Use cumulative tokens but clamped to context window (best available approximation)
# The stdin JSON does NOT contain current_usage, and /context is internal API only
# We use total_input_tokens + total_output_tokens as the best available proxy
get_context_usage_current() {
    local context_json="$1"

    local context_size=$(echo "$context_json" | jq -r '.context_window_size // 200000')
    local used_pct=0
    local used_tokens=0

    # v2.78.5: Use cumulative tokens as proxy (best available approximation)
    # The stdin JSON does not contain current_usage (it's null or missing)
    # /context uses internal API that statusline cannot access
    local total_input=$(echo "$context_json" | jq -r '.total_input_tokens // 0')
    local total_output=$(echo "$context_json" | jq -r '.total_output_tokens // 0')
    local cumulative_tokens=$((total_input + total_output))

    # Clamp to context window (we can't exceed the window)
    if [[ $cumulative_tokens -gt $context_size ]]; then
        used_tokens=$context_size
        used_pct=100
    elif [[ $cumulative_tokens -gt 0 ]]; then
        used_tokens=$cumulative_tokens
        used_pct=$((used_tokens * 100 / context_size))
    fi

    # Fallback: try used_percentage if available
    if [[ $used_tokens -eq 0 ]]; then
        used_pct=$(echo "$context_json" | jq -r '.used_percentage // 0')
        used_tokens=$((context_size * used_pct / 100))
    fi

    # Validate percentage is within bounds (0-100)
    if [[ $used_pct -lt 0 ]]; then used_pct=0; fi
    if [[ $used_pct -gt 100 ]]; then used_pct=100; fi

    # Calculate remaining and token counts
    local remaining_pct=$((100 - used_pct))
    local free_space=$((context_size - used_tokens))

    # Autocompact buffer (22.5% of context window)
    local autocompact_buffer=$((context_size * 225 / 1000))

    local ctx_display=$(format_tokens "$used_tokens")
    local size_display=$(format_tokens "$context_size")
    local free_display=$(format_tokens "$free_space")
    local buffer_display=$(format_tokens "$autocompact_buffer" true)

    # Color coding
    local color="$CYAN"
    if [[ $used_pct -ge 85 ]]; then
        color="$RED"
    elif [[ $used_pct -ge 75 ]]; then
        color="$YELLOW"
    elif [[ $used_pct -ge 50 ]]; then
        color="$GREEN"
    fi

    # Format: | CtxUse: 133k/200k tokens (66.6%)
    printf '%b' "CtxUse:${RESET} ${ctx_display}/${size_display} tokens (${color}${used_pct}%${RESET})"
}

# ============================================
# Git Info Function
# ============================================

get_git_info() {
    local cwd="${1:-.}"

    if ! git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
        return
    fi

    local branch=""
    local worktree_info=""
    local is_worktree=false

    branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null)
    if [[ -z "$branch" ]]; then
        branch=$(git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
        branch="($branch)"
    fi

    local git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    if [[ "$git_dir" == *".git/worktrees/"* ]]; then
        is_worktree=true
        local wt_name=$(basename "$(dirname "$git_dir")" 2>/dev/null)
        worktree_info=" 🌳${wt_name}"
    fi

    local status_icon=""
    if ! git -C "$cwd" diff --quiet HEAD &>/dev/null; then
        status_icon="*"
    fi

    local ahead=$(git -C "$cwd" rev-list --count @{upstream}..HEAD 2>/dev/null || echo "0")
    local push_icon=""
    if [[ "$ahead" -gt 0 ]]; then
        push_icon="↑${ahead}"
    fi

    local git_output=""
    if [[ "$is_worktree" == true ]]; then
        git_output="${MAGENTA}⎇ ${branch}${status_icon}${worktree_info}${RESET}"
    else
        git_output="${GREEN}⎇ ${branch}${status_icon}${RESET}"
    fi

    if [[ -n "$push_icon" ]]; then
        git_output="${git_output} ${DIM}${push_icon}${RESET}"
    fi

    printf '%b\n' "$git_output"
}

# ============================================
# GLM Usage Functions
# ============================================

get_glm_plan_usage() {
    local cache_manager="${PROJECT_ROOT:-$(pwd)}/.claude/scripts/glm-usage-cache-manager.sh"
    if [[ ! -f "$cache_manager" ]]; then
        cache_manager="${HOME}/.ralph/scripts/glm-usage-cache-manager.sh"
    fi

    if [[ -f "$cache_manager" ]]; then
        "$cache_manager" get-statusline 2>/dev/null || echo ""
    fi
}

# ============================================
# Ralph Progress Function
# ============================================

get_ralph_progress() {
    local cwd="${1:-.}"
    local plan_state_file=""

    if [[ -f "${cwd}/.claude/plan-state.json" ]]; then
        plan_state_file="${cwd}/.claude/plan-state.json"
    fi

    if [[ -z "$plan_state_file" ]] && [[ -f "${HOME}/.ralph/metadata/current-project.json" ]]; then
        local active_project_path
        active_project_path=$(jq -r '.project.path // ""' "${HOME}/.ralph/metadata/current-project.json" 2>/dev/null || echo "")

        if [[ -n "$active_project_path" ]]; then
            if [[ "$active_project_path" =~ \.\. ]] || [[ "$active_project_path" != /* ]]; then
                active_project_path=""
            else
                active_project_path=$(realpath "$active_project_path" 2>/dev/null || echo "")
            fi
        fi

        if [[ -n "$active_project_path" ]] && [[ -f "${active_project_path}/.claude/plan-state.json" ]]; then
            plan_state_file="${active_project_path}/.claude/plan-state.json"
        fi
    fi

    if [[ -z "$plan_state_file" ]]; then
        if [[ -n "${PROJECT_ID:-}" ]] && [[ -f "${HOME}/.ralph/active-plan/${PROJECT_ID}.json" ]]; then
            plan_state_file="${HOME}/.ralph/active-plan/${PROJECT_ID}.json"
        else
            if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
                local repo_remote
                repo_remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")
                if [[ -n "$repo_remote" ]]; then
                    local project_id
                    project_id=$(basename "$repo_remote" .git 2>/dev/null | sed 's|.*/||')
                    if [[ -f "${HOME}/.ralph/active-plan/${project_id}.json" ]]; then
                        plan_state_file="${HOME}/.ralph/active-plan/${project_id}.json"
                    fi
                fi
            fi
        fi
    fi

    if [[ -z "$plan_state_file" ]] || [[ ! -f "$plan_state_file" ]]; then
        return
    fi

    local plan_state
    plan_state=$(cat "$plan_state_file" 2>/dev/null)

    if [[ -z "$plan_state" ]]; then
        return
    fi

    local version
    version=$(echo "$plan_state" | jq -r '.version // "1.0"' 2>/dev/null)

    if [[ -z "$version" ]]; then
        return
    fi

    local total_steps
    total_steps=$(echo "$plan_state" | jq -r '
        if .steps then
            if (.steps | type) == "array" then
                (.steps | length)
            else
                (.steps | keys | length)
            end
        else
            0
        end
    ' 2>/dev/null)

    if [[ "$total_steps" == "0" || -z "$total_steps" ]]; then
        return
    fi

    local completed_steps
    completed_steps=$(echo "$plan_state" | jq -r '
        if .steps then
            if (.steps | type) == "array" then
                ([.steps[] | select(.status == "completed" or .status == "verified")] | length)
            else
                ([.steps | to_entries[] | select(.value.status == "completed" or .value.status == "verified")] | length)
            end
        else
            0
        end
    ' 2>/dev/null)

    local in_progress_steps
    in_progress_steps=$(echo "$plan_state" | jq -r '
        if .steps then
            if (.steps | type) == "array" then
                ([.steps[] | select(.status == "in_progress")] | length)
            else
                ([.steps | to_entries[] | select(.value.status == "in_progress")] | length)
            end
        else
            0
        end
    ' 2>/dev/null)

    local workflow_type adaptive_mode
    workflow_type=$(echo "$plan_state" | jq -r '.classification.workflow_route // .classification.route // .workflow_type // "STANDARD"' 2>/dev/null)
    adaptive_mode=$(echo "$plan_state" | jq -r '.classification.adaptive_mode // ""' 2>/dev/null)

    if [[ -n "$adaptive_mode" ]] && [[ "$adaptive_mode" != "null" ]]; then
        workflow_type="$adaptive_mode"
    fi

    local percentage=0
    if [[ "$total_steps" -gt 0 ]]; then
        percentage=$((completed_steps * 100 / total_steps))
    fi

    local status
    if [[ "$completed_steps" -eq "$total_steps" ]]; then
        status="completed"
    elif [[ "$in_progress_steps" -gt 0 ]]; then
        status="in_progress"
    else
        status="pending"
    fi

    local icon="📊"
    case "$status" in
        "in_progress"|"executing")
            icon="🔄"
            ;;
        "completed"|"verified"|"VERIFIED_DONE")
            icon="✅"
            ;;
        "paused"|"waiting")
            icon="⏸️"
            ;;
        "error"|"failed")
            icon="❌"
            ;;
    esac

    case "$workflow_type" in
        "FAST_PATH")
            icon="⚡"
            ;;
        "SIMPLE")
            icon="📝"
            ;;
        "COMPLEX")
            icon="🔄"
            ;;
        "RECURSIVE_DECOMPOSE")
            icon="🔀"
            ;;
    esac

    local current_phase phase_name active_agent
    current_phase=$(echo "$plan_state" | jq -r '.current_phase // .loop_state.current_phase // empty' 2>/dev/null)

    if [[ -n "$current_phase" ]] && [[ "$current_phase" != "null" ]]; then
        phase_name=$(echo "$plan_state" | jq -r --arg phase "$current_phase" '.phases[] | select(.phase_id == $phase) | .phase_name // empty' 2>/dev/null)
        if [[ -z "$phase_name" ]] || [[ "$phase_name" == "null" ]]; then
            phase_name="$current_phase"
        fi
    fi

    active_agent=$(echo "$plan_state" | jq -r '.active_agent // .loop_state.active_agent // empty' 2>/dev/null)

    local status_details=""
    if [[ -n "$phase_name" ]] && [[ "$phase_name" != "null" ]]; then
        status_details="${status_details} ${DIM}${phase_name}${RESET}"
    fi
    if [[ -n "$active_agent" ]] && [[ "$active_agent" != "null" ]]; then
        status_details="${status_details} ${MAGENTA}${active_agent}${RESET}"
    fi

    local unsatisfied_barriers
    unsatisfied_barriers=$(echo "$plan_state" | jq -r '
        if .barriers then
            [.barriers | to_entries[] | select(.value == false) | .key] | join(",")
        else
            ""
        end
    ' 2>/dev/null)
    if [[ -n "$unsatisfied_barriers" ]] && [[ "$unsatisfied_barriers" != "null" ]]; then
        status_details="${status_details} ${YELLOW}!${unsatisfied_barriers}${RESET}"
    fi

    local progress_output
    if [[ "$percentage" -ge 100 ]]; then
        progress_output="${BLUE}${icon}${RESET} ${GREEN}done${RESET}${status_details}"
    else
        progress_output="${BLUE}${icon}${RESET} ${DIM}${completed_steps}/${total_steps}${RESET} ${CYAN}${percentage}%${RESET}${status_details}"
    fi

    printf '%b\n' "$progress_output"
}

# ============================================
# Main Execution
# ============================================

# Read stdin
stdin_data=$(cat)

# Extract cwd from stdin JSON
cwd=$(echo "$stdin_data" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

# ============================================
# v2.78.0: Extract context window directly from stdin JSON
# ============================================
# No cache needed - used_percentage comes directly from Claude Code's native tracking
# This is the SAME data source as /context command
# See: docs/context-monitoring/ANALYSIS.md

context_info=$(echo "$stdin_data" | jq -r '.context_window // "{}"' 2>/dev/null)
context_cumulative_display=""
context_current_display=""

if [[ -n "$context_info" ]] && [[ "$context_info" != "null" ]] && [[ "$context_info" != "{}" ]]; then
    context_cumulative_display=$(get_context_usage_cumulative "$context_info")
    context_current_display=$(get_context_usage_current "$context_info")
fi

# Get git info
git_info=$(get_git_info "$cwd")

# Get GLM Coding Plan usage
glm_plan_usage=$(get_glm_plan_usage)

# Get ralph progress
ralph_progress=$(get_ralph_progress "$cwd")

# Find and run claude-hud
claude_hud_dir=$(ls -td ~/.claude-sneakpeek/zai/config/plugins/cache/claude-hud/claude-hud/*/ ~/.claude/plugins/cache/claude-hud/claude-hud/*/ ~/.claude-code-old/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | head -1)

if [[ -n "$claude_hud_dir" ]] && [[ -f "${claude_hud_dir}dist/index.js" ]]; then
    # Run claude-hud and capture output
    hud_output=$(echo "$stdin_data" | node "${claude_hud_dir}dist/index.js" 2>/dev/null)

    # Filter out claude-hud's [model] progress line and git:(...) lines
    model_name=$(echo "$stdin_data" | jq -r '.model.display_name // "model"')
    hud_output=$(echo "$hud_output" | grep -vF "[${model_name}]" || echo "$hud_output")
    hud_output=$(echo "$hud_output" | grep -v "git:(" || echo "$hud_output")

    # Build combined segment
    combined_segment=""

    if [[ -n "$git_info" ]]; then
        combined_segment="${git_info}"
    fi

    # Add cumulative context display (claude-hud style)
    if [[ -n "$context_cumulative_display" ]]; then
        if [[ -n "$combined_segment" ]]; then
            combined_segment="${combined_segment} │ ${context_cumulative_display}"
        else
            combined_segment="${context_cumulative_display}"
        fi
    fi

    # Add current context display (/context style)
    if [[ -n "$context_current_display" ]]; then
        if [[ -n "$combined_segment" ]]; then
            combined_segment="${combined_segment} │ ${context_current_display}"
        else
            combined_segment="${context_current_display}"
        fi
    fi

    if [[ -n "$glm_plan_usage" ]]; then
        if [[ -n "$combined_segment" ]]; then
            combined_segment="${combined_segment} │ ${glm_plan_usage}"
        else
            combined_segment="${glm_plan_usage}"
        fi
    fi

    if [[ -n "$ralph_progress" ]]; then
        if [[ -n "$combined_segment" ]]; then
            combined_segment="${combined_segment} │ ${ralph_progress}"
        else
            combined_segment="${ralph_progress}"
        fi
    fi

    if [[ -n "$combined_segment" ]]; then
        printf '%b\n' "$combined_segment"

        # Output remaining claude-hud lines
        first_line=$(echo "$hud_output" | head -1)
        rest=$(echo "$hud_output" | tail -n +2)

        if [[ -n "$first_line" ]]; then
            echo "$first_line"
        fi
        if [[ -n "$rest" ]]; then
            echo "$rest"
        fi
    else
        echo "$hud_output"
    fi
else
    # Fallback: show git info, context, GLM usage, and progress
    if [[ -n "$git_info" ]] || [[ -n "$context_cumulative_display" ]] || [[ -n "$context_current_display" ]] || [[ -n "$glm_plan_usage" ]] || [[ -n "$ralph_progress" ]]; then
        fallback=""
        [[ -n "$git_info" ]] && fallback="$git_info"

        if [[ -n "$context_cumulative_display" ]]; then
            [[ -n "$fallback" ]] && fallback="${fallback} │ "
            fallback="${fallback}${context_cumulative_display}"
        fi

        if [[ -n "$context_current_display" ]]; then
            [[ -n "$fallback" ]] && fallback="${fallback} │ "
            fallback="${fallback}${context_current_display}"
        fi

        if [[ -n "$glm_plan_usage" ]]; then
            [[ -n "$fallback" ]] && fallback="${fallback} │ "
            fallback="${fallback}${glm_plan_usage}"
        fi

        if [[ -n "$ralph_progress" ]]; then
            [[ -n "$fallback" ]] && fallback="${fallback} │ "
            fallback="${fallback}${ralph_progress}"
        fi
        printf '%b\n' "$fallback"
    else
        echo "[statusline] Initializing..."
    fi
fi
