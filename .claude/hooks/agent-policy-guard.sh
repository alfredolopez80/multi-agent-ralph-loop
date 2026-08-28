#!/usr/bin/env bash
# agent-policy-guard.sh — PreToolUse:Task guard enforcing #48 agent policy
# VERSION: 1.0.0 (T101)
#
# Triggered by: PreToolUse:Task hook event
# Purpose: deny Task tool invocations that would exceed the configured
#          agent ceiling or depth limit, per the M3 acceptance bullet of
#          issue #48:
#
#            "Configurable agent ceiling starts at 8; depth <=2 is tested
#             and easy to configure."
#
# Configuration (env vars, with defaults set by #48):
#   RALPH_AGENT_CEILING   default 8   (max concurrent subagents per session)
#   RALPH_AGENT_DEPTH     default 2   (max nesting depth, root counted as 0)
#
# State file (per-session, atomic write, mkdir-based mutex):
#   ~/.ralph/state/agent-policy/<session-key>.json
#
#   {
#     "active": [
#       {"id":"sub-XXX","depth":1,"parent_id":"root","subagent_type":"ralph-coder","started_at":"..."},
#       {"id":"sub-YYY","depth":2,"parent_id":"sub-XXX","subagent_type":"ralph-tester","started_at":"..."}
#     ],
#     "last_updated": "2026-08-28T15:00:00Z"
#   }
#
# session-key: derived from stdin .session_id, sanitised to filename-safe
#              characters. Falls back to a stable digest of cwd + YYYYMMDD
#              when .session_id is absent. NEVER uses PID (BUG-6 regression —
#              see tests/hooks/test_session_dedup_key.sh).
#
# Outputs:
#   allow  -> clean exit 0 (no stdout; the harness reads rc 0 as allow)
#   deny   -> {"continue":false,"stopReason":"agent ceiling N reached: ..."}
#
# Notes:
#   - This guard does NOT decrement active[] on SubagentStop. The
#     session-key scope means a fresh session starts at zero; this is
#     acceptable for the #48 wording ("max concurrent spawned agents")
#     because the counter resets per session. A SubagentStop-side
#     decrementer is intentionally left for a separate task (so this hook
#     stays single-responsibility).
#   - Depth inference: the caller of the new Task is treated as the most
#     recently spawned active subagent. proposed_depth = caller_depth + 1
#     (or 1 when active[] is empty, i.e. the caller is the root session).
#   - Lock: mkdir-based mutex (POSIX, no flock dependency). The lock
#     directory is removed on EXIT via trap.

set -uo pipefail

_HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${_HOOK_DIR}/lib/plan-state-writer.sh" 2>/dev/null || true

# --- Configuration ----------------------------------------------------------

CEILING="${RALPH_AGENT_CEILING:-8}"
DEPTH_LIMIT="${RALPH_AGENT_DEPTH:-2}"

STATE_ROOT="${HOME}/.ralph/state/agent-policy"
mkdir -p "$STATE_ROOT" 2>/dev/null || true

# --- Input parsing ----------------------------------------------------------

INPUT="$(head -c 100000)"

tool_name="$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)"
if [[ "$tool_name" != "Task" ]]; then
    exit 0
fi

subagent_type="$(printf '%s' "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)"
if [[ -z "$subagent_type" || "$subagent_type" == "null" ]]; then
    # Task tool without subagent_type is not a subagent spawn (could be a
    # generic Task). Out of scope for the agent-policy guard.
    exit 0
fi

# --- Session-key derivation (BUG-6 regression) -------------------------------

session_key="$(printf '%s' "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)"
if [[ -z "$session_key" || "$session_key" == "null" ]]; then
    # Stable fallback: cwd digest + YYYYMMDD. NEVEN PID.
    cwd_digest="$(pwd | tr -cd '[:alnum:]._-' | head -c 32)"
    session_key="cwd-${cwd_digest}-$(date +%Y%m%d)"
fi
# Sanitise to filename-safe characters (no /, no whitespace). Then collapse
# any run of two-or-more dots to a single underscore so a payload like
# "../../etc/passwd" cannot produce a "...." segment that some downstream
# tool might resolve as path traversal. Single dots (legitimate in UUIDs
# and dotted session-ids) are preserved.
session_key="$(printf '%s' "$session_key" | tr -cd '[:alnum:]._-' | sed 's/\.\.\+/_/g' | head -c 128)"
if [[ -z "$session_key" || "$session_key" == *".."* || "$session_key" == *"/"* ]]; then
    cwd_digest="$(pwd | tr -cd '[:alnum:]-_' | head -c 32)"
    session_key="cwd-${cwd_digest}-$(date +%Y%m%d)"
fi

state_file="${STATE_ROOT}/${session_key}.json"

# --- Mutex (mkdir-based, portable) ------------------------------------------

lockdir="${state_file}.lock"
acquired=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
    if mkdir "$lockdir" 2>/dev/null; then
        acquired=1
        break
    fi
    sleep 0.05 2>/dev/null || sleep 1
done
if [[ "$acquired" -ne 1 ]]; then
    # Could not acquire lock after 10 attempts. Fail OPEN for the spawn
    # to avoid a deadlock from a stuck lock — but log so the operator sees.
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] agent-policy-guard: WARN lock not acquired for ${state_file}" \
        >> "${HOME}/.ralph/logs/agent-policy.log" 2>/dev/null || true
    exit 0
fi
trap 'rmdir "$lockdir" 2>/dev/null || true' EXIT

# --- Read state (initialise if missing) -------------------------------------

if [[ ! -f "$state_file" ]]; then
    mkdir -p "$(dirname "$state_file")" 2>/dev/null || true
    jq -n --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{active: [], last_updated: $now}' > "$state_file" || {
        rmdir "$lockdir" 2>/dev/null || true
        exit 0  # fail-open on I/O error to avoid blocking legitimate work
    }
fi

active_json="$(jq -c '.active' "$state_file" 2>/dev/null || echo '[]')"
active_count="$(printf '%s' "$active_json" | jq 'length' 2>/dev/null || echo 0)"

# --- Inference: caller depth and proposed depth -----------------------------

# The "caller" of the new Task is treated as the most recently spawned
# active subagent. If active[] is empty, the caller is the root session
# (depth = 0). This is a conservative inference: when the model spawns
# from the root, depth = 1; when a depth-1 subagent spawns, depth = 2.
caller_id="root"
caller_depth=0
if [[ "$active_count" -gt 0 ]]; then
    last="$(printf '%s' "$active_json" | jq -c '. | sort_by(.started_at) | last' 2>/dev/null || echo '{}')"
    caller_id="$(printf '%s' "$last" | jq -r '.id // "root"' 2>/dev/null)"
    caller_depth="$(printf '%s' "$last" | jq -r '.depth // 0' 2>/dev/null)"
fi

proposed_depth=$((caller_depth + 1))

# --- Decision ---------------------------------------------------------------

deny() {
    local reason="$1"
    jq -n --arg reason "$reason" \
        '{continue: false, stopReason: $reason}'
    exit 0  # hooks exit 0 even on deny; the JSON signals the decision
}

if [[ "$active_count" -ge "$CEILING" ]]; then
    deny "agent ceiling reached: ${active_count}/${CEILING} concurrent subagents in this session. Wait for one to finish or raise RALPH_AGENT_CEILING."
fi

if [[ "$proposed_depth" -gt "$DEPTH_LIMIT" ]]; then
    deny "agent depth limit reached: caller at depth ${caller_depth}, proposed ${proposed_depth} > limit ${DEPTH_LIMIT}. Spawn from a shallower agent or raise RALPH_AGENT_DEPTH."
fi

# --- Approve: append new active subagent ------------------------------------

new_id="sub-$(date +%s%N | tail -c 8)"
new_entry="$(jq -c -n \
    --arg id "$new_id" \
    --argjson depth "$proposed_depth" \
    --arg parent "$caller_id" \
    --arg type "$subagent_type" \
    --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{id: $id, depth: $depth, parent_id: $parent, subagent_type: $type, started_at: $now}')"

tmp="$(mktemp "${state_file}.XXXXXX")" || {
    rmdir "$lockdir" 2>/dev/null || true
    exit 0
}
chmod 600 "$tmp"
jq --argjson entry "$new_entry" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '.active += [$entry] | .last_updated = $now' \
    "$state_file" > "$tmp" || {
    rm -f "$tmp"
    rmdir "$lockdir" 2>/dev/null || true
    exit 0
}
mv "$tmp" "$state_file"

# Allow: clean exit, no stdout.
exit 0
