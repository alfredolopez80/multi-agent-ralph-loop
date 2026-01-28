#!/bin/bash
# VERSION: 2.69.0
# v2.52: Fixed JSON output format for SessionStart hooks
# Hook: SessionStart - Auto-migrate plan-state.json
# Purpose: Automatically migrate plan-state.json from v1 to v2 when session starts
#
# Safety:
#   - Only runs at SessionStart (minimal overhead)
#   - Creates backup before any migration
#   - Silent on success (no noise)
#   - Logs to ~/.ralph/logs/auto-migrate.log

set -euo pipefail
umask 077

# Configuration
MIGRATE_SCRIPT="${HOME}/.claude/scripts/migrate-plan-state.sh"
LOG_FILE="${HOME}/.ralph/logs/auto-migrate.log"
PLAN_STATE=".claude/plan-state.json"

mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Helper: Return JSON for SessionStart hook
return_json() {
    local msg="${1:-}"
    if [[ -n "$msg" ]]; then
        local escaped_msg
        escaped_msg=$(printf '%s' "$msg" | jq -R -s '.' 2>/dev/null || echo '""')
        echo "{\"hookSpecificOutput\": {\"hookEventName\": \"SessionStart\", \"additionalContext\": $escaped_msg}}"
    else
        echo '{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": ""}}'
    fi
}

# Only run if script exists
if [[ ! -x "$MIGRATE_SCRIPT" ]]; then
    return_json ""
    exit 0
fi

# Only run if plan-state.json exists
if [[ ! -f "$PLAN_STATE" ]]; then
    return_json ""
    exit 0
fi

# Check if migration is needed (silent check)
check_result=$("$MIGRATE_SCRIPT" --check 2>/dev/null) || true

if echo "$check_result" | grep -q "Migration Required"; then
    log "Auto-migration triggered for: $(pwd)/$PLAN_STATE"

    # Run migration silently
    if "$MIGRATE_SCRIPT" > /dev/null 2>&1; then
        log "Migration successful"

        # Output JSON for SessionStart (v2.52 fix)
        return_json "plan-state.json migrated to v2.51.0 schema (phases + barriers)"
    else
        log "Migration failed"
        return_json "Warning: plan-state.json migration failed. Run 'ralph migrate check' for details."
    fi
else
    # No migration needed, return empty JSON (v2.52 fix)
    return_json ""
fi

exit 0
