#!/usr/bin/env bash
# test-pr10-claude-md-scope-absence.sh — gate wrapper for the PR10 C4 suite.
#
# The merge gate (tests/run-all-unit-tests.sh) is bash-only; the scope
# assertions live in tests/test_pr10_claude_md_scope_absence.py. This wrapper
# runs pytest on that file and re-emits the runner's expected summary.
# Fail-loud: a pytest exit != 0, a zero-test collection, or a missing file all
# FAIL here — never a silent pass.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/test_pr10_claude_md_scope_absence.py"

if [[ ! -f "$TARGET" ]]; then
    echo "FAIL: absence suite not found: $TARGET" >&2
    echo "Results: 0 passed, 1 failed"
    exit 1
fi

OUT="$(python3 -m pytest "$TARGET" -q 2>&1)"
RC=$?

echo "$OUT" | tail -3

if [[ $RC -ne 0 ]]; then
    echo "Results: 0 passed, 1 failed (pytest exit ${RC})"
    exit 1
fi

# pytest's summary line is like "9 passed in 0.11s" — extract the count and
# apply the zero-tests rule: a collection that found nothing is a failure.
PASSED="$(echo "$OUT" | grep -oE '[0-9]+ passed' | grep -oE '[0-9]+' | head -1)"
if [[ -z "$PASSED" || "$PASSED" -eq 0 ]]; then
    echo "FAIL: pytest collected 0 tests — nothing was asserted" >&2
    echo "Results: 0 passed, 1 failed"
    exit 1
fi

echo "Results: ${PASSED} passed, 0 failed"
exit 0
