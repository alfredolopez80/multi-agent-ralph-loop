#!/usr/bin/env bash
# test_agent_policy_guard.sh — Regression test for T101 (M3 of #48).
#
# Verifies the agent-policy-guard.sh hook enforces:
#   - agent ceiling (default 8, configurable via RALPH_AGENT_CEILING)
#   - depth limit (default 2, configurable via RALPH_AGENT_DEPTH)
#   - per-session isolation (state keyed by session_id)
#   - non-Task tool calls pass through untouched
#   - Task calls without subagent_type pass through (they are not spawns)
#   - session-key derivation is stable and stdin-derived (BUG-6 regression
#     — never falls back to PID; stable across invocations)
#
# Usage: bash tests/hooks/test_agent_policy_guard.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/hooks/agent-policy-guard.sh"
STATE_ROOT="${HOME}/.ralph/state/agent-policy"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

# Clean state before each scenario. Use a unique session-key per test to
# avoid cross-pollution between sub-cases. Uses `find -delete` rather
# than globbing because some macOS bash + nounset combinations leave the
# glob unexpanded and rm silently does nothing.
clean_state() {
    find "${STATE_ROOT}" -maxdepth 1 -name 't101-*.json' -delete 2>/dev/null || true
    find "${STATE_ROOT}" -maxdepth 1 -name 't101-*.json.lock' -delete 2>/dev/null || true
    # Lockdirs are directories, not files.
    find "${STATE_ROOT}" -maxdepth 1 -name 't101-*.json.lock.d' -type d -exec rmdir {} \; 2>/dev/null || true
}

# --- helpers --------------------------------------------------------------

# Run the hook with a stdin payload + env, capture stdout + rc.
# Usage: run_hook '{"tool":...}' [ENV=val ...]
# The first arg is the stdin payload piped into the hook. Remaining args
# are env-var assignments that are exported via `env` for the bash invocation.
run_hook() {
    local stdin_payload="$1"; shift
    local rc=0 stdout=""
    stdout="$(printf '%s' "$stdin_payload" | env "$@" bash "$HOOK" 2>&1)" || rc=$?
    printf '%s' "$stdout"
    return $rc
}

# Read active count from state file (returns 0 if file absent or empty).
active_count() {
    local key="$1"
    [[ -f "${STATE_ROOT}/${key}.json" ]] || { echo 0; return; }
    jq '.active | length' "${STATE_ROOT}/${key}.json" 2>/dev/null || echo 0
}

# --- 1. Non-Task tool calls pass through ----------------------------------
echo "=== 1. Non-Task tool calls pass through untouched ==="
clean_state
out="$(run_hook '{"tool_name":"Bash","tool_input":{"command":"ls"}}')"
if [[ -z "$out" ]] && [[ "$(active_count 't101-passthru')" == "0" ]]; then
    pass "Bash call: empty output + state untouched"
else
    fail "Bash call leaked" "out='$out' count=$(active_count 't101-passthru')"
fi
out="$(run_hook '{"tool_name":"Edit","tool_input":{}}')"
[[ -z "$out" ]] && pass "Edit call: empty output" || fail "Edit call leaked" "out='$out'"

# --- 2. Task without subagent_type passes through -------------------------
echo
echo "=== 2. Task without subagent_type is not a spawn (passes through) ==="
clean_state
out="$(run_hook '{"tool_name":"Task","tool_input":{"prompt":"todo"},"session_id":"t101-notaspawn"}')"
if [[ -z "$out" ]] && [[ "$(active_count 't101-notaspawn')" == "0" ]]; then
    pass "Task without subagent_type: no state entry"
else
    fail "Task without subagent_type leaked into state" "out='$out' count=$(active_count 't101-notaspawn')"
fi

# --- 3. Default ceiling + depth: a single spawn is allowed ---------------
echo
echo "=== 3. Defaults: ceiling=8, depth=2; single spawn allowed ==="
clean_state
out="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-default"}')"
if [[ -z "$out" ]] && [[ "$(active_count 't101-default')" == "1" ]]; then
    pass "single spawn: empty stdout, 1 active entry"
else
    fail "single spawn" "out='$out' count=$(active_count 't101-default')"
fi

# --- 4. Ceiling enforcement ----------------------------------------------
echo
echo "=== 4. Ceiling=1 denies the second spawn ==="
clean_state
out1="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"a"},"session_id":"t101-ceil"}')"
out2="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-tester","prompt":"b"},"session_id":"t101-ceil"}' "RALPH_AGENT_CEILING=1")"
if [[ -z "$out1" ]] \
   && printf '%s' "$out2" | jq -e '.continue == false' >/dev/null 2>&1 \
   && printf '%s' "$out2" | jq -r '.stopReason' 2>/dev/null | grep -qi "ceiling"; then
    pass "ceiling=1: 1st allow, 2nd deny with stopReason mentioning ceiling"
else
    fail "ceiling=1" "out1='$out1' out2='$out2' count=$(active_count 't101-ceil')"
fi

# --- 5. Depth enforcement ------------------------------------------------
echo
echo "=== 5. Depth=2 denies the third nested spawn ==="
clean_state
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"a"},"session_id":"t101-depth"}' >/dev/null
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-tester","prompt":"b"},"session_id":"t101-depth"}' >/dev/null
out3="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-reviewer","prompt":"c"},"session_id":"t101-depth"}' "RALPH_AGENT_DEPTH=2")"
if printf '%s' "$out3" | jq -e '.continue == false' >/dev/null 2>&1 \
   && printf '%s' "$out3" | jq -r '.stopReason' 2>/dev/null | grep -qi "depth"; then
    pass "depth=2: 1st/2nd allow, 3rd deny with stopReason mentioning depth"
else
    fail "depth=2" "out3='$out3' state=$(jq -c . ${STATE_ROOT}/t101-depth.json 2>/dev/null)"
fi

# --- 6. Env override silences ---------------------------------------------
echo
echo "=== 6. Env override RALPH_AGENT_DEPTH=99 silences the depth deny ==="
clean_state
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"a"},"session_id":"t101-override"}' >/dev/null
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-tester","prompt":"b"},"session_id":"t101-override"}' >/dev/null
out="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-reviewer","prompt":"c"},"session_id":"t101-override"}' "RALPH_AGENT_DEPTH=99")"
if [[ -z "$out" ]] && [[ "$(active_count 't101-override')" == "3" ]]; then
    pass "RALPH_AGENT_DEPTH=99: 3rd spawn allowed (override silences)"
else
    fail "env override" "out='$out' count=$(active_count 't101-override')"
fi

# --- 7. Per-session isolation --------------------------------------------
echo
echo "=== 7. Per-session isolation: session A full, session B unaffected ==="
clean_state
# Fill session A with 1 active entry, ceiling=1
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-iso-A"}' "RALPH_AGENT_CEILING=1" >/dev/null
# Session B has ceiling=1 too — should be able to spawn its own 1
out="$(run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-iso-B"}' "RALPH_AGENT_CEILING=1")"
if [[ -z "$out" ]] && [[ "$(active_count 't101-iso-A')" == "1" ]] && [[ "$(active_count 't101-iso-B')" == "1" ]]; then
    pass "isolated state files: A=1, B=1 (per-session counters)"
else
    fail "per-session isolation" "out='$out' A=$(active_count 't101-iso-A') B=$(active_count 't101-iso-B')"
fi

# --- 8. BUG-6 regression: session-key is stable, never PID ---------------
echo
echo "=== 8. BUG-6 regression: same stdin -> same state file (no PID fallback) ==="
clean_state
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"t101-bug6"}' >/dev/null
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"y"},"session_id":"t101-bug6"}' >/dev/null
# Both calls must have written to the SAME state file (key is deterministic).
# If the hook fell back to PID, each call would have written to a different
# file and active_count would be 1 each, but the file would differ.
count="$(active_count 't101-bug6')"
if [[ "$count" == "2" ]]; then
    pass "stable session-key: both invocations accumulated into 1 state file (count=2)"
else
    fail "BUG-6 regression: session-key may be unstable" "count=$count (expected 2)"
fi

# --- 9. Filename-safety: adversarial session_id --------------------------
echo
echo "=== 9. Adversarial session_id is sanitised (no path traversal) ==="
clean_state
run_hook '{"tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","prompt":"x"},"session_id":"../../etc/passwd"}' >/dev/null
# No file named with `..` or `passwd` should exist anywhere under STATE_ROOT.
bad=$(find "${STATE_ROOT}" \( -name "*..*" -o -name "*passwd*" \) 2>/dev/null)
if [[ -z "$bad" ]]; then
    pass "adversarial session_id sanitised; no traversal"
else
    fail "path-traversal possible" "$bad"
fi

# --- summary -------------------------------------------------------------
echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
