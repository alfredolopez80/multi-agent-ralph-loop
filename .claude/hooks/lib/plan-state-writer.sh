#!/usr/bin/env bash
# plan-state-writer.sh — Canonical atomic writer for .claude/plan-state.json
# VERSION: 1.0.0
#
# Why this exists
# ---------------
# Eight hooks mutate plan-state.json with bespoke jq+mktemp+mv dances. Only two
# of them refresh the top-level `.last_updated` field that Stop-chain freshness
# detection relies on (`anti-rationalization-gate.sh` per-project isolation,
# `plan-state-lifecycle.sh` staleness archival). Two coexisting schemas also
# use different freshness fields: v1 writes `.last_updated`, v2 writes
# `.updated_at`. Readers assume either without coordination.
#
# This library consolidates both concerns:
#   - Atomicity: mktemp → jq → mv (POSIX, race-free on same filesystem)
#   - Freshness: every write forces BOTH `.last_updated` AND `.updated_at` to
#     `now | todate` (ISO-UTC), so any reader observing either field sees
#     consistent freshness.
#
# Usage (in a hook):
#   _HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${_HOOK_DIR}/lib/plan-state-writer.sh"
#
#   plan_state_update "$PLAN_STATE" '.steps[$step].status = "completed"' \
#       --arg step "s1"
#
#   # Or just refresh the timestamp without other changes:
#   plan_state_touch "$PLAN_STATE"
#
# Contract
# --------
# - Returns 0 on success, 1 on any failure (I/O, jq, mv).
# - On failure, the target file is NEVER left half-written (atomic rename).
# - Missing file is an error (use the caller's init path instead of touch).
# - Logs errors to the caller's $LOG_FILE if defined; otherwise silent.
#
# Fail-open philosophy
# --------------------
# If `jq` is missing, this library will refuse to write and return 1. Callers
# MUST check the return code. We do NOT fall back to naive overwrites because
# a corrupted plan-state.json would cascade into every downstream hook.

set -o pipefail

# Internal: log only if caller defined LOG_FILE; never create one ourselves.
_psw_log() {
    if [[ -n "${LOG_FILE:-}" ]]; then
        printf '[%s] [plan-state-writer] %s\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >> "$LOG_FILE" 2>/dev/null || true
    fi
}

# plan_state_update PLAN_PATH JQ_FILTER [jq_args...]
#
# Applies JQ_FILTER to PLAN_PATH atomically, then force-merges the current
# ISO-UTC timestamp into `.last_updated` AND `.updated_at`.
#
# Example:
#   plan_state_update "$PLAN_STATE" \
#       '.steps |= map(if .id == $s then .status = "completed" else . end)' \
#       --arg s "s1"
plan_state_update() {
    local plan_path="$1"
    local user_filter="$2"
    shift 2

    if ! command -v jq >/dev/null 2>&1; then
        _psw_log "ERROR: jq not available; refusing to write $plan_path"
        return 1
    fi

    if [[ ! -f "$plan_path" ]]; then
        _psw_log "ERROR: plan-state not found at $plan_path"
        return 1
    fi

    local temp_file
    temp_file=$(mktemp "${plan_path}.XXXXXX") || {
        _psw_log "ERROR: mktemp failed for $plan_path"
        return 1
    }

    # Always append the freshness-dual-write stage AFTER the user filter, so
    # even if the user filter explicitly sets one of these fields we overwrite
    # with a coherent "now". Two fields, one source of truth.
    local full_filter="(${user_filter}) | .last_updated = (now | todate) | .updated_at = (now | todate)"

    if jq "$@" "$full_filter" "$plan_path" > "$temp_file"; then
        # mv is atomic on same filesystem (POSIX rename(2))
        if mv "$temp_file" "$plan_path"; then
            return 0
        fi
        _psw_log "ERROR: mv failed for $plan_path"
        rm -f "$temp_file"
        return 1
    fi

    _psw_log "ERROR: jq filter failed for $plan_path (filter: ${user_filter})"
    rm -f "$temp_file"
    return 1
}

# plan_state_touch PLAN_PATH
#
# Refresh only the freshness fields. Useful for hooks that have already
# written (e.g., legacy bespoke writers being gradually migrated) and just
# need to signal "this plan is active right now".
plan_state_touch() {
    local plan_path="$1"
    plan_state_update "$plan_path" '.'
}
