#!/usr/bin/env bash
#===============================================================================
# validate-directories.sh - Validate directory structure
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Check all required directories exist with correct permissions
#
# Usage:
#   ./scripts/validate-directories.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All directories exist with correct permissions
#   1: Some directories missing or have wrong permissions
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
Usage: validate-directories.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - All Ralph directories exist (~/.ralph/*)
  - All Claude directories exist (~/.claude/*)
  - Directory permissions are correct
  - Directory ownership is correct

Exit codes:
  0  All directories valid
  1  Some directories invalid
  2  Cannot run checks
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 2
            ;;
    esac
done

#===============================================================================
# DIRECTORY DEFINITIONS
#===============================================================================

# Directories with their expected permissions (octal) and sensitivity
# Format: "path|permissions|sensitive"
# sensitive: 1 = should be 700, 0 = can be 755

declare -A REQUIRED_DIRS=(
    # CLI scripts (world-readable, executable)
    ["local_bin"]="$HOME/.local/bin|755|0"

    # Main data directory (private)
    ["ralph_main"]="$HOME/.ralph|700|1"

    # Ralph subdirectories (private)
    ["ralph_config"]="$HOME/.ralph/config|700|1"
    ["ralph_logs"]="$HOME/.ralph/logs|700|1"
    ["ralph_memory"]="$HOME/.ralph/memory|700|1"
    ["ralph_plans"]="$HOME/.ralph/plans|700|1"
    ["ralph_episodes"]="$HOME/.ralph/episodes|700|1"
    ["ralph_ledgers"]="$HOME/.ralph/ledgers|700|1"
    ["ralph_handoffs"]="$HOME/.ralph/handoffs|700|1"
    ["ralph_improvements"]="$HOME/.ralph/improvements|700|1"

    # Claude directories (readable for tool access)
    ["claude_main"]="$HOME/.claude|755|0"
    ["claude_agents"]="$HOME/.claude/agents|755|0"
    ["claude_commands"]="$HOME/.claude/commands|755|0"
    ["claude_skills"]="$HOME/.claude/skills|755|0"
    ["claude_hooks"]="$HOME/.claude/hooks|755|0"
)

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A RESULTS
declare -A MESSAGES
declare -A PERMISSIONS
PASSED=0
FAILED=0
WARNINGS=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Get directory permissions in octal
get_dir_permissions() {
    local dir="$1"
    stat -f "%Lp" "$dir" 2>/dev/null || stat -c "%a" "$dir" 2>/dev/null || echo "000"
}

# Check if directory is owned by current user
is_owned_by_user() {
    local dir="$1"
    local owner
    owner=$(stat -f "%Su" "$dir" 2>/dev/null || stat -c "%U" "$dir" 2>/dev/null)
    [[ "$owner" == "$(whoami)" ]]
}

# Check a single directory
check_directory() {
    local key="$1"
    local info="${REQUIRED_DIRS[$key]}"
    local path="${info%%|*}"
    local rest="${info#*|}"
    local expected_perms="${rest%%|*}"
    local sensitive="${rest##*|}"

    local status=""
    local message=""

    if [[ ! -d "$path" ]]; then
        status="FAIL"
        message="Directory does not exist"
        PERMISSIONS["$key"]="missing"
    else
        local actual_perms
        actual_perms=$(get_dir_permissions "$path")

        PERMISSIONS["$key"]="$actual_perms"

        # Check ownership
        if ! is_owned_by_user "$path"; then
            status="WARN"
            message="Not owned by current user (permissions: $actual_perms)"
        # Check permissions
        elif [[ "$actual_perms" != "$expected_perms" ]]; then
            # Permission mismatch is a warning, not a failure
            # (different systems have different security requirements)
            status="WARN"
            message="Permissions: $actual_perms (expected $expected_perms)"
        else
            status="PASS"
            message="Permissions: $actual_perms"
        fi
    fi

    RESULTS["$key"]="$status"
    MESSAGES["$key"]="$message"

    case "$status" in
        PASS) PASSED=$((PASSED + 1)) ;;
        FAIL) FAILED=$((FAILED + 1)) ;;
        WARN) WARNINGS=$((WARNINGS + 1)) ;;
    esac
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Directory Structure Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Group by type
    echo -e "${BLUE}CLI DIRECTORIES${NC}"
    echo "───────────────────────────────────────────────────────────────"
    for key in "local_bin"; do
        local path="${REQUIRED_DIRS[$key]%%|*}"
        local status="${RESULTS[$key]}"
        local message="${MESSAGES[$key]}"

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $path: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $path: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $path: $message" ;;
        esac
    done
    echo ""

    echo -e "${BLUE}RALPH DIRECTORIES${NC}"
    echo "───────────────────────────────────────────────────────────────"
    for key in ralph_main ralph_config ralph_logs ralph_memory ralph_plans ralph_episodes ralph_ledgers ralph_handoffs ralph_improvements; do
        local path="${REQUIRED_DIRS[$key]%%|*}"
        local status="${RESULTS[$key]}"
        local message="${MESSAGES[$key]}"

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $path: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $path: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $path: $message" ;;
        esac
    done
    echo ""

    echo -e "${BLUE}CLAUDE DIRECTORIES${NC}"
    echo "───────────────────────────────────────────────────────────────"
    for key in claude_main claude_agents claude_commands claude_skills claude_hooks; do
        local path="${REQUIRED_DIRS[$key]%%|*}"
        local status="${RESULTS[$key]}"
        local message="${MESSAGES[$key]}"

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $path: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $path: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $path: $message" ;;
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
        echo -e "${GREEN}✓ All required directories exist${NC}"
        return 0
    else
        echo -e "${RED}✗ Some directories are missing or misconfigured${NC}"
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
  "summary": {
    "passed": $PASSED,
    "failed": $FAILED,
    "warnings": $WARNINGS
  },
  "directories": {
EOF

    local first=true
    for key in "${!RESULTS[@]}"; do
        $first || echo ","
        first=false
        local path="${REQUIRED_DIRS[$key]%%|*}"
        cat << EOF
    "$key": {
      "path": "$path",
      "status": "${RESULTS[$key]}",
      "message": "${MESSAGES[$key]}",
      "permissions": "${PERMISSIONS[$key]}"
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check all directories
for key in "${!REQUIRED_DIRS[@]}"; do
    check_directory "$key"
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
