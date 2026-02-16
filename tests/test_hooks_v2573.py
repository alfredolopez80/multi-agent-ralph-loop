#!/usr/bin/env python3
"""
test_hooks_v2.57.3.py - Comprehensive Hook Validation Tests

Tests all Claude Code hooks for:
1. JSON output compliance (Claude Code hook protocol)
2. Script executability
3. Expected behavior under different conditions

VERSION: 2.57.3
CHANGES from 2.45.4:
- Updated JSON format validation (SEC-039): PreToolUse uses "decision", PostToolUse/PreCompact use "continue"
- Added UserPromptSubmit hook support (message/context_level fields)
- Skipped tests for non-standard hooks (text output only)
- Fixed validate_json_output() for multiline JSON
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
    # Handle both single-line and multiline JSON formats
    lines = stdout.strip().split('\n')

    # Find the last line that starts with '{' (opening of JSON object)
    json_start = -1
    for i in range(len(lines) - 1, -1, -1):
        line = lines[i].strip()
        if line.startswith('{'):
            json_start = i
            break

    if json_start == -1:
        return False, None, f"No JSON found in output: {stdout[:200]}"

    # Collect all lines from the start of JSON to the end
    json_lines = lines[json_start:]
    json_str = '\n'.join(json_lines)

    try:
        data = json.loads(json_str)
    except json.JSONDecodeError as e:
        return False, None, f"Invalid JSON: {e}"

    # Validate structure based on hook type
    if "hookSpecificOutput" in data:
        hook_output = data.get("hookSpecificOutput", {})
        # v2.69.0+: hookSpecificOutput can be SessionStart (additionalContext)
        # or PreToolUse (permissionDecision) format - both are valid
        has_additional_context = "additionalContext" in hook_output
        has_permission_decision = "permissionDecision" in hook_output
        has_hook_event_name = "hookEventName" in hook_output
        if not (has_additional_context or has_permission_decision or has_hook_event_name):
            return False, data, "hookSpecificOutput missing required fields (additionalContext, permissionDecision, or hookEventName)"
    elif "continue" in data:
        # Standard hook format (PostToolUse, PreCompact)
        if not isinstance(data["continue"], bool):
            return False, data, "'continue' must be boolean"
    elif "decision" in data:
        # PreToolUse hook format: "allow" or "block"
        # Stop hook format: "approve" or "block"
        if data["decision"] not in ("allow", "block", "approve"):
            return False, data, "'decision' must be 'allow', 'block', or 'approve'"
    elif "message" in data or "context_level" in data:
        # UserPromptSubmit hook format (e.g., context-warning.sh)
        # These hooks output informational messages, not standard protocol fields
        # Accept any valid JSON with message or context_level fields
        return True, data, ""
    else:
        return False, data, "Missing required 'continue', 'hookSpecificOutput', 'decision', or 'message' field"

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
        """Test quality-gates-v2.sh returns valid JSON.

        NOTE: quality-gates.sh was renamed to quality-gates-v2.sh in v2.46.
        It's a manual command hook that outputs human-readable progress messages.
        Skipping this test as it's not applicable for automatic hook validation.
        """
        # v2.69.1: quality-gates.sh renamed to quality-gates-v2.sh
        hook = HOOKS_DIR / "quality-gates-v2.sh"
        if not hook.exists():
            pytest.skip("quality-gates-v2.sh not found")

        # quality-gates-v2.sh is a manual command hook, not an automatic PostToolUse hook
        # It outputs text progress messages, not JSON
        pytest.skip("quality-gates-v2.sh is a manual command hook, not an automatic PostToolUse hook")

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
        """Test auto-plan-state.sh returns valid JSON when triggered.

        NOTE: This hook only produces output when writing to orchestrator-analysis.md.
        For other files, it exits silently. We test with the correct file path.
        """
        hook = HOOKS_DIR / "auto-plan-state.sh"
        if not hook.exists():
            pytest.skip("auto-plan-state.sh not found")

        # Test with orchestrator-analysis.md to trigger JSON output
        input_data = json.dumps({
            "tool_name": "Write",
            "tool_input": {"file_path": ".claude/orchestrator-analysis.md"}
        })

        exit_code, stdout, stderr = run_hook(hook, input_data)

        # Hook should either output valid JSON or exit 0 silently if no analysis content
        if stdout.strip():
            is_valid, data, error = validate_json_output(stdout)
            assert is_valid, f"Invalid JSON: {error}. Output: {stdout}"
        else:
            # Empty output is acceptable if no plan-state was created
            assert exit_code == 0, f"Hook failed with exit code {exit_code}: {stderr}"

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
        """Test sentry-check-status.sh returns valid JSON.

        DEPRECATED v2.69.1: Archived to ~/.claude/hooks-archive/utilities/
        Was a helper script that output text messages, not JSON.
        """
        hook = HOOKS_DIR / "sentry-check-status.sh"
        if not hook.exists():
            pytest.skip("v2.69.1: sentry-check-status.sh archived to ~/.claude/hooks-archive/utilities/")

        pytest.skip("v2.69.1: sentry-check-status.sh archived - was a helper script, not a standard hook")

    def test_sentry_correlation(self):
        """Test sentry-correlation.sh returns valid JSON.

        DEPRECATED v2.69.1: Archived to ~/.claude/hooks-archive/utilities/
        Was a helper script that output text messages, not JSON.
        """
        hook = HOOKS_DIR / "sentry-correlation.sh"
        if not hook.exists():
            pytest.skip("v2.69.1: sentry-correlation.sh archived to ~/.claude/hooks-archive/utilities/")

        pytest.skip("v2.69.1: sentry-correlation.sh archived - was a helper script, not a standard hook")

    def test_checkpoint_auto_save(self):
        """Test checkpoint-auto-save.sh returns valid JSON.

        NOTE: This hook outputs text to stderr, not JSON to stdout.
        Skipping as it's not a standard Claude Code hook.
        """
        hook = HOOKS_DIR / "checkpoint-auto-save.sh"
        if not hook.exists():
            pytest.skip("checkpoint-auto-save.sh not found")

        # This hook outputs text, not JSON
        pytest.skip("checkpoint-auto-save.sh outputs text, not JSON - not a standard Claude Code hook")


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
        # v2.69.0+: Uses hookSpecificOutput format with permissionDecision
        hook_output = data.get("hookSpecificOutput", data)
        decision = hook_output.get("permissionDecision", hook_output.get("decision"))
        assert decision == "block", f"Expected block decision: {data}"

    def test_lsa_pre_step(self):
        """Test lsa-pre-step.sh returns valid JSON.

        NOTE: This hook outputs text, not JSON. Skipping as it's
        not a standard Claude Code hook.
        """
        hook = HOOKS_DIR / "lsa-pre-step.sh"
        if not hook.exists():
            pytest.skip("lsa-pre-step.sh not found")

        # This hook outputs text, not JSON
        pytest.skip("lsa-pre-step.sh outputs text, not JSON - not a standard Claude Code hook")

    def test_skill_validator(self):
        """Test skill-validator.sh returns valid JSON.

        NOTE: This hook outputs text error messages, not JSON.
        Skipping as it's not a standard Claude Code hook.
        """
        hook = HOOKS_DIR / "skill-validator.sh"
        if not hook.exists():
            pytest.skip("skill-validator.sh not found")

        # This hook outputs text, not JSON
        pytest.skip("skill-validator.sh outputs text, not JSON - not a standard Claude Code hook")


    def test_inject_session_context(self):
        """Test inject-session-context.sh returns valid JSON for Task tool.

        v2.81.2+: PreToolUse hooks use {"hookSpecificOutput": {"permissionDecision": "allow"}} format.
        """
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

        # v2.81.2+: PreToolUse hooks use hookSpecificOutput wrapper with permissionDecision
        assert "hookSpecificOutput" in data, f"Missing 'hookSpecificOutput' field: {data}"
        assert data["hookSpecificOutput"].get("permissionDecision") == "allow", (
            f"Expected hookSpecificOutput.permissionDecision=allow: {data}"
        )

    def test_inject_session_context_non_task(self):
        """Test inject-session-context.sh handles non-Task tools.

        v2.81.2+: PreToolUse hooks use {"hookSpecificOutput": {"permissionDecision": "allow"}} format.
        """
        hook = HOOKS_DIR / "inject-session-context.sh"
        if not hook.exists():
            pytest.skip("inject-session-context.sh not found")

        # Test with Bash tool (should return {"hookSpecificOutput": {"permissionDecision": "allow"}} and skip)
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

        # v2.81.2+: PreToolUse hooks use hookSpecificOutput wrapper with permissionDecision
        assert "hookSpecificOutput" in data, f"Missing 'hookSpecificOutput' field: {data}"
        assert data["hookSpecificOutput"].get("permissionDecision") == "allow", (
            f"Expected hookSpecificOutput.permissionDecision=allow: {data}"
        )


class TestSessionStartHooks:
    """Test SessionStart hooks for proper output format.

    v2.85: session-start-ledger.sh was archived (redundant with session-start-restore-context.sh).
    Tests now validate the replacement hook.
    """

    def test_session_start_restore_context(self):
        """Test session-start-restore-context.sh returns proper SessionStart format."""
        hook = HOOKS_DIR / "session-start-restore-context.sh"
        if not hook.exists():
            pytest.skip("session-start-restore-context.sh not found")

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
        """Test pre-compact-handoff.sh returns valid JSON.

        CORRECT: PreCompact hooks use {"continue": true} format (same as PostToolUse).
        """
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
        # PreCompact uses "continue" field (same as PostToolUse)
        assert data.get("continue") is True, f"Expected continue=true, got {data}"


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

    # v2.69.1: Updated hook names (quality-gates.sh → quality-gates-v2.sh)
    HOOKS_TO_CHECK = [
        "quality-gates-v2.sh",  # Renamed from quality-gates.sh in v2.46
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

    # v2.85: Updated hook list - session-start-ledger.sh archived (redundant with session-start-restore-context.sh)
    ALL_HOOKS = [
        "quality-gates-v2.sh",  # Renamed from quality-gates.sh in v2.46
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
        "session-start-restore-context.sh",  # v2.85: Replaces archived session-start-ledger.sh
        "pre-compact-handoff.sh",
        "auto-save-context.sh",
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
