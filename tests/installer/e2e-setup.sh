#!/usr/bin/env bash
#===============================================================================
# e2e-setup.sh - Setup script for E2E Installation Tests
#
# VERSION: 1.0.0
# DATE: 2026-02-15
# PURPOSE: Creates a clean isolated environment for E2E installer testing
#
# Usage:
#   ./e2e-setup.sh                    # Create test environment
#   ./e2e-setup.sh --cleanup          # Remove test environment
#   ./e2e-setup.sh --status           # Check environment status
#
# Environment Variables:
#   E2E_TEST_DIR - Override default test directory (default: /tmp/ralph-e2e-test)
#===============================================================================

set -euo pipefail

# Configuration
E2E_TEST_DIR="${E2E_TEST_DIR:-/tmp/ralph-e2e-test-$$}"
E2E_HOME="$E2E_TEST_DIR/home"
E2E_BIN="$E2E_TEST_DIR/bin"
E2E_STATE_FILE="$E2E_TEST_DIR/.e2e-state"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create mock commands needed for install.sh
create_mock_commands() {
    log_info "Creating mock commands..."

    # jq - JSON processor
    cat > "$E2E_BIN/jq" << 'EOF'
#!/usr/bin/env bash
case "$1" in
    --version|-V) echo "jq-1.6"; exit 0;;
    --help|-h) echo "jq - commandline JSON processor"; exit 0;;
    empty) exit 0;;
    *) # Simple jq implementation for basic operations
       if [[ "$*" == *".permissions"* ]]; then
           echo '{"allow": ["Bash(ralph:*)", "Bash(mmc:*)"]}'
       elif [[ "$*" == *".hooks"* ]]; then
           echo '{"PreToolUse": [], "PostToolUse": []}'
       else
           cat
       fi
       ;;
esac
EOF
    chmod +x "$E2E_BIN/jq"

    # curl - HTTP client
    cat > "$E2E_BIN/curl" << 'EOF'
#!/usr/bin/env bash
case "$1" in
    --version|-V) echo "curl 8.0.0"; exit 0;;
    --help|-h) echo "curl - transfer a URL"; exit 0;;
    -fsSL|-sSL)
        # Simulate successful download
        echo "# Mock skill file"
        exit 0
        ;;
    *) exit 0;;
esac
EOF
    chmod +x "$E2E_BIN/curl"

    # git
    cat > "$E2E_BIN/git" << 'EOF'
#!/usr/bin/env bash
case "$1" in
    --version) echo "git version 2.40.0"; exit 0;;
    rev-parse)
        if [[ "$2" == "--show-toplevel" ]]; then
            echo "/tmp/ralph-e2e-test-$$"
        fi
        exit 0
        ;;
    *) exit 0;;
esac
EOF
    chmod +x "$E2E_BIN/git"

    # Create wrapper script to run commands with test environment
    cat > "$E2E_TEST_DIR/run-with-env.sh" << EOF
#!/usr/bin/env bash
export HOME="$E2E_HOME"
export PATH="$E2E_HOME/.local/bin:$E2E_BIN:\$PATH"
cd "$E2E_HOME"
exec "\$@"
EOF
    chmod +x "$E2E_TEST_DIR/run-with-env.sh"

    log_success "Mock commands created in $E2E_BIN"
}

# Create directory structure
create_directories() {
    log_info "Creating directory structure..."

    # Main directories
    mkdir -p "$E2E_HOME/.local/bin"
    mkdir -p "$E2E_HOME/.claude/agents"
    mkdir -p "$E2E_HOME/.claude/commands"
    mkdir -p "$E2E_HOME/.claude/skills"
    mkdir -p "$E2E_HOME/.claude/hooks"
    mkdir -p "$E2E_BIN"

    # Create empty shell config files
    touch "$E2E_HOME/.zshrc"
    touch "$E2E_HOME/.bashrc"

    # Add some basic content to shell configs
    cat > "$E2E_HOME/.zshrc" << 'EOF'
# Test zshrc file
export ZSH_VERSION="5.9"
EOF

    cat > "$E2E_HOME/.bashrc" << 'EOF'
# Test bashrc file
export BASH_VERSION="5.2"
EOF

    log_success "Directory structure created at $E2E_HOME"
}

# Save state for later cleanup
save_state() {
    log_info "Saving environment state..."

    cat > "$E2E_STATE_FILE" << EOF
E2E_TEST_DIR=$E2E_TEST_DIR
E2E_HOME=$E2E_HOME
E2E_BIN=$E2E_BIN
CREATED_AT=$(date -Iseconds)
ORIGINAL_HOME=$HOME
ORIGINAL_PATH=$PATH
EOF

    log_success "State saved to $E2E_STATE_FILE"
}

# Setup the test environment
setup_environment() {
    log_info "Setting up E2E test environment..."
    echo ""

    # Check if already exists
    if [[ -d "$E2E_TEST_DIR" ]]; then
        log_warn "Test directory already exists: $E2E_TEST_DIR"
        read -p "Remove and recreate? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cleanup_environment
        else
            log_error "Aborted"
            exit 1
        fi
    fi

    # Create directories
    create_directories

    # Create mock commands
    create_mock_commands

    # Save state
    save_state

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    log_success "E2E Test Environment Ready"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  Test directory: $E2E_TEST_DIR"
    echo "  Simulated HOME: $E2E_HOME"
    echo ""
    echo "  To run install.sh in test environment:"
    echo "    $E2E_TEST_DIR/run-with-env.sh bash -c 'echo Y | /path/to/install.sh'"
    echo ""
    echo "  To cleanup:"
    echo "    $0 --cleanup"
    echo ""
}

# Cleanup the test environment
cleanup_environment() {
    log_info "Cleaning up E2E test environment..."

    if [[ -d "$E2E_TEST_DIR" ]]; then
        rm -rf "$E2E_TEST_DIR"
        log_success "Removed: $E2E_TEST_DIR"
    else
        log_warn "Test directory not found: $E2E_TEST_DIR"
    fi
}

# Show environment status
show_status() {
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  E2E Test Environment Status"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""

    if [[ -f "$E2E_STATE_FILE" ]]; then
        echo "  State file: $E2E_STATE_FILE"
        echo "  Contents:"
        cat "$E2E_STATE_FILE" | sed 's/^/    /'
        echo ""
    fi

    if [[ -d "$E2E_TEST_DIR" ]]; then
        echo "  Test directory exists: $E2E_TEST_DIR"
        echo ""
        echo "  Directory structure:"
        find "$E2E_TEST_DIR" -type d 2>/dev/null | head -20 | sed 's/^/    /'
        echo ""
        echo "  Installed files:"
        echo "    - ralph CLI: $([ -f "$E2E_HOME/.local/bin/ralph" ] && echo "YES" || echo "NO")"
        echo "    - mmc CLI: $([ -f "$E2E_HOME/.local/bin/mmc" ] && echo "YES" || echo "NO")"
        echo "    - settings.json: $([ -f "$E2E_HOME/.claude/settings.json" ] && echo "YES" || echo "NO")"
        echo "    - .ralph dir: $([ -d "$E2E_HOME/.ralph" ] && echo "YES" || echo "NO")"
    else
        echo "  Test directory does not exist: $E2E_TEST_DIR"
    fi

    echo ""
}

# Export environment variables for use in tests
export_environment() {
    echo "# Add to your shell:"
    echo "export E2E_TEST_DIR='$E2E_TEST_DIR'"
    echo "export E2E_HOME='$E2E_HOME'"
    echo "export E2E_BIN='$E2E_BIN'"
    echo "export HOME='$E2E_HOME'"
    echo "export PATH='$E2E_HOME/.local/bin:$E2E_BIN:\$PATH'"
}

# Main
main() {
    case "${1:-setup}" in
        --cleanup|-c)
            cleanup_environment
            ;;
        --status|-s)
            show_status
            ;;
        --export|-e)
            export_environment
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (no args)    Setup test environment"
            echo "  --cleanup    Remove test environment"
            echo "  --status     Show environment status"
            echo "  --export     Print export commands for shell"
            echo "  --help       Show this help"
            echo ""
            echo "Environment Variables:"
            echo "  E2E_TEST_DIR - Override test directory (default: /tmp/ralph-e2e-test-\$\$)"
            ;;
        *)
            setup_environment
            ;;
    esac
}

main "$@"
