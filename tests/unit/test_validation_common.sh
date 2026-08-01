#!/usr/bin/env bash
# Unit test for scripts/lib/validation-common.sh.
# Proves the shared verdict behaves — most importantly that its zero-checks guard fails
# a run that counted nothing, the property the whole library exists to guarantee.
#
# This runner obeys its own rule: it declares success only when RAN > 0 AND FAILS == 0,
# and increments with VAR=$((VAR+1)) so `set -e` can never abort it mid-way.
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIB="$REPO_ROOT/scripts/lib/validation-common.sh"

RAN=0
FAILS=0

# Run "vc_init; <ops>; vc_verdict T" in a clean subshell and check exit code + a substring.
# `ops` is a snippet of shell so several calls can be sequenced; each case is isolated so a
# counter set by one cannot leak into the next.
check() {  # check <expected_rc> <expected_substr_in_output> <ops-snippet>
  local want_rc="$1" want_sub="$2" ops="$3"
  RAN=$((RAN + 1))
  local out rc
  out="$(NO_COLOR=1 bash -c 'source "$1"; vc_init; eval "$2"; vc_verdict "T"' _ "$LIB" "$ops" 2>&1)"
  rc=$?
  if [[ "$rc" -ne "$want_rc" ]]; then
    echo "  FAIL: [$ops] exit $rc, expected $want_rc"; FAILS=$((FAILS + 1)); return
  fi
  if [[ -n "$want_sub" && "$out" != *"$want_sub"* ]]; then
    echo "  FAIL: [$ops] output missing '$want_sub': $out"; FAILS=$((FAILS + 1)); return
  fi
  echo "  OK  : [$ops] -> exit $rc"
}

[[ -f "$LIB" ]] || { echo "FATAL: $LIB missing"; exit 1; }

echo "=== zero-checks guard (the property that matters) ==="
check 1 "zero checks executed" ":"               # nothing counted -> FATAL, non-zero
check 1 "zero checks"          "true"            # a command that isn't a vc_* call still counts nothing

echo "=== normal verdicts ==="
check 0 "all checks passed"     "vc_pass"
check 1 "1 check(s) failed"     "vc_fail"
check 0 "passed with 1 warning" "vc_warn"
check 0 "Passed:   2"           "vc_pass; vc_pass"   # counting-only form still tallies
check 1 ""                      "vc_pass; vc_fail"   # any failure -> non-zero

echo "=== counting-only form does not abort under a caller-style flow ==="
# vc_pass with no args must return 0 so `set -e` callers survive.
if NO_COLOR=1 bash -c 'set -e; source "$1"; vc_init; vc_pass; vc_pass; vc_verdict T' _ "$LIB" >/dev/null 2>&1; then
  RAN=$((RAN + 1)); echo "  OK  : set -e caller survives counting-only vc_pass"
else
  RAN=$((RAN + 1)); FAILS=$((FAILS + 1)); echo "  FAIL: set -e caller aborted on counting-only vc_pass"
fi

echo
if [[ "$RAN" -eq 0 ]]; then
  echo "FATAL: zero cases executed — cannot declare success" >&2; exit 1
fi
if [[ "$FAILS" -eq 0 ]]; then
  echo "ALL OK ($RAN cases)"; exit 0
else
  echo "$FAILS FAILURES of $RAN"; exit 1
fi
