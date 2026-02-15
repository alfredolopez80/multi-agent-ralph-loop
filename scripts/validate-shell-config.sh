#!/usr/bin/env bash
#===============================================================================
# validate-shell-config.sh - Validate shell environment configuration
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Check PATH, aliases, and environment variables for Ralph
#
# Usage:
#   ./scripts/validate-shell-config.sh [--format json|text] [--verbose]
#
# Exit codes:
#   0: All checks pass
#   1: Some checks failed
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
Usage: validate-shell-config.sh [OPTIONS]

Options:
  --format FORMAT  Output format: text (default) or json
  --verbose, -v    Show detailed information
  --help, -h       Show this help message

Checks:
  - PATH contains ~/.local/bin
  - Shell rc file has Ralph markers
  - All Ralph aliases are defined
  - MiniMax aliases are defined
  - Claude Code environment variables are set

Exit codes:
  0  All checks pass
  1  Some checks failed
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
# CONFIGURATION
#===============================================================================

# Detect shell
SHELL_TYPE=$(basename "${SHELL:-/bin/bash}")
RC_FILE=""

case "$SHELL_TYPE" in
    zsh)
        RC_FILE="${HOME}/.zshrc"
        ;;
    bash)
        RC_FILE="${HOME}/.bashrc"
        ;;
    *)
        RC_FILE="${HOME}/.profile"
        ;;
esac

# Ralph aliases (16 aliases)
RALPH_ALIASES=(
    "ralph"
    "orch"
    "loop"
    "gates"
    "adversarial"
    "bugs"
    "security"
    "retrospective"
    "clarify"
    "curator"
    "repo-learn"
    "task-batch"
    "create-task-batch"
    "research"
    "glm5"
    "parallel"
)

# MiniMax aliases
MINIMAX_ALIASES=(
    "mmc"
    "mmc-search"
    "mmc-config"
    "mmc-status"
)

# Ralph marker in rc file
RALPH_MARKER="# RALPH CONFIGURATION"
RALPH_END_MARKER="# END RALPH CONFIGURATION"

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

# Check if PATH contains ~/.local/bin
check_path() {
    local local_bin="$HOME/.local/bin"
    local status=""
    local message=""

    if [[ ":$PATH:" == *":$local_bin:"* ]]; then
        status="PASS"
        message="$local_bin is in PATH"
    else
        status="FAIL"
        message="$local_bin is NOT in PATH"
    fi

    record_check "path_local_bin" "$status" "$message"
}

# Check if RC file exists
check_rc_file() {
    local status=""
    local message=""

    if [[ -f "$RC_FILE" ]]; then
        status="PASS"
        message="$RC_FILE exists"
    else
        status="WARN"
        message="$RC_FILE not found"
    fi

    record_check "rc_file_exists" "$status" "$message"
}

# Check Ralph markers in RC file
check_ralph_markers() {
    local status=""
    local message=""

    if [[ ! -f "$RC_FILE" ]]; then
        status="WARN"
        message="RC file not found, cannot check markers"
        record_check "ralph_markers" "$status" "$message"
        return
    fi

    if grep -q "$RALPH_MARKER" "$RC_FILE" 2>/dev/null; then
        status="PASS"
        message="Ralph configuration markers found"
    else
        status="WARN"
        message="Ralph configuration markers not found (optional for manual installs)"
    fi

    record_check "ralph_markers" "$status" "$message"
}

# Check Ralph aliases
check_ralph_aliases() {
    local found=0
    local total=${#RALPH_ALIASES[@]}
    local missing=()

    for alias_name in "${RALPH_ALIASES[@]}"; do
        # Check if alias exists or command exists
        if alias "$alias_name" &>/dev/null || command -v "$alias_name" &>/dev/null; then
            found=$((found + 1))
        else
            missing+=("$alias_name")
        fi
    done

    local status=""
    local message=""

    if [[ $found -eq $total ]]; then
        status="PASS"
        message="All $total Ralph aliases available"
    elif [[ $found -gt 0 ]]; then
        status="WARN"
        message="$found/$total Ralph aliases available (missing: ${missing[*]})"
    else
        status="WARN"
        message="No Ralph aliases found (aliases optional, commands may be in PATH)"
    fi

    record_check "ralph_aliases" "$status" "$message"
}

# Check MiniMax aliases
check_minimax_aliases() {
    local found=0
    local total=${#MINIMAX_ALIASES[@]}
    local missing=()

    for alias_name in "${MINIMAX_ALIASES[@]}"; do
        if alias "$alias_name" &>/dev/null || command -v "$alias_name" &>/dev/null; then
            found=$((found + 1))
        else
            missing+=("$alias_name")
        fi
    done

    local status=""
    local message=""

    if [[ $found -eq $total ]]; then
        status="PASS"
        message="All $total MiniMax aliases available"
    elif [[ $found -gt 0 ]]; then
        status="WARN"
        message="$found/$total MiniMax aliases available (missing: ${missing[*]})"
    else
        status="WARN"
        message="No MiniMax aliases found (optional)"
    fi

    record_check "minimax_aliases" "$status" "$message"
}

# Check Claude Code environment variables
check_claude_env() {
    local status=""
    local message=""
    local found_vars=()

    # Check CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS
    if [[ -n "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-}" ]]; then
        found_vars+=("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS}")
    fi

    # Check other Claude-related env vars
    if [[ -n "${CLAUDE_CONFIG_DIR:-}" ]]; then
        found_vars+=("CLAUDE_CONFIG_DIR")
    fi

    if [[ ${#found_vars[@]} -gt 0 ]]; then
        status="PASS"
        message="Claude environment variables: ${found_vars[*]}"
    else
        status="WARN"
        message="No Claude environment variables set (optional)"
    fi

    record_check "claude_env" "$status" "$message"
}

# Check shell version
check_shell_version() {
    local version=""
    local status=""
    local message=""

    case "$SHELL_TYPE" in
        zsh)
            version=$(zsh --version 2>&1 | head -1)
            ;;
        bash)
            version=$(bash --version 2>&1 | head -1)
            ;;
        *)
            version="unknown"
            ;;
    esac

    status="PASS"
    message="$SHELL_TYPE: $version"

    record_check "shell_version" "$status" "$message"
}

# Print text output
print_text_output() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   Shell Environment Validation - v1.0.0"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""
    echo "Shell: $SHELL_TYPE"
    echo "RC File: $RC_FILE"
    echo ""

    echo -e "${BLUE}CHECKS${NC}"
    echo "───────────────────────────────────────────────────────────────"

    for check in "${!RESULTS[@]}"; do
        local status="${RESULTS[$check]}"
        local message="${MESSAGES[$check]}"

        case "$status" in
            PASS)
                echo -e "${GREEN}✓${NC} $check: $message"
                ;;
            FAIL)
                echo -e "${RED}✗${NC} $check: $message"
                ;;
            WARN)
                echo -e "${YELLOW}⚠${NC} $check: $message"
                ;;
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
        echo -e "${GREEN}✓ Shell environment is properly configured${NC}"
        return 0
    else
        echo -e "${RED}✗ Some shell configuration issues detected${NC}"
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
  "shell": {
    "type": "$SHELL_TYPE",
    "rc_file": "$RC_FILE"
  },
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

# Run all checks
check_path
check_rc_file
check_ralph_markers
check_ralph_aliases
check_minimax_aliases
check_claude_env
check_shell_version

# Output results
case "$FORMAT" in
    json)
        print_json_output
        ;;
    text|*)
        print_text_output
        ;;
esac
