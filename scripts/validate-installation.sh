#!/usr/bin/env bash
#===============================================================================
# validate-installation.sh - Master validation script
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Run all validation scripts and generate comprehensive report
#
# Usage:
#   ./scripts/validate-installation.sh [--format json|text] [--quick] [--verbose]
#
# Exit codes:
#   0: All validations pass
#   1: One or more validations failed
#   2: Cannot run validations
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Output format
FORMAT="${FORMAT:-text}"
VERBOSE="${VERBOSE:-0}"
QUICK="${QUICK:-0}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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
        --quick|-q)
            QUICK=1
            shift
            ;;
        --help|-h)
            cat << 'EOF'
Usage: validate-installation.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --quick, -q      Quick check (critical only)
  --help, -h       Show this help message

Validations:
  1. System Requirements    - Required tools and versions
  2. Shell Environment      - PATH, aliases, environment
  3. Directory Structure    - Required directories and permissions
  4. Hooks Registration     - All hooks registered and executable
  5. Skills Registration    - All skills properly installed
  6. Agents Registration    - All agents properly defined
  7. Settings Structure     - Settings.json valid structure

Exit codes:
  0  All validations pass
  1  One or more validations failed
  2  Cannot run validations
EOF
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

#===============================================================================
# VALIDATION RESULTS
#===============================================================================

declare -A VALIDATION_RESULTS
declare -A VALIDATION_MESSAGES
declare -A VALIDATION_PASSED
declare -A VALIDATION_FAILED
declare -A VALIDATION_WARNINGS

TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_WARNINGS=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Run a validation script
run_validation() {
    local name="$1"
    local script="$2"
    local args="${3:-}"

    local status=""
    local message=""
    local passed=0
    local failed=0
    local warnings=0

    if [[ ! -x "$script" ]]; then
        status="ERROR"
        message="Script not found or not executable"
    else
        # Run the validation
        local output
        local exit_code

        if [[ "$FORMAT" == "json" ]]; then
            output=$("$script" --format json $args 2>&1) || exit_code=$?
            exit_code="${exit_code:-0}"

            # Parse JSON output
            status=$(echo "$output" | jq -r '.status' 2>/dev/null || echo "error")
            passed=$(echo "$output" | jq '.summary.passed // 0' 2>/dev/null || echo "0")
            failed=$(echo "$output" | jq '.summary.failed // 0' 2>/dev/null || echo "0")
            warnings=$(echo "$output" | jq '.summary.warnings // 0' 2>/dev/null || echo "0")

            if [[ "$status" == "pass" ]]; then
                message="All checks passed"
            else
                message="$failed checks failed"
            fi
        else
            output=$("$script" $args 2>&1) || exit_code=$?
            exit_code="${exit_code:-0}"

            if [[ $exit_code -eq 0 ]]; then
                status="PASS"
                message="All checks passed"
            else
                status="FAIL"
                message="Some checks failed"
            fi
        fi
    fi

    VALIDATION_RESULTS["$name"]="$status"
    VALIDATION_MESSAGES["$name"]="$message"
    VALIDATION_PASSED["$name"]="$passed"
    VALIDATION_FAILED["$name"]="$failed"
    VALIDATION_WARNINGS["$name"]="$warnings"

    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_WARNINGS=$((TOTAL_WARNINGS + warnings))
}

# Print text output
print_text_output() {
    echo -e "${MAGENTA}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC}       INSTALLATION VALIDATION - v1.0.0                        ${MAGENTA}║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "Project: $PROJECT_ROOT"
    echo "Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")"
    echo ""

    # Validation results
    echo -e "${BLUE}VALIDATION RESULTS${NC}"
    echo "───────────────────────────────────────────────────────────────"

    for name in "${!VALIDATION_RESULTS[@]}"; do
        local status="${VALIDATION_RESULTS[$name]}"
        local message="${VALIDATION_MESSAGES[$name]}"

        case "$status" in
            PASS)
                echo -e "${GREEN}✓${NC} $name: $message"
                ;;
            FAIL)
                echo -e "${RED}✗${NC} $name: $message"
                ;;
            ERROR)
                echo -e "${RED}!${NC} $name: $message"
                ;;
            *)
                echo -e "${YELLOW}?${NC} $name: $message"
                ;;
        esac
    done

    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "   OVERALL SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Total Passed:   $TOTAL_PASSED"
    echo "  Total Failed:   $TOTAL_FAILED"
    echo "  Total Warnings: $TOTAL_WARNINGS"
    echo ""

    if [[ $TOTAL_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ INSTALLATION IS VALID${NC}"
        echo ""
        echo "All validations passed. The installation is properly configured."
        return 0
    else
        echo -e "${RED}✗ INSTALLATION HAS ISSUES${NC}"
        echo ""
        echo "Some validations failed. Please review the output above."
        return 1
    fi
}

# Print JSON output
print_json_output() {
    local overall_status="pass"
    [[ $TOTAL_FAILED -gt 0 ]] && overall_status="fail"

    cat << EOF
{
  "status": "$overall_status",
  "project": "$PROJECT_ROOT",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "summary": {
    "passed": $TOTAL_PASSED,
    "failed": $TOTAL_FAILED,
    "warnings": $TOTAL_WARNINGS
  },
  "validations": {
EOF

    local first=true
    for name in "${!VALIDATION_RESULTS[@]}"; do
        $first || echo ","
        first=false
        cat << EOF
    "$name": {
      "status": "${VALIDATION_RESULTS[$name]}",
      "message": "${VALIDATION_MESSAGES[$name]}",
      "passed": ${VALIDATION_PASSED[$name]},
      "failed": ${VALIDATION_FAILED[$name]},
      "warnings": ${VALIDATION_WARNINGS[$name]}
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Critical validations (always run)
run_validation "system_requirements" "$SCRIPT_DIR/validate-system-requirements.sh"
run_validation "hooks_registration" "$SCRIPT_DIR/validate-hooks-registration.sh"
run_validation "settings_structure" "$SCRIPT_DIR/validate-settings-structure.sh"

# Extended validations (skip if quick)
if [[ $QUICK -eq 0 ]]; then
    run_validation "shell_environment" "$SCRIPT_DIR/validate-shell-config.sh"
    run_validation "directory_structure" "$SCRIPT_DIR/validate-directories.sh"
    run_validation "skills_registration" "$SCRIPT_DIR/validate-skills-registration.sh"
    run_validation "agents_registration" "$SCRIPT_DIR/validate-agents-registration.sh"
fi

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac
