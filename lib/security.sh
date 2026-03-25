#!/usr/bin/env bash
# lib/security.sh - Security utilities for Ralph CLI
# Extracted from scripts/ralph security functions
#
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../lib/security.sh"

[[ -n "${_RALPH_LIB_SECURITY_LOADED:-}" ]] && return 0
_RALPH_LIB_SECURITY_LOADED=1

# SECURITY: Ensure created files are user-only by default (VULN-008)
umask 077

# ═══════════════════════════════════════════════════════════════════════════════
# TEMP DIRECTORY (secure, unpredictable)
# ═══════════════════════════════════════════════════════════════════════════════
init_secure_tmpdir() {
    local tmpdir
    tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/ralph.XXXXXXXXXXXXXXXX") || {
        echo "FATAL: Cannot create secure temp directory" >&2
        exit 1
    }
    echo "$tmpdir"
}

# ═══════════════════════════════════════════════════════════════════════════════
# PATH VALIDATION (prevent path traversal, command injection)
# ═══════════════════════════════════════════════════════════════════════════════
validate_path() {
    local input="$1"
    local purpose="${2:-file access}"

    # Block command substitution before any expansion
    if [[ "$input" == *'$('* ]] || [[ "$input" == *'`'* ]]; then
        log_security "BLOCKED" "Command substitution in path" "$purpose" "$input"
        return 1
    fi

    # Block null bytes (use printf to detect; bash strips them from variables)
    if printf '%s' "$input" | grep -qP '\x00' 2>/dev/null; then
        log_security "BLOCKED" "Null byte in path" "$purpose" "$input"
        return 1
    fi

    # Block path traversal (realpath -m is GNU-only; use -e or fallback)
    local resolved
    resolved=$(realpath "$input" 2>/dev/null || echo "$input")

    if [[ "$resolved" == *".."* ]]; then
        log_security "BLOCKED" "Path traversal attempt" "$purpose" "$input"
        return 1
    fi

    echo "$resolved"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# TEXT INPUT VALIDATION (for non-path user inputs)
# ═══════════════════════════════════════════════════════════════════════════════
validate_text_input() {
    local input="$1"
    local purpose="${2:-text input}"
    local max_length="${3:-10000}"

    # Length check
    if [[ ${#input} -gt $max_length ]]; then
        log_security "BLOCKED" "Input exceeds max length ($max_length)" "$purpose" "${input:0:50}..."
        return 1
    fi

    # Block command substitution
    if [[ "$input" == *'$('* ]] || [[ "$input" == *'`'* ]]; then
        log_security "BLOCKED" "Command substitution in text" "$purpose" "${input:0:50}..."
        return 1
    fi

    # Block null bytes
    if printf '%s' "$input" | grep -qP '\x00' 2>/dev/null; then
        log_security "BLOCKED" "Null byte in text" "$purpose" "${input:0:50}..."
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════════
# SHELL ESCAPING (prevent injection in constructed commands)
# ═══════════════════════════════════════════════════════════════════════════════
escape_for_shell() {
    printf '%q' "$1"
}

# ═══════════════════════════════════════════════════════════════════════════════
# SECURITY EVENT LOGGING
# ═══════════════════════════════════════════════════════════════════════════════
log_security() {
    local action="$1"
    local reason="$2"
    local context="${3:-}"
    local detail="${4:-}"
    local log_file="${RALPH_HOME:-${HOME}/.ralph}/security-audit.log"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # Structured JSON log entry
    local entry
    entry=$(printf '{"timestamp":"%s","action":"%s","reason":"%s","context":"%s","detail":"%s","pid":%d}\n' \
        "$timestamp" "$action" "$reason" "$context" "${detail:0:200}" "$$")

    echo "$entry" >> "$log_file" 2>/dev/null || true
}
