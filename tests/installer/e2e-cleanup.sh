#!/usr/bin/env bash
#===============================================================================
# e2e-cleanup.sh - Cleanup script for E2E Installation Tests
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Cleans up test environment after E2E installer testing
#
# Usage:
#   ./e2e-cleanup.sh                    # Clean up default test directory
#   ./e2e-cleanup.sh --all              # Clean up all ralph-e2e-test directories
#   ./e2e-cleanup.sh --force            # Skip confirmation
#
# Environment Variables:
#   E2E_TEST_DIR - Override test directory (default: /tmp/ralph-e2e-test-*)
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Find all E2E test directories
find_test_dirs() {
    find /tmp -maxdepth 1 -type d -name "ralph-e2e-test-*" 2>/dev/null || true
}

# Clean a single test directory
cleanup_dir() {
    local dir="$1"
    local force="${2:-false}"

    if [[ ! -d "$dir" ]]; then
        log_warn "Directory not found: $dir"
        return 0
    fi

    # Safety check - ensure it's actually a test directory
    if [[ ! "$dir" =~ ralph-e2e-test ]]; then
        log_error "Refusing to delete non-test directory: $dir"
        return 1
    fi

    # Check for state file
    local state_file="$dir/.e2e-state"
    if [[ -f "$state_file" ]]; then
        log_info "Found state file for: $dir"
        if [[ "$force" != "true" ]]; then
            echo "  State:"
            cat "$state_file" | sed 's/^/    /'
            echo ""
        fi
    fi

    # Confirm deletion unless --force
    if [[ "$force" != "true" ]]; then
        read -p "Remove $dir? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipped: $dir"
            return 0
        fi
    fi

    # Remove directory
    rm -rf "$dir"
    log_success "Removed: $dir"
}

# Clean up all test directories
cleanup_all() {
    local force="${1:-false}"
    local dirs
    dirs=$(find_test_dirs)

    if [[ -z "$dirs" ]]; then
        log_info "No test directories found"
        return 0
    fi

    log_info "Found test directories:"
    echo "$dirs" | while read -r dir; do
        echo "  - $dir"
    done
    echo ""

    if [[ "$force" != "true" ]]; then
        read -p "Remove all test directories? [y/N] " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Aborted"
            return 0
        fi
    fi

    echo "$dirs" | while read -r dir; do
        cleanup_dir "$dir" "true"
    done
}

# Clean up specific directory
cleanup_specific() {
    local dir="${E2E_TEST_DIR:-}"
    local force="${1:-false}"

    if [[ -z "$dir" ]]; then
        # Try to find the most recent test directory
        dir=$(find_test_dirs | head -1)
        if [[ -z "$dir" ]]; then
            log_info "No test directories found"
            return 0
        fi
    fi

    cleanup_dir "$dir" "$force"
}

# Show summary
show_summary() {
    local dirs
    dirs=$(find_test_dirs)

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  E2E Test Directory Summary"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""

    if [[ -z "$dirs" ]]; then
        echo "  No test directories found."
    else
        echo "  Test directories:"
        echo "$dirs" | while read -r dir; do
            local size
            size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo "    - $dir ($size)"

            # Show state info if available
            if [[ -f "$dir/.e2e-state" ]]; then
                local created
                created=$(grep "CREATED_AT" "$dir/.e2e-state" | cut -d= -f2)
                echo "      Created: $created"
            fi
        done
    fi

    echo ""
}

# Main
main() {
    local force="false"
    local mode="specific"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a)
                mode="all"
                shift
                ;;
            --force|-f)
                force="true"
                shift
                ;;
            --summary|--status|-s)
                show_summary
                exit 0
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  (no args)    Clean up most recent test directory"
                echo "  --all        Clean up all ralph-e2e-test directories"
                echo "  --force      Skip confirmation prompts"
                echo "  --summary    Show summary of test directories"
                echo "  --help       Show this help"
                echo ""
                echo "Environment Variables:"
                echo "  E2E_TEST_DIR - Specific test directory to clean"
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  E2E Test Cleanup"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""

    case "$mode" in
        all)
            cleanup_all "$force"
            ;;
        *)
            cleanup_specific "$force"
            ;;
    esac

    echo ""
    log_success "Cleanup complete"
    echo ""
}

main "$@"
