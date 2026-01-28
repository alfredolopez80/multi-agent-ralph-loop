#!/bin/bash
# Memory Write Trigger - Hot Path Detection (v2.49.0)
# Hook: UserPromptSubmit
# Purpose: Detect memory intent phrases and inject memory context
#
# Triggers on phrases like:
# - "remember this", "remember that"
# - "don't forget", "do not forget"
# - "note that", "note this"
# - "keep in mind"
# - "for future reference"
#
# VERSION: 2.69.0
# v2.68.11: SEC-111 FIX - Input length validation to prevent DoS
# v2.68.10: SEC-110 FIX - Redact sensitive data (API keys, tokens, passwords) before logging
# SECURITY: Added ERR trap for guaranteed JSON output, MATCHED escaping

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR EXIT

# Helper: Escape string for JSON (SEC-002)
escape_json() {
    local str="$1"
    # Remove control characters and escape quotes/backslashes
    printf '%s' "$str" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# SEC-110: Redact sensitive data before logging
# Patterns: API keys, tokens, passwords, secrets, credentials
redact_sensitive() {
    local str="$1"
    # Redact common API key patterns (sk-, pk-, api_, key_, token_, secret_)
    str=$(echo "$str" | sed -E 's/(sk-|pk-|api_|key_|token_|secret_|password[=:_ ]*)[a-zA-Z0-9_-]{10,}/\1[REDACTED]/gi')
    # Redact long alphanumeric strings (potential tokens/keys - 20+ chars)
    str=$(echo "$str" | sed -E 's/[a-zA-Z0-9_-]{32,}/[REDACTED]/g')
    # Redact base64-like patterns (40+ chars with mixed case/numbers)
    str=$(echo "$str" | sed -E 's/[A-Za-z0-9+/=]{40,}/[REDACTED]/g')
    echo "$str"
}

# Parse input
# CRIT-001 FIX: Removed duplicate stdin read - SEC-111 already reads at top
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null || echo "")

# SEC-111: Input length validation to prevent DoS from large prompts
MAX_INPUT_LEN=100000
if [[ ${#USER_PROMPT} -gt $MAX_INPUT_LEN ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Exit if no prompt
if [[ -z "$USER_PROMPT" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Convert to lowercase for matching
PROMPT_LOWER=$(echo "$USER_PROMPT" | tr '[:upper:]' '[:lower:]')

# Memory config
CONFIG_FILE="$HOME/.ralph/config/memory-config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Check if hot path is enabled
HOT_PATH_ENABLED=$(jq -r '.hot_path.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
if [[ "$HOT_PATH_ENABLED" != "true" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Load triggers from config
TRIGGERS=$(jq -r '.hot_path.auto_triggers[]?' "$CONFIG_FILE" 2>/dev/null || echo "")
if [[ -z "$TRIGGERS" ]]; then
    # Default triggers
    TRIGGERS="remember
note
don't forget
do not forget
keep in mind
for future reference"
fi

# Check for trigger matches
MATCHED=""
while IFS= read -r trigger; do
    [[ -z "$trigger" ]] && continue
    if [[ "$PROMPT_LOWER" == *"$trigger"* ]]; then
        MATCHED="$trigger"
        break
    fi
done <<< "$TRIGGERS"

# If no match, continue normally
if [[ -z "$MATCHED" ]]; then
    echo '{"continue": true}'
    exit 0
fi

# Memory intent detected - inject context
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/memory-triggers-$(date +%Y%m%d).log"

# SEC-110: Redact sensitive data before logging user prompts
SAFE_EXCERPT=$(redact_sensitive "${USER_PROMPT:0:100}")
{
    echo "[$(date -Iseconds)] Memory trigger detected: '$MATCHED'"
    echo "  Prompt excerpt: ${SAFE_EXCERPT}..."
} >> "$LOG_FILE" 2>/dev/null || true

# Get recent memory stats for context
MEMORY_STATS=""
if command -v python3 &>/dev/null && [[ -f "$HOME/.claude/scripts/memory-manager.py" ]]; then
    MEMORY_STATS=$(python3 "$HOME/.claude/scripts/memory-manager.py" stats 2>/dev/null | head -10 || echo "")
fi

# Prepare context injection
CONTEXT="Memory intent detected (trigger: '$MATCHED').

Available memory commands:
- Use python3 ~/.claude/scripts/memory-manager.py write <type> --content \"...\" to store
- Types: semantic (facts), episodic (experiences), procedural (behaviors)

Quick example:
python3 ~/.claude/scripts/memory-manager.py write semantic --content \"User preference noted\" --category preferences --importance 7"

if [[ -n "$MEMORY_STATS" ]]; then
    CONTEXT="$CONTEXT

Current memory stats:
$MEMORY_STATS"
fi

# Escape for JSON
CONTEXT_ESCAPED=$(echo "$CONTEXT" | jq -R -s '.')

# Escape MATCHED for safe JSON inclusion (SEC-002)
MATCHED_ESCAPED=$(escape_json "$MATCHED")

echo "{
    \"continue\": true,
    \"additionalContext\": $CONTEXT_ESCAPED,
    \"memory_trigger\": {
        \"detected\": true,
        \"trigger\": \"$MATCHED_ESCAPED\",
        \"timestamp\": \"$(date -Iseconds)\"
    }
}"
