#!/bin/bash
# Repo Curator Discovery Script v2.55.0
# Discovers candidate repositories from GitHub based on query
#
# Usage: curator-discovery.sh --type <type> --lang <lang> --query <query> [--tier <tier>]
#
# Outputs: JSON list of candidates to stdout

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CONFIG_FILE="${CURATOR_DIR}/config.yml"
CACHE_DIR="${CURATOR_DIR}/cache"
CANDIDATES_DIR="${CURATOR_DIR}/candidates"
LOGS_DIR="${CURATOR_DIR}/logs"

# Default values
QUERY_TYPE="backend"
QUERY_LANG="typescript"
QUERY=""
TIER="economic"
MAX_RESULTS=100
OUTPUT_FILE=""
CONTEXT_CRITERIA=""
TOPIC_FILTERS=""
MIN_STARS=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions - ALL go to stderr to keep stdout clean for output
# v2.55: Moved BEFORE validate_input() which uses log_error
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# SEC-010: Validation patterns (alphanumeric, dash, underscore only)
readonly VALID_INPUT_PATTERN='^[a-zA-Z0-9_-]+$'

# SEC-010: Validate input against allowed pattern
validate_input() {
    local value="$1"
    local name="$2"
    if [[ ! "$value" =~ $VALID_INPUT_PATTERN ]]; then
        log_error "Invalid $name: contains disallowed characters"
        exit 1
    fi
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                QUERY_TYPE="$2"
                # SEC-010: Validate type input
                validate_input "$QUERY_TYPE" "type"
                shift 2
                ;;
            --lang)
                QUERY_LANG="$2"
                # SEC-010: Validate language input
                validate_input "$QUERY_LANG" "lang"
                shift 2
                ;;
            --query)
                QUERY="$2"
                shift 2
                ;;
            --tier)
                TIER="$2"
                # SEC-010: Validate tier is one of allowed values
                case "$TIER" in
                    free|economic|full) ;;
                    *) log_error "Invalid tier: $TIER (must be free, economic, or full)"; exit 1 ;;
                esac
                shift 2
                ;;
            --max-results)
                MAX_RESULTS="$2"
                # SEC-010: Validate max-results is numeric
                if [[ ! "$MAX_RESULTS" =~ ^[0-9]+$ ]]; then
                    log_error "Invalid max-results: must be numeric"
                    exit 1
                fi
                shift 2
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --context)
                CONTEXT_CRITERIA="$2"
                shift 2
                ;;
            --topics)
                TOPIC_FILTERS="$2"
                shift 2
                ;;
            --min-stars)
                MIN_STARS="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Repo Curator Discovery Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --type <type>         Query type: backend, frontend, fullstack, cli, library (default: backend)
  --lang <lang>         Programming language (default: typescript)
  --query <query>       Custom search query (optional, auto-generated if empty)
  --tier <tier>         Pricing tier: free, economic, full (default: economic)
  --max-results <n>     Maximum results (default: 100)
  --output <file>       Output file path (optional)
  --help, -h            Show this help message

Examples:
  $(basename "$0") --type backend --lang typescript
  $(basename "$0") --type cli --lang rust --tier free
  $(basename "$0") --query "enterprise microservice architecture" --tier economic

Output:
  Writes JSON to stdout or specified output file
EOF
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Loading configuration from $CONFIG_FILE"
    else
        log_warn "Configuration file not found, using defaults"
    fi
}

# Generate search query based on type, language, and contextual criteria
generate_query() {
    if [[ -n "$QUERY" ]]; then
        echo "$QUERY"
        return
    fi

    local lang_filter="language:$QUERY_LANG"

    # Determine star filter (lower when context is specific)
    local star_filter
    if [[ -n "$MIN_STARS" ]]; then
        star_filter="stars:>$MIN_STARS"
    elif [[ -n "$CONTEXT_CRITERIA" ]]; then
        # Lower threshold for context-aware searches (more specific = fewer results)
        star_filter="stars:>500"
    else
        star_filter="stars:>2000"
    fi

    # Build topic filters - use OR logic via multiple searches if needed
    # For now, take only the FIRST topic to avoid over-restriction
    local topic_filter=""
    if [[ -n "$TOPIC_FILTERS" ]]; then
        # Take first topic only (GitHub AND's all topics which is too restrictive)
        local first_topic
        first_topic=$(echo "$TOPIC_FILTERS" | cut -d',' -f1 | xargs)
        topic_filter="topic:$first_topic"
        log_info "Primary topic filter: $first_topic"
    fi

    # Generate base topic based on type (only if no custom topics)
    if [[ -z "$topic_filter" ]]; then
        case "$QUERY_TYPE" in
            backend)
                topic_filter="topic:api"
                ;;
            frontend)
                topic_filter="topic:frontend"
                star_filter="${star_filter:-stars:>1000}"
                ;;
            fullstack)
                topic_filter="topic:fullstack"
                star_filter="${star_filter:-stars:>500}"
                ;;
            cli)
                topic_filter="topic:cli"
                star_filter="${star_filter:-stars:>500}"
                ;;
            library)
                topic_filter="topic:library"
                star_filter="${star_filter:-stars:>1000}"
                ;;
            *)
                # No default topic for generic type
                ;;
        esac
    fi

    # Add context criteria to the query
    # Strategy: Use context as description search (in:description,readme)
    local context_query=""
    if [[ -n "$CONTEXT_CRITERIA" ]]; then
        # Take first 2-3 keywords for GitHub search
        # GitHub has limits on query complexity
        local keywords
        keywords=$(echo "$CONTEXT_CRITERIA" | tr ',' '\n' | head -2 | tr '\n' ' ' | xargs)
        context_query="$keywords in:description,readme"
        log_info "Context keywords: $keywords"
    fi

    # Build final query - prioritize finding results over precision
    # Order matters: context first, then language, then star filter, topic last
    if [[ -n "$context_query" ]]; then
        QUERY="$context_query $lang_filter $star_filter"
    else
        QUERY="$lang_filter $topic_filter $star_filter"
    fi

    # Clean up extra spaces
    QUERY=$(echo "$QUERY" | tr -s ' ')

    echo "$QUERY"
}

# Search GitHub using gh CLI or API
github_search() {
    local query="$1"
    local output_file="$2"
    # SEC-009: Use mktemp instead of $$ for secure temp files
    local tmp_file
    tmp_file=$(mktemp "${CACHE_DIR}/gh_search_XXXXXX.json")

    log_info "Searching GitHub for: $query"

    # Check if gh CLI is available
    if command -v gh &>/dev/null; then
        log_info "Using gh CLI for search"

        # Set auth token if available
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            export GH_TOKEN="$GITHUB_TOKEN"
        fi

        # Execute search with rate limit handling
        local attempts=0
        local max_attempts=3

        # URL-encode the query
        local encoded_query
        encoded_query=$(printf '%s' "$query" | jq -sRr @uri)
        local api_endpoint="search/repositories?q=${encoded_query}&sort=stars&order=desc&per_page=${MAX_RESULTS}"

        while [[ $attempts -lt $max_attempts ]]; do
            if gh api "$api_endpoint" --jq '.items[] | {owner: .owner.login, name: .name, full_name: .full_name, description: .description, stars: .stargazers_count, forks: .forks_count, open_issues: .open_issues_count, language: .language, updated_at: .updated_at, html_url: .html_url, clone_url: .clone_url}' > "$tmp_file" 2>&1; then
                break
            else
                attempts=$((attempts + 1))
                log_warn "GitHub search attempt $attempts failed"
                if [[ $attempts -lt $max_attempts ]]; then
                    sleep 2
                fi
            fi
        done

        if [[ $attempts -eq $max_attempts ]]; then
            log_error "GitHub search failed after $max_attempts attempts"
            return 1
        fi

    else
        log_warn "gh CLI not found, using curl fallback"

        # Fallback to direct API call
        local encoded_query
        encoded_query=$(echo "$query" | jq -sRr @uri)
        local api_url="https://api.github.com/search/repositories?q=${encoded_query}&sort=stars&per_page=100"

        # Set auth header if token available
        local auth_header=""
        if [[ -n "${GITHUB_TOKEN:-}" ]]; then
            auth_header="Authorization: Bearer $GITHUB_TOKEN"
        fi

        curl -s -H "$auth_header" -H "Accept: application/vnd.github.v3+json" "$api_url" | jq '.items[]' > "$tmp_file" 2>/dev/null || {
            log_error "Failed to fetch from GitHub API"
            return 1
        }
    fi

    # Process and validate results
    if [[ -s "$tmp_file" ]]; then
        # Add metadata and wrap in array using jq -s (slurp)
        # tmp_file contains newline-separated JSON objects from gh api --jq
        jq -s --arg type "$QUERY_TYPE" --arg lang "$QUERY_LANG" --argjson timestamp "$(date +%s)" \
            '[.[] | . + {discovered_type: $type, discovered_lang: $lang, discovered_at: $timestamp, status: "candidate"}]' \
            "$tmp_file" > "$output_file" 2>/dev/null || {
            # Fallback: just wrap raw objects
            jq -s '.' "$tmp_file" > "$output_file"
        }

        # Clean up
        rm -f "$tmp_file"

        local count
        count=$(jq 'length' "$output_file" 2>/dev/null || echo "0")
        log_success "Found $count candidates"
    else
        log_error "No results found"
        rm -f "$tmp_file"
        return 1
    fi
}

# Apply filters to candidates
filter_candidates() {
    local input_file="$1"
    local output_file="$2"

    log_info "Filtering candidates..."

    # Filter by stars, last update, etc.
    jq "[.[] |
        select(.stars >= 100) |
        select(.updated_at | fromdateiso8601 > (now - 31536000)) |  # Last year
        {owner, name, full_name, description, stars, forks, open_issues, language, updated_at, html_url, clone_url, discovered_type, discovered_lang, discovered_at, status}
    ]" "$input_file" > "$output_file"

    local count
    count=$(jq 'length' "$output_file")
    log_success "After filtering: $count candidates"
}

# Main function
main() {
    parse_args "$@"
    load_config

    # Ensure directories exist
    mkdir -p "$CACHE_DIR" "$CANDIDATES_DIR" "$LOGS_DIR"

    # Generate output filename if not provided
    if [[ -z "$OUTPUT_FILE" ]]; then
        local sanitized_type
        sanitized_type=$(echo "$QUERY_TYPE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        local sanitized_lang
        sanitized_lang=$(echo "$QUERY_LANG" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
        OUTPUT_FILE="${CANDIDATES_DIR}/${sanitized_type}_${sanitized_lang}_$(date +%Y%m%d_%H%M%S).json"
    fi

    local query
    query=$(generate_query)

    # SEC-009: Use mktemp instead of $$ for secure temp files
    local tmp_candidates
    tmp_candidates=$(mktemp "${CACHE_DIR}/candidates_raw_XXXXXX.json")

    # Run discovery
    if github_search "$query" "$tmp_candidates"; then
        filter_candidates "$tmp_candidates" "$OUTPUT_FILE"
        rm -f "$tmp_candidates"

        log_success "Discovery complete. Results saved to: $OUTPUT_FILE"

        # Output summary to stderr (keeping stdout clean)
        local count
        count=$(jq 'length' "$OUTPUT_FILE")
        {
            echo ""
            echo "=== Discovery Summary ==="
            echo "Type: $QUERY_TYPE"
            echo "Language: $QUERY_LANG"
            echo "Query: $query"
            echo "Candidates found: $count"
            echo "Output file: $OUTPUT_FILE"
            echo "========================"
        } >&2
    else
        rm -f "$tmp_candidates"
        log_error "Discovery failed"
        exit 1
    fi
}

# Run main
main "$@"
