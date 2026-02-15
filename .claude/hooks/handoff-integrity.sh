#!/usr/bin/env bash
# handoff-integrity.sh - SHA-256 checksum library for handoffs and ledgers
# VERSION: 2.89.0
# PURPOSE: Integrity validation for handoff/ledger files
# FINDING: HIGH-003 - Prevent tampered handoff injection
#
# Usage:
#   source handoff-integrity.sh
#   handoff_create_checksum "/path/to/file"    # Creates .sha256 sidecar
#   handoff_verify_checksum "/path/to/file"     # Returns 0 if valid, 1 if tampered
#   handoff_sanitize_content "content"           # Removes control chars and injection patterns

# Create SHA-256 checksum sidecar file for a given file
handoff_create_checksum() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    local checksum_file="${file}.sha256"
    shasum -a 256 "$file" | awk '{print $1}' > "$checksum_file"
    return 0
}

# Verify SHA-256 checksum of a file against its sidecar
# Returns 0 if valid, 1 if tampered or missing checksum
handoff_verify_checksum() {
    local file="$1"
    local checksum_file="${file}.sha256"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    if [[ ! -f "$checksum_file" ]]; then
        # No checksum file - treat as untrusted
        return 1
    fi

    local expected
    expected=$(cat "$checksum_file" 2>/dev/null)
    local actual
    actual=$(shasum -a 256 "$file" | awk '{print $1}')

    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        return 1
    fi
}

# Sanitize content to prevent prompt injection and control character attacks
# Removes:
#   - Control characters (except newline, tab)
#   - Common prompt injection patterns
#   - Escape sequences
handoff_sanitize_content() {
    local content="$1"

    # Remove control characters except newline (\n) and tab (\t)
    content=$(echo "$content" | tr -d '\000-\010\013\014\016-\037')

    # Remove ANSI escape sequences
    content=$(echo "$content" | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g')

    # Remove common prompt injection patterns
    # Pattern: "Ignore previous instructions" variants
    content=$(echo "$content" | sed -E 's/[Ii]gnore (all )?previous (instructions|context|rules)/[SANITIZED]/g')
    # Pattern: "You are now" role reassignment
    content=$(echo "$content" | sed -E 's/[Yy]ou are now [a-zA-Z]+/[SANITIZED]/g')
    # Pattern: "System:" prefix injection
    content=$(echo "$content" | sed -E 's/^[Ss]ystem:\s*/[SANITIZED]: /g')

    echo "$content"
}
