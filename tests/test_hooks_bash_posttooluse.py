#!/usr/bin/env python3
"""
Unit tests for PostToolUse:Bash hooks
Tests: progress-tracker.sh, status-auto-check.sh, auto-save-context.sh

These hooks trigger after every Bash command and MUST output valid JSON.
Per official Claude Code documentation, the correct format is:
    {"continue": true, "suppressOutput": false, "systemMessage": "..."}

NOT {"decision": "continue"} which is ONLY for Stop hooks.
"""
import json
import subprocess
import pytest
import os
from pathlib import Path


GLOBAL_HOOKS_DIR = Path.home() / ".claude" / "hooks"
LOCAL_HOOKS_DIR = Path(__file__).parent.parent / ".claude" / "hooks"

BASH_POSTTOOLUSE_HOOKS = [
    "progress-tracker.sh",
    "status-auto-check.sh",
    "auto-save-context.sh",
]


def get_hook_path(hook_name: str) -> Path:
    """Get hook path, preferring global over local."""
    global_path = GLOBAL_HOOKS_DIR / hook_name
    local_path = LOCAL_HOOKS_DIR / hook_name
    if global_path.exists():
        return global_path
    elif local_path.exists():
        return local_path
    pytest.skip(f"Hook not found: {hook_name}")


def run_hook(hook_path: Path, input_data: dict, timeout: int = 10) -> tuple[str, int]:
    """Run a hook with given input and return output and exit code."""
    try:
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=json.dumps(input_data),
            capture_output=True,
            text=True,
            timeout=timeout,
            env={**os.environ, "HOME": str(Path.home())},
            cwd=str(Path(__file__).parent.parent),
        )
        return result.stdout.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", 124


# Test input payloads
BASH_TOOL_INPUT = {
    "tool_name": "Bash",
    "tool_input": {"command": "echo 'hello world'"},
    "tool_result": "hello world",
    "session_id": "test-session-001",
}

BASH_ERROR_INPUT = {
    "tool_name": "Bash",
    "tool_input": {"command": "cat nonexistent.txt"},
    "tool_result": "cat: nonexistent.txt: No such file or directory\nError: command failed",
    "session_id": "test-session-001",
}

NON_BASH_INPUT = {
    "tool_name": "Read",
    "tool_input": {"file_path": "/tmp/test.txt"},
    "tool_result": "file contents",
    "session_id": "test-session-001",
}

EMPTY_INPUT = {}

MALFORMED_INPUT = {"tool_name": 123, "tool_input": "not-an-object"}


class TestPostToolUseBashHooksJsonValidity:
    """Test that all PostToolUse:Bash hooks output valid JSON."""

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_valid_json_on_bash_input(self, hook_name):
        """Hook must output valid JSON when processing Bash tool."""
        hook_path = get_hook_path(hook_name)
        output, _ = run_hook(hook_path, BASH_TOOL_INPUT)

        assert output, f"{hook_name} produced no output"
        try:
            parsed = json.loads(output.split('\n')[-1])  # Take last line (may have logs)
            assert isinstance(parsed, dict), f"{hook_name} did not output a JSON object"
        except json.JSONDecodeError as e:
            pytest.fail(f"{hook_name} produced invalid JSON: {output[:200]}\nError: {e}")

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_valid_json_on_error_result(self, hook_name):
        """Hook must output valid JSON even when bash command has errors."""
        hook_path = get_hook_path(hook_name)
        output, _ = run_hook(hook_path, BASH_ERROR_INPUT)

        assert output, f"{hook_name} produced no output on error input"
        try:
            parsed = json.loads(output.split('\n')[-1])
            assert isinstance(parsed, dict)
        except json.JSONDecodeError:
            pytest.fail(f"{hook_name} produced invalid JSON on error: {output[:200]}")

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_valid_json_on_non_bash_tool(self, hook_name):
        """Hook must output valid JSON for non-Bash tools (early exit path)."""
        hook_path = get_hook_path(hook_name)
        output, _ = run_hook(hook_path, NON_BASH_INPUT)

        if output:  # Some hooks may not output for non-matching tools
            try:
                parsed = json.loads(output.split('\n')[-1])
                assert isinstance(parsed, dict)
            except json.JSONDecodeError:
                pytest.fail(f"{hook_name} produced invalid JSON for non-Bash: {output[:200]}")

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_valid_json_on_empty_input(self, hook_name):
        """Hook must handle empty input gracefully with valid JSON."""
        hook_path = get_hook_path(hook_name)
        output, _ = run_hook(hook_path, EMPTY_INPUT)

        if output:
            try:
                parsed = json.loads(output.split('\n')[-1])
                assert isinstance(parsed, dict)
            except json.JSONDecodeError:
                pytest.fail(f"{hook_name} failed on empty input: {output[:200]}")

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_valid_json_on_malformed_input(self, hook_name):
        """Hook must handle malformed input gracefully."""
        hook_path = get_hook_path(hook_name)
        output, _ = run_hook(hook_path, MALFORMED_INPUT)

        if output:
            try:
                parsed = json.loads(output.split('\n')[-1])
                assert isinstance(parsed, dict)
            except json.JSONDecodeError:
                pytest.fail(f"{hook_name} failed on malformed input: {output[:200]}")


class TestPostToolUseBashHooksFormat:
    """Test that hooks use correct JSON format: {"continue": true} NOT {"decision": "continue"}."""

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_uses_continue_boolean_not_decision(self, hook_name):
        """Hook must use 'continue' boolean key, NOT 'decision' key.

        Per official Claude Code documentation:
        - PostToolUse: {"continue": true, ...}
        - Stop: {"decision": "approve|block", ...}
        """
        hook_path = get_hook_path(hook_name)
        output, _ = run_hook(hook_path, BASH_TOOL_INPUT)

        if output:
            parsed = json.loads(output.split('\n')[-1])
            # PostToolUse hooks MUST use "continue" boolean, NOT "decision"
            assert "decision" not in parsed, \
                f"{hook_name} uses wrong format 'decision' - should use 'continue' boolean"
            # Should have continue key with boolean value
            if "continue" in parsed:
                assert parsed["continue"] is True, \
                    f"{hook_name} has wrong continue value: {parsed['continue']} (should be true)"

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_optional_system_message(self, hook_name):
        """If hook has systemMessage, it must be a string."""
        hook_path = get_hook_path(hook_name)
        output, _ = run_hook(hook_path, BASH_TOOL_INPUT)

        if output:
            parsed = json.loads(output.split('\n')[-1])
            if "systemMessage" in parsed:
                assert isinstance(parsed["systemMessage"], str), \
                    f"{hook_name} systemMessage is not a string"


class TestPostToolUseBashHooksTimeout:
    """Test that hooks complete within reasonable time."""

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_completes_under_5_seconds(self, hook_name):
        """Hook must complete within 5 seconds."""
        hook_path = get_hook_path(hook_name)
        _, exit_code = run_hook(hook_path, BASH_TOOL_INPUT, timeout=5)

        assert exit_code != 124, f"{hook_name} timed out (>5s)"

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_handles_large_result(self, hook_name):
        """Hook must handle large tool results efficiently."""
        large_input = {
            **BASH_TOOL_INPUT,
            "tool_result": "x" * 100000,  # 100KB result
        }
        hook_path = get_hook_path(hook_name)
        output, exit_code = run_hook(hook_path, large_input, timeout=10)

        assert exit_code != 124, f"{hook_name} timed out on large input"
        if output:
            parsed = json.loads(output.split('\n')[-1])
            assert isinstance(parsed, dict)


class TestPostToolUseBashHooksExitCodes:
    """Test hook exit codes."""

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_exits_zero_on_success(self, hook_name):
        """Hook must exit with code 0 on normal execution."""
        hook_path = get_hook_path(hook_name)
        _, exit_code = run_hook(hook_path, BASH_TOOL_INPUT)

        assert exit_code == 0, f"{hook_name} exited with code {exit_code}"


class TestProgressTrackerSpecific:
    """Specific tests for progress-tracker.sh."""

    def test_tracks_edit_write_bash_only(self):
        """Progress tracker should only track Edit, Write, Bash tools."""
        hook_path = get_hook_path("progress-tracker.sh")

        # Bash should be tracked (produces JSON)
        output, _ = run_hook(hook_path, BASH_TOOL_INPUT)
        assert output
        parsed = json.loads(output.split('\n')[-1])
        assert "continue" in parsed  # Uses correct format

        # Read should not be tracked (early exit with JSON)
        output, _ = run_hook(hook_path, NON_BASH_INPUT)
        assert output
        parsed = json.loads(output.split('\n')[-1])
        assert "continue" in parsed  # Uses correct format


class TestStatusAutoCheckSpecific:
    """Specific tests for status-auto-check.sh."""

    def test_respects_disable_env_var(self):
        """Status check should be disabled when env var is false."""
        hook_path = get_hook_path("status-auto-check.sh")

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=json.dumps(BASH_TOOL_INPUT),
            capture_output=True,
            text=True,
            timeout=10,
            env={**os.environ, "RALPH_STATUS_AUTO_CHECK": "false"},
            cwd=str(Path(__file__).parent.parent),
        )

        assert result.stdout.strip()
        parsed = json.loads(result.stdout.strip().split('\n')[-1])
        # Uses correct format: {"continue": true} NOT {"decision": "continue"}
        assert parsed.get("continue") is True


class TestAutoSaveContextSpecific:
    """Specific tests for auto-save-context.sh."""

    def test_outputs_json_not_text(self):
        """Auto-save must output JSON, not plain text."""
        hook_path = get_hook_path("auto-save-context.sh")
        output, _ = run_hook(hook_path, BASH_TOOL_INPUT)

        # Should not start with "AUTO_SAVE:" (old format)
        assert not output.startswith("AUTO_SAVE:"), \
            f"auto-save-context.sh still outputs plain text: {output[:100]}"

        # Should be valid JSON with correct format
        parsed = json.loads(output.split('\n')[-1])
        assert "continue" in parsed  # Uses correct format


class TestVersionHeaders:
    """Test that hooks have correct version headers."""

    @pytest.mark.parametrize("hook_name", BASH_POSTTOOLUSE_HOOKS)
    def test_has_version_header(self, hook_name):
        """Hook should have VERSION comment."""
        hook_path = get_hook_path(hook_name)
        content = hook_path.read_text()

        assert "VERSION:" in content, f"{hook_name} missing VERSION header"

    @pytest.mark.parametrize("hook_name", ["status-auto-check.sh", "auto-save-context.sh"])
    def test_has_security_fix_marker(self, hook_name):
        """Fixed hooks should have SEC- marker."""
        hook_path = get_hook_path(hook_name)
        content = hook_path.read_text()

        assert "SEC-" in content, f"{hook_name} missing SEC- security fix marker"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
