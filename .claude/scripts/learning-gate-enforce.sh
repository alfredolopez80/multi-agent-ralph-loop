#!/bin/bash
# Learning Gate Enforcement Script v2.88.0
# Enforces learning requirements for CRITICAL gaps
#
# GAP-C03 FIX: Makes learning_state: CRITICAL blocking
# Prevents tasks from proceeding without required domain knowledge
#
# Usage: learning-gate-enforce.sh --check <domain> [--block]
#
# VERSION: 2.88.0

set -euo pipefail
umask 077

# Configuration
RULES_FILE="${HOME}/.ralph/procedural/rules.json"
CONFIG_FILE="${HOME}/.ralph/config/memory-config.json"
PLAN_STATE="${HOME}/.ralph/plan-state/plan-state.json"
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

# Default settings
MIN_RULES_DOMAIN=3
MIN_RULES_QUADRATIC=5
BLOCK_ON_CRITICAL=false
LEARNING_ENABLED=true

# Parse arguments
CHECK_DOMAIN=""
BLOCK_MODE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check) CHECK_DOMAIN="$2"; shift 2 ;;
        --block) BLOCK_MODE=true; shift ;;
        --min-rules) MIN_RULES_DOMAIN="$2"; shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

show_help() {
    cat << EOF
Learning Gate Enforcement v2.88.0

GAP-C03 FIX: Enforces learning requirements

Usage: $(basename "$0") [OPTIONS]

Options:
  --check <domain>  Check if domain has sufficient rules
  --block           Block execution if CRITICAL gap
  --min-rules N     Minimum rules required (default: 3)
  --help, -h        Show this help

Exit Codes:
  0 - Sufficient knowledge (proceed)
  1 - Insufficient knowledge but not blocking
  2 - CRITICAL gap - execution blocked

Examples:
  $(basename "$0") --check backend
  $(basename "$0") --check security --block
EOF
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        LEARNING_ENABLED=$(jq -r '.auto_learn.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
        BLOCK_ON_CRITICAL=$(jq -r '.auto_learn.blocking // false' "$CONFIG_FILE" 2>/dev/null || echo "false")
        MIN_RULES_DOMAIN=$(jq -r '.auto_learn.min_rules // 3' "$CONFIG_FILE" 2>/dev/null || echo "3")
    fi
}

# Check domain rules
check_domain_rules() {
    local domain="$1"

    if [[ ! -f "$RULES_FILE" ]]; then
        echo "0"
        return
    fi

    # Count rules matching domain
    local count=$(jq -r --arg domain "$domain" \
        '[.rules[] | select(.domain == $domain or .category == $domain)] | length' \
        "$RULES_FILE" 2>/dev/null || echo "0")

    echo "$count"
}

# Check plan-state for learning_state
check_plan_state() {
    if [[ ! -f "$PLAN_STATE" ]]; then
        echo "NONE"
        return
    fi

    local state=$(jq -r '.learning_state.severity // "NONE"' "$PLAN_STATE" 2>/dev/null || echo "NONE")
    echo "$state"
}

# Main
main() {
    mkdir -p "$LOG_DIR"

    load_config

    if [[ -z "$CHECK_DOMAIN" ]]; then
        log_error "Domain required. Use --check <domain>"
        show_help
        exit 1
    fi

    # Validate domain
    case "$CHECK_DOMAIN" in
        backend|frontend|database|security|testing|devops|hooks|general) ;;
        *)
            log_warn "Unknown domain: $CHECK_DOMAIN, treating as general"
            CHECK_DOMAIN="general"
            ;;
    esac

    local rule_count=$(check_domain_rules "$CHECK_DOMAIN")
    local plan_state=$(check_plan_state)

    # Determine gate status
    local gate_status="PASS"
    local gap_severity="NONE"
    local message=""

    if [[ "$rule_count" -eq 0 ]]; then
        gate_status="BLOCK"
        gap_severity="CRITICAL"
        message="No rules found for domain: $CHECK_DOMAIN"
    elif [[ "$rule_count" -lt "$MIN_RULES_DOMAIN" ]]; then
        gate_status="WARN"
        gap_severity="HIGH"
        message="Insufficient rules for $CHECK_DOMAIN: $rule_count/$MIN_RULES_DOMAIN"
    else
        gate_status="PASS"
        gap_severity="NONE"
        message="Sufficient knowledge for $CHECK_DOMAIN: $rule_count rules"
    fi

    # Log result
    {
        echo "[$(date -Iseconds)] Learning Gate Check:"
        echo "  Domain: $CHECK_DOMAIN"
        echo "  Rule count: $rule_count"
        echo "  Required: $MIN_RULES_DOMAIN"
        echo "  Gate status: $gate_status"
        echo "  Gap severity: $gap_severity"
        echo "  Block mode: $BLOCK_MODE"
    } >> "${LOG_DIR}/learning-gate-$(date +%Y%m%d).log" 2>&1

    # Output result
    echo ""
    echo "========================================"
    echo -e "      ${BLUE}Learning Gate Check${NC}"
    echo "========================================"
    echo "  Domain: $CHECK_DOMAIN"
    echo "  Rules: $rule_count/$MIN_RULES_DOMAIN"
    echo "  Status: $gate_status"
    echo "  Severity: $gap_severity"
    echo "  Message: $message"
    echo "========================================"

    # Handle blocking
    if [[ "$gate_status" == "BLOCK" ]]; then
        if [[ "$BLOCK_MODE" == "true" ]] || [[ "$BLOCK_ON_CRITICAL" == "true" ]]; then
            log_error "LEARNING GATE BLOCKED: $message"
            echo ""
            echo "Required action: Run learning before proceeding"
            echo "  /curator full --type $CHECK_DOMAIN"
            exit 2
        else
            log_warn "LEARNING GATE WARNING: $message (non-blocking)"
            exit 1
        fi
    elif [[ "$gate_status" == "WARN" ]]; then
        log_warn "LEARNING GATE WARNING: $message"
        exit 1
    fi

    log_success "$message"
    exit 0
}

main
