#!/usr/bin/env python3
"""
Functional tests for v2.84.1 hooks.

These tests verify actual BEHAVIOR, not just existence.
They run the hooks with realistic inputs and validate outputs.

VERSION: 2.84.1
CHANGES from 2.57.3:
- Updated to support v2.81.2+ hookSpecificOutput wrapper format
- PreToolUse hooks now use {"hookSpecificOutput": {"permissionDecision": "allow"}}
  or legacy {"decision": "allow"} format
- PostToolUse hooks use {"continue": true} format
"""

import json
import subprocess
import pytest
from pathlib import Path


def is_valid_pretooluse_permission(output: dict) -> bool:
    """Check if output has valid PreToolUse permission decision.

    Supports both v2.81.2+ format and legacy format:
    - {"hookSpecificOutput": {"permissionDecision": "allow"}}
    - {"permissionDecision": "allow"}
    - {"decision": "allow"}
    """
    if output is None:
        return False
    if output == {}:
        return True

    # v2.81.2+ format
    if "hookSpecificOutput" in output:
        hso = output.get("hookSpecificOutput", {})
        if hso.get("permissionDecision") in ("allow", "block"):
            return True

    # Intermediate format
    if output.get("permissionDecision") in ("allow", "block"):
        return True

    # Legacy format
    if output.get("decision") in ("allow", "block"):
        return True

    return False


def get_pretooluse_decision(output: dict) -> str:
    """Extract the permission decision from PreToolUse output (supports both formats).

    Returns "allow", "block", or empty string if not found.
    """
    if output is None:
        return ""

    # v2.81.2+ format
    if "hookSpecificOutput" in output:
        hso = output.get("hookSpecificOutput", {})
        decision = hso.get("permissionDecision", "")
        if decision in ("allow", "block"):
            return decision

    # Intermediate format
    if output.get("permissionDecision") in ("allow", "block"):
        return output["permissionDecision"]

    # Legacy format
    if output.get("decision") in ("allow", "block"):
        return output["decision"]

    return ""


class TestAutoPlanStateHookFunctional:
    """Functional tests for auto-plan-state.sh hook behavior."""

    @pytest.fixture
    def hook_path(self):
        """Get path to auto-plan-state.sh hook."""
        paths = [
            Path.home() / ".claude" / "hooks" / "auto-plan-state.sh",
            Path(".claude") / "hooks" / "auto-plan-state.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("auto-plan-state.sh not found")

    @pytest.fixture
    def temp_project_dir(self, tmp_path):
        """Create a temporary project directory with .claude folder."""
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()
        return tmp_path

    @pytest.fixture
    def sample_analysis_content(self):
        """Sample orchestrator-analysis.md content."""
        return """# Task Analysis: Implement User Authentication

## Summary
Implement JWT-based user authentication with login, logout, and session management.

## Classification
- **Complexity**: 7/10
- **Model Routing**: opus
- **Adversarial Required**: Yes

## Implementation Phases

### Phase 1: Database Setup
Create user tables and migrations.

### Phase 2: Auth Service
Implement authentication logic with JWT.

### Phase 3: API Endpoints
Create login, logout, refresh token endpoints.

### Phase 4: Testing
Write unit and integration tests.

## Files to Modify
- src/auth/service.ts
- src/auth/routes.ts
- src/db/migrations/001_users.sql
"""

    def test_hook_creates_valid_json_from_analysis(
        self, hook_path, temp_project_dir, sample_analysis_content
    ):
        """Hook should create valid plan-state.json from orchestrator-analysis.md."""
        # Setup: Create analysis file
        analysis_file = temp_project_dir / ".claude" / "orchestrator-analysis.md"
        analysis_file.write_text(sample_analysis_content)

        # Prepare hook input JSON
        hook_input = json.dumps({
            "tool_name": "Write",
            "tool_input": {
                "file_path": str(analysis_file)
            }
        })

        # Run hook
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(temp_project_dir),
            timeout=30
        )

        # Verify hook executed
        assert result.returncode == 0, f"Hook failed: {result.stderr}"

        # Check plan-state.json was created
        plan_state_file = temp_project_dir / ".claude" / "plan-state.json"
        assert plan_state_file.exists(), "plan-state.json was not created"

        # Validate JSON structure
        plan_state = json.loads(plan_state_file.read_text())

        # Required fields
        assert "$schema" in plan_state
        assert "plan_id" in plan_state
        assert "task" in plan_state
        assert "classification" in plan_state
        assert "steps" in plan_state
        assert "loop_state" in plan_state
        assert "metadata" in plan_state

        # Verify extracted values
        assert plan_state["classification"]["complexity"] == 7
        assert plan_state["classification"]["model_routing"] == "opus"
        assert plan_state["classification"]["adversarial_required"] is True

        # Verify steps extracted (4 phases)
        assert len(plan_state["steps"]) >= 1

    def test_hook_handles_empty_analysis(self, hook_path, temp_project_dir):
        """Hook should handle empty orchestrator-analysis.md gracefully."""
        # Setup: Create empty analysis file
        analysis_file = temp_project_dir / ".claude" / "orchestrator-analysis.md"
        analysis_file.write_text("")

        hook_input = json.dumps({
            "tool_name": "Write",
            "tool_input": {"file_path": str(analysis_file)}
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(temp_project_dir),
            timeout=30
        )

        # Should not crash
        assert result.returncode == 0

    def test_hook_skips_non_analysis_files(self, hook_path, temp_project_dir):
        """Hook should skip files that are not orchestrator-analysis.md."""
        hook_input = json.dumps({
            "tool_name": "Write",
            "tool_input": {"file_path": "/some/other/file.md"}
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(temp_project_dir),
            timeout=30
        )

        # Should exit 0 without creating plan-state.json
        assert result.returncode == 0

        plan_state_file = temp_project_dir / ".claude" / "plan-state.json"
        assert not plan_state_file.exists()

    def test_hook_uses_atomic_write(self, hook_path):
        """Verify hook uses mktemp + mv pattern for atomic writes."""
        hook_content = hook_path.read_text()

        # Check for atomic write pattern
        assert "mktemp" in hook_content, "Hook should use mktemp for atomic writes"
        assert "mv " in hook_content or "mv \"" in hook_content, "Hook should use mv for atomic rename"


class TestInjectSessionContextHookFunctional:
    """Functional tests for inject-session-context.sh hook."""

    @pytest.fixture
    def hook_path(self):
        """Get path to inject-session-context.sh hook."""
        paths = [
            Path.home() / ".claude" / "hooks" / "inject-session-context.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("inject-session-context.sh not found")

    def test_hook_returns_valid_json_for_task_tool(self, hook_path, tmp_path):
        """Hook should return valid JSON with permission=allow for Task tool.

        Note: PreToolUse hooks cannot inject context into Task calls.
        The hook allows the Task tool and provides info via additionalContext.

        v2.84.1: Supports both legacy and v2.81.2+ formats.
        """
        # Create minimal CLAUDE.md
        claude_md = tmp_path / "CLAUDE.md"
        claude_md.write_text("# Test Project v1.0\n\nTest content.")

        hook_input = json.dumps({
            "tool_name": "Task",
            "session_id": "test-session-123"
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(tmp_path),
            timeout=15
        )

        assert result.returncode == 0, f"Hook failed: {result.stderr}"

        # Parse output as JSON
        output = json.loads(result.stdout)

        # v2.84.1: Support both legacy and v2.81.2+ formats
        assert is_valid_pretooluse_permission(output), (
            f"Expected valid PreToolUse permission format, got: {output}"
        )
        decision = get_pretooluse_decision(output)
        assert decision == "allow", f"Expected permission=allow, got: {decision}"

    def test_hook_skips_non_task_tools(self, hook_path, tmp_path):
        """Hook should return permission=allow for non-Task tools.

        v2.84.1: Supports both legacy and v2.81.2+ formats.
        """
        hook_input = json.dumps({
            "tool_name": "Read",
            "session_id": "test-session-456"
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(tmp_path),
            timeout=15
        )

        assert result.returncode == 0

        output = json.loads(result.stdout)
        # v2.84.1: Support both legacy and v2.81.2+ formats
        assert is_valid_pretooluse_permission(output), (
            f"Expected valid PreToolUse permission format, got: {output}"
        )
        decision = get_pretooluse_decision(output)
        assert decision == "allow", f"Expected permission=allow, got: {decision}"

    def test_hook_performance_under_5_seconds(self, hook_path, tmp_path):
        """Hook should complete within 5 seconds (well under 15s timeout)."""
        import time

        hook_input = json.dumps({
            "tool_name": "Task",
            "session_id": "perf-test"
        })

        start = time.time()
        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(tmp_path),
            timeout=15
        )
        elapsed = time.time() - start

        assert result.returncode == 0
        assert elapsed < 5.0, f"Hook took {elapsed:.2f}s, should be under 5s"


class TestLsaPreStepHookFunctional:
    """Functional tests for lsa-pre-step.sh hook."""

    @pytest.fixture
    def hook_path(self):
        """Get path to lsa-pre-step.sh hook."""
        paths = [
            Path.home() / ".claude" / "hooks" / "lsa-pre-step.sh",
            Path(".claude") / "hooks" / "lsa-pre-step.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("lsa-pre-step.sh not found")

    def test_hook_passes_without_plan_state(self, hook_path, tmp_path):
        """Hook should pass (exit 0) when no plan-state.json exists."""
        hook_input = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": "/some/file.ts"}
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(tmp_path),
            timeout=10
        )

        # Should not block when no plan state
        assert result.returncode == 0


class TestPlanSyncPostStepHookFunctional:
    """Functional tests for plan-sync-post-step.sh hook."""

    @pytest.fixture
    def hook_path(self):
        """Get path to plan-sync-post-step.sh hook."""
        paths = [
            Path.home() / ".claude" / "hooks" / "plan-sync-post-step.sh",
            Path(".claude") / "hooks" / "plan-sync-post-step.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("plan-sync-post-step.sh not found")

    def test_hook_passes_without_plan_state(self, hook_path, tmp_path):
        """Hook should pass when no plan-state.json exists."""
        hook_input = json.dumps({
            "tool_name": "Edit",
            "tool_input": {"file_path": "/some/file.ts"}
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(tmp_path),
            timeout=10
        )

        assert result.returncode == 0


class TestHookErrorRecovery:
    """Tests for hook error recovery and graceful degradation."""

    def test_hooks_handle_invalid_json_input(self):
        """Hooks should handle malformed JSON input gracefully."""
        hook_paths = [
            Path.home() / ".claude" / "hooks" / "auto-plan-state.sh",
            Path.home() / ".claude" / "hooks" / "inject-session-context.sh",
        ]

        for hook_path in hook_paths:
            if not hook_path.exists():
                continue

            # Send invalid JSON
            result = subprocess.run(
                ["bash", str(hook_path)],
                input="not valid json {{{",
                capture_output=True,
                text=True,
                timeout=15
            )

            # Should not crash (exit 0)
            assert result.returncode == 0, f"{hook_path.name} crashed on invalid JSON"

    def test_hooks_handle_empty_input(self):
        """Hooks should handle empty input gracefully."""
        hook_paths = [
            Path.home() / ".claude" / "hooks" / "auto-plan-state.sh",
            Path.home() / ".claude" / "hooks" / "inject-session-context.sh",
            Path.home() / ".claude" / "hooks" / "lsa-pre-step.sh",
            Path.home() / ".claude" / "hooks" / "plan-sync-post-step.sh",
        ]

        for hook_path in hook_paths:
            if not hook_path.exists():
                continue

            result = subprocess.run(
                ["bash", str(hook_path)],
                input="",
                capture_output=True,
                text=True,
                timeout=15
            )

            # Should not crash
            assert result.returncode == 0, f"{hook_path.name} crashed on empty input"


class TestHookIntegrationScenarios:
    """Integration tests simulating real workflow scenarios."""

    @pytest.fixture
    def mock_project(self, tmp_path):
        """Create a mock project structure."""
        # Create .claude directory
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()

        # Create CLAUDE.md
        (tmp_path / "CLAUDE.md").write_text("# Mock Project v2.45.2\n")

        # Create progress.md
        (claude_dir / "progress.md").write_text("""## Current Goal
Implement user authentication

## Recent Progress
- [x] Created auth service skeleton
- [x] Added JWT library
- [ ] Implement login endpoint
""")

        return tmp_path

    def test_task_context_injection_with_progress(self, mock_project):
        """Verify hook runs for Task tool and returns valid output.

        Note: PreToolUse hooks cannot inject context into Task calls.
        The hook acknowledges the Task tool but context injection requires SessionStart.

        v2.84.1: Supports both legacy and v2.81.2+ formats.
        """
        hook_path = Path.home() / ".claude" / "hooks" / "inject-session-context.sh"
        if not hook_path.exists():
            pytest.skip("inject-session-context.sh not found")

        hook_input = json.dumps({
            "tool_name": "Task",
            "session_id": "integration-test"
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(mock_project),
            timeout=15
        )

        assert result.returncode == 0

        output = json.loads(result.stdout)

        # v2.84.1: Support both legacy and v2.81.2+ formats
        assert is_valid_pretooluse_permission(output), (
            f"Expected valid PreToolUse permission format, got: {output}"
        )
        decision = get_pretooluse_decision(output)
        assert decision == "allow", f"Expected permission=allow, got: {decision}"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
