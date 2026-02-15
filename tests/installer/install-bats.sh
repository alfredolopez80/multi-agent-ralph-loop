#!/usr/bin/env bash
#===============================================================================
# install-bats.sh - Install BATS and dependencies for installer tests
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Set up BATS testing framework for installer validation
#
# Usage:
#   ./tests/installer/install-bats.sh [--check | --install | --upgrade]
#
# Options:
#   --check    Check if BATS is installed and report version
#   --install  Install BATS if not present
#   --upgrade  Upgrade BATS to latest version
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# BATS version to install (if needed)
BATS_VERSION="1.11.0"
BATS_SUPPORT_VERSION="0.3.0"
BATS_ASSERT_VERSION="2.1.0"

# Installation directories
INSTALL_DIR="${HOME}/.local/share/bats"
BIN_DIR="${HOME}/.local/bin"

#===============================================================================
# FUNCTIONS
#===============================================================================

log_info() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_step() {
    echo -e "${BLUE}→${NC} $1"
}

# Check if BATS is installed
check_bats() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   BATS Installation Check"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    local status=0

    # Check bats-core
    if command -v bats &>/dev/null; then
        local version
        version=$(bats --version 2>&1 | head -1)
        log_info "bats-core: $version"
    else
        log_error "bats-core: Not installed"
        status=1
    fi

    # Check bats-support (via npm or manual install)
    if [[ -d "${INSTALL_DIR}/bats-support" ]] || npm list bats-support &>/dev/null 2>&1; then
        log_info "bats-support: Installed"
    else
        log_warn "bats-support: Not installed (optional but recommended)"
    fi

    # Check bats-assert
    if [[ -d "${INSTALL_DIR}/bats-assert" ]] || npm list bats-assert &>/dev/null 2>&1; then
        log_info "bats-assert: Installed"
    else
        log_warn "bats-assert: Not installed (optional but recommended)"
    fi

    echo ""
    if [[ $status -eq 0 ]]; then
        log_info "BATS is ready for use"
    else
        log_warn "Run with --install to set up BATS"
    fi

    return $status
}

# Install BATS via Homebrew (macOS)
install_bats_homebrew() {
    log_step "Installing BATS via Homebrew..."

    if ! command -v brew &>/dev/null; then
        log_error "Homebrew not found. Please install Homebrew first."
        return 1
    fi

    brew install bats-core || {
        log_error "Failed to install bats-core"
        return 1
    }

    # Install support libraries
    brew tap kaos/shell || true
    brew install bats-support bats-assert 2>/dev/null || {
        log_warn "Could not install bats-support/bats-assert via Homebrew"
        log_step "Installing manually..."
        install_bats_libraries
    }

    log_info "BATS installed via Homebrew"
    return 0
}

# Install BATS via npm (cross-platform)
install_bats_npm() {
    log_step "Installing BATS via npm..."

    if ! command -v npm &>/dev/null; then
        log_error "npm not found. Please install Node.js first."
        return 1
    fi

    npm install -g bats bats-support bats-assert || {
        log_error "Failed to install BATS via npm"
        return 1
    }

    log_info "BATS installed via npm"
    return 0
}

# Install BATS libraries manually
install_bats_libraries() {
    mkdir -p "$INSTALL_DIR"

    # Install bats-support
    if [[ ! -d "${INSTALL_DIR}/bats-support" ]]; then
        log_step "Installing bats-support..."
        git clone https://github.com/bats-core/bats-support.git "${INSTALL_DIR}/bats-support" || {
            log_warn "Could not clone bats-support"
        }
    fi

    # Install bats-assert
    if [[ ! -d "${INSTALL_DIR}/bats-assert" ]]; then
        log_step "Installing bats-assert..."
        git clone https://github.com/bats-core/bats-assert.git "${INSTALL_DIR}/bats-assert" || {
            log_warn "Could not clone bats-assert"
        }
    fi

    log_info "BATS libraries installed to $INSTALL_DIR"
}

# Install BATS from source
install_bats_source() {
    log_step "Installing BATS from source..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    cd "$tmp_dir"

    git clone https://github.com/bats-core/bats-core.git || {
        log_error "Failed to clone bats-core"
        rm -rf "$tmp_dir"
        return 1
    }

    cd bats-core
    ./install.sh "$INSTALL_DIR" || {
        log_error "Failed to install BATS"
        rm -rf "$tmp_dir"
        return 1
    }

    # Create symlink
    mkdir -p "$BIN_DIR"
    ln -sf "${INSTALL_DIR}/bin/bats" "${BIN_DIR}/bats"

    rm -rf "$tmp_dir"
    log_info "BATS installed from source"
    return 0
}

# Main install function
install_bats() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   BATS Installation"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    # Already installed?
    if command -v bats &>/dev/null; then
        log_info "BATS is already installed: $(bats --version 2>&1 | head -1)"
        read -p "Reinstall/Upgrade? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Skipping installation"
            return 0
        fi
    fi

    # Try different installation methods
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS: prefer Homebrew
        install_bats_homebrew || install_bats_npm || install_bats_source
    else
        # Linux: try npm, then source
        install_bats_npm || install_bats_source
    fi

    # Install libraries
    install_bats_libraries

    # Verify
    echo ""
    check_bats
}

# Upgrade BATS
upgrade_bats() {
    echo "═══════════════════════════════════════════════════════════════"
    echo "   BATS Upgrade"
    echo "═══════════════════════════════════════════════════════════════"
    echo ""

    if command -v brew &>/dev/null; then
        log_step "Upgrading via Homebrew..."
        brew upgrade bats-core 2>/dev/null || brew install bats-core
    elif command -v npm &>/dev/null; then
        log_step "Upgrading via npm..."
        npm update -g bats bats-support bats-assert
    fi

    # Update libraries
    if [[ -d "${INSTALL_DIR}/bats-support" ]]; then
        log_step "Updating bats-support..."
        cd "${INSTALL_DIR}/bats-support" && git pull
    fi

    if [[ -d "${INSTALL_DIR}/bats-assert" ]]; then
        log_step "Updating bats-assert..."
        cd "${INSTALL_DIR}/bats-assert" && git pull
    fi

    echo ""
    check_bats
}

# Show usage
usage() {
    cat << EOF
Usage: $(basename "$0") [OPTION]

Options:
  --check     Check if BATS is installed and report version
  --install   Install BATS if not present
  --upgrade   Upgrade BATS to latest version
  --help      Show this help message

Examples:
  $(basename "$0") --check
  $(basename "$0") --install
  $(basename "$0") --upgrade

BATS Libraries Location:
  $INSTALL_DIR

Add to PATH (if needed):
  export PATH="$BIN_DIR:\$PATH"
EOF
}

#===============================================================================
# MAIN
#===============================================================================

case "${1:-}" in
    --check)
        check_bats
        ;;
    --install)
        install_bats
        ;;
    --upgrade)
        upgrade_bats
        ;;
    --help|-h)
        usage
        ;;
    "")
        # Default: check and offer to install
        check_bats || install_bats
        ;;
    *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
esac
