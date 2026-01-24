#!/bin/bash
# Repo Curator Approve Script v2.57.0
# Approves staged repositories for learning
#
# Usage: curator-approve.sh --repo <owner/repo> [--all]
#
# Security fixes v2.57.0:
#   SEC-017: Added repo format validation
#   SEC-018: Strict allowlist sanitization

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CORPUS_DIR="${CURATOR_DIR}/corpus"
STAGING_DIR="${CORPUS_DIR}/staging"
APPROVED_DIR="${CORPUS_DIR}/approved"
REJECTED_DIR="${CORPUS_DIR}/rejected"
RANKINGS_DIR="${CURATOR_DIR}/rankings"
PROCEDURAL_FILE="${HOME}/.ralph/procedural/rules.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo)
                REPO="$2"
                shift 2
                ;;
            --all)
                APPROVE_ALL=true
                shift
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
Repo Curator Approve Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --repo <owner/repo>   Repository to approve (required, unless --all)
  --all                 Approve all staged repositories
  --help, -h            Show this help

Examples:
  $(basename "$0") --repo nestjs/nest
  $(basename "$0") --repo prisma/prisma
  $(basename "$0") --all
EOF
}

# SEC-017: Validate repo format
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

# SEC-018: Sanitize repo name with strict allowlist
sanitize_dir() {
    echo "$1" | tr '/' '_' | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-'
}

# Approve a single repository
approve_repo() {
    local repo="$1"

    # Find the staged repository
    local sanitized
    sanitized=$(sanitize_dir "$repo")

    local staging_path=""
    for dir in "${STAGING_DIR}/${sanitized}"*/; do
        if [[ -d "$dir" ]]; then
            staging_path="$dir"
            break
        fi
    done

    if [[ -z "$staging_path" ]]; then
        # Try finding by repo name file
        # Use grep -Fx for exact fixed-string match (no regex)
        staging_path=$(find "$STAGING_DIR" -maxdepth 1 -name ".repo_name" -exec grep -Fxl "$repo" {} \; 2>/dev/null | head -1 | xargs dirname 2>/dev/null || true)
    fi

    if [[ -z "$staging_path" || ! -d "$staging_path" ]]; then
        log_error "Staged repository not found: $repo"
        log_info "Available staged repos:"
        ls -la "$STAGING_DIR" 2>/dev/null || true
        return 1
    fi

    # Move to approved
    local approved_name
    approved_name=$(sanitize_dir "$repo")
    local approved_path="${APPROVED_DIR}/${approved_name}"

    # Remove existing approved if exists (with safety validation)
    if [[ -d "$approved_path" ]]; then
        # SEC-007: Validate path is within APPROVED_DIR before rm -rf
        if [[ -n "$approved_path" && "$approved_path" == "$APPROVED_DIR"/* ]]; then
            log_info "Removing existing approved version: $approved_path"
            rm -rf "$approved_path"
        else
            log_error "Invalid approved path (security check failed): $approved_path"
            return 1
        fi
    fi

    mv "$staging_path" "$approved_path"

    log_success "Approved: $repo -> $approved_path"

    # Update rankings if exists
    update_rankings "$repo" "$approved_path"

    echo "$approved_path"
}

# Update rankings file to mark repo as approved
update_rankings() {
    local repo="$1"
    local approved_path="$2"

    # Find ranking files
    for ranking in "${RANKINGS_DIR}"/*.json; do
        [[ -f "$ranking" ]] || continue

        # Check if repo is in ranking
        if jq -e --arg repo "$repo" '.rankings[] | select(.full_name == $repo)' "$ranking" >/dev/null 2>&1; then
            log_info "Updating ranking: $(basename "$ranking")"

            # Update ranking entry
            jq --arg repo "$repo" --arg path "$approved_path" \
                '.rankings |= map(if .full_name == $repo then . + {approved: true, corpus_path: $path} else . end)' \
                "$ranking" > "${ranking}.tmp" && mv "${ranking}.tmp" "$ranking"
        fi
    done
}

# Approve all staged repositories
approve_all() {
    log_info "Approving all staged repositories..."

    local count=0
    local failed=0

    for staged_dir in "${STAGING_DIR}"*/; do
        [[ -d "$staged_dir" ]] || continue

        local repo_name_file="${staged_dir}.repo_name"
        if [[ -f "$repo_name_file" ]]; then
            local repo
            repo=$(cat "$repo_name_file" 2>/dev/null | head -1)
            if [[ -n "$repo" ]]; then
                if approve_repo "$repo"; then
                    count=$((count + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        else
            # Try to infer from directory name
            local dir_name
            dir_name=$(basename "$staged_dir" | sed 's/_[0-9]*$//')
            log_warn "No .repo_name file in $staged_dir, skipping"
            failed=$((failed + 1))
        fi
    done

    log_success "Approved $count repositories ($failed failed)"
}

# Main function
main() {
    local REPO=""
    local APPROVE_ALL=false

    parse_args "$@"

    # Ensure directories exist
    mkdir -p "$APPROVED_DIR" "$RANKINGS_DIR"

    if [[ "$APPROVE_ALL" == "true" ]]; then
        approve_all
    elif [[ -n "$REPO" ]]; then
        # SEC-017: Validate repo format before use
        validate_repo "$REPO"
        approve_repo "$REPO"
    else
        log_error "Repository or --all flag is required"
        show_help
        exit 1
    fi
}

main "$@"
