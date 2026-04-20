#!/usr/bin/env bash
# test_anti_rationalization_gate.sh — Local tests for the Stop gate (v2.0.0)
#
# Design constraint (security): the hook MUST be project-isolated.
# - State lives in $CWD/.claude/state/ (not $HOME)
# - Plan detection reads only $CWD/.claude/plan-state.json
# - No global fallback is permitted (cross-project contamination)
#
# These tests therefore use a TEMP PROJECT ROOT as CWD and verify that:
#   1. stop_hook_active short-circuits to approve
#   2. Excuse patterns block
#   3. Active plan + confirmation blocks
#   4. No active plan + confirmation approves
#   5. Plain transcripts approve
#   6. Max blocks threshold resets + approves
#   7. Global ~/.ralph/active-plan is IGNORED even if it contains a plan
#      (project isolation guarantee)

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

echo "=== Test 1: stop_hook_active=true → approve ==="
P=$(new_project)
OUT=$(run_hook "$P" "{\"stop_hook_active\": true, \"cwd\": \"$P\"}")
assert_output "approve on stop_hook_active" '"decision": "approve"' "$OUT"
rm -rf "$P"

echo "=== Test 2: excuse pattern → block ==="
P=$(new_project)
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Sequential is simpler to implement\"}")
assert_output "block on excuse 'Sequential is simpler'" '"decision": "block"' "$OUT"
rm -rf "$P"

echo "=== Test 3: active plan + confirmation → block ==="
P=$(new_project)
fresh_plan "$P"
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Should I continue with step 2?\"}")
assert_output "block on confirmation with active plan" 'Plan-immutability gate' "$OUT"
rm -rf "$P"

echo "=== Test 4: NO active plan + confirmation → approve ==="
P=$(new_project)
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Should I continue?\"}")
assert_output "approve when no active plan exists" '"decision": "approve"' "$OUT"
rm -rf "$P"

echo "=== Test 5: no pattern → approve ==="
P=$(new_project)
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"work complete\"}")
assert_output "approve on benign transcript" '"decision": "approve"' "$OUT"
rm -rf "$P"

echo "=== Test 6: max blocks → approve + reset ==="
P=$(new_project)
echo '{"blocks": 3}' > "$P/.claude/state/anti-rat-blocks.json"
OUT=$(run_hook "$P" "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Sequential is simpler\"}")
assert_output "approve after max blocks" '"decision": "approve"' "$OUT"
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

echo "=== Test 7: project isolation — global ~/.ralph/active-plan is IGNORED ==="
P=$(new_project)
# Simulate a polluted HOME with an active plan that the hook must IGNORE.
ISO_HOME=$(mktemp -d)
mkdir -p "$ISO_HOME/.ralph/active-plan"
cat > "$ISO_HOME/.ralph/active-plan/poison.json" <<EOF
{"last_updated":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","steps":{"0":{"status":"in_progress"}}}
EOF
OUT=$(HOME="$ISO_HOME" printf '%s' "{\"stop_hook_active\": false, \"cwd\": \"$P\", \"transcript\": \"Should I continue?\"}" | HOME="$ISO_HOME" /bin/bash "$HOOK")
assert_output "ignores global ~/.ralph/active-plan (per-repo isolation)" '"decision": "approve"' "$OUT"
rm -rf "$P" "$ISO_HOME"

echo
echo "=========================================="
echo "Passed: $PASS | Failed: $FAIL"
echo "=========================================="
exit $FAIL
