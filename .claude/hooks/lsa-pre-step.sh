#!/usr/bin/env bash
# VERSION: 2.45.1
# Hook: LSA Pre-Step Verification
# Trigger: PreToolUse (when tool is Edit or Write in orchestrated context)
# Purpose: Verify architecture compliance BEFORE implementation
# Security: v2.45.1 - Fixed race condition with atomic updates

set -euo pipefail

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
    exit 0
fi

# Get current step from environment or plan-state
CURRENT_STEP="${RALPH_CURRENT_STEP:-}"

if [ -z "$CURRENT_STEP" ]; then
    # Find first in_progress step
    CURRENT_STEP=$(jq -r '.steps[] | select(.status == "in_progress") | .id' "$PLAN_STATE" 2>/dev/null | head -1)
fi

if [ -z "$CURRENT_STEP" ]; then
    log "No active step found, skipping LSA pre-check"
    exit 0
fi

log "LSA Pre-Step Check for step: $CURRENT_STEP"

# Extract spec for current step
SPEC=$(jq -r ".steps[] | select(.id == \"$CURRENT_STEP\") | .spec" "$PLAN_STATE" 2>/dev/null)

if [ "$SPEC" = "null" ] || [ -z "$SPEC" ]; then
    log "No spec found for step $CURRENT_STEP"
    exit 0
fi

# Output verification reminder
cat << EOF

╔══════════════════════════════════════════════════════════════════╗
║                    LSA PRE-STEP VERIFICATION                      ║
╠══════════════════════════════════════════════════════════════════╣
║  Step: $CURRENT_STEP
║                                                                   ║
║  VERIFY BEFORE IMPLEMENTING:                                      ║
║  ┌────────────────────────────────────────────────────────────┐  ║
║  │ [ ] Target file matches spec                               │  ║
║  │ [ ] Dependencies available                                 │  ║
║  │ [ ] Patterns from architecture understood                  │  ║
║  │ [ ] Export names match spec exactly                        │  ║
║  │ [ ] Function signatures match spec                         │  ║
║  └────────────────────────────────────────────────────────────┘  ║
║                                                                   ║
║  Spec Summary:                                                    ║
$(echo "$SPEC" | jq -r 'to_entries | .[] | "║  • \(.key): \(.value | tostring | .[0:50])"' 2>/dev/null || echo "║  (Unable to parse spec)")
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝

EOF

# SECURITY: Atomic update using mktemp to prevent race conditions (v2.45.1)
TEMP_FILE=$(mktemp "${PLAN_STATE}.XXXXXX") || {
    log "ERROR: Failed to create temp file for atomic update"
    exit 1
}

trap 'rm -f "$TEMP_FILE"' EXIT

if jq --arg step "$CURRENT_STEP" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
  .steps |= map(
    if .id == $step then
      .lsa_verification.pre_check = {
        "triggered_at": $ts,
        "spec_loaded": true
      }
    else . end
  )
' "$PLAN_STATE" > "$TEMP_FILE"; then
    mv "$TEMP_FILE" "$PLAN_STATE"
    trap - EXIT
else
    log "ERROR: jq failed to update plan-state"
    rm -f "$TEMP_FILE"
    exit 1
fi

log "LSA pre-check completed for step $CURRENT_STEP"
