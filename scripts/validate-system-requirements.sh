#!/usr/bin/env bash
#===============================================================================
# validate-system-requirements.sh - Validate system dependencies
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Check all required and optional tools for multi-agent-ralph-loop
#
# Usage:
#   ./scripts/validate-system-requirements.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All required tools pass
#   1: One or more required tools missing or invalid
#   2: Cannot run checks (jq missing, etc.)
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
Usage: validate-system-requirements.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Exit codes:
  0  All required tools pass
  1  One or more required tools missing or invalid
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
# TOOL DEFINITIONS
#===============================================================================

# Required tools (must be present)
declare -A REQUIRED_TOOLS=(
    ["bash"]="4.0|Shell execution"
    ["jq"]="1.5|JSON parsing"
    ["curl"]="7.0|HTTP requests"
    ["git"]="2.0|Version control"
)

# Optional tools (nice to have)
declare -A OPTIONAL_TOOLS=(
    ["node"]="18|TypeScript/ESLint runtime"
    ["python3"]="3.9|Python tools"
    ["bun"]="1.0|claude-mem plugin runtime"
    ["npx"]="8|npm package executor"
    ["pyright"]="0|Python type checker"
    ["ruff"]="0|Python linter"
    ["semgrep"]="0|Security scanning"
    ["gitleaks"]="0|Secret detection"
)

# Recommended tools
declare -A RECOMMENDED_TOOLS=(
    ["claude"]="0|Claude Code CLI"
    ["gh"]="2.0|GitHub CLI"
    ["bats"]="1.0|Bash testing"
)

#===============================================================================
# RESULT STORAGE
#===============================================================================

declare -A RESULTS
declare -A VERSIONS
declare -A MESSAGES
TOTAL_REQUIRED=0
TOTAL_OPTIONAL=0
TOTAL_RECOMMENDED=0
PASSED=0
FAILED=0
WARNINGS=0

#===============================================================================
# FUNCTIONS
#===============================================================================

# Extract version from command output
extract_version() {
    local cmd="$1"
    local version_output

    # Try different version flags
    version_output=$("$cmd" --version 2>&1 || "$cmd" -V 2>&1 || "$cmd" version 2>&1 || echo "unknown")

    # Common version patterns
    if [[ "$version_output" =~ ([0-9]+\.[0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$version_output" =~ ([0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$version_output" =~ ([0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "0"
    fi
}

# Compare versions (returns 0 if $1 >= $2)
version_ge() {
    local v1="$1"
    local v2="$2"

    [[ "$v1" == "$v2" ]] && return 0

    IFS='.' read -ra v1_parts <<< "$v1"
    IFS='.' read -ra v2_parts <<< "$v2"

    local max_parts=${#v1_parts[@]}
    [[ ${#v2_parts[@]} -gt $max_parts ]] && max_parts=${#v2_parts[@]}

    for ((i=0; i<max_parts; i++)); do
        local p1="${v1_parts[i]:-0}"
        local p2="${v2_parts[i]:-0}"

        # Remove non-numeric suffixes
        p1="${p1%%[!0-9]*}"
        p2="${p2%%[!0-9]*}"

        if (( p1 > p2 )); then
            return 0
        elif (( p1 < p2 )); then
            return 1
        fi
    done

    return 0
}

# Check a single tool
check_tool() {
    local tool="$1"
    local min_version="$2"
    local description="$3"
    local required="$4"

    local status=""
    local version=""
    local message=""

    if command -v "$tool" &>/dev/null; then
        version=$(extract_version "$tool")

        if [[ "$min_version" == "0" ]]; then
            # No minimum version required
            status="PASS"
            message="$description"
        elif version_ge "$version" "$min_version"; then
            status="PASS"
            message="$description (v$version >= v$min_version)"
        else
            status="FAIL"
            message="$description (v$version < required v$min_version)"
        fi
    else
        status="MISSING"
        message="$description (not found)"
    fi

    RESULTS["$tool"]="$status"
    VERSIONS["$tool"]="$version"
    MESSAGES["$tool"]="$message"

    case "$status" in
        PASS)
            PASSED=$((PASSED + 1))
            ;;
        FAIL)
            FAILED=$((FAILED + 1))
            ;;
        MISSING)
            if [[ "$required" == "required" ]]; then
                FAILED=$((FAILED + 1))
            else
                WARNINGS=$((WARNINGS + 1))
            fi
            ;;
    esac
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   System Requirements Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Required tools
    echo -e "${BLUE}REQUIRED TOOLS${NC}"
    echo "───────────────────────────────────────────────────────────────"
    for tool in "${!REQUIRED_TOOLS[@]}"; do
        local info="${REQUIRED_TOOLS[$tool]}"
        local min_version="${info%%|*}"
        local desc="${info#*|}"

        case "${RESULTS[$tool]}" in
            PASS)
                echo -e "${GREEN}✓${NC} $tool: ${MESSAGES[$tool]}"
                [[ $VERBOSE -eq 1 ]] && echo "    Version: ${VERSIONS[$tool]}"
                ;;
            FAIL)
                echo -e "${RED}✗${NC} $tool: ${MESSAGES[$tool]}"
                [[ $VERBOSE -eq 1 ]] && echo "    Required: v$min_version"
                ;;
            MISSING)
                echo -e "${RED}✗${NC} $tool: NOT FOUND - $desc"
                ;;
        esac
    done
    echo ""

    # Optional tools
    echo -e "${BLUE}OPTIONAL TOOLS${NC}"
    echo "───────────────────────────────────────────────────────────────"
    for tool in "${!OPTIONAL_TOOLS[@]}"; do
        local info="${OPTIONAL_TOOLS[$tool]}"
        local min_version="${info%%|*}"
        local desc="${info#*|}"

        case "${RESULTS[$tool]}" in
            PASS)
                echo -e "${GREEN}✓${NC} $tool: ${MESSAGES[$tool]}"
                ;;
            FAIL)
                echo -e "${YELLOW}⚠${NC} $tool: ${MESSAGES[$tool]}"
                ;;
            MISSING)
                echo -e "${YELLOW}○${NC} $tool: not installed ($desc)"
                ;;
        esac
    done
    echo ""

    # Recommended tools
    echo -e "${BLUE}RECOMMENDED TOOLS${NC}"
    echo "───────────────────────────────────────────────────────────────"
    for tool in "${!RECOMMENDED_TOOLS[@]}"; do
        local info="${RECOMMENDED_TOOLS[$tool]}"
        local min_version="${info%%|*}"
        local desc="${info#*|}"

        case "${RESULTS[$tool]}" in
            PASS)
                echo -e "${GREEN}✓${NC} $tool: ${MESSAGES[$tool]}"
                ;;
            FAIL)
                echo -e "${YELLOW}⚠${NC} $tool: ${MESSAGES[$tool]}"
                ;;
            MISSING)
                echo -e "${YELLOW}○${NC} $tool: not installed ($desc)"
                ;;
        esac
    done
    echo ""

    # Summary
    echo "═══════════════════════════════════════════════════════════════"
    echo "   SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  Passed:   $PASSED"
    echo "  Failed:   $FAILED"
    echo "  Warnings: $WARNINGS"
    echo ""

    if [[ $FAILED -eq 0 ]]; then
        echo -e "${GREEN}✓ All required tools are available${NC}"
        return 0
    else
        echo -e "${RED}✗ Some required tools are missing or outdated${NC}"
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
  "required": {
EOF

    local first=true
    for tool in "${!REQUIRED_TOOLS[@]}"; do
        $first || echo ","
        first=false
        local version="${VERSIONS[$tool]:-null}"
        [[ "$version" == "null" || -z "$version" ]] && version="null" || version="\"$version\""
        cat << EOF
    "$tool": {
      "status": "${RESULTS[$tool]}",
      "version": $version,
      "message": "${MESSAGES[$tool]}"
    }
EOF
    done

    echo "  },"
    echo '  "optional": {'

    first=true
    for tool in "${!OPTIONAL_TOOLS[@]}"; do
        $first || echo ","
        first=false
        local version="${VERSIONS[$tool]:-null}"
        [[ "$version" == "null" || -z "$version" ]] && version="null" || version="\"$version\""
        cat << EOF
    "$tool": {
      "status": "${RESULTS[$tool]}",
      "version": $version,
      "message": "${MESSAGES[$tool]}"
    }
EOF
    done

    echo "  },"
    echo '  "recommended": {'

    first=true
    for tool in "${!RECOMMENDED_TOOLS[@]}"; do
        $first || echo ","
        first=false
        local version="${VERSIONS[$tool]:-null}"
        [[ "$version" == "null" || -z "$version" ]] && version="null" || version="\"$version\""
        cat << EOF
    "$tool": {
      "status": "${RESULTS[$tool]}",
      "version": $version,
      "message": "${MESSAGES[$tool]}"
    }
EOF
    done

    echo "  }"
    echo "}"
}

#===============================================================================
# MAIN
#===============================================================================

# Check jq first (needed for JSON output)
if [[ "$FORMAT" == "json" ]] && ! command -v jq &>/dev/null; then
    echo '{"status": "error", "message": "jq is required for JSON output"}' >&2
    exit 2
fi

# Check required tools
for tool in "${!REQUIRED_TOOLS[@]}"; do
    TOTAL_REQUIRED=$((TOTAL_REQUIRED + 1))
    info="${REQUIRED_TOOLS[$tool]}"
    min_version="${info%%|*}"
    desc="${info#*|}"
    check_tool "$tool" "$min_version" "$desc" "required"
done

# Check optional tools
for tool in "${!OPTIONAL_TOOLS[@]}"; do
    TOTAL_OPTIONAL=$((TOTAL_OPTIONAL + 1))
    info="${OPTIONAL_TOOLS[$tool]}"
    min_version="${info%%|*}"
    desc="${info#*|}"
    check_tool "$tool" "$min_version" "$desc" "optional"
done

# Check recommended tools
for tool in "${!RECOMMENDED_TOOLS[@]}"; do
    TOTAL_RECOMMENDED=$((TOTAL_RECOMMENDED + 1))
    info="${RECOMMENDED_TOOLS[$tool]}"
    min_version="${info%%|*}"
    desc="${info#*|}"
    check_tool "$tool" "$min_version" "$desc" "recommended"
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
