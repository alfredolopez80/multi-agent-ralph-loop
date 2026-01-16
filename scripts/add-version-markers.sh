#!/bin/bash
# add-version-markers.sh - Add VERSION markers to all Claude config files
#
# VERSION: 2.43.0
#
# Adds "# VERSION: X.Y.Z" markers to agents, skills, hooks, and commands
# for better tracking and validation of updates.
#
# Usage:
#   add-version-markers.sh                 # Add to project .claude/
#   add-version-markers.sh --global        # Add to global ~/.claude/
#   add-version-markers.sh --all           # Add to both
#   add-version-markers.sh --check         # Check current versions
#
# Part of Multi-Agent Ralph v2.43

set -euo pipefail

# Configuration
VERSION="2.43.0"
PROJECT_DIR="/Users/alfredolopez/Documents/GitHub/multi-agent-ralph-loop"
GLOBAL_DIR="${HOME}/.claude"
LOG_FILE="${HOME}/.ralph/logs/version-markers.log"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure log directory exists
mkdir -p "${HOME}/.ralph/logs"

# Logging
log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true
}

print_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
print_success() { echo -e "${GREEN}[OK]${NC}   $*"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# Add VERSION marker to a markdown file
add_version_md() {
    local file="$1"
    local version="$2"

    if [[ ! -f "$file" ]]; then
        return
    fi

    # Check if already has VERSION
    if grep -q "^# VERSION:" "$file" 2>/dev/null; then
        # Update existing version
        sed -i '' "s/^# VERSION:.*/# VERSION: ${version}/" "$file"
        print_info "Updated: $(basename "$file")"
    else
        # Check if file has YAML frontmatter
        if head -1 "$file" | grep -q "^---"; then
            # Insert VERSION after first ---
            sed -i '' "2i\\
# VERSION: ${version}
" "$file"
        else
            # Add VERSION at top
            local tmp=$(mktemp)
            echo "# VERSION: ${version}" > "$tmp"
            echo "" >> "$tmp"
            cat "$file" >> "$tmp"
            mv "$tmp" "$file"
        fi
        print_success "Added: $(basename "$file")"
    fi

    log "Added version ${version} to ${file}"
}

# Add VERSION marker to a shell script
add_version_sh() {
    local file="$1"
    local version="$2"

    if [[ ! -f "$file" ]]; then
        return
    fi

    # Check if already has VERSION
    if grep -q "^# VERSION:" "$file" 2>/dev/null; then
        # Update existing version
        sed -i '' "s/^# VERSION:.*/# VERSION: ${version}/" "$file"
        print_info "Updated: $(basename "$file")"
    else
        # Find the end of the header comment block
        local line_num=1
        while IFS= read -r line; do
            if [[ ! "$line" =~ ^# ]] && [[ -n "$line" ]]; then
                break
            fi
            ((line_num++))
        done < "$file"

        # Insert VERSION before the blank line after comments
        sed -i '' "${line_num}i\\
# VERSION: ${version}
" "$file"
        print_success "Added: $(basename "$file")"
    fi

    log "Added version ${version} to ${file}"
}

# Process a directory
process_directory() {
    local base_dir="$1"
    local claude_dir="${base_dir}/.claude"

    if [[ ! -d "$claude_dir" ]]; then
        print_warn "No .claude directory found in $base_dir"
        return
    fi

    echo ""
    print_info "Processing: $base_dir"
    echo ""

    local count=0

    # Process agents
    if [[ -d "${claude_dir}/agents" ]]; then
        print_info "Agents:"
        for file in "${claude_dir}/agents"/*.md; do
            [[ -f "$file" ]] || continue
            add_version_md "$file" "$VERSION"
            ((count++))
        done
    fi

    # Process commands
    if [[ -d "${claude_dir}/commands" ]]; then
        print_info "Commands:"
        for file in "${claude_dir}/commands"/*.md; do
            [[ -f "$file" ]] || continue
            add_version_md "$file" "$VERSION"
            ((count++))
        done
    fi

    # Process skills (directories with SKILL.md)
    if [[ -d "${claude_dir}/skills" ]]; then
        print_info "Skills:"
        for skill_dir in "${claude_dir}/skills"/*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_file="${skill_dir}SKILL.md"
            if [[ -f "$skill_file" ]]; then
                add_version_md "$skill_file" "$VERSION"
                ((count++))
            fi
        done
        # Also check for direct .md files in skills
        for file in "${claude_dir}/skills"/*.md; do
            [[ -f "$file" ]] || continue
            add_version_md "$file" "$VERSION"
            ((count++))
        done
    fi

    # Process hooks
    if [[ -d "${claude_dir}/hooks" ]]; then
        print_info "Hooks:"
        for file in "${claude_dir}/hooks"/*.sh; do
            [[ -f "$file" ]] || continue
            add_version_sh "$file" "$VERSION"
            ((count++))
        done
        for file in "${claude_dir}/hooks"/*.py; do
            [[ -f "$file" ]] || continue
            add_version_sh "$file" "$VERSION"
            ((count++))
        done
    fi

    echo ""
    print_success "Processed ${count} files"
}

# Check versions in a directory
check_versions() {
    local base_dir="$1"
    local claude_dir="${base_dir}/.claude"

    if [[ ! -d "$claude_dir" ]]; then
        return
    fi

    echo ""
    print_info "Checking versions in: $base_dir"
    echo ""

    local current=0
    local outdated=0
    local missing=0

    # Function to check a file
    check_file() {
        local file="$1"
        local name=$(basename "$file")
        local file_version=$(grep -E "^# VERSION:" "$file" 2>/dev/null | head -1 | sed 's/# VERSION: //' || echo "")

        if [[ -z "$file_version" ]]; then
            print_warn "Missing: $name"
            ((missing++))
        elif [[ "$file_version" == "$VERSION" ]]; then
            print_success "Current: $name (v${file_version})"
            ((current++))
        else
            print_warn "Outdated: $name (v${file_version} -> v${VERSION})"
            ((outdated++))
        fi
    }

    # Check all file types
    for file in "${claude_dir}/agents"/*.md "${claude_dir}/commands"/*.md; do
        [[ -f "$file" ]] && check_file "$file"
    done

    for skill_dir in "${claude_dir}/skills"/*/; do
        [[ -d "$skill_dir" ]] && [[ -f "${skill_dir}SKILL.md" ]] && check_file "${skill_dir}SKILL.md"
    done

    for file in "${claude_dir}/hooks"/*.sh "${claude_dir}/hooks"/*.py; do
        [[ -f "$file" ]] && check_file "$file"
    done

    echo ""
    echo "Summary: ${current} current, ${outdated} outdated, ${missing} missing"
}

# Main
case "${1:-}" in
    --global)
        process_directory "$HOME"
        ;;
    --project)
        process_directory "$PROJECT_DIR"
        ;;
    --all)
        process_directory "$PROJECT_DIR"
        process_directory "$HOME"
        ;;
    --check)
        check_versions "$PROJECT_DIR"
        check_versions "$HOME"
        ;;
    --help|-h)
        echo "Usage: add-version-markers.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --project  Add to project .claude/ only"
        echo "  --global   Add to global ~/.claude/ only"
        echo "  --all      Add to both project and global"
        echo "  --check    Check current version markers"
        echo "  --help     Show this help"
        echo ""
        echo "Current version: $VERSION"
        ;;
    "")
        process_directory "$PROJECT_DIR"
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage"
        exit 1
        ;;
esac
