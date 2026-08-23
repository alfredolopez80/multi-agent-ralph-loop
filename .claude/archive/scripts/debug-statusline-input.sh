#!/bin/bash
# Debug script to see what JSON the statusline receives

# Read stdin FIRST
stdin_data=$(cat)

# Save to log file in background (don't block)
LOG_FILE="${HOME}/.ralph/logs/statusline-input-debug.log"
mkdir -p "$(dirname "$LOG_FILE")"

(
    echo "=== Statusline Input Debug ===" >> "$LOG_FILE"
    echo "Timestamp: $(date)" >> "$LOG_FILE"
    echo "$stdin_data" | jq '.' >> "$LOG_FILE" 2>/dev/null || echo "$stdin_data" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
) &

# Pass stdin to the real statusline
echo "$stdin_data" | bash $PROJECT_ROOT/.claude/scripts/statusline-ralph.sh
