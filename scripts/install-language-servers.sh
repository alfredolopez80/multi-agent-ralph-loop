#!/bin/bash
#===============================================================================
# install-language-servers.sh - Install LSP language servers for Claude Code
#
# VERSION: 1.0.1
# DATE: 2026-02-15
# PURPOSE: Install all LSP language servers needed for lsp-explore skill
# COMPAT: Bash 3.2+ (macOS native)
#
# USAGE:
#   ./scripts/install-language-servers.sh          # Install all servers
#   ./scripts/install-language-servers.sh --check  # Check status only
#   ./scripts/install-language-servers.sh --essential  # Essential only
#   ./scripts/install-language-servers.sh --help   # Show help
#===============================================================================

set -e

SCRIPT_VERSION="1.0.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#===============================================================================
# Configuration Arrays (Bash 3 compatible)
#===============================================================================

# Essential servers: name|installer|package|check_command
ESSENTIAL_SERVERS=(
    "typescript|npm|typescript-language-server|typescript-language-server --version"
    "python|npm|pyright|pyright --version"
    "clangd|brew|llvm|clangd --version"
    "swift|xcode||sourcekit-lsp --help"
)

# Optional servers
OPTIONAL_SERVERS=(
    "go|go|golang.org/x/tools/gopls@latest|gopls version"
    "rust|rustup|rust-analyzer|which rust-analyzer"
    "lua|brew|lua-language-server|lua-language-server --version"
    "php|npm|intelephense|intelephense --version"
    "kotlin|brew|kotlin-language-server|kotlin-language-server --version"
    "csharp|manual||echo manual"
)

#===============================================================================
# Helper Functions
#===============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}  Language Servers Installer v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo ""
}

print_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check      Check language servers status without installing"
    echo "  --essential  Install only essential servers"
    echo "  --verbose    Show detailed output"
    echo "  --help       Show this help message"
    echo ""
    echo "Essential Language Servers:"
    echo "  - typescript-language-server (TypeScript/JavaScript)"
    echo "  - pyright (Python)"
    echo "  - clangd (C/C++)"
    echo "  - sourcekit-lsp (Swift - macOS only)"
    echo ""
    echo "Optional Language Servers:"
    echo "  - gopls (Go)"
    echo "  - rust-analyzer (Rust)"
    echo "  - lua-language-server (Lua)"
    echo "  - intelephense (PHP)"
    echo "  - kotlin-language-server (Kotlin)"
    echo ""
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

#===============================================================================
# Installation Functions
#===============================================================================

install_npm() {
    local package="$1"
    echo -n "  Installing via npm... "
    if npm install -g "$package" 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

install_go() {
    local package="$1"
    echo -n "  Installing via go... "
    if go install "$package" 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

install_brew() {
    local package="$1"
    echo -n "  Installing via brew... "
    if brew install "$package" 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

install_rustup() {
    local component="$1"
    echo -n "  Installing via rustup... "
    if rustup component add "$component" 2>/dev/null; then
        echo -e "${GREEN}✅${NC}"
        return 0
    else
        echo -e "${RED}❌${NC}"
        return 1
    fi
}

#===============================================================================
# Check Functions
#===============================================================================

check_server() {
    local entry="$1"
    IFS='|' read -r name installer package check_cmd <<< "$entry"

    printf "  %-25s " "$name"

    # SEC: Use bash -c instead of eval for command execution
    if bash -c "$check_cmd" >/dev/null 2>&1; then
        local version
        version=$(bash -c "$check_cmd" 2>/dev/null | head -1 | cut -c1-40)
        echo -e "${GREEN}✅ ${version:-installed}${NC}"
        return 0
    else
        echo -e "${RED}❌ NOT INSTALLED${NC}"
        return 1
    fi
}

check_all_servers() {
    echo -e "${YELLOW}Essential Language Servers:${NC}"

    local essential_installed=0
    local essential_missing=0

    for server in "${ESSENTIAL_SERVERS[@]}"; do
        if check_server "$server"; then
            ((essential_installed++))
        else
            ((essential_missing++))
        fi
    done

    echo ""
    echo -e "${YELLOW}Optional Language Servers:${NC}"

    local optional_installed=0
    local optional_missing=0

    for server in "${OPTIONAL_SERVERS[@]}"; do
        if check_server "$server"; then
            ((optional_installed++))
        else
            ((optional_missing++))
        fi
    done

    echo ""
    echo -e "${BLUE}==========================================${NC}"
    echo -e "Essential: ${GREEN}$essential_installed installed${NC}, ${RED}$essential_missing missing${NC}"
    echo -e "Optional:  ${GREEN}$optional_installed installed${NC}, ${RED}$optional_missing missing${NC}"
    echo -e "${BLUE}==========================================${NC}"

    return $essential_missing
}

#===============================================================================
# Install Functions
#===============================================================================

install_server() {
    local entry="$1"
    IFS='|' read -r name installer package check_cmd <<< "$entry"

    echo -e "\n${BLUE}Installing $name...${NC}"

    case "$installer" in
        npm)
            install_npm "$package"
            ;;
        go)
            install_go "$package"
            ;;
        brew)
            install_brew "$package"
            ;;
        rustup)
            install_rustup "$package"
            ;;
        xcode)
            echo -e "  ${YELLOW}Included with Xcode - skipping${NC}"
            return 0
            ;;
        manual)
            echo -e "  ${YELLOW}Requires manual installation${NC}"
            echo "    See: https://$name.org/"
            return 0
            ;;
        "")
            echo -e "  ${YELLOW}No installer configured${NC}"
            return 0
            ;;
        *)
            echo -e "${RED}Unknown installer: $installer${NC}"
            return 1
            ;;
    esac
}

install_essential_servers() {
    echo -e "${YELLOW}Installing essential language servers...${NC}"

    for server in "${ESSENTIAL_SERVERS[@]}"; do
        install_server "$server"
    done
}

install_all_servers() {
    echo -e "${YELLOW}Installing essential language servers...${NC}"

    for server in "${ESSENTIAL_SERVERS[@]}"; do
        install_server "$server"
    done

    echo ""
    echo -e "${YELLOW}Installing optional language servers...${NC}"

    for server in "${OPTIONAL_SERVERS[@]}"; do
        install_server "$server"
    done
}

#===============================================================================
# Main Entry Point
#===============================================================================

main() {
    local check_only=false
    local essential_only=false
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check)
                check_only=true
                shift
                ;;
            --essential)
                essential_only=true
                shift
                ;;
            --verbose)
                verbose=true
                shift
                ;;
            --help|-h)
                print_help
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                print_help
                exit 1
                ;;
        esac
    done

    print_header

    if [[ "$check_only" == true ]]; then
        check_all_servers
        local missing=$?
        echo ""
        if [[ $missing -gt 0 ]]; then
            echo -e "${YELLOW}Run without --check to install missing servers${NC}"
        fi
        exit $missing
    fi

    # Check prerequisites
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    if ! check_command "npm"; then
        echo -e "${RED}npm is required but not installed${NC}"
        echo "Install Node.js from https://nodejs.org/"
        exit 1
    fi

    echo -e "  npm: ${GREEN}✅$(npm --version | head -1)${NC}"

    if check_command "brew"; then
        echo -e "  brew: ${GREEN}✅$(brew --version | head -1)${NC}"
    else
        echo -e "  brew: ${YELLOW}not found (optional)${NC}"
    fi

    if check_command "go"; then
        echo -e "  go: ${GREEN}✅$(go version | cut -d' ' -f3)${NC}"
    else
        echo -e "  go: ${YELLOW}not found (optional for gopls)${NC}"
    fi

    echo ""

    # Install servers
    if [[ "$essential_only" == true ]]; then
        install_essential_servers
    else
        install_all_servers
    fi

    echo ""
    check_all_servers
}

main "$@"
