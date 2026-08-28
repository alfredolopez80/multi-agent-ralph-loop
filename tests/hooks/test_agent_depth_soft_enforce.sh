#!/usr/bin/env bash
# test_agent_depth_soft_enforce.sh - Regression test for T101 depth-check hook.
#
# Walks a real parent-chain fixture (3 levels) and asserts:
#  - depth 1 (parent=root) -> additionalContext says chain=root->X, depth=1
#  - depth 2 (parent=A1 active in state) -> depth=2, allow
#  - depth 3 (parent=A2 active in state) -> additionalContext carries
#    DEPTH_EXCEEDED directive, agent terminates on first turn.
#
# Sandbox HOME: every test creates a private HOME under /tmp/t101-depth-* so
# the hook reads from its own fake state dir, not the real one (T101 RETURN
# finding 6: tests previously wrote to the user's real $HOME).
#
# Usage: bash tests/hooks/test_agent_depth_soft_enforce.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="${REPO_ROOT}/.claude/hooks/agent-depth-soft-enforce.sh"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

# Sandbox HOME so the hook writes to /tmp/t101-depth-*/.ralph, not $HOME.
SANDBOX_BASE="${TMPDIR:-/tmp}/t101-depth"
rm -f "${SANDBOX_BASE}-"* 2>/dev/null || true
SANDBOX_HOME="$(mktemp -d "${SANDBOX_BASE}-XXXXXX")"
trap 'rm -rf "$SANDBOX_HOME"' EXIT
export HOME="$SANDBOX_HOME"

# Pre-create the log directory the hook writes to. Otherwise the hook's
# fallback path emits to stderr, which contaminates the captured output the
# test parses as JSON.
mkdir -p "${HOME}/.ralph/logs"

# Helper: invoke the hook with a stdin payload + env. The remaining args are
# env-var assignments that are exported via `env` for the bash invocation.
run_hook() {
    local stdin_payload="$1"; shift
    local rc=0 stdout=""
    stdout="$(printf '%s' "$stdin_payload" | env "$@" bash "$HOOK" 2>&1)" || rc=$?
    printf '%s' "$stdout"
    return $rc
}

# --- 1. depth 1 (parent=root) -> allow with chain root->X --------------------
echo "=== 1. depth 1 (parent=root) -> allow ==="
out="$(run_hook '{"agent_id":"A1","parent_id":"root","sessionId":"test-session","agent_type":"ralph-coder"}')"
if printf '%s' "$out" | jq -e '.continue == true' >/dev/null 2>&1 \
   && printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "depth=1"; then
    pass "depth 1: continue=true, chain root->A1, depth=1"
else
    fail "depth 1" "out='$out'"
fi

# --- 2. depth 2 (parent=A1 in state) -> allow --------------------------------
# Plant A1 as active in state.
mkdir -p "${HOME}/.ralph/state/test-session/subagents"
printf '%s' '{"id":"A1","parent":"root","status":"active"}' \
    > "${HOME}/.ralph/state/test-session/subagents/A1.json"
echo "=== 2. depth 2 (parent=A1 active) -> allow ==="
out="$(run_hook '{"agent_id":"A2","parent_id":"A1","sessionId":"test-session","agent_type":"ralph-tester"}')"
if printf '%s' "$out" | jq -e '.continue == true' >/dev/null 2>&1 \
   && printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null | grep -q "depth=2"; then
    pass "depth 2: continue=true, chain root->A1->A2, depth=2"
else
    fail "depth 2" "out='$out'"
fi

# --- 3. depth 3 (parent=A2 in state) -> DEPTH_EXCEEDED directive ------------
# Plant A2 as active.
printf '%s' '{"id":"A2","parent":"A1","status":"active"}' \
    > "${HOME}/.ralph/state/test-session/subagents/A2.json"
echo "=== 3. depth 3 (parent=A2 active) -> DEPTH_EXCEEDED directive ==="
out="$(run_hook '{"agent_id":"A3","parent_id":"A2","sessionId":"test-session","agent_type":"ralph-reviewer"}' RALPH_AGENT_DEPTH=2)"
if printf '%s' "$out" | jq -e '.continue == true' >/dev/null 2>&1 \
   && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | tostring | contains("DEPTH_EXCEEDED")' >/dev/null 2>&1; then
    pass "depth 3: continue=true, additionalContext carries DEPTH_EXCEEDED directive"
else
    fail "depth 3" "out='$out'"
fi

# --- 4. RALPH_AGENT_DEPTH override silences the depth-exceeded DENY --------
# Walk a depth-4 chain. With default depth=2 it would deny; with depth=4 it allows.
mkdir -p "${HOME}/.ralph/state/deep-session/subagents"
printf '%s' '{"id":"D1","parent":"root","status":"active"}' > "${HOME}/.ralph/state/deep-session/subagents/D1.json"
printf '%s' '{"id":"D2","parent":"D1","status":"active"}' > "${HOME}/.ralph/state/deep-session/subagents/D2.json"
printf '%s' '{"id":"D3","parent":"D2","status":"active"}' > "${HOME}/.ralph/state/deep-session/subagents/D3.json"
echo "=== 4. RALPH_AGENT_DEPTH=4 silences depth-exceeded ==="
out="$(run_hook '{"agent_id":"D4","parent_id":"D3","sessionId":"deep-session","agent_type":"ralph-coder"}' RALPH_AGENT_DEPTH=4)"
if printf '%s' "$out" | jq -e '.continue == true' >/dev/null 2>&1 \
   && ! printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext | tostring | contains("DEPTH_EXCEEDED")' >/dev/null 2>&1; then
    pass "RALPH_AGENT_DEPTH=4: depth 4 allowed (no DEPTH_EXCEEDED)"
else
    fail "depth override" "out='$out'"
fi

# --- 5. RALPH_AGENT_DEPTH=abc (non-numeric) falls back to default ------------
echo "=== 5. RALPH_AGENT_DEPTH=abc -> default 2 (fail-loud, not crash) ==="
out="$(run_hook '{"agent_id":"A4","parent_id":"A2","sessionId":"test-session","agent_type":"ralph-coder"}' RALPH_AGENT_DEPTH=abc)"
rc=$?
if [[ $rc -eq 0 ]] \
   && printf '%s' "$out" | jq -e '.continue == true' >/dev/null 2>&1; then
    pass "non-numeric env var: rc=0, JSON valid (graceful fallback)"
else
    fail "non-numeric env" "rc=$rc out='$out'"
fi

# --- 6. Missing parent in state -> partial walk, allow ------------------------
# (T91: ancestor not registered yet — the walk stops; we still allow with
# a partial-depth hint, since the chain isn't definitively over the limit.)
printf '%s' '{"id":"ROOT_ONLY","parent":"root","status":"active"}' \
    > "${HOME}/.ralph/state/partial/subagents/ROOT_ONLY.json"
echo "=== 6. parent with missing state file -> partial walk ==="
out="$(run_hook '{"agent_id":"ORPHAN","parent_id":"NO_STATE","sessionId":"partial","agent_type":"ralph-coder"}')"
if printf '%s' "$out" | jq -e '.continue == true' >/dev/null 2>&1; then
    pass "missing ancestor state: continue=true (no false deny)"
else
    fail "missing ancestor" "out='$out'"
fi

# --- 7. Empty stdin -> allow (no agent_id means nothing to do) --------------
echo "=== 7. Empty stdin -> allow (no agent_id, no work) ==="
out="$(run_hook '{}')"
if printf '%s' "$out" | jq -e '.continue == true' >/dev/null 2>&1; then
    pass "empty stdin: continue=true"
else
    fail "empty stdin" "out='$out'"
fi

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
