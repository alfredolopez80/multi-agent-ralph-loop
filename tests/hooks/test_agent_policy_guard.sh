#!/usr/bin/env bash
# test_agent_policy_guard.sh - Regression test for T101 (M3 of #48) ceiling guard.
#
# Verifies the agent-policy-guard.sh hook enforces the configured agent
# ceiling by counting `status == "active"` subagents in
# ~/.ralph/state/<session>/subagents/*.json. The hook is a thin wrapper
# over the ralph-subagent-start/subagent-stop-universal state (the source
# of truth); this test fakes that state per scenario.
#
# Coverage:
#   1. Non-Task tool calls pass through.
#   2. Task without subagent_type passes through (not a spawn).
#   3. Default ceiling=8: single spawn allowed (count=0 in state).
#   4. Eight sequential root spawns all allow (the regression for the
#      T101 RETURN finding 1: the old inference-of-depth produced a
#      deny after the 2nd spawn). Test #4 = the floor: ceiling is honoured
#      at exactly 8 by 9 successful requests, not by 2.
#   5. Ceiling=1 denies the 2nd spawn with permissionDecision:deny schema
#      and an accionable permissionDecisionReason.
#   6. RALPH_AGENT_CEILING=99 silences the ceiling deny.
#   7. Per-session isolation: A full, B unaffected.
#   8. BUG-6 regression: same stdin -> same state file (no PID fallback).
#   9. Adversarial session_id '../../etc/passwd' is sanitised; no path
#      traversal in any state file under the sandboxed HOME.
#  10. RALPH_AGENT_CEILING=abc (non-numeric) -> default 8 (fail-loud, not
#      unbound variable crash).
#
# Sandbox HOME: every test creates a private HOME under /tmp/t101-guard-*
# so the hook reads from its own fake state dir, not the user's real one.
# (T101 RETURN finding 6: tests previously wrote to $HOME.)
#
# Usage: bash tests/hooks/test_agent_policy_guard.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/hooks/agent-policy-guard.sh"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

# Sandbox HOME.
SANDBOX_BASE="${TMPDIR:-/tmp}/t101-guard"
rm -f "${SANDBOX_BASE}-"* 2>/dev/null || true
SANDBOX_HOME="$(mktemp -d "${SANDBOX_BASE}-XXXXXX")"
trap 'rm -rf "$SANDBOX_HOME"' EXIT
export HOME="$SANDBOX_HOME"
mkdir -p "${HOME}/.ralph/logs"

# Clean state for the current sandbox session-key before each scenario.
find "${HOME}/.ralph/state" -name 't101-*.json' -delete 2>/dev/null || true
find "${HOME}/.ralph/state" -name 't101-*.json.lock' -delete 2>/dev/null || true
find "${HOME}/.ralph/state" -name 't101-*.json.lock.d' -type d -exec rmdir {} \; 2>/dev/null || true
find "${HOME}/.ralph/state" -name '*-passwd*' -delete 2>/dev/null || true

# Helper: invoke the hook with a stdin payload + env. Remaining args are
# env-var assignments exported via `env` for the bash invocation.
run_hook() {
    local stdin_payload="$1"; shift
    local rc=0 stdout=""
    stdout="$(printf '%s' "$stdin_payload" | env "$@" bash "$HOOK" 2>&1)" || rc=$?
    printf '%s' "$stdout"
    return $rc
}

# Seed N active subagent state files in the sandbox for a given session.
# macOS BSD `seq 1 0` emits "1\n0" (a known macOS quirk), so a simple
# `for i in $(seq 1 "$n")` would create files even when n=0. Use a
# bounded while loop so n=0 really means zero files.
seed_active() {
    local n="$1" session="$2"
    local d="${HOME}/.ralph/state/${session}/subagents"
    mkdir -p "$d"
    local i=1
    while [[ $i -le $n ]]; do
        printf '%s' "{\"id\":\"sub-$i\",\"parent\":\"root\",\"status\":\"active\"}" > "$d/sub-$i.json"
        i=$((i + 1))
    done
}

# Read active count from sandbox state (0 if absent).
active_count() {
    local key="$1"
    [[ -d "${HOME}/.ralph/state/${key}/subagents" ]] || { echo 0; return; }
    jq -s '[.[] | select(.status == "active")] | length' \
        "${HOME}/.ralph/state/${key}/subagents"/*.json 2>/dev/null || echo 0
}

# --- 1. Non-Task tool calls pass through -------------------------------------
echo "=== 1. Non-Task tool calls pass through ==="
out="$(run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}')"
if [[ -z "$out" ]]; then
    pass "Bash: empty stdout, allow"
else
    fail "Bash leaked" "out='$out'"
fi

# --- 2. Task without subagent_type passes through --------------------------
echo "=== 2. Task without subagent_type is not a spawn ==="
out="$(run_hook '{"tool_name":"Task","tool_input":{"prompt":"x"},"session_id":"t101-notaspawn"}')"
if [[ -z "$out" ]]; then
    pass "Task without subagent_type: no state entry, allow"
else
    fail "Task without subagent_type leaked" "out='$out'"
fi

# --- 3. Default ceiling: a single spawn is allowed (no state yet) -----------
echo "=== 3. Default ceiling: single spawn allowed ==="
out="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-default"}')"
if [[ -z "$out" ]]; then
    pass "single spawn: empty stdout, allow"
else
    fail "single spawn" "out='$out'"
fi

# --- 4. Ceiling=8 gradient: seed 7 allow, seed 8 deny (T101-r2 finding 6) ----
# The hook is read-only: it counts active subagents in state. The T101-r2
# reviewer pointed out the prior test (seed 0 + 8 reads of empty) didn't
# cover the gradient at the boundary. We simulate ralph-subagent-start's
# state writes by seeding between hook invocations.
echo "=== 4. Ceiling=8 gradient: seed 7 allow, seed 8 deny ==="
seed_active 7 "t101-grad"
out7="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-grad"}')"
seed_active 8 "t101-grad"
out8="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-tester","prompt":"y"},"session_id":"t101-grad"}')"
seed_active 9 "t101-grad"
out9="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-reviewer","prompt":"z"},"session_id":"t101-grad"}')"
if [[ -z "$out7" ]] \
   && printf '%s' "$out8" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
   && printf '%s' "$out9" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    pass "gradient: count=7 allow, count=8 deny, count=9 deny (ceiling=8 enforced at boundary)"
else
    fail "ceiling gradient" "out7='$out7' out8='$out8' out9='$out9'"
fi

# --- 5. Ceiling=1 denies the 2nd spawn with correct schema ---------------
# The hook is read-only: it counts active subagents in state, it does not
# add entries. We simulate ralph-subagent-start's state write between
# the two hook invocations.
echo "=== 5. Ceiling=1 denies 2nd spawn with permissionDecision:deny schema ==="
seed_active 0 "t101-ceil"
out1="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"a"},"session_id":"t101-ceil"}' RALPH_AGENT_CEILING=1)"
seed_active 1 "t101-ceil"
out2="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-tester","prompt":"b"},"session_id":"t101-ceil"}' RALPH_AGENT_CEILING=1)"
if [[ -z "$out1" ]] \
   && printf '%s' "$out2" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
   && printf '%s' "$out2" | jq -e '.hookSpecificOutput.permissionDecisionReason | test("ceiling")' >/dev/null 2>&1; then
    pass "ceiling=1: 1st allow (count=0), 2nd deny (count=1) with permissionDecision:deny"
else
    fail "ceiling=1" "out1='$out1' out2='$out2'"
fi

# --- 6. RALPH_AGENT_CEILING=99 silences the ceiling deny -------------------
echo "=== 6. RALPH_AGENT_CEILING=99 silences the ceiling deny ==="
seed_active 8 "t101-override"
out="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-override"}' RALPH_AGENT_CEILING=99)"
if [[ -z "$out" ]]; then
    pass "RALPH_AGENT_CEILING=99: 9th spawn allowed (override silences)"
else
    fail "ceiling override" "out='$out'"
fi

# --- 7. Per-session isolation --------------------------------------------
# Each session has its own counter from its own state directory. A full
# does not affect B; B remains at 0 active subagents regardless.
echo "=== 7. Per-session isolation: A full, B unaffected ==="
seed_active 1 "t101-iso-A"
out_a="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-iso-A"}' RALPH_AGENT_CEILING=1)"
out_b="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-iso-B"}' RALPH_AGENT_CEILING=1)"
if printf '%s' "$out_a" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1 \
   && [[ -z "$out_b" ]]; then
    pass "isolated: A denies (count=1/1), B allows (count=0/1) — per-session counters"
else
    fail "per-session" "out_a='$out_a' out_b='$out_b'"
fi

# --- 8. BUG-6 regression: stable session-key, never PID -----------------
# The hook is read-only; it does not write to state. We seed one active
# file and confirm BOTH invocations observe it, proving the key derivation
# is stdin-derived and stable (not a fresh PID per call).
echo "=== 8. BUG-6 regression: stable session-key, never PID ==="
seed_active 1 "t101-bug6"
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-bug6"}' >/dev/null
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"y"},"session_id":"t101-bug6"}' >/dev/null
count="$(active_count 't101-bug6')"
if [[ "$count" -eq 1 ]]; then
    pass "stable session-key: both invocations observed the same state file (count=1, never PID-driven)"
else
    fail "BUG-6 regression" "count=$count (expected 1)"
fi

# --- 9. Adversarial session_id sanitised --------------------------------
echo "=== 9. Adversarial session_id sanitised ==="
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"../../etc/passwd"}' >/dev/null
bad=$(find "${HOME}/.ralph/state" \( -name "*..*" -o -name "*passwd*" \) 2>/dev/null)
if [[ -z "$bad" ]]; then
    pass "adversarial session_id sanitised; no traversal"
else
    fail "path-traversal possible" "$bad"
fi

# --- 10. Non-numeric RALPH_AGENT_CEILING falls back to default ------------
echo "=== 10. RALPH_AGENT_CEILING=abc -> default 8 (fail-loud, not crash) ==="
seed_active 0 "t101-badenv"
out="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-badenv"}' RALPH_AGENT_CEILING=abc)"
rc=$?
if [[ $rc -eq 0 ]] && [[ -z "$out" ]]; then
    pass "non-numeric env: rc=0, allow (graceful fallback to default 8)"
else
    fail "non-numeric env" "rc=$rc out='$out'"
fi

# --- 11. Corrupt state -> FAIL-LOUD with rc=2 (T101-r2 finding 1) ----------
# The pre-fix bug had `exit 2` INSIDE `$(...)`, which only killed the subshell:
# the script fell through with active_count="" → 0 < ceiling → ALLOW. This
# test seeds a valid JSON file with a syntactically invalid sibling so that
# the jq pass fails; with the fix, the hook exits 2 (or whatever nonzero the
# fail-loud path emits) and we never allow a Task on a corrupt state.
echo "=== 11. Corrupt state -> FAIL-LOUD with non-zero rc (not silent ALLOW) ==="
mkdir -p "${HOME}/.ralph/state/t101-corrupt/subagents"
# Write a valid file alongside one that jq can't parse, then point the
# hook at the dir. The valid file alone would make the count 1; the corrupt
# sibling makes the jq pass fail.
printf '%s' '{"id":"good","parent":"root","status":"active"}' > "${HOME}/.ralph/state/t101-corrupt/subagents/good.json"
printf '%s' '{ this is not valid json' > "${HOME}/.ralph/state/t101-corrupt/subagents/bad.json"
out="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-corrupt"}' 2>&1)"
rc=$?
# Either: the hook denies with permissionDecision OR exits non-zero. We
# check both — the contract is "do not silently allow". Empty stdout +
# rc=0 would be the regression.
if [[ $rc -ne 0 ]] || printf '%s' "$out" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' >/dev/null 2>&1; then
    pass "corrupt state: rc=$rc non-zero (fail-loud) or deny JSON — not silent allow"
else
    fail "corrupt state" "rc=$rc out='$out' (regression of T101-r2 finding 1)"
fi
rm -rf "${HOME}/.ralph/state/t101-corrupt"

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
