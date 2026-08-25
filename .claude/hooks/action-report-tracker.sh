#!/bin/bash
umask 077
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
# BUG-3: `trap ... ERR EXIT` emitted twice. Under `set -e` a failing command
# fires ERR (emits JSON) and then EXIT (emits again); stdout then carried two
# concatenated objects and Claude Code rejected the payload with
# "Hook JSON output validation failed - (root): Invalid input". emit_json makes
# emission idempotent, and every `trap -` clears ERR as well as EXIT.
readonly DEFAULT_HOOK_JSON='{"continue": true}'
_HOOK_EMITTED=0
emit_json() {
    [ "${_HOOK_EMITTED}" -eq 1 ] && return 0
    _HOOK_EMITTED=1
    printf '%s\n' "${1:-$DEFAULT_HOOK_JSON}"
}
trap 'emit_json' ERR EXIT

# Load report generator library
REPORT_GENERATOR=".claude/lib/action-report-generator.sh"
if [[ ! -f "$REPORT_GENERATOR" ]]; then
    trap - ERR EXIT  # clear trap first so it does not emit a SECOND JSON object
    emit_json '{"continue": true}'
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
    trap - ERR EXIT
    emit_json '{"continue": true}'
    exit 0
fi

# Extract skill name from subagent_type
SUBAGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.subagent_type // ""' 2>/dev/null || echo "")
TASK_DESCRIPTION=$(echo "$TOOL_INPUT" | jq -r '.description // ""' 2>/dev/null || echo "")
RUN_IN_BACKGROUND=$(echo "$TOOL_INPUT" | jq -r '.run_in_background // false' 2>/dev/null || echo "false")

log "Task completed: subagent=$SUBAGENT_TYPE, background=$RUN_IN_BACKGROUND"

# Map subagent types to skill names.
#
# A `case`, NOT `declare -A` (#42/#44). This hook has `#!/bin/bash`, which on macOS is
# unconditionally bash 3.2 — a hard-pinned interpreter cannot reach a Homebrew bash 5
# however the user's PATH is set, so this file was strictly more exposed than the
# scripts/ validators. Bash 3.2 has no associative arrays and does not abort on one: it
# warns to stderr, continues, and collapses every key onto index 0 because an unset name
# in an array subscript evaluates arithmetically to 0. Every subagent type would have
# resolved to whichever entry landed last, filing every action report under the wrong
# skill — quietly, on every Task completion. A `case` needs no bash 4 at all.
case "$SUBAGENT_TYPE" in
    orchestrator|ralph-coder)   SKILL_NAME="orchestrator" ;;
    ralph-reviewer|ralph-tester) SKILL_NAME="gates" ;;
    ralph-researcher)           SKILL_NAME="curator" ;;
    general-purpose)            SKILL_NAME="loop" ;;
    security-scanner)           SKILL_NAME="security" ;;
    bug-scanner)                SKILL_NAME="bugs" ;;
    codex-reviewer)             SKILL_NAME="code-reviewer" ;;
    *)                          SKILL_NAME="$SUBAGENT_TYPE" ;;
esac

# Skip if unknown skill
if [[ -z "$SKILL_NAME" || "$SKILL_NAME" == "null" ]]; then
    log "Unknown subagent type: $SUBAGENT_TYPE - skipping report"
    trap - ERR EXIT
    emit_json '{"continue": true}'
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
trap - ERR EXIT
emit_json '{"continue": true}'
