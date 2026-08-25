"""Regression tests for permission-guard.sh v2.0 (T16, issue #58).

The guard must FAIL CLOSED: a delegate that is missing, crashes, exits
non-zero, prints nothing, or prints unparseable output produces a DENY —
never an allow. One test per delegate failure mode (the bug survived since
f19e2f70 precisely because only the happy path was covered), plus the
trap path, stderr preservation, and the PreToolUse JSON contract
(tests/HOOK_FORMAT_REFERENCE.md).

The delegates are fakes in a sandbox (real guard copy + controllable
delegates) — these tests never execute the real git-safety-guard.py.
"""
import json
import os
import shutil
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
GUARD = REPO / ".claude" / "hooks" / "permission-guard.sh"

BASH_INPUT = '{"tool_name": "Bash", "tool_input": {"command": "ls -la"}}'
EDIT_INPUT = '{"tool_name": "Edit", "tool_input": {"file_path": "/tmp/x.py"}}'

FAKE_SAFETY_PY = """\
import os, sys
mode = os.environ.get("FAKE_SAFETY", "allow")
if mode == "allow":
    print('{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}')
    sys.exit(0)
if mode == "deny":
    print('{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "fake safety deny"}}')
    sys.exit(1)  # real delegate exits 1 on deny — JSON is authoritative
if mode == "ask":
    print('{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": "fake safety ask"}}')
    sys.exit(0)
if mode == "empty":
    sys.exit(0)
if mode == "garbage":
    print("not-json{{{")
    sys.exit(0)
if mode == "noise3":
    sys.stderr.write("boom from safety delegate\\n")
    print("noise")
    sys.exit(3)
sys.exit(0)
"""

FAKE_BOUNDARY_SH = """\
#!/usr/bin/env bash
case "${FAKE_BOUNDARY:-allow}" in
  allow)   echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}'; exit 0 ;;
  deny)    echo '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": "fake boundary deny"}}'; exit 0 ;;
  empty)   exit 0 ;;
  garbage) echo 'no-json{{'; exit 0 ;;
  crash)   echo "boundary internal error" >&2; exit 2 ;;
esac
"""


def build_sandbox(tmp_path, with_safety=True, with_boundary=True):
    hooks = tmp_path / "hooks"
    hooks.mkdir()
    shutil.copy2(GUARD, hooks / "permission-guard.sh")
    if with_safety:
        (hooks / "git-safety-guard.py").write_text(FAKE_SAFETY_PY)
    if with_boundary:
        p = hooks / "repo-boundary-guard.sh"
        p.write_text(FAKE_BOUNDARY_SH)
        p.chmod(0o755)
    return hooks


def run_guard(hooks, stdin, env_extra=None, cwd=None):
    env = {k: v for k, v in os.environ.items()
           if not k.startswith("FAKE_")}
    env["HOME"] = str(hooks.parent)  # log isolation
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["bash", str(hooks / "permission-guard.sh")],
        input=stdin,
        capture_output=True,
        text=True,
        env=env,
        cwd=str(cwd or hooks.parent),
        timeout=30,
    )


def decision_of(result):
    payload = json.loads(result.stdout)  # double-echo would fail here
    return payload["hookSpecificOutput"]["permissionDecision"]


# --- Happy paths and propagation (behavior preserved from v1.1) ---

def test_allow_flow(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, BASH_INPUT,
                       {"FAKE_SAFETY": "allow", "FAKE_BOUNDARY": "allow"})
    assert result.returncode == 0
    assert decision_of(result) == "allow"

def test_safety_deny_json_propagated_despite_exit_1(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, BASH_INPUT, {"FAKE_SAFETY": "deny"})
    assert decision_of(result) == "deny"
    assert "fake safety deny" in result.stdout

def test_safety_ask_propagated(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, BASH_INPUT, {"FAKE_SAFETY": "ask"})
    assert decision_of(result) == "ask"

def test_boundary_deny_propagated(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, EDIT_INPUT, {"FAKE_BOUNDARY": "deny"})
    assert decision_of(result) == "deny"


# --- One test per delegate failure mode: each must DENY (issue #58) ---

def test_missing_interpreter_denies(tmp_path):
    hooks = build_sandbox(tmp_path)
    binroot = tmp_path / "bin"
    binroot.mkdir()
    for tool in ("bash", "jq", "head", "mktemp", "date", "cat", "rm", "dirname"):
        target = shutil.which(tool)
        assert target, f"test env lacks {tool}"
        os.symlink(target, binroot / tool)
    # python3 deliberately absent from PATH
    result = run_guard(hooks, BASH_INPUT, {"PATH": str(binroot)})
    assert decision_of(result) == "deny"
    assert "git-safety-guard.py" in result.stdout

def test_missing_safety_delegate_denies(tmp_path):
    hooks = build_sandbox(tmp_path, with_safety=False)
    result = run_guard(hooks, BASH_INPUT)
    assert decision_of(result) == "deny"
    assert "git-safety-guard.py" in result.stdout

def test_missing_boundary_delegate_denies(tmp_path):
    hooks = build_sandbox(tmp_path, with_boundary=False)
    result = run_guard(hooks, EDIT_INPUT)
    assert decision_of(result) == "deny"
    assert "repo-boundary-guard.sh" in result.stdout

def test_delegate_exit_nonzero_unparseable_denies(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, BASH_INPUT, {"FAKE_SAFETY": "noise3"})
    assert decision_of(result) == "deny"

def test_safety_empty_output_denies(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, BASH_INPUT, {"FAKE_SAFETY": "empty"})
    assert decision_of(result) == "deny"

def test_boundary_empty_output_denies(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, EDIT_INPUT, {"FAKE_BOUNDARY": "empty"})
    assert decision_of(result) == "deny"

def test_safety_invalid_json_denies(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, BASH_INPUT, {"FAKE_SAFETY": "garbage"})
    assert decision_of(result) == "deny"

def test_boundary_invalid_json_denies(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, EDIT_INPUT, {"FAKE_BOUNDARY": "garbage"})
    assert decision_of(result) == "deny"

def test_boundary_crash_denies(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, EDIT_INPUT, {"FAKE_BOUNDARY": "crash"})
    assert decision_of(result) == "deny"


# --- The trap: premature death denies, with exactly ONE verdict ---

def test_trap_premature_death_denies_single_json(tmp_path):
    # Premature death simulated on a copy: a `false` right after the stdin
    # read trips set -e before any decision point. (TMPDIR tricks do NOT
    # work here — macOS mktemp silently ignores an invalid TMPDIR, verified
    # rc=0.) The trap must yield exactly ONE parseable deny: json.loads
    # would fail on the double echo of a non-idempotent trap.
    hooks = build_sandbox(tmp_path)
    guard = hooks / "permission-guard.sh"
    text = guard.read_text()
    anchor = "INPUT=$(head -c 100000)"
    assert anchor in text
    guard.write_text(text.replace(
        anchor, anchor + "\nfalse  # T16 test injection: premature death", 1))
    result = run_guard(hooks, BASH_INPUT)
    assert decision_of(result) == "deny"
    assert "trap" in result.stdout


# --- Requirement 2: delegate stderr is visible, not swallowed ---

def test_delegate_stderr_preserved_and_logged(tmp_path):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, BASH_INPUT, {"FAKE_SAFETY": "noise3"})
    assert "boom from safety delegate" in result.stderr  # re-emitted
    log = hooks.parent / ".ralph" / "permission-guard.log"
    assert log.exists()
    assert "git-safety-guard.py" in log.read_text()      # logged


# --- PreToolUse JSON contract (tests/HOOK_FORMAT_REFERENCE.md) ---

@pytest.mark.parametrize("scenario,stdin,env", [
    ("allow", BASH_INPUT, {"FAKE_SAFETY": "allow"}),
    ("deny-propagated", BASH_INPUT, {"FAKE_SAFETY": "deny"}),
    ("ask-propagated", BASH_INPUT, {"FAKE_SAFETY": "ask"}),
    ("deny-internal", BASH_INPUT, {"FAKE_SAFETY": "garbage"}),
])
def test_json_contract_never_decision_continue(tmp_path, scenario, stdin, env):
    hooks = build_sandbox(tmp_path)
    result = run_guard(hooks, stdin, env)
    payload = json.loads(result.stdout)
    assert payload["hookSpecificOutput"]["hookEventName"] == "PreToolUse"
    assert payload["hookSpecificOutput"]["permissionDecision"] in ("allow", "deny", "ask")
    assert '"decision": "continue"' not in result.stdout
    assert '"decision":"continue"' not in result.stdout
