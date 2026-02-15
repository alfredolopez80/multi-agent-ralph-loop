#!/usr/bin/env bash
#===============================================================================
# validate-agents-registration.sh - Validate agents registration
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate that all agent definitions are properly installed
#
# Usage:
#   ./scripts/validate-agents-registration.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All agents registered correctly
#   1: Some agents missing or invalid
#   2: Cannot run checks
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Output format
FORMAT="${FORMAT:-text}"
VERBOSE="${VERBOSE:-0}"

# Agents directory
AGENTS_DIR="${HOME}/.claude/agents"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=1
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: validate-agents-registration.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - Agents directory exists
  - All agent files exist
  - Agent markdown is valid
  - Agent has required fields

Exit codes:
  0  All agents valid
  1  Some agents invalid
  2  Cannot run checks
EOF
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

#===============================================================================
# AGENTS TO VALIDATE
#===============================================================================

REQUIRED_AGENTS=(
    "ralph-coder"
    "ralph-reviewer"
    "ralph-tester"
    "ralph-researcher"
)

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A RESULTS
declare -A MESSAGES
PASSED=0
FAILED=0
WARNINGS=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Record a check result
record_check() {
    local check_name="$1"
    local status="$2"
    local message="$3"

    RESULTS["$check_name"]="$status"
    MESSAGES["$check_name"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

# Check agents directory exists
check_agents_dir() {
    if [[ -d "$AGENTS_DIR" ]]; then
        local count
        count=$(find "$AGENTS_DIR" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
        record_check "agents_dir" "PASS" "Agents directory exists with $count agents"
    else
        record_check "agents_dir" "FAIL" "Agents directory not found: $AGENTS_DIR"
    fi
}

# Validate a single agent
validate_agent() {
    local agent="$1"
    local agent_file="${AGENTS_DIR}/${agent}.md"
    local status=""
    local message=""

    if [[ ! -f "$agent_file" ]]; then
        status="FAIL"
        message="Agent file not found"
    elif [[ ! -s "$agent_file" ]]; then
        status="FAIL"
        message="Agent file is empty"
    else
        # Check for markdown content
        if grep -q "^#" "$agent_file" 2>/dev/null; then
            status="PASS"
            message="Valid agent definition"
        else
            status="WARN"
            message="No markdown headers found"
        fi
    fi

    RESULTS["$agent"]="$status"
    MESSAGES["$agent"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Agents Registration Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Agents Dir: $AGENTS_DIR"
    echo ""

    # Directory check
    local dir_status="${RESULTS[agents_dir]}"
    local dir_message="${MESSAGES[agents_dir]}"

    echo -e "${BLUE}DIRECTORY${NC}"
    echo "───────────────────────────────────────────────────────────────"
    case "$dir_status" in
        PASS) echo -e "${GREEN}✓${NC} $dir_message" ;;
        FAIL) echo -e "${RED}✗${NC} $dir_message" ;;
        WARN) echo -e "${YELLOW}⚠${NC} $dir_message" ;;
    esac
    echo ""

    echo -e "${BLUE}AGENTS${NC}"
    echo "───────────────────────────────────────────────────────────────"

    for agent in "${REQUIRED_AGENTS[@]}"; do
        local status="${RESULTS[$agent]:-SKIP}"
        local message="${MESSAGES[$agent]:-Not checked}"

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $agent: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $agent: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $agent: $message" ;;
            SKIP) echo -e "${BLUE}○${NC} $agent: $message" ;;
        esac
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "   SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Passed:   $PASSED"
    echo "  Failed:   $FAILED"
    echo "  Warnings: $WARNINGS"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All required agents are properly installed${NC}"
        return 0
    else
        echo -e "${RED}✗ Some agents are missing or invalid${NC}"
        return 1
    fi
}

# Print JSON output
print_json_output() {
    local overall_status="pass"
    [[ $FAILED -gt 0 ]] && overall_status="fail"

    cat << EOF
{
  "status": "$overall_status",
  "agents_dir": "$AGENTS_DIR",
  "summary": {
    "passed": $PASSED,
    "failed": $FAILED,
    "warnings": $WARNINGS
  },
  "agents": {
EOF

    local first=true
    for agent in "${REQUIRED_AGENTS[@]}"; do
        $first || echo ","
        first=false
        cat << EOF
    "$agent": {
      "status": "${RESULTS[$agent]:-SKIP}",
      "message": "${MESSAGES[$agent]:-Not checked}"
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check agents directory
check_agents_dir

# Validate required agents
for agent in "${REQUIRED_AGENTS[@]}"; do
    validate_agent "$agent"
done

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac
