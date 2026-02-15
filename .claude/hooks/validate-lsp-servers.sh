#!/bin/bash
#===============================================================================
# validate-lsp-servers.sh - Validate LSP servers availability for lsp-explore
#
# VERSION: 1.1.0
# DATE: 2026-02-15
# PURPOSE: Hook that validates language servers are available before LSP operations
# SECURITY: v1.1.0 - Added JSON escaping, PATH validation, output limits
#
# USAGE:
#   ./validate-lsp-servers.sh              # Full validation
#   ./validate-lsp-servers.sh --essential  # Essential servers only
#   ./validate-lsp-servers.sh --json       # JSON output
#===============================================================================

set -e

SCRIPT_VERSION="1.1.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Essential servers for lsp-explore to function
ESSENTIAL_SERVERS=("typescript-language-server" "pyright" "clangd")
# Optional servers that enhance functionality
OPTIONAL_SERVERS=("gopls" "rust-analyzer" "lua-language-server" "intelephense" "kotlin-language-server" "sourcekit-lsp")

# Security: Allowed paths for server binaries (prevents PATH hijacking)
ALLOWED_PATH_PREFIXES=(
    "/usr/local/bin"
    "/usr/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/opt"
    "$HOME/.nvm"
    "$HOME/.cargo/bin"
    "$HOME/.local/bin"
)

#===============================================================================
# Security Helper Functions
#===============================================================================

# Escape string for safe JSON embedding
escape_json_string() {
    local str="$1"
    # Limit length first
    str="${str:0:100}"
    # Escape special characters
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    # Remove control characters
    str="${str//[$'\x01'-$'\x1f']/}"
    echo "$str"
}

# Validate server name format (prevent injection)
validate_server_name() {
    local server="$1"
    if [[ ! "$server" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        return 1
    fi
    return 0
}

# Check if binary path is in allowed location (prevent PATH hijacking)
is_path_allowed() {
    local binary_path="$1"

    for allowed_prefix in "${ALLOWED_PATH_PREFIXES[@]}"; do
        # Expand $HOME in prefix
        local expanded_prefix="${allowed_prefix/\$HOME/$HOME}"
        if [[ "$binary_path" == "$expanded_prefix"* ]]; then
            return 0
        fi
    done
    return 1
}

#===============================================================================
# Core Functions
#===============================================================================

check_server() {
    local server="$1"

    # Security: Validate server name format
    if ! validate_server_name "$server"; then
        return 1
    fi

    local server_path
    server_path=$(command -v "$server" 2>/dev/null) || return 1

    # Security: Verify binary is in allowed location
    if ! is_path_allowed "$server_path"; then
        return 1
    fi

    return 0
}

get_server_version() {
    local server="$1"

    # Security: Validate server name
    if ! validate_server_name "$server"; then
        echo "invalid"
        return
    fi

    local version="unknown"

    case "$server" in
        typescript-language-server)
            version=$($server --version 2>/dev/null | head -c 100 || echo "unknown")
            ;;
        pyright)
            version=$($server --version 2>/dev/null | head -c 100 || echo "unknown")
            ;;
        clangd)
            version=$($server --version 2>/dev/null | head -1 | head -c 100 || echo "unknown")
            ;;
        sourcekit-lsp)
            version="Xcode bundled"
            ;;
        gopls)
            version=$($server version 2>/dev/null | head -c 100 || echo "unknown")
            ;;
        rust-analyzer)
            version="installed"
            ;;
        lua-language-server)
            version=$($server --version 2>/dev/null | head -c 100 || echo "unknown")
            ;;
        intelephense)
            version="installed"
            ;;
        kotlin-language-server)
            version="installed"
            ;;
        *)
            version="unknown"
            ;;
    esac

    # Security: Escape for safe display
    echo "$version" | tr -d '\n\r' | head -c 100
}

#===============================================================================
# Validation Functions
#===============================================================================

validate_essential() {
    local missing=0
    local results=()

    for server in "${ESSENTIAL_SERVERS[@]}"; do
        if check_server "$server"; then
            local version
            version=$(get_server_version "$server")
            results+=("✅ $server: $version")
        else
            results+=("❌ $server: NOT INSTALLED")
            ((missing++)) || true
        fi
    done

    printf '%s\n' "${results[@]}"
    return $missing
}

validate_optional() {
    local available=0
    local results=()

    for server in "${OPTIONAL_SERVERS[@]}"; do
        if check_server "$server"; then
            local version
            version=$(get_server_version "$server")
            results+=("✅ $server: $version")
            ((available++)) || true
        else
            results+=("⚪ $server: not installed (optional)")
        fi
    done

    printf '%s\n' "${results[@]}"
    return 0
}

validate_json() {
    local essential_ok=true
    local json='{"status":"'

    # Check essential
    for server in "${ESSENTIAL_SERVERS[@]}"; do
        if ! check_server "$server"; then
            essential_ok=false
            break
        fi
    done

    if $essential_ok; then
        json+="ok"
    else
        json+="degraded"
    fi

    json+='","servers":{'

    # Add all servers with proper escaping
    local first=true
    for server in "${ESSENTIAL_SERVERS[@]}" "${OPTIONAL_SERVERS[@]}"; do
        if ! $first; then
            json+=","
        fi
        first=false

        local status="missing"
        local version="null"

        if check_server "$server"; then
            status="available"
            local raw_version
            raw_version=$(get_server_version "$server")
            version="\"$(escape_json_string "$raw_version")\""
        fi

        # Server name is already validated, safe to embed
        json+="\"$server\":{\"status\":\"$status\",\"version\":$version}"
    done

    json+="}}"

    echo "$json"
}

#===============================================================================
# Hook Output Functions
#===============================================================================

output_hook_pass() {
    echo '{"continue":true}'
}

output_hook_block() {
    local message="$1"
    # Security: Escape message for JSON
    local escaped_msg
    escaped_msg=$(escape_json_string "$message")
    echo "{\"continue\":false,\"reason\":\"$escaped_msg\"}"
}

#===============================================================================
# Main
#===============================================================================

main() {
    local mode="text"
    local servers_only="all"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --essential)
                servers_only="essential"
                shift
                ;;
            --json)
                mode="json"
                shift
                ;;
            --hook)
                mode="hook"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --essential  Check only essential servers"
                echo "  --json       Output as JSON"
                echo "  --hook       Output as hook response"
                echo "  --help       Show this help"
                exit 0
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
            *)
                shift
                ;;
        esac
    done

    case "$mode" in
        json)
            validate_json
            ;;
        hook)
            # Hook mode: validate essential servers
            local missing=0
            for server in "${ESSENTIAL_SERVERS[@]}"; do
                if ! check_server "$server"; then
                    ((missing++)) || true
                fi
            done

            if [[ $missing -eq 0 ]]; then
                output_hook_pass
            else
                output_hook_block "$missing essential LSP servers missing. Run: ./scripts/install-language-servers.sh --essential"
                exit 2
            fi
            ;;
        *)
            echo "=== LSP Servers Validation ==="
            echo ""
            echo "Essential Servers:"

            # Handle set -e with subshell
            local essential_missing=0
            validate_essential || essential_missing=$?

            echo ""
            echo "Optional Servers:"
            validate_optional

            echo ""
            if [[ $essential_missing -eq 0 ]]; then
                echo "✅ All essential LSP servers available"
                exit 0
            else
                echo "❌ $essential_missing essential servers missing"
                echo "   Run: ./scripts/install-language-servers.sh --essential"
                exit 1
            fi
            ;;
    esac
}

main "$@"
