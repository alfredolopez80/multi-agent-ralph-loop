#!/usr/bin/env bash
# test_session_dedup_key.sh - Regression test for BUG-6.
#
# BUG-6: hooks derived their per-session dedup key from
#     get_session_id() { echo "${CLAUDE_SESSION_ID:-$$}"; }
# CLAUDE_SESSION_ID is not exported to hooks, so the fallback `$$` always
# applied — and that is a new PID on every invocation. The "already triggered
# once this session" marker was written under a key that could never be read
# back, so deduplication never worked at all.
#
# The key must now come from the hook's stdin payload (.session_id) and fall back
# to a stable cwd+date digest, never to $$.
#
# Usage: bash tests/hooks/test_session_dedup_key.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1
HOOKS_DIR=".claude/hooks"

# Hooks that key a marker file on the session id.
# smart-skill-reminder.sh was removed from this list in T52: the hook is
# retired (deregistered, body reduced to a no-op) because no PreToolUse
# channel reaches the model — additionalContext delivered 0/1343 and
# allow+permissionDecisionReason has no delivery path at all. It no longer
# keys anything on a session id, so asserting that it does was testing a
# mechanism that had been deliberately removed. See
# tests/archive/smart-skill-reminder/README.md.
DEDUP_HOOKS=(
    "adversarial-auto-trigger.sh"
    "ai-code-audit.sh"
    "code-review-auto.sh"
)

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

# Evaluate a hook's get_session_id() in isolation. The hook cannot simply be
# sourced: its body runs main() and exits. So the function definition is
# extracted (from `get_session_id() {` to the first `}` at column 0) and eval'd
# against a chosen $INPUT and cwd.
extract_get_session_id() {
    awk '/^get_session_id\(\) \{/{f=1} f{print} f&&/^\}/{exit}' \
        "${REPO_ROOT}/${HOOKS_DIR}/$1"
}

session_id_of() {
    local hook="$1" payload="$2" cwd="$3" fn
    fn=$(extract_get_session_id "$hook")
    [[ -n "$fn" ]] || return 0
    (
        cd "$cwd" || exit 1
        INPUT="$payload"
        eval "$fn"
        get_session_id
    ) 2>/dev/null
}

# ---------------------------------------------------------------------------
# 1. No live hook may fall back to $$.
# ---------------------------------------------------------------------------
test_no_pid_fallback() {
    local violations
    violations=$(grep -rn 'CLAUDE_SESSION_ID:-\$\$' "$HOOKS_DIR" 2>/dev/null \
        | grep -v '^\s*#' | grep -vE '^[^:]+:[0-9]+:\s*#' || true)

    if [[ -z "$violations" ]]; then
        pass "no hook derives a session key from \$\$"
    else
        fail "hooks still fall back to \$\$ for the session key" "$violations"
    fi
}

# ---------------------------------------------------------------------------
# 2. The key must be stable across invocations with the same stdin payload.
# ---------------------------------------------------------------------------
test_key_is_stable_across_invocations() {
    local hook="$1"
    [[ -f "${HOOKS_DIR}/${hook}" ]] || { pass "${hook} (skipped: not present)"; return; }

    local payload='{"tool_name":"Task","session_id":"stable-session-abc","tool_input":{}}'
    local a b
    a=$(session_id_of "$hook" "$payload" "$REPO_ROOT")
    b=$(session_id_of "$hook" "$payload" "$REPO_ROOT")

    if [[ -z "$a" ]]; then
        fail "${hook}: get_session_id produced nothing" "payload=$payload"
    elif [[ "$a" != "$b" ]]; then
        fail "${hook}: key changes between invocations (dedup impossible)" "run1=$a run2=$b"
    elif [[ "$a" != *"stable-session-abc"* ]]; then
        fail "${hook}: key ignores .session_id from stdin" "got=$a"
    else
        pass "${hook}: key is stable and derived from .session_id ($a)"
    fi
}

# ---------------------------------------------------------------------------
# 3. With no .session_id, the fallback must still be stable (not a PID).
# ---------------------------------------------------------------------------
test_fallback_is_stable() {
    local hook="$1"
    [[ -f "${HOOKS_DIR}/${hook}" ]] || { pass "${hook} fallback (skipped)"; return; }

    local payload='{"tool_name":"Task","tool_input":{}}'
    local a b
    a=$(session_id_of "$hook" "$payload" "$REPO_ROOT")
    b=$(session_id_of "$hook" "$payload" "$REPO_ROOT")

    if [[ -z "$a" ]]; then
        fail "${hook}: fallback produced nothing" "payload=$payload"
    elif [[ "$a" != "$b" ]]; then
        fail "${hook}: fallback key is not stable" "run1=$a run2=$b"
    elif [[ "$a" =~ ^[0-9]+$ ]]; then
        fail "${hook}: fallback still looks like a PID" "got=$a"
    else
        pass "${hook}: fallback key is stable and not a PID ($a)"
    fi
}

# ---------------------------------------------------------------------------
# 4. The key must be filename-safe (it is interpolated into a marker path).
# ---------------------------------------------------------------------------
test_key_is_filename_safe() {
    local hook="$1"
    [[ -f "${HOOKS_DIR}/${hook}" ]] || { pass "${hook} sanitisation (skipped)"; return; }

    local payload='{"tool_name":"Task","session_id":"../../etc/passwd","tool_input":{}}'
    local key
    key=$(session_id_of "$hook" "$payload" "$REPO_ROOT")

    if [[ "$key" == *"/"* || "$key" == *".."* ]]; then
        fail "${hook}: session key allows path traversal into the marker path" "got=$key"
    else
        pass "${hook}: session key is filename-safe ($key)"
    fi
}

echo "BUG-6 regression: session dedup key must be stable and stdin-derived"
echo

test_no_pid_fallback
for hook in "${DEDUP_HOOKS[@]}"; do
    test_key_is_stable_across_invocations "$hook"
done
for hook in "${DEDUP_HOOKS[@]}"; do
    test_fallback_is_stable "$hook"
done
for hook in "${DEDUP_HOOKS[@]}"; do
    test_key_is_filename_safe "$hook"
done

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
