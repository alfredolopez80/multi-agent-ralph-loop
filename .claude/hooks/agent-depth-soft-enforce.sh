#!/usr/bin/env bash
umask 077
# agent-depth-soft-enforce.sh - SubagentStart hook enforcing #48 depth limit.
# VERSION: 1.0.0 (T101 RETURN)
#
# Triggered by: SubagentStart hook event (matcher: ralph-* via settings.json)
# Purpose: compute the new subagent's depth as the EXACT length of its
#          parentId chain (no heuristics, no freshness windows) and emit an
#          early-exit directive into additionalContext when the chain would
#          exceed RALPH_AGENT_DEPTH. The subagent terminates on its first
#          turn, so the gate is enforced without cutting the parent's turn
#          (a PreToolUse deny would) and without a parallel counter
#          (the state files in ~/.ralph/state/<session>/subagents/*.json are
#          the source of truth, written by ralph-subagent-start.sh and
#          marked completed by subagent-stop-universal.sh).
#
# Configuration (env vars):
#   RALPH_AGENT_DEPTH     default 2   (max nesting depth; root counted as 0)
#
# Chain walk (exact, no heuristics):
#   1. New agent's parent_id is read from stdin SubagentStart payload.
#   2. Walk: parent -> parent -> ... until "root" or unknown.
#   3. depth = number of edges walked (root -> A1 = 1, A1 -> A2 = 2, ...).
#   4. If depth > RALPH_AGENT_DEPTH: emit DEPTH_EXCEEDED directive.
#
# Output (allow): {"continue": true, "hookSpecificOutput": {"hookEventName":
#   "SubagentStart", "additionalContext": "<contextual block>"}}.
# Output (depth-exceeded): additionalContext carries the DEPTH_EXCEEDED
#   directive; the subagent terminates on its first turn with
#   `depth-exceeded` reported to the caller.

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
        printf '[%s] agent-depth-soft-enforce: %s\n' "$ts" "$msg" >> "$LOG_FILE" 2>/dev/null || true
    else
        printf '[%s] agent-depth-soft-enforce: %s\n' "$ts" "$msg" >&2 || true
    fi
}

DEFAULT_DEPTH=2

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

depth_limit="$(validate_int RALPH_AGENT_DEPTH "$DEFAULT_DEPTH")"

INPUT="$(head -c 100000)"

agent_id="$(printf '%s' "$INPUT" | jq -r '.agent_id // .subagentId // .subagent_id // empty' 2>/dev/null || true)"
parent_id="$(printf '%s' "$INPUT" | jq -r '.parent_id // .parentId // "root"' 2>/dev/null || true)"
session_id="$(printf '%s' "$INPUT" | jq -r '.sessionId // .session_id // "default"' 2>/dev/null || true)"

session_id="$(printf '%s' "$session_id" | tr -cd '[:alnum:]-_' | head -c 128)"
[[ -z "$session_id" ]] && session_id="default"
agent_id="$(printf '%s' "$agent_id" | tr -cd '[:alnum:]-_' | head -c 128)"
parent_id="$(printf '%s' "$parent_id" | tr -cd '[:alnum:]-_' | head -c 128)"

RALPH_STATE_DIR="${RALPH_STATE_DIR:-${HOME}/.ralph}"
subagents_dir="${RALPH_STATE_DIR}/state/${session_id}/subagents"

chain_log=""
depth=0
current="$parent_id"

if [[ "$parent_id" == "root" || -z "$parent_id" ]]; then
    depth=1
    chain_log="root -> ${agent_id}"
else
    safety=20
    while [[ -n "$current" && "$current" != "root" && $safety -gt 0 ]]; do
        depth=$((depth + 1))
        chain_log="${chain_log}${current} -> "
        state_file="${subagents_dir}/${current}.json"
        if [[ ! -f "$state_file" ]]; then
            chain_log="${chain_log}missing -> "
            break
        fi
        current="$(jq -r '.parent // "root"' "$state_file" 2>/dev/null || echo "root")"
        current="$(printf '%s' "$current" | tr -cd '[:alnum:]-_' | head -c 128)"
        safety=$((safety - 1))
    done
    if [[ "$current" == "root" ]]; then
        depth=$((depth + 1))
        chain_log="${chain_log}root -> ${agent_id} depth=${depth}"
    else
        chain_log="${chain_log}partial depth=${depth}"
    fi
fi

if [[ "$depth" -gt "$depth_limit" ]]; then
    log "ERROR: agent-policy depth exceeded for ${agent_id} chain=${chain_log} threshold=${depth_limit} soft-enforce=directive"
    directive_msg="DEPTH_EXCEEDED: You are at depth ${depth} in the parent chain (chain: ${chain_log}). Policy RALPH_AGENT_DEPTH=${depth_limit} forbids this nesting. Terminate IMMEDIATELY in this turn: report depth-exceeded to your caller and exit. Do not perform any task work."
    directive_str=$(printf '%s' "$directive_msg" | jq -Rs '.')
    extra_ctx=$(jq -nc --arg ctx "$directive_str" '$ctx | fromjson')
    jq -nc --arg ctx "$extra_ctx" '{continue: true, hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: $ctx}}'
    exit 0
fi

allow_msg="# SubagentStart T101 depth-check: chain ${chain_log} depth=${depth} limit=${depth_limit} OK"
jq -nc --arg ctx "$allow_msg" '{continue: true, hookSpecificOutput: {hookEventName: "SubagentStart", additionalContext: $ctx}}'
exit 0
