> Full text of the global rule ~/.claude/rules/proven/testing-zero-tests-is-never-success.md, preserved 2026-09-03 when the always-loaded copy was reduced to norm + trigger. The rule file links here.

# zero-tests-is-never-success

ABSOLUTE PRINCIPLE: A test run that executed ZERO tests MUST NEVER report success — not a unit test suite, not an e2e gate, not a CI step, in ANY project. "Nothing failed" is not "everything passed."

## The Rule

A test harness MUST assert on **two** independent conditions before declaring success:

1. `failed == 0` — nothing that ran, failed.
2. `total > 0` — something actually ran.

Checking only condition 1 is a fail-open: when fixture setup dies, a filter matches nothing, a file glob resolves empty, or a precondition aborts collection, the harness reports green over an empty result set. The signal that everything is broken is indistinguishable from the signal that everything is fine.

Stronger still, where the expected count is knowable: assert `total >= expected_minimum`. A suite that normally runs 5 tests and now runs 1 has silently lost 80% of its coverage while still printing "All tests passed."

## Canonical Failure (observed 2026-07-31, evenfire `scripts/e2e/e2e-lib.sh:841`)

```bash
print_results() {
  echo "Total: ${e2e_total}  |  Pass: ${e2e_pass}  |  Fail: ${e2e_fail}"
  if [ "$e2e_fail" -eq 0 ]; then
    echo "All tests passed!"
    return 0          # <-- returns 0 with e2e_total == 0
  else
    return 1
  fi
}
```

Real output from a gate whose fixture Host failed to materialize:

```
Total: 0  |  Pass: 0  |  Fail: 0

All tests passed!
```

The gate executed zero tests and declared success, returning exit 0. It only surfaced as red because an unrelated `NotFound` killed the script earlier under `set -e` — **not because of its own verdict**. Had the fixture failed more gracefully, the gate would have reported green.

Blast radius in that repo: **28 e2e gates** shared that single `print_results` function. One fail-open helper silently underwrote every gate in the suite.

## The Correct Form

```bash
print_results() {
  echo "Total: ${e2e_total}  |  Pass: ${e2e_pass}  |  Fail: ${e2e_fail}"
  if [ "${e2e_total}" -eq 0 ]; then
    echo "FAIL: zero tests executed — the harness never reached a real assertion" >&2
    return 1
  fi
  [ "$e2e_fail" -eq 0 ] || return 1
  echo "All tests passed!"
  return 0
}
```

## Silent Cause: `set -e` + `((COUNTER++))` (observed 2026-07-31, `scripts/validate-skills-unification.sh`)

A harness can reach zero counters without any test failing — because the script died before running them. In bash, a post-increment on a counter holding **0** evaluates to 0, which is exit status 1. Under `set -e` that aborts the script on the very first counter update:

```bash
set -e
PASS=0
((PASS++))          # evaluates to 0 -> exit status 1 -> script dies here, silently
PASS=$((PASS+1))    # correct: assignment always returns 0
```

The validator printed one check and vanished. There was no error message, no failure count, and no indication that the remaining 14 checks never ran. Any `validate-*.sh` combining `set -e` with `((VAR++))` is one zero-valued counter away from this.

**Rule**: in a `set -e` script, always write `VAR=$((VAR+1))`, never `((VAR++))`.

## Where This Bites (check all of these)

- Shell e2e harnesses with a `total`/`pass`/`fail` counter trio
- `pytest` with a filter/marker that matches nothing (use `--strict-markers`; treat exit code 5 "no tests collected" as FAILURE, never as success)
- `vitest` / `jest` with an `include` glob that resolves empty (`--passWithNoTests` is the fail-open flag — do NOT set it in CI)
- `go test ./...` over a package set with no test files
- CI matrix legs that skip their whole body on a condition and still report green
- Any `for f in $(find ...)` loop whose find returns nothing

## Relationship to Other Rules

This is the counting-side companion to `testing-fail-loud-fail-fast`. That rule forbids masking a failure that happened; this one forbids manufacturing a pass when nothing happened. Both exist because a test's only job is to surface failure, and both failure modes end with a green checkmark over a broken system.

## Detection Duty (applies even outside the current scope)

If you detect a harness that can report success with zero tests in ANY file — whether or not it is the target of the current analysis, PR, or task — you MUST:

1. Run `git blame` on the offending line(s) to identify when and by whom it was introduced.
2. Measure and report the blast radius (how many suites/gates consume that helper).
3. Report the finding to the user (file, line, blame author/commit, and what an empty run would look like).
4. Do NOT silently keep it.

**Trigger**: Authoring or reviewing any test harness, result reporter, CI test step, or e2e gate; any run whose reported test count is 0 or unexpectedly low
**Domain**: testing
**Confidence**: 1.0
**Usage**: 1 (first documented occurrence: 2026-07-31, evenfire PR #205 T2 minikube gate)
