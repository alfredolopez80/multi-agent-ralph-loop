"""
Tests for the 3 v3.0 hooks:
  1. session-accumulator.sh  (PostToolUse Edit|Write)
  2. vault-graduation.sh     (SessionStart)
  3. project-state.sh        (SessionStart)

~30 tests covering structure, safety properties, and functional behavior.
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
SESSION_ACCUMULATOR = HOOKS_DIR / "session-accumulator.sh"
VAULT_GRADUATION = HOOKS_DIR / "vault-graduation.sh"
PROJECT_STATE = HOOKS_DIR / "project-state.sh"

ALL_HOOKS = [SESSION_ACCUMULATOR, VAULT_GRADUATION, PROJECT_STATE]
HOOK_IDS = ["session-accumulator", "vault-graduation", "project-state"]


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

    @pytest.mark.parametrize(
        "hook,expected_key",
        [
            (SESSION_ACCUMULATOR, "continue"),
            (VAULT_GRADUATION, "hookSpecificOutput"),
        ],
        ids=["session-accumulator", "vault-graduation"],
    )
    def test_trap_produces_valid_json(self, hook, expected_key):
        """Verify the trap string itself is parseable JSON containing the expected key."""
        text = _read_hook(hook)
        # Extract the trap argument (single-quoted string after trap)
        for line in text.splitlines():
            stripped = line.strip()
            if stripped.startswith("trap ") and "ERR" in stripped:
                # Pull the single-quoted payload: trap '...' ERR INT TERM
                start = stripped.index("'") + 1
                end = stripped.index("'", start)
                trap_payload = stripped[start:end]
                # The payload is: echo "{\"continue\": true}"
                # Strip the 'echo ' prefix and outer double quotes to get the JSON
                trap_payload = trap_payload.strip()
                if trap_payload.startswith("echo "):
                    trap_payload = trap_payload[len("echo "):]
                trap_payload = trap_payload.strip().strip('"')
                # Unescape \" -> "
                trap_json_str = trap_payload.replace('\\"', '"')
                parsed = json.loads(trap_json_str)
                assert expected_key in parsed, (
                    f"Trap JSON missing '{expected_key}': {parsed}"
                )
                return
        pytest.fail(f"Could not extract trap string from {hook.name}")


# ===========================================================================
# session-accumulator.sh  (PostToolUse)
# ===========================================================================

class TestSessionAccumulator:
    """Functional tests for session-accumulator.sh."""

    def test_valid_edit_input_returns_continue(self):
        """Feed valid PostToolUse JSON for an Edit tool call."""
        payload = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": "src/main.ts"},
        })
        result = _run_hook(SESSION_ACCUMULATOR, stdin_data=payload)
        assert result.returncode == 0
        output = _parse_json_output(result)
        assert output.get("continue") is True

    def test_valid_write_input_returns_continue(self):
        """Feed valid PostToolUse JSON for a Write tool call."""
        payload = json.dumps({
            "tool_name": "Write",
            "tool_input": {"file_path": "scripts/deploy.sh"},
        })
        result = _run_hook(SESSION_ACCUMULATOR, stdin_data=payload)
        assert result.returncode == 0
        output = _parse_json_output(result)
        assert output.get("continue") is True

    def test_empty_input_returns_continue(self):
        """Empty stdin must not crash; should return continue."""
        result = _run_hook(SESSION_ACCUMULATOR, stdin_data="")
        # Even if jq fails on empty, the trap should emit valid JSON
        output = _parse_json_output(result)
        assert output.get("continue") is True

    def test_missing_file_path_returns_continue(self):
        """If file_path is absent, the hook should exit early with continue."""
        payload = json.dumps({"tool_name": "Edit", "tool_input": {}})
        result = _run_hook(SESSION_ACCUMULATOR, stdin_data=payload)
        output = _parse_json_output(result)
        assert output.get("continue") is True

    def test_categorizes_ts_as_typescript(self):
        """A .ts file should be categorized as 'typescript'."""
        text = _read_hook(SESSION_ACCUMULATOR)
        # Verify the case statement maps ts -> typescript
        assert 'ts|tsx|js|jsx) CATEGORY="typescript"' in text

    def test_categorizes_py_as_python(self):
        """A .py file should be categorized as 'python'."""
        text = _read_hook(SESSION_ACCUMULATOR)
        assert 'py) CATEGORY="python"' in text

    def test_categorizes_sh_as_hooks(self):
        """A .sh file should be categorized as 'hooks'."""
        text = _read_hook(SESSION_ACCUMULATOR)
        assert 'sh|bash) CATEGORY="hooks"' in text

    def test_categorizes_md_as_documentation(self):
        """A .md file should be categorized as 'documentation'."""
        text = _read_hook(SESSION_ACCUMULATOR)
        assert 'md) CATEGORY="documentation"' in text

    def test_categorizes_json_as_configuration(self):
        """A .json file should be categorized as 'configuration'."""
        text = _read_hook(SESSION_ACCUMULATOR)
        assert 'json) CATEGORY="configuration"' in text

    def test_output_is_valid_json(self):
        """Any invocation should produce parseable JSON on stdout."""
        payload = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": "lib/utils.py"},
        })
        result = _run_hook(SESSION_ACCUMULATOR, stdin_data=payload)
        output = _parse_json_output(result)
        assert isinstance(output, dict)


# ===========================================================================
# vault-graduation.sh  (SessionStart)
# ===========================================================================

class TestVaultGraduation:
    """Functional tests for vault-graduation.sh."""

    def test_session_start_returns_valid_json(self):
        """Feed SessionStart JSON and verify output is valid JSON."""
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(VAULT_GRADUATION, stdin_data=payload)
        assert result.returncode == 0
        output = _parse_json_output(result)
        assert isinstance(output, dict)

    def test_output_has_hook_specific_output(self):
        """Output must contain hookSpecificOutput for SessionStart."""
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(VAULT_GRADUATION, stdin_data=payload)
        output = _parse_json_output(result)
        assert "hookSpecificOutput" in output, f"Missing hookSpecificOutput: {output}"

    def test_output_mentions_vault_graduation(self):
        """The additionalContext should reference vault-graduation."""
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(VAULT_GRADUATION, stdin_data=payload)
        output = _parse_json_output(result)
        additional = output.get("hookSpecificOutput", {}).get("additionalContext", "")
        assert "vault-graduation" in additional, (
            f"additionalContext does not mention vault-graduation: '{additional}'"
        )

    def test_no_vault_skips_gracefully(self):
        """When VAULT_DIR points to non-existent dir, hook skips without error."""
        env = {"VAULT_DIR": "/tmp/nonexistent_vault_dir_test"}
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(VAULT_GRADUATION, stdin_data=payload, env_override=env)
        assert result.returncode == 0
        output = _parse_json_output(result)
        additional = output.get("hookSpecificOutput", {}).get("additionalContext", "")
        assert "no vault found" in additional or "vault-graduation" in additional

    def test_empty_input_returns_json(self):
        """Empty stdin should not crash the hook."""
        result = _run_hook(VAULT_GRADUATION, stdin_data="")
        output = _parse_json_output(result)
        assert isinstance(output, dict)


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

    def test_output_contains_context_model(self):
        """hookSpecificOutput should include context.model."""
        payload = json.dumps({"hookEventName": "SessionStart"})
        result = _run_hook(PROJECT_STATE, stdin_data=payload)
        output = _parse_json_output(result)
        ctx = output.get("hookSpecificOutput", {}).get("context", {})
        assert "model" in ctx, f"Missing 'model' in context: {ctx}"

    def test_validate_skills_subcommand(self):
        """Running with 'validate-skills' arg should return JSON with status field."""
        result = _run_hook(PROJECT_STATE, stdin_data="", args=["validate-skills"])
        assert result.returncode == 0
        output = _parse_json_output(result)
        assert "status" in output, f"validate-skills missing 'status': {output}"

    def test_get_dir_subcommand(self):
        """Running with 'get-dir' arg should return a directory path."""
        result = _run_hook(PROJECT_STATE, stdin_data="", args=["get-dir"])
        assert result.returncode == 0
        dir_path = result.stdout.strip()
        assert len(dir_path) > 0, "get-dir returned empty string"

    def test_get_model_subcommand(self):
        """Running with 'get-model' should return 'claude' or 'glm'."""
        result = _run_hook(PROJECT_STATE, stdin_data="", args=["get-model"])
        assert result.returncode == 0
        model = result.stdout.strip()
        assert model in ("claude", "glm", "unknown"), f"Unexpected model: '{model}'"
