#!/usr/bin/env bash
# GLM Usage Tracking Installation Script
# VERSION: 1.0.0
#
# This script automates the installation and setup of GLM usage tracking
# for Multi-Agent Ralph statusline integration.
#
# USAGE:
#   ./install-glm-usage-tracking.sh [--force] [--test]
#
# OPTIONS:
#   --force    - Reinstall even if already installed
#   --test     - Run tests after installation
#   --help     - Show this help message
#
# ENVIRONMENT VARIABLES:
#   Z_AI_API_KEY - Z.ai API key (optional, will use settings.json if not set)
#
# EXIT CODES:
#   0 - Success
#   1 - General error
#   2 - Dependency missing
#   3 - Installation failed
#   4 - Test failed
#
# Part of Multi-Agent Ralph v2.74.2
# See: docs/GLM_USAGE_FIX_v2.0.0.md

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SCRIPT_NAME="glm-usage-cache-manager.sh"
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
INSTALL_PATH="${HOME}/.ralph/scripts/${SCRIPT_NAME}"
CACHE_DIR="${HOME}/.ralph/cache"
CACHE_FILE="${CACHE_DIR}/glm-usage-cache.json"
API_URL="https://api.z.ai/api/monitor/usage/quota/limit"

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Options
FORCE_INSTALL=false
RUN_TESTS=false

# ============================================================================
# FUNCTIONS
# ============================================================================

# Print colored message
log() {
    local level="$1"
    shift
    local message="$*"
    local color=""

    case "$level" in
        INFO)  color="$CYAN" ;;
        SUCCESS) color="$GREEN" ;;
        WARNING) color="$YELLOW" ;;
        ERROR) color="$RED" ;;
        *)     color="$RESET" ;;
    esac

    echo -e "${color}[${level}]${RESET} ${message}"
}

# Print header
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${BLUE}║${RESET}   GLM Usage Tracking Installation Script v1.0.0       ${BLUE}║${RESET}"
    echo -e "${BLUE}║${RESET}   Multi-Agent Ralph v2.74.2                          ${BLUE}║${RESET}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

# Print step
print_step() {
    echo ""
    echo -e "${CYAN}▶ $1${RESET}"
}

# Check if command exists
command_exists() {
    command -v "$1" &>/dev/null
}

# Check dependencies
check_dependencies() {
    print_step "Checking dependencies"

    local missing_deps=()

    # Check curl
    if command_exists curl; then
        local curl_version
        curl_version=$(curl --version 2>/dev/null | head -1)
        log SUCCESS "curl found: ${curl_version}"
    else
        log ERROR "curl not found"
        missing_deps+=("curl")
    fi

    # Check jq
    if command_exists jq; then
        local jq_version
        jq_version=$(jq --version 2>/dev/null)
        log SUCCESS "jq found: ${jq_version}"
    else
        log ERROR "jq not found"
        missing_deps+=("jq")
    fi

    # Check node (optional, for backward compatibility)
    if command_exists node; then
        local node_version
        node_version=$(node --version 2>/dev/null)
        log INFO "node found: ${node_version} (optional)"
    else
        log INFO "node not found (optional, not required)"
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo ""
        log ERROR "Missing dependencies: ${missing_deps[*]}"
        echo ""
        echo "Please install missing dependencies:"
        echo "  macOS:   brew install ${missing_deps[*]}"
        echo "  Ubuntu:  sudo apt-get install ${missing_deps[*]}"
        echo "  Fedora:  sudo dnf install ${missing_deps[*]}"
        exit 2
    fi
}

# Get API key from settings.json or environment
get_api_key() {
    local api_key="${Z_AI_API_KEY:-}"

    if [[ -z "$api_key" ]]; then
        local settings_file="${HOME}/.claude-sneakpeek/zai/config/settings.json"

        if [[ -f "$settings_file" ]]; then
            api_key=$(jq -r '.env.Z_AI_API_KEY // .env.ANTHROPIC_API_KEY // ""' "$settings_file" 2>/dev/null || echo "")
        fi
    fi

    echo "$api_key"
}

# Test API connection
test_api() {
    print_step "Testing API connection"

    local api_key
    api_key=$(get_api_key)

    if [[ -z "$api_key" ]]; then
        log WARNING "No API key found, skipping API test"
        return 0
    fi

    log INFO "Testing API endpoint: ${API_URL}"

    local response
    response=$(curl -s "$API_URL" -H "x-api-key: $api_key" 2>&1)

    local success
    success=$(echo "$response" | jq -r '.success // false' 2>/dev/null || echo "false")

    if [[ "$success" == "true" ]]; then
        log SUCCESS "API connection successful"

        local five_hour_pct
        local monthly_pct
        five_hour_pct=$(echo "$response" | jq -r '.data.limits[] | select(.type == "TOKENS_LIMIT") | .percentage')
        monthly_pct=$(echo "$response" | jq -r '.data.limits[] | select(.type == "TIME_LIMIT") | .percentage')

        log INFO "Current usage: 5h=${five_hour_pct}%, MCP=${monthly_pct}%"
    else
        log ERROR "API connection failed"
        log ERROR "Response: ${response:0:200}..."
        return 1
    fi
}

# Install script
install_script() {
    print_step "Installing script"

    # Create target directory
    mkdir -p "$(dirname "$INSTALL_PATH")"

    # Check if already installed
    if [[ -f "$INSTALL_PATH" ]] && [[ "$FORCE_INSTALL" != true ]]; then
        local installed_version
        installed_version=$(grep "^# VERSION:" "$INSTALL_PATH" | awk '{print $3}' || echo "unknown")
        local source_version
        source_version=$(grep "^# VERSION:" "$SCRIPT_PATH" | awk '{print $3}' || echo "unknown")

        if [[ "$installed_version" == "$source_version" ]]; then
            log INFO "Script already installed (v${installed_version})"
            log INFO "Use --force to reinstall"
            return 0
        fi

        log WARNING "Different version installed: ${installed_version} vs ${source_version}"
        log INFO "Updating to v${source_version}"
    fi

    # Copy script
    cp "$SCRIPT_PATH" "$INSTALL_PATH"
    chmod +x "$INSTALL_PATH"

    log SUCCESS "Script installed: ${INSTALL_PATH}"

    # Verify installation
    if [[ ! -x "$INSTALL_PATH" ]]; then
        log ERROR "Script is not executable"
        return 1
    fi

    local version
    version=$(grep "^# VERSION:" "$INSTALL_PATH" | awk '{print $3}')
    log INFO "Version: ${version}"
}

# Create cache directory
create_cache_dir() {
    print_step "Creating cache directory"

    if [[ ! -d "$CACHE_DIR" ]]; then
        mkdir -p "$CACHE_DIR"
        log SUCCESS "Cache directory created: ${CACHE_DIR}"
    else
        log INFO "Cache directory exists: ${CACHE_DIR}"
    fi

    # Set permissions
    chmod 700 "$CACHE_DIR"
}

# Refresh cache
refresh_cache() {
    print_step "Refreshing cache"

    if [[ ! -x "$INSTALL_PATH" ]]; then
        log ERROR "Script not installed or not executable"
        return 1
    fi

    local output
    output=$("$INSTALL_PATH" refresh 2>&1)

    if [[ $? -eq 0 ]]; then
        log SUCCESS "Cache refreshed"
        echo "$output"
    else
        log ERROR "Failed to refresh cache"
        echo "$output"
        return 1
    fi
}

# Run tests
run_tests() {
    print_step "Running tests"

    local failed=0

    # Test 1: Script exists and is executable
    echo ""
    echo -n "  Test 1: Script executable... "
    if [[ -x "$INSTALL_PATH" ]]; then
        echo -e "${GREEN}PASS${RESET}"
    else
        echo -e "${RED}FAIL${RESET}"
        failed=$((failed + 1))
    fi

    # Test 2: Cache file exists
    echo -n "  Test 2: Cache file exists... "
    if [[ -f "$CACHE_FILE" ]]; then
        echo -e "${GREEN}PASS${RESET}"
    else
        echo -e "${RED}FAIL${RESET}"
        failed=$((failed + 1))
    fi

    # Test 3: Cache is valid JSON
    echo -n "  Test 3: Cache is valid JSON... "
    if jq empty "$CACHE_FILE" 2>/dev/null; then
        echo -e "${GREEN}PASS${RESET}"
    else
        echo -e "${RED}FAIL${RESET}"
        failed=$((failed + 1))
    fi

    # Test 4: Statusline output works
    echo -n "  Test 4: Statusline output... "
    local statusline
    statusline=$("$INSTALL_PATH" get-statusline 2>/dev/null)
    if [[ -n "$statusline" ]]; then
        echo -e "${GREEN}PASS${RESET}"
        echo "         ${statusline}"
    else
        echo -e "${RED}FAIL${RESET}"
        failed=$((failed + 1))
    fi

    # Test 5: Show command works
    echo -n "  Test 5: Show command... "
    local show_output
    show_output=$("$INSTALL_PATH" show 2>&1)
    if [[ -n "$show_output" ]]; then
        echo -e "${GREEN}PASS${RESET}"
    else
        echo -e "${RED}FAIL${RESET}"
        failed=$((failed + 1))
    fi

    if [[ $failed -gt 0 ]]; then
        echo ""
        log ERROR "${failed} test(s) failed"
        return 4
    else
        echo ""
        log SUCCESS "All tests passed"
    fi
}

# Show summary
show_summary() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║${RESET}   Installation Complete!                                 ${GREEN}║${RESET}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo "Installed files:"
    echo "  Script:   ${INSTALL_PATH}"
    echo "  Cache:    ${CACHE_FILE}"
    echo ""
    echo "Usage:"
    echo "  ${INSTALL_PATH} refresh       - Refresh cache from API"
    echo "  ${INSTALL_PATH} get-statusline - Get statusline output"
    echo "  ${INSTALL_PATH} show          - Show detailed info"
    echo ""
    echo "Documentation:"
    echo "  ${PROJECT_ROOT}/docs/GLM_USAGE_FIX_v2.0.0.md"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_INSTALL=true
            shift
            ;;
        --test)
            RUN_TESTS=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force] [--test] [--help]"
            echo ""
            echo "Options:"
            echo "  --force    - Reinstall even if already installed"
            echo "  --test     - Run tests after installation"
            echo "  --help     - Show this help message"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Run installation
print_header

check_dependencies
test_api || true  # Don't fail on API test error
install_script || exit 3
create_cache_dir
refresh_cache || exit 3

if [[ "$RUN_TESTS" == true ]]; then
    run_tests || exit 4
fi

show_summary

exit 0
