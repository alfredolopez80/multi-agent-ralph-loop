#!/usr/bin/env bash
# test_anti_rationalization_gate.sh — Local tests for the Stop gate (v2.0.0)
#
# Design constraint (security): the hook MUST be project-isolated.
# - State lives in $CWD/.claude/state/ (not $HOME)
# - Plan detection reads only $CWD/.claude/plan-state.json
# - No global fallback is permitted (cross-project contamination)
#
# These tests therefore use a TEMP PROJECT ROOT as CWD and verify that:
#   1. stop_hook_active short-circuits to allow
#   2. Excuse patterns block
#   3. Active plan + confirmation blocks
#   4. No active plan + confirmation allows
#   5. Plain transcripts allow
#   6. Max blocks threshold resets + allows
#   7. Global ~/.ralph/active-plan is IGNORED even if it contains a plan
#      (project isolation guarantee)
#
# Allow contract: per tests/HOOK_FORMAT_REFERENCE.md a Stop hook allows with a
# clean `exit 0` and NO stdout. `{"decision": "approve"}` is not a valid Claude
# Code value, so the allow paths are asserted with assert_allow(), not by
# grepping for an "approve" payload the hook must never emit.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/.claude/hooks/anti-rationalization-gate.sh"

if [[ ! -x "$HOOK" ]]; then
  echo "FAIL: hook not found or not executable: $HOOK"
  exit 1
fi

PASS=0
FAIL=0

assert_output() {
  local label="$1"
  local expected_substr="$2"
  local actual="$3"
  if [[ "$actual" == *"$expected_substr"* ]]; then
    echo "  OK   $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $label"
    echo "       expected substring: $expected_substr"
    echo "       actual: $actual"
    FAIL=$((FAIL + 1))
  fi
}

# Asserts the Stop allow contract: silent stdout and exit 0. Emitting anything
# on an allow path (notably {"decision": "approve"}) fails runtime validation.
assert_allow() {
  local label="$1"
  local actual="$2"
  local rc="$3"
  if [[ -z "${actual//[[:space:]]/}" && "$rc" -eq 0 ]]; then
    echo "  OK   $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $label"
    echo "       expected: no stdout and exit 0 (Stop allow contract)"
    echo "       actual: rc=$rc stdout=$actual"
    FAIL=$((FAIL + 1))
  fi
}

# Each test gets its own isolated project root
new_project() {
  local dir
  dir=$(mktemp -d)
  mkdir -p "$dir/.claude/state"
  echo "$dir"
}

fresh_plan() {
  # Writes an active plan-state.json with last_updated=now and in_progress step
  local project="$1"
  local now_iso
  now_iso=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "$project/.claude/plan-state.json" <<EOF
{"version":"1.0","last_updated":"$now_iso","steps":[{"id":"s1","name":"test step","status":"in_progress"}]}
EOF
}

run_hook() {
  local project="$1"
  local json_stdin="$2"
  # Execute the hook with an isolated HOME to guarantee that any accidental
  # global lookups (which must not exist in v2.0.0) would land on an empty HOME.
  local iso_home
  iso_home=$(mktemp -d)
  HOME="$iso_home" printf '%s' "$json_stdin" | HOME="$iso_home" /bin/bash "$HOOK"
  local rc=$?
  rm -rf "$iso_home"
  return $rc
}

echo "=== Test 1: stop_hook_active=true → allow ==="
P=$(new_project)
RC=0
OUT=$(run_hook "$P" "{\"stop_hook_active\": true, \"cwd\": \"$P\"}") || RC=$?
assert_allow "allow on stop_hook_active" "$OUT" "$RC"
rm -rf "$P"

echo "=== Test 2: excuse pattern → block ==="
P=$(new_project)
echo "=== Test 2: excuse pattern → block ==="
# The gate greps the RAW stdin for the DOC-QUOTED excuse ("excuse" with its
# table quotes), so the transcript is passed as free text carrying the quoted
# excuse literally — a JSON-escaped closing quote would never match (the same
# reason json.dumps payloads do not match). The gate does not parse this
# input; it only greps it.
OUT=$(run_hook "$P" '{"stop_hook_active": false, "cwd": "'"$P"'", "transcript_text": user said "I'"'"'ll fix it in the next iteration", stopping here.}')
assert_output "block on excuse 'I'll fix it in the next iteration'" '"decision": "block"' "$OUT"
rm -rf "$P"

echo "=== Test 3: active plan + confirmation → block ==="
P=$(new_project)
fresh_plan "$P"
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Should I continue with step 2?\"}")
assert_output "block on confirmation with active plan" 'Plan-immutability gate' "$OUT"
rm -rf "$P"

echo "=== Test 4: NO active plan + confirmation → allow ==="
P=$(new_project)
RC=0
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Should I continue?\"}") || RC=$?
assert_allow "allow when no active plan exists" "$OUT" "$RC"
rm -rf "$P"

echo "=== Test 5: no pattern → allow ==="
P=$(new_project)
RC=0
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"work complete\"}") || RC=$?
assert_allow "allow on benign transcript" "$OUT" "$RC"
rm -rf "$P"

echo "=== Test 6: max blocks → allow + reset ==="
P=$(new_project)
echo '{"blocks": 3}' > "$P/.claude/state/anti-rat-blocks.json"
RC=0
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Sequential is simpler\"}") || RC=$?
assert_allow "allow after max blocks" "$OUT" "$RC"
COUNTER=$(cat "$P/.claude/state/anti-rat-blocks.json")
assert_output "counter resets to 0" '"blocks": 0' "$COUNTER"
rm -rf "$P"

echo "=== Test 8: plan-state with last_updated=null but fresh mtime → block confirmation ==="
P=$(new_project)
cat > "$P/.claude/plan-state.json" <<'EOF'
{"version":"1.0","last_updated":null,"steps":[{"id":"s1","name":"step","status":"in_progress"}]}
EOF
# mtime is "now" by construction — the defensive fallback must catch it
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Should I continue?\"}")
assert_output "fallback to mtime when last_updated is null" 'Plan-immutability gate' "$OUT"
rm -rf "$P"

echo "=== Test 9: cwd=subdirectory — root-resolved plan detection (T87 delta) ==="
# The behavioural delta of the T87 fix, measured by this scenario:
#   pre-fix  → the gate reads $cwd/.claude/plan-state.json; from a moved cwd
#              the active plan at the root is invisible → Modo B silently OFF
#              → confirmation escape is ALLOWED (this assertion failed RED).
#   post-fix → the gate resolves the working-tree root CONTAINING cwd, sees
#              the active plan → Modo B turns ON → BLOCK.
P=$(new_project)
git -C "$P" init -q >/dev/null 2>&1
git -C "$P" config user.email t87@test
git -C "$P" config user.name t87
mkdir -p "$P/src"
fresh_plan "$P"
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P/src\", \"transcript\": \"Should I continue?\"}")
assert_output "Modo B fires from moved cwd (plan seen at root)" 'Plan-immutability gate' "$OUT"
rm -rf "$P"

echo "=== Test 10: escape hatch — MAX_BLOCKS also caps Modo B from moved cwd ==="
# The gate has NO env-var bypass by design (an agent must not be able to
# switch off its own anti-rationalization gate with RALPH_SKIP=1). The two
# legitimate escapes are structural: stop_hook_active (Test 1) and this
# MAX_BLOCKS=3 auto-reset. This scenario proves the cap covers Modo B — the
# mode the T87 root-resolution fix newly activates from a moved cwd.
P=$(new_project)
git -C "$P" init -q >/dev/null 2>&1
git -C "$P" config user.email t87@test
git -C "$P" config user.name t87
mkdir -p "$P/src"
fresh_plan "$P"
echo '{"blocks": 3}' > "$P/.claude/state/anti-rat-blocks.json"
RC=0
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P/src\", \"transcript\": \"Should I continue?\"}") || RC=$?
assert_allow "allow after MAX_BLOCKS even with active plan from moved cwd" "$OUT" "$RC"
COUNTER=$(cat "$P/.claude/state/anti-rat-blocks.json")
assert_output "counter auto-resets to 0" '"blocks": 0' "$COUNTER"
rm -rf "$P"

echo "=== Test 7: project isolation — global ~/.ralph/active-plan is IGNORED ==="
P=$(new_project)
# Simulate a polluted HOME with an active plan that the hook must IGNORE.
ISO_HOME=$(mktemp -d)
mkdir -p "$ISO_HOME/.ralph/active-plan"
cat > "$ISO_HOME/.ralph/active-plan/poison.json" <<EOF
{"last_updated":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","steps":{"0":{"status":"in_progress"}}}
EOF
RC=0
OUT=$(HOME="$ISO_HOME" printf '%s' "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Should I continue?\"}" | HOME="$ISO_HOME" /bin/bash "$HOOK") || RC=$?
assert_allow "ignores global ~/.ralph/active-plan (per-repo isolation)" "$OUT" "$RC"
rm -rf "$P" "$ISO_HOME"

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
