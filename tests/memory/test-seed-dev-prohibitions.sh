#!/usr/bin/env bash
#
# test-seed-dev-prohibitions.sh — fail-loud contract tests for the
# dev-prohibitions seeder (scripts/memory/seed-dev-prohibitions.sh).
#
# Verifies the guard rails a reader cannot trust by eye: misuse and missing
# inputs MUST exit non-zero with a clear FATAL message, and the in-repo seed
# fixture MUST be valid. This test is itself fail-loud: any broken contract
# exits 1.
#
set -euo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 && pwd)"
SEEDER="$REPO_ROOT/scripts/memory/seed-dev-prohibitions.sh"
SEED_JSON="$REPO_ROOT/scripts/memory/seed-data/dev-prohibitions.json"

PASS=0
FAIL=0
pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }

[[ -f "$SEEDER" ]] || { echo "FATAL: seeder not found: $SEEDER" >&2; exit 1; }

# --- Test 1: missing seed file must fail loud ---------------------------------
rc=0
out="$(SEED_FILE=/nonexistent/seed.json bash "$SEEDER" --dry-run 2>&1)" || rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "FATAL: seed file not found" <<<"$out"; then
  pass "missing seed file exits non-zero with FATAL (rc=$rc)"
else
  fail "missing seed file did not fail loud (rc=$rc): $out"
fi

# --- Test 2: unknown argument must fail loud (before any prerequisite check) ---
rc=0
out="$(bash "$SEEDER" --bogus-arg 2>&1)" || rc=$?
if [[ "$rc" -ne 0 ]] && grep -q "FATAL: unknown argument" <<<"$out"; then
  pass "unknown argument exits non-zero with FATAL (rc=$rc)"
else
  fail "unknown argument did not fail loud (rc=$rc): $out"
fi

# --- Test 3: in-repo seed fixture is valid JSON with the 4 expected rules ------
expected="dev-no-placeholders dev-no-production-code-for-tests dev-no-unrequested-fallbacks testing-fail-loud-fail-fast "
if [[ ! -f "$SEED_JSON" ]]; then
  fail "in-repo seed fixture missing: $SEED_JSON"
elif ! command -v jq >/dev/null 2>&1; then
  fail "jq not available — cannot validate seed fixture"
else
  ids="$(jq -r '.[].rule_id' "$SEED_JSON" | sort | tr '\n' ' ')"
  if [[ "$ids" == "$expected" ]]; then
    pass "in-repo seed fixture is valid and has the 4 expected rule ids"
  else
    fail "seed fixture rule-id mismatch: got [$ids] expected [$expected]"
  fi
fi

echo
printf 'Results: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
echo "All seeder contract tests passed"
