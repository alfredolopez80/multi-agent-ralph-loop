#!/bin/bash
# statusline-ralph.sh - Enhanced StatusLine with Git + Ralph Progress
#
# VERSION: 2.73.0
# v2.73.0: NEW - Real context tracking using native Claude API (claude --print "/context")
#          - Shows ✓ indicator when context is from native API (100% accurate)
#          - Falls back to estimated context when native unavailable
# v2.72.0: FIX-CRIT-007 - Project-specific context tracking using git root
# v2.71.3: FIX-CRIT-006 - Always show GLM mode icon with percentage, even at 0%
# v2.71.2: FIX-CRIT-006 - Use unified tracker for proper GLM context display in statusline
# v2.71.1: FIX-CRIT-006 - Add session context display to statusline for real-time visibility
#
# Extends statusline-git.sh with orchestration progress tracking.
# Reads plan-state.json to show current phase and step completion.
#
# Format: ⎇ branch* │ 🤖 0% │ ⚡ 8/11 72% │ [claude-hud output with icons]
#
# Usage: Called by settings.json statusLine.command
#
# Part of Multi-Agent Ralph v2.71
#
# v2.71.0 changes:
# - Session context tracking (works for both Claude and GLM)
# - Color-coded context percentage (cyan<50%, green<75%, yellow>=75%, red>=85%)
# - Always show GLM mode indicator when active
# - Prioritizes session context over GLM specific display
# - Better integration with auto-compaction system
#
# v2.70.0 changes:
# - GLM-4.7 context tracking support
# - Environment detection (Claude CLI vs GLM-API)
# - Shows GLM context percentage when in API mode
# - Fallback mode with GLM context display
#
# v2.69.0 changes:
# - Show phase_name instead of phase_id to avoid branch name duplication
# - Add git info duplication detection (avoid claude-hud git:(...) overlap)
# - Format stats line with icons: 📄 3 files | 📋 7 rules | 🔌 13 MCPs | ⚙️ 6 hooks
# - macOS-compatible: use sed '$d' instead of head -n -1

# BUG-002 FIX: Define log function (was calling macOS system log command)
# StatusLine should be silent - log to file only if DEBUG is set
log() {
    if [[ -n "${STATUSLINE_DEBUG:-}" ]]; then
        echo "[statusline] $*" >> "${HOME}/.ralph/logs/statusline.log" 2>/dev/null || true
    fi
}

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
DIM='\033[2m'
RESET='\033[0m'

# Plan state file location
PLAN_STATE=".claude/plan-state.json"

# Get git branch/worktree info (from statusline-git.sh)
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

# Detect environment type (GLM-API vs Claude CLI)
get_environment_type() {
    # Check if detect-environment.sh exists
    local detect_script="${HOME}/.claude/hooks/detect-environment.sh"
    if [[ -f "$detect_script" ]]; then
        local env_json=$("$detect_script" 2>/dev/null || echo '{}')
        echo "$env_json" | jq -r '.type // "unknown"' 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

# Get native Claude context percentage (REAL, not estimated)
# Uses claude --print "/context" API when available
get_native_context_percentage() {
    # Try to get real context from Claude CLI
    if command -v claude &>/dev/null; then
        local native_pct
        native_pct=$(claude --print "/context" 2>/dev/null || echo "")

        # Claude returns just the percentage (e.g., "14%")
        if [[ -n "$native_pct" ]] && [[ "$native_pct" =~ ^[0-9]+%$ ]]; then
            # Extract just the number
            local pct_num="${native_pct%\%}"
            echo "${pct_num}"
            return 0
        fi
    fi
    return 1
}

# Get session context percentage (works for both Claude and GLM)
# v2.73.0: NEW - Shows REAL context when available, with estimated for comparison
# FIX-CRIT-007: Use project-specific state instead of global state
# Context should be per-project, not shared across all projects
get_session_context_percentage() {
    local native_pct=""
    local estimated_pct=""
    local tokens_used="0"
    local context_window="128000"

    # Try to get REAL context from Claude CLI API (most accurate)
    native_pct=$(get_native_context_percentage 2>/dev/null || echo "")

    # For GLM-API mode, also get estimated context from tracker
    local env_type=$(get_environment_type)
    if [[ "$env_type" == "glm-api" ]]; then
        local tracker="${HOME}/.claude/hooks/unified-context-tracker.sh"

        # unified-context-tracker now uses project-specific state
        if [[ -f "$tracker" ]]; then
            local model
            model=$("$tracker" get-model 2>/dev/null || echo "")

            if [[ "$model" == "glm" ]]; then
                estimated_pct=$("$tracker" get-percentage 2>/dev/null || echo "0")

                # Get exact token count from glm-context.json
                local project_state="${HOME}/.claude/hooks/project-state.sh"
                local state_dir=$("$project_state" get-dir 2>/dev/null)
                local context_file="${state_dir}/glm-context.json"

                if [[ -f "$context_file" ]]; then
                    tokens_used=$(jq -r '.total_tokens // 0' "$context_file" 2>/dev/null || echo "0")
                    context_window=$(jq -r '.context_window // 128000' "$context_file" 2>/dev/null || echo "128000")
                fi
            fi
        fi
    fi

    # Decide which percentage to use (prefer native/real)
    local display_pct=""
    local display_type=""

    if [[ -n "$native_pct" ]]; then
        # Native context is available - use it
        display_pct="$native_pct"
        display_type="real"
    elif [[ -n "$estimated_pct" ]] && [[ "$estimated_pct" != "0" ]]; then
        # Only estimated available
        display_pct="$estimated_pct"
        display_type="est"
    else
        # No context available
        return 0
    fi

    # Format tokens in K notation
    local tokens_display="${tokens_used}"
    local window_display="${context_window}"

    if [[ $tokens_used -ge 1000 ]]; then
        tokens_display="$((tokens_used / 1000))K"
    fi
    if [[ $context_window -ge 1000 ]]; then
        window_display="$((context_window / 1000))K"
    fi

    # Determine color based on percentage
    local color="${CYAN}"
    if [[ "$display_pct" -ge 85 ]]; then
        color="${RED}"
    elif [[ "$display_pct" -ge 75 ]]; then
        color="${YELLOW}"
    elif [[ "$display_pct" -ge 50 ]]; then
        color="${GREEN}"
    fi

    # Format: 🤖 14% (real) · 18K/128K
    # OR: 🤖 14% (est) · 18K/128K when only estimated available
    local type_label=""
    if [[ "$display_type" == "real" ]]; then
        type_label="✓"  # Checkmark for verified real value
    fi

    echo "${color}🤖 ${display_pct}%${type_label} · ${tokens_display}/${window_display}${RESET}"
    return 0
}

# Get GLM-4.7 context percentage (works for both Claude and GLM)
# v2.72.1: SHOW-TOKENS - Display both percentage AND exact token count for validation
# v2.72.0: FIX-CRIT-007 - Now uses project-specific state
# v2.71.3: FIX-CRIT-006 - Always show GLM mode icon, even at 0%
get_glm_context_percentage() {
    local tracker="${HOME}/.claude/hooks/unified-context-tracker.sh"

    if [[ -f "$tracker" ]]; then
        # Check if we're in GLM mode first
        local model
        model=$("$tracker" get-model 2>/dev/null || echo "")

        if [[ "$model" == "glm" ]]; then
            # We're in GLM mode - get percentage, tokens, and window
            # unified-context-tracker now uses project-specific state
            local pct
            pct=$("$tracker" get-percentage 2>/dev/null || echo "0")

            # Get exact token count from glm-context.json
            local project_state="${HOME}/.claude/hooks/project-state.sh"
            local state_dir=$("$project_state" get-dir 2>/dev/null)
            local context_file="${state_dir}/glm-context.json"

            local tokens_used="0"
            local context_window="128000"

            if [[ -f "$context_file" ]]; then
                tokens_used=$(jq -r '.total_tokens // 0' "$context_file" 2>/dev/null || echo "0")
                context_window=$(jq -r '.context_window // 128000' "$context_file" 2>/dev/null || echo "128000")
            fi

            # Format tokens in K notation for readability
            local tokens_display="${tokens_used}"
            local window_display="${context_window}"

            if [[ $tokens_used -ge 1000 ]]; then
                tokens_display="$((tokens_used / 1000))K"
            fi
            if [[ $context_window -ge 1000 ]]; then
                window_display="$((context_window / 1000))K"
            fi

            # Determine color based on percentage
            local color="${CYAN}"
            if [[ "$pct" -ge 85 ]]; then
                color="${RED}"
            elif [[ "$pct" -ge 75 ]]; then
                color="${YELLOW}"
            elif [[ "$pct" -ge 50 ]]; then
                color="${GREEN}"
            fi

            # ALWAYS show GLM icon with percentage AND token count
            # Format: 🤖 75% · 96K/128K
            echo "${color}🤖 ${pct}% · ${tokens_display}/${window_display}${RESET}"
            return 0
        fi
    fi

    return 0
}

# Get GLM Coding Plan usage (5-hour + monthly MCP)
# Shows Z.AI plan quota status
get_glm_plan_usage() {
    local cache_manager="${HOME}/.ralph/scripts/glm-usage-cache-manager.sh"

    if [[ -f "$cache_manager" ]]; then
        "$cache_manager" get-statusline
    fi
}

# Get Ralph orchestration progress
# VERSION: 2.68.14 - GAP-003 FIX: Use current-project.json to find active project's plan-state
get_ralph_progress() {
    local cwd="${1:-.}"
    local plan_state_file=""

    # Step 1: Check local plan-state (highest priority)
    if [[ -f "${cwd}/.claude/plan-state.json" ]]; then
        plan_state_file="${cwd}/.claude/plan-state.json"
        log "Found local plan-state at: $plan_state_file"
    fi

    # Step 2: If not found, check current-project.json for active project path
    # GAP-003 FIX: current-project.json contains project metadata, NOT plan-state
    # We need to extract the project path and look for plan-state there
    if [[ -z "$plan_state_file" ]] && [[ -f "${HOME}/.ralph/metadata/current-project.json" ]]; then
        local active_project_path
        active_project_path=$(jq -r '.project.path // ""' "${HOME}/.ralph/metadata/current-project.json" 2>/dev/null || echo "")

        # SEC-002 FIX: Validate path to prevent path traversal attacks
        if [[ -n "$active_project_path" ]]; then
            # Reject paths with .. (traversal) or non-absolute paths
            if [[ "$active_project_path" =~ \.\. ]] || [[ "$active_project_path" != /* ]]; then
                log "SEC-002: Rejected invalid project path: $active_project_path"
                active_project_path=""
            else
                # Resolve symlinks to prevent symlink attacks
                active_project_path=$(realpath "$active_project_path" 2>/dev/null || echo "")
            fi
        fi

        if [[ -n "$active_project_path" ]] && [[ -f "${active_project_path}/.claude/plan-state.json" ]]; then
            plan_state_file="${active_project_path}/.claude/plan-state.json"
            log "Found plan-state via current-project.json at: $plan_state_file"
        fi
    fi

    # Step 3: Check active-plan with PROJECT_ID or derived from git
    if [[ -z "$plan_state_file" ]]; then
        # First try PROJECT_ID if set
        if [[ -n "${PROJECT_ID:-}" ]] && [[ -f "${HOME}/.ralph/active-plan/${PROJECT_ID}.json" ]]; then
            plan_state_file="${HOME}/.ralph/active-plan/${PROJECT_ID}.json"
            log "Found active-plan for PROJECT_ID: $PROJECT_ID"
        else
            # Try to derive project ID from git
            if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
                local repo_remote
                repo_remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")
                if [[ -n "$repo_remote" ]]; then
                    local project_id
                    project_id=$(basename "$repo_remote" .git 2>/dev/null | sed 's|.*/||')
                    if [[ -f "${HOME}/.ralph/active-plan/${project_id}.json" ]]; then
                        plan_state_file="${HOME}/.ralph/active-plan/${project_id}.json"
                        log "Found global plan-state for: $project_id"
                    fi
                fi
            fi
        fi
    fi

    # If still not found, return empty
    if [[ -z "$plan_state_file" ]] || [[ ! -f "$plan_state_file" ]]; then
        return
    fi

    # Read plan state
    local plan_state
    plan_state=$(cat "$plan_state_file" 2>/dev/null)

    if [[ -z "$plan_state" ]]; then
        return
    fi

    # Check version (must be 2.46+)
    local version
    version=$(echo "$plan_state" | jq -r '.version // "1.0"' 2>/dev/null)

    if [[ -z "$version" ]]; then
        return
    fi

    # Count total steps (handles both array and object formats)
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

    # Skip if no meaningful progress
    if [[ "$total_steps" == "0" || -z "$total_steps" ]]; then
        return
    fi

    # Count completed steps (status == "completed" or "verified")
    # Handles both array format (.steps[].status) and object format (.steps | to_entries[])
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

    # Count in_progress steps to determine status
    # Handles both array and object formats
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

    # Check workflow type and adaptive mode (v2.57.0)
    # Schema v2.54 uses workflow_route, older versions use route or workflow_type
    local workflow_type adaptive_mode
    workflow_type=$(echo "$plan_state" | jq -r '.classification.workflow_route // .classification.route // .workflow_type // "STANDARD"' 2>/dev/null)
    adaptive_mode=$(echo "$plan_state" | jq -r '.classification.adaptive_mode // ""' 2>/dev/null)

    # Override workflow_type with adaptive_mode if present
    if [[ -n "$adaptive_mode" ]] && [[ "$adaptive_mode" != "null" ]]; then
        workflow_type="$adaptive_mode"
    fi

    # Calculate percentage based on completed steps
    local percentage=0
    if [[ "$total_steps" -gt 0 ]]; then
        percentage=$((completed_steps * 100 / total_steps))
    fi

    # Determine status based on step counts
    local status
    if [[ "$completed_steps" -eq "$total_steps" ]]; then
        status="completed"
    elif [[ "$in_progress_steps" -gt 0 ]]; then
        status="in_progress"
    else
        status="pending"
    fi

    # Determine icon based on status
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

    # Special icon based on workflow/adaptive mode (v2.57.0)
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

    # Extract additional plan state fields (v2.54.0)
    local current_phase phase_name active_agent barriers status_details
    current_phase=$(echo "$plan_state" | jq -r '.current_phase // .loop_state.current_phase // empty' 2>/dev/null)

    # Get phase_name instead of phase_id for better display (v2.69.0 fix)
    if [[ -n "$current_phase" ]] && [[ "$current_phase" != "null" ]]; then
        phase_name=$(echo "$plan_state" | jq -r --arg phase "$current_phase" '.phases[] | select(.phase_id == $phase) | .phase_name // empty' 2>/dev/null)
        # Fallback to phase_id if phase_name not found
        if [[ -z "$phase_name" ]] || [[ "$phase_name" == "null" ]]; then
            phase_name="$current_phase"
        fi
    fi

    active_agent=$(echo "$plan_state" | jq -r '.active_agent // .loop_state.active_agent // empty' 2>/dev/null)

    # Build status details with phase, agent, and barriers
    status_details=""
    if [[ -n "$phase_name" ]] && [[ "$phase_name" != "null" ]]; then
        status_details="${status_details} ${DIM}${phase_name}${RESET}"
    fi
    if [[ -n "$active_agent" ]] && [[ "$active_agent" != "null" ]]; then
        status_details="${status_details} ${MAGENTA}${active_agent}${RESET}"
    fi

    # Check for any unsatisfied barriers (v2.54.0 WAIT-ALL pattern)
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

    # Build progress string
    local progress_output
    if [[ "$percentage" -ge 100 ]]; then
        progress_output="${BLUE}${icon}${RESET} ${GREEN}done${RESET}${status_details}"
    else
        progress_output="${BLUE}${icon}${RESET} ${DIM}${completed_steps}/${total_steps}${RESET} ${CYAN}${percentage}%${RESET}${status_details}"
    fi

    echo -e "$progress_output"
}

# Read stdin to pass to claude-hud
stdin_data=$(cat)

# Extract cwd from stdin JSON
cwd=$(echo "$stdin_data" | jq -r '.cwd // "."' 2>/dev/null || echo ".")

# Get git info
git_info=$(get_git_info "$cwd")

# Get ralph progress
ralph_progress=$(get_ralph_progress "$cwd")

# Get session context percentage (works for both Claude and GLM)
session_context=$(get_session_context_percentage)

# Get GLM specific context (legacy, for display when available)
glm_context=$(get_glm_context_percentage)

# Get GLM Coding Plan usage (NEW - 5-hour + monthly MCP)
glm_plan_usage=$(get_glm_plan_usage)

# Detect environment type
ENV_TYPE=$(get_environment_type)

# Find and run claude-hud
claude_hud_dir=$(ls -td ~/.claude/plugins/cache/claude-hud/claude-hud/*/ 2>/dev/null | head -1)

if [[ -n "$claude_hud_dir" ]] && [[ -f "${claude_hud_dir}dist/index.js" ]]; then
    # Run claude-hud and capture output
    hud_output=$(echo "$stdin_data" | node "${claude_hud_dir}dist/index.js" 2>/dev/null)

    # v2.69.0 FIX: Detect if claude-hud already includes git info to avoid duplication
    # claude-hud shows "git:(branch*)" in its output, so we skip our git_info
    hud_has_git=$(echo "$hud_output" | grep -c "git:(" || echo "0")

    # Build combined segment
    combined_segment=""

    # Only add git_info if claude-hud doesn't already have it
    if [[ "$hud_has_git" == "0" ]] && [[ -n "$git_info" ]]; then
        combined_segment="${git_info}"
    fi

    # Add session context FIRST (most important)
    if [[ -n "$session_context" ]]; then
        if [[ -n "$combined_segment" ]]; then
            combined_segment="${combined_segment} │ ${session_context}"
        else
            combined_segment="${session_context}"
        fi
    fi

    # Add GLM specific context if available
    if [[ -n "$glm_context" ]] && [[ "$session_context" != "$glm_context" ]]; then
        if [[ -n "$combined_segment" ]]; then
            combined_segment="${combined_segment} │ ${glm_context}"
        else
            combined_segment="${glm_context}"
        fi
    fi

    # Add GLM Coding Plan usage (5-hour + monthly MCP)
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
        # Prepend to first line of hud output
        first_line=$(echo "$hud_output" | head -1)
        rest=$(echo "$hud_output" | tail -n +2)

        # v2.69.0: Combine git branch line with stats line
        # Goal: "multi-agent-ralph-loop git:(main*) | 3 CLAUDE.md | 7 rules | 13 MCPs | 6 hooks"
        if [[ -n "$rest" ]]; then
            # Split rest into lines
            line_count=$(echo "$rest" | wc -l | awk '{print $1}')

            if [[ "$line_count" -ge 2 ]]; then
                # Get first line (git branch) and second line (stats)
                git_branch_line=$(echo "$rest" | head -1)
                stats_line=$(echo "$rest" | head -2 | tail -1)
                remaining_rest=$(echo "$rest" | tail -n +3)

                # Check if stats_line contains "CLAUDE.md" pattern
                if echo "$stats_line" | grep -q "CLAUDE.md"; then
                    # Remove ANSI color codes for clean combination
                    clean_git=$(echo "$git_branch_line" | sed 's/\x1b\[[0-9;]*m//g')
                    clean_stats=$(echo "$stats_line" | sed 's/\x1b\[[0-9;]*m//g')

                    # Combine with separator
                    combined_line="${clean_git} | ${clean_stats}"

                    # Reconstruct rest with combined line
                    if [[ -n "$remaining_rest" ]]; then
                        rest="${combined_line}"$'\n'"${remaining_rest}"
                    else
                        rest="${combined_line}"
                    fi
                fi
            fi
        fi

        # Use non-breaking spaces for proper display
        segment="${combined_segment} │ "
        segment="${segment// /$'\u00A0'}"  # Replace spaces with non-breaking spaces (U+00A0)

        echo -e "${segment}${first_line}"
        if [[ -n "$rest" ]]; then
            echo "$rest"
        fi
    else
        echo "$hud_output"
    fi
else
    # Fallback: just show git info, session context, and progress
    if [[ -n "$git_info" ]] || [[ -n "$session_context" ]] || [[ -n "$ralph_progress" ]]; then
        local fallback=""
        [[ -n "$git_info" ]] && fallback="$git_info"

        # Add session context FIRST (most important)
        if [[ -n "$session_context" ]]; then
            [[ -n "$fallback" ]] && fallback="${fallback} │ "
            fallback="${fallback}${session_context}"
        fi

        if [[ -n "$ralph_progress" ]]; then
            [[ -n "$fallback" ]] && fallback="${fallback} │ "
            fallback="${fallback}${ralph_progress}"
        fi
        echo -e "$fallback"
    else
        # Show environment type in initialization
        if [[ "$ENV_TYPE" == "glm-api" ]]; then
            echo -e "${CYAN}[statusline] GLM-API mode${RESET}"
        else
            echo "[statusline] Initializing..."
        fi
    fi
fi
