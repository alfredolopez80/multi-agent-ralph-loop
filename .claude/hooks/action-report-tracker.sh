#!/bin/bash
# action-report-tracker.sh - Hook for automatic action report generation
# Hook: PostToolUse (Task tool)
# VERSION: 2.93.0
#
# Purpose: Generate action reports automatically when skills complete
# Trigger: After Task tool completes (subagent execution)
#
# This hook detects when a Ralph skill completes and generates:
# 1. Markdown report in docs/actions/{skill}/{timestamp}.md
# 2. JSON metadata in .claude/metadata/actions/{skill}/{timestamp}.json
# 3. Visible report in Claude conversation (stdout)

set -euo pipefail

# Error trap - hooks should never block workflow
trap 'echo "{\"continue\": true}"' ERR EXIT

# Load report generator library
REPORT_GENERATOR=".claude/lib/action-report-generator.sh"
if [[ ! -f "$REPORT_GENERATOR" ]]; then
    echo "{\"continue\": true}"
    exit 0
fi

# Source the library (use bash subshell to avoid polluting environment)
source "$REPORT_GENERATOR"

# Logging
LOG_FILE="${HOME}/.ralph/logs/action-report-tracker.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*" >> "$LOG_FILE" 2>/dev/null || true
}

# SEC-111: Read input with length limit
INPUT=$(head -c 100000)

# Parse JSON input
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}' 2>/dev/null || echo "{}")
TOOL_RESULT=$(echo "$INPUT" | jq -r '.tool_result // ""' 2>/dev/null || echo "")
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# Only track Task tool completions (skill invocations)
if [[ "$TOOL_NAME" != "Task" ]]; then
    trap - EXIT
    echo '{"continue": true}'
    exit 0
fi

# Extract skill name from subagent_type
SUBAGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // ""' 2>/dev/null || echo "")
TASK_DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r '.description // ""' 2>/dev/null || echo "")
RUN_IN_BACKGROUND=$(echo "$TOOL_INPUT" | jq -r '.run_in_background // false' 2>/dev/null || echo "false")

log "Task completed: subagent=$SUBAGENT_TYPE, background=$RUN_IN_BACKGROUND"

# Map subagent types to skill names
declare -A SKILL_MAPPING=(
    ["orchestrator"]="orchestrator"
    ["ralph-coder"]="orchestrator"
    ["ralph-reviewer"]="gates"
    ["ralph-tester"]="gates"
    ["ralph-researcher"]="curator"
    ["general-purpose"]="loop"
    ["security-scanner"]="security"
    ["bug-scanner"]="bugs"
    ["code-reviewer"]="code-reviewer"
)

# Determine skill name
SKILL_NAME="${SKILL_MAPPING[$SUBAGENT_TYPE]:-$SUBAGENT_TYPE}"

# Skip if unknown skill
if [[ -z "$SKILL_NAME" || "$SKILL_NAME" == "null" ]]; then
    log "Unknown subagent type: $SUBAGENT_TYPE - skipping report"
    trap - EXIT
    echo '{"continue": true}'
    exit 0
fi

# Determine status from tool result
STATUS="completed"
if echo "$TOOL_RESULT" | grep -qiE "(error|failed|exception)"; then
    STATUS="failed"
fi

# Generate details JSON
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DETAILS=$(jq -n \
    --arg subagent_type "$SUBAGENT_TYPE" \
    --arg description "$TASK_DESCRIPTION" \
    --arg run_in_background "$RUN_IN_BACKGROUND" \
    --arg timestamp "$TIMESTAMP" \
    --arg session_id "$SESSION_ID" \
    '{
        subagent_type: $subagent_type,
        description: $description,
        run_in_background: $run_in_background,
        completed_at: $timestamp,
        session_id: $session_id
    }')

# Generate report
log "Generating action report for skill: $SKILL_NAME"

# IMPORTANT: Output both report and JSON
# The report goes to stdout (visible in Claude)
# JSON goes to stdout (hook protocol)
{
    echo ""
    echo "## 📊 Action Report Generated"
    echo ""

    # Generate the full report (this outputs markdown + location info)
    generate_action_report "$SKILL_NAME" "$STATUS" "$TASK_DESCRIPTION" "$DETAILS"

    echo ""
} >&2  # Send to stderr to avoid mixing with JSON output

# Log completion
log "Action report generated: $SKILL_NAME ($STATUS)"

# Clear trap and output hook protocol
trap - EXIT
echo '{"continue": true}'
