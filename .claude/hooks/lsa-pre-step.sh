#!/bin/bash
#!/usr/bin/env bash
# VERSION: 2.84.3
# LSA Pre-Step Verification
# v2.69.0: CRIT-003 - Added EXIT to trap + trap clears before outputs
# v2.68.7: CRIT-002 - Added error trap for guaranteed JSON output
# v2.66.8: HIGH-004 - Redirect ASCII art to stderr (stdout reserved for JSON)
# Hook: PreToolUse (Edit|Write)
# Purpose: Verify architecture compliance BEFORE implementation
# Security: v2.45.1 - Fixed race condition with atomic updates
# v2.62.3: Support both array (v1) and object (v2) steps format

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# SEC-006: Guaranteed JSON output on any error (CRIT-002 + CRIT-003 fix)
# v2.87.0 FIX: Use hookSpecificOutput wrapper for PreToolUse hooks
trap 'echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"allow\"}"' ERR EXIT

# Configuration
PLAN_STATE=".claude/plan-state.json"
LOG_FILE="${HOME}/.ralph/logs/lsa-pre-step.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Check if we're in orchestrated context (plan-state exists)
if [ ! -f "$PLAN_STATE" ]; then
    # Not in orchestrated mode, skip LSA verification
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'; exit 0
fi

# Get current step from environment or plan-state
CURRENT_STEP="${RALPH_CURRENT_STEP:-}"

if [ -z "$CURRENT_STEP" ]; then
    # v2.62.3: Find first in_progress step (handles both array and object format)
    CURRENT_STEP=$(jq -r '
        if (.steps | type) == "array" then
            # v1 array format
            .steps[] | select(.status == "in_progress") | .id
        else
            # v2 object format
            .steps | to_entries[] | select(.value.status == "in_progress") | .key
        end
    ' "$PLAN_STATE" 2>/dev/null | head -1)
fi

if [ -z "$CURRENT_STEP" ]; then
    log "No active step found, skipping LSA pre-check"
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'; exit 0
fi

log "LSA Pre-Step Check for step: $CURRENT_STEP"

# v2.62.3: Extract spec for current step (handles both formats)
SPEC=$(jq -r --arg id "$CURRENT_STEP" '
    if (.steps | type) == "array" then
        # v1 array format
        .steps[] | select(.id == $id) | .spec
    else
        # v2 object format - check _v1_data for spec or use name
        .steps[$id] | if ._v1_data then ._v1_data.spec else {name: .name} end
    end
' "$PLAN_STATE" 2>/dev/null)

if [ "$SPEC" = "null" ] || [ -z "$SPEC" ]; then
    log "No spec found for step $CURRENT_STEP"
    trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'; exit 0
fi

# v2.69.0: Write verification banner to log file instead of stderr (fixes hook error warnings)
# stderr causes Claude Code to display "hook error" even when hook succeeds
LOG_FILE="${HOME}/.ralph/logs/lsa-pre-step.log"
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true

{
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                    LSA PRE-STEP VERIFICATION                      ║"
    echo "╠══════════════════════════════════════════════════════════════════╣"
    echo "║  Step: $CURRENT_STEP"
    echo "║  Time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "║                                                                   ║"
    echo "║  VERIFY BEFORE IMPLEMENTING:                                      ║"
    echo "║  • Target file matches spec                                       ║"
    echo "║  • Dependencies available                                         ║"
    echo "║  • Patterns from architecture understood                          ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo ""
} >> "$LOG_FILE" 2>/dev/null || true

# Create additionalContext message for Claude
LSA_CONTEXT="🔍 LSA Pre-Step: Verifying step '$CURRENT_STEP' - check spec compliance before implementing"

# v2.0: atomic update + dual-write freshness via lib/plan-state-writer.sh
# shellcheck disable=SC1091
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/plan-state-writer.sh"

if ! plan_state_update "$PLAN_STATE" '
  if (.steps | type) == "array" then
    # v1 array format
    .steps |= map(
      if .id == $step then
        .lsa_verification.pre_check = {
          "triggered_at": $ts,
          "spec_loaded": true
        }
      else . end
    )
  else
    # v2 object format
    .steps[$step].verification.started_at = $ts |
    .steps[$step]._v1_data.lsa_verification.pre_check = {
      "triggered_at": $ts,
      "spec_loaded": true
    }
  end
' \
    --arg step "$CURRENT_STEP" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)"; then
    log "ERROR: plan_state_update failed"
    exit 1
fi

log "LSA pre-check completed for step $CURRENT_STEP"

# v2.69.0: PreToolUse hooks output JSON with additionalContext (instead of stderr)
# v2.87.0 FIX: Use hookSpecificOutput wrapper for PreToolUse hooks
trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"allow\", \"additionalContext\": \"$LSA_CONTEXT\"}}"
