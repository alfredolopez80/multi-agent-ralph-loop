#!/usr/bin/env python3
"""
Tests for Memory Search v2.57.0 fixes.

Verifies that:
1. todo-plan-sync.sh handles step-X-Y format keys (not just numeric)
2. smart-memory-search.sh uses SQLite for claude-mem (not JSON files)
3. inject-session-context.sh doesn't output JSON (PreToolUse hook)
4. Plan-state updates correctly from TodoWrite

VERSION: 2.57.0
Part of v2.57.0 Memory System Reconstruction - Phase 5
"""

import json
import subprocess
import pytest
from pathlib import Path


class TestTodoPlanSync:
    """Tests for todo-plan-sync.sh hook fixes."""

    @pytest.fixture
    def hook_path(self):
        """Get path to todo-plan-sync.sh hook."""
        path = Path.home() / ".claude" / "hooks" / "todo-plan-sync.sh"
        if not path.exists():
            pytest.skip("todo-plan-sync.sh not found")
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
    """Tests for smart-memory-search.sh SQLite fix."""

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

    def test_uses_sqlite_not_json_files(self, hook_path):
        """Hook should search SQLite database, not JSON files."""
        content = hook_path.read_text()

        # v2.57.0: Should use SQLite
        assert "sqlite3" in content, \
            "Hook should use sqlite3 for claude-mem search"

        # Should reference the actual database
        assert "claude-mem.db" in content, \
            "Hook should reference claude-mem.db"

        # Should use FTS
        assert "observations_fts" in content or "MATCH" in content, \
            "Hook should use FTS for efficient search"

    def test_version_is_257(self, hook_path):
        """Hook version should be 2.57.0."""
        content = hook_path.read_text()
        assert "2.57.0" in content

    def test_pretooluse_no_json_output(self, hook_path):
        """PreToolUse hook should exit 0 silently, not output JSON."""
        content = hook_path.read_text()

        # Should mention that it exits 0 silently
        assert "exit 0" in content

        # The final output should NOT be JSON
        lines = content.strip().split('\n')
        last_code_line = [l for l in lines if l.strip() and not l.strip().startswith('#')][-1]
        assert "exit 0" in last_code_line, \
            "Hook should end with 'exit 0' (PreToolUse must be silent)"


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

    def test_version_is_257(self, hook_path):
        """Hook version should be 2.57.0."""
        content = hook_path.read_text()
        assert "VERSION: 2.57.0" in content

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
