#!/usr/bin/env bash
# test-slice-c-absence.sh — PR7-EXEC (Slice C of #69 Phase 3, plan by mmx-3).
#
# Absence + survivor assertions for the quality-enforcement consolidation:
#   Grupo 1: the 7 removed hook FILES do not exist
#   Grupo 2: settings.json.example registers none of them
#   Grupo 3: their dedicated test dirs are gone or empty
#   Grupo 4: survivor hooks exist (files); survivors are NOT example-registered
#            (their registrations are ACTIVE-side, by design)
#   Grupo 5: worker-blocked-safe hooks are untouched (files exist)
#   Grupo 6: SECURITY_BASELINE.json manifest intact (6 controls + the 5 gap ids)
#   Grupo 7: positive control — the runner still lists this suite and the
#            surviving dedicated suites, so the absence logic cannot pass
#            vacuously
#
# ESCAPE HATCH: re-introducing any of these hooks requires updating this suite
# AND SECURITY_BASELINE.json in the same PR — manifest and code move together.
# (Bash adaptation of mmx-3's pytest shape: the gate's runner executes bash
# suites only; a pytest absence file would never run — un-runnable test = the
# exact fail-open this suite exists to prevent.)

set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
EXAMPLE="$REPO_ROOT/.claude/settings.json.example"
MANIFEST="$REPO_ROOT/.claude/security/SECURITY_BASELINE.json"
GATE="$REPO_ROOT/tests/run-all-unit-tests.sh"

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  FAIL(slice-c): $1" >&2; }

REMOVED=(teammate-idle-quality-gate agent-diary-writer subagent-stop-universal
         ralph-subagent-stop ralph-stop-quality-gate anti-rationalization-gate
         quality-parallel-async)

# 1. file absence
for h in "${REMOVED[@]}"; do
  if [[ -e "$REPO_ROOT/.claude/hooks/$h.sh" || -e "$REPO_ROOT/.claude/hooks/$h.py" ]]; then
    bad "hook re-appeared: $h.sh (escape hatch: update SECURITY_BASELINE + this suite in the same PR)"
  else
    ok
  fi
done

# 2. example absence
ex_json=$(cat "$EXAMPLE")
for h in "${REMOVED[@]}"; do
  if grep -q "$h" "$EXAMPLE"; then
    bad "example registers removed hook: $h"
  else
    ok
  fi
done

# 3. dedicated test dirs gone or empty
for d in tests/stop-hook tests/quality-parallel; do
  if [[ ! -e "$REPO_ROOT/$d" ]] || [[ -z "$(ls -A "$REPO_ROOT/$d" 2>/dev/null)" ]]; then
    ok
  else
    bad "dedicated dir still has content: $d"
  fi
done

# 4. survivor hooks exist as files (registration is ACTIVE-side, not example)
for s in task-completed-quality-gate.sh task-list-projection.sh \
         orchestrator-report.sh sentry-report.sh; do
  if [[ -f "$REPO_ROOT/.claude/hooks/$s" ]]; then
    ok
  else
    bad "survivor hook missing: $s"
  fi
done

# 5. worker-blocked-safe preserved
for h in git-safety-guard.py repo-boundary-guard.sh permission-guard.sh \
         k8s-context-guard-v2.py skill-validator.sh; do
  if [[ -f "$REPO_ROOT/.claude/hooks/$h" ]]; then
    ok
  else
    bad "worker-blocked-safe hook missing: $h"
  fi
done

# 6. SECURITY manifest intact
n_controls=$(jq '.controls | length' "$MANIFEST" 2>/dev/null)
gap_ids=$(jq -r '[.gaps[].id] | sort | join(",")' "$MANIFEST" 2>/dev/null)
if [[ "$n_controls" == "6" && "$gap_ids" == "mcp-egress,package-manager,red-toxic,secrets-ordinary-work,symlink-escape" ]]; then
  ok
else
  bad "SECURITY manifest drifted (controls=$n_controls gaps=$gap_ids)"
fi

# 7. positive control: this suite stays registered in the gate
grep -q "security/test-slice-c-absence.sh" "$GATE" \
  || bad "suite de-registered from the gate (coverage removed silently)"

echo "Results: $PASS passed, $FAIL failed (Slice C absence matrix)"
if [[ "$FAIL" -ne 0 || "$PASS" -eq 0 ]]; then
  echo "FAIL(slice-c-absence): $FAIL failing / $PASS passing assertions" >&2
  exit 1
fi
exit 0
