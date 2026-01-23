#!/bin/bash
#===============================================================================
# SEC-CONTEXT VALIDATE HOOK v2.62.3
# Hook: PostToolUse (Edit|Write)
# Output: {"continue": true}
#===============================================================================

set -euo pipefail

# Error trap: Always output valid JSON for PostToolUse
trap 'echo "{\"continue\": true}"' ERR EXIT

readonly VERSION="2.62.3"
readonly LOG_DIR="${HOME}/.ralph/logs"
readonly LOG_FILE="${LOG_DIR}/sec-context-$(date +%Y%m%d).log"
readonly MAX_FILE_SIZE=10485760  # 10MB in bytes

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local sanitized
    sanitized=$(printf '%s' "$*" | tr -d '\n\r')
    echo "[${timestamp}] [${level}] ${sanitized}" >> "${LOG_FILE}"
    echo "sec-context:[${level}] ${sanitized}" >&2
}

ensure_log_dir() { mkdir -p "${LOG_DIR}"; }

check_codex_available() { command -v codex &>/dev/null; }

is_binary() {
    local file="$1"
    [[ "${file}" =~ \.(png|jpg|jpeg|gif|ico|pdf|zip|tar|gz|exe|dmg|bin)$ ]]
}

is_valid_file() {
    local file="$1"
    [[ -n "${file}" && -f "${file}" && -r "${file}" ]]
}

get_file_size() {
    local file="$1"
    stat -f%z "${file}" 2>/dev/null || stat -c%s "${file}" 2>/dev/null || echo 0
}

is_file_too_large() {
    local file="$1"
    local size
    size=$(get_file_size "${file}")
    [[ ${size} -gt ${MAX_FILE_SIZE} ]]
}

validate_code() {
    local file="$1"
    local found_issues=0
    local findings=""
    
    if is_binary "${file}"; then
        return 0
    fi
    
    # Pattern 1: Hardcoded secrets (case-insensitive, 10+ chars, exclude variable refs)
    # Skip lines with environ, getenv, os. or osfetch to avoid false positives on variable references
    if grep -viE '(environ|getenv|os\.|osfetch)' "${file}" 2>/dev/null | grep -qiE '(api[_-]?key|secret|password|token).*=.*["'"'"'][a-zA-Z0-9_]{10,}["'"'"']' 2>/dev/null; then
        findings="${findings}HARDCODED_SECRETS - Critical Priority 23"$'\n'
        found_issues=1
    fi
    
    # Pattern 2: SQL Injection
    if grep -qE '["'"'"']\s*\+\s*(user_|id|query)' "${file}" 2>/dev/null; then
        findings="${findings}SQL_INJECTION - High Priority 22"$'\n'
        found_issues=1
    fi
    
    # Pattern 3: XSS
    if grep -qE '\.innerHTML\s*=' "${file}" 2>/dev/null; then
        findings="${findings}XSS - Critical Priority 23"$'\n'
        found_issues=1
    fi
    
    # Pattern 4: Command Injection
    if grep -qE 'os\.system\s*\(|subprocess.*shell.*True' "${file}" 2>/dev/null; then
        findings="${findings}COMMAND_INJECTION - High Priority 22"$'\n'
        found_issues=1
    fi
    
    # Pattern 5: JWT issues
    if grep -qE 'algorithms.*none' "${file}" 2>/dev/null; then
        findings="${findings}JWT_NONE_ALGORITHM - High Priority 22"$'\n'
        found_issues=1
    fi
    
    # Pattern 6: Weak cryptography
    if grep -qE 'hashlib\.(md5|sha1)' "${file}" 2>/dev/null; then
        findings="${findings}WEAK_CRYPTO_MD5 - High Priority 20"$'\n'
        found_issues=1
    fi
    if grep -qE 'AES\.MODE_ECB' "${file}" 2>/dev/null; then
        findings="${findings}WEAK_CRYPTO_ECB - High Priority 20"$'\n'
        found_issues=1
    fi
    
    # Pattern 7: Insecure random
    if grep -qE 'Math\.random' "${file}" 2>/dev/null; then
        findings="${findings}INSECURE_RANDOM - Medium Priority 18"$'\n'
        found_issues=1
    fi
    
    if [[ ${found_issues} -eq 1 ]]; then
        echo "=== SEC-CONTEXT FINDINGS ==="
        echo "File: ${file}"
        echo "${findings}"
        echo "============================"
        return 1
    fi
    
    return 0
}

run_codex() {
    local file="$1"
    if check_codex_available; then
        log INFO "Running Codex on ${file}"
        codex review "Security analysis of ${file}" >/dev/null 2>&1 || log WARN "Codex found issues"
    fi
}

main() {
    local action="${1:-}"
    local file="${2:-}"
    
    ensure_log_dir
    log INFO "sec-context-validate: ${action} ${file}"
    
    if [[ "${action}" != "Edit" && "${action}" != "Write" ]]; then
        exit 0
    fi
    
    if ! is_valid_file "${file}"; then
        log INFO "Invalid file: ${file}"
        exit 0
    fi
    
    if is_file_too_large "${file}"; then
        log INFO "File too large: ${file}"
        exit 0
    fi
    
    if validate_code "${file}"; then
        log INFO "No issues in ${file}"
        echo "No sec-context issues found in ${file}"
    else
        log WARN "Issues found in ${file}"
    fi

    # Optionally run Codex for deeper analysis (non-blocking)
    if check_codex_available; then
        run_codex "${file}" || true
    fi

    # Exit based on validation result
    if validate_code "${file}" 2>/dev/null; then
        echo '{"continue": true}'
        exit 0
    else
        echo '{"continue": false}'
        exit 1
    fi
}

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <action> <file_path>" >&2
    exit 0
fi

main "$1" "$2"
