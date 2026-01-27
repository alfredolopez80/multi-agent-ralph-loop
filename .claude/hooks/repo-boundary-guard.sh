#!/usr/bin/env bash
# repo-boundary-guard.sh - Repository Isolation Enforcement
# Hook: PreToolUse (Edit|Write|Bash)
# Purpose: Prevent accidental work in external repositories
# VERSION: 2.69.0
# v2.66.8: SEC-051 - Use realpath for proper path canonicalization

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap: Always output valid JSON for PreToolUse
trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT

# Configuration
LOG_FILE="${HOME}/.ralph/logs/repo-boundary.log"
CURRENT_REPO=""
GITHUB_DIR="${HOME}/Documents/GitHub"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get current repository root
get_current_repo() {
    git rev-parse --show-toplevel 2>/dev/null || echo ""
}

# v2.69.0 FIX: Check if command is read-only (safe to run on external repos)
# This prevents false positives blocking legitimate ls, cat, grep commands
is_readonly_command() {
    local command="$1"

    # Extract base command (first word)
    local base_cmd
    base_cmd=$(echo "$command" | awk '{print $1}')

    # Safe read-only commands
    case "$base_cmd" in
        ls|ll|la|tree|find|fd)
            return 0 ;;
        cat|less|more|head|tail)
            return 0 ;;
        grep|egrep|fgrep|rg|ag)
            return 0 ;;
        diff|sdiff|cmp)
            return 0 ;;
        wc|sort|uniq)
            return 0 ;;
        file|stat|du)
            return 0 ;;
        jq|yq)
            return 0 ;;
        pwd|which|whereis)
            return 0 ;;
        md5sum|sha256sum|shasum)
            return 0 ;;
        echo|printf)
            return 0 ;;
        *)
            # Check git read-only commands
            if [[ "$command" =~ ^git\ (show|log|diff|status|branch) ]]; then
                return 0
            fi
            return 1 ;;
    esac
}

# Check if a path is within the current repo or allowed locations
is_allowed_path() {
    local path="$1"
    local current_repo="$2"

    # SEC-051: Canonicalize path using realpath (handles ~, .., symlinks)
    # First expand ~ manually, then use realpath for full canonicalization
    path="${path/#\~/$HOME}"
    path=$(realpath -m "$path" 2>/dev/null || echo "$path")

    # Allow global config directories
    if [[ "$path" == "${HOME}/.claude"* ]] || \
       [[ "$path" == "${HOME}/.ralph"* ]] || \
       [[ "$path" == "${HOME}/.config"* ]] || \
       [[ "$path" == "/tmp"* ]] || \
       [[ "$path" == "/var"* ]]; then
        return 0  # Allowed
    fi

    # If no current repo detected, allow
    if [[ -z "$current_repo" ]]; then
        return 0
    fi

    # Check if path is within current repo
    if [[ "$path" == "$current_repo"* ]]; then
        return 0  # Allowed - within current repo
    fi

    # Check if path is in another GitHub repo
    if [[ "$path" == "$GITHUB_DIR"* ]] && [[ "$path" != "$current_repo"* ]]; then
        return 1  # BLOCKED - another repo
    fi

    # Allow other paths (system, etc.)
    return 0
}

# Extract paths from tool input
extract_paths() {
    local input="$1"

    # Extract file_path, path, or command paths
    echo "$input" | jq -r '
        .tool_input // . |
        if type == "object" then
            (.file_path // .path // .command // "")
        else
            ""
        end
    ' 2>/dev/null || echo ""
}

# Main logic
main() {
    # v2.69: Use $INPUT from SEC-111 read instead of second cat (fixes double-read bug)
    local input="$INPUT"

    if [[ -z "$input" ]]; then
        log "DEBUG: Empty input, allowing"
        trap - ERR EXIT
        echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
        exit 0
    fi

    # Get current repo
    CURRENT_REPO=$(get_current_repo)

    if [[ -z "$CURRENT_REPO" ]]; then
        log "DEBUG: Not in a git repo, allowing"
        trap - ERR EXIT
        echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
        exit 0
    fi

    # Extract tool name
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

    # Only check Edit, Write, Bash
    case "$tool_name" in
        Edit|Write|Bash)
            ;;
        *)
            log "DEBUG: Tool $tool_name not checked, allowing"
            trap - ERR EXIT
            echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
            exit 0
            ;;
    esac

    # Extract paths from input
    local paths
    paths=$(extract_paths "$input")

    # For Bash, also check command content
    if [[ "$tool_name" == "Bash" ]]; then
        local command
        command=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

        # v2.69.0 FIX: Check if command is read-only FIRST
        # Read-only commands (ls, cat, grep, etc.) are safe to run on external repos
        if is_readonly_command "$command"; then
            log "ALLOWED: Read-only command (safe for cross-repo): $command"
            trap - ERR EXIT
            echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
            exit 0
        fi

        # Only check repo boundaries for non-readonly (potentially destructive) commands
        # Look for patterns like /Users/.../GitHub/OtherRepo
        if echo "$command" | grep -qE "${GITHUB_DIR}/[^/]+/" 2>/dev/null; then
            local mentioned_path
            mentioned_path=$(echo "$command" | grep -oE "${GITHUB_DIR}/[^/[:space:]]+" | head -1)

            if ! is_allowed_path "$mentioned_path" "$CURRENT_REPO"; then
                log "BLOCKED: Bash command references external repo: $mentioned_path"
                trap - ERR EXIT
                cat << EOF
{
  "decision": "block",
  "reason": "⚠️ REPO BOUNDARY: Command references external repository ($mentioned_path). Use /repo-learn to learn from it instead, or explicitly switch repos."
}
EOF
                exit 0
            fi
        fi
    fi

    # Check extracted paths
    for path in $paths; do
        if [[ -n "$path" ]] && ! is_allowed_path "$path" "$CURRENT_REPO"; then
            log "BLOCKED: Access to external repo path: $path (current: $CURRENT_REPO)"
            trap - ERR EXIT
            cat << EOF
{
  "decision": "block",
  "reason": "⚠️ REPO BOUNDARY: Path $path is outside current repo ($CURRENT_REPO). Use /repo-learn to learn from external repos, or explicitly switch."
}
EOF
            exit 0
        fi
    done

    log "ALLOWED: All paths within boundary"
    trap - ERR EXIT
    echo \'{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}\'
}

main "$@"
