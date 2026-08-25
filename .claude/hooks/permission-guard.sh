#!/usr/bin/env bash
# permission-guard.sh — Unified permission pipeline (v2.1)
# Hook: PreToolUse (Bash|Edit|Write + Agent|Task)
# VERSION: 2.1.0
#
# v2.0.0 (issue #58): FAIL-CLOSED — every failure path now denies.
#   - Delegate exits non-zero with empty/unparseable output -> deny
#     (v1.1's `|| true` turned an unreachable delegate into ALLOW).
#   - Delegate stderr is preserved: logged to ~/.ralph/permission-guard.log
#     and re-emitted — a broken delegate must be visible, not silent.
#   - ERR/EXIT trap inverted to deny: v1.1 echoed ALLOW on any premature
#     death, so a syntax error in this file WAS a permission bypass. The
#     trap's virtue is kept (Claude Code always receives parseable JSON);
#     only its default changed: no conclusion reached => not allowed.
#   - v2.1.0 (T19): unparseable or EMPTY stdin payload -> deny. "Could not
#     read the input" is not "read it and have no objection": a malformed
#     payload reaching this guard means something upstream broke, and
#     answering allow to something unread is the exact shape of the bug
#     this guard exists to fix. A VALID payload for a tool this guard does
#     not cover still allows (the phases key on tool_name).
# v1.1.0: propagate permissionDecision "ask" from git-safety-guard.py
#         (cloud CLI confirmation tier) in addition to "deny"
#
# Consolidates: git-safety-guard.py + repo-boundary-guard.sh
# Strategy: Thin wrapper that dispatches stdin to original guards with
# short-circuit on block. Original guard logic is 100% preserved —
# both scripts remain on disk as internal modules.
#
# Delegate contract (verified against both delegates' sources):
#   git-safety-guard.py   allow -> JSON + exit 0; ask -> JSON + exit 0;
#                         deny  -> JSON + exit 1. Every terminal path prints
#                         JSON (allow_and_exit, CRIT-002; ask prints before
#                         sys.exit(0)). A non-zero exit WITH parseable JSON is
#                         a normal deny — propagate the JSON, not an error.
#   repo-boundary-guard.sh allow/deny -> JSON + exit 0; internal crash -> its
#                         own fail-closed deny (its trap, line 17).
#   Therefore: empty or unparseable output from a delegate is an INTERNAL
#   FAILURE, never a benign "no finding". Deny, loudly.
#
# SECURITY: SEC-111 (stdin limit), SEC-006 (error trap), umask 077

set -euo pipefail
umask 077

LOG_FILE="${HOME}/.ralph/permission-guard.log"

ALLOW='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'
# Premature death (set -e trip, missing utility, mktemp failure): deny.
DENY_TRAP='{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "permission-guard died before reaching a decision (ERR/EXIT trap) — see ~/.ralph/permission-guard.log"}}'

ERR1=""; ERR2=""
cleanup() { rm -f "${ERR1:-}" "${ERR2:-}" 2>/dev/null || true; }

# Idempotent trap body: under set -e a failure fires ERR first and EXIT right
# after — an unguarded trap would echo the deny JSON TWICE, producing
# unparseable output (which the harness may treat as a non-blocking error,
# i.e. a bypass). The flag guarantees exactly one verdict.
_TRAP_FIRED=""
_trap_deny() {
    [[ -n "$_TRAP_FIRED" ]] && return 0
    _TRAP_FIRED=1
    cleanup
    echo "$DENY_TRAP"
}
trap '_trap_deny' ERR EXIT

# Build a deny decision. jq when available (dynamic reason); a static deny if
# even jq is broken — the deny itself never depends on tooling health.
deny_json() {  # $1 = reason
    jq -nc --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}' 2>/dev/null \
        || echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "permission-guard: internal failure (jq unavailable)"}}'
}

# Best-effort log of a delegate failure. The decision is already deny when this
# runs; a logging failure must never change or block it.
log_delegate_failure() {  # $1 = delegate name, $2 = exit code, $3 = stderr file
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] delegate=$1 exit=$2"
        head -c 2000 "$3" 2>/dev/null
        echo ""
    } >> "$LOG_FILE" 2>/dev/null || true
}

# Emit the fail-closed verdict for a delegate that produced no parseable
# decision: log, re-emit its stderr (visible, not silent), deny.
deny_no_decision() {  # $1 = delegate name, $2 = exit code, $3 = stderr file
    log_delegate_failure "$1" "$2" "$3"
    cat "$3" >&2 2>/dev/null || true
    cleanup
    trap - ERR EXIT
    deny_json "permission-guard: $1 produced no parseable decision (exit=$2) — stderr logged to $LOG_FILE and re-emitted above"
    exit 0
}

# SEC-111: Read input once from stdin (100KB max)
INPUT=$(head -c 100000)

# T19 (issue #58): the payload itself must be parseable JSON. Empty stdin or
# garbage means the transport broke — deny, distinguishably from a VALID
# payload for a tool this guard does not cover (which allows below).
if [[ -z "$INPUT" ]] || ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
    trap - ERR EXIT
    deny_json "permission-guard: unparseable or empty stdin payload — cannot evaluate the operation (fail-closed)"
    exit 0
fi

HOOKS_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")

# --- Phase 1: Git Safety Check (Bash commands only) ---
# git-safety-guard.py blocks destructive git and filesystem commands.
if [[ "$TOOL_NAME" == "Bash" ]]; then
    ERR1="$(mktemp)"
    RC1=0
    SAFETY_RESULT=$(echo "$INPUT" | python3 "$HOOKS_DIR/git-safety-guard.py" 2>"$ERR1") || RC1=$?
    # Parse the decision. Empty or unparseable output = internal failure.
    SAFETY_DECISION=$(echo "$SAFETY_RESULT" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null) || SAFETY_DECISION=""
    if [[ -z "$SAFETY_DECISION" ]]; then
        deny_no_decision "git-safety-guard.py" "$RC1" "$ERR1"
    fi
    # v1.1.0: short-circuit on "deny" AND "ask" — swallowing "ask" would
    # silently allow destructive cloud CLI operations awaiting confirmation.
    # Note: deny arrives with exit 1; the JSON is authoritative, not the code.
    if [[ "$SAFETY_DECISION" == "deny" || "$SAFETY_DECISION" == "ask" ]]; then
        cleanup
        trap - ERR EXIT
        echo "$SAFETY_RESULT"
        exit 0
    fi
fi

# --- Phase 2: Repo Boundary Check (all applicable tools) ---
# repo-boundary-guard.sh handles tool-specific path extraction internally
# and works correctly for Bash, Edit, Write, Agent, and Task tools.
# Contract: allow/deny JSON only (no "ask") — deny is propagated, allow
# falls through.
ERR2="$(mktemp)"
RC2=0
BOUNDARY_RESULT=$(echo "$INPUT" | "$HOOKS_DIR/repo-boundary-guard.sh" 2>"$ERR2") || RC2=$?
BOUNDARY_DECISION=$(echo "$BOUNDARY_RESULT" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null) || BOUNDARY_DECISION=""
if [[ -z "$BOUNDARY_DECISION" ]]; then
    deny_no_decision "repo-boundary-guard.sh" "$RC2" "$ERR2"
fi
if [[ "$BOUNDARY_DECISION" == "deny" ]]; then
    cleanup
    trap - ERR EXIT
    echo "$BOUNDARY_RESULT"
    exit 0
fi

# All checks passed — allow the operation
cleanup
trap - ERR EXIT
echo "$ALLOW"
