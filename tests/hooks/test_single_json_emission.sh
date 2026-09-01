#!/usr/bin/env bash
# test_single_json_emission.sh - Regression test for BUG-3.
#
# BUG-3: hooks arm `trap 'output_json' ERR EXIT` but early-exit branches cleared
# only `trap - EXIT`. ERR stayed armed, so under `set -e` a failing command fired
# ERR (emitting JSON) and then EXIT (emitting again). stdout carried two
# concatenated objects, Claude Code reported
#   Hook JSON output validation failed - (root): Invalid input
# and for a PreToolUse hook that rejection is treated as a block. This is the
# mechanism that prevented subagent (Task) launches.
#
# This test drives each affected hook into a forced internal failure (HOME
# pointing at a path where ~/.ralph cannot be created) and asserts stdout parses
# as AT MOST ONE JSON object. It also enforces the structural invariant that no
# hook clears EXIT without also clearing ERR.
#
# Usage: bash tests/hooks/test_single_json_emission.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOKS_DIR="${REPO_ROOT}/.claude/hooks"

PASS=0
FAIL=0

pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

# Count top-level JSON objects on stdin. Prints the count, or -1 if the stream
# contains trailing garbage that is not valid JSON.
count_json_objects() {
    python3 -c '
import sys, json
s = sys.stdin.read().strip()
if not s:
    print(0); raise SystemExit
dec = json.JSONDecoder()
i = 0
n = 0
while i < len(s):
    while i < len(s) and s[i].isspace():
        i += 1
    if i >= len(s):
        break
    try:
        _, i = dec.raw_decode(s, i)
    except ValueError:
        print(-1); raise SystemExit
    n += 1
print(n)
'
}

# ---------------------------------------------------------------------------
# Structural invariant: `trap -` must never clear EXIT while leaving ERR armed.
# ---------------------------------------------------------------------------
test_no_bare_exit_trap_clear() {
    local violations
    violations=$(grep -n 'trap - EXIT' "${HOOKS_DIR}"/*.sh 2>/dev/null | grep -v 'trap - ERR EXIT' || true)

    if [[ -z "$violations" ]]; then
        pass "no hook clears EXIT without also clearing ERR"
    else
        fail "hooks clear EXIT but leave ERR armed" "$violations"
    fi
}

# ---------------------------------------------------------------------------
# Behavioural: a forced internal failure must not produce two JSON objects.
# ---------------------------------------------------------------------------
test_single_emission_on_forced_failure() {
    local hook_name="$1"
    local stdin_payload="$2"
    local hook_path="${HOOKS_DIR}/${hook_name}"

    if [[ ! -f "$hook_path" ]]; then
        pass "${hook_name} (skipped: not present)"
        return
    fi

    # A regular file at $HOME/.ralph makes every `mkdir -p "$HOME/.ralph/..."`
    # fail, which is what trips the ERR trap while the EXIT trap is still armed.
    local fake_home
    fake_home=$(mktemp -d)
    : > "${fake_home}/.ralph"

    local stdout_file="${fake_home}/stdout"
    (
        cd "$fake_home" || exit 1
        printf '%s' "$stdin_payload" | HOME="$fake_home" bash "$hook_path"
    ) >"$stdout_file" 2>/dev/null

    local count
    count=$(count_json_objects <"$stdout_file")

    if [[ "$count" == "-1" ]]; then
        fail "${hook_name}: stdout is not valid JSON" "$(head -c 300 "$stdout_file")"
    elif [[ "$count" -gt 1 ]]; then
        fail "${hook_name}: emitted ${count} JSON objects on one run" \
             "$(head -c 300 "$stdout_file")"
    else
        pass "${hook_name}: emitted ${count} JSON object(s) under forced failure"
    fi

    rm -rf -- "$fake_home"
}

echo "BUG-3 regression: single JSON emission per hook run"
echo

test_no_bare_exit_trap_clear

TASK_INPUT='{"tool_name":"Task","tool_input":{"subagent_type":"orchestrator","prompt":"implement a distributed authentication microservice"},"session_id":"bug3-test"}'
EDIT_INPUT='{"tool_name":"Edit","tool_input":{"file_path":"/tmp/bug3-test.txt"},"session_id":"bug3-test"}'
PROMPT_INPUT='{"prompt":"implement a distributed cache","session_id":"bug3-test"}'
STOP_INPUT='{"session_id":"bug3-test","reason":"test"}'

test_single_emission_on_forced_failure "orchestrator-auto-learn.sh" "$TASK_INPUT"
test_single_emission_on_forced_failure "action-report-tracker.sh"   "$EDIT_INPUT"
test_single_emission_on_forced_failure "checkpoint-smart-save.sh"   "$EDIT_INPUT"
test_single_emission_on_forced_failure "plan-state-adaptive.sh"     "$PROMPT_INPUT"
test_single_emission_on_forced_failure "plan-state-lifecycle.sh"    "$PROMPT_INPUT"
test_single_emission_on_forced_failure "skill-validator.sh"         "$EDIT_INPUT"
test_single_emission_on_forced_failure "progress-tracker.sh"        "$EDIT_INPUT"

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
