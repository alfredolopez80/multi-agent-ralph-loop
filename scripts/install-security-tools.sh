#!/bin/bash
# install-security-tools.sh - Install semgrep + gitleaks for local security scanning
# VERSION: 2.48.0
# Part of Ralph Orchestrator SECURITY_SCAN feature
#
# Usage: ./install-security-tools.sh [--check]
#        ./install-security-tools.sh --uninstall

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }

check_tool() {
    local tool="$1"
    if command -v "$tool" &>/dev/null; then
        local version
        case "$tool" in
            semgrep) version=$(semgrep --version 2>/dev/null | head -1) ;;
            gitleaks) version=$(gitleaks version 2>/dev/null) ;;
            *) version="installed" ;;
        esac
        print_success "$tool: $version"
        return 0
    else
        print_warning "$tool: not installed"
        return 1
    fi
}

install_semgrep() {
    print_status "Installing semgrep..."

    # Prefer pipx for isolation, fallback to brew, then pip
    if command -v pipx &>/dev/null; then
        pipx install semgrep
    elif command -v brew &>/dev/null; then
        brew install semgrep
    elif command -v pip3 &>/dev/null; then
        pip3 install --user semgrep
    else
        print_error "No package manager found (pipx, brew, pip3)"
        return 1
    fi

    print_success "semgrep installed successfully"
}

install_gitleaks() {
    print_status "Installing gitleaks..."

    if command -v brew &>/dev/null; then
        brew install gitleaks
    elif command -v go &>/dev/null; then
        go install github.com/gitleaks/gitleaks/v8@latest
    else
        # Download binary directly
        local os arch url
        os=$(uname -s | tr '[:upper:]' '[:lower:]')
        arch=$(uname -m)
        [[ "$arch" == "x86_64" ]] && arch="x64"
        [[ "$arch" == "arm64" ]] && arch="arm64"

        url="https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_${os}_${arch}.tar.gz"
        print_status "Downloading from $url"

        local tmp_dir
        tmp_dir=$(mktemp -d)
        curl -sL "$url" | tar xz -C "$tmp_dir"

        local install_dir="${HOME}/.local/bin"
        mkdir -p "$install_dir"
        mv "$tmp_dir/gitleaks" "$install_dir/"
        chmod +x "$install_dir/gitleaks"
        rm -rf "$tmp_dir"

        print_warning "Installed to $install_dir/gitleaks - ensure this is in your PATH"
    fi

    print_success "gitleaks installed successfully"
}

# Main
case "${1:-install}" in
    --check)
        echo ""
        echo "=== Security Tools Status ==="
        echo ""
        MISSING=0
        check_tool "semgrep" || MISSING=$((MISSING + 1))
        check_tool "gitleaks" || MISSING=$((MISSING + 1))
        echo ""

        if [[ $MISSING -eq 0 ]]; then
            print_success "All security tools installed!"
            echo ""
            echo "Quality gates will automatically run:"
            echo "  • semgrep --config=auto (SAST rules)"
            echo "  • gitleaks protect --staged (secret detection)"
            exit 0
        else
            print_warning "$MISSING tool(s) missing"
            echo ""
            echo "Install with: ./install-security-tools.sh"
            exit 1
        fi
        ;;

    --uninstall)
        print_status "Uninstalling security tools..."
        if command -v brew &>/dev/null; then
            brew uninstall semgrep gitleaks 2>/dev/null || true
        fi
        if command -v pipx &>/dev/null; then
            pipx uninstall semgrep 2>/dev/null || true
        fi
        rm -f "${HOME}/.local/bin/gitleaks" 2>/dev/null || true
        print_success "Security tools uninstalled"
        ;;

    install|"")
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        echo "║     Ralph Security Tools Installer (v2.48)                   ║"
        echo "║                                                              ║"
        echo "║  This installs:                                              ║"
        echo "║  • semgrep  - Static analysis (SAST) for 30+ languages      ║"
        echo "║  • gitleaks - Secret detection in git repositories          ║"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""

        # Check current status
        SEMGREP_OK=false
        GITLEAKS_OK=false

        if check_tool "semgrep"; then
            SEMGREP_OK=true
        fi

        if check_tool "gitleaks"; then
            GITLEAKS_OK=true
        fi

        echo ""

        # Install missing tools
        if [[ "$SEMGREP_OK" == "false" ]]; then
            install_semgrep
        fi

        if [[ "$GITLEAKS_OK" == "false" ]]; then
            install_gitleaks
        fi

        echo ""
        echo "=== Verification ==="
        check_tool "semgrep"
        check_tool "gitleaks"

        echo ""
        print_success "Security scanning enabled in quality-gates-v2.sh!"
        echo ""
        echo "What happens now:"
        echo "  1. Every Edit/Write triggers quality gates"
        echo "  2. Stage 2.5 SECURITY runs semgrep + gitleaks"
        echo "  3. Security issues are BLOCKING (quality-first)"
        echo ""
        echo "To test manually:"
        echo "  semgrep --config=auto path/to/file.py"
        echo "  gitleaks protect --staged --verbose"
        ;;

    *)
        echo "Usage: $0 [--check | --uninstall | install]"
        exit 1
        ;;
esac
