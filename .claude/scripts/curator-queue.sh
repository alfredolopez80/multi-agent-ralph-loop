#!/bin/bash
# Repo Curator Queue Script v2.55.0
# Shows pending, approved, and rejected repositories
#
# Usage: curator-queue.sh [--type <type>] [--lang <lang>]

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
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                FILTER_TYPE="$2"
                shift 2
                ;;
            --lang)
                FILTER_LANG="$2"
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
Repo Curator Queue Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --type <type>   Filter by type (backend, frontend, etc.)
  --lang <lang>   Filter by language
  --help, -h      Show this help

Shows:
  - Pending: repositories awaiting review
  - Approved: repositories approved for learning
  - Rejected: repositories rejected
EOF
}

# Get repository info from manifest
get_repo_info() {
    local dir="$1"
    local manifest="${dir}/manifest.json"

    if [[ -f "$manifest" ]]; then
        jq -r '.repository // "unknown"' "$manifest"
    elif [[ -f "${dir}/.repo_name" ]]; then
        cat "${dir}/.repo_name"
    else
        basename "$dir"
    fi
}

# Count files in repo
get_file_count() {
    local dir="$1"
    local count_file="${dir}/.ingest_count"

    if [[ -f "$count_file" ]]; then
        cat "$count_file"
    else
        find "$dir" -type f ! -name ".repo_name" ! -name ".ingest_count" ! -name ".rejection_reason" ! -name "manifest.json" | wc -l | tr -d ' '
    fi
}

# Show repository details
show_repo() {
    local dir="$1"
    local status="$2"

    local repo
    repo=$(get_repo_info "$dir")

    local file_count
    file_count=$(get_file_count "$dir")

    local date_str=""
    if [[ -f "${dir}/manifest.json" ]]; then
        date_str=$(jq -r '.cloned_at // "unknown"' "${dir}/manifest.json" 2>/dev/null | cut -d'T' -f1)
    fi

    case "$status" in
        pending)
            echo -e "  ${YELLOW}⏳${NC} $repo ($file_count files) $date_str"
            ;;
        approved)
            echo -e "  ${GREEN}✅${NC} $repo ($file_count files) $date_str"
            ;;
        rejected)
            local reason=""
            if [[ -f "${dir}/.rejection_reason" ]]; then
                reason=$(tail -1 "${dir}/.rejection_reason" | cut -d' ' -f2-)
            fi
            echo -e "  ${RED}❌${NC} $repo - $reason"
            ;;
    esac
}

# Show queue for a directory
show_queue_dir() {
    local dir="$1"
    local label="$2"
    local status="$3"

    if [[ ! -d "$dir" ]]; then
        return
    fi

    local count=0
    # Note: tmp_file was dead code (never used), removed

    for subdir in "$dir"*/; do
        [[ -d "$subdir" ]] || continue
        # CRIT-001 fix: Use $((var + 1)) instead of ((var++)) with set -e
        count=$((count + 1))
    done

    if [[ $count -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}$label ($count)${NC}"
        echo " ----------------------------------------"

        for subdir in "$dir"*/; do
            [[ -d "$subdir" ]] || continue
            show_repo "$subdir" "$status"
        done
    fi
}

# Show rankings
show_rankings() {
    echo ""
    echo -e "${CYAN}📊 Rankings${NC}"
    echo "  ----------------------------------------"

    for ranking in "${RANKINGS_DIR}"/*.json; do
        [[ -f "$ranking" ]] || continue

        local filename
        filename=$(basename "$ranking" .json)
        local count
        count=$(jq '.rankings | length' "$ranking" 2>/dev/null || echo "0")
        local approved_count
        approved_count=$(jq '[.rankings[] | select(.approved == true)] | length' "$ranking" 2>/dev/null || echo "0")

        echo "  📋 $filename: $count repos ($approved_count approved)"
    done
}

# Main function
main() {
    local FILTER_TYPE=""
    local FILTER_LANG=""

    parse_args "$@"

    echo ""
    echo "========================================"
    echo -e "      ${BLUE}Repo Curator Queue${NC}"
    echo "========================================"

    # Show summary
    local pending_count=0
    local approved_count=0
    local rejected_count=0

    pending_count=$(find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    approved_count=$(find "$APPROVED_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    rejected_count=$(find "$REJECTED_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')

    echo ""
    echo -e "  ${YELLOW}Pending:${NC}   $pending_count"
    echo -e "  ${GREEN}Approved:${NC}  $approved_count"
    echo -e "  ${RED}Rejected:${NC}   $rejected_count"

    # Show queues
    show_queue_dir "$STAGING_DIR" "⏳ Pending Review" "pending"
    show_queue_dir "$APPROVED_DIR" "✅ Approved" "approved"
    show_queue_dir "$REJECTED_DIR" "❌ Rejected" "rejected"

    # Show rankings
    show_rankings

    echo ""
    echo "========================================"
}

main "$@"
