#!/bin/bash
# project-state.sh - Project-specific state management
# VERSION: 1.0.0
# Part of FIX-CRIT-007 - Project-specific context tracking
#
# Provides utilities to manage per-project state instead of global state.
# Each project is identified by its git root directory, ensuring proper
# isolation of context tracking between different repositories.
#
# Usage:
#   source project-state.sh
#   get_project_state_dir    # Returns the project-specific state directory
#   init_project_state       # Creates the state directory if needed
#
# Example:
#   STATE_DIR=$(get_project_state_dir)
#   mkdir -p "$STATE_DIR"
#   echo "0" > "${STATE_DIR}/operation-counter"

set -euo pipefail

# Get the git root directory of the current project
# Returns empty string if not in a git repository
get_git_root() {
    local cwd="${1:-.}"

    if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null; then
        git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Generate a safe, unique identifier for a project from its path
# Uses SHA256 hash of the git root path for safety and uniqueness
get_project_id() {
    local git_root="$1"

    if [[ -z "$git_root" ]]; then
        echo "non-git"
        return
    fi

    # Normalize the path (resolve symlinks, remove trailing slashes)
    local normalized_path
    normalized_path=$(realpath "$git_root" 2>/dev/null || echo "$git_root")

    # Generate SHA256 hash for unique, safe identifier
    echo -n "$normalized_path" | shasum -a 256 | awk '{print $1}'
}

# Get the project-specific state directory
# Returns ~/.ralph/projects/<project-id>/state/
get_project_state_dir() {
    local cwd="${1:-.}"

    # Get git root
    local git_root
    git_root=$(get_git_root "$cwd")

    # Generate project ID
    local project_id
    project_id=$(get_project_id "$git_root")

    # Build state directory path
    local ralph_dir="${RALPH_DIR:-${HOME}/.ralph}"
    echo "${ralph_dir}/projects/${project_id}/state"
}

# Initialize project state directory
# Creates the directory structure if it doesn't exist
init_project_state() {
    local cwd="${1:-.}"

    local state_dir
    state_dir=$(get_project_state_dir "$cwd")

    mkdir -p "$state_dir"

    # Also create a symlink for easy access by project path (optional)
    local git_root
    git_root=$(get_git_root "$cwd")

    if [[ -n "$git_root" ]]; then
        local project_id
        project_id=$(get_project_id "$git_root")

        local ralph_dir="${RALPH_DIR:-${HOME}/.ralph}"
        local projects_dir="${ralph_dir}/projects"

        # Create a human-readable symlink: ~/.ralph/projects/by-path/<sanitized-path>
        local sanitized_path
        sanitized_path=$(echo "$git_root" | sed 's|/|-|g' | sed 's|^\.||')

        local symlink_path="${projects_dir}/by-path/${sanitized_path}"
        local symlink_target="../${project_id}"

        mkdir -p "${projects_dir}/by-path"
        ln -sf "$symlink_target" "$symlink_path" 2>/dev/null || true
    fi

    echo "$state_dir"
}

# Get project metadata (optional, for debugging)
get_project_metadata() {
    local cwd="${1:-.}"

    local git_root
    git_root=$(get_git_root "$cwd")

    local project_id
    project_id=$(get_project_id "$git_root")

    local state_dir
    state_dir=$(get_project_state_dir "$cwd")

    # Try to get project name from git remote
    local project_name=""
    if [[ -n "$git_root" ]]; then
        local remote_url
        remote_url=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            project_name=$(basename "$remote_url" .git 2>/dev/null | sed 's|.*/||')
        else
            project_name=$(basename "$git_root")
        fi
    else
        project_name="non-git-project"
    fi

    cat <<EOF
{
  "project_id": "$project_id",
  "project_name": "$project_name",
  "git_root": "$git_root",
  "state_dir": "$state_dir"
}
EOF
}

# Migration helper: migrate global state to project-specific state
# This reads from the old global location and copies to the new location
migrate_global_state() {
    local cwd="${1:-.}"

    local old_state_dir="${RALPH_DIR:-${HOME}/.ralph}/state"
    local new_state_dir
    new_state_dir=$(get_project_state_dir "$cwd")

    # Check if old state exists
    if [[ ! -d "$old_state_dir" ]]; then
        echo "No global state to migrate"
        return 0
    fi

    # Create new state directory
    mkdir -p "$new_state_dir"

    # Copy relevant state files
    local files_to_migrate=(
        "operation-counter"
        "message_count"
        "glm-context.json"
    )

    local migrated_count=0
    for file in "${files_to_migrate[@]}"; do
        local old_file="${old_state_dir}/${file}"
        local new_file="${new_state_dir}/${file}"

        if [[ -f "$old_file" ]]; then
            # Copy if new file doesn't exist
            if [[ ! -f "$new_file" ]]; then
                cp "$old_file" "$new_file"
                ((migrated_count++))
                echo "Migrated: $file"
            fi
        fi
    done

    echo "Migration complete: $migrated_count files copied to $new_state_dir"
}

# Export functions for use in other scripts
export -f get_git_root
export -f get_project_id
export -f get_project_state_dir
export -f init_project_state
export -f get_project_metadata
export -f migrate_global_state

# If executed directly (not sourced), run the requested command
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        get-dir)
            get_project_state_dir
            ;;
        init)
            init_project_state
            ;;
        metadata)
            get_project_metadata
            ;;
        migrate)
            migrate_global_state
            ;;
        *)
            echo "Usage: $0 {get-dir|init|metadata|migrate}"
            echo "  get-dir   - Print project-specific state directory"
            echo "  init      - Initialize project state directory"
            echo "  metadata  - Show project metadata JSON"
            echo "  migrate   - Migrate global state to project-specific"
            exit 1
            ;;
    esac
fi
