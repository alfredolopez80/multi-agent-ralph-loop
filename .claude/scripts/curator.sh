#!/bin/bash
# Repo Curator Full Pipeline Script v2.55.0
# Orchestrates the complete discovery -> score -> rank -> ingest pipeline
#
# Usage: curator.sh full --type <type> --lang <lang> [--tier <tier>] [--auto-approve]

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CACHE_DIR="${CURATOR_DIR}/cache"
CANDIDATES_DIR="${CURATOR_DIR}/candidates"
RANKINGS_DIR="${CURATOR_DIR}/rankings"
CORPUS_DIR="${CURATOR_DIR}/corpus"
STAGING_DIR="${CORPUS_DIR}/staging"
APPROVED_DIR="${CORPUS_DIR}/approved"
LOGS_DIR="${CURATOR_DIR}/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                QUERY_TYPE="$2"
                shift 2
                ;;
            --lang)
                QUERY_LANG="$2"
                shift 2
                ;;
            --tier)
                TIER="$2"
                shift 2
                ;;
            --query)
                CUSTOM_QUERY="$2"
                shift 2
                ;;
            --context)
                # Contextual criteria for more specific searches
                # Example: --context "error handling, retry patterns"
                CONTEXT_CRITERIA="$2"
                shift 2
                ;;
            --topics)
                # GitHub topics to filter by (comma-separated)
                # Example: --topics "resilience,fault-tolerance,microservices"
                TOPIC_FILTERS="$2"
                shift 2
                ;;
            --min-stars)
                MIN_STARS="$2"
                shift 2
                ;;
            --auto-approve)
                AUTO_APPROVE=true
                shift
                ;;
            --top-n)
                TOP_N="$2"
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
    cat << 'EOF'
Repo Curator Full Pipeline v2.55.0

Usage: curator.sh full [OPTIONS]

Options:
  --type <type>       Query type: backend, frontend, fullstack, cli, library (default: backend)
  --lang <lang>       Programming language (default: typescript)
  --tier <tier>       Pricing tier: free, economic, full (default: economic)
  --query <query>     Custom search query (overrides all other criteria)
  --context <text>    Contextual criteria for specific knowledge (v2.55)
                      Example: "error handling, retry patterns, resilience"
  --topics <list>     GitHub topics to filter (comma-separated, v2.55)
                      Example: "microservices,distributed-systems"
  --min-stars <n>     Minimum stars filter (default: type-dependent)
  --auto-approve      Auto-approve top repos
  --top-n <n>         Number of repos to include (default: 10)
  --help, -h          Show this help

Pipeline Steps:
  1. Discovery  - Search GitHub for candidate repositories (context-aware)
  2. Scoring    - Calculate quality scores
  3. Ranking    - Generate ranked list (max 2 per org)
  4. Ingest     - Clone approved repos to corpus

Examples:
  # Basic search
  curator.sh full --type backend --lang typescript

  # Context-aware search for specific patterns (v2.55)
  curator.sh full --type backend --lang typescript \
    --context "error handling, retry logic, circuit breaker" \
    --topics "resilience,fault-tolerance"

  # Find CLI tools for Go with specific criteria
  curator.sh full --type cli --lang go \
    --context "configuration management, environment variables"

  # Auto-approve with lower star threshold
  curator.sh full --type library --lang python \
    --min-stars 500 --auto-approve
EOF
}

# Check tier availability
check_tier() {
    local tier="$1"

    case "$tier" in
        free)
            return 0
            ;;
        economic)
            # Check if MiniMax is available
            if command -v minimax &>/dev/null || [[ -n "${MINIMAX_API_KEY:-}" ]]; then
                return 0
            else
                log_warn "MiniMax not available, falling back to free tier"
                return 1
            fi
            ;;
        full)
            # Check if Claude and Codex are available
            if command -v claude &>/dev/null && command -v codex &>/dev/null; then
                return 0
            else
                log_warn "Claude/Codex not available, falling back to economic tier"
                return 1
            fi
            ;;
    esac
}

# Run discovery
run_discovery() {
    local type="$1"
    local lang="$2"
    local query="${3:-}"
    local context="${4:-}"
    local topics="${5:-}"
    local min_stars="${6:-}"

    log_info "=== Step 1: Discovery ==="

    local discovery_output="${CANDIDATES_DIR}/${type}_${lang}_$(date +%Y%m%d_%H%M%S).json"

    local discovery_args=("--type" "$type" "--lang" "$lang" "--output" "$discovery_output")

    if [[ -n "$query" ]]; then
        discovery_args+=("--query" "$query")
    fi

    if [[ -n "$context" ]]; then
        discovery_args+=("--context" "$context")
    fi

    if [[ -n "$topics" ]]; then
        discovery_args+=("--topics" "$topics")
    fi

    if [[ -n "$min_stars" ]]; then
        discovery_args+=("--min-stars" "$min_stars")
    fi

    # Run discovery (output goes to stderr via log functions, file path is pre-determined)
    if ! "${HOME}/.claude/scripts/curator-discovery.sh" "${discovery_args[@]}"; then
        log_error "Discovery failed"
        return 1
    fi

    # Verify output file was created
    if [[ ! -f "$discovery_output" ]]; then
        log_error "Discovery output file not found: $discovery_output"
        return 1
    fi

    # Return only the file path
    echo "$discovery_output"
}

# Run scoring
run_scoring() {
    local input_file="$1"
    local tier="$2"
    local context="${3:-}"

    log_info "=== Step 2: Scoring ==="

    local scoring_output="${input_file%.json}_scored.json"

    local scoring_args=("--input" "$input_file" "--output" "$scoring_output" "--tier" "$tier")

    # v2.55: Pass context keywords for relevance scoring
    if [[ -n "$context" ]]; then
        scoring_args+=("--context" "$context")
    fi

    "${HOME}/.claude/scripts/curator-scoring.sh" "${scoring_args[@]}" || {
        log_error "Scoring failed"
        return 1
    }

    echo "$scoring_output"
}

# Run ranking
run_ranking() {
    local input_file="$1"
    local top_n="$2"

    log_info "=== Step 3: Ranking ==="

    local ranking_output="${RANKINGS_DIR}/ranking_$(basename "$input_file" .json).json"

    "${HOME}/.claude/scripts/curator-rank.sh" --input "$input_file" --output "$ranking_output" --top-n "$top_n" || {
        log_error "Ranking failed"
        return 1
    }

    echo "$ranking_output"
}

# Auto-approve top repos
auto_approve() {
    local ranking_file="$1"

    log_info "=== Step 4: Auto-Approval ==="

    local repo_count
    repo_count=$(jq '.rankings | length' "$ranking_file")

    log_info "Auto-approving top $repo_count repositories"

    jq -r '.rankings[] | .full_name' "$ranking_file" | while read -r repo; do
        "${HOME}/.claude/scripts/curator-approve.sh" --repo "$repo" || true
    done
}

# Main function
main() {
    local QUERY_TYPE="backend"
    local QUERY_LANG="typescript"
    local TIER="economic"
    local CUSTOM_QUERY=""
    local CONTEXT_CRITERIA=""
    local TOPIC_FILTERS=""
    local MIN_STARS=""
    local AUTO_APPROVE=false
    local TOP_N=10

    parse_args "$@"

    # Ensure directories exist
    mkdir -p "$CACHE_DIR" "$CANDIDATES_DIR" "$RANKINGS_DIR" "$CORPUS_DIR" "$STAGING_DIR" "$APPROVED_DIR" "$LOGS_DIR"

    echo ""
    echo "========================================"
    echo -e "      ${CYAN}Repo Curator Pipeline${NC}"
    echo "========================================"
    echo ""
    echo "Configuration:"
    echo "  Type: $QUERY_TYPE"
    echo "  Language: $QUERY_LANG"
    echo "  Tier: $TIER"
    echo "  Top N: $TOP_N"
    echo ""

    # Check tier availability
    if ! check_tier "$TIER"; then
        if [[ "$TIER" == "full" ]]; then
            TIER="economic"
        else
            TIER="free"
        fi
        log_info "Using fallback tier: $TIER"
    fi

    # Start pipeline
    local start_time
    start_time=$(date +%s)

    # Step 1: Discovery
    local discovery_output
    discovery_output=$(run_discovery "$QUERY_TYPE" "$QUERY_LANG" "$CUSTOM_QUERY" "$CONTEXT_CRITERIA" "$TOPIC_FILTERS" "$MIN_STARS") || exit 1

    # Step 2: Scoring (with context relevance scoring v2.55)
    local scoring_output
    scoring_output=$(run_scoring "$discovery_output" "$TIER" "$CONTEXT_CRITERIA") || exit 1

    # Step 3: Ranking
    local ranking_output
    ranking_output=$(run_ranking "$scoring_output" "$TOP_N") || exit 1

    # Step 4: Auto-approve (if requested)
    if [[ "$AUTO_APPROVE" == "true" ]]; then
        auto_approve "$ranking_output"
    fi

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    echo ""
    echo "========================================"
    echo -e "      ${GREEN}Pipeline Complete${NC}"
    echo "========================================"
    echo "  Duration: ${duration}s"
    echo "  Ranking file: $ranking_output"
    echo ""
    echo "Next Steps:"
    echo "  1. Review ranking: ralph curator show --type $QUERY_TYPE --lang $QUERY_LANG"
    echo "  2. Approve repos: ralph curator approve <repo>"
    echo "  3. Learn patterns: ralph curator learn --repo <repo>"
    echo "========================================"
}

main "$@"
