#!/usr/bin/env bash
#
# fix-pretooluse-hooks.sh
#
# Auto-fix PreToolUse hooks to include hookEventName in JSON output
# Required for Claude Code v2.70.0+ hook format validation
#
# Version: 1.0.0
# Updated: 2026-01-28
#
# Usage:
#   ./fix-pretooluse-hooks.sh                    # Auto-fix all hooks
#   ./fix-pretooluse-hooks.sh --check           # Check only, don't fix

set -euo pipefail

VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
TOTAL_ISSUES=0
TOTAL_FIXED=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[✓]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[✗]${NC} $*"; }

# Show usage
show_usage() {
    cat <<EOF
fix-pretooluse-hooks.sh v${VERSION}

Auto-fix PreToolUse hooks to include hookEventName in JSON output.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --check       Check only, don't apply fixes
    --dry-run     Show what would be changed without applying
    --help        Show this help message

WHAT IT FIXES:
    Before: {"hookSpecificOutput": {"permissionDecision": "allow"}}
    After:  {"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}

HOOKS DIRECTORIES:
    ~/.claude/hooks/           (global hooks)
    .claude/hooks/             (project hooks)

EOF
}

# Fix patterns using sed
fix_hook_file() {
    local hook_file="$1"
    local dry_run="${2:-false}"

    local fixes_count=0

    # Backup
    if [[ "$dry_run" != "true" ]]; then
        cp "$hook_file" "${hook_file}.backup.$(date +%s)"
    fi

    local temp_file="${hook_file}.tmp"

    # Use Perl for better regex handling
    perl -pe '
        # Pattern 1: Simple {"hookSpecificOutput": {"permissionDecision": "allow"}}
        s/"\{\\?"hookSpecificOutput\\?": \{\\?"permissionDecision\\?": \\?"allow\\?"\}\}"/"{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"allow\"}}"/g &&
        $fixes_count++;

        # Pattern 2: permissionDecision without hookEventName (more generic)
        s/"hookSpecificOutput": \{(\s*)"permissionDecision"/"hookSpecificOutput": {$1"hookEventName": "PreToolUse", $1"permissionDecision"/g &&
        $fixes_count++;
    ' "$hook_file" > "$temp_file" 2>/dev/null || true

    if [[ -s "$temp_file" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            # Count changes in temp file
            local changes
            changes=$(diff "$hook_file" "$temp_file" 2>/dev/null | grep -c "^<" || echo "0")
            echo "$changes"
            rm -f "$temp_file"
        else
            mv "$temp_file" "$hook_file"
            # Count how many lines were changed
            echo "0"  # Will be recalculated by check
        fi
    else
        rm -f "$temp_file"
        echo "0"
    fi
}

# Check a single hook file
check_hook_file() {
    local hook_file="$1"

    if [[ ! -f "$hook_file" ]]; then
        echo "0|0"
        return 0
    fi

    # Only check PreToolUse hooks (those with permissionDecision)
    if ! grep -q "permissionDecision" "$hook_file" 2>/dev/null; then
        echo "0|0"
        return 0
    fi

    local bad_count=0
    local good_count=0

    # Count outputs with permissionDecision
    local total_outputs
    total_outputs=$(grep -c "permissionDecision" "$hook_file" 2>/dev/null || echo "0")

    # Count outputs that already have hookEventName
    good_count=$(grep -c "hookEventName.*PreToolUse" "$hook_file" 2>/dev/null || echo "0")

    # Bad = total - good
    if [[ "$total_outputs" -gt 0 ]]; then
        bad_count=$((total_outputs - good_count))
    fi

    echo "${bad_count}|${good_count}"
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
                echo "fix-pretooluse-hooks.sh v${VERSION}"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    log_info "PreToolUse Hook Fixer v${VERSION}"
    echo ""

    # Find all hook files
    local hooks_dirs=("$HOME/.claude/hooks" ".claude/hooks")
    local hooks_files=()

    for dir in "${hooks_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            while IFS= read -r -d '' file; do
                hooks_files+=("$file")
            done < <(find "$dir" -name "*.sh" -type f -print0 2>/dev/null)
        fi
    done

    if [[ ${#hooks_files[@]} -eq 0 ]]; then
        log_warning "No hook files found"
        exit 0
    fi

    log_info "Found ${#hooks_files[@]} hook file(s)"
    echo ""

    # Check and fix each file
    for hook_file in "${hooks_files[@]}"; do
        local counts
        counts="$(check_hook_file "$hook_file")"
        local bad_count="${counts%%|*}"
        local good_count="${counts##*|}"

        if [[ "$bad_count" -gt 0 ]]; then
            log_warning "$(basename "$hook_file"): $bad_count output(s) need fixing"
            ((TOTAL_ISSUES += bad_count))

            if [[ "$check_only" == "false" ]]; then
                local fixed_count
                fixed_count="$(fix_hook_file "$hook_file" "$dry_run")"
                ((TOTAL_FIXED += fixed_count))

                if [[ "$dry_run" == "true" ]]; then
                    log_info "  [DRY-RUN] Would fix $fixed_count output(s)"
                elif [[ "$fixed_count" -gt 0 ]]; then
                    log_success "  Fixed $fixed_count output(s)"
                fi
            fi
        elif [[ "$good_count" -gt 0 ]]; then
            log_success "$(basename "$hook_file"): Already correct ($good_count outputs)"
        fi
    done

    echo ""
    log_info "Summary:"
    echo "  Total issues found: $TOTAL_ISSUES"
    echo "  Total fixed: $TOTAL_FIXED"

    if [[ "$check_only" == "true" ]]; then
        echo "  Mode: Check only (no changes made)"
    elif [[ "$dry_run" == "true" ]]; then
        echo "  Mode: Dry run (no changes made)"
    elif [[ "$TOTAL_FIXED" -gt 0 ]]; then
        echo "  Mode: Fixed"
        log_success "✓ All hooks fixed successfully"
    fi
}

# Run main
main "$@"
