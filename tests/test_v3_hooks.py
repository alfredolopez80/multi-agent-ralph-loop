"""
Tests for the surviving v3.0 hook:
  1. project-state.sh        (SessionStart)

session-accumulator.sh and vault-graduation.sh were removed by #69 Slice D
(automatic memory writers); their test classes died with them.

Tests cover structure, safety properties, and functional behavior.
"""

import json
import os
import stat
import subprocess
import tempfile
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).parent.parent
HOOKS_DIR = REPO_ROOT / ".claude" / "hooks"

# ---------------------------------------------------------------------------
# Hook paths
# ---------------------------------------------------------------------------
PROJECT_STATE = HOOKS_DIR / "project-state.sh"

ALL_HOOKS = [PROJECT_STATE]
HOOK_IDS = ["project-state"]


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _read_hook(path: Path) -> str:
    """Return the full text of a hook file."""
    return path.read_text(encoding="utf-8")


def _run_hook(hook: Path, stdin_data: str = "", env_override: dict | None = None,
              args: list[str] | None = None, timeout: int = 15) -> subprocess.CompletedProcess:
    """Execute a hook, feeding *stdin_data* on stdin, and return the result."""
    env = os.environ.copy()
    # Use a temp vault dir so we don't write into the real vault
    tmp_vault = tempfile.mkdtemp(prefix="test_vault_")
    env["VAULT_DIR"] = tmp_vault
    if env_override:
        env.update(env_override)
    cmd = [str(hook)] + (args or [])
    return subprocess.run(
        cmd,
        input=stdin_data,
        capture_output=True,
        text=True,
        timeout=timeout,
        env=env,
        cwd=str(REPO_ROOT),
    )


def _parse_json_output(result: subprocess.CompletedProcess) -> dict:
    """Parse the last line of stdout as JSON (hooks may emit log lines before JSON)."""
    stdout = result.stdout.strip()
    if not stdout:
        return {}
    # Try full stdout first, then last line
    try:
        return json.loads(stdout)
    except json.JSONDecodeError:
        last_line = stdout.splitlines()[-1]
        return json.loads(last_line)


# ===========================================================================
# STRUCTURAL TESTS (all hooks)
# ===========================================================================

class TestAllHooksExistAndExecutable:
    """Every v3.0 hook must exist and be executable."""

    @pytest.mark.parametrize("hook", ALL_HOOKS, ids=HOOK_IDS)
    def test_file_exists(self, hook):
        assert hook.exists(), f"{hook.name} does not exist"

    @pytest.mark.parametrize("hook", ALL_HOOKS, ids=HOOK_IDS)
    def test_is_executable(self, hook):
        mode = hook.stat().st_mode
        assert mode & stat.S_IXUSR, f"{hook.name} is not executable by owner"


class TestAllHooksShebang:
    """Every v3.0 hook must start with the correct shebang."""

    @pytest.mark.parametrize("hook", ALL_HOOKS, ids=HOOK_IDS)
    def test_has_bash_shebang(self, hook):
        first_line = _read_hook(hook).splitlines()[0]
        assert first_line == "#!/usr/bin/env bash", (
            f"{hook.name} shebang is '{first_line}', expected '#!/usr/bin/env bash'"
        )


class TestAllHooksStrictMode:
    """Every v3.0 hook must use 'set -euo pipefail'."""

    @pytest.mark.parametrize("hook", ALL_HOOKS, ids=HOOK_IDS)
    def test_has_strict_mode(self, hook):
        text = _read_hook(hook)
        assert "set -euo pipefail" in text, f"{hook.name} missing 'set -euo pipefail'"


class TestAllHooksVersionMarker:
    """Every v3.0 hook must have a VERSION marker in its header."""

    @pytest.mark.parametrize("hook", ALL_HOOKS, ids=HOOK_IDS)
    def test_has_version_marker(self, hook):
        text = _read_hook(hook)
        assert "VERSION:" in text, f"{hook.name} missing VERSION marker"


class TestAllHooksUmask:
    """Every v3.0 hook should have 'umask 077' for secure file creation."""

    @pytest.mark.parametrize("hook", ALL_HOOKS, ids=HOOK_IDS)
    def test_has_umask_077(self, hook):
        text = _read_hook(hook)
        has_umask = "umask 077" in text or "umask 0077" in text
        if not has_umask:
            pytest.xfail(f"{hook.name} does not yet have umask 077 (recommended hardening)")


class TestAllHooksErrTrap:
    """Every v3.0 hook should have an ERR/INT/TERM trap producing valid JSON."""

    @pytest.mark.parametrize("hook", ALL_HOOKS, ids=HOOK_IDS)
    def test_has_err_trap(self, hook):
        text = _read_hook(hook)
        has_trap = "trap " in text and "ERR" in text
        if not has_trap:
            pytest.xfail(f"{hook.name} does not yet have ERR trap (recommended hardening)")




# ===========================================================================
# project-state.sh  (SessionStart)
# ===========================================================================

class TestProjectState:
    """Functional tests for project-state.sh."""

    def test_hook_mode_returns_valid_json(self):
        """Default invocation (hook mode) should return valid JSON."""
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(PROJECT_STATE, stdin_data=payload)
        assert result.returncode == 0
        output = _parse_json_output(result)
        assert isinstance(output, dict)

    def test_output_has_hook_specific_output(self):
        """Hook mode output must include hookSpecificOutput."""
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(PROJECT_STATE, stdin_data=payload)
        output = _parse_json_output(result)
        assert "hookSpecificOutput" in output, f"Missing hookSpecificOutput: {output}"

    def test_output_contains_skills_sync(self):
        """hookSpecificOutput should include skills_sync status."""
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(PROJECT_STATE, stdin_data=payload)
        output = _parse_json_output(result)
        hso = output.get("hookSpecificOutput", {})
        assert "skills_sync" in hso, f"Missing skills_sync in hookSpecificOutput: {hso}"

    def test_output_context_names_no_model(self):
        """hookSpecificOutput.context carries state, never a model/provider name.

        The hook used to report `context.model` ("claude" / "glm"), which made a
        provider visible in every SessionStart payload. The model is whatever the
        session runs; this hook has no business naming it.
        """
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(PROJECT_STATE, stdin_data=payload)
        output = _parse_json_output(result)
        hso = output.get("hookSpecificOutput", {})
        ctx = hso.get("context", {})
        assert "state_dir" in ctx, f"Missing 'state_dir' in context: {ctx}"
        assert "model" not in ctx, f"context must not name a model: {ctx}"
        assert "model" not in hso.get("additionalContext", "")

    def test_validate_skills_subcommand(self, isolated_home):
        """Running with 'validate-skills' arg should return JSON with status field.

        project-state.sh scans three skills locations under $HOME:
        ``~/.claude/skills``, ``~/backup/claude-skills`` and ``~/.agents/skills``. Under
        ``set -euo pipefail`` a ``find -L`` on a MISSING directory aborts the hook (the
        pipeline fails). On a fresh CI runner those last two dirs don't exist, so we run
        the hook under an isolated $HOME with all three skills dirs present — the real,
        expected environment for this subcommand — instead of the developer's $HOME."""
        for sub in ("backup/claude-skills", ".agents/skills"):
            (isolated_home / sub).mkdir(parents=True, exist_ok=True)
        # `.claude/skills` is already created by the isolated_home fixture.
        result = _run_hook(
            PROJECT_STATE,
            stdin_data="",
            args=["validate-skills"],
            env_override={"HOME": str(isolated_home)},
        )
        assert result.returncode == 0, (
            f"validate-skills exited {result.returncode}: "
            f"stdout={result.stdout!r} stderr={result.stderr!r}"
        )
        output = _parse_json_output(result)
        assert "status" in output, f"validate-skills missing 'status': {output}"

    def test_get_dir_subcommand(self):
        """Running with 'get-dir' arg should return a directory path."""
        result = _run_hook(PROJECT_STATE, stdin_data="", args=["get-dir"])
        assert result.returncode == 0
        dir_path = result.stdout.strip()
        assert len(dir_path) > 0, "get-dir returned empty string"

    def test_no_get_model_subcommand(self):
        """project-state.sh must not detect or report a model/provider.

        The verb used to branch context tracking on 'claude' vs 'glm' over an
        identical computation — provider routing with no behavioural difference.
        It is gone, and an unknown verb must fail loudly rather than guess.
        """
        result = _run_hook(PROJECT_STATE, stdin_data="", args=["get-model"])
        assert result.returncode != 0, "get-model should no longer be a valid verb"
        assert "Usage:" in result.stderr
        assert "get-model" not in result.stderr
