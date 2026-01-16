#!/bin/bash
# cleanup-project-configs.sh - Remove or update local project configs for global inheritance
#
# VERSION: 2.43.0
#
# Problem: Claude Code checks local .claude/ before global ~/.claude/
# If projects have old local configs, they don't receive global updates.
#
# Solution: This script identifies and cleans up local configs so they
# inherit from the updated global ~/.claude/ directory.
#
# Usage:
#   cleanup-project-configs.sh                 # Interactive mode
#   cleanup-project-configs.sh --scan          # Scan only (no changes)
#   cleanup-project-configs.sh --clean         # Remove local configs
#   cleanup-project-configs.sh --backup-clean  # Backup then remove
#   cleanup-project-configs.sh --sync-versions # Update VERSION markers only
#
# Part of Multi-Agent Ralph v2.43

set -euo pipefail

# Configuration
GITHUB_DIR="${HOME}/Documents/GitHub"
GLOBAL_CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${HOME}/.ralph/backups/project-configs"
CURRENT_VERSION="2.43.0"
LOG_FILE="${HOME}/.ralph/logs/cleanup-project-configs.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "$BACKUP_DIR" "${HOME}/.ralph/logs"

# Logging function
log() {
    local level="$1"
    shift
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [$level] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Print with color
print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_success() { echo -e "${GREEN}[OK]${NC}   $*"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
print_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check if a file has VERSION marker
get_version() {
    local file="$1"
    if [[ -f "$file" ]]; then
        grep -E "^# VERSION:|^version:" "$file" 2>/dev/null | \
            head -1 | sed -E 's/.*VERSION:\s*|version:\s*//' | tr -d ' "' || echo "unknown"
    else
        echo "missing"
    fi
}

# Check if local config is outdated compared to global
is_outdated() {
    local local_file="$1"
    local global_file="$2"

    if [[ ! -f "$local_file" ]]; then
        return 1  # Not outdated (doesn't exist)
    fi

    if [[ ! -f "$global_file" ]]; then
        return 1  # No global to compare
    fi

    local local_version=$(get_version "$local_file")
    local global_version=$(get_version "$global_file")

    if [[ "$local_version" == "unknown" ]] && [[ "$global_version" != "unknown" ]]; then
        return 0  # Local has no version, global does - outdated
    fi

    if [[ "$local_version" != "$global_version" ]]; then
        return 0  # Versions differ - outdated
    fi

    return 1  # Not outdated
}

# Scan a project for local Claude configs
scan_project() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local claude_dir="${project_dir}/.claude"

    if [[ ! -d "$claude_dir" ]]; then
        return 0  # No .claude directory
    fi

    local has_issues=false
    local outdated_files=()
    local removable_files=()

    # Check for settings.json (should NOT exist - use settings.local.json instead)
    if [[ -f "${claude_dir}/settings.json" ]]; then
        print_warn "  ${project_name}: has settings.json (should use global + settings.local.json)"
        removable_files+=("${claude_dir}/settings.json")
        has_issues=true
    fi

    # Check agents
    if [[ -d "${claude_dir}/agents" ]]; then
        for agent in "${claude_dir}/agents"/*.md; do
            [[ -f "$agent" ]] || continue
            local agent_name=$(basename "$agent")
            local global_agent="${GLOBAL_CLAUDE_DIR}/agents/${agent_name}"

            if is_outdated "$agent" "$global_agent"; then
                local local_v=$(get_version "$agent")
                local global_v=$(get_version "$global_agent")
                print_warn "  ${project_name}/agents/${agent_name}: outdated (local: ${local_v}, global: ${global_v})"
                outdated_files+=("$agent")
                has_issues=true
            fi
        done
    fi

    # Check commands
    if [[ -d "${claude_dir}/commands" ]]; then
        for cmd in "${claude_dir}/commands"/*.md; do
            [[ -f "$cmd" ]] || continue
            local cmd_name=$(basename "$cmd")
            local global_cmd="${GLOBAL_CLAUDE_DIR}/commands/${cmd_name}"

            if is_outdated "$cmd" "$global_cmd"; then
                local local_v=$(get_version "$cmd")
                local global_v=$(get_version "$global_cmd")
                print_warn "  ${project_name}/commands/${cmd_name}: outdated (local: ${local_v}, global: ${global_v})"
                outdated_files+=("$cmd")
                has_issues=true
            fi
        done
    fi

    # Check skills
    if [[ -d "${claude_dir}/skills" ]]; then
        for skill_dir in "${claude_dir}/skills"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name=$(basename "$skill_dir")
            local skill_file="${skill_dir}SKILL.md"
            local global_skill="${GLOBAL_CLAUDE_DIR}/skills/${skill_name}/SKILL.md"

            if [[ -f "$skill_file" ]] && is_outdated "$skill_file" "$global_skill"; then
                local local_v=$(get_version "$skill_file")
                local global_v=$(get_version "$global_skill")
                print_warn "  ${project_name}/skills/${skill_name}: outdated (local: ${local_v}, global: ${global_v})"
                outdated_files+=("$skill_file")
                has_issues=true
            fi
        done
    fi

    # Check hooks
    if [[ -d "${claude_dir}/hooks" ]]; then
        for hook in "${claude_dir}/hooks"/*; do
            [[ -f "$hook" ]] || continue
            local hook_name=$(basename "$hook")
            local global_hook="${GLOBAL_CLAUDE_DIR}/hooks/${hook_name}"

            if is_outdated "$hook" "$global_hook"; then
                local local_v=$(get_version "$hook")
                local global_v=$(get_version "$global_hook")
                print_warn "  ${project_name}/hooks/${hook_name}: outdated (local: ${local_v}, global: ${global_v})"
                outdated_files+=("$hook")
                has_issues=true
            fi
        done
    fi

    if [[ "$has_issues" == "true" ]]; then
        echo "${project_name}:${#outdated_files[@]}:${#removable_files[@]}"
        return 0
    fi

    return 0
}

# Backup a project's .claude directory
backup_project() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="${BACKUP_DIR}/${project_name}-${timestamp}"

    if [[ -d "${project_dir}/.claude" ]]; then
        mkdir -p "$backup_path"
        cp -r "${project_dir}/.claude" "$backup_path/"
        print_success "  Backed up ${project_name}/.claude to ${backup_path}"
        log "INFO" "Backed up ${project_dir}/.claude to ${backup_path}"
        return 0
    fi
    return 1
}

# Clean a project's local configs (remove duplicates of global)
clean_project() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local claude_dir="${project_dir}/.claude"
    local cleaned=0

    # Remove settings.json (keep settings.local.json)
    if [[ -f "${claude_dir}/settings.json" ]]; then
        rm "${claude_dir}/settings.json"
        print_success "  Removed ${project_name}/.claude/settings.json"
        ((cleaned++))
    fi

    # Remove agents that exist in global
    if [[ -d "${claude_dir}/agents" ]]; then
        for agent in "${claude_dir}/agents"/*.md; do
            [[ -f "$agent" ]] || continue
            local agent_name=$(basename "$agent")
            if [[ -f "${GLOBAL_CLAUDE_DIR}/agents/${agent_name}" ]]; then
                rm "$agent"
                print_success "  Removed ${project_name}/agents/${agent_name}"
                ((cleaned++))
            fi
        done
        # Remove directory if empty
        rmdir "${claude_dir}/agents" 2>/dev/null || true
    fi

    # Remove commands that exist in global
    if [[ -d "${claude_dir}/commands" ]]; then
        for cmd in "${claude_dir}/commands"/*.md; do
            [[ -f "$cmd" ]] || continue
            local cmd_name=$(basename "$cmd")
            if [[ -f "${GLOBAL_CLAUDE_DIR}/commands/${cmd_name}" ]]; then
                rm "$cmd"
                print_success "  Removed ${project_name}/commands/${cmd_name}"
                ((cleaned++))
            fi
        done
        rmdir "${claude_dir}/commands" 2>/dev/null || true
    fi

    # Remove skills that exist in global
    if [[ -d "${claude_dir}/skills" ]]; then
        for skill_dir in "${claude_dir}/skills"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name=$(basename "$skill_dir")
            if [[ -d "${GLOBAL_CLAUDE_DIR}/skills/${skill_name}" ]]; then
                rm -rf "$skill_dir"
                print_success "  Removed ${project_name}/skills/${skill_name}/"
                ((cleaned++))
            fi
        done
        rmdir "${claude_dir}/skills" 2>/dev/null || true
    fi

    # Remove hooks that exist in global
    if [[ -d "${claude_dir}/hooks" ]]; then
        for hook in "${claude_dir}/hooks"/*; do
            [[ -f "$hook" ]] || continue
            local hook_name=$(basename "$hook")
            if [[ -f "${GLOBAL_CLAUDE_DIR}/hooks/${hook_name}" ]]; then
                rm "$hook"
                print_success "  Removed ${project_name}/hooks/${hook_name}"
                ((cleaned++))
            fi
        done
        rmdir "${claude_dir}/hooks" 2>/dev/null || true
    fi

    log "INFO" "Cleaned ${cleaned} files from ${project_dir}/.claude"
    echo "$cleaned"
}

# Main scan function
do_scan() {
    print_info "Scanning projects in ${GITHUB_DIR}..."
    print_info "Global config: ${GLOBAL_CLAUDE_DIR}"
    print_info "Current version: ${CURRENT_VERSION}"
    echo ""

    local projects_with_issues=0
    local total_outdated=0
    local total_removable=0

    for project_dir in "${GITHUB_DIR}"/*/; do
        [[ -d "$project_dir" ]] || continue
        [[ -d "${project_dir}/.claude" ]] || continue

        local result=$(scan_project "$project_dir")
        if [[ -n "$result" ]]; then
            ((projects_with_issues++))
            local outdated=$(echo "$result" | cut -d: -f2)
            local removable=$(echo "$result" | cut -d: -f3)
            ((total_outdated += outdated))
            ((total_removable += removable))
        fi
    done

    echo ""
    echo "==============================================================="
    echo "  SCAN SUMMARY"
    echo "==============================================================="
    echo "  Projects with issues: ${projects_with_issues}"
    echo "  Outdated files: ${total_outdated}"
    echo "  Removable files: ${total_removable}"
    echo ""

    if [[ $projects_with_issues -gt 0 ]]; then
        print_warn "Run with --backup-clean to backup and remove outdated configs"
        print_info "After cleanup, projects will inherit from global ~/.claude/"
    else
        print_success "All projects are up to date with global configuration"
    fi
}

# Main clean function
do_clean() {
    local with_backup="$1"

    print_info "Cleaning local configs to enable global inheritance..."
    echo ""

    local total_cleaned=0

    for project_dir in "${GITHUB_DIR}"/*/; do
        [[ -d "$project_dir" ]] || continue
        [[ -d "${project_dir}/.claude" ]] || continue

        local project_name=$(basename "$project_dir")

        if [[ "$with_backup" == "true" ]]; then
            backup_project "$project_dir"
        fi

        local cleaned=$(clean_project "$project_dir")
        ((total_cleaned += cleaned))
    done

    echo ""
    echo "==============================================================="
    echo "  CLEANUP SUMMARY"
    echo "==============================================================="
    echo "  Total files cleaned: ${total_cleaned}"
    echo ""
    print_success "Projects now inherit from global ~/.claude/"
    print_info "Run 'ralph sync-global' to update global configs"
}

# Interactive mode
do_interactive() {
    echo "==============================================================="
    echo "  Project Config Cleanup Tool - v${CURRENT_VERSION}"
    echo "==============================================================="
    echo ""
    echo "This tool helps clean up outdated local .claude/ configurations"
    echo "so projects properly inherit from the global ~/.claude/ directory."
    echo ""
    echo "Options:"
    echo "  1) Scan projects for issues (no changes)"
    echo "  2) Backup and clean all projects"
    echo "  3) Clean without backup (dangerous)"
    echo "  4) Exit"
    echo ""
    read -p "Select option [1-4]: " choice

    case "$choice" in
        1)
            do_scan
            ;;
        2)
            do_clean true
            ;;
        3)
            print_warn "This will remove local configs without backup!"
            read -p "Are you sure? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                do_clean false
            else
                print_info "Cancelled"
            fi
            ;;
        4)
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
}

# Parse arguments
case "${1:-}" in
    --scan)
        do_scan
        ;;
    --clean)
        do_clean false
        ;;
    --backup-clean)
        do_clean true
        ;;
    --help|-h)
        echo "Usage: cleanup-project-configs.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --scan          Scan projects for outdated configs"
        echo "  --clean         Remove local configs (no backup)"
        echo "  --backup-clean  Backup then remove configs"
        echo "  --help          Show this help"
        echo ""
        echo "Without options, runs in interactive mode."
        ;;
    "")
        do_interactive
        ;;
    *)
        print_error "Unknown option: $1"
        echo "Use --help for usage"
        exit 1
        ;;
esac
