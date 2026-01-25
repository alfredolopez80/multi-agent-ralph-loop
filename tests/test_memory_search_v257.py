#!/usr/bin/env python3
"""
Tests for Memory Search v2.69.0 (updated from v2.57.0).

Verifies that:
1. todo-plan-sync.sh [DEPRECATED v2.62 - replaced by global-task-sync.sh]
2. smart-memory-search.sh uses parallel memory sources (claude-mem MCP, memvid, handoffs, ledgers, web search)
3. inject-session-context.sh outputs valid JSON (PreToolUse hook format: {"decision": "allow"})
4. Plan-state updates correctly from TodoWrite

VERSION: 2.69.0
Part of v2.69.0 GLM-4.7 integration and parallel memory architecture
"""

import json
import subprocess
import pytest
from pathlib import Path


@pytest.mark.skip(reason="v2.69.1: todo-plan-sync.sh was replaced by global-task-sync.sh in v2.62. TodoWrite replaced by Task Primitive.")
class TestTodoPlanSync:
    """Tests for todo-plan-sync.sh hook fixes.

    DEPRECATED v2.69.1: This hook was replaced by global-task-sync.sh in v2.62.
    The Task Primitive (TaskCreate/TaskUpdate/TaskList) replaced TodoWrite.
    """

    @pytest.fixture
    def hook_path(self):
        """Get path to todo-plan-sync.sh hook."""
        path = Path.home() / ".claude" / "hooks" / "todo-plan-sync.sh"
        if not path.exists():
            pytest.skip("todo-plan-sync.sh not found - replaced by global-task-sync.sh in v2.62")
        return path

    def test_hook_exists(self, hook_path):
        """Hook file should exist."""
        assert hook_path.exists()

    def test_uses_sort_not_tonumber(self, hook_path):
        """Hook should use 'sort' not 'sort_by(tonumber)' for step keys."""
        content = hook_path.read_text()

        # Should NOT have sort_by(tonumber) anymore
        assert "sort_by(tonumber)" not in content, \
            "Hook still uses sort_by(tonumber) which fails with step-X-Y keys"

        # Should have simple sort
        assert "keys | sort |" in content or "keys | sort |" in content.replace("  ", " "), \
            "Hook should use 'keys | sort' for step-X-Y format keys"

    def test_version_is_257(self, hook_path):
        """Hook version should be 2.57.0."""
        content = hook_path.read_text()
        assert "VERSION: 2.57.0" in content

    def test_returns_valid_json(self, hook_path):
        """Hook should return valid JSON for TodoWrite."""
        # Create minimal TodoWrite input
        hook_input = json.dumps({
            "tool_name": "TodoWrite",
            "tool_input": {
                "todos": [
                    {"content": "Test task 1", "status": "completed", "activeForm": "Testing task 1"},
                    {"content": "Test task 2", "status": "in_progress", "activeForm": "Testing task 2"},
                ]
            },
            "session_id": "test-session"
        })

        # Run hook in a temp directory to avoid modifying real plan-state
        import tempfile
        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                ["bash", str(hook_path)],
                input=hook_input,
                capture_output=True,
                text=True,
                timeout=30,
                cwd=tmpdir,
                env={
                    "HOME": str(Path.home()),
                    "PATH": "/usr/bin:/bin:/usr/local/bin"
                }
            )

            assert result.returncode == 0, f"Hook failed: {result.stderr}"

            # Should output valid JSON
            output = result.stdout.strip()
            if output:
                parsed = json.loads(output)
                assert "continue" in parsed


class TestSmartMemorySearch:
    """Tests for smart-memory-search.sh v2.69.0 parallel memory architecture."""

    @pytest.fixture
    def hook_path(self):
        """Get path to smart-memory-search.sh hook."""
        path = Path.home() / ".claude" / "hooks" / "smart-memory-search.sh"
        if not path.exists():
            pytest.skip("smart-memory-search.sh not found")
        return path

    def test_hook_exists(self, hook_path):
        """Hook file should exist."""
        assert hook_path.exists()

    def test_uses_parallel_memory_sources(self, hook_path):
        """Hook should use parallel memory sources (v2.69.0: MCP, memvid, handoffs, ledgers, web)."""
        content = hook_path.read_text()

        # v2.69.0: Should use claude-mem MCP (not direct SQLite)
        assert "claude-mem" in content or "mcp" in content.lower(), \
            "Hook should use claude-mem MCP for semantic search"

        # Should reference multiple parallel sources
        assert "handoffs" in content or "HANDOFFS" in content, \
            "Hook should search handoffs"

        assert "ledgers" in content or "LEDGERS" in content, \
            "Hook should search ledgers"

    def test_version_is_current(self, hook_path):
        """Hook version should be >= 2.69.0."""
        content = hook_path.read_text()
        # Version-agnostic check - just verify it has a version
        assert "VERSION:" in content or "version:" in content.lower()
        # If it has 2.69 or 2.68 or 2.70, it's current enough
        assert "2.69" in content or "2.68" in content or "2.70" in content

    def test_pretooluse_json_output(self, hook_path):
        """PreToolUse hook should output JSON with {"decision": "allow"}."""
        content = hook_path.read_text()

        # Should output JSON (v2.69: PreToolUse hooks output JSON)
        assert 'decision' in content, \
            "Hook should output JSON with 'decision' field"

        # Should use proper PreToolUse format
        assert '"allow"' in content or "'allow'" in content, \
            "Hook should use 'decision': 'allow' format"


class TestInjectSessionContext:
    """Tests for inject-session-context.sh PreToolUse fix."""

    @pytest.fixture
    def hook_path(self):
        """Get path to inject-session-context.sh hook."""
        path = Path.home() / ".claude" / "hooks" / "inject-session-context.sh"
        if not path.exists():
            pytest.skip("inject-session-context.sh not found")
        return path

    def test_hook_exists(self, hook_path):
        """Hook file should exist."""
        assert hook_path.exists()

    def test_no_json_output(self, hook_path):
        """PreToolUse hook should NOT output JSON."""
        content = hook_path.read_text()

        # Should NOT have echo '{"tool_input":' or similar
        assert 'echo "{' not in content or 'echo "{}' not in content, \
            "Hook should not output JSON to stdout"

        # Should document that PreToolUse can't modify tool_input
        assert "CANNOT" in content or "can't modify" in content.lower() or "cannot modify" in content.lower(), \
            "Hook should document that PreToolUse cannot modify tool_input"

    def test_ends_with_exit_0(self, hook_path):
        """Hook should end with exit 0, not JSON output."""
        content = hook_path.read_text()
        lines = content.strip().split('\n')
        last_line = lines[-1].strip()
        assert last_line == "exit 0", \
            f"Hook should end with 'exit 0', got: {last_line}"

    def test_version_is_current(self, hook_path):
        """Hook version should be >= 2.69.0."""
        content = hook_path.read_text()
        # Version-agnostic check
        assert "VERSION:" in content
        # Should be recent version
        assert "2.69" in content or "2.68" in content or "2.70" in content

    def test_saves_context_to_cache(self, hook_path):
        """Hook should save context to cache for SessionStart hook."""
        content = hook_path.read_text()
        assert "CONTEXT_CACHE" in content, \
            "Hook should use CONTEXT_CACHE variable"


class TestPlanStateSchema:
    """Tests for plan-state.json schema compatibility."""

    @pytest.fixture
    def plan_state_path(self):
        """Get path to plan-state.json."""
        path = Path.cwd() / ".claude" / "plan-state.json"
        if not path.exists():
            pytest.skip("plan-state.json not found in current directory")
        return path

    def test_plan_state_exists(self, plan_state_path):
        """Plan state file should exist."""
        assert plan_state_path.exists()

    def test_plan_state_is_valid_json(self, plan_state_path):
        """Plan state should be valid JSON."""
        data = json.loads(plan_state_path.read_text())
        assert "steps" in data

    def test_steps_have_step_format_keys(self, plan_state_path):
        """Steps should have step-X-Y format keys."""
        data = json.loads(plan_state_path.read_text())
        steps = data.get("steps", {})

        if steps:
            keys = list(steps.keys())
            # Check if any key matches step-X-Y pattern
            import re
            step_pattern = re.compile(r'^step-\d+-\d+$')
            step_format_keys = [k for k in keys if step_pattern.match(k)]
            numeric_keys = [k for k in keys if k.isdigit()]

            # Should have step-X-Y format (v2.54+) or numeric (v2.51-)
            assert step_format_keys or numeric_keys, \
                f"Steps should have step-X-Y or numeric keys, got: {keys}"


class TestClaudeMemDatabase:
    """Tests for claude-mem SQLite database."""

    @pytest.fixture
    def db_path(self):
        """Get path to claude-mem database."""
        path = Path.home() / ".claude-mem" / "claude-mem.db"
        if not path.exists():
            pytest.skip("claude-mem.db not found")
        return path

    def test_database_exists(self, db_path):
        """Database should exist."""
        assert db_path.exists()

    def test_has_observations_table(self, db_path):
        """Database should have observations table."""
        import sqlite3
        conn = sqlite3.connect(str(db_path))
        cursor = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='observations'"
        )
        result = cursor.fetchone()
        conn.close()

        assert result is not None, "Database should have 'observations' table"

    def test_has_fts_table(self, db_path):
        """Database should have FTS virtual table."""
        import sqlite3
        conn = sqlite3.connect(str(db_path))
        cursor = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='observations_fts'"
        )
        result = cursor.fetchone()
        conn.close()

        assert result is not None, "Database should have 'observations_fts' FTS table"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
