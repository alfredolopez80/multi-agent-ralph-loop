#!/usr/bin/env bash
# VERSION: 2.69.0
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
trap 'echo "{\"decision\": \"allow\"}"' ERR EXIT

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
    echo '{"decision": "allow"}'; exit 0
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
    echo '{"decision": "allow"}'; exit 0
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
    echo '{"decision": "allow"}'; exit 0
fi

# Output verification reminder to stderr (HIGH-004: stdout reserved for JSON)
cat >&2 << EOF

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

# v2.62.3: Update plan-state with LSA pre-check (handles both formats)
if jq --arg step "$CURRENT_STEP" --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
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
' "$PLAN_STATE" > "$TEMP_FILE"; then
    mv "$TEMP_FILE" "$PLAN_STATE"
    trap - EXIT
else
    log "ERROR: jq failed to update plan-state"
    rm -f "$TEMP_FILE"
    exit 1
fi

log "LSA pre-check completed for step $CURRENT_STEP"

# v2.62.3: PreToolUse hooks must output JSON
trap - ERR EXIT  # CRIT-003b: Clear trap before explicit output
echo '{"decision": "allow"}'
