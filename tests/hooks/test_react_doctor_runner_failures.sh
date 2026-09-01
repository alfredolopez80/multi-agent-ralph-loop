#!/usr/bin/env bash
# test_react_doctor_runner_failures.sh - react-doctor.mjs must not present a
# runner/setup failure as a code-quality finding.
#
# The hook tries several ways to invoke react-doctor (local bin, global, pnpm dlx,
# npx) and falls through on 127/9009. It used to accept the first candidate that
# merely *started*, so a registry 404, auth, TLS or offline error exited non-zero,
# got written to the output file, and was reported to the model as "React Doctor
# found issues in the changed files" — a false regression warning after every
# qualifying edit in a restricted environment. It also skipped the remaining
# fallbacks. A scan reports on stdout; a runner that never ran the tool does not.
#
# Usage: bash tests/hooks/test_react_doctor_runner_failures.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK="$REPO_ROOT/.claude/hooks/react-doctor.mjs"
EDIT_BATCH='{"hook_event_name":"PostToolBatch","tool_calls":[{"tool_name":"Edit"}]}'

PASS=0
FAIL=0
pass() { PASS=$((PASS + 1)); }
fail() {
    printf '  FAIL  %s\n' "$1"
    printf '        %s\n' "$2"
    FAIL=$((FAIL + 1))
}

# Build a project whose local react-doctor bin behaves as described, and neutralise
# the network fallbacks so this exercises the hook rather than the real react-doctor:
# stub pnpm/npx exit 127, which is the code the hook already treats as "not here".
#
# The hook reads react-doctor's --json report and ignores the exit code, so $3 is
# set to values the real tool uses (non-zero both for findings and for "cannot run")
# precisely to prove the exit code no longer decides anything.
run_with_fake_bin() { # $1=stdout $2=stderr $3=exit-code -> prints hook stdout
    local fake_stdout="$1" fake_stderr="$2" fake_rc="$3" proj bin stub
    proj="$(mktemp -d)"
    bin="$proj/node_modules/.bin/react-doctor"
    mkdir -p "$(dirname "$bin")"
    # A root package.json marks the tree as JS; tsconfig.json narrows the hook's
    # applicability to TypeScript projects (user decision 2026-09-01, commit
    # "react-doctor: applicability narrowed to TypeScript projects").
    printf '{"name":"probe","dependencies":{"react":"18.0.0"}}\n' > "$proj/package.json"
    printf '{"compilerOptions":{}}\n' > "$proj/tsconfig.json"
    {
        printf '#!/bin/sh\n'
        [ -n "$fake_stdout" ] && printf 'printf "%%s\\n" %q\n' "$fake_stdout"
        [ -n "$fake_stderr" ] && printf 'printf "%%s\\n" %q >&2\n' "$fake_stderr"
        printf 'exit %s\n' "$fake_rc"
    } > "$bin"
    chmod +x "$bin"

    stub="$proj/.stub-bin"
    mkdir -p "$stub"
    for absent in pnpm npx react-doctor; do
        printf '#!/bin/sh\nexit 127\n' > "$stub/$absent"
        chmod +x "$stub/$absent"
    done

    # Prepend rather than replace: the stubs must shadow the real pnpm/npx, but the
    # rest of PATH has to stay intact (timeout(1) is not in /usr/bin on macOS).
    printf '%s' "$EDIT_BATCH" \
        | PATH="$stub:$PATH" CLAUDE_PROJECT_DIR="$proj" timeout 60 node "$HOOK" 2>/dev/null
}

reports_findings() { # $1=hook stdout -> "yes"/"no"
    printf '%s' "$1" | python3 -c '
import json, sys
raw = sys.stdin.read().strip()
if not raw:
    print("no"); raise SystemExit
try:
    d = json.loads(raw)
except ValueError:
    print("unparseable"); raise SystemExit
ctx = (d.get("hookSpecificOutput") or {}).get("additionalContext") or d.get("additional_context") or ""
print("yes" if "React Doctor found" in ctx else "no")
'
}

echo "react-doctor runner-failure probe"
echo

# 1. Registry/network failure: started, exited non-zero, nothing on stdout.
OUT="$(run_with_fake_bin '' 'ERR_PNPM_FETCH_404 GET https://registry.npmjs.org/react-doctor: Not Found' 1)"
if [[ "$(reports_findings "$OUT")" == "no" ]]; then
    pass
else
    fail "a registry failure was reported as a React Doctor finding" \
         "$(printf '%s' "$OUT" | head -c 300)"
fi

# 2. Same, but the runner also produced no stderr worth showing.
OUT="$(run_with_fake_bin '' '' 1)"
if [[ "$(reports_findings "$OUT")" == "no" ]]; then
    pass
else
    fail "a silent non-zero runner was reported as a finding" \
         "$(printf '%s' "$OUT" | head -c 300)"
fi

# A report carrying one error-severity diagnostic.
ERROR_REPORT='{"schemaVersion":3,"error":null,"reactDetected":true,"diagnostics":[{"filePath":"src/App.tsx","rule":"react-doctor/no-unstable-context-value","severity":"error","message":"Unstable context value","help":"Memoise it","line":12,"column":5,"category":"Correctness"}],"summary":{"errorCount":1,"warningCount":0,"totalDiagnosticCount":1}}'

# 3. Real findings must still be reported, exit code notwithstanding.
OUT="$(run_with_fake_bin "$ERROR_REPORT" 'scanned 1 file' 1)"
if [[ "$(reports_findings "$OUT")" == "yes" ]]; then
    pass
else
    fail "an error-severity diagnostic was suppressed" \
         "$(printf '%s' "$OUT" | head -c 300)"
fi

# 4. A clean report stays silent.
OUT="$(run_with_fake_bin '{"schemaVersion":3,"error":null,"reactDetected":true,"diagnostics":[],"summary":{"errorCount":0,"warningCount":0,"totalDiagnosticCount":0}}' '' 0)"
if [[ -z "${OUT// /}" ]]; then
    pass
else
    fail "a clean report emitted output" "$(printf '%s' "$OUT" | head -c 300)"
fi

# 5. A populated `error` field is a setup failure, never a finding — this is the
# shape the real tool returns in a tree with no React project.
OUT="$(run_with_fake_bin '{"schemaVersion":3,"error":{"message":"No React project found in /tmp/x"},"reactDetected":null,"diagnostics":[],"summary":{"errorCount":0,"warningCount":0,"totalDiagnosticCount":0}}' '' 1)"
if [[ -z "${OUT// /}" ]]; then
    pass
else
    fail "a report carrying an error field was presented as findings" \
         "$(printf '%s' "$OUT" | head -c 300)"
fi

# 6. Plain warnings outside a reported category do not interrupt; the same report
# with a Security category does. Reporting every warning on every edit batch is
# the noise this filter exists to prevent.
WARN='{"schemaVersion":3,"error":null,"reactDetected":true,"diagnostics":[{"filePath":"src/a.js","rule":"r","severity":"warning","message":"m","line":1,"column":1,"category":"Style"}],"summary":{"errorCount":0,"warningCount":1,"totalDiagnosticCount":1}}'
OUT="$(run_with_fake_bin "$WARN" '' 1)"
if [[ -z "${OUT// /}" ]]; then
    pass
else
    fail "a Style warning interrupted the loop" "$(printf '%s' "$OUT" | head -c 300)"
fi

SEC="${WARN//\"Style\"/\"Security\"}"
OUT="$(run_with_fake_bin "$SEC" '' 1)"
if [[ "$(reports_findings "$OUT")" == "yes" ]]; then
    pass
else
    fail "a Security warning was suppressed" "$(printf '%s' "$OUT" | head -c 300)"
fi

# 7. An unknown schemaVersion means the field names may have moved: stay silent
# rather than reporting from a shape we cannot read.
OUT="$(run_with_fake_bin "${ERROR_REPORT//\"schemaVersion\":3/\"schemaVersion\":99}" '' 1)"
if [[ -z "${OUT// /}" ]]; then
    pass
else
    fail "an unsupported schemaVersion was still parsed as findings" \
         "$(printf '%s' "$OUT" | head -c 300)"
fi

# 8. Whatever happens, the hook must emit valid JSON or nothing at all.
for spec in "|err|1" "$ERROR_REPORT|err|1" "$ERROR_REPORT||0" "not-json|err|1"; do
    IFS='|' read -r so se rc <<< "$spec"
    OUT="$(run_with_fake_bin "$so" "$se" "$rc")"
    if [[ "$(reports_findings "$OUT")" == "unparseable" ]]; then
        fail "hook emitted unparseable stdout [rc=$rc]" "$(printf '%s' "$OUT" | head -c 200)"
    else
        pass
    fi
done

# 6. A tree with no package.json is not scanned at all: react-doctor would exit
# non-zero there with "No React project found", a setup condition, not a finding.
# This hook is registered globally, so it fires in repos with no JavaScript.
NOJS="$(mktemp -d)"
OUT="$(printf '%s' "$EDIT_BATCH" | CLAUDE_PROJECT_DIR="$NOJS" timeout 60 node "$HOOK" 2>/dev/null)"
rmdir "$NOJS" 2>/dev/null || true
if [[ -z "${OUT// /}" ]]; then
    pass
else
    fail "a tree with no package.json produced output" "$(printf '%s' "$OUT" | head -c 300)"
fi

# 6b. A JS-only project (package.json present, no tsconfig.json and no typescript
# dependency) is out of scope since the 2026-09-01 TypeScript-only decision: the
# applicability guard must exit silently without invoking the runner.
NOTS="$(mktemp -d)"
printf '{"name":"probe","dependencies":{"react":"18.0.0"}}\n' > "$NOTS/package.json"
OUT="$(printf '%s' "$EDIT_BATCH" | CLAUDE_PROJECT_DIR="$NOTS" timeout 60 node "$HOOK" 2>/dev/null)"
rm -rf "$NOTS"
if [[ -z "${OUT// /}" ]]; then
    pass
else
    fail "a JS-only (non-TS) project produced output" "$(printf '%s' "$OUT" | head -c 300)"
fi

echo
printf 'checks passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
