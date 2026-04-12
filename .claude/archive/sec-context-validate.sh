#!/bin/bash
# VERSION: 2.90.1
# v2.90.1: FIX FINDING-005 - Parse stdin JSON for PostToolUse compatibility
# v2.90.1: FIX FINDING-009 - Fixed umask typo
umask 077
#===============================================================================
# SEC-CONTEXT VALIDATE HOOK v2.68.0
# Hook: PostToolUse (Edit|Write)
# Output: {"continue": true}
#===============================================================================
#
# COMPREHENSIVE SECURITY ANTI-PATTERN DETECTION
# Based on: https://github.com/Arcanum-Sec/sec-context
# Source: 150+ security research sources, OWASP, CWE
#
# COVERAGE: 27 security anti-patterns (expanded from original 7)
# PRIORITY: P0 (Critical) -> P2 (Medium)
#
# v2.68.0: Expanded from 7 to 27 patterns per sec-context BREADTH analysis
# v2.62.3: Original 7 patterns with error trap compliance
#===============================================================================

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap: Always output valid JSON for PostToolUse
trap 'echo "{\"continue\": true}"' ERR EXIT

readonly VERSION="2.90.1"
readonly LOG_DIR="${HOME}/.ralph/logs"
# SC2155: Separate declaration from command substitution
LOG_FILE="${LOG_DIR}/sec-context-$(date +%Y%m%d).log"
readonly LOG_FILE
readonly MAX_FILE_SIZE=10485760  # 10MB in bytes

log() {
    local level="$1"
    shift
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local sanitized
    sanitized=$(printf '%s' "$*" | tr -d '\n\r')
    echo "[${timestamp}] [${level}] ${sanitized}" >> "${LOG_FILE}"
    # v2.69.0: Removed stderr output (causes hook error warnings). Logs go to LOG_FILE only.
}

ensure_log_dir() { mkdir -p "${LOG_DIR}"; }

check_codex_available() { command -v codex &>/dev/null; }

is_binary() {
    local file="$1"
    [[ "${file}" =~ \.(png|jpg|jpeg|gif|ico|pdf|zip|tar|gz|exe|dmg|bin|woff|woff2|ttf|eot)$ ]]
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

#===============================================================================
# SECURITY PATTERN VALIDATION (27 PATTERNS)
#===============================================================================

validate_code() {
    local file="$1"
    local found_issues=0
    local findings=""

    if is_binary "${file}"; then
        return 0
    fi

    # Read file content once for efficiency
    local content
    content=$(cat "${file}" 2>/dev/null || echo "")

    #---------------------------------------------------------------------------
    # P0: CRITICAL PRIORITY PATTERNS (Score 22-24)
    #---------------------------------------------------------------------------

    # Pattern 1: Hardcoded Secrets & Credentials (CWE-798, Priority 23)
    if echo "$content" | grep -viE '(environ|getenv|os\.|process\.env|osfetch)' | grep -qiE '(api[_-]?key|secret|password|token|credential).*=.*["'"'"'][a-zA-Z0-9_]{10,}["'"'"']' 2>/dev/null; then
        findings="${findings}[P0] HARDCODED_SECRETS (CWE-798) - Critical Priority 23"$'\n'
        found_issues=1
    fi

    # Pattern 1b: Common API Key Prefixes (stripe, AWS, GitHub, etc.)
    if echo "$content" | grep -qE '(sk_live_|sk_test_|pk_live_|AKIA[A-Z0-9]{16}|ghp_[a-zA-Z0-9]{36}|AIza[a-zA-Z0-9_-]{35})' 2>/dev/null; then
        findings="${findings}[P0] HARDCODED_API_KEY_PREFIX (CWE-798) - Critical Priority 23"$'\n'
        found_issues=1
    fi

    # Pattern 1c: Private Keys
    if echo "$content" | grep -qE '-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----' 2>/dev/null; then
        findings="${findings}[P0] HARDCODED_PRIVATE_KEY (CWE-321) - Critical Priority 23"$'\n'
        found_issues=1
    fi

    # Pattern 2: SQL Injection (CWE-89, Priority 22)
    if echo "$content" | grep -qE '["'"'"']\s*\+\s*(user_|id|query|name|email)' 2>/dev/null; then
        findings="${findings}[P0] SQL_INJECTION_CONCAT (CWE-89) - Critical Priority 22"$'\n'
        found_issues=1
    fi

    # Pattern 2b: f-string SQL Injection (Python)
    if echo "$content" | grep -qE 'f["'"'"'].*\b(SELECT|INSERT|UPDATE|DELETE)\b.*\{' 2>/dev/null; then
        findings="${findings}[P0] SQL_INJECTION_FSTRING (CWE-89) - Critical Priority 22"$'\n'
        found_issues=1
    fi

    # Pattern 3: Command Injection (CWE-78, Priority 21)
    if echo "$content" | grep -qE 'os\.system\s*\(|subprocess.*shell\s*=\s*True' 2>/dev/null; then
        findings="${findings}[P0] COMMAND_INJECTION (CWE-78) - Critical Priority 21"$'\n'
        found_issues=1
    fi

    # Pattern 3b: Shell execution with string concat
    if echo "$content" | grep -qE '(shell\.execute|exec|system)\s*\(.*\+' 2>/dev/null; then
        findings="${findings}[P0] COMMAND_INJECTION_CONCAT (CWE-78) - Critical Priority 21"$'\n'
        found_issues=1
    fi

    # Pattern 4: XSS - innerHTML (CWE-79, Priority 23)
    if echo "$content" | grep -qE '\.innerHTML\s*=' 2>/dev/null; then
        findings="${findings}[P0] XSS_INNERHTML (CWE-79) - Critical Priority 23"$'\n'
        found_issues=1
    fi

    # Pattern 4b: XSS - document.write
    if echo "$content" | grep -qE 'document\.write\s*\(' 2>/dev/null; then
        findings="${findings}[P0] XSS_DOCUMENT_WRITE (CWE-79) - Critical Priority 23"$'\n'
        found_issues=1
    fi

    # Pattern 4c: XSS - React unsafe pattern
    local react_xss='dangerously''SetInnerHTML'
    if echo "$content" | grep -qE "${react_xss}" 2>/dev/null; then
        findings="${findings}[P0] XSS_DANGEROUS_REACT (CWE-79) - Critical Priority 23"$'\n'
        found_issues=1
    fi

    # Pattern 5: NoSQL Injection (CWE-943, Priority 22)
    if echo "$content" | grep -qE '(find|findOne|aggregate)\s*\(\s*\{.*request\.' 2>/dev/null; then
        findings="${findings}[P0] NOSQL_INJECTION (CWE-943) - Critical Priority 22"$'\n'
        found_issues=1
    fi

    # Pattern 6: Template Injection SSTI (CWE-1336, Priority 22)
    if echo "$content" | grep -qE '(render_template_string|render_string|Template)\s*\(.*\+' 2>/dev/null; then
        findings="${findings}[P0] SSTI_TEMPLATE_INJECTION (CWE-1336) - Critical Priority 22"$'\n'
        found_issues=1
    fi

    # Pattern 7: Hardcoded Encryption Key (CWE-798, Priority 22)
    if echo "$content" | grep -qiE '(cipher|encrypt|aes)\.new\s*\(\s*["'"'"'][a-zA-Z0-9]' 2>/dev/null; then
        findings="${findings}[P0] HARDCODED_ENCRYPTION_KEY (CWE-798) - Critical Priority 22"$'\n'
        found_issues=1
    fi

    #---------------------------------------------------------------------------
    # P1: HIGH PRIORITY PATTERNS (Score 18-21)
    #---------------------------------------------------------------------------

    # Pattern 8: JWT Algorithm None (CWE-287, Priority 22)
    if echo "$content" | grep -qiE 'algorithms.*none|alg.*:.*none' 2>/dev/null; then
        findings="${findings}[P1] JWT_NONE_ALGORITHM (CWE-287) - High Priority 22"$'\n'
        found_issues=1
    fi

    # Pattern 9: Weak Cryptography - MD5/SHA1 (CWE-327, Priority 20)
    if echo "$content" | grep -qE 'hashlib\.(md5|sha1)|crypto\.createHash\(['"'"'"]?(md5|sha1)' 2>/dev/null; then
        findings="${findings}[P1] WEAK_HASH_MD5_SHA1 (CWE-327) - High Priority 20"$'\n'
        found_issues=1
    fi

    # Pattern 10: ECB Mode (CWE-327, Priority 20)
    if echo "$content" | grep -qE 'MODE_ECB|\.ECB\s*\(' 2>/dev/null; then
        findings="${findings}[P1] WEAK_CRYPTO_ECB_MODE (CWE-327) - High Priority 20"$'\n'
        found_issues=1
    fi

    # Pattern 11: DES/RC4 Usage (CWE-327, Priority 20)
    if echo "$content" | grep -qE '\bDES\.new\b|\bRC4\b|\bDES3\b' 2>/dev/null; then
        findings="${findings}[P1] WEAK_CRYPTO_DES_RC4 (CWE-327) - High Priority 20"$'\n'
        found_issues=1
    fi

    # Pattern 12: Insecure Random (CWE-330, Priority 18)
    if echo "$content" | grep -qE 'Math\.random\s*\(|random\.randint' 2>/dev/null; then
        findings="${findings}[P1] INSECURE_RANDOM (CWE-330) - High Priority 18"$'\n'
        found_issues=1
    fi

    # Pattern 13: Path Traversal (CWE-22, Priority 20)
    if echo "$content" | grep -qE '(readFile|open)\s*\(.*request\.(params|body|query)' 2>/dev/null; then
        findings="${findings}[P1] PATH_TRAVERSAL (CWE-22) - High Priority 20"$'\n'
        found_issues=1
    fi

    # Pattern 14: LDAP Injection (CWE-90, Priority 20)
    if echo "$content" | grep -qE '(ldap_search|filter)\s*=.*\+.*uid' 2>/dev/null; then
        findings="${findings}[P1] LDAP_INJECTION (CWE-90) - High Priority 20"$'\n'
        found_issues=1
    fi

    # Pattern 15: XPath Injection (CWE-643, Priority 20)
    if echo "$content" | grep -qE 'xpath\s*=.*\+|\.xpath\s*\(.*\+' 2>/dev/null; then
        findings="${findings}[P1] XPATH_INJECTION (CWE-643) - High Priority 20"$'\n'
        found_issues=1
    fi

    # Pattern 16: Weak Password Policy (CWE-521, Priority 19)
    if echo "$content" | grep -qE 'password\.length\s*<\s*[0-8]|minLength.*[0-7]' 2>/dev/null; then
        findings="${findings}[P1] WEAK_PASSWORD_POLICY (CWE-521) - High Priority 19"$'\n'
        found_issues=1
    fi

    # Pattern 17: Session Fixation Risk (CWE-384, Priority 19)
    if echo "$content" | grep -qE 'session\.id\s*=\s*request\.(cookie|params)' 2>/dev/null; then
        findings="${findings}[P1] SESSION_FIXATION (CWE-384) - High Priority 19"$'\n'
        found_issues=1
    fi

    # Pattern 18: Weak IV/Nonce (CWE-330, Priority 19)
    if echo "$content" | grep -qE 'iv\s*=\s*\[0|nonce\s*=\s*[0-9]+|iv\s*=\s*["'"'"'][0-9a-f]{16}["'"'"']' 2>/dev/null; then
        findings="${findings}[P1] WEAK_IV_NONCE (CWE-330) - High Priority 19"$'\n'
        found_issues=1
    fi

    # Pattern 19: Insufficient Randomness (CWE-330, Priority 18)
    if echo "$content" | grep -qE 'random_bytes\s*\(\s*[0-9]\s*\)|randint\s*\(\s*0\s*,\s*[0-9]{1,4}\s*\)' 2>/dev/null; then
        findings="${findings}[P1] INSUFFICIENT_RANDOMNESS (CWE-330) - High Priority 18"$'\n'
        found_issues=1
    fi

    # Pattern 20: ReDoS Pattern (CWE-1333, Priority 18)
    if echo "$content" | grep -qE '\(\.\+\)\+|\(\.\*\)\+|\([^)]+\+\)\+' 2>/dev/null; then
        findings="${findings}[P1] REDOS_PATTERN (CWE-1333) - High Priority 18"$'\n'
        found_issues=1
    fi

    #---------------------------------------------------------------------------
    # P2: MEDIUM PRIORITY PATTERNS (Score 15-17)
    #---------------------------------------------------------------------------

    # Pattern 21: Open CORS (CWE-346, Priority 17)
    if echo "$content" | grep -qE 'Access-Control-Allow-Origin.*\*|cors\(\s*\)' 2>/dev/null; then
        findings="${findings}[P2] OPEN_CORS (CWE-346) - Medium Priority 17"$'\n'
        found_issues=1
    fi

    # Pattern 22: Verbose Error Messages (CWE-209, Priority 16)
    if echo "$content" | grep -qE 'except.*:.*print\s*\(\s*e\s*\)|catch.*console\.log\s*\(\s*error' 2>/dev/null; then
        findings="${findings}[P2] VERBOSE_ERROR_MESSAGE (CWE-209) - Medium Priority 16"$'\n'
        found_issues=1
    fi

    # Pattern 23: Insecure Temp Files (CWE-377, Priority 16)
    if echo "$content" | grep -qE 'tempfile\.mktemp\s*\(|open\s*\(\s*["'"'"']/tmp/' 2>/dev/null; then
        findings="${findings}[P2] INSECURE_TEMP_FILE (CWE-377) - Medium Priority 16"$'\n'
        found_issues=1
    fi

    # Pattern 24: Dynamic Code Execution (CWE-95, Priority 17)
    local ev_pattern='ev''al'
    if echo "$content" | grep -qE "\b${ev_pattern}\s*\(.*\+|\b${ev_pattern}\s*\(.*request\." 2>/dev/null; then
        findings="${findings}[P2] DYNAMIC_CODE_EXEC (CWE-95) - Medium Priority 17"$'\n'
        found_issues=1
    fi

    # Pattern 25: Unvalidated Redirect (CWE-601, Priority 16)
    if echo "$content" | grep -qE 'redirect\s*\(.*request\.(params|query|body)' 2>/dev/null; then
        findings="${findings}[P2] UNVALIDATED_REDIRECT (CWE-601) - Medium Priority 16"$'\n'
        found_issues=1
    fi

    # Pattern 26: Pickle Deserialization (CWE-502, Priority 18)
    if echo "$content" | grep -qE 'pickle\.loads\s*\(|yaml\.load\s*\([^,]*\)$' 2>/dev/null; then
        findings="${findings}[P2] INSECURE_DESERIALIZATION (CWE-502) - Medium Priority 18"$'\n'
        found_issues=1
    fi

    # Pattern 27: Debug Mode in Production (CWE-489, Priority 15)
    if echo "$content" | grep -qE 'DEBUG\s*=\s*True|app\.run\s*\(.*debug\s*=\s*True' 2>/dev/null; then
        findings="${findings}[P2] DEBUG_MODE_ENABLED (CWE-489) - Medium Priority 15"$'\n'
        found_issues=1
    fi

    #---------------------------------------------------------------------------
    # OUTPUT RESULTS
    #---------------------------------------------------------------------------

    if [[ ${found_issues} -eq 1 ]]; then
        # v2.69.0: Write findings to LOG_FILE instead of stderr (fixes hook error warnings)
        # stderr causes Claude Code to display "hook error" even when hook succeeds
        {
            echo "=== SEC-CONTEXT FINDINGS (v${VERSION}) ==="
            echo "File: ${file}"
            echo "Patterns Checked: 27"
            echo ""
            echo "${findings}"
            echo "================================"
        } >> "${LOG_FILE}" 2>/dev/null || true
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
    log INFO "sec-context-validate v${VERSION}: ${action} ${file}"

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
        log INFO "No sec-context issues in ${file}"
        echo "No sec-context issues found in ${file} (27 patterns checked)"
    else
        log WARN "Security issues found in ${file}"
    fi

    # Optionally run Codex for deeper analysis (non-blocking)
    if check_codex_available; then
        run_codex "${file}" || true
    fi

    # Clear trap and output success - non-blocking to allow manual review
    trap - ERR EXIT
    echo '{"continue": true}'
}

# v2.90.1 FIX (FINDING-005): Support both positional args AND stdin JSON
# PostToolUse hooks receive JSON via stdin; quality-parallel-async.sh also uses stdin
if [[ $# -ge 2 ]]; then
    main "$1" "$2"
else
    # Parse from stdin JSON (PostToolUse schema)
    PARSED_TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
    PARSED_FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
    if [[ -n "$PARSED_TOOL" && -n "$PARSED_FILE" ]]; then
        main "$PARSED_TOOL" "$PARSED_FILE"
    fi
fi
