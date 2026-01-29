#!/usr/bin/env bash
# Security Real Audit Hook - Actual security analysis
# VERSION: 1.0.1
# Purpose: Perform real security pattern matching on files
#
# FIX v1.0.1: LOW-003 - Added consistent error handling with JSON output

set -euo pipefail

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

# Output findings
if [[ $FINDINGS -gt 0 ]]; then
    echo "🔒 Security Audit: Found $FINDINGS potential security issues"
    for pattern in "${MATCHING_PATTERNS[@]}"; do
        echo "  - Pattern: $pattern"
    done
else
    echo "✅ Security Audit: No obvious security issues found"
fi

# LOW-003 FIX: Clear trap before normal exit to prevent duplicate JSON
trap - ERR EXIT
echo '{"continue": true}'
