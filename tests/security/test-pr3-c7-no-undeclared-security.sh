#!/usr/bin/env bash
# test-pr3-c7-no-undeclared-security.sh — PR3-C7 (#69 §1B, PR 3 slice 1)
#
# Asserts the reconciliation of the two security-looking but non-enforcing
# registrations (Caso 7 of results-side analysis, docs/benchmark/PHASE0):
#   1. settings.json.example has NO audit-secrets.js / promptify-security.sh
#   2. SECURITY_BASELINE.json "deregistered" names BOTH, with destination+reason
#   3. the security-only profile is green: valid JSON, every registration
#      resolves to an existing repo file, neither hook appears in it
#   4. this suite is still registered in the gate (run-all-unit-tests.sh)
#
# ESCAPE HATCH (documented): the manifest is the contract. If one of these
# hooks must return to settings.json.example, the SAME PR must remove or
# re-scope its entry in SECURITY_BASELINE.json "deregistered" — this test
# stays red until manifest and settings move together. No other bypass exists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
EXAMPLE="$REPO_ROOT/.claude/settings.json.example"
MANIFEST="$REPO_ROOT/.claude/security/SECURITY_BASELINE.json"
SECONLY="$REPO_ROOT/.claude/security/settings.security-only.json"
GATE="$REPO_ROOT/tests/run-all-unit-tests.sh"

fail() { echo "FAIL(PR3-C7): $*" >&2; exit 1; }

# 0. both JSON files parse
jq -e . "$EXAMPLE" >/dev/null 2>&1 || fail "settings.json.example is not valid JSON"
jq -e . "$MANIFEST" >/dev/null 2>&1 || fail "SECURITY_BASELINE.json is not valid JSON"

# 1. example clean of the deregistered hooks
for hook in audit-secrets.js promptify-security.sh; do
  if grep -q "$hook" "$EXAMPLE"; then
    fail "$hook re-registered in settings.json.example. ESCAPE HATCH: remove or re-scope its SECURITY_BASELINE.json 'deregistered' entry in the SAME PR — manifest and settings move together."
  fi
done
echo "ok 1: settings.json.example carries no audit-secrets.js / promptify-security.sh"

# 2. manifest 'deregistered' names both, with a real reason
jq -e '.deregistered | length >= 2' "$MANIFEST" >/dev/null 2>&1 \
  || fail "SECURITY_BASELINE.json has no 'deregistered' array (or it is empty)"
for hook in audit-secrets.js promptify-security.sh; do
  jq -e --arg h "$hook" '.deregistered[] | select(.hook | endswith($h)) | .reason | length > 20' \
    "$MANIFEST" >/dev/null 2>&1 \
    || fail "SECURITY_BASELINE.json 'deregistered' lacks an entry (or a substantive reason) for $hook"
done
echo "ok 2: manifest 'deregistered' names both hooks with destination and reason"

# 3. security-only profile green: all registrations resolve; no deregistered hook
if ! python3 - "$SECONLY" "$REPO_ROOT" <<'PY'
import json, os, sys
profile, root = sys.argv[1], sys.argv[2]
data = json.load(open(profile))
bad = []
for event, groups in (data.get("hooks") or {}).items():
    for g in groups:
        for h in g.get("hooks", []):
            cmd = h.get("command", "")
            path = cmd.replace("$CLAUDE_PROJECT_DIR", root)
            if not os.path.exists(path):
                bad.append(f"{event}: {cmd} (target missing)")
            if "audit-secrets" in cmd or "promptify-security" in cmd:
                bad.append(f"{event}: {cmd} (deregistered hook present)")
if bad:
    print("\n".join(bad), file=sys.stderr)
    sys.exit(1)
PY
then
  fail "security-only profile is not green (see targets listed above)"
fi
echo "ok 3: security-only profile green (every registration resolves; no deregistered hooks)"

# 4. suite still registered in the gate
grep -q "security/test-pr3-c7-no-undeclared-security.sh" "$GATE" \
  || fail "this suite was de-registered from tests/run-all-unit-tests.sh (gate coverage removed silently)"
echo "ok 4: suite registered in the unit-test gate"

echo "Results: 4 passed, 0 failed — no undeclared security registrations; manifest, example and profile reconciled (PR3-C7)"
