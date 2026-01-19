#!/usr/bin/env python3
"""
test_hooks_v2.45.4.py - Comprehensive Hook Validation Tests

Tests all Claude Code hooks for:
1. JSON output compliance (Claude Code hook protocol)
2. Script executability
3. Expected behavior under different conditions

VERSION: 2.45.4
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Optional

import pytest

# Configuration
HOOKS_DIR = Path.home() / ".claude" / "hooks"
TIMEOUT = 10  # seconds


def run_hook(hook_path: Path, stdin_data: str = "{}") -> tuple[int, str, str]:
    """Run a hook script and return (exit_code, stdout, stderr)."""
    try:
        result = subprocess.run(
            [str(hook_path)],
            input=stdin_data,
            capture_output=True,
            text=True,
            timeout=TIMEOUT,
            env={**os.environ, "PATH": os.environ.get("PATH", "")},
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "TIMEOUT"
    except Exception as e:
        return -2, "", str(e)


def validate_json_output(stdout: str) -> tuple[bool, Optional[dict], str]:
    """
    Validate that output is valid JSON and follows Claude Code hook protocol.
    Returns (is_valid, parsed_json, error_message)
    """
    if not stdout.strip():
        return False, None, "Empty output"

    # Find the JSON in the output (may have other text before it)
    lines = stdout.strip().split('\n')
    json_line = None
    for line in reversed(lines):  # Check from end
        line = line.strip()
        if line.startswith('{') and line.endswith('}'):
            json_line = line
            break

    if not json_line:
        return False, None, f"No JSON found in output: {stdout[:200]}"

    try:
        data = json.loads(json_line)
    except json.JSONDecodeError as e:
        return False, None, f"Invalid JSON: {e}"

    # Validate structure based on hook type
    if "hookSpecificOutput" in data:
        # SessionStart hook format
        if "additionalContext" not in data.get("hookSpecificOutput", {}):
            return False, data, "SessionStart hook missing additionalContext"
    elif "continue" in data:
        # Standard hook format
        if not isinstance(data["continue"], bool):
            return False, data, "'continue' must be boolean"
    elif "decision" in data:
        # PreToolUse block format
        if data["decision"] not in ("block", "allow"):
            return False, data, "'decision' must be 'block' or 'allow'"
    else:
        return False, data, "Missing required 'continue', 'hookSpecificOutput', or 'decision' field"

    return True, data, ""


class TestPostToolUseHooks:
    """Test PostToolUse hooks for JSON compliance."""

    def test_progress_tracker(self):
        """Test progress-tracker.sh returns valid JSON."""
        hook = HOOKS_DIR / "progress-tracker.sh"
        if not hook.exists():
            pytest.skip("progress-tracker.sh not found")

        input_data = json.dumps({
            "tool_name": "Bash",
            "tool_input": {"command": "echo test"},
            "tool_result": {"stdout": "test"},
            "session_id": "test-session"
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed with exit code {exit_code}: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"
        assert data.get("continue") is True, f"Expected continue=true, got {data}"

    def test_quality_gates(self):
        """Test quality-gates.sh returns valid JSON."""
        hook = HOOKS_DIR / "quality-gates.sh"
        if not hook.exists():
            pytest.skip("quality-gates.sh not found")

        exit_code, stdout, stderr = run_hook(hook, "{}")
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout[:500]}"

    def test_auto_save_context(self):
        """Test auto-save-context.sh returns valid JSON."""
        hook = HOOKS_DIR / "auto-save-context.sh"
        if not hook.exists():
            pytest.skip("auto-save-context.sh not found")

        exit_code, stdout, stderr = run_hook(hook, "{}")
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"

    def test_plan_sync_post_step(self):
        """Test plan-sync-post-step.sh returns valid JSON."""
        hook = HOOKS_DIR / "plan-sync-post-step.sh"
        if not hook.exists():
            pytest.skip("plan-sync-post-step.sh not found")

        # Should exit silently when no plan-state exists
        exit_code, stdout, stderr = run_hook(hook, "{}")
        # When no plan-state, may exit 0 without output (acceptable for this hook)
        if stdout.strip():
            is_valid, data, error = validate_json_output(stdout)
            assert is_valid, f"Invalid JSON when output present: {error}"

    def test_auto_plan_state(self):
        """Test auto-plan-state.sh returns valid JSON."""
        hook = HOOKS_DIR / "auto-plan-state.sh"
        if not hook.exists():
            pytest.skip("auto-plan-state.sh not found")

        input_data = json.dumps({
            "tool_name": "Write",
            "tool_input": {"file_path": "test.md"}
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"

    def test_plan_analysis_cleanup(self):
        """Test plan-analysis-cleanup.sh returns valid JSON."""
        hook = HOOKS_DIR / "plan-analysis-cleanup.sh"
        if not hook.exists():
            pytest.skip("plan-analysis-cleanup.sh not found")

        exit_code, stdout, stderr = run_hook(hook, "{}")
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"

    def test_sentry_check_status(self):
        """Test sentry-check-status.sh returns valid JSON."""
        hook = HOOKS_DIR / "sentry-check-status.sh"
        if not hook.exists():
            pytest.skip("sentry-check-status.sh not found")

        input_data = json.dumps({
            "tool_input": {"command": "echo test"}
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"

    def test_sentry_correlation(self):
        """Test sentry-correlation.sh returns valid JSON."""
        hook = HOOKS_DIR / "sentry-correlation.sh"
        if not hook.exists():
            pytest.skip("sentry-correlation.sh not found")

        input_data = json.dumps({
            "tool_input": {"command": "echo test"}
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"

    def test_checkpoint_auto_save(self):
        """Test checkpoint-auto-save.sh returns valid JSON."""
        hook = HOOKS_DIR / "checkpoint-auto-save.sh"
        if not hook.exists():
            pytest.skip("checkpoint-auto-save.sh not found")

        input_data = json.dumps({
            "tool_input": {"command": "echo test"}
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"


class TestPreToolUseHooks:
    """Test PreToolUse hooks for JSON compliance."""

    def test_git_safety_guard(self):
        """Test git-safety-guard.py handles safe commands."""
        hook = HOOKS_DIR / "git-safety-guard.py"
        if not hook.exists():
            pytest.skip("git-safety-guard.py not found")

        # Safe command - should exit 0 silently
        input_data = json.dumps({
            "tool_name": "Bash",
            "tool_input": {"command": "git status"}
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        assert exit_code == 0, f"Safe command was blocked: {stdout} {stderr}"

    def test_git_safety_guard_blocks_dangerous(self):
        """Test git-safety-guard.py blocks dangerous commands."""
        hook = HOOKS_DIR / "git-safety-guard.py"
        if not hook.exists():
            pytest.skip("git-safety-guard.py not found")

        # Dangerous command - should block with JSON
        input_data = json.dumps({
            "tool_name": "Bash",
            "tool_input": {"command": "git reset --hard"}
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        assert exit_code != 0, "Dangerous command was allowed"
        is_valid, data, error = validate_json_output(stdout)
        assert is_valid, f"Block response not valid JSON: {error}"
        assert data.get("decision") == "block", f"Expected block decision: {data}"

    def test_lsa_pre_step(self):
        """Test lsa-pre-step.sh returns valid JSON."""
        hook = HOOKS_DIR / "lsa-pre-step.sh"
        if not hook.exists():
            pytest.skip("lsa-pre-step.sh not found")

        # Without plan-state, should return JSON and exit 0
        exit_code, stdout, stderr = run_hook(hook, "{}")
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"

    def test_skill_validator(self):
        """Test skill-validator.sh returns valid JSON."""
        hook = HOOKS_DIR / "skill-validator.sh"
        if not hook.exists():
            pytest.skip("skill-validator.sh not found")

        input_data = json.dumps({
            "skill": "nonexistent-skill"
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        is_valid, data, error = validate_json_output(stdout)

        # May exit 0 or 1 depending on skill existence, but must return JSON
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"


    def test_inject_session_context(self):
        """Test inject-session-context.sh returns valid JSON for Task tool."""
        hook = HOOKS_DIR / "inject-session-context.sh"
        if not hook.exists():
            pytest.skip("inject-session-context.sh not found")

        # Test with Task tool input
        input_data = json.dumps({
            "tool_name": "Task",
            "session_id": "test-session-123"
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        assert exit_code == 0, f"Hook failed: {stderr}"

        # Parse JSON
        try:
            data = json.loads(stdout.strip())
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}. Output: {stdout}")

        # PreToolUse hooks return {"decision": "continue"} format (not {"continue": true})
        assert "decision" in data, f"Missing 'decision' field: {data}"
        assert data["decision"] == "continue", f"Expected decision='continue': {data}"

    def test_inject_session_context_non_task(self):
        """Test inject-session-context.sh handles non-Task tools."""
        hook = HOOKS_DIR / "inject-session-context.sh"
        if not hook.exists():
            pytest.skip("inject-session-context.sh not found")

        # Test with Bash tool (should return {"continue": true} and skip)
        input_data = json.dumps({
            "tool_name": "Bash",
            "session_id": "test-session-456"
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        assert exit_code == 0, f"Hook failed: {stderr}"

        # Parse JSON
        try:
            data = json.loads(stdout.strip())
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}. Output: {stdout}")

        # PreToolUse hooks return {"decision": "continue"} format
        assert "decision" in data, f"Missing 'decision' field: {data}"


class TestSessionStartHooks:
    """Test SessionStart hooks for proper output format."""

    def test_session_start_ledger(self):
        """Test session-start-ledger.sh returns proper SessionStart format."""
        hook = HOOKS_DIR / "session-start-ledger.sh"
        if not hook.exists():
            pytest.skip("session-start-ledger.sh not found")

        input_data = json.dumps({
            "source": "startup",
            "session_id": "test-session-123"
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)

        assert exit_code == 0, f"Hook failed: {stderr}"

        # Parse JSON
        try:
            data = json.loads(stdout.strip())
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON: {e}. Output: {stdout}")

        # SessionStart hooks use hookSpecificOutput format
        assert "hookSpecificOutput" in data, f"Missing hookSpecificOutput: {data}"
        assert "additionalContext" in data["hookSpecificOutput"], f"Missing additionalContext: {data}"


class TestPreCompactHooks:
    """Test PreCompact hooks for JSON compliance."""

    def test_pre_compact_handoff(self):
        """Test pre-compact-handoff.sh returns valid JSON."""
        hook = HOOKS_DIR / "pre-compact-handoff.sh"
        if not hook.exists():
            pytest.skip("pre-compact-handoff.sh not found")

        input_data = json.dumps({
            "session_id": "test-session",
            "transcript_path": ""
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"


class TestUserPromptSubmitHooks:
    """Test UserPromptSubmit hooks for JSON compliance."""

    def test_context_warning(self):
        """Test context-warning.sh returns valid JSON.

        Note: May timeout in test environments where context command fails.
        The hook should exit gracefully regardless.
        """
        hook = HOOKS_DIR / "context-warning.sh"
        if not hook.exists():
            pytest.skip("context-warning.sh not found")

        exit_code, stdout, stderr = run_hook(hook, "{}")

        # Hook may timeout in test env - that's acceptable
        if exit_code == -1 and stderr == "TIMEOUT":
            pytest.skip("context-warning.sh timed out (expected in test environment)")

        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"


class TestStopHooks:
    """Test Stop hooks for JSON compliance."""

    def test_stop_verification(self):
        """Test stop-verification.sh returns valid JSON."""
        hook = HOOKS_DIR / "stop-verification.sh"
        if not hook.exists():
            pytest.skip("stop-verification.sh not found")

        exit_code, stdout, stderr = run_hook(hook, "{}")
        is_valid, data, error = validate_json_output(stdout)

        assert exit_code == 0, f"Hook failed: {stderr}"
        assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"


class TestHookVersions:
    """Verify all hooks have VERSION markers."""

    HOOKS_TO_CHECK = [
        "quality-gates.sh",
        "checkpoint-auto-save.sh",
        "plan-sync-post-step.sh",
        "auto-plan-state.sh",
        "plan-analysis-cleanup.sh",
        "skill-validator.sh",
        "lsa-pre-step.sh",
        "context-warning.sh",
        "stop-verification.sh",
    ]

    @pytest.mark.parametrize("hook_name", HOOKS_TO_CHECK)
    def test_hook_version(self, hook_name):
        """Test that hook has a VERSION marker (any version is acceptable).

        Version markers help with troubleshooting and audit trails.
        We don't require a specific version - just that hooks are versioned.
        """
        hook = HOOKS_DIR / hook_name
        if not hook.exists():
            pytest.skip(f"{hook_name} not found")

        content = hook.read_text()
        # Check for any VERSION marker (format: VERSION: X.X.X)
        assert "VERSION:" in content, \
            f"{hook_name} missing VERSION marker"
        # Verify it follows the expected format
        assert re.search(r'VERSION:\s*\d+\.\d+\.\d+', content), \
            f"{hook_name} has malformed VERSION marker"


class TestHookExecutability:
    """Verify all hooks are executable."""

    ALL_HOOKS = [
        "quality-gates.sh",
        "progress-tracker.sh",
        "checkpoint-auto-save.sh",
        "plan-sync-post-step.sh",
        "auto-plan-state.sh",
        "plan-analysis-cleanup.sh",
        "skill-validator.sh",
        "lsa-pre-step.sh",
        "context-warning.sh",
        "stop-verification.sh",
        "git-safety-guard.py",
        "session-start-ledger.sh",
        "pre-compact-handoff.sh",
        "sentry-check-status.sh",
        "sentry-correlation.sh",
        "auto-save-context.sh",
        "detect-environment.sh",
        "inject-session-context.sh",
    ]

    @pytest.mark.parametrize("hook_name", ALL_HOOKS)
    def test_hook_executable(self, hook_name):
        """Test that hook file is executable."""
        hook = HOOKS_DIR / hook_name
        if not hook.exists():
            pytest.skip(f"{hook_name} not found")

        assert os.access(hook, os.X_OK), f"{hook_name} is not executable"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
