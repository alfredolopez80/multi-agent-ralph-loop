#!/bin/bash
# Repo Curator Ranking Script v2.55.0
# Generates rankings from scored repositories
#
# Usage: curator-rank.sh --input <file> --output <file> [--top-n <n>] [--max-per-org <n>]

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CACHE_DIR="${CURATOR_DIR}/cache"
RANKINGS_DIR="${CURATOR_DIR}/rankings"

# Default values
INPUT_FILE=""
OUTPUT_FILE=""
TOP_N=10
MAX_PER_ORG=2

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
            --input)
                INPUT_FILE="$2"
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --top-n)
                TOP_N="$2"
                # SEC-010: Validate top-n is numeric
                if [[ ! "$TOP_N" =~ ^[0-9]+$ ]]; then
                    log_error "Invalid top-n: must be numeric"
                    exit 1
                fi
                shift 2
                ;;
            --max-per-org)
                MAX_PER_ORG="$2"
                # SEC-010: Validate max-per-org is numeric
                if [[ ! "$MAX_PER_ORG" =~ ^[0-9]+$ ]]; then
                    log_error "Invalid max-per-org: must be numeric"
                    exit 1
                fi
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
Repo Curator Ranking Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --input <file>      Input JSON file with scored repos (required)
  --output <file>     Output JSON file for ranking (required)
  --top-n <n>         Maximum repos in ranking (default: 10)
  --max-per-org <n>   Maximum repos per organization (default: 2)
  --help, -h          Show this help

Examples:
  $(basename "$0") --input scored.json --output ranking.json --top-n 10
  $(basename "$0") --input scored.json --output ranking.json --max-per-org 1
EOF
}

# Main ranking function
main() {
    parse_args "$@"

    if [[ -z "$INPUT_FILE" ]]; then
        log_error "Input file is required"
        exit 1
    fi

    if [[ ! -f "$INPUT_FILE" ]]; then
        log_error "Input file not found: $INPUT_FILE"
        exit 1
    fi

    mkdir -p "$CACHE_DIR" "$RANKINGS_DIR"

    # Generate output filename if not provided
    if [[ -z "$OUTPUT_FILE" ]]; then
        local basename
        basename=$(basename "$INPUT_FILE" .json)
        OUTPUT_FILE="${RANKINGS_DIR}/${basename}_ranking.json"
    fi

    log_info "Generating ranking from: $INPUT_FILE"
    log_info "Output will be saved to: $OUTPUT_FILE"

    # Step 1: Sort by composite score (quality + relevance boost) - v2.55
    # Step 2: Limit to top N per organization
    # Step 3: Take final top N

    # SEC-009: Use mktemp instead of $$ for secure temp files
    local tmp_file
    tmp_file=$(mktemp "${CACHE_DIR}/ranking_tmp_XXXXXX.json")

    # Get repos sorted by composite score:
    # - Primary: quality_score * (1 + relevance_boost)
    # - Where relevance_boost = max(0, context_relevance_score * 0.1)
    # This ensures repos with positive relevance rank higher among same-quality repos
    jq '[.[] | . + {
        _composite_score: (
            (.quality_metrics.quality_score // 0) *
            (1 + ([0, ((.quality_metrics.context_relevance_score // 0) * 0.1)] | max))
        )
    }] | sort_by(._composite_score) | reverse | map(del(._composite_score))' "$INPUT_FILE" > "$tmp_file"

    # Count repos per org
    local org_counts
    org_counts=$(jq '[.[] | {owner: .owner, name: .name}]' "$tmp_file" | jq -r '.[].owner' | sort | uniq -c | sort -rn)

    # Filter to max per org
    local org_filtered
    org_filtered=$(jq '
        reduce .[] as $repo ([];
          . as $acc |
          ($repo.owner) as $org |
          ([.[] | select(.owner == $org)] | length) as $current_count |
          if $current_count < '$MAX_PER_ORG' then
            . + [$repo]
          else
            .
          end
        )
    ' "$tmp_file")

    # Add ranking position and filter to top N
    # SEC-009: Use mktemp instead of $$ for secure temp files
    local ranked_file
    ranked_file=$(mktemp "${CACHE_DIR}/ranked_XXXXXX.json")
    echo "$org_filtered" | jq '
        [limit('"$TOP_N"'; .[])] |
        to_entries |
        map(.value + {ranking_position: (.key + 1), tier: "curated"}) |
        sort_by(.ranking_position)
    ' > "$ranked_file" 2>/dev/null || {
        log_error "Failed to process ranking"
        rm -f "$ranked_file"
        return 1
    }

    # Add metadata
    local timestamp
    timestamp=$(date -Iseconds)

    local final_output
    final_output=$(jq \
        --arg timestamp "$timestamp" \
        --arg input "$INPUT_FILE" \
        --arg top_n "$TOP_N" \
        --arg max_per_org "$MAX_PER_ORG" \
        --arg version "2.55.0" \
        '{
            metadata: {
                generated_at: $timestamp,
                source_file: $input,
                top_n: ($top_n | tonumber),
                max_per_org: ($max_per_org | tonumber),
                total_repos: (. | length),
                version: $version
            },
            rankings: .
        }' "$ranked_file")

    rm -f "$ranked_file"

    echo "$final_output" | jq '.' > "$OUTPUT_FILE"

    local count
    count=$(jq '.rankings | length' "$OUTPUT_FILE")

    log_success "Ranking complete!"
    {
        echo ""
        echo "=== Ranking Summary ==="
        echo "Repositories in ranking: $count"
        echo "Max per organization: $MAX_PER_ORG"
        echo "Output file: $OUTPUT_FILE"
        echo "======================="
    } >&2

    rm -f "$tmp_file"
}

main "$@"
