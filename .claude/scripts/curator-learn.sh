#!/bin/bash
# Repo Curator Learn Script v2.55.0
# Executes learning on approved repositories and updates procedural memory
#
# Usage: curator-learn.sh [--type <type>] [--lang <lang>] [--repo <repo>] [--all]

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CORPUS_DIR="${CURATOR_DIR}/corpus"
APPROVED_DIR="${CORPUS_DIR}/approved"
PROCEDURAL_FILE="${HOME}/.ralph/procedural/rules.json"
PROCEDURAL_BACKUP="${HOME}/.ralph/procedural/rules.json.backup.$(date +%Y%m%d_%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions - v2.55: Moved BEFORE validate_input() which uses log_error
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# SEC-010: Validation patterns
readonly VALID_INPUT_PATTERN='^[a-zA-Z0-9_-]+$'
readonly VALID_REPO_PATTERN='^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$'

# SEC-010: Validate input against pattern
validate_input() {
    local value="$1"
    local name="$2"
    local pattern="${3:-$VALID_INPUT_PATTERN}"
    if [[ ! "$value" =~ $pattern ]]; then
        log_error "Invalid $name: contains disallowed characters"
        exit 1
    fi
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                FILTER_TYPE="$2"
                # SEC-010: Validate type input
                validate_input "$FILTER_TYPE" "type"
                shift 2
                ;;
            --lang)
                FILTER_LANG="$2"
                # SEC-010: Validate lang input
                validate_input "$FILTER_LANG" "lang"
                shift 2
                ;;
            --repo)
                TARGET_REPO="$2"
                # SEC-010: Validate repo format
                validate_input "$TARGET_REPO" "repo" "$VALID_REPO_PATTERN"
                shift 2
                ;;
            --all)
                LEARN_ALL=true
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
Repo Curator Learn Script v2.55.0

Usage: $(basename "$0") [OPTIONS]

Options:
  --type <type>   Filter by type (backend, frontend, etc.)
  --lang <lang>   Filter by language
  --repo <repo>   Learn specific repository (owner/repo)
  --all           Learn all approved repositories
  --help, -h      Show this help

Examples:
  $(basename "$0") --type backend --lang typescript
  $(basename "$0") --repo nestjs/nest
  $(basename "$0") --all
EOF
}

# Get repository info
get_repo_info() {
    local dir="$1"
    local manifest="${dir}/manifest.json"

    if [[ -f "$manifest" ]]; then
        jq -r '.repository // "unknown"' "$manifest"
    else
        basename "$dir"
    fi
}

# Extract source name from repo
get_source_name() {
    local repo="$1"
    # Extract meaningful source name (e.g., "nestjs" from "nestjs/nest")
    echo "$repo" | cut -d'/' -f1
}

# Run pattern extraction on repository
extract_patterns() {
    local repo_dir="$1"
    local source_repo="$2"

    log_info "Extracting patterns from: $source_repo"

    # Use pattern-extractor.py if available
    local extractor="${HOME}/.claude/scripts/pattern-extractor.py"

    if [[ -f "$extractor" ]]; then
        # SEC-009: Use mktemp for secure temp files
        local output_file
        output_file=$(mktemp "${CURATOR_DIR}/.tmp_patterns_XXXXXX.json")
        python3 "$extractor" --input "$repo_dir" --output "$output_file" --source "$source_repo" 2>/dev/null || {
            log_warn "Pattern extraction failed for $source_repo"
            return 1
        }
        echo "$output_file"
    else
        log_warn "Pattern extractor not found, using basic extraction"
        echo ""
    fi
}

# Update procedural memory with new rules
update_procedural_memory() {
    local patterns_file="$1"
    local source_repo="$2"

    log_info "Updating procedural memory with rules from: $source_repo"

    # Backup current rules
    cp "$PROCEDURAL_FILE" "$PROCEDURAL_BACKUP" 2>/dev/null || true

    if [[ -s "$patterns_file" && -f "$patterns_file" ]]; then
        # Read new patterns
        local new_rules
        new_rules=$(cat "$patterns_file")

        # Read current rules
        local current_rules
        current_rules=$(cat "$PROCEDURAL_FILE")

        # Merge rules
        local merged
        merged=$(jq -s \
            --argjson current "$current_rules" \
            --argjson new "$new_rules" \
            '$current * {rules: ($current.rules + $new.rules | unique_by(.rule_id))}' \
            "$PROCEDURAL_FILE" 2>/dev/null || echo "$current_rules")

        # Update file
        echo "$merged" | jq '.' > "$PROCEDURAL_FILE"

        local rule_count
        rule_count=$(echo "$new_rules" | jq '. | length' 2>/dev/null || echo "0")
        log_success "Added $rule_count rules from $source_repo"
    else
        # Create a basic rule from repository metadata
        local source_name
        source_name=$(get_source_name "$source_repo")

        local timestamp
        timestamp=$(date -Iseconds)

        local new_rule=$(
            jq -n \
                --arg id "repo-${source_name}-$(date +%s)" \
                --arg source "$source_repo" \
                --arg trigger "$source_name" \
                --arg behavior "Pattern learned from $source_repo" \
                --argjson conf 0.8 \
                --argjson ts "$(date +%s)" \
                '{
                    rule_id: $id,
                    source_repo: $source,
                    trigger: $trigger,
                    behavior: $behavior,
                    confidence: $conf,
                    source_episodes: [],
                    created_at: $ts
                }'
        )

        jq --argjson rule "$new_rule" '.rules += [$rule]' "$PROCEDURAL_FILE" > "${PROCEDURAL_FILE}.tmp" && mv "${PROCEDURAL_FILE}.tmp" "$PROCEDURAL_FILE"
        log_success "Added basic rule from $source_repo"
    fi
}

# Learn from a single repository
learn_repo() {
    local repo_dir="$1"

    local repo
    repo=$(get_repo_info "$repo_dir")

    if [[ -z "$repo" || "$repo" == "unknown" ]]; then
        log_warn "Skipping repository with unknown name: $repo_dir"
        return 1
    fi

    log_info "Learning from: $repo"

    # Extract patterns
    local patterns_file
    patterns_file=$(extract_patterns "$repo_dir" "$repo")

    # Update procedural memory
    if [[ -n "$patterns_file" && -s "$patterns_file" ]]; then
        update_procedural_memory "$patterns_file" "$repo"
    else
        update_procedural_memory "" "$repo"
    fi

    # Update manifest to mark as learned
    local manifest="${repo_dir}/manifest.json"
    if [[ -f "$manifest" ]]; then
        jq --argjson timestamp "$(date +%s)" '.learned_at = $timestamp' "$manifest" > "${manifest}.tmp" && mv "${manifest}.tmp" "$manifest"
    fi

    log_success "Completed learning from: $repo"
}

# Main function
main() {
    local FILTER_TYPE=""
    local FILTER_LANG=""
    local TARGET_REPO=""
    local LEARN_ALL=false

    parse_args "$@"

    # Ensure directories exist
    mkdir -p "$APPROVED_DIR"

    if [[ ! -d "$APPROVED_DIR" ]]; then
        log_warn "No approved repositories to learn from"
        exit 0
    fi

    echo ""
    echo "========================================"
    echo -e "      ${BLUE}Repo Curator Learn${NC}"
    echo "========================================"

    local learned_count=0
    local failed_count=0

    if [[ -n "$TARGET_REPO" ]]; then
        # Learn specific repository
        local sanitized
        sanitized=$(echo "$TARGET_REPO" | tr '/' '_' | tr '[:upper:]' '[:lower:]')
        local repo_dir="${APPROVED_DIR}/${sanitized}"*

        if [[ -d "$repo_dir" ]]; then
            learn_repo "$repo_dir"
            learned_count=$((learned_count + 1))
        else
            log_error "Approved repository not found: $TARGET_REPO"
            exit 1
        fi
    elif [[ "$LEARN_ALL" == "true" ]]; then
        # Learn all approved repositories
        for repo_dir in "${APPROVED_DIR}"*/; do
            [[ -d "$repo_dir" ]] || continue
            if learn_repo "$repo_dir"; then
                learned_count=$((learned_count + 1))
            else
                failed_count=$((failed_count + 1))
            fi
        done
    else
        log_error "Specify --repo or --all"
        show_help
        exit 1
    fi

    echo ""
    echo "========================================"
    echo -e "      ${GREEN}Learning Complete${NC}"
    echo "========================================"
    echo "  Learned: $learned_count repositories"
    echo "  Failed: $failed_count"
    echo ""
    echo "  Procedural memory updated: $PROCEDURAL_FILE"
    echo "========================================"
}

main "$@"
