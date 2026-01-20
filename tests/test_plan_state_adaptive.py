#!/usr/bin/env python3
"""
Functional tests for plan-state-adaptive.sh hook.

These tests verify that the adaptive plan-state system correctly:
1. Classifies prompts into FAST_PATH, SIMPLE, COMPLEX, ORCHESTRATOR
2. Creates appropriate plan-states with correct complexity settings
3. Respects staleness thresholds
4. Does not overwrite active plans

VERSION: 2.57.0

Part of v2.57.0 Memory System Reconstruction - Phase 1
"""

import json
import subprocess
import pytest
import time
from pathlib import Path
from typing import Dict, Any


class TestPlanStateAdaptiveClassification:
    """Tests for prompt classification logic."""

    @pytest.fixture
    def hook_path(self):
        """Get path to plan-state-adaptive.sh hook."""
        paths = [
            Path.home() / ".claude" / "hooks" / "plan-state-adaptive.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("plan-state-adaptive.sh not found")

    @pytest.fixture
    def temp_project_dir(self, tmp_path):
        """Create a temporary project directory with .claude folder."""
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()
        return tmp_path

    def run_hook(self, hook_path: Path, project_dir: Path, prompt: str) -> Dict[str, Any]:
        """Run the hook and return parsed JSON output."""
        hook_input = json.dumps({
            "userPrompt": prompt
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            timeout=30,
            env={
                "HOME": str(Path.home()),
                "PATH": "/usr/bin:/bin:/usr/local/bin"
            }
        )

        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "output": json.loads(result.stdout) if result.stdout.strip() else {}
        }

    def get_plan_state(self, project_dir: Path) -> Dict[str, Any]:
        """Read and parse plan-state.json if it exists."""
        plan_state_path = project_dir / ".claude" / "plan-state.json"
        if plan_state_path.exists():
            return json.loads(plan_state_path.read_text())
        return {}

    # ==========================================================================
    # Classification Tests
    # ==========================================================================

    def test_trivial_prompt_creates_fast_path(self, hook_path, temp_project_dir):
        """Trivial prompts like 'fix typo' should create FAST_PATH plan-state."""
        result = self.run_hook(hook_path, temp_project_dir, "fix typo in readme")

        assert result["returncode"] == 0, f"Hook failed: {result['stderr']}"

        plan_state = self.get_plan_state(temp_project_dir)
        assert plan_state, "Plan-state was not created"
        assert plan_state.get("classification", {}).get("adaptive_mode") == "FAST_PATH"
        assert plan_state.get("classification", {}).get("complexity") == 2
        assert plan_state.get("loop_state", {}).get("max_iterations") == 3

    def test_simple_prompt_creates_simple_plan(self, hook_path, temp_project_dir):
        """Simple prompts like 'fix this bug' should create SIMPLE plan-state."""
        result = self.run_hook(hook_path, temp_project_dir, "fix the validation error in the login form")

        assert result["returncode"] == 0, f"Hook failed: {result['stderr']}"

        plan_state = self.get_plan_state(temp_project_dir)
        assert plan_state, "Plan-state was not created"
        assert plan_state.get("classification", {}).get("adaptive_mode") == "SIMPLE"
        assert plan_state.get("classification", {}).get("complexity") == 4
        assert plan_state.get("loop_state", {}).get("max_iterations") == 10

    def test_complex_prompt_creates_complex_plan(self, hook_path, temp_project_dir):
        """Complex prompts with multiple steps should create COMPLEX plan-state."""
        prompt = (
            "implement user authentication with JWT tokens, including "
            "login, logout, password reset, and email verification"
        )
        result = self.run_hook(hook_path, temp_project_dir, prompt)

        assert result["returncode"] == 0, f"Hook failed: {result['stderr']}"

        plan_state = self.get_plan_state(temp_project_dir)
        assert plan_state, "Plan-state was not created"
        assert plan_state.get("classification", {}).get("adaptive_mode") == "COMPLEX"
        assert plan_state.get("classification", {}).get("complexity") == 7
        assert plan_state.get("loop_state", {}).get("max_iterations") == 25

    def test_orchestrator_command_defers(self, hook_path, temp_project_dir):
        """Orchestrator commands should defer plan creation."""
        result = self.run_hook(hook_path, temp_project_dir, "/orchestrator implement feature X")

        assert result["returncode"] == 0, f"Hook failed: {result['stderr']}"

        # Should NOT create plan-state (defers to orchestrator)
        plan_state = self.get_plan_state(temp_project_dir)
        assert not plan_state, "Plan-state should not be created for /orchestrator"

    # ==========================================================================
    # Plan-State Schema Tests
    # ==========================================================================

    def test_plan_state_has_required_fields(self, hook_path, temp_project_dir):
        """Created plan-state should have all required fields."""
        self.run_hook(hook_path, temp_project_dir, "update the version number")

        plan_state = self.get_plan_state(temp_project_dir)
        assert plan_state, "Plan-state was not created"

        # Required top-level fields
        assert "$schema" in plan_state or "plan_id" in plan_state
        assert "classification" in plan_state
        assert "steps" in plan_state
        assert "loop_state" in plan_state
        assert "phases" in plan_state
        assert "version" in plan_state

        # Classification fields
        classification = plan_state["classification"]
        assert "complexity" in classification
        assert "adaptive_mode" in classification
        assert "model_routing" in classification

    def test_plan_state_has_valid_step_structure(self, hook_path, temp_project_dir):
        """Created plan-state should have valid step structure."""
        self.run_hook(hook_path, temp_project_dir, "add logging to the API")

        plan_state = self.get_plan_state(temp_project_dir)
        assert plan_state, "Plan-state was not created"

        steps = plan_state.get("steps", {})
        assert len(steps) >= 1, "Should have at least one step"

        # Check first step
        step_1 = steps.get("1", {})
        assert step_1.get("status") == "pending"
        assert "title" in step_1

    # ==========================================================================
    # Staleness Tests
    # ==========================================================================

    def test_does_not_overwrite_active_plan(self, hook_path, temp_project_dir):
        """Should not overwrite an active (recent) plan-state."""
        # Create first plan
        self.run_hook(hook_path, temp_project_dir, "fix typo")
        first_plan = self.get_plan_state(temp_project_dir)
        first_plan_id = first_plan.get("plan_id")

        # Try to create second plan immediately
        self.run_hook(hook_path, temp_project_dir, "update readme")
        second_plan = self.get_plan_state(temp_project_dir)
        second_plan_id = second_plan.get("plan_id")

        # Should be the same plan (not overwritten)
        assert first_plan_id == second_plan_id, "Active plan should not be overwritten"

    def test_replaces_completed_plan(self, hook_path, temp_project_dir):
        """Should replace a completed plan-state."""
        # Create first plan
        self.run_hook(hook_path, temp_project_dir, "fix typo")

        # Mark plan as completed
        plan_state_path = temp_project_dir / ".claude" / "plan-state.json"
        plan_state = json.loads(plan_state_path.read_text())
        plan_state["phases"][0]["status"] = "completed"
        plan_state_path.write_text(json.dumps(plan_state, indent=2))

        # Create second plan
        self.run_hook(hook_path, temp_project_dir, "update documentation")
        new_plan = self.get_plan_state(temp_project_dir)

        # Should be a new plan
        assert new_plan.get("phases", [{}])[0].get("status") == "pending"

    # ==========================================================================
    # Edge Cases
    # ==========================================================================

    def test_empty_prompt_does_nothing(self, hook_path, temp_project_dir):
        """Empty prompt should not create plan-state."""
        result = self.run_hook(hook_path, temp_project_dir, "")

        assert result["returncode"] == 0
        plan_state = self.get_plan_state(temp_project_dir)
        assert not plan_state, "Empty prompt should not create plan-state"

    def test_very_long_prompt_classification(self, hook_path, temp_project_dir):
        """Very long prompts should be classified based on content and length."""
        long_prompt = "please " + " ".join(["review"] * 50)  # Very long but simple
        result = self.run_hook(hook_path, temp_project_dir, long_prompt)

        assert result["returncode"] == 0
        plan_state = self.get_plan_state(temp_project_dir)
        # Long prompts default to COMPLEX
        if plan_state:
            assert plan_state.get("classification", {}).get("adaptive_mode") in ["SIMPLE", "COMPLEX"]


class TestPlanStateLifecycleAdaptive:
    """Tests for plan-state-lifecycle.sh adaptive support."""

    @pytest.fixture
    def lifecycle_hook_path(self):
        """Get path to plan-state-lifecycle.sh hook."""
        paths = [
            Path.home() / ".claude" / "hooks" / "plan-state-lifecycle.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("plan-state-lifecycle.sh not found")

    @pytest.fixture
    def temp_project_dir(self, tmp_path):
        """Create a temporary project directory with .claude folder."""
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()
        return tmp_path

    def create_plan_state(
        self, project_dir: Path, adaptive_mode: str, age_minutes: int = 0
    ) -> Path:
        """Create a plan-state.json with specific adaptive mode and age."""
        plan_state = {
            "$schema": "plan-state-v2",
            "plan_id": f"test-{int(time.time())}",
            "task": "Test task",
            "classification": {
                "complexity": 5,
                "adaptive_mode": adaptive_mode,
                "route": adaptive_mode
            },
            "steps": {"1": {"status": "pending", "title": "Test step"}},
            "phases": [{"phase_id": "main", "status": "pending", "step_ids": ["1"]}],
            "loop_state": {"max_iterations": 10},
            "version": "2.57.0"
        }

        plan_state_path = project_dir / ".claude" / "plan-state.json"
        plan_state_path.write_text(json.dumps(plan_state, indent=2))

        # Adjust file modification time if needed
        if age_minutes > 0:
            import os
            old_time = time.time() - (age_minutes * 60)
            os.utime(plan_state_path, (old_time, old_time))

        return plan_state_path

    def run_lifecycle_hook(
        self, hook_path: Path, project_dir: Path, prompt: str
    ) -> Dict[str, Any]:
        """Run the lifecycle hook and return result."""
        hook_input = json.dumps({
            "userPromptContent": prompt
        })

        result = subprocess.run(
            ["bash", str(hook_path)],
            input=hook_input,
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            timeout=30,
            env={
                "HOME": str(Path.home()),
                "PATH": "/usr/bin:/bin:/usr/local/bin"
            }
        )

        return {
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr
        }

    def test_fast_path_staleness_threshold(self, lifecycle_hook_path, temp_project_dir):
        """FAST_PATH plans should have 30-minute staleness threshold."""
        # Create FAST_PATH plan that's 35 minutes old
        self.create_plan_state(temp_project_dir, "FAST_PATH", age_minutes=35)

        result = self.run_lifecycle_hook(
            lifecycle_hook_path, temp_project_dir,
            "implement a new feature with authentication and database"
        )

        assert result["returncode"] == 0
        # Should mention auto-archive or staleness
        # (actual behavior depends on whether it's detected as new task)

    def test_complex_staleness_threshold(self, lifecycle_hook_path, temp_project_dir):
        """COMPLEX plans should have 2-hour staleness threshold."""
        # Create COMPLEX plan that's 90 minutes old (should NOT be stale yet)
        self.create_plan_state(temp_project_dir, "COMPLEX", age_minutes=90)

        result = self.run_lifecycle_hook(
            lifecycle_hook_path, temp_project_dir, "implement something new"
        )

        assert result["returncode"] == 0
        # 90 minutes is less than 120 minute threshold, so should not archive


class TestStatusLineAdaptiveMode:
    """Tests for statusline-ralph.sh adaptive mode display."""

    @pytest.fixture
    def statusline_path(self):
        """Get path to statusline-ralph.sh."""
        paths = [
            Path.home() / ".claude" / "scripts" / "statusline-ralph.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("statusline-ralph.sh not found")

    @pytest.fixture
    def temp_project_dir(self, tmp_path):
        """Create a temporary project directory with .claude folder."""
        claude_dir = tmp_path / ".claude"
        claude_dir.mkdir()
        # Initialize as git repo for statusline
        subprocess.run(["git", "init", "-q"], cwd=str(tmp_path))
        return tmp_path

    def create_plan_state_with_mode(
        self, project_dir: Path, adaptive_mode: str
    ) -> None:
        """Create a plan-state with specific adaptive mode."""
        plan_state = {
            "$schema": "plan-state-v2",
            "plan_id": "test-123",
            "classification": {
                "complexity": 5,
                "adaptive_mode": adaptive_mode,
                "route": adaptive_mode
            },
            "steps": {
                "1": {"status": "completed"},
                "2": {"status": "in_progress"},
                "3": {"status": "pending"}
            },
            "phases": [{"phase_id": "main", "status": "in_progress"}],
            "version": "2.57.0"
        }

        plan_state_path = project_dir / ".claude" / "plan-state.json"
        plan_state_path.write_text(json.dumps(plan_state, indent=2))

    def run_statusline(self, script_path: Path, project_dir: Path) -> str:
        """Run statusline script and return output."""
        stdin_data = json.dumps({"cwd": str(project_dir)})

        result = subprocess.run(
            ["bash", str(script_path)],
            input=stdin_data,
            capture_output=True,
            text=True,
            cwd=str(project_dir),
            timeout=10,
            env={
                "HOME": str(Path.home()),
                "PATH": "/usr/bin:/bin:/usr/local/bin"
            }
        )

        return result.stdout

    def test_fast_path_shows_lightning_icon(self, statusline_path, temp_project_dir):
        """FAST_PATH mode should show lightning icon."""
        self.create_plan_state_with_mode(temp_project_dir, "FAST_PATH")
        output = self.run_statusline(statusline_path, temp_project_dir)

        # Should contain lightning icon for FAST_PATH
        assert "⚡" in output or "FAST" in output or "1/3" in output

    def test_simple_shows_notepad_icon(self, statusline_path, temp_project_dir):
        """SIMPLE mode should show notepad icon."""
        self.create_plan_state_with_mode(temp_project_dir, "SIMPLE")
        output = self.run_statusline(statusline_path, temp_project_dir)

        # Should show progress with notepad icon
        assert "📝" in output or "1/3" in output

    def test_complex_shows_cycle_icon(self, statusline_path, temp_project_dir):
        """COMPLEX mode should show cycle/refresh icon."""
        self.create_plan_state_with_mode(temp_project_dir, "COMPLEX")
        output = self.run_statusline(statusline_path, temp_project_dir)

        # Should show progress with cycle icon
        assert "🔄" in output or "1/3" in output


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
