"""
T75: parallel-explore.sh isolated output path — three-condition validation.

The defect this guards against (v2.69.0 and earlier):
  EXPLORATION_OUTPUT="$PROJECT_DIR/.claude/exploration-context.json"
which (a) polluted the real project tree during mocked-stdin testing, and
(b) left a generated artefact versioned in git because .gitignore did not
cover it. The fix (v2.69.1) routes the default through two env vars
(PARALLEL_EXPLORE_PROJECT_DIR, PARALLEL_EXPLORE_LOG_DIR,
PARALLEL_EXPLORE_OUTPUT) and places the default next to the log file —
outside the project. Setting PARALLEL_EXPLORE_OUTPUT to a path inside
$PROJECT_DIR is the documented escape hatch; it MUST be loud (WARN to the
log) so a caller cannot hide the override from reviewers.

Three conditions per the gate-validation rule:
  (a) Default invocation leaves the project's
      .claude/exploration-context.json UNTOUCHED.
  (b) When the escape hatch fires, the hook emits a visible WARN; this is
      the failure-detector for the violation, not the silent fallback.
  (c) The artefact written is valid JSON with the documented shape
      (status == "completed", exploration.*, session_id).
"""

import json
import os
import subprocess
from pathlib import Path

HOOK_PATH = (
    Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "parallel-explore.sh"
)


def run_hook(env_overrides, stdin_payload, timeout=120):
    env = os.environ.copy()
    for k, v in env_overrides.items():
        env[k] = str(v)
    return subprocess.run(
        [str(HOOK_PATH)],
        input=stdin_payload,
        env=env,
        capture_output=True,
        text=True,
        timeout=timeout,
    )


def task_payload():
    """Minimal stdin that reaches the gap-analyst branch inside the hook."""
    return json.dumps(
        {
            "tool_name": "Task",
            "session_id": "test-session",
            "tool_input": {
                "subagent_type": "gap-analyst",
                "prompt": "explore the project layout for review",
            },
        }
    )


def test_default_does_not_pollute_project(isolated_home, tmp_path):
    """(a) Default output lives OUTSIDE the project — the canonical artefact is never touched."""
    fake_project = tmp_path / "fake-project"
    fake_project.mkdir()
    log_dir = tmp_path / "ralph-logs"
    log_dir.mkdir()

    result = run_hook(
        env_overrides={
            "PARALLEL_EXPLORE_PROJECT_DIR": str(fake_project),
            "PARALLEL_EXPLORE_LOG_DIR": str(log_dir),
        },
        stdin_payload=task_payload(),
    )
    assert result.returncode == 0, f"hook crashed: {result.stderr}"
    payload = json.loads(result.stdout)
    assert payload["continue"] is True, (
        f"hook did not emit the expected PostToolUse shape: {payload}"
    )

    artefact = fake_project / ".claude" / "exploration-context.json"
    assert not artefact.exists(), (
        f"VIOLATION: default wrote to {artefact}; the v2.69.1 fix guarantees "
        f"the default leaves the project tree untouched. If this assertion "
        f"fires, either the default regressed or an upstream caller is "
        f"leaking an override into a default invocation."
    )


def test_default_output_is_valid_json(isolated_home, tmp_path):
    """(c) The artefact written by the default is valid JSON with the documented shape."""
    log_dir = tmp_path / "ralph-logs"
    log_dir.mkdir()

    result = run_hook(
        env_overrides={"PARALLEL_EXPLORE_LOG_DIR": str(log_dir)},
        stdin_payload=task_payload(),
    )
    assert result.returncode == 0, f"hook crashed: {result.stderr}"

    artefacts = sorted(log_dir.glob("exploration-context-*.json"))
    assert artefacts, (
        f"no exploration-context-*.json produced in {log_dir}; the default "
        f"path resolution or the writing block may have regressed."
    )
    payload = json.loads(artefacts[-1].read_text())
    assert payload["status"] == "completed"
    assert "exploration" in payload
    assert payload["session_id"] == "test-session"


def test_escape_hatch_writes_inside_project_with_warn(isolated_home, tmp_path):
    """(b) Escape hatch: caller opts to write inside the project → WARN logged, no abort."""
    fake_project = tmp_path / "fake-project"
    fake_project.mkdir()
    log_dir = tmp_path / "ralph-logs"
    log_dir.mkdir()

    target = fake_project / ".claude" / "exploration-context.json"
    result = run_hook(
        env_overrides={
            "PARALLEL_EXPLORE_PROJECT_DIR": str(fake_project),
            "PARALLEL_EXPLORE_LOG_DIR": str(log_dir),
            "PARALLEL_EXPLORE_OUTPUT": str(target),
        },
        stdin_payload=task_payload(),
    )
    assert result.returncode == 0, (
        f"hook aborted on opt-in override (exit {result.returncode}); the "
        f"escape hatch must allow writing inside the project. stderr:\n"
        f"{result.stderr}"
    )

    # (c) artefact written at the requested location
    assert target.exists(), (
        f"escape hatch failed end-to-end: no artefact at {target}. The WARN "
        f"block claims the override took effect; if the file is missing, "
        f"the override pipeline is broken."
    )
    payload = json.loads(target.read_text())
    assert payload["status"] == "completed"

    # (b) WARN is loud somewhere in the log produced this run
    logs = sorted(log_dir.glob("parallel-explore-*.log"))
    assert logs, (
        f"no parallel-explore-*.log in {log_dir}; the log block regressed or "
        f"LOG_DIR resolution broke."
    )
    log_text = logs[-1].read_text()
    assert "WARN parallel-explore: writing inside project tree" in log_text, (
        f"WARN signal missing in log {logs[-1]}. An opt-in override MUST be "
        f"audible; a silent override is the failure mode the contract "
        f"requires this assertion to detect."
    )
