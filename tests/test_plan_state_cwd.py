"""Plan-state path resolution is cwd-independent (T86, #47/#48 state family).

Three hooks resolved `.claude/plan-state.json` RELATIVELY: the file was found
(or created) wherever the session's cwd happened to be. A session whose cwd
had moved into a subdirectory silently skipped updates (status-auto-check,
reader), lost lib updates with an ERROR log (lsa-pre-step, writer via
plan_state_update), or could write out of place (plan-state-adaptive,
conditional writer). The statusline — the always-on consumer — reads the file
from the working tree root, so the resolution must be root-anchored.

Method: run each hook with `bash -x` from a SUBDIRECTORY of a temp git repo
and assert the trace resolves the absolute root path, never a bare relative
one. The trace makes the assertion independent of each hook's trigger
conditions — a skipped hook still resolves its paths first.
"""
import json
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parent.parent
HOOKS = REPO / ".claude" / "hooks"

HOOKS_UNDER_TEST = [
    "status-auto-check.sh",
    "plan-state-adaptive.sh",
    "lsa-pre-step.sh",
]

PAYLOADS = {
    "status-auto-check.sh": {"session_id": "t86", "tool_name": "Bash",
                             "tool_input": {"command": "ls"},
                             "tool_response": {"stdout": "x"}},
    "plan-state-adaptive.sh": {"session_id": "t86", "prompt": "cwd resolution test"},
    "lsa-pre-step.sh": {"session_id": "t86", "tool_name": "Task",
                        "tool_input": {"subagent_type": "ralph-coder",
                                       "prompt": "implement step s1"}},
}

PLAN_STATE_SEED = {
    "version": "3.0.0",
    "plan_name": "t86-plan",
    "current_phase": "implement",
    "active_agent": "",
    "classification": {"workflow_route": "standard", "adaptive_mode": "on"},
    "phases": [{"name": "implement", "status": "in_progress"}],
    "barriers": {},
    "steps": [{"id": "s1", "status": "in_progress", "description": "x"}],
    "metadata": {"session_id": "t86", "started_at": "2026-08-26T00:00:00Z"},
}


@pytest.fixture()
def repo_with_subdir(tmp_path):
    repo = tmp_path / "repo"
    (repo / ".claude").mkdir(parents=True)
    (repo / "sub" / "deep").mkdir(parents=True)
    subprocess.run(["git", "-C", str(repo), "init", "-q"], check=True)
    (repo / ".claude" / "plan-state.json").write_text(json.dumps(PLAN_STATE_SEED))
    return repo


@pytest.mark.parametrize("hook_name", HOOKS_UNDER_TEST)
def test_plan_state_resolves_from_working_tree_root(repo_with_subdir, hook_name):
    """From a subdirectory, the hook must reference the ABSOLUTE root path
    (…/repo/.claude/plan-state.json) and must never resolve or create a
    bare relative `.claude/plan-state.json` under the subdirectory."""
    repo = repo_with_subdir
    hook = HOOKS / hook_name
    proc = subprocess.run(
        ["bash", "-x", str(hook)],
        input=json.dumps(PAYLOADS[hook_name]),
        capture_output=True, text=True, timeout=30,
        cwd=str(repo / "sub" / "deep"),
    )
    trace = proc.stderr  # bash -x writes the trace to stderr
    root_ref = str(repo / ".claude" / "plan-state.json")
    assert root_ref in trace, (
        f"{hook_name}: from a subdirectory the trace never references the "
        f"root-anchored plan-state path — the relative-path bug is live. "
        f"Trace excerpt: {trace[-400:]!r}"
    )
    assert not list((repo / "sub").glob("**/plan-state.json")), (
        f"{hook_name}: created a plan-state.json under the subdirectory"
    )


def test_plan_state_update_writes_root_from_subdir(repo_with_subdir):
    """The writer mechanism, end to end: plan_state_update invoked with the
    root-anchored path (as the fixed hooks now resolve it) writes the ROOT
    file from a subdirectory — bumping .updated_at/.last_updated (the
    dual-write the statusline's freshness depends on). lsa-pre-step's own
    update is spec-gated, so the gate is exercised at the lib boundary where
    it is deterministic."""
    repo = repo_with_subdir
    lib = HOOKS / "lib" / "plan-state-writer.sh"
    root_state = repo / ".claude" / "plan-state.json"
    script = f'source "{lib}" && plan_state_update "{root_state}" \'.t86_probe = 1\''
    proc = subprocess.run(
        ["bash", "-c", script], capture_output=True, text=True, timeout=30,
        cwd=str(repo / "sub" / "deep"),
    )
    assert proc.returncode == 0, f"plan_state_update failed: {proc.stderr[-200:]}"
    data = json.loads(root_state.read_text())
    assert data.get("t86_probe") == 1, "update did not land on the root file"
    assert data.get("updated_at") and data.get("last_updated"), (
        "the dual-write freshness fields must both be bumped"
    )
    assert not list((repo / "sub").glob("**/plan-state.json"))
