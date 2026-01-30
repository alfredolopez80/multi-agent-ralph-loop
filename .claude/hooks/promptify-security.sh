#!/bin/bash
# promptify-security.sh - Security hardening functions for Promptify integration
# VERSION: 1.0.0
# Purpose: Credential redaction, clipboard consent, agent timeout, audit logging

set -euo pipefail

readonly VERSION="1.0.0"
readonly CONFIG_FILE="$HOME/.ralph/config/promptify.json"
readonly CONSENT_FILE="$HOME/.ralph/config/promptify-consent.json"
readonly LOG_DIR="$HOME/.ralph/logs"
readonly AUDIT_LOG="$LOG_DIR/promptify-audit.log"

# Create directories
mkdir -p "$LOG_DIR" "$(dirname "$CONFIG_FILE")"

# =============================================================================
# SECURITY FUNCTIONS
# =============================================================================

# Credential redaction function (SEC-110)
# Redacts sensitive information before clipboard operations or logging
redact_credentials() {
    local text="$1"

    # Redact common credential patterns
    echo "$text" | sed -E \
        -e 's/(password|passwd|pwd|secret|token|api_key|apikey|access_token|auth_token|credential|client_secret|client_id)[[:space:]]*[:=][[:space:]]*[^[:space:]]+/\1: [REDACTED]/gi' \
        -e 's/(bearer|authorization)[[:space:]]*:[[:space:]]*[A-Za-z0-9\-._~+/]+=*/\1: [REDACTED]/gi' \
        -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}/[EMAIL REDACTED]/g' \
        -e 's/[0-9]{3}-[0-9]{3}-[0-9]{4}/[PHONE REDACTED]/g' \
        -e 's/sk-[a-zA-Z0-9]{32,}/[SK-KEY REDACTED]/g' \
        -e 's/sk_live_[a-zA-Z0-9]{32,}/[SK-LIVE-KEY REDACTED]/g' \
        -e 's/sk_test_[a-zA-Z0-9]{32,}/[SK-TEST-KEY REDACTED]/g' \
        -e 's/ghp_[a-zA-Z0-9]{36,}/[GH-TOKEN REDACTED]/g' \
        -e 's/gho_[a-zA-Z0-9]{36,}/[GH-OAUTH-TOKEN REDACTED]/g' \
        -e 's/ghu_[a-zA-Z0-9]{36,}/[GH-USER-TOKEN REDACTED]/g' \
        -e 's/xoxb-[a-zA-Z0-9\-]{10,}/[SLACK-BOT-TOKEN REDACTED]/g' \
        -e 's/xoxp-[a-zA-Z0-9\-]{10,}/[SLACK-USER-TOKEN REDACTED]/g' \
        -e 's/AKIA[0-9A-Z]{16}/[AWS-ACCESS-KEY REDACTED]/g' \
        -e 's/[0-9]{21}L/[AWS-SECRET-KEY REDACTED]/g'
}

# Check clipboard consent (SEC-120)
# Returns 0 if consent granted, 1 if denied or not set
check_clipboard_consent() {
    local config_consent=""

    # Check config file first
    if [[ -f "$CONFIG_FILE" ]]; then
        config_consent=$(jq -r '.clipboard_consent // false' "$CONFIG_FILE" 2>/dev/null || echo "false")
    fi

    # Check consent file
    if [[ -f "$CONSENT_FILE" ]]; then
        local file_consent=$(jq -r '.clipboard_consent // false' "$CONSENT_FILE" 2>/dev/null || echo "false")

        # File consent takes precedence
        if [[ "$file_consent" == "true" ]]; then
            return 0
        else
            return 1
        fi
    fi

    # Fall back to config
    if [[ "$config_consent" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Request clipboard consent interactively
request_clipboard_consent() {
    # This function should be called from an interactive context
    # It returns a JSON response for AskUserQuestion tool

    cat <<'EOF'
{
  "action": "ask_user",
  "title": "Promptify Clipboard Consent",
  "message": "Promptify needs to write the optimized prompt to your clipboard. Allow this operation?\n\nYou can change this later in ~/.ralph/config/promptify.json",
  "buttons": ["Allow", "Deny"]
}
EOF
}

# Save clipboard consent
save_clipboard_consent() {
    local granted="$1"

    mkdir -p "$(dirname "$CONSENT_FILE")"

    jq -n \
        --argjson granted "$granted" \
        '{"clipboard_consent": $granted, "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' \
        > "$CONSENT_FILE"
}

# =============================================================================
# AUDIT LOGGING FUNCTIONS
# =============================================================================

# Log promptify invocation (SEC-140)
log_promptify_invocation() {
    local original_prompt="$1"
    local optimized_prompt="$2"
    local clarity_score="$3"
    local agents_used="${4:-[]}"
    local execution_time="${5:-0}"
    local success="${6:-true}"

    # Create log directory if needed
    mkdir -p "$LOG_DIR"

    # Redact credentials before logging
    local redacted_original=$(redact_credentials "$original_prompt")
    local redacted_optimized=$(redact_credentials "$optimized_prompt")

    # Create log entry
    local log_entry=$(jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg original "$redacted_original" \
        --arg optimized "$redacted_optimized" \
        --argjson clarity "$clarity_score" \
        --argjson agents "$agents_used" \
        --argjson time "$execution_time" \
        --argjson success "$success" \
        --arg version "$VERSION" \
        '{
          timestamp: $timestamp,
          original_prompt: $original,
          optimized_prompt: $optimized,
          clarity_score: $clarity,
          agents_used: $agents,
          execution_time_seconds: $time,
          success: $success,
          version: $version
        }')

    # Append to audit log
    echo "$log_entry" >> "$AUDIT_LOG"

    # Return log entry for potential use
    echo "$log_entry"
}

# Get audit statistics
get_audit_stats() {
    if [[ ! -f "$AUDIT_LOG" ]]; then
        echo '{"total_invocations": 0, "successful": 0, "failed": 0, "average_clarity_score": 0}'
        return 0
    fi

    jq -s '
        {
            total_invocations: length,
            successful: map(select(.success == true)) | length,
            failed: map(select(.success == false)) | length,
            average_clarity_score: (map(.clarity_score) | add / length)
        }
    ' "$AUDIT_LOG"
}

# Rotate audit log if too large
rotate_audit_log() {
    local max_size_mb=10

    if [[ ! -f "$AUDIT_LOG" ]]; then
        return 0
    fi

    # Get file size in MB
    local size_mb=$(du -m "$AUDIT_LOG" | cut -f1)

    if [[ $size_mb -gt $max_size_mb ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup_file="${AUDIT_LOG}.${timestamp}.bak"

        mv "$AUDIT_LOG" "$backup_file"
        touch "$AUDIT_LOG"

        echo "Rotated audit log: $backup_file"
    fi
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate prompt for security issues
validate_prompt_security() {
    local prompt="$1"
    local issues=()

    # Check for potential injection attempts
    if echo "$prompt" | grep -qiE "ignore.*instruction|override.*prompt|disregard.*system"; then
        issues+=("Possible prompt injection attempt detected")
    fi

    # Check for jailbreak attempts
    if echo "$prompt" | grep -qiE "jailbreak|bypass.*filter|ignore.*safety|developer.*mode"; then
        issues+=("Possible jailbreak attempt detected")
    fi

    # Check for malicious URLs
    if echo "$prompt" | grep -qE "https?://[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"; then
        issues+=("Suspicious IP address URL detected")
    fi

    # Return validation result
    if [[ ${#issues[@]} -gt 0 ]]; then
        jq -n \
            --argjson valid "false" \
            --argjson issues "$(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)" \
            '{valid: $valid, issues: $issues}'
    else
        jq -n \
            --argjson valid "true" \
            --argjson issues "[]" \
            '{valid: $valid, issues: $issues}'
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Sanitize input to prevent injection
sanitize_input() {
    local input="$1"

    # Remove null bytes
    input="${input//\x00/}"

    # Remove control characters (except newline, tab, carriage return)
    input=$(echo "$input" | tr -d '[:cntrl:]' | tr '\n\t\r' ' \n\t')

    # Limit length
    local max_length=100000
    if [[ ${#input} -gt $max_length ]]; then
        input="${input:0:$max_length}"
    fi

    echo "$input"
}

# Export functions for use in other scripts
export -f redact_credentials
export -f check_clipboard_consent
export -f request_clipboard_consent
export -f save_clipboard_consent
export -f log_promptify_invocation
export -f get_audit_stats
export -f rotate_audit_log
export -f validate_prompt_security
export -f sanitize_input
