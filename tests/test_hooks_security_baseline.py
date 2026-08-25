"""Regression tests for the SECURITY_BASELINE manifest (T20, issue #46).

The manifest (.claude/security/SECURITY_BASELINE.json) declares what the
security plane IS. These tests make its erosion loud:

  1. The manifest is non-empty and well-formed — zero controls is failure,
     never pass (same principle as the GNU guard's zero-scope rule).
  2. Every hook-kind control is REGISTERED in the active profile — a security
     hook that gets unregistered from settings.json must fail this suite.
     The checker logic is proven deterministically against a synthetic
     profile (CI-safe, per tests/test_hooks_registration.py's convention);
     the live check runs against the real ~/.claude/settings.json when it
     exists and SKIPS VISIBLY otherwise (skip is not pass).
  3. Every declared gap from #45 is still named — erasing a gap from the
     manifest must fail too.
  4. Every control's fixture actually fires: the control works TODAY, not
     just on paper.
"""
import json
import os
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
BASELINE_PATH = REPO / ".claude" / "security" / "SECURITY_BASELINE.json"

REQUIRED_GAP_IDS = {
    "secrets-ordinary-work",
    "red-toxic",
    "mcp-egress",
    "package-manager",
    "symlink-escape",
}
HOOK_REQUIRED_KEYS = {"id", "kind", "hook", "event", "matchers", "sources",
                      "fixture"}
VALID_GAP_STATUS = {"no-hook", "partial"}


# ---------------------------------------------------------------- validation

def _validate_baseline(data):
    """Raise ValueError on any way the manifest can lie by omission."""
    if not isinstance(data, dict) or "controls" not in data or "gaps" not in data:
        raise ValueError("manifest must be an object with 'controls' and 'gaps'")
    controls = data["controls"]
    if not isinstance(controls, list) or len(controls) == 0:
        raise ValueError("manifest has 0 controls — nothing was checked, "
                         "which is NOT 'all fine' (zero-scope rule)")
    for c in controls:
        missing = HOOK_REQUIRED_KEYS - set(c)
        if missing:
            raise ValueError(f"control {c.get('id', '?')} missing keys: {missing}")
        if c["kind"] == "hook" and (not c["event"] or not c["matchers"]):
            raise ValueError(f"hook control {c['id']} must declare event+matchers")
    gaps = {g.get("id"): g for g in data["gaps"]}
    for gap_id in REQUIRED_GAP_IDS:
        if gap_id not in gaps:
            raise ValueError(f"declared gap '{gap_id}' (#45) vanished from the "
                             f"manifest — a manifest that hides its gaps fakes "
                             f"coverage")
        if gaps[gap_id].get("status") not in VALID_GAP_STATUS:
            raise ValueError(f"gap '{gap_id}' has invalid status")


def _load():
    return json.loads(BASELINE_PATH.read_text())


def test_manifest_exists_nonempty_and_wellformed():
    data = _load()
    _validate_baseline(data)  # raises on any structural lie
    assert len(data["controls"]) >= 5  # the five shipped controls


def test_zero_entries_is_failure_not_pass():
    # The property, proven deterministically: an emptied manifest raises.
    with pytest.raises(ValueError, match="0 controls"):
        _validate_baseline({"controls": [], "gaps": []})


def test_baseline_files_exist():
    data = _load()
    for c in data["controls"]:
        assert (REPO / c["hook"]).is_file(), f"missing hook: {c['hook']}"
        for src in c.get("sources", []):
            assert (REPO / src).is_file(), f"missing source: {src} of {c['id']}"


# ------------------------------------------------------------ registration

def _missing_registrations(controls, settings):
    """(control_id, event, matcher) triples absent from the active profile."""
    hooks = settings.get("hooks", {})
    active = set()
    for event, matchers in hooks.items():
        for m in matchers:
            for h in m.get("hooks", []):
                cmd = h.get("command", "")
                active.add((event, m.get("matcher", ""), cmd))
    missing = []
    for c in controls:
        if c["kind"] != "hook":
            continue
        basename = Path(c["hook"]).name
        for matcher in c["matchers"]:
            found = any(event == c["event"] and matcher == m and basename in cmd
                        for event, m, cmd in active)
            if not found:
                missing.append((c["id"], c["event"], matcher))
    return missing


SYNTHETIC_SETTINGS = {
    "hooks": {
        "PreToolUse": [
            {"matcher": "Bash", "hooks": [
                {"command": "/x/.claude/hooks/git-safety-guard.py"}]},
            {"matcher": "Edit|Write", "hooks": [
                {"command": "/x/.claude/hooks/permission-guard.sh"}]},
        ]
    }
}


def test_registration_checker_fails_on_missing_entry():
    controls = [
        {"id": "git-safety", "kind": "hook", "hook": ".claude/hooks/git-safety-guard.py",
         "event": "PreToolUse", "matchers": ["Bash"], "sources": [], "fixture": {}},
        {"id": "permission-pipeline", "kind": "hook",
         "hook": ".claude/hooks/permission-guard.sh",
         "event": "PreToolUse", "matchers": ["Bash", "Edit|Write", "Agent|Task"],
         "sources": [], "fixture": {}},
    ]
    missing = _missing_registrations(controls, SYNTHETIC_SETTINGS)
    # git-safety fully registered; permission-guard only on Edit|Write.
    assert ("permission-pipeline", "PreToolUse", "Bash") in missing
    assert ("permission-pipeline", "PreToolUse", "Agent|Task") in missing
    assert all(cid != "git-safety" for cid, _, _ in missing)


def test_every_hook_control_registered_in_active_profile():
    settings_path = os.environ.get(
        "SECURITY_BASELINE_SETTINGS",
        os.path.expanduser("~/.claude/settings.json"),
    )
    if not os.path.isfile(settings_path):
        pytest.skip(
            "machine-local control: no active Claude profile on this host "
            "(checker logic proven by test_registration_checker_fails_on_"
            "missing_entry). Set SECURITY_BASELINE_SETTINGS to run the live "
            "check."
        )
    settings = json.loads(Path(settings_path).read_text())
    missing = _missing_registrations(_load()["controls"], settings)
    assert missing == [], (
        f"security controls unregistered from the active profile: {missing} "
        f"— a security hook that is not registered protects nothing"
    )


# ---------------------------------------------------------------- fixtures

@pytest.mark.parametrize("control_id", [
    "permission-pipeline", "git-safety", "repo-boundary", "k8s-context",
])
def test_control_fixture_fires(control_id):
    data = _load()
    control = next(c for c in data["controls"] if c["id"] == control_id)
    result = subprocess.run(
        ["bash", "-c", control["fixture"]["run"]],
        cwd=str(REPO), capture_output=True, text=True, timeout=30,
    )
    payload = json.loads(result.stdout)  # unparseable fixture output fails here
    decision = payload["hookSpecificOutput"]["permissionDecision"]
    assert decision == control["fixture"]["expect_decision"], (
        f"{control_id} fixture: expected "
        f"{control['fixture']['expect_decision']}, got {decision}"
    )
    assert control["fixture"]["expect_reason_contains"] in result.stdout


def test_lib_fixture_works():
    data = _load()
    control = next(c for c in data["controls"] if c["id"] == "worktree-utils")
    result = subprocess.run(
        ["bash", "-c", control["fixture"]["run"]],
        cwd=str(REPO), capture_output=True, text=True, timeout=30,
    )
    assert result.returncode == 0
    assert "multi-agent-ralph-loop" in result.stdout
