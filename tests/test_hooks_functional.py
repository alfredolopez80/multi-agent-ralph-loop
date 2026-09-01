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

# CI-safe: hooks always resolve from the repo's versioned copy, never the
# developer's ~/.claude/hooks (which is absent in a clean CI checkout → exit 127).
HOOKS_DIR = Path(__file__).parent.parent / ".claude" / "hooks"


class TestLsaPreStepHookFunctional:
    """Functional tests for lsa-pre-step.sh hook."""

    @pytest.fixture
    def hook_path(self):
        """Get path to lsa-pre-step.sh hook (repo copy)."""
        p = HOOKS_DIR / "lsa-pre-step.sh"
        if not p.exists():
            pytest.skip("lsa-pre-step.sh not found")
        return p

    def test_hook_passes_without_plan_state(self, hook_path, tmp_path, isolated_home):
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
        """Get path to plan-sync-post-step.sh hook (repo copy)."""
        p = HOOKS_DIR / "plan-sync-post-step.sh"
        if not p.exists():
            pytest.skip("plan-sync-post-step.sh not found")
        return p

    def test_hook_passes_without_plan_state(self, hook_path, tmp_path, isolated_home):
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

    def test_hooks_handle_invalid_json_input(self, isolated_home):
        """Hooks should handle malformed JSON input gracefully."""
        hook_paths = [
            HOOKS_DIR / "auto-plan-state.sh",
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

    def test_hooks_handle_empty_input(self, isolated_home):
        """Hooks should handle empty input gracefully."""
        hook_paths = [
            HOOKS_DIR / "auto-plan-state.sh",
            HOOKS_DIR / "lsa-pre-step.sh",
            HOOKS_DIR / "plan-sync-post-step.sh",
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


if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
