#!/bin/bash
#!/usr/bin/env bash
#===============================================================================
# Security Full Audit Hook v2.70.0
# PostToolUse hook - AUTO-INVOKE /security for sensitive files
#===============================================================================
#
# VERSION: 2.70.0
# v2.70.0: AUTO-007 - Detect RALPH_AUTO_MODE for automatic execution
# v2.69.0: SEC-104 FIX - Replace MD5 with SHA-256 for file hashing
# TRIGGER: PostToolUse (Edit|Write)
# PURPOSE: Automatically invoke /security for auth/payment/crypto files
#
# AUTO MODE: When RALPH_AUTO_MODE=true, runs silently without interrupting flow
# MANUAL MODE: Shows instruction message for user to execute /security

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

readonly VERSION="2.70.0"
readonly HOOK_NAME="security-full-audit"

# Configuration
readonly MARKERS_DIR="${HOME}/.ralph/markers"
readonly LOG_FILE="${HOME}/.ralph/logs/security-audit.log"
readonly COOLDOWN_MINUTES=15

# AUTO-007: Check if running in automatic mode (orchestrator/loop)
# When RALPH_AUTO_MODE=true, hook runs silently without blocking flow
is_auto_mode() {
    [[ "${RALPH_AUTO_MODE:-false}" == "true" ]]
}

# Ensure directories exist
mkdir -p "$MARKERS_DIR" "$(dirname "$LOG_FILE")" 2>/dev/null || true

# Guaranteed JSON output on any error
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Logging
log() {
    echo "[$(date -Iseconds)] [$HOOK_NAME] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# Get session ID
get_session_id() {
    echo "${CLAUDE_SESSION_ID:-$$}"
}

# Check if file is security-sensitive
is_security_sensitive() {
    local file_path="$1"
    local filename
    filename=$(basename "$file_path" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")
    local dir_path
    dir_path=$(dirname "$file_path" 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "")

    # Check filename patterns
    # SC2221/SC2222 FIX: Removed *oauth* (already covered by *auth*)
    case "$filename" in
        *auth*|*login*|*password*|*credential*|*secret*|*token*|*jwt*|*session*)
            return 0
            ;;
        *payment*|*billing*|*stripe*|*checkout*|*transaction*|*wallet*)
            return 0
            ;;
        *crypto*|*encrypt*|*decrypt*|*cipher*|*hash*|*key*)
            return 0
            ;;
        *security*|*permission*|*access*|*role*|*privilege*)
            return 0
            ;;
    esac

    # Check directory patterns
    # SC2221/SC2222 FIX: Removed *middleware/auth* (already covered by *auth*)
    case "$dir_path" in
        *auth*|*security*|*payment*|*crypto*)
            return 0
            ;;
    esac

    return 1
}

# Check cooldown for file
is_within_cooldown() {
    local file_hash
    # SEC-104 FIX: Use SHA-256 instead of MD5 (MD5 is cryptographically broken)
    file_hash=$(echo "$1" | shasum -a 256 2>/dev/null | cut -c1-16 || echo "unknown")
    local marker="${MARKERS_DIR}/security-audit-${file_hash}"

    if [[ -f "$marker" ]]; then
        local marker_age
        # MEDIUM-001 FIX: Portable stat (macOS/BSD: -f %m, Linux: -c %Y)
        marker_age=$(( $(date +%s) - $(stat -f %m "$marker" 2>/dev/null || stat -c %Y "$marker" 2>/dev/null || echo 0) ))
        (( marker_age < COOLDOWN_MINUTES * 60 ))
    else
        return 1
    fi
}

# Update cooldown marker
update_cooldown() {
    local file_hash
    # SEC-104 FIX: Use SHA-256 instead of MD5 (MD5 is cryptographically broken)
    file_hash=$(echo "$1" | shasum -a 256 2>/dev/null | cut -c1-16 || echo "unknown")
    local marker="${MARKERS_DIR}/security-audit-${file_hash}"
    touch "$marker" 2>/dev/null || true
}

# Main logic
main() {
    # v2.69: Use $INPUT from SEC-111 read instead of second cat (fixes CRIT-001 double-read bug)
    local input="$INPUT"

    # Extract tool name and file path
    local tool_name
    tool_name=$(echo "$input" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
    local file_path
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

    # Only process Edit/Write
    if [[ "$tool_name" != "Edit" ]] && [[ "$tool_name" != "Write" ]]; then
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Skip if no file path
    if [[ -z "$file_path" ]]; then
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Check if security-sensitive
    if ! is_security_sensitive "$file_path"; then
        log "Not security-sensitive: $file_path"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Check cooldown
    if is_within_cooldown "$file_path"; then
        log "Within cooldown for: $file_path"
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    fi

    # Update cooldown
    update_cooldown "$file_path"

    log "Security-sensitive file modified: $file_path"

    # AUTO-007: Check mode and behave accordingly
    if is_auto_mode; then
        # AUTO MODE: Completely silent - orchestrator/loop will execute /security automatically
        log "AUTO MODE: Marking for automatic security audit"

        # Store file path for auto-execution by orchestrator/loop
        mkdir -p "$MARKERS_DIR" 2>/dev/null || true
        echo "$file_path" > "${MARKERS_DIR}/security-pending-$(get_session_id).txt" 2>/dev/null || true

        # Completely silent - no systemMessage at all
        trap - ERR EXIT
        echo '{"continue": true}'
        exit 0
    else
        # MANUAL MODE: Show informational message (non-blocking)
        log "MANUAL MODE: Informing about security audit option"

        # Build informational message (non-imperative)
        local instruction
        instruction=$(cat << EOF
🔒 **Security-sensitive file modified**: \`$file_path\`

A security audit is available. To run: \`/security $file_path\`
EOF
)

        # Output with system message (informational)
        local escaped_instruction
        escaped_instruction=$(echo "$instruction" | jq -Rs '.')

        trap - ERR EXIT
        echo "{\"continue\": true, \"systemMessage\": $escaped_instruction}"
    fi
}

main "$@"
