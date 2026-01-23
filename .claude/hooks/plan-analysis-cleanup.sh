#!/usr/bin/env bash
# VERSION: 2.62.3
# plan-analysis-cleanup.sh
# Hook: PostToolUse (ExitPlanMode)
# Cleans up orchestrator analysis file after ExitPlanMode
# Output: {"continue": true}

set -euo pipefail
umask 077

# Error trap: Always output valid JSON for PostToolUse
trap 'echo "{\"continue\": true}"' ERR EXIT

ANALYSIS_FILE=".claude/orchestrator-analysis.md"
BACKUP_DIR="${HOME}/.ralph/analysis"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Function to return JSON response (Claude Code hook protocol)
return_json() {
    local continue_flag="${1:-true}"
    local message="${2:-}"
    if [ -n "$message" ]; then
        echo "{\"continue\": $continue_flag, \"message\": \"$message\"}"
    else
        echo "{\"continue\": $continue_flag}"
    fi
}

# Read stdin (hook input - we don't need it but must consume it)
cat > /dev/null 2>&1 || true

# Only run if analysis file exists
if [ -f "$ANALYSIS_FILE" ]; then
    # Create backup directory if needed
    mkdir -p "$BACKUP_DIR"

    # Extract task name from first heading for meaningful filename
    TASK_NAME=$(head -5 "$ANALYSIS_FILE" | grep -E "^#" | head -1 | sed 's/^#* //' | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-50)

    if [ -z "$TASK_NAME" ]; then
        TASK_NAME="analysis"
    fi

    # Backup with timestamp
    BACKUP_FILE="${BACKUP_DIR}/${TASK_NAME}-${TIMESTAMP}.md"
    cp "$ANALYSIS_FILE" "$BACKUP_FILE"

    # Remove working file
    rm "$ANALYSIS_FILE"

    # Keep only last 20 backups
    ls -t "$BACKUP_DIR"/*.md 2>/dev/null | tail -n +21 | xargs rm -f 2>/dev/null || true

    return_json true "Analysis backed up to: $BACKUP_FILE"
else
    return_json true
fi
