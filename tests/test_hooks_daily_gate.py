"""
T81: daily-gate.sh — periodic maintenance hooks skip when already ran today.

Three conditions per the gate-validation rule (applied to time-based dedup):
  (a) PASSES on a clean tree: when a marker for today exists, the gate reports
      "should skip" so the hook emits a breadcrumb and exits 0 — body never runs.
  (b) FAILS on a fresh violation: if the marker is cleared (or never written),
      the gate reports "should run" — the body executes and produces its artefact.
  (c) ESCAPE HATCH silences: when RALPH_FORCE_DAILY_GATE=1 is set, the gate
      reports "should run" EVEN IF a marker for today exists — an explicit
      override beats the dedup.

Plus a T75 alignment check: markers live under $HOME/.ralph/markers/ (or the
override), NEVER inside the project tree. The lib takes RALPH_DAILY_GATE_DIR
as the override hook so a test can isolate without polluting the real home.

A single integration test confirms the wiring: vault-graduation.sh sources
the library and the gate actually short-circuits the body on a second call.
The other three hooks (vault-promotion, auto-sync-global,
project-backup-metadata) use the same source line, so this integration is the
proof for the pattern.
"""

import json
import os
import shutil
import subprocess
from pathlib import Path

LIB_PATH = (
    Path(__file__).resolve().parent.parent / ".claude" / "hooks" / "lib" / "daily-gate.sh"
)
HOOKS_DIR = Path(__file__).resolve().parent.parent / ".claude" / "hooks"
VAULT_GRADUATION_HOOK = HOOKS_DIR / "vault-graduation.sh"


def source_lib_in_subprocess(env_overrides, hook_name="t81-test-hook"):
    """Source the library in a fresh bash subprocess and call daily_gate_check.

    Returns (returncode, stdout).
    """
    env = os.environ.copy()
    for k, v in env_overrides.items():
        if v is None:
            env.pop(k, None)
        else:
            env[k] = str(v)

    # Heredoc that sources the lib, runs the check, captures return code + output.
    script = f"""
set +e
source {repr(str(LIB_PATH))}
if daily_gate_check {repr(hook_name)!r}; then
    echo "RUN"
else
    echo "SKIP"
fi
exit 0
"""
    result = subprocess.run(
        ["bash", "-c", script],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )
    return result.returncode, result.stdout.strip(), result.stderr


def touch_marker(env_dir, hook_name="t81-test-hook"):
    """Create a marker file for (hook, today) under the override dir.

    The marker content is irrelevant (the lib creates a zero-byte file); only
    the filename matching the lib's convention matters.
    """
    marker = env_dir / "daily-gate-{}-{}.tmp".format(
        hook_name, "today"
    )
    # Use the same naming convention as the lib internally:
    import datetime as _dt

    today = _dt.datetime.now(_dt.UTC).strftime("%Y%m%d")
    real_marker = env_dir / f"daily-gate-{hook_name}-{today}"
    real_marker.touch()
    return real_marker


# ---------------------------------------------------------------------------
# Condition (a) — PASSES on a clean tree: marker present → gate says SKIP.
# ---------------------------------------------------------------------------
def test_daily_gate_skips_when_marker_present(isolated_home, tmp_path):
    """A second invocation the same day must be a no-op."""
    env_dir = tmp_path / "markers"
    env_dir.mkdir()

    # Pre-condition: write a marker as if the hook had already run today.
    touch_marker(env_dir, "t81-skip-once")
    assert (env_dir / f"daily-gate-t81-skip-once-{(__import__('datetime').datetime.now(__import__('datetime').UTC).strftime('%Y%m%d'))}").exists()

    env_overrides = {"RALPH_DAILY_GATE_DIR": str(env_dir), "RALPH_FORCE_DAILY_GATE": None}
    rc, out, err = source_lib_in_subprocess(env_overrides, "t81-skip-once")
    assert rc == 0, f"bash crashed: {err}"
    assert out == "SKIP", (
        f"gate returned {out!r}; expected SKIP because the marker exists. "
        f"If this assertion fires, the gate is letting a second same-day "
        f"invocation through — the periodic maintenance will pay the full "
        f"cost twice and the T81 fix did not take."
    )


# ---------------------------------------------------------------------------
# Condition (b) — FAILS on a fresh violation: marker cleared → gate says RUN.
# ---------------------------------------------------------------------------
def test_daily_gate_runs_when_marker_cleared(isolated_home, tmp_path):
    """After deleting today's marker (simulating a clock-tick or fresh user),
    the next invocation must run."""
    env_dir = tmp_path / "markers"
    env_dir.mkdir()

    hook_name = "t81-runs-after-clear"

    # First call: marker absent → RUN, then call touch to create it.
    import datetime as _dt
    today = _dt.datetime.now(_dt.UTC).strftime("%Y%m%d")
    marker_path = env_dir / f"daily-gate-{hook_name}-{today}"
    assert not marker_path.exists(), "test bug: marker already exists"

    env_overrides = {"RALPH_DAILY_GATE_DIR": str(env_dir), "RALPH_FORCE_DAILY_GATE": None}
    rc, out, err = source_lib_in_subprocess(env_overrides, hook_name)
    assert rc == 0
    assert out == "RUN"

    # Touch the marker (simulate post-body) and verify a second call says SKIP.
    marker_path.touch()
    rc, out, err = source_lib_in_subprocess(env_overrides, hook_name)
    assert out == "SKIP"

    # Now simulate the violation: clear the marker and re-invoke.
    marker_path.unlink()
    rc, out, err = source_lib_in_subprocess(env_overrides, hook_name)
    assert out == "RUN", (
        f"after clearing today's marker, gate must allow the body to run "
        f"again; got {out!r}. If this assertion fires, the gate's re-arm "
        f"path is broken and T81 cannot recover from mid-day restarts."
    )


# ---------------------------------------------------------------------------
# Condition (c) — ESCAPE HATCH silences: force flag overrides an existing marker.
# ---------------------------------------------------------------------------
def test_daily_gate_force_bypasses_existing_marker(isolated_home, tmp_path):
    """Setting RALPH_FORCE_DAILY_GATE=1 must bypass the dedup, even when the
    marker for today already exists."""
    env_dir = tmp_path / "markers"
    env_dir.mkdir()

    # Pre-condition: marker present.
    touch_marker(env_dir, "t81-force-bypass")
    env_overrides_no_force = {
        "RALPH_DAILY_GATE_DIR": str(env_dir),
        "RALPH_FORCE_DAILY_GATE": None,
    }
    rc, out, _ = source_lib_in_subprocess(env_overrides_no_force, "t81-force-bypass")
    assert out == "SKIP", "control: gate normally says SKIP with marker + no force"

    # The escape hatch: force flag set → must say RUN.
    env_overrides_force = {
        "RALPH_DAILY_GATE_DIR": str(env_dir),
        "RALPH_FORCE_DAILY_GATE": "1",
    }
    rc, out, _ = source_lib_in_subprocess(env_overrides_force, "t81-force-bypass")
    assert out == "RUN", (
        f"with RALPH_FORCE_DAILY_GATE=1 the gate must return RUN even though "
        f"the marker exists; got {out!r}. If this assertion fires, the "
        f"escape hatch is broken and an operator who actually wants to force "
        f"a periodic re-run cannot."
    )


# ---------------------------------------------------------------------------
# T75 alignment: markers are NEVER inside the project tree.
# ---------------------------------------------------------------------------
def test_marker_path_is_outside_project(isolated_home, tmp_path):
    """The lib must default to $HOME/.ralph/markers/ and respect
    RALPH_DAILY_GATE_DIR; it must not write anywhere under the project cwd."""
    # Use a marker-less invocation and inspect the path it would write to.
    env_overrides = {"RALPH_DAILY_GATE_DIR": str(tmp_path / "isolated")}
    rc, _, _ = source_lib_in_subprocess(env_overrides, "t81-isolation")
    assert rc == 0

    # Now touch with the override and verify the project tree is untouched.
    from tests.conftest import PROJECT_ROOT  # type: ignore

    project_root = Path(PROJECT_ROOT)
    project_root_resolved = project_root.resolve()

    # Walk the project; any file matching the marker shape would be a leak.
    leak_patterns = [
        ".claude/daily-gate-t81-isolation-*",
        "daily-gate-t81-isolation-*",
        ".claude/markers/daily-gate-t81-isolation-*",
    ]
    for pattern in leak_patterns:
        for hit in project_root_resolved.rglob(pattern):
            assert False, f"marker leaked into project tree: {hit}"

    # And the override dir is honoured:
    expected_dir = tmp_path / "isolated"
    assert expected_dir.is_dir(), (
        f"RALPH_DAILY_GATE_DIR was not created/used; expected {expected_dir}"
    )


# ---------------------------------------------------------------------------
# Integration: vault-graduation.sh sources the library and the gate takes effect.
# ---------------------------------------------------------------------------
def test_vault_graduation_hook_skips_with_marker_present(isolated_home, tmp_path):
    """End-to-end: invoke the real hook with a marker already written for
    today. Expect (a) exit 0, (b) the breadcrumb mentions 'skipped', and
    (c) no background fork was launched (no bg log file appears)."""
    env_dir = tmp_path / "markers"
    env_dir.mkdir()
    touch_marker(env_dir, "vault-graduation")

    bg_log = Path(os.path.expanduser("~")) / ".ralph" / "logs" / "vault-graduation.bg.log"
    bg_size_before = bg_log.stat().st_size if bg_log.exists() else 0

    env = os.environ.copy()
    env["RALPH_DAILY_GATE_DIR"] = str(env_dir)
    env["RALPH_FORCE_DAILY_GATE"] = ""

    result = subprocess.run(
        [str(VAULT_GRADUATION_HOOK)],
        input="",
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
    )
    assert result.returncode == 0, f"hook exited non-zero: {result.stderr}"

    # Condition (a): no error on stderr.
    assert "error" not in result.stderr.lower(), (
        f"unexpected stderr: {result.stderr!r}"
    )

    # Condition (b): the breadcrumb mentions the skipped state.
    out = result.stdout.strip()
    assert "skipped" in out.lower(), (
        f"breadcrumb does not say 'skipped'; got {out!r}. Either the gate "
        f"fired and we forgot to update the breadcrumb text, or the body "
        f"still ran because the source / check call is not wired."
    )

    # Condition (c): no new bytes in the background log (no fork happened).
    if bg_log.exists():
        bg_size_after = bg_log.stat().st_size
        assert bg_size_after == bg_size_before, (
            f"background log grew from {bg_size_before} to {bg_size_after} "
            f"despite the gate firing; the gate did not short-circuit the "
            f"bg dispatch and we are paying the full cost every SessionStart."
        )
