#!/usr/bin/env bash
# test_no_hook_hangs_or_blocks.sh - End-to-end guard against the failure mode that
# started this branch: a hook that hangs, or that blocks a Task (subagent) launch
# by emitting output the runtime cannot parse.
#
# Three invariants, checked against every hook in .claude/hooks/ driven with a
# benign PreToolUse payload for the Task tool:
#
#   1. TERMINATES  - the hook exits within HOOK_TIMEOUT seconds. A hook that
#                    blocks on stdin, on a lock, or on a network call stalls the
#                    whole tool call.
#   2. PARSES      - stdout is either empty or exactly ONE JSON object. Two
#                    concatenated objects make the runtime report
#                    "Hook JSON output validation failed - (root): Invalid input",
#                    which for a PreToolUse hook is treated as a deny.
#   3. ALLOWS      - no hook denies a benign Task launch, whether via
#                    permissionDecision "deny"/"ask", {"continue": false},
#                    {"decision": "block"}, or exit code 2.
#
# Hooks run with an isolated HOME so the real ~/.ralph and ~/.claude are not
# touched, which also exercises the cold-start path where state files are absent.
#
# Usage: bash tests/hooks/test_no_hook_hangs_or_blocks.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

HOOK_TIMEOUT="${HOOK_TIMEOUT:-10}"
# Overridable so the probe can be pointed at another checkout of the hooks, e.g.
# to confirm it reports the pre-fix tree as broken.
HOOKS_DIR="${HOOKS_DIR:-.claude/hooks}"
PASS=0
FAIL=0
SLOWEST_TIME=0
SLOWEST_HOOK="none"

pass() { PASS=$((PASS + 1)); }
fail() {
    printf '  FAIL  %s\n' "$1"
    printf '        %s\n' "$2"
    FAIL=$((FAIL + 1))
}

# A benign subagent launch: the exact shape that was being blocked.
TASK_PAYLOAD='{"session_id":"hang-probe-session","hook_event_name":"PreToolUse","cwd":"'"$REPO_ROOT"'","tool_name":"Task","tool_input":{"subagent_type":"ralph-coder","description":"probe","prompt":"probe"}}'

ISO_HOME="$(mktemp -d)"
mkdir -p "$ISO_HOME/.ralph" "$ISO_HOME/.claude"
trap 'rm -rf "$ISO_HOME"' EXIT

# Verdict helper: does this stdout / exit code deny the tool call?
denies() {
    python3 - "$1" "$2" <<'PY'
import json, sys
out, rc = sys.argv[1], sys.argv[2]
reasons = []
if rc == "2":
    reasons.append("exit code 2")
text = out.strip()
if text:
    try:
        obj = json.loads(text)
    except ValueError:
        obj = None
    if isinstance(obj, dict):
        hso = obj.get("hookSpecificOutput") or {}
        pd = hso.get("permissionDecision")
        if pd in ("deny", "ask"):
            reasons.append(f'permissionDecision "{pd}"')
        if obj.get("continue") is False:
            reasons.append('"continue": false')
        if obj.get("decision") == "block":
            reasons.append('"decision": "block"')
print("; ".join(reasons))
PY
}

# Counts JSON objects on stdout: 0 (silent), 1 (valid), or >1 / unparseable.
json_object_count() {
    python3 - "$1" <<'PY'
import json, sys
text = sys.argv[1].strip()
if not text:
    print(0)
    raise SystemExit
dec = json.JSONDecoder()
i, n = 0, 0
while i < len(text):
    while i < len(text) and text[i] in " \t\r\n":
        i += 1
    if i >= len(text):
        break
    try:
        _, end = dec.raw_decode(text, i)
    except ValueError:
        print(-1)
        raise SystemExit
    n += 1
    i = end
print(n)
PY
}

# Probe one hook with one stdin payload against all three invariants.
# $3 selects whether invariant 3 (must allow) applies: a hook is entitled to
# withhold permission when it cannot understand its input, but it is never
# entitled to hang or to emit garbage.
probe_hook() {
    local hook="$1" payload="$2" require_allow="$3" label="$4"
    local name started out rc elapsed count verdict
    name="$(basename "$hook")"

    # Hooks are not all shell scripts: settings.json also registers .mjs and .py
    # handlers, and those were escaping this probe entirely.
    local -a runner
    case "$hook" in
        *.mjs|*.js) runner=(node "$hook") ;;
        *.py)       runner=(python3 "$hook") ;;
        *)          runner=(/bin/bash "$hook") ;;
    esac

    started=$(date +%s)
    out=$(printf '%s' "$payload" \
        | HOME="$ISO_HOME" timeout "$HOOK_TIMEOUT" "${runner[@]}" 2>/dev/null)
    rc=$?
    elapsed=$(( $(date +%s) - started ))

    if [[ "$elapsed" -gt "$SLOWEST_TIME" ]]; then
        SLOWEST_TIME="$elapsed"
        SLOWEST_HOOK="$name"
    fi

    # 1. TERMINATES — timeout(1) reports 124 when it had to kill the process.
    if [[ "$rc" -eq 124 ]]; then
        fail "$name did not terminate [$label]" "still running after ${HOOK_TIMEOUT}s; this stalls the tool call"
        return
    fi
    pass

    # 2. PARSES
    count=$(json_object_count "$out")
    case "$count" in
        0|1) pass ;;
        -1)  fail "$name emitted unparseable stdout [$label]" "$(printf '%s' "$out" | head -c 300)" ;;
        *)   fail "$name emitted $count JSON objects [$label]" "runtime rejects concatenated objects: $(printf '%s' "$out" | head -c 300)" ;;
    esac

    # 3. ALLOWS
    if [[ "$require_allow" == "yes" ]]; then
        verdict=$(denies "$out" "$rc")
        if [[ -n "$verdict" ]]; then
            fail "$name blocks a benign Task launch [$label]" "$verdict"
        else
            pass
        fi
    fi
}

echo "Hook hang/block probe — ${HOOK_TIMEOUT}s budget per hook, isolated HOME"
echo

# Phase 1: the happy path that was being blocked.
for hook in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/*.mjs "$HOOKS_DIR"/*.py; do
    [[ -f "$hook" ]] || continue
    probe_hook "$hook" "$TASK_PAYLOAD" "yes" "benign Task"
done

# Phase 2: degenerate stdin. This drives the ERR/EXIT trap paths, where a
# malformed JSON literal or a trap armed on both ERR and EXIT produces invalid or
# duplicated output — the mechanism that made the runtime treat a PreToolUse hook
# as a deny. Hooks may refuse here, but must still terminate and emit valid JSON.
for hook in "$HOOKS_DIR"/*.sh "$HOOKS_DIR"/*.mjs "$HOOKS_DIR"/*.py; do
    [[ -f "$hook" ]] || continue
    probe_hook "$hook" '' "no" "empty stdin"
    probe_hook "$hook" 'not json at all' "no" "garbage stdin"
    probe_hook "$hook" '{"tool_name":"Task","tool_input":null,"cwd":"/nonexistent/path"}' "no" "unusable cwd"
done

echo
printf 'slowest hook: %s (%ss)\n' "$SLOWEST_HOOK" "$SLOWEST_TIME"
printf 'checks passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
