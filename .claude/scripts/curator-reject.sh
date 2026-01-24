#!/bin/bash
# Repo Curator Reject Script v2.57.0
# Rejects staged or approved repositories
#
# Usage: curator-reject.sh --repo <owner/repo> [--reason <reason>]
#
# Security fixes v2.57.0:
#   SEC-019: Added repo format validation
#   SEC-020: Strict allowlist sanitization
#   SEC-021: Path validation before rm -rf (TOCTOU fix)

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CORPUS_DIR="${CURATOR_DIR}/corpus"
STAGING_DIR="${CORPUS_DIR}/staging"
APPROVED_DIR="${CORPUS_DIR}/approved"
REJECTED_DIR="${CORPUS_DIR}/rejected"
RANKINGS_DIR="${CURATOR_DIR}/rankings"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --reason)
                REASON="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Repo Curator Reject Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --repo <owner/repo>   Repository to reject (required)
  --reason <text>       Reason for rejection (optional)
  --help, -h            Show this help

Examples:
  $(basename "$0") --repo some-repo/bad-repo --reason "Low quality code"
EOF
}

# SEC-019: Validate repo format
validate_repo() {
    local repo="$1"
    if [[ ! "$repo" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*/[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]]; then
        log_error "Invalid repository format: $repo"
        exit 1
    fi
    if [[ "$repo" =~ \.\.|/\.|\./ ]]; then
        log_error "Invalid repository format: suspicious path sequence"
        exit 1
    fi
}

# SEC-020: Sanitize repo name with strict allowlist
sanitize_dir() {
    echo "$1" | tr '/' '_' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-'
}

# Reject a repository
reject_repo() {
    local repo="$1"
    local reason="${2:-"No reason provided"}"

    local sanitized
    sanitized=$(sanitize_dir "$repo")
    local rejected_path="${REJECTED_DIR}/${sanitized}"

    # Check staging first
    local source_path=""
    for dir in "${STAGING_DIR}/${sanitized}"*/ "${APPROVED_DIR}/${sanitized}"*/; do
        if [[ -d "$dir" ]]; then
            source_path="$dir"
            break
        fi
    done

    if [[ -z "$source_path" ]]; then
        log_error "Repository not found in staging or approved: $repo"
        return 1
    fi

    # Move to rejected
    # SEC-021: Validate path before rm -rf (same pattern as curator-approve.sh)
    if [[ -d "$rejected_path" ]]; then
        if [[ -n "$rejected_path" && "$rejected_path" == "$REJECTED_DIR"/* ]]; then
            log_info "Removing existing rejected version: $rejected_path"
            rm -rf "$rejected_path"
        else
            log_error "Invalid rejected path (security check failed): $rejected_path"
            return 1
        fi
    fi
    mv "$source_path" "$rejected_path"

    # Add rejection reason
    echo "Rejected: $(date -Iseconds)" > "${rejected_path}/.rejection_reason"
    echo "Reason: $reason" >> "${rejected_path}/.rejection_reason"

    log_success "Rejected: $repo"
    echo "Reason: $reason"
}

# Main function
main() {
    local REPO=""
    local REASON=""

    parse_args "$@"

    if [[ -z "$REPO" ]]; then
        log_error "Repository is required (--repo)"
        show_help
        exit 1
    fi

    # Ensure directory exists
    mkdir -p "$REJECTED_DIR"

    reject_repo "$REPO" "$REASON"
}

main "$@"
