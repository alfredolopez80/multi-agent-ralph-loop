#!/usr/bin/env bash
# test_plan_state_writer.sh — Invariant tests for lib/plan-state-writer.sh
#
# The freshness invariant: after ANY successful plan_state_update call, both
# `.last_updated` AND `.updated_at` MUST equal "now" (within 5s tolerance).
# This is the guarantee that prevents the anti-rationalization-gate from
# falsely treating an active plan as stale.

set -euo pipefail

LIB="$(cd "$(dirname "$0")/../.." && pwd)/.claude/hooks/lib/plan-state-writer.sh"

if [[ ! -f "$LIB" ]]; then
    echo "FAIL: lib not found: $LIB"
    exit 1
fi

# shellcheck disable=SC1090
source "$LIB"

PASS=0
FAIL=0

assert() {
    local label="$1"
    local cond="$2"
    if eval "$cond"; then
        echo "  OK   $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL $label  (cond: $cond)"
        FAIL=$((FAIL + 1))
    fi
}

parse_iso() {
    # BSD/Linux-portable ISO-UTC → epoch
    TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" "+%s" 2>/dev/null \
        || date -d "$1" "+%s" 2>/dev/null \
        || echo 0
}

new_plan() {
    local f
    f=$(mktemp -t plan-test.XXXXXX)
    cat > "$f" <<'EOF'
{"version":"1.0","last_updated":"2020-01-01T00:00:00Z","updated_at":"2020-01-01T00:00:00Z","steps":[{"id":"s1","status":"pending"},{"id":"s2","status":"pending"}]}
EOF
    echo "$f"
}

echo "=== Test 1: update refreshes both timestamp fields ==="
P=$(new_plan)
NOW=$(date -u +%s)
plan_state_update "$P" '.steps |= map(if .id == $s then .status = "completed" else . end)' --arg s "s1"
LAST=$(jq -r '.last_updated' "$P")
UPD=$(jq -r '.updated_at' "$P")
LAST_E=$(parse_iso "$LAST")
UPD_E=$(parse_iso "$UPD")
assert "last_updated within 5s of now" "[[ \$((NOW - LAST_E)) -ge -1 && \$((NOW - LAST_E)) -le 5 ]]"
assert "updated_at within 5s of now"   "[[ \$((NOW - UPD_E))  -ge -1 && \$((NOW - UPD_E))  -le 5 ]]"
assert "user mutation applied"          "[[ \"\$(jq -r '.steps[0].status' \"$P\")\" == 'completed' ]]"
rm -f "$P"

echo "=== Test 2: touch refreshes without mutating ==="
P=$(new_plan)
NOW=$(date -u +%s)
plan_state_touch "$P"
LAST_E=$(parse_iso "$(jq -r '.last_updated' "$P")")
STATUS=$(jq -r '.steps[0].status' "$P")
assert "touch refreshes last_updated"  "[[ \$((NOW - LAST_E)) -le 5 ]]"
assert "touch does not mutate steps"   "[[ \"$STATUS\" == 'pending' ]]"
rm -f "$P"

echo "=== Test 3: atomicity — failed jq leaves file intact ==="
P=$(new_plan)
ORIG=$(cat "$P")
if plan_state_update "$P" 'this_is_invalid_jq_syntax(((' 2>/dev/null; then
    echo "  FAIL bad filter should have failed"
    FAIL=$((FAIL + 1))
else
    assert "file unchanged after failed update" "[[ \"\$(cat \"$P\")\" == \"\$ORIG\" ]]"
fi
# No leftover sibling temps (mktemp emits "${P}.XXXXXX")
TEMPS=$(find "$(dirname "$P")" -maxdepth 1 -name "$(basename "$P").*" 2>/dev/null | wc -l | tr -d ' ')
assert "no leftover temp files" "[[ $TEMPS -eq 0 ]]"
rm -f "$P"

echo "=== Test 4: missing file is an error ==="
GHOST="/tmp/does-not-exist-$$.json"
if plan_state_update "$GHOST" '.' 2>/dev/null; then
    echo "  FAIL missing file should have returned 1"
    FAIL=$((FAIL + 1))
else
    echo "  OK   missing file returns error"
    PASS=$((PASS + 1))
fi

echo "=== Test 5: freshness field overwrite ==="
# User filter tries to set last_updated to a fake past value; lib must overwrite
P=$(new_plan)
NOW=$(date -u +%s)
plan_state_update "$P" '.last_updated = "1999-01-01T00:00:00Z" | .updated_at = "1999-01-01T00:00:00Z"'
LAST_E=$(parse_iso "$(jq -r '.last_updated' "$P")")
UPD_E=$(parse_iso "$(jq -r '.updated_at' "$P")")
assert "lib overrides user last_updated" "[[ \$((NOW - LAST_E)) -le 5 ]]"
assert "lib overrides user updated_at"   "[[ \$((NOW - UPD_E))  -le 5 ]]"
rm -f "$P"

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
