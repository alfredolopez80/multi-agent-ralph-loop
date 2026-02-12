#!/bin/bash
# Repo Curator Scoring Script v2.84.2
# Scores candidate repositories based on quality metrics AND context relevance
#
# Usage: curator-scoring.sh --input <file> --output <file> [--tier <tier>] [--context <keywords]
#
# v2.84.2: SECURITY FIX - Sanitize owner/repo names to prevent URL injection

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CONFIG_FILE="${CURATOR_DIR}/config.yml"
CACHE_DIR="${CURATOR_DIR}/cache"
LOGS_DIR="${CURATOR_DIR}/logs"

# Default values
INPUT_FILE=""
OUTPUT_FILE=""
TIER="economic"
VERBOSE=false
CONTEXT_KEYWORDS=""

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

# v2.84.2: SECURITY FIX - Sanitize GitHub owner/repo names
# Only allow alphanumeric, hyphens, underscores, and dots
sanitize_github_name() {
    local name="$1"
    # Remove any character that's not alphanumeric, hyphen, underscore, or dot
    echo "$name" | sed 's/[^a-zA-Z0-9._-]//g'
}

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
            --tier)
                TIER="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --context)
                CONTEXT_KEYWORDS="$2"
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
Repo Curator Scoring Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --input <file>      Input JSON file with candidates (required)
  --output <file>     Output JSON file for scored repos (required)
  --tier <tier>       Pricing tier: free, economic, full (default: economic)
  --context <keywords> Comma-separated keywords for relevance scoring (v2.55)
  --verbose, -v       Verbose output
  --help, -h          Show this help

Context Relevance Scoring (v2.55):
  When --context is provided, repos are scored on relevance:
  - +3 points if description contains context keywords
  - +2 points if repo name contains context keywords
  - -1 point if no description or irrelevant description

Examples:
  $(basename "$0") --input candidates.json --output scored.json --tier free
  $(basename "$0") --input candidates.json --output scored.json --context "error handling,retry,resilience"
EOF
}

# Load quality weights from config
load_weights() {
    local weights_file="${CURATOR_DIR}/weights.json"

    if [[ -f "$weights_file" ]]; then
        log_info "Loading weights from $weights_file"
        cat "$weights_file"
    else
        # Default weights
        cat << 'EOF'
{
  "stars": 0.15,
  "open_issues": 0.10,
  "closed_issues_ratio": 0.10,
  "contributors": 0.08,
  "has_tests": 0.15,
  "has_ci": 0.12,
  "has_readme": 0.05,
  "has_license": 0.05,
  "code_quality": 0.15,
  "recent_activity": 0.05
}
EOF
    fi
}

# Check for test files in repo
check_tests() {
    local owner="$1"
    local repo="$2"

    # v2.84.2: SECURITY FIX - Sanitize owner and repo names
    owner=$(sanitize_github_name "$owner")
    repo=$(sanitize_github_name "$repo")

    # Validate sanitized values are not empty
    [[ -z "$owner" || -z "$repo" ]] && { echo "false"; return; }

    # Check if repo has test files using GitHub API
    if command -v gh &>/dev/null && [[ -n "${GITHUB_TOKEN:-}" ]]; then
        export GH_TOKEN="$GITHUB_TOKEN"
        if gh api "repos/$owner/$repo/contents" --jq '.[].name' 2>/dev/null | grep -iqE "(test|spec|\.test\.|_test\.)"; then
            echo "true"
            return
        fi
    fi

    # Fallback: check common test directories
    local test_patterns=("test/" "tests/" "spec/" "__tests__/" "*.test.*" "*.spec.*")
    local has_tests=false

    for pattern in "${test_patterns[@]}"; do
        # v2.84.2: Use URL encoding for pattern
        local encoded_pattern=$(printf '%s' "$pattern" | jq -sRr @uri)
        if curl -s -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/search/code?q=${encoded_pattern}+repo:${owner}/${repo}" | \
            jq -e '.total_count > 0' 2>/dev/null; then
            has_tests=true
            break
        fi
    done

    $has_tests && echo "true" || echo "false"
}

# Check for CI/CD configuration
check_ci() {
    local owner="$1"
    local repo="$2"

    # v2.84.2: SECURITY FIX - Sanitize owner and repo names
    owner=$(sanitize_github_name "$owner")
    repo=$(sanitize_github_name "$repo")

    # Validate sanitized values are not empty
    [[ -z "$owner" || -z "$repo" ]] && { echo "false"; return; }

    local ci_patterns=(".github/workflows" ".travis.yml" ".circleci/config.yml" "Jenkinsfile" ".gitlab-ci.yml" "Makefile")

    for pattern in "${ci_patterns[@]}"; do
        # v2.84.2: Use URL encoding for pattern
        local encoded_pattern=$(printf '%s' "$pattern" | jq -sRr @uri)
        if curl -s -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${owner}/${repo}/contents/${encoded_pattern}" 2>/dev/null | \
            jq -e 'type == "object"' 2>/dev/null; then
            echo "true"
            return
        fi
    done

    echo "false"
}

# Calculate context relevance score (v2.55 - VITAL)
# Scores how well a repo matches the search context keywords
calculate_relevance_score() {
    local repo_json="$1"
    local context_keywords="$2"

    # If no context keywords, return neutral score
    if [[ -z "$context_keywords" ]]; then
        echo "0"
        return
    fi

    local description name
    description=$(echo "$repo_json" | jq -r '.description // ""' | tr '[:upper:]' '[:lower:]')
    name=$(echo "$repo_json" | jq -r '.name // ""' | tr '[:upper:]' '[:lower:]')

    local relevance_score=0
    local keyword_matches=0
    local total_keywords=0

    # Split keywords using POSIX-compatible method (works in zsh and bash)
    local OLD_IFS="$IFS"
    IFS=','
    for keyword in $context_keywords; do
        # Trim whitespace and lowercase
        keyword=$(echo "$keyword" | xargs | tr '[:upper:]' '[:lower:]')
        [[ -z "$keyword" ]] && continue

        total_keywords=$((total_keywords + 1))

        # Check if description contains keyword (+3 points per match)
        # Use grep -F (fixed string) to avoid regex injection
        if [[ -n "$description" ]] && echo "$description" | grep -Fqi "$keyword"; then
            relevance_score=$((relevance_score + 3))
            keyword_matches=$((keyword_matches + 1))
        fi

        # Check if repo name contains keyword (+2 points per match)
        # Use grep -F (fixed string) to avoid regex injection
        if echo "$name" | grep -Fqi "$keyword"; then
            relevance_score=$((relevance_score + 2))
            keyword_matches=$((keyword_matches + 1))
        fi
    done
    IFS="$OLD_IFS"

    # Penalty for no matches when context was specified
    if [[ $total_keywords -gt 0 && $keyword_matches -eq 0 ]]; then
        relevance_score=-1
    fi

    # Bonus for high match rate (>50% keywords matched)
    if [[ $total_keywords -gt 0 && $keyword_matches -gt 0 ]]; then
        local match_rate=$((keyword_matches * 100 / total_keywords))
        if [[ $match_rate -ge 50 ]]; then
            relevance_score=$((relevance_score + 2))
        fi
    fi

    echo "$relevance_score"
}

# Calculate quality score for a repository
calculate_score() {
    local repo_json="$1"
    local context_keywords="${2:-}"

    local stars forks open_issues description name
    stars=$(echo "$repo_json" | jq -r '.stars // 0')
    forks=$(echo "$repo_json" | jq -r '.forks // 0')
    open_issues=$(echo "$repo_json" | jq -r '.open_issues // 0')
    description=$(echo "$repo_json" | jq -r '.description // ""')
    name=$(echo "$repo_json" | jq -r '.name // ""')

    # SEC-008: Validate numeric inputs before bc (prevent injection)
    [[ "$stars" =~ ^[0-9]+$ ]] || stars=0
    [[ "$forks" =~ ^[0-9]+$ ]] || forks=0
    [[ "$open_issues" =~ ^[0-9]+$ ]] || open_issues=0

    # Normalize stars (log scale)
    local stars_score
    stars_score=$(echo "scale=2; l($stars + 1) / l(10000) * 10" | bc -l 2>/dev/null || echo "0")
    stars_score=$(echo "$stars_score" | awk '{if ($1 > 10) print 10; else if ($1 < 0) print 0; else print $1}')

    # Issue ratio score
    local total_issues=$((forks + open_issues))
    local issues_ratio_score=5
    if [[ $total_issues -gt 0 ]]; then
        issues_ratio_score=$(echo "scale=2; (1 - $open_issues / $total_issues) * 10" | bc -l 2>/dev/null || echo "5")
    fi

    # Description quality (FIXED: now using assigned description)
    local desc_length
    desc_length=$(echo "$description" | wc -c)
    local desc_score=0
    if [[ $desc_length -gt 50 ]]; then
        desc_score=7
    fi
    if [[ $desc_length -gt 100 ]]; then
        desc_score=10
    fi

    # Has readme and license
    local has_readme=5
    local has_license=5

    # Calculate weighted score
    local total_score
    total_score=$(echo "scale=2; ($stars_score * 0.15) + ($issues_ratio_score * 0.10) + ($desc_score * 0.05) + ($has_readme * 0.05) + ($has_license * 0.05)" | bc -l 2>/dev/null || echo "5")

    # Add test and CI scores
    local owner
    owner=$(echo "$repo_json" | jq -r '.owner')

    local has_tests has_ci
    has_tests=$(check_tests "$owner" "$name")
    has_ci=$(check_ci "$owner" "$name")

    local tests_score=0
    local ci_score=0

    if [[ "$has_tests" == "true" ]]; then
        tests_score=10
    fi

    if [[ "$has_ci" == "true" ]]; then
        ci_score=10
    fi

    total_score=$(echo "scale=2; $total_score + ($tests_score * 0.15) + ($ci_score * 0.12)" | bc -l 2>/dev/null || echo "5")

    # v2.55: Context Relevance Score (VITAL)
    local relevance_score=0
    if [[ -n "$context_keywords" ]]; then
        relevance_score=$(calculate_relevance_score "$repo_json" "$context_keywords")

        # Apply relevance as a multiplier for context-aware searches
        # - Positive relevance (matched keywords): boost score
        # - Negative relevance (no matches): reduce score significantly
        if [[ $relevance_score -gt 0 ]]; then
            # Boost: +5% per relevance point (max ~50% boost for very relevant repos)
            local boost
            boost=$(echo "scale=2; 1 + ($relevance_score * 0.05)" | bc -l 2>/dev/null || echo "1")
            total_score=$(echo "scale=2; $total_score * $boost" | bc -l 2>/dev/null || echo "$total_score")
        elif [[ $relevance_score -lt 0 ]]; then
            # Penalty: reduce by 30% for no relevance match (important for context searches)
            total_score=$(echo "scale=2; $total_score * 0.70" | bc -l 2>/dev/null || echo "$total_score")
        fi
    fi

    # Ensure score is between 0 and 10
    total_score=$(echo "$total_score" | awk '{if ($1 > 10) print 10; else if ($1 < 0) print 0; else print $1}')

    # Output as JSON
    jq -n \
        --argjson stars "$stars_score" \
        --argjson issues "$issues_ratio_score" \
        --argjson desc "$desc_score" \
        --argjson tests "$tests_score" \
        --argjson ci "$ci_score" \
        --argjson relevance "$relevance_score" \
        --argjson total "$total_score" \
        '{
            stars_score: $stars,
            issues_ratio_score: $issues,
            description_score: $desc,
            has_tests_score: $tests,
            has_ci_score: $ci,
            context_relevance_score: $relevance,
            quality_score: $total
        }'
}

# Main scoring function
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

    mkdir -p "$CACHE_DIR" "$LOGS_DIR"

    # Generate output filename if not provided
    if [[ -z "$OUTPUT_FILE" ]]; then
        OUTPUT_FILE="${INPUT_FILE%.json}_scored.json"
    fi

    log_info "Scoring repositories from: $INPUT_FILE"
    log_info "Output will be saved to: $OUTPUT_FILE"

    local total_count
    total_count=$(jq 'length' "$INPUT_FILE")
    log_info "Processing $total_count repositories..."

    # Log context keywords if provided (v2.55)
    if [[ -n "$CONTEXT_KEYWORDS" ]]; then
        log_info "Context relevance scoring enabled with keywords: $CONTEXT_KEYWORDS"
    fi

    # Process each repository
    jq -c '.[]' "$INPUT_FILE" | while read -r repo; do
        local owner name full_name
        owner=$(echo "$repo" | jq -r '.owner')
        name=$(echo "$repo" | jq -r '.name')
        full_name=$(echo "$repo" | jq -r '.full_name')

        if [[ "$VERBOSE" == "true" ]]; then
            log_info "Scoring: $full_name"
        fi

        # Calculate scores (pass context keywords for relevance scoring)
        local scores
        scores=$(calculate_score "$repo" "$CONTEXT_KEYWORDS")

        # Add scores to repo
        echo "$repo" | jq --argjson scores "$scores" '. + {quality_metrics: $scores}'
    done | jq -s '.' > "$OUTPUT_FILE"

    local scored_count
    scored_count=$(jq 'length' "$OUTPUT_FILE")

    # Calculate average score
    local avg_score
    avg_score=$(jq '[.[] | .quality_metrics.quality_score] | add / length' "$OUTPUT_FILE")

    log_success "Scoring complete!"
    {
        echo ""
        echo "=== Scoring Summary ==="
        echo "Repositories processed: $total_count"
        echo "Repositories scored: $scored_count"
        echo "Average quality score: $avg_score"
        echo "Output file: $OUTPUT_FILE"
        echo "======================"
    } >&2
}

main "$@"
