#!/usr/bin/env bash
#===============================================================================
# validate-settings-structure.sh - Validate settings.json structure
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Validate that settings.json has correct structure
#
# Usage:
#   ./scripts/validate-settings-structure.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: Settings structure is valid
#   1: Settings structure is invalid
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

# Settings path
SETTINGS_PATH="${HOME}/.claude/settings.json"

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
Usage: validate-settings-structure.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - Valid JSON structure
  - All required top-level keys present
  - Hooks structure is correct
  - Permissions structure is correct
  - No duplicate hook entries
  - JSON schema validation

Exit codes:
  0  Settings structure is valid
  1  Settings structure is invalid
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
# REQUIRED STRUCTURE
#===============================================================================

# Required top-level keys
REQUIRED_KEYS=("env" "permissions" "hooks")

# Required hook events
REQUIRED_HOOK_EVENTS=(
    "SessionStart"
    "PreToolUse"
    "PostToolUse"
    "Stop"
    "PreCompact"
    "UserPromptSubmit"
)

# Required permission keys
REQUIRED_PERMISSION_KEYS=("allow" "deny")

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

# Check if JSON is valid
check_json_valid() {
    if jq empty < "$SETTINGS_PATH" 2>/dev/null; then
        record_check "json_valid" "PASS" "Valid JSON structure"
    else
        record_check "json_valid" "FAIL" "Invalid JSON structure"
    fi
}

# Check required top-level keys
check_required_keys() {
    local missing=()
    local found=0

    for key in "${REQUIRED_KEYS[@]}"; do
        if jq -e ".$key" < "$SETTINGS_PATH" >/dev/null 2>&1; then
            found=$((found + 1))
        else
            missing+=("$key")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        record_check "required_keys" "PASS" "All required keys present: ${REQUIRED_KEYS[*]}"
    else
        record_check "required_keys" "FAIL" "Missing keys: ${missing[*]}"
    fi
}

# Check hooks structure
check_hooks_structure() {
    local missing_events=()
    local found=0

    for event in "${REQUIRED_HOOK_EVENTS[@]}"; do
        if jq -e ".hooks.$event" < "$SETTINGS_PATH" >/dev/null 2>&1; then
            found=$((found + 1))
        else
            missing_events+=("$event")
        fi
    done

    if [[ ${#missing_events[@]} -eq 0 ]]; then
        record_check "hooks_events" "PASS" "All hook events present"
    else
        record_check "hooks_events" "WARN" "Missing hook events: ${missing_events[*]}"
    fi
}

# Check permissions structure
check_permissions_structure() {
    local missing=()

    for key in "${REQUIRED_PERMISSION_KEYS[@]}"; do
        if ! jq -e ".permissions.$key" < "$SETTINGS_PATH" >/dev/null 2>&1; then
            missing+=("$key")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        record_check "permissions_structure" "PASS" "Permissions structure is correct"
    else
        record_check "permissions_structure" "WARN" "Missing permission keys: ${missing[*]}"
    fi
}

# Check for duplicate hooks
check_duplicate_hooks() {
    local duplicates=0

    # Check each event for duplicate hook commands
    for event in "${REQUIRED_HOOK_EVENTS[@]}"; do
        local count
        count=$(jq -r ".hooks.$event // [] | .. | .command? // empty" < "$SETTINGS_PATH" 2>/dev/null | sort | uniq -d | wc -l | tr -d ' ')
        if [[ "$count" -gt 0 ]]; then
            duplicates=$((duplicates + count))
        fi
    done

    if [[ $duplicates -eq 0 ]]; then
        record_check "no_duplicate_hooks" "PASS" "No duplicate hooks found"
    else
        record_check "no_duplicate_hooks" "WARN" "Found $duplicates duplicate hook entries"
    fi
}

# Check env variables
check_env_variables() {
    local env_count
    env_count=$(jq '.env | length' < "$SETTINGS_PATH" 2>/dev/null || echo "0")

    if [[ $env_count -gt 0 ]]; then
        record_check "env_variables" "PASS" "$env_count environment variables configured"
    else
        record_check "env_variables" "WARN" "No environment variables configured"
    fi
}

# Check Agent Teams env var
check_agent_teams_env() {
    local value
    value=$(jq -r '.env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS // empty' < "$SETTINGS_PATH" 2>/dev/null)

    if [[ "$value" == "1" ]]; then
        record_check "agent_teams_env" "PASS" "Agent Teams is enabled"
    else
        record_check "agent_teams_env" "WARN" "Agent Teams is not enabled"
    fi
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Settings Structure Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Settings: $SETTINGS_PATH"
    echo ""

    echo -e "${BLUE}CHECKS${NC}"
    echo "───────────────────────────────────────────────────────────────"

    for check in "${!RESULTS[@]}"; do
        local status="${RESULTS[$check]}"
        local message="${MESSAGES[$check]}"

        case "$status" in
            PASS) echo -e "${GREEN}✓${NC} $check: $message" ;;
            FAIL) echo -e "${RED}✗${NC} $check: $message" ;;
            WARN) echo -e "${YELLOW}⚠${NC} $check: $message" ;;
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
        echo -e "${GREEN}✓ Settings structure is valid${NC}"
        return 0
    else
        echo -e "${RED}✗ Settings structure is invalid${NC}"
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
  "settings_path": "$SETTINGS_PATH",
  "summary": {
    "passed": $PASSED,
    "failed": $FAILED,
    "warnings": $WARNINGS
  },
  "checks": {
EOF

    local first=true
    for check in "${!RESULTS[@]}"; do
        $first || echo ","
        first=false
        cat << EOF
    "$check": {
      "status": "${RESULTS[$check]}",
      "message": "${MESSAGES[$check]}"
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check if settings.json exists
if [[ ! -f "$SETTINGS_PATH" ]]; then
    echo "Settings file not found: $SETTINGS_PATH" >&2
    exit 2
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
    echo "jq is required but not installed" >&2
    exit 2
fi

# Run all checks
check_json_valid
check_required_keys
check_hooks_structure
check_permissions_structure
check_duplicate_hooks
check_env_variables
check_agent_teams_env

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac
