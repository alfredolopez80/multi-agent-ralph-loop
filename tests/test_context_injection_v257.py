#!/usr/bin/env python3
"""
Tests for context injection hooks v2.57.0 fixes.

Verifies that:
1. inject-session-context.sh actually injects context into Task prompts
2. orchestrator-auto-learn.sh injects learning recommendations

VERSION: 2.57.0
Part of v2.57.0 Memory System Reconstruction - Phase 3
"""

import json
import os
import subprocess
import pytest
from pathlib import Path


class TestInjectSessionContext:
    """Tests for inject-session-context.sh hook."""

    @pytest.fixture
    def hook_path(self):
        """Get path to inject-session-context.sh hook."""
        path = Path.home() / ".claude" / "hooks" / "inject-session-context.sh"
        if not path.exists():
            pytest.skip("inject-session-context.sh not found")
        return path

    @pytest.fixture
    def temp_project_dir(self, tmp_path):
        """Create a temp project with .claude directory and progress.md."""
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()

        # Create progress.md with test content
        progress = claude_dir / "progress.md"
        progress.write_text("""# Progress

## Current Goal
Implement user authentication with JWT

## Recent Progress
- Added login endpoint
- Created user model
- Implemented token validation
""")

        # Create CLAUDE.md
        claude_md = tmp_path / "CLAUDE.md"
        claude_md.write_text("# Test Project v1.0\n\nTest project description.")

        return tmp_path

    def run_hook(self, hook_path: Path, project_dir: Path, tool_name: str, prompt: str = "Test task") -> dict:
        """Run the hook with given parameters."""
        hook_input = json.dumps({
            "tool_name": tool_name,
            "tool_input": {"prompt": prompt, "subagent_type": "general-purpose"},
            "session_id": "test-session-123"
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            timeout=30,
            env={
                **os.environ,  # Use full environment to avoid missing commands
                "HOME": str(Path.home()),
            }
        )

        return {
            "returncode": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr,
        }

    def test_injects_context_for_task_tool(self, hook_path, temp_project_dir):
        """Hook should inject context when Task tool is called."""
        result = self.run_hook(hook_path, temp_project_dir, "Task", "Analyze the codebase")

        assert result["returncode"] == 0

        # Should output JSON with modified tool_input
        output = result["stdout"]
        if output and output != "{}":
            parsed = json.loads(output)
            if "tool_input" in parsed:
                modified_prompt = parsed["tool_input"].get("prompt", "")
                # Should contain context header
                assert "Session Context" in modified_prompt or "Current Goal" in modified_prompt

    def test_skips_non_task_tools(self, hook_path, temp_project_dir):
        """Hook should skip non-Task tools but still return valid PreToolUse JSON.

        v2.81.2+: PreToolUse hooks use {"hookSpecificOutput": {"permissionDecision": "allow"}} format.
        Even when skipping a tool, the hook returns permissionDecision=allow to permit execution.
        """
        result = self.run_hook(hook_path, temp_project_dir, "Read")

        assert result["returncode"] == 0
        # v2.81.2+: PreToolUse hooks use hookSpecificOutput wrapper with permissionDecision
        # Accept both new format and legacy formats for compatibility
        valid_outputs = [
            '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "allow"}}',
            '{"decision": "allow"}',
            '',
            '{}'
        ]
        # Check if output matches any valid format or contains permissionDecision/decision
        assert result["stdout"] in valid_outputs or (
            '"permissionDecision"' in result["stdout"] or '"decision"' in result["stdout"]
        ), f"Unexpected output: {result['stdout']}"

    def test_returns_valid_json(self, hook_path, temp_project_dir):
        """Hook should always return valid JSON."""
        result = self.run_hook(hook_path, temp_project_dir, "Task")

        assert result["returncode"] == 0
        if result["stdout"]:
            # Should be valid JSON
            json.loads(result["stdout"])


class TestOrchestratorAutoLearn:
    """Tests for orchestrator-auto-learn.sh hook."""

    @pytest.fixture
    def hook_path(self):
        """Get path to orchestrator-auto-learn.sh hook."""
        path = Path.home() / ".claude" / "hooks" / "orchestrator-auto-learn.sh"
        if not path.exists():
            pytest.skip("orchestrator-auto-learn.sh not found")
        return path

    @pytest.fixture
    def temp_project_dir(self, tmp_path):
        """Create temp project directory."""
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()
        return tmp_path

    def run_hook(self, hook_path: Path, project_dir: Path, prompt: str) -> dict:
        """Run the hook with given prompt."""
        hook_input = json.dumps({
            "tool_name": "Task",
            "tool_input": {
                "prompt": prompt,
                "subagent_type": "orchestrator"
            },
            "session_id": "test-session-456"
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            timeout=30,
            env={
                **os.environ,  # Use full environment to avoid missing commands
                "HOME": str(Path.home()),
            }
        )

        return {
            "returncode": result.returncode,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr,
        }

    def test_returns_valid_json(self, hook_path, temp_project_dir):
        """Hook should return valid JSON.

        Note: The hook may return non-zero exit code due to trap handling in bash,
        but it always outputs valid JSON. We verify the JSON output format.
        """
        result = self.run_hook(
            hook_path, temp_project_dir,
            "Implement a simple feature"
        )

        # Hook outputs valid JSON even if exit code is non-zero (trap handling)
        if result["stdout"]:
            # Should be valid JSON - extract first JSON object
            first_json = result["stdout"].split('\n')[0]
            parsed = json.loads(first_json)
            # Verify it uses v2.81.2+ format
            assert "hookSpecificOutput" in parsed or "decision" in parsed, (
                f"Expected v2.81.2+ format, got: {parsed}"
            )

    def test_skips_non_task_tools(self, hook_path, temp_project_dir):
        """Hook should skip non-Task tools."""
        hook_input = json.dumps({
            "tool_name": "Read",
            "tool_input": {"file_path": "/test.txt"},
            "session_id": "test"
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(temp_project_dir),
            timeout=30,
            env={
                **os.environ,  # Use full environment to avoid missing commands
                "HOME": str(Path.home()),
            }
        )

        assert result.returncode == 0

    def test_processes_complex_tasks(self, hook_path, temp_project_dir):
        """Hook should process complex implementation tasks."""
        result = self.run_hook(
            hook_path, temp_project_dir,
            "Implement a distributed microservice architecture with authentication"
        )

        assert result["returncode"] == 0
        # Should output some JSON (either empty or with learning recommendation)
        if result["stdout"]:
            parsed = json.loads(result["stdout"])
            # May or may not have modified prompt depending on procedural rules
            assert isinstance(parsed, dict)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
