#!/bin/bash
# Domain Backfill Script v2.88.0
# Backfills domain categories for existing uncategorized rules
#
# GAP-C02 FIX: Categorizes existing rules that have category="all" or undefined domain
# Uses same domain detection logic as curator-learn.sh
#
# Usage: backfill-domains.sh [--dry-run] [--batch-size N]
#
# VERSION: 2.88.0

set -euo pipefail
umask 077

# Configuration
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
BACKUP_DIR="${HOME}/.ralph/procedural/backups"
LOG_DIR="${HOME}/.ralph/logs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# GAP-C02: Domain detection keywords (portable - no associative arrays)
# Format: domain|keyword1|keyword2|keyword3...
DOMAIN_PATTERNS="
backend|api|server|rest|graphql|microservice|endpoint|controller|service|repository|middleware|express|fastapi|django|nestjs|spring
frontend|react|vue|angular|component|hook|state|css|styled|jsx|tsx|dom|render|props|context|redux
database|sql|query|schema|migration|orm|prisma|sequelize|typeorm|knex|postgres|mysql|mongodb|redis|index|transaction
security|auth|jwt|token|encrypt|decrypt|hash|password|csrf|xss|injection|sanitize|validate|permission|role|rbac
testing|test|spec|jest|vitest|mocha|cypress|playwright|mock|stub|assert|coverage|unit|integration|e2e
devops|docker|kubernetes|ci|cd|pipeline|deploy|container|helm|terraform|ansible|jenkins|github|actions
hooks|hook|lifecycle|callback|trigger|event|listener|interceptor|pre|post|init|destroy
general|config|util|helper|common|shared|lib|types|interface|enum|constant
"

# Detect domain from rule content (portable version)
detect_domain_from_rule() {
    local rule_json="$1"
    local detected_domain="general"
    local max_matches=0

    # Extract text content from rule
    local content=""
    content+=$(echo "$rule_json" | jq -r '.name // ""' 2>/dev/null || echo "")
    content+=" "
    content+=$(echo "$rule_json" | jq -r '.behavior // ""' 2>/dev/null || echo "")
    content+=" "
    content+=$(echo "$rule_json" | jq -r '.trigger // ""' 2>/dev/null || echo "")
    content+=" "
    content+=$(echo "$rule_json" | jq -r '.category // ""' 2>/dev/null || echo "")
    content+=" "
    content+=$(echo "$rule_json" | jq -r '.source_file // ""' 2>/dev/null || echo "")

    # Convert to lowercase for matching
    content=$(echo "$content" | tr '[:upper:]' '[:lower:]')

    # Count keyword matches for each domain
    while IFS='|' read -r domain keywords; do
        [[ -z "$domain" || -z "$keywords" ]] && continue

        local matches=0
        for kw in ${keywords//|/ }; do
            local count=$(echo "$content" | grep -o "\b$kw\b" 2>/dev/null | wc -l | tr -d ' ')
            matches=$((matches + count))
        done

        if [[ $matches -gt $max_matches ]]; then
            max_matches=$matches
            detected_domain="$domain"
        fi
    done <<< "$DOMAIN_PATTERNS"

    echo "$detected_domain"
}

# Parse arguments
DRY_RUN=false
BATCH_SIZE=100

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=true; shift ;;
        --batch-size) BATCH_SIZE="$2"; shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

show_help() {
    cat << EOF
Domain Backfill Script v2.88.0

GAP-C02 FIX: Categorizes existing uncategorized rules

Usage: $(basename "$0") [OPTIONS]

Options:
  --dry-run         Show what would be changed without modifying
  --batch-size N    Process N rules at a time (default: 100)
  --help, -h        Show this help

Examples:
  $(basename "$0") --dry-run
  $(basename "$0") --batch-size 50
EOF
}

# Main
main() {
    mkdir -p "$BACKUP_DIR" "$LOG_DIR"

    echo ""
    echo "========================================"
    echo -e "      ${BLUE}Domain Backfill v2.88${NC}"
    echo "========================================"

    if [[ ! -f "$RULES_FILE" ]]; then
        log_error "Rules file not found: $RULES_FILE"
        exit 1
    fi

    # Count rules needing backfill
    local total_rules=$(jq -r '.rules | length // 0' "$RULES_FILE" 2>/dev/null || echo "0")
    local uncategorized=$(jq -r '[.rules[] | select(.domain == null or .domain == "" or .domain == "all" or .category == "all")] | length' "$RULES_FILE" 2>/dev/null || echo "0")

    log_info "Total rules: $total_rules"
    log_info "Rules needing backfill: $uncategorized"

    if [[ "$uncategorized" -eq 0 ]]; then
        log_success "All rules already have domain categories!"
        exit 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_warn "DRY RUN - No changes will be made"
    fi

    # Create backup
    local backup_file="${BACKUP_DIR}/rules.json.backup.$(date +%Y%m%d_%H%M%S)"
    if [[ "$DRY_RUN" != "true" ]]; then
        cp "$RULES_FILE" "$backup_file"
        log_info "Backup created: $backup_file"
    fi

    # Process rules
    local processed=0
    local updated=0

    # Get indices of rules needing backfill
    local indices=$(jq -r '[.rules | to_entries[] | select(.value.domain == null or .value.domain == "" or .value.domain == "all" or .value.category == "all") | .key] | @tsv' "$RULES_FILE" 2>/dev/null)

    for idx in $indices; do
        [[ -z "$idx" ]] && continue

        local rule=$(jq -r ".rules[$idx]" "$RULES_FILE" 2>/dev/null)
        [[ -z "$rule" || "$rule" == "null" ]] && continue

        local detected_domain=$(detect_domain_from_rule "$rule")
        local current_domain=$(echo "$rule" | jq -r '.domain // "null"')

        if [[ "$detected_domain" != "$current_domain" ]]; then
            local rule_name=$(echo "$rule" | jq -r '.name // .rule_id // "unnamed"')

            if [[ "$DRY_RUN" == "true" ]]; then
                echo "  Rule $idx: '$rule_name' -> domain: $detected_domain"
            else
                # Update the rule
                local temp_file=$(mktemp)
                jq --arg idx "$idx" --arg domain "$detected_domain" \
                    ".rules[$idx].domain = \$domain | .rules[$idx].category = \$domain" \
                    "$RULES_FILE" > "$temp_file" 2>/dev/null && mv "$temp_file" "$RULES_FILE" || rm -f "$temp_file"
            fi
            updated=$((updated + 1))
        fi

        processed=$((processed + 1))

        # Progress indicator
        if [[ $((processed % 100)) -eq 0 ]]; then
            log_info "Processed $processed/$uncategorized rules..."
        fi
    done

    echo ""
    echo "========================================"
    echo -e "      ${GREEN}Backfill Complete${NC}"
    echo "========================================"
    echo "  Total processed: $processed"
    echo "  Rules updated: $updated"
    echo "  Dry run: $DRY_RUN"

    if [[ "$DRY_RUN" != "true" && "$updated" -gt 0 ]]; then
        echo ""
        echo "  Backup: $backup_file"

        # Show domain distribution after backfill
        echo ""
        log_info "New domain distribution:"
        jq -r '.rules | group_by(.domain) | .[] | "\(.[0].domain // "undefined"): \(length)"' "$RULES_FILE" 2>/dev/null | sort -t: -k2 -nr | head -10
    fi

    echo "========================================"
}

main
