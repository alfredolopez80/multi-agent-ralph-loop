#!/bin/bash
# Repo Curator Trigger Hook v2.52.0
# Hook: UserPromptSubmit
# Purpose: Detect /curator commands and trigger appropriate actions
#
# VERSION: 2.57.4
# v2.52: Fixed JSON output and bash syntax error (local outside function)
# Schema: {"continue": true} or {"continue": true, "systemMessage": "..."}

set -euo pipefail
umask 077

# Configuration
CURATOR_DIR="${HOME}/.ralph/curator"
CONFIG_FILE="${CURATOR_DIR}/config.yml"

# Parse input
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")

# Check if this is a curator command
if [[ "$PROMPT" =~ ^/curator[[:space:]] ]]; then
    # Extract subcommand (fixed: removed 'local' outside function)
    subcommand=$(echo "$PROMPT" | awk '{print $2}')

    case "$subcommand" in
        full|discover|score|rank|ingest|approve|reject|pending|show|learn|status)
            # Valid curator command, allow execution
            echo '{"continue": true}'
            exit 0
            ;;
        help|--help|-h)
            # Show help, allow execution
            echo '{"continue": true}'
            exit 0
            ;;
        *)
            # Unknown command, might be a mistake
            # Allow it but log warning
            echo '{"continue": true, "systemMessage": "Unknown curator subcommand"}'
            exit 0
            ;;
    esac
fi

# Not a curator command, continue normally
echo '{"continue": true}'
