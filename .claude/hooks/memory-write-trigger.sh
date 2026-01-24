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
# VERSION: 2.68.2
# SECURITY: Added ERR trap for guaranteed JSON output, MATCHED escaping

set -euo pipefail
umask 077

# Guaranteed JSON output on any error (SEC-006)
output_json() {
    echo '{"continue": true}'
}
trap 'output_json' ERR

# Helper: Escape string for JSON (SEC-002)
escape_json() {
    local str="$1"
    # Remove control characters and escape quotes/backslashes
    printf '%s' "$str" | tr -d '\000-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# Parse input
INPUT=$(cat)
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null || echo "")

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

{
    echo "[$(date -Iseconds)] Memory trigger detected: '$MATCHED'"
    echo "  Prompt excerpt: ${USER_PROMPT:0:100}..."
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
