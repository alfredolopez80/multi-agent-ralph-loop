#!/usr/bin/env bash
umask 077
# agent-policy-guard.sh — PreToolUse:Task guard enforcing #48 agent ceiling.
# VERSION: 2.0.0 (T101 RETURN)
#
# Triggered by: PreToolUse:Task hook event (matcher: Task)
# Purpose: deny Task tool invocations that would exceed the configured
#          agent ceiling. Source of truth is the per-subagent state files
#          that ralph-subagent-start.sh writes and subagent-stop-universal.sh
#          marks `completed` — this hook does NOT maintain a parallel
#          registry. A Task is approved when the number of currently-active
#          subagents in the session is below RALPH_AGENT_CEILING.
#
# Depth limit (RALPH_AGENT_DEPTH) is enforced by a SEPARATE hook,
# agent-depth-soft-enforce.sh, in SubagentStart. The reason is structural:
# PreToolUse:Task's stdin does not carry the caller's agent_id, so a chain
# walk of parentIds is impossible here without inventing a heuristic that
# would also be wrong (e.g. "caller = most recent active" failed for three
# sequential root-spawned tasks, which the T101 RETURN reviewer caught).
# The depth criterion is satisfied there with exact chain truth instead.
#
# Configuration (env vars, with defaults set by #48):
#   RALPH_AGENT_CEILING   default 8   (max concurrent subagents per session)
#
# State read from:
#   ${RALPH_STATE_DIR:-${HOME}/.ralph}/state/<session-id>/subagents/*.json
#   Each file is a subagent; relevant field for ceiling: `status` (active | completed).
#
# Output (allow): clean exit 0 (no stdout; PreToolUse allow is signaled by exit 0).
# Output (deny):  {"hookSpecificOutput":{"hookEventName":"PreToolUse",
#                                         "permissionDecision":"deny",
#                                         "permissionDecisionReason":"..."}}.
#                The continue:false shape was the original implementation but
#                cuts the WHOLE TURN, not just the tool call. permissionDecision
#                is the only correct deny vocabulary for PreToolUse — see
#                tests/HOOK_FORMAT_REFERENCE.md:34.

set -uo pipefail

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${HOME}/.ralph/logs/agent-policy.log"

# Internal logger: writes to LOG_FILE if its directory exists, otherwise to
# stderr. Avoids the macOS system `log(1)` command which would clobber our
# output with usage text.
log() {
    local msg="$1"
    local ts
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")"
    if [[ -d "$(dirname "$LOG_FILE")" ]]; then
        printf '[%s] agent-policy-guard: %s\n' "$ts" "$msg" >> "$LOG_FILE" 2>/dev/null || true
    else
        printf '[%s] agent-policy-guard: %s\n' "$ts" "$msg" >&2 || true
    fi
}

# --- Configuration ----------------------------------------------------------

DEFAULT_CEILING=8

# --- Numeric validation -----------------------------------------------------
# An unparseable RALPH_AGENT_CEILING (e.g. `abc`) must NOT crash with
# `unbound variable` and silently disable the policy. The env override is
# the configured escape hatch; the hook still applies the default when the
# override is invalid, with a one-line log so the operator can spot the typo.

validate_int() {
    local var_name="$1" default="$2"
    local raw="${!var_name:-}"
    if [[ -z "$raw" ]]; then
        printf '%s' "$default"
        return 0
    fi
    if [[ ! "$raw" =~ ^[0-9]+$ ]]; then
        log "WARN: $var_name='$raw' is not a non-negative integer; using default $default"
        printf '%s' "$default"
        return 0
    fi
    printf '%s' "$raw"
}

ceiling="$(validate_int RALPH_AGENT_CEILING "$DEFAULT_CEILING")"

# --- Input parsing ----------------------------------------------------------

INPUT="$(head -c 100000)"

tool_name="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
if [[ "$tool_name" != "Task" ]]; then
    exit 0
fi

subagent_type="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"
if [[ -z "$subagent_type" || "$subagent_type" == "null" ]]; then
    exit 0
fi

session_id="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
if [[ -z "$session_id" || "$session_id" == "null" ]]; then
    cwd_digest="$(pwd | tr -cd '[:alnum:]-_' | head -c 32)"
    session_id="cwd-${cwd_digest}-$(date +%Y%m%d)"
fi
# Portable sanitisation (no sed; BSD/GNU both have tr and awk).
session_id="$(printf '%s' "$session_id" | tr -cd '[:alnum:]-_' | head -c 128)"
[[ -z "$session_id" ]] && session_id="unknown-session"

# --- Source of truth: subagents/<id>.json ----------------------------------

RALPH_STATE_DIR="${RALPH_STATE_DIR:-${HOME}/.ralph}"
subagents_dir="${RALPH_STATE_DIR}/state/${session_id}/subagents"

# Count files whose status field equals "active" — single jq pass. A new
# session has no subagent state files yet; the glob expands to nothing and
# jq on an empty stream fails. compgen -G detects empty globs cleanly, so
# treat empty as zero (no active subagents yet).
active_count=0
orphan_count=0
# T101-r3 bug 3: GC stale state files. A subagent that died without emitting
# SubagentStop (OOM, kill -9, harness crash) leaves an "active" file that
# the ceiling would count forever. Files older than ORPHAN_THRESHOLD_HOURS
# are excluded from the count and logged as reclaimed. Override the
# threshold via RALPH_AGENT_GC_HOURS for testing or tuning.
ORPHAN_THRESHOLD_HOURS="${RALPH_AGENT_GC_HOURS:-24}"
if [[ -d "$subagents_dir" ]] && compgen -G "${subagents_dir}/*.json" > /dev/null; then
    # Two passes: orphans first (logged separately, excluded from count),
    # then active count over fresh files only. The `|| { log; exit 2; }`
    # is at script level (NOT inside $()), so a jq parse error actually
    # terminates the hook with rc=2 — not silently leaves active_count=""
    # and falls through to ALLOW. The T101-r2 finding 1 was that the prior
    # version had the exit inside $(), which only killed the subshell.
    while IFS= read -r -d '' f; do
        if [[ -n "$(find "$f" -mmin +$((ORPHAN_THRESHOLD_HOURS * 60)) -print 2>/dev/null)" ]]; then
            log "ORPHAN reclaimed: $f (mtime > ${ORPHAN_THRESHOLD_HOURS}h, excluded from ceiling count)"
            orphan_count=$((orphan_count + 1))
        fi
    done < <(find "${subagents_dir}" -maxdepth 1 -name '*.json' -print0 2>/dev/null)
    _active_count_raw="$(find "${subagents_dir}" -maxdepth 1 -name '*.json' -mmin -$((ORPHAN_THRESHOLD_HOURS * 60)) -print0 2>/dev/null \
        | xargs -0 jq -s '[.[] | select(.status == "active")] | length' 2>/dev/null)" \
        || { log "FAIL-LOUD: state under $subagents_dir is corrupt or unreadable; refusing to allow this spawn (better safe than fail-open). Inspect and either repair or delete the offending .json files."; echo "agent-policy-guard: FAIL-LOUD state corrupt; refusing this spawn (see ~/.ralph/logs/agent-policy.log)" >&2; exit 2; }
    # xargs returns 123 if no files were passed; treat that as zero (no fresh files).
    [[ $? -eq 123 && -z "$_active_count_raw" ]] && _active_count_raw=0
    active_count="$_active_count_raw"
fi

# --- Decision ---------------------------------------------------------------

deny() {
    local reason="$1"
    jq -nc \
        --arg reason "$reason" \
        --arg event "PreToolUse" \
        '{hookSpecificOutput: {hookEventName: $event, permissionDecision: "deny", permissionDecisionReason: $reason}}'
    exit 0
}

if [[ "$active_count" -ge "$ceiling" ]]; then
    if [[ "$orphan_count" -gt 0 ]]; then
        deny "agent ceiling reached: $active_count/$ceiling concurrent subagents in this session. Note: $orphan_count stale state file(s) were reclaimed by the orphan GC (mtime > ${ORPHAN_THRESHOLD_HOURS}h); the actual concurrent count is $active_count. To raise the limit for this machine, set RALPH_AGENT_CEILING in the env block of ~/.claude/settings.json (the documented escape hatch); restarting Claude Code is required for the change to take effect."
    else
        deny "agent ceiling reached: $active_count/$ceiling concurrent subagents in this session. To raise the limit for this machine, set RALPH_AGENT_CEILING in the env block of ~/.claude/settings.json (the documented escape hatch); restarting Claude Code is required for the change to take effect."
    fi
fi

# Allow: clean exit, no stdout.
exit 0
