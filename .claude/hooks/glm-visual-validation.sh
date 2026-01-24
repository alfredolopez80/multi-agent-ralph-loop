#!/bin/bash
# glm-visual-validation.sh - v2.68.26 Visual Validation via GLM-4.7
# Hook: PostToolUse (Edit|Write)
# Purpose: Visual regression testing for frontend file changes using GLM vision tools
#
# Triggers when:
#   - Frontend files modified (.tsx, .jsx, .css, .scss, .vue, .svelte)
#   - Screenshot exists for comparison
#
# Uses GLM-4.7 tools:
#   - ui_diff_check: Compare before/after screenshots
#   - analyze_image: General visual analysis
#
# VERSION: 2.68.26
# v2.68.26: Initial implementation for GLM-4.7 integration

# SEC-111: Read input from stdin with length limit (100KB max)
INPUT=$(head -c 100000)

set -euo pipefail
umask 077

# Guaranteed JSON output on error (SEC-033)
trap 'echo "{\"continue\": true}"' ERR EXIT

# Parse input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null)

# Only trigger on Edit or Write
if [[ "$TOOL_NAME" != "Edit" ]] && [[ "$TOOL_NAME" != "Write" ]]; then
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

# Get file path from tool result
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_result.path // .tool_input.file_path // empty' 2>/dev/null)

if [[ -z "$FILE_PATH" ]]; then
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

# Check if this is a frontend file
FRONTEND_PATTERN='\.(tsx|jsx|css|scss|sass|less|vue|svelte|html)$'
if ! echo "$FILE_PATH" | grep -qE "$FRONTEND_PATTERN"; then
    trap - ERR EXIT
    echo '{"continue": true}'
    exit 0
fi

# Check for Z_AI_API_KEY (required for GLM endpoints)
# Try environment first, then fall back to .zshrc
if [[ -z "${Z_AI_API_KEY:-}" ]]; then
    # Source from .zshrc if available
    if [[ -f "$HOME/.zshrc" ]]; then
        Z_AI_API_KEY=$(grep "^export Z_AI_API_KEY=" "$HOME/.zshrc" 2>/dev/null | head -1 | sed "s/export Z_AI_API_KEY=//; s/['\"]//g")
    fi
fi

if [[ -z "${Z_AI_API_KEY:-}" ]]; then
    trap - ERR EXIT
    echo '{"continue": true, "systemMessage": "GLM visual validation: Skipped (no Z_AI_API_KEY)"}'
    exit 0
fi

# Setup logging
LOG_DIR="$HOME/.ralph/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/glm-visual-validation-$(date +%Y%m%d).log"

{
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] Visual validation triggered"
    echo "  File: $FILE_PATH"
} >> "$LOG_FILE"

# Check for screenshot directory
SCREENSHOT_DIR="$HOME/.ralph/screenshots"
PROJECT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
PROJECT_SCREENSHOT_DIR="$PROJECT_ROOT/.claude/screenshots"

# Look for existing screenshots
BEFORE_SCREENSHOT=""
AFTER_SCREENSHOT=""

# Check project-level screenshots first
if [[ -d "$PROJECT_SCREENSHOT_DIR" ]]; then
    FILE_BASENAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
    BEFORE_SCREENSHOT=$(find "$PROJECT_SCREENSHOT_DIR" -name "${FILE_BASENAME}-before*" -type f 2>/dev/null | head -1)
    AFTER_SCREENSHOT=$(find "$PROJECT_SCREENSHOT_DIR" -name "${FILE_BASENAME}-after*" -type f 2>/dev/null | head -1)
fi

# If no screenshots, check global directory
if [[ -z "$BEFORE_SCREENSHOT" ]] && [[ -d "$SCREENSHOT_DIR" ]]; then
    FILE_BASENAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
    BEFORE_SCREENSHOT=$(find "$SCREENSHOT_DIR" -name "${FILE_BASENAME}-before*" -type f 2>/dev/null | head -1)
    AFTER_SCREENSHOT=$(find "$SCREENSHOT_DIR" -name "${FILE_BASENAME}-after*" -type f 2>/dev/null | head -1)
fi

# If no screenshots found, just log and exit
if [[ -z "$BEFORE_SCREENSHOT" ]] || [[ -z "$AFTER_SCREENSHOT" ]]; then
    echo "  No before/after screenshots found for visual diff" >> "$LOG_FILE"
    trap - ERR EXIT
    echo '{"continue": true, "systemMessage": "GLM visual validation: Ready. Capture before/after screenshots to ~/.ralph/screenshots/ for ui_diff_check"}'
    exit 0
fi

echo "  Before: $BEFORE_SCREENSHOT" >> "$LOG_FILE"
echo "  After: $AFTER_SCREENSHOT" >> "$LOG_FILE"

# Call ui_diff_check via GLM API
DIFF_RESULT=$(timeout 30 curl -s -X POST \
    "https://api.z.ai/api/mcp/zai_mcp_server/mcp" \
    -H "Authorization: Bearer ${Z_AI_API_KEY}" \
    -H "Content-Type: application/json" \
    -d "{
        \"jsonrpc\": \"2.0\",
        \"method\": \"tools/call\",
        \"params\": {
            \"name\": \"ui_diff_check\",
            \"arguments\": {
                \"before_image\": \"file://$BEFORE_SCREENSHOT\",
                \"after_image\": \"file://$AFTER_SCREENSHOT\"
            }
        },
        \"id\": 1
    }" 2>/dev/null) || {
    echo "  ui_diff_check API call failed" >> "$LOG_FILE"
    trap - ERR EXIT
    echo '{"continue": true, "systemMessage": "GLM visual validation: API call failed"}'
    exit 0
}

# Parse result
if echo "$DIFF_RESULT" | jq -e '.result' >/dev/null 2>&1; then
    DIFF_SUMMARY=$(echo "$DIFF_RESULT" | jq -r '.result.summary // .result // "No changes detected"' 2>/dev/null | head -c 500)
    DIFF_STATUS=$(echo "$DIFF_RESULT" | jq -r '.result.status // "unknown"' 2>/dev/null)

    echo "  Result: $DIFF_STATUS" >> "$LOG_FILE"
    echo "  Summary: $DIFF_SUMMARY" >> "$LOG_FILE"

    # Build message based on diff result
    if [[ "$DIFF_STATUS" == "significant_changes" ]]; then
        MSG="⚠️ GLM Visual Diff: Significant UI changes detected in $FILE_PATH. Review: $DIFF_SUMMARY"
    elif [[ "$DIFF_STATUS" == "minor_changes" ]]; then
        MSG="✅ GLM Visual Diff: Minor UI changes in $FILE_PATH. $DIFF_SUMMARY"
    else
        MSG="ℹ️ GLM Visual Diff: $DIFF_SUMMARY"
    fi

    trap - ERR EXIT
    jq -n --arg msg "$MSG" '{"continue": true, "systemMessage": $msg}'
else
    echo "  No valid result from ui_diff_check" >> "$LOG_FILE"
    trap - ERR EXIT
    echo '{"continue": true}'
fi
