#!/usr/bin/env bash
# test_quality_check_registry.sh - Regression test for BUG-5.
#
# BUG-5: quality-parallel-async.sh registered four checks, three of which
# pointed at scripts that had been moved to .claude/archive/ by the Wave H1 hook
# census (d066c63):
#   sec-context-validate.sh, quality-gates-v2.sh, deslop-auto-clean.sh
# Nothing hung, because run_quality_check caught the non-zero exit, wrote
# {"status":"failed","error":"Script returned non-zero"} and still touched the
# .done marker. So the gates had never run and every aggregated report carried
# three permanently failed checks.
#
# Secondary defect: the display names ("quality-gates", "deslop-clean") did not
# match the result-file basenames ("code-review", "deslop") that
# read-quality-results.sh polls, so the self-reported "checks" array listed
# names that never corresponded to a file.
#
# This test enforces three invariants:
#   1. Every .claude/hooks/<script> referenced from hooks or scripts exists.
#   2. Every check name equals its result-file basename.
#   3. quality-parallel-async.sh and read-quality-results.sh agree on the list.
#
# Usage: bash tests/hooks/test_quality_check_registry.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT" || exit 1

ASYNC_HOOK=".claude/hooks/quality-parallel-async.sh"
READER=".claude/scripts/read-quality-results.sh"

PASS=0
FAIL=0
pass() { printf '  PASS  %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; printf '        %s\n' "$2"; FAIL=$((FAIL + 1)); }

# ---------------------------------------------------------------------------
# 1. No dangling .claude/hooks/<script> reference anywhere in hooks or scripts.
# ---------------------------------------------------------------------------
test_no_dangling_hook_references() {
    local dangling
    dangling=$(python3 - <<'PY'
import pathlib, re
pat = re.compile(r"\.claude/hooks/[A-Za-z0-9._-]+\.(?:sh|py|mjs|js)")
out = []
for d in (".claude/hooks", ".claude/scripts"):
    root = pathlib.Path(d)
    if not root.is_dir():
        continue
    for p in sorted(root.rglob("*")):
        if not p.is_file():
            continue
        try:
            text = p.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for lineno, line in enumerate(text.split("\n"), 1):
            if line.lstrip().startswith("#"):
                continue
            for ref in pat.findall(line):
                if not pathlib.Path(ref).exists():
                    out.append(f"{p}:{lineno}: {ref}")
print("\n".join(out))
PY
)
    if [[ -z "$dangling" ]]; then
        pass "no hook or script references a missing .claude/hooks/ script"
    else
        fail "dangling .claude/hooks/ references" "$dangling"
    fi
}

# ---------------------------------------------------------------------------
# 2 + 3. Check names match result basenames and both files agree.
# ---------------------------------------------------------------------------
test_check_names_match_result_basenames() {
    local report
    report=$(python3 - "$ASYNC_HOOK" "$READER" <<'PY'
import re, sys, pathlib

async_hook, reader = (pathlib.Path(p) for p in sys.argv[1:3])
problems = []

hook_text = async_hook.read_text()

# run_quality_check "<name>" "<script>" "$<VAR>_RESULT" ...
launches = re.findall(
    r'run_quality_check\s+"([^"]+)"\s+"([^"]+)"\s+"\$\{?(\w+)\}?"', hook_text
)
# readonly VAR="${RESULTS_DIR}/<basename>_${RUN_ID}.json"
result_vars = dict(
    re.findall(r'readonly\s+(\w+)="\$\{RESULTS_DIR\}/([A-Za-z0-9._-]+)_\$\{RUN_ID\}\.json"', hook_text)
)

launched = []
for name, _script, var in launches:
    launched.append(name)
    basename = result_vars.get(var)
    if basename is None:
        problems.append(f'check "{name}" uses unknown result variable ${var}')
    elif basename != name:
        problems.append(
            f'check name "{name}" does not match its result-file basename "{basename}"'
        )

# self-reported "checks": [...] array
declared = re.search(r'"checks":\s*\[([^\]]*)\]', hook_text)
declared_names = re.findall(r'"([^"]+)"', declared.group(1)) if declared else []
if sorted(declared_names) != sorted(launched):
    problems.append(
        f'self-reported "checks" {declared_names} != actually launched {launched}'
    )

# reader's polled check lists
reader_text = reader.read_text()
for match in re.finditer(r'local checks=\(([^)]*)\)', reader_text):
    polled = re.findall(r'"([^"]+)"', match.group(1))
    if sorted(polled) != sorted(launched):
        problems.append(
            f"read-quality-results.sh polls {polled} but the hook launches {launched}"
        )

print("\n".join(problems))
PY
)
    if [[ -z "$report" ]]; then
        pass "check names match result basenames and all three lists agree"
    else
        fail "quality check registry is inconsistent" "$report"
    fi
}

# ---------------------------------------------------------------------------
# BUG-7 guard: stop-slop-hook.sh reads .tool_input.file_path, which the Stop
# event does not carry, so registering it on Stop makes it a permanent no-op.
# The repo template ships no such registration today; this keeps it that way.
# ---------------------------------------------------------------------------
test_stop_slop_not_registered_on_stop() {
    local templates=()
    while IFS= read -r f; do templates+=("$f"); done < <(
        git ls-files '*settings*.json' '*settings*.json.example' 'installer/*' 2>/dev/null
    )
    [[ ${#templates[@]} -gt 0 ]] || { pass "stop-slop registration (no templates tracked)"; return; }

    local report
    report=$(python3 - "${templates[@]}" <<'PY'
import json, re, sys
problems = []
for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8").read()
    except (OSError, UnicodeDecodeError):
        continue
    if "stop-slop" not in text:
        continue
    try:
        data = json.loads(text)
    except ValueError:
        # Not JSON (installer script): flag only an explicit Stop registration.
        if re.search(r'Stop[^\n]*stop-slop|stop-slop[^\n]*Stop', text):
            problems.append(f"{path}: registers stop-slop near a Stop event")
        continue
    for entry in (data.get("hooks") or {}).get("Stop", []):
        for hook in entry.get("hooks", []):
            if "stop-slop" in hook.get("command", ""):
                problems.append(
                    f"{path}: stop-slop registered on Stop (no .tool_input there); "
                    "use PostToolUse with a Write|Edit|MultiEdit matcher"
                )
print("\n".join(problems))
PY
)
    if [[ -z "$report" ]]; then
        pass "no tracked template registers stop-slop on Stop"
    else
        fail "stop-slop registered on an event that lacks its input" "$report"
    fi
}

echo "BUG-5 regression: quality check registry consistency"
echo

test_no_dangling_hook_references
test_check_names_match_result_basenames
test_stop_slop_not_registered_on_stop

echo
printf 'passed: %d  failed: %d\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
