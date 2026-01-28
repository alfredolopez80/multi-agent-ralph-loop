#!/usr/bin/env bash
#
# fix-claude-mem-hooks.sh
#
# Auto-detect and fix CLAUDE_PLUGIN_ROOT path resolution issue in claude-mem hooks
#
# Issue: Bun cannot resolve ${CLAUDE_PLUGIN_ROOT} when used as part of a path argument
# Solution: Wrap in subshell with cd to plugin root first
#
# Version: 1.0.0
# Updated: 2026-01-28
#
# Usage:
#   ./fix-claude-mem-hooks.sh                    # Auto-detect and fix
#   ./fix-claude-mem-hooks.sh --check           # Check only, don't fix
#   ./fix-claude-mem-hooks.sh --dry-run         # Show what would be changed
#   ./fix-claude-mem-hooks.sh --version         # Show version info

set -euo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

# Show usage
show_usage() {
    cat <<EOF
fix-claude-mem-hooks.sh v${VERSION}

Auto-detect and fix CLAUDE_PLUGIN_ROOT path resolution issue in claude-mem hooks.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --check       Check only, don't apply fixes
    --dry-run     Show what would be changed without applying
    --help        Show this help message
    --version     Show version info

WHAT IT FIXES:
    Incorrect:  bun "\${CLAUDE_PLUGIN_ROOT}/scripts/worker-service.cjs" start
    Correct:    (cd "\${CLAUDE_PLUGIN_ROOT}" && bun scripts/worker-service.cjs start)

AFFECTED FILES:
    ~/.claude-sneakpeek/zai/config/plugins/cache/thedotmack/claude-mem/*/hooks/hooks.json
    ~/.claude-sneakpeek/zai/config/plugins/marketplaces/thedotmack/plugin/hooks/hooks.json

AUTO-DETECTION:
    This script is automatically detected and can be run by:
    - Claude Code: /fix-claude-mem-hooks
    - Ralph CLI: ralph fix claude-mem-hooks
    - Manual: .claude/scripts/fix-claude-mem-hooks.sh

EOF
}

# Check if hooks.json has the issue
check_hooks_file() {
    local hooks_file="$1"
    local incorrect_count=0
    local correct_count=0

    if [[ ! -f "$hooks_file" ]]; then
        return 1
    fi

    # Count incorrect patterns (handle grep exit 1 when no matches)
    # Look for: bun "${CLAUDE_PLUGIN_ROOT}/scripts/worker-service.cjs" (absolute path with bun)
    incorrect_count=$(grep -c 'bun "\\${CLAUDE_PLUGIN_ROOT}/scripts/worker-service' "$hooks_file" 2>/dev/null || true)
    if [[ -z "$incorrect_count" ]]; then
        incorrect_count=0
    fi

    # Count correct patterns using simpler regex
    # Look for: (cd "${CLAUDE_PLUGIN_ROOT}" && bun scripts/worker-service.cjs)
    correct_count=$(grep -c 'cd.*CLAUDE_PLUGIN_ROOT.*bun.*worker-service' "$hooks_file" 2>/dev/null || true)
    if [[ -z "$correct_count" ]]; then
        correct_count=0
    fi

    echo "${incorrect_count}|${correct_count}"
    return 0
}

# Find claude-mem plugin directory
find_claude_mem_plugin() {
    local plugin_path=""

    # Try standard locations
    if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
        plugin_path="$(dirname "$(dirname "$CLAUDE_PLUGIN_ROOT")")"
    else
        # Search in zai config
        plugin_path="$(find ~/.claude-sneakpeek/zai/config/plugins/cache -type d -name "claude-mem" 2>/dev/null | head -1)"
    fi

    if [[ -z "$plugin_path" ]]; then
        log_error "Could not find claude-mem plugin directory"
        return 1
    fi

    echo "$plugin_path"
}

# Fix hooks file
fix_hooks_file() {
    local hooks_file="$1"
    local dry_run="${2:-false}"

    if [[ ! -f "$hooks_file" ]]; then
        log_error "Hooks file not found: $hooks_file"
        return 1
    fi

    # Backup
    if [[ "$dry_run" != "true" ]]; then
        cp "$hooks_file" "${hooks_file}.backup.$(date +%s)"
        log_info "Backup created: ${hooks_file}.backup.$(date +%s)"
    fi

    # Apply fix
    local temp_file="${hooks_file}.tmp"
    local fixed_count=0

    # Read and fix the JSON file
    while IFS= read -r line; do
        local new_line="$line"
        if [[ "$line" =~ 'bun "\\${CLAUDE_PLUGIN_ROOT}/scripts/worker-service\.cjs"'(.*)'"' ]]; then
            local args="${BASH_REMATCH[1]}"
            new_line="            \"command\": \"(cd \\\"\\\${CLAUDE_PLUGIN_ROOT}\\\" \\&\\& bun scripts/worker-service.cjs${args})\","
            ((fixed_count++))
        fi
        echo "$new_line" >> "$temp_file"
    done < "$hooks_file"

    if [[ "$dry_run" == "true" ]]; then
        rm -f "$temp_file"
    else
        mv "$temp_file" "$hooks_file"
    fi

    echo "$fixed_count"
}

# Main function
main() {
    local check_only=false
    local dry_run=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                check_only=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                echo "fix-claude-mem-hooks.sh v${VERSION}"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    log_info "Claude-Mem Hooks Fix v${VERSION}"
    echo ""

    # Find plugin
    log_info "Searching for claude-mem plugin..."
    local plugin_path
    plugin_path="$(find_claude_mem_plugin)" || exit 1

    log_success "Found plugin at: $plugin_path"
    echo ""

    # Find all hooks.json files (both cache and marketplace)
    local hooks_files=()
    while IFS= read -r -d '' file; do
        hooks_files+=("$file")
    done < <(find ~/.claude-sneakpeek/zai/config/plugins -name "hooks.json" -path "*/claude-mem/*" -print0 2>/dev/null)

    if [[ ${#hooks_files[@]} -eq 0 ]]; then
        log_warning "No hooks.json files found"
        exit 0
    fi

    log_info "Found ${#hooks_files[@]} hooks.json file(s)"
    echo ""

    # Check each file
    local total_issues=0
    local total_fixed=0

    for hooks_file in "${hooks_files[@]}"; do
        local counts
        counts="$(check_hooks_file "$hooks_file")"
        local incorrect_count="${counts%%|*}"
        local correct_count="${counts##*|}"

        if [[ "$incorrect_count" -gt 0 ]]; then
            log_warning "$hooks_file: $incorrect_count incorrect pattern(s)"
            ((total_issues += incorrect_count))

            if [[ "$check_only" == "false" ]]; then
                local fixed_count
                fixed_count="$(fix_hooks_file "$hooks_file" "$dry_run")"
                ((total_fixed += fixed_count))

                if [[ "$dry_run" == "true" ]]; then
                    log_info "  [DRY-RUN] Would fix $fixed_count command(s)"
                elif [[ "$fixed_count" -gt 0 ]]; then
                    log_success "  Fixed $fixed_count command(s)"
                fi
            fi
        elif [[ "$correct_count" -gt 0 ]]; then
            log_success "$hooks_file: Already correct ($correct_count commands)"
        else
            log_info "$hooks_file: No worker-service commands found"
        fi
    done

    echo ""
    log_info "Summary:"
    echo "  Total issues found: $total_issues"
    echo "  Total fixed: $total_fixed"

    if [[ "$check_only" == "true" ]]; then
        echo "  Mode: Check only (no changes made)"
    elif [[ "$dry_run" == "true" ]]; then
        echo "  Mode: Dry run (no changes made)"
    elif [[ "$total_fixed" -gt 0 ]]; then
        echo "  Mode: Fixed"
        log_success "✓ All hooks fixed successfully"
    fi

    if [[ "$total_issues" -gt 0 && "$check_only" == "false" && "$dry_run" == "false" ]]; then
        echo ""
        log_info "To verify the fix, restart Claude Code/z.ai"
    fi
}

# Run main
main "$@"
