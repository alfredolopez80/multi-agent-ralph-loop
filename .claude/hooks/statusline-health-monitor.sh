#!/bin/bash
# statusline-health-monitor.sh - Periodic health check for statusline
# VERSION: 2.69.0
# v2.69.0: FIX CRIT-001 - Removed duplicate stdin read (cat > /dev/null)
# v2.68.2: FIX CRIT-009 - Clear EXIT trap before explicit JSON output
#
# Purpose: Validate statusline health every 5 minutes
#
# Trigger: UserPromptSubmit
#
# Health Checks:
# 1. Script exists and is executable
# 2. Plan-state.json is valid JSON with required fields
# 3. Stuck detection (in_progress > 30 min without change)
# 4. Sync verification (statusline matches plan-state)

# SEC-111: Read input from stdin with length limit (100KB max)
# Prevents DoS from malicious input
INPUT=$(head -c 100000)


set -euo pipefail

# Error trap for guaranteed JSON output (v2.62.3)
trap 'echo "{}"' ERR EXIT


STATUSLINE_SCRIPT="${HOME}/.claude/scripts/statusline-ralph.sh"
PLAN_STATE=".claude/plan-state.json"
HEALTH_CACHE="${HOME}/.ralph/cache/statusline-health"
LOG_FILE="${HOME}/.ralph/logs/statusline-health.log"
CHECK_INTERVAL_SECONDS=300  # 5 minutes
STUCK_THRESHOLD_MINUTES=30

# Check if disabled
if [[ "${RALPH_HEALTH_MONITOR:-true}" == "false" ]]; then
    trap - EXIT  # CRIT-009: Clear trap before explicit output
    echo '{}'
    exit 0
fi

mkdir -p "$HEALTH_CACHE"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# CRIT-001 FIX: Removed duplicate stdin read
# stdin already consumed by SEC-111 read at top of script

# Check if we should run (every 5 minutes)
NOW=$(date +%s)
LAST_CHECK_FILE="$HEALTH_CACHE/last-check-time"
if [[ -f "$LAST_CHECK_FILE" ]]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo "0")
    ELAPSED=$((NOW - LAST_CHECK))
    if [[ "$ELAPSED" -lt "$CHECK_INTERVAL_SECONDS" ]]; then
        trap - EXIT  # CRIT-009: Clear trap before explicit output
        echo '{}'
        exit 0
    fi
fi
echo "$NOW" > "$LAST_CHECK_FILE"

log "Running health check..."

ISSUES=()
WARNINGS=()

# Check 1: Statusline script exists and is executable
if [[ ! -f "$STATUSLINE_SCRIPT" ]]; then
    ISSUES+=("Statusline script not found: $STATUSLINE_SCRIPT")
elif [[ ! -x "$STATUSLINE_SCRIPT" ]]; then
    ISSUES+=("Statusline script not executable")
fi

# Check 2: Plan-state.json validity
if [[ -f "$PLAN_STATE" ]]; then
    if ! jq empty "$PLAN_STATE" 2>/dev/null; then
        ISSUES+=("plan-state.json is not valid JSON")
    else
        # Check required fields
        HAS_STEPS=$(jq 'has("steps")' "$PLAN_STATE" 2>/dev/null || echo "false")
        HAS_VERSION=$(jq 'has("version")' "$PLAN_STATE" 2>/dev/null || echo "false")
        if [[ "$HAS_STEPS" != "true" ]] || [[ "$HAS_VERSION" != "true" ]]; then
            WARNINGS+=("plan-state.json missing required fields")
        fi

        # Check 3: Stuck detection
        # Get last update time from file modification
        # MEDIUM-001 FIX: Portable stat (macOS/BSD: -f %m, Linux: -c %Y)
        PLAN_MTIME=$(stat -f %m "$PLAN_STATE" 2>/dev/null || stat -c %Y "$PLAN_STATE" 2>/dev/null || echo "0")
        PLAN_AGE_MINUTES=$(( (NOW - PLAN_MTIME) / 60 ))

        # Check if any step is in_progress
        IN_PROGRESS_COUNT=$(jq '[.steps | to_entries[] | select(.value.status == "in_progress")] | length' "$PLAN_STATE" 2>/dev/null || echo "0")
        PHASE_STATUS=$(jq -r '.phases[0].status // "unknown"' "$PLAN_STATE" 2>/dev/null || echo "unknown")

        if [[ "$IN_PROGRESS_COUNT" -gt 0 ]] && [[ "$PLAN_AGE_MINUTES" -ge "$STUCK_THRESHOLD_MINUTES" ]]; then
            WARNINGS+=("Plan may be stuck: in_progress for ${PLAN_AGE_MINUTES}+ minutes")
        fi

        # Check 4: Sync verification
        if [[ -x "$STATUSLINE_SCRIPT" ]]; then
            # Get values from plan-state
            TOTAL_STEPS=$(jq '[.steps | to_entries[] | select(.key != "null")] | length' "$PLAN_STATE" 2>/dev/null || echo "0")
            COMPLETED_STEPS=$(jq '[.steps | to_entries[] | select(.value.status == "completed" or .value.status == "verified")] | length' "$PLAN_STATE" 2>/dev/null || echo "0")

            # Run statusline and check output
            STATUSLINE_OUTPUT=$("$STATUSLINE_SCRIPT" 2>/dev/null | head -1 || echo "")

            # Basic sanity check - statusline should contain the count if plan exists
            if [[ "$TOTAL_STEPS" -gt 0 ]] && [[ "$PHASE_STATUS" != "completed" ]]; then
                if ! echo "$STATUSLINE_OUTPUT" | grep -q "$COMPLETED_STEPS/$TOTAL_STEPS"; then
                    # Could be out of sync
                    log "Potential sync issue: plan shows $COMPLETED_STEPS/$TOTAL_STEPS but statusline: $STATUSLINE_OUTPUT"
                fi
            fi
        fi
    fi
fi

# Log results
if [[ ${#ISSUES[@]} -gt 0 ]]; then
    log "ISSUES: ${ISSUES[*]}"
fi
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    log "WARNINGS: ${WARNINGS[*]}"
fi

# Output warning if issues found
if [[ ${#ISSUES[@]} -gt 0 ]]; then
    ISSUE_MSG="⚠️ StatusLine Health: ${ISSUES[0]}"
    printf '%s' "$ISSUE_MSG" | jq -Rs '{userPromptContent: (. + "\n\n" + input)}' - <(cat)
    exit 0
elif [[ ${#WARNINGS[@]} -gt 0 ]]; then
    # Just log warnings, don't interrupt user
    log "Health check complete with warnings"
fi

log "Health check passed"
trap - EXIT  # CRIT-009: Clear trap before explicit output
echo '{}'
