#!/bin/bash
# Repo Curator Learn Script v2.88.0
# Executes learning on approved repositories and updates procedural memory
#
# GAP FIXES:
# - GAP-C01: Now populates manifest files[] with processed files
# - GAP-C02: Now detects and assigns domain to extracted rules
# - Pattern extraction works without external Python script
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

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# SEC-010: Validation patterns
readonly VALID_INPUT_PATTERN='^[a-zA-Z0-9_-]+$'
readonly VALID_REPO_PATTERN='^[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+$'

# GAP-C02 FIX: Domain detection keywords
declare -A DOMAIN_KEYWORDS
DOMAIN_KEYWORDS["backend"]="api|server|rest|graphql|microservice|endpoint|controller|service|repository|middleware|express|fastapi|django|nestjs|spring"
DOMAIN_KEYWORDS["frontend"]="react|vue|angular|component|hook|state|css|styled|jsx|tsx|dom|render|props|context|redux"
DOMAIN_KEYWORDS["database"]="sql|query|schema|migration|orm|prisma|sequelize|typeorm|knex|postgres|mysql|mongodb|redis|index|transaction"
DOMAIN_KEYWORDS["security"]="auth|jwt|token|encrypt|decrypt|hash|password|csrf|xss|injection|sanitize|validate|permission|role|rbac"
DOMAIN_KEYWORDS["testing"]="test|spec|jest|vitest|mocha|cypress|playwright|mock|stub|assert|coverage|unit|integration|e2e"
DOMAIN_KEYWORDS["devops"]="docker|kubernetes|ci|cd|pipeline|deploy|container|helm|terraform|ansible|jenkins|github.actions|gitlab.ci"
DOMAIN_KEYWORDS["hooks"]="hook|lifecycle|callback|trigger|event|listener|middleware|interceptor|pre|post|init|destroy"
DOMAIN_KEYWORDS["general"]="config|util|helper|common|shared|lib|types|interface|enum|constant"

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

# GAP-C02 FIX: Detect domain from repository content
detect_domain() {
    local repo_dir="$1"
    local detected_domain="general"
    local max_matches=0

    # Get all source files content (limited sample)
    local sample_content=""
    if [[ -d "$repo_dir/src" ]]; then
        sample_content=$(find "$repo_dir/src" -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" 2>/dev/null | head -20 | xargs cat 2>/dev/null | tr '[:upper:]' '[:lower:]' | head -c 50000)
    fi

    # Also check root files
    sample_content+=" $(cat "$repo_dir"/*.md "$repo_dir"/package.json "$repo_dir"/README.md 2>/dev/null | tr '[:upper:]' '[:lower:]' | head -c 10000)"

    # Count keyword matches for each domain
    for domain in "${!DOMAIN_KEYWORDS[@]}"; do
        local keywords="${DOMAIN_KEYWORDS[$domain]}"
        local matches=0

        IFS='|' read -ra KW_ARRAY <<< "$keywords"
        for kw in "${KW_ARRAY[@]}"; do
            local count=$(echo "$sample_content" | grep -o "$kw" | wc -l | tr -d ' ')
            matches=$((matches + count))
        done

        if [[ $matches -gt $max_matches ]]; then
            max_matches=$matches
            detected_domain="$domain"
        fi
    done

    echo "$detected_domain"
}

# GAP-C02 FIX: Detect language from repository
detect_language() {
    local repo_dir="$1"

    if [[ -f "$repo_dir/package.json" ]]; then
        if [[ -f "$repo_dir/tsconfig.json" ]]; then
            echo "typescript"
        else
            echo "javascript"
        fi
    elif [[ -f "$repo_dir/requirements.txt" ]] || [[ -f "$repo_dir/pyproject.toml" ]] || [[ -f "$repo_dir/setup.py" ]]; then
        echo "python"
    elif [[ -f "$repo_dir/go.mod" ]]; then
        echo "go"
    elif [[ -f "$repo_dir/Cargo.toml" ]]; then
        echo "rust"
    elif [[ -f "$repo_dir/pom.xml" ]] || [[ -f "$repo_dir/build.gradle" ]]; then
        echo "java"
    else
        echo "unknown"
    fi
}

# GAP-C01 FIX: Extract patterns from repository files
extract_patterns_from_files() {
    local repo_dir="$1"
    local source_repo="$2"
    local domain="$3"
    local language="$4"

    log_info "Extracting patterns from: $source_repo (domain: $domain, lang: $language)"

    local patterns="[]"
    local processed_files="[]"
    local rule_count=0

    # Find relevant source files
    local find_pattern=""
    case "$language" in
        typescript|javascript) find_pattern="\( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \)" ;;
        python) find_pattern="-name '*.py'" ;;
        go) find_pattern="-name '*.go'" ;;
        rust) find_pattern="\( -name '*.rs' -o -name 'Cargo.toml' \)" ;;
        java) find_pattern="\( -name '*.java' -o -name 'pom.xml' -o -name 'build.gradle' \)" ;;
        *) find_pattern="\( -name '*.ts' -o -name '*.js' -o -name '*.py' -o -name '*.go' \)" ;;
    esac

    # Process source files
    local files_processed=0
    while IFS= read -r -d '' file; do
        [[ -f "$file" ]] || continue
        [[ -s "$file" ]] || continue

        local rel_path="${file#$repo_dir/}"
        local filename=$(basename "$file")

        # Skip test files, config files, and generated files
        [[ "$rel_path" =~ node_modules ]] && continue
        [[ "$rel_path" =~ \.test\. ]] && continue
        [[ "$rel_path" =~ \.spec\. ]] && continue
        [[ "$rel_path" =~ \.config\. ]] && continue
        [[ "$filename" =~ ^_ ]] && continue

        # Extract patterns from file
        local content=$(cat "$file" 2>/dev/null | head -200)

        # Pattern: Function/method definitions
        local functions=$(echo "$content" | grep -oE '(function|def|func|fn|public|private|protected)\s+[a-zA-Z_][a-zA-Z0-9_]*' | head -5)

        # Pattern: Class definitions
        local classes=$(echo "$content" | grep -oE '(class|interface|type)\s+[a-zA-Z_][a-zA-Z0-9_]*' | head -3)

        # Pattern: Import patterns
        local imports=$(echo "$content" | grep -oE '(import|from|require|use)\s+[a-zA-Z_./]+' | head -5)

        # Create rule if we found patterns
        if [[ -n "$functions" ]] || [[ -n "$classes" ]]; then
            local timestamp=$(date +%s)
            local rule_id="rule-${domain}-${timestamp}-${RANDOM}"

            local behavior=""
            [[ -n "$classes" ]] && behavior+="Classes: $(echo "$classes" | tr '\n' ', ' | sed 's/,$//'). "
            [[ -n "$functions" ]] && behavior+="Functions: $(echo "$functions" | tr '\n' ', ' | sed 's/,$//')."

            local new_rule=$(jq -n \
                --arg id "$rule_id" \
                --arg domain "$domain" \
                --arg category "$domain" \
                --arg source "$source_repo" \
                --arg file "$rel_path" \
                --arg behavior "$behavior" \
                --argjson confidence 0.75 \
                --argjson ts "$timestamp" \
                '{
                    rule_id: $id,
                    domain: $domain,
                    category: $category,
                    source_repo: $source,
                    source_file: $file,
                    trigger: $domain,
                    behavior: $behavior,
                    confidence: $confidence,
                    source_episodes: [],
                    created_at: $ts,
                    applied_count: 0
                }')

            patterns=$(echo "$patterns" | jq --argjson rule "$new_rule" '. += [$rule]')
            rule_count=$((rule_count + 1))
        fi

        # Add to processed files
        processed_files=$(echo "$processed_files" | jq --arg path "$rel_path" '. += [$path]')
        files_processed=$((files_processed + 1))

        # Limit to prevent excessive processing
        [[ $files_processed -ge 50 ]] && break

    done < <(eval "find '$repo_dir' -type f $find_pattern -print0 2>/dev/null | head -50")

    # Return JSON with both patterns and processed files
    jq -n \
        --argjson patterns "$patterns" \
        --argjson files "$processed_files" \
        --argjson count "$rule_count" \
        '{patterns: $patterns, files: $files, count: $count}'
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type) FILTER_TYPE="$2"; validate_input "$FILTER_TYPE" "type"; shift 2 ;;
            --lang) FILTER_LANG="$2"; validate_input "$FILTER_LANG" "lang"; shift 2 ;;
            --repo) TARGET_REPO="$2"; validate_input "$TARGET_REPO" "repo" "$VALID_REPO_PATTERN"; shift 2 ;;
            --all) LEARN_ALL=true; shift ;;
            --help|-h) show_help; exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done
}

show_help() {
    cat << EOF
Repo Curator Learn Script v2.88.0

GAP FIXES:
- GAP-C01: Manifest files[] now populated
- GAP-C02: Domain detection and assignment

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

# Update procedural memory with new rules
update_procedural_memory() {
    local extraction_result="$1"
    local source_repo="$2"
    local domain="$3"

    log_info "Updating procedural memory with rules from: $source_repo"

    # Backup current rules
    cp "$PROCEDURAL_FILE" "$PROCEDURAL_BACKUP" 2>/dev/null || true

    local patterns=$(echo "$extraction_result" | jq '.patterns')
    local rule_count=$(echo "$extraction_result" | jq '.count')

    if [[ "$rule_count" -gt 0 ]]; then
        # Merge rules
        local current_rules=$(cat "$PROCEDURAL_FILE" 2>/dev/null || echo '{"rules":[]}')

        local merged=$(jq -s \
            --argjson current "$current_rules" \
            --argjson new "$patterns" \
            '$current * {rules: ($current.rules + $new | unique_by(.rule_id))}' \
            <<< "$current_rules" 2>/dev/null || echo "$current_rules")

        echo "$merged" | jq '.' > "$PROCEDURAL_FILE"
        log_success "Added $rule_count rules from $source_repo (domain: $domain)"
    else
        log_warn "No patterns extracted from $source_repo"
    fi

    echo "$rule_count"
}

# GAP-C01 FIX: Update manifest with processed files
update_manifest() {
    local manifest="$1"
    local extraction_result="$2"
    local domain="$3"
    local language="$4"

    if [[ -f "$manifest" ]]; then
        local processed_files=$(echo "$extraction_result" | jq '.files')
        local rule_count=$(echo "$extraction_result" | jq '.count')

        jq \
            --argjson timestamp "$(date +%s)" \
            --arg domain "$domain" \
            --arg language "$language" \
            --argjson files "$processed_files" \
            --argjson patterns "$rule_count" \
            '.learned_at = $timestamp |
             .detected_domain = $domain |
             .detected_language = $language |
             .files = $files |
             .patterns_extracted = $patterns' \
            "$manifest" > "${manifest}.tmp" && mv "${manifest}.tmp" "$manifest"

        log_success "Updated manifest with $(echo "$processed_files" | jq 'length') files"
    fi
}

# Learn from a single repository
learn_repo() {
    local repo_dir="$1"

    local repo=$(get_repo_info "$repo_dir")

    if [[ -z "$repo" || "$repo" == "unknown" ]]; then
        log_warn "Skipping repository with unknown name: $repo_dir"
        return 1
    fi

    log_info "Learning from: $repo"

    # GAP-C02 FIX: Detect domain and language
    local domain=$(detect_domain "$repo_dir")
    local language=$(detect_language "$repo_dir")

    log_info "Detected: domain=$domain, language=$language"

    # GAP-C01 FIX: Extract patterns with file tracking
    local extraction_result=$(extract_patterns_from_files "$repo_dir" "$repo" "$domain" "$language")

    # Update procedural memory
    local rule_count=$(update_procedural_memory "$extraction_result" "$repo" "$domain")

    # GAP-C01 FIX: Update manifest with processed files
    local manifest="${repo_dir}/manifest.json"
    update_manifest "$manifest" "$extraction_result" "$domain" "$language"

    log_success "Completed learning from: $repo ($rule_count rules)"
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
    echo -e "      ${BLUE}Repo Curator Learn v2.88${NC}"
    echo "========================================"

    local learned_count=0
    local failed_count=0
    local total_rules=0

    if [[ -n "$TARGET_REPO" ]]; then
        local sanitized=$(echo "$TARGET_REPO" | tr '/' '_' | tr '[:upper:]' '[:lower:]')
        local repo_dir="${APPROVED_DIR}/${sanitized}"*

        if [[ -d "$repo_dir" ]]; then
            learn_repo "$repo_dir" && learned_count=$((learned_count + 1)) || failed_count=$((failed_count + 1))
        else
            log_error "Approved repository not found: $TARGET_REPO"
            exit 1
        fi
    elif [[ "$LEARN_ALL" == "true" ]]; then
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
    echo "  Procedural memory: $PROCEDURAL_FILE"
    echo "  Backup: $PROCEDURAL_BACKUP"
    echo ""
    echo "  GAP FIXES Applied:"
    echo "    - GAP-C01: Manifest files[] populated"
    echo "    - GAP-C02: Domain detection enabled"
    echo "========================================"
}

main "$@"
