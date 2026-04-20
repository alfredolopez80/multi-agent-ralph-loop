#!/usr/bin/env bash
# test_task_list_projection.sh — Invariant tests for task-list-projection.sh
#
# Contract: the hook is the SINGLE writer of $CWD/.claude/tasks.json.
# After each event it must keep total, completed, pct consistent and
# refresh the dual timestamp fields via plan-state-writer.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$ROOT/.claude/hooks/task-list-projection.sh"

PASS=0; FAIL=0

assert() {
    local label="$1" cond="$2"
    if eval "$cond"; then echo "  OK   $label"; PASS=$((PASS + 1))
    else echo "  FAIL $label  (cond: $cond)"; FAIL=$((FAIL + 1)); fi
}

new_repo() {
    local d; d=$(mktemp -d -t tlp-XXXXXX)
    mkdir -p "$d/.claude"
    echo "$d"
}

send() {
    local repo="$1"; shift
    ( cd "$repo" && echo "$1" | "$HOOK" >/dev/null )
}

# ─────────────────────────────────────────────
echo "=== Test 1: TaskCreated appends and recalculates totals ==="
R=$(new_repo)
send "$R" '{"hook_event_name":"TaskCreated","taskId":"a","subject":"first","status":"pending","owner":"claude"}'
send "$R" '{"hook_event_name":"TaskCreated","taskId":"b","subject":"second","status":"pending","owner":"claude"}'
T=$(jq -r '.total' "$R/.claude/tasks.json")
C=$(jq -r '.completed' "$R/.claude/tasks.json")
P=$(jq -r '.pct' "$R/.claude/tasks.json")
assert "total == 2"      "[[ \"$T\" == '2' ]]"
assert "completed == 0"  "[[ \"$C\" == '0' ]]"
assert "pct == 0"        "[[ \"$P\" == '0' ]]"
rm -rf "$R"

# ─────────────────────────────────────────────
echo "=== Test 2: TaskCompleted flips status and recomputes pct ==="
R=$(new_repo)
send "$R" '{"hook_event_name":"TaskCreated","taskId":"a","subject":"one","status":"pending","owner":"claude"}'
send "$R" '{"hook_event_name":"TaskCreated","taskId":"b","subject":"two","status":"pending","owner":"claude"}'
send "$R" '{"hook_event_name":"TaskCompleted","taskId":"a","subject":"one","status":"completed","owner":"claude"}'
STATUS_A=$(jq -r '.tasks[] | select(.id=="a") | .status' "$R/.claude/tasks.json")
COMPLETED_AT=$(jq -r '.tasks[] | select(.id=="a") | .completed_at' "$R/.claude/tasks.json")
PCT=$(jq -r '.pct' "$R/.claude/tasks.json")
LAST=$(jq -r '.last_updated' "$R/.claude/tasks.json")
UPD=$(jq -r '.updated_at' "$R/.claude/tasks.json")
assert "task a -> completed"           "[[ \"$STATUS_A\" == 'completed' ]]"
assert "task a has completed_at"       "[[ \"$COMPLETED_AT\" != 'null' && -n \"$COMPLETED_AT\" ]]"
assert "pct == 50"                     "[[ \"$PCT\" == '50' ]]"
assert "dual-write last_updated set"   "[[ \"$LAST\" != 'null' && -n \"$LAST\" ]]"
assert "dual-write updated_at set"     "[[ \"$UPD\" != 'null' && -n \"$UPD\" ]]"
rm -rf "$R"

# ─────────────────────────────────────────────
echo "=== Test 3: Atomicity — bogus input does not corrupt file ==="
R=$(new_repo)
send "$R" '{"hook_event_name":"TaskCreated","taskId":"a","subject":"first","status":"pending","owner":"claude"}'
ORIG=$(cat "$R/.claude/tasks.json")
# Missing taskId -> hook must skip cleanly
( cd "$R" && echo '{"hook_event_name":"TaskCreated"}' | "$HOOK" >/dev/null )
AFTER=$(cat "$R/.claude/tasks.json")
assert "file unchanged after no-op input" "[[ \"$ORIG\" == \"$AFTER\" ]]"
# No leftover lockdir
LOCK_COUNT=$(find "$R/.claude" -maxdepth 1 -name 'tasks.json.lock' -type d 2>/dev/null | wc -l | tr -d ' ')
assert "no leftover lock directory" "[[ $LOCK_COUNT -eq 0 ]]"
rm -rf "$R"

# ─────────────────────────────────────────────
echo "=== Test 4: Per-project isolation — tasks.json never crosses repos ==="
R1=$(new_repo); R2=$(new_repo)
send "$R1" '{"hook_event_name":"TaskCreated","taskId":"r1-only","subject":"x","status":"pending","owner":"claude"}'
send "$R2" '{"hook_event_name":"TaskCreated","taskId":"r2-only","subject":"y","status":"pending","owner":"claude"}'
IDS_R1=$(jq -r '[.tasks[].id] | sort | join(",")' "$R1/.claude/tasks.json")
IDS_R2=$(jq -r '[.tasks[].id] | sort | join(",")' "$R2/.claude/tasks.json")
assert "R1 sees only r1-only" "[[ \"$IDS_R1\" == 'r1-only' ]]"
assert "R2 sees only r2-only" "[[ \"$IDS_R2\" == 'r2-only' ]]"
rm -rf "$R1" "$R2"

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
