#!/bin/bash
#!/usr/bin/env bash
# Security Real Audit Hook - Actual security analysis
# Set secure permissionsnumask 077
# VERSION: 2.83.1
# Timestamp: 2026-01-30
# Purpose: Perform real security pattern matching on files
#
# v2.83.1: PERF-004 - Added structured JSON logging
# FIX v1.0.2: CRITICAL - Removed plain text output before JSON
# FIX v1.0.1: LOW-003 - Added consistent error handling with JSON output

set -euo pipefail

# Log file for security audit messages
LOG_FILE="${RALPH_LOGS:-$HOME/.ralph/logs}/security-audit.log"
LOG_FILE_JSON="${LOG_FILE}.jsonl"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

# PERF-004: JSON structured logging function
log_json() {
    local level="$1"
    local message="$2"
    local hook_name="${0##*/}"
    jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg lvl "$level" \
        --arg hook "$hook_name" \
        --arg msg "$message" \
        '{timestamp: $ts, level: $lvl, hook: $hook, message: $msg}' \
        >> "$LOG_FILE_JSON" 2>/dev/null || true
}

# LOW-003 FIX: Error trap ensures valid JSON output on failure
trap 'echo "{\"continue\": true}"' ERR EXIT

readonly VERSION="1.0.0"

# Read stdin with SEC-111 protection (100KB limit)
INPUT=$(head -c 100000)

# Parse input - CRITICAL FIX: Use correct PostToolUse field names
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only run on Edit/Write operations
if [[ ! "$TOOL_NAME" =~ ^(Edit|Write)$ ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Skip if no file path
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Security patterns to check (P0, P1, P2)
PATTERNS=(
    # P0 - Critical
    "sk-[a-zA-Z0-9]{32}"           # API keys
    "sk_live_[a-zA-Z0-9]{32}"      # Stripe live keys
    "AKIA[0-9A-Z]{16}"             # AWS access keys
    "password.*=.*['\"].*['\"]"    # Hardcoded passwords
    "api_key.*=.*['\"].*['\"]"     # API keys in variables
    "secret.*=.*['\"].*['\"]"       # Secrets in variables
    "token.*=.*['\"].*['\"]"       # Tokens in variables

    # P0 - Injection
    "SELECT.*WHERE.*\+"            # SQL injection
    "eval\("                       # Code execution
    "exec\("                       # Command execution
    "system\("                     # Command execution
    "innerHTML"                    # XSS risk (in JS files)
    "document\.write"              # XSS risk

    # P1 - High
    "md5\("                        # Weak hashing
    "sha1\("                       # Weak hashing
    "ecb"                          # ECB mode encryption
    "none"                         # None algorithm in JWT

    # P2 - Medium
    "TODO.*security"               # Security TODOs
    "FIXME.*security"              # Security FIXMEs
    "HACK.*security"               # Security hacks
)

FINDINGS=0
MATCHING_PATTERNS=()

for pattern in "${PATTERNS[@]}"; do
    if grep -qiE "$pattern" "$FILE_PATH" 2>/dev/null; then
        FINDINGS=$((FINDINGS + 1))
        MATCHING_PATTERNS+=("$pattern")
    fi
done

# Output findings to log file (not stdout - must be valid JSON only)
{
    echo "[$(date -Iseconds)] Security Audit: $FILE_PATH"
    if [[ $FINDINGS -gt 0 ]]; then
        echo "  Found $FINDINGS potential security issues:"
        for pattern in "${MATCHING_PATTERNS[@]}"; do
            echo "    - Pattern: $pattern"
        done
    else
        echo "  No obvious security issues found"
    fi
} >> "$LOG_FILE" 2>/dev/null || true

# PERF-004: Structured JSON logging
if [[ $FINDINGS -gt 0 ]]; then
    log_json "WARN" "Security audit found $FINDINGS issues in $FILE_PATH"
    for pattern in "${MATCHING_PATTERNS[@]}"; do
        log_json "WARN" "Security pattern match: $pattern"
    done
else
    log_json "INFO" "Security audit passed for $FILE_PATH"
fi

# LOW-003 FIX: Clear trap before normal exit to prevent duplicate JSON
trap - ERR EXIT
echo '{"continue": true}'
