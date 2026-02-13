"""
Tests for claude-mem configuration validation.

Validates that CLAUDE_PLUGIN_ROOT is correctly configured
and all required files exist.

Issue: v2.85.1 - CLAUDE_PLUGIN_ROOT was pointing to non-existent 9.0.10
Fix: Updated to 10.0.6 which exists and has all required files
"""

import os
import subprocess
import pytest
from pathlib import Path


class TestClaudePluginRootConfiguration:
    """Test CLAUDE_PLUGIN_ROOT environment variable configuration."""

    def test_claude_plugin_root_is_set(self):
        """CLAUDE_PLUGIN_ROOT should be set in the environment."""
        plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        assert plugin_root is not None, "CLAUDE_PLUGIN_ROOT is not set"

    def test_claude_plugin_root_directory_exists(self):
        """CLAUDE_PLUGIN_ROOT should point to an existing directory."""
        plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if not plugin_root:
            pytest.skip("CLAUDE_PLUGIN_ROOT not set")

        path = Path(plugin_root)
        assert path.exists(), f"CLAUDE_PLUGIN_ROOT directory does not exist: {plugin_root}"
        assert path.is_dir(), f"CLAUDE_PLUGIN_ROOT is not a directory: {plugin_root}"

    def test_claude_plugin_root_is_not_stale_9_0_10(self):
        """CLAUDE_PLUGIN_ROOT should NOT point to the non-existent 9.0.10 version."""
        plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if not plugin_root:
            pytest.skip("CLAUDE_PLUGIN_ROOT not set")

        assert "9.0.10" not in plugin_root, (
            f"CLAUDE_PLUGIN_ROOT points to non-existent 9.0.10: {plugin_root}. "
            "Update .zshrc to use 10.0.6 or later."
        )

    def test_claude_plugin_root_has_valid_version(self):
        """CLAUDE_PLUGIN_ROOT should point to a valid version (10.0.6+)."""
        plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if not plugin_root:
            pytest.skip("CLAUDE_PLUGIN_ROOT not set")

        # Extract version from path
        version = None
        for part in Path(plugin_root).parts:
            if part.startswith(("9.", "10.")):
                version = part
                break

        assert version is not None, f"Could not detect version in CLAUDE_PLUGIN_ROOT: {plugin_root}"

        # Parse version and validate
        major, minor = map(int, version.split(".")[:2])
        assert (major, minor) >= (10, 0), (
            f"CLAUDE_PLUGIN_ROOT version {version} is too old. Expected 10.0.6 or later."
        )


class TestClaudeMemRequiredFiles:
    """Test that all required claude-mem files exist."""

    REQUIRED_SCRIPTS = [
        "scripts/worker-service.cjs",
        "scripts/bun-runner.js",
        "scripts/smart-install.js",
        "scripts/setup.sh",
        "scripts/context-generator.cjs",
    ]

    REQUIRED_DIRS = [
        "scripts",
        "hooks",
    ]

    @pytest.fixture
    def plugin_root(self):
        """Get CLAUDE_PLUGIN_ROOT path."""
        root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if not root:
            pytest.skip("CLAUDE_PLUGIN_ROOT not set")
        return Path(root)

    @pytest.mark.parametrize("script_path", REQUIRED_SCRIPTS)
    def test_required_script_exists(self, plugin_root, script_path):
        """All required scripts should exist in CLAUDE_PLUGIN_ROOT."""
        full_path = plugin_root / script_path
        assert full_path.exists(), f"Required script not found: {full_path}"

    @pytest.mark.parametrize("script_path", REQUIRED_SCRIPTS)
    def test_required_script_is_executable(self, plugin_root, script_path):
        """Shell scripts should be executable."""
        if not script_path.endswith(".sh"):
            pytest.skip(f"Not a shell script: {script_path}")

        full_path = plugin_root / script_path
        if not full_path.exists():
            pytest.skip(f"Script not found: {full_path}")

        assert os.access(full_path, os.X_OK), f"Script is not executable: {full_path}"

    @pytest.mark.parametrize("dir_path", REQUIRED_DIRS)
    def test_required_directory_exists(self, plugin_root, dir_path):
        """All required directories should exist."""
        full_path = plugin_root / dir_path
        assert full_path.exists(), f"Required directory not found: {full_path}"
        assert full_path.is_dir(), f"Path is not a directory: {full_path}"

    def test_hooks_json_exists(self, plugin_root):
        """hooks/hooks.json should exist."""
        hooks_json = plugin_root / "hooks" / "hooks.json"
        assert hooks_json.exists(), f"hooks.json not found: {hooks_json}"

    def test_hooks_json_is_valid_json(self, plugin_root):
        """hooks/hooks.json should be valid JSON."""
        import json

        hooks_json = plugin_root / "hooks" / "hooks.json"
        if not hooks_json.exists():
            pytest.skip(f"hooks.json not found: {hooks_json}")

        content = hooks_json.read_text()
        try:
            data = json.loads(content)
            assert "hooks" in data, "hooks.json missing 'hooks' key"
        except json.JSONDecodeError as e:
            pytest.fail(f"hooks.json is not valid JSON: {e}")


class TestClaudeMemWorkerService:
    """Test claude-mem worker-service functionality."""

    @pytest.fixture
    def plugin_root(self):
        """Get CLAUDE_PLUGIN_ROOT path."""
        root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if not root:
            pytest.skip("CLAUDE_PLUGIN_ROOT not set")
        return Path(root)

    def test_worker_service_can_show_status(self, plugin_root):
        """worker-service.cjs status command should work."""
        worker_path = plugin_root / "scripts" / "worker-service.cjs"
        if not worker_path.exists():
            pytest.skip(f"worker-service.cjs not found: {worker_path}")

        result = subprocess.run(
            ["bun", str(worker_path), "status"],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(plugin_root)
        )

        # Should not error (exit code 0 or output contains status info)
        assert result.returncode == 0 or "running" in result.stdout.lower() or "not running" in result.stdout.lower(), (
            f"worker-service.cjs status failed: {result.stderr}"
        )

    def test_worker_service_is_running(self, plugin_root):
        """claude-mem worker should be running."""
        worker_path = plugin_root / "scripts" / "worker-service.cjs"
        if not worker_path.exists():
            pytest.skip(f"worker-service.cjs not found: {worker_path}")

        result = subprocess.run(
            ["bun", str(worker_path), "status"],
            capture_output=True,
            text=True,
            timeout=30,
            cwd=str(plugin_root)
        )

        assert "running" in result.stdout.lower(), (
            f"claude-mem worker is not running. Output: {result.stdout}"
        )


class TestZshrcConfiguration:
    """Test .zshrc claude-mem configuration."""

    ZSHRC_PATH = Path.home() / ".zshrc"

    def test_zshrc_exists(self):
        """.zshrc should exist."""
        assert self.ZSHRC_PATH.exists(), ".zshrc not found"

    def test_zshrc_has_claude_plugin_root(self):
        """.zshrc should define CLAUDE_PLUGIN_ROOT."""
        if not self.ZSHRC_PATH.exists():
            pytest.skip(".zshrc not found")

        content = self.ZSHRC_PATH.read_text()
        assert "CLAUDE_PLUGIN_ROOT" in content, (
            "CLAUDE_PLUGIN_ROOT not defined in .zshrc"
        )

    def test_zshrc_claude_plugin_root_not_9_0_10(self):
        """.zshrc CLAUDE_PLUGIN_ROOT should not reference non-existent 9.0.10."""
        if not self.ZSHRC_PATH.exists():
            pytest.skip(".zshrc not found")

        content = self.ZSHRC_PATH.read_text()

        # Check for stale 9.0.10 reference
        if "claude-mem/9.0.10" in content:
            pytest.fail(
                ".zshrc still references claude-mem/9.0.10 which does not exist. "
                "Update to 10.0.6 or later."
            )

    def test_zshrc_claude_mem_alias_exists(self):
        """.zshrc should have claude-mem alias."""
        if not self.ZSHRC_PATH.exists():
            pytest.skip(".zshrc not found")

        content = self.ZSHRC_PATH.read_text()
        assert "alias claude-mem=" in content or "alias claude-mem =" in content, (
            "claude-mem alias not found in .zshrc"
        )

    def test_zshrc_claude_mem_alias_points_to_valid_path(self):
        """claude-mem alias should point to an existing file."""
        if not self.ZSHRC_PATH.exists():
            pytest.skip(".zshrc not found")

        content = self.ZSHRC_PATH.read_text()

        # Extract alias path - handles formats like:
        # alias claude-mem='bun /path/to/script'
        # alias claude-mem="/path/to/script"
        import re
        match = re.search(r"alias\s+claude-mem\s*=\s*['\"](.+?)['\"]", content)
        if not match:
            pytest.skip("Could not parse claude-mem alias")

        alias_command = match.group(1)

        # Extract the actual file path from the command
        # Handle "bun /path/to/script" or just "/path/to/script"
        parts = alias_command.split()
        for part in parts:
            if part.startswith("/") or part.startswith("~"):
                alias_path = os.path.expanduser(part)
                break
        else:
            # If no path found, skip the test
            pytest.skip(f"Could not extract path from alias: {alias_command}")

        assert Path(alias_path).exists(), (
            f"claude-mem alias points to non-existent file: {alias_path}"
        )


class TestClaudeMemHooksJson:
    """Test claude-mem hooks.json configuration."""

    @pytest.fixture
    def plugin_root(self):
        """Get CLAUDE_PLUGIN_ROOT path."""
        root = os.environ.get("CLAUDE_PLUGIN_ROOT")
        if not root:
            pytest.skip("CLAUDE_PLUGIN_ROOT not set")
        return Path(root)

    def test_hooks_json_exists(self, plugin_root):
        """hooks.json should exist in the hooks directory."""
        hooks_json = plugin_root / "hooks" / "hooks.json"
        assert hooks_json.exists(), f"hooks.json not found: {hooks_json}"

    def test_hooks_json_not_using_node_bun_runner(self, plugin_root):
        """hooks.json should NOT use node bun-runner.js wrapper.

        The bun-runner.js wrapper was causing issues because it didn't
        preserve the current working directory, which the worker uses
        to detect the project name.

        Fix: Use 'bun' directly instead of 'node bun-runner.js'
        """
        hooks_json = plugin_root / "hooks" / "hooks.json"
        if not hooks_json.exists():
            pytest.skip(f"hooks.json not found: {hooks_json}")

        content = hooks_json.read_text()

        # Check that we're NOT using the broken node bun-runner.js pattern
        assert 'node " ' not in content.lower() or "bun-runner.js" not in content, (
            "hooks.json is using the broken 'node bun-runner.js' pattern. "
            "This causes project detection to fail. Use 'bun' directly instead."
        )

    def test_hooks_json_uses_bun_directly(self, plugin_root):
        """hooks.json should use bun directly for worker commands."""
        hooks_json = plugin_root / "hooks" / "hooks.json"
        if not hooks_json.exists():
            pytest.skip(f"hooks.json not found: {hooks_json}")

        content = hooks_json.read_text()

        # Check that we're using bun directly (escaped quote in JSON)
        assert 'bun \\"' in content or 'bun "' in content, (
            "hooks.json should use 'bun' directly for worker commands. "
            "Pattern: bun \"${CLAUDE_PLUGIN_ROOT}/scripts/worker-service.cjs\" ..."
        )

    def test_hooks_json_session_start_has_context_hook(self, plugin_root):
        """SessionStart should have the context hook for injecting claude-mem context."""
        import json

        hooks_json = plugin_root / "hooks" / "hooks.json"
        if not hooks_json.exists():
            pytest.skip(f"hooks.json not found: {hooks_json}")

        content = json.loads(hooks_json.read_text())

        session_start = content.get("hooks", {}).get("SessionStart", [])
        assert len(session_start) > 0, "SessionStart hooks not found"

        # Check that there's a context hook
        has_context_hook = False
        for hook_group in session_start:
            for hook in hook_group.get("hooks", []):
                command = hook.get("command", "")
                if "context" in command:
                    has_context_hook = True
                    break

        assert has_context_hook, (
            "SessionStart should have a hook that generates context. "
            "Pattern: ... hook claude-code context"
        )


class TestClaudeMemDatabase:
    """Test claude-mem SQLite database."""

    DB_PATH = Path.home() / ".claude-mem" / "claude-mem.db"

    def test_database_exists(self):
        """claude-mem database should exist."""
        assert self.DB_PATH.exists(), (
            f"claude-mem database not found: {self.DB_PATH}"
        )

    def test_database_is_valid_sqlite(self):
        """claude-mem database should be valid SQLite."""
        if not self.DB_PATH.exists():
            pytest.skip("claude-mem database not found")

        result = subprocess.run(
            ["sqlite3", str(self.DB_PATH), ".tables"],
            capture_output=True,
            text=True,
            timeout=10
        )

        assert result.returncode == 0, f"Database is not valid SQLite: {result.stderr}"
        assert "observations" in result.stdout, "Database missing 'observations' table"

    def test_database_has_observations(self):
        """claude-mem database should have observations."""
        if not self.DB_PATH.exists():
            pytest.skip("claude-mem database not found")

        result = subprocess.run(
            ["sqlite3", str(self.DB_PATH), "SELECT COUNT(*) FROM observations"],
            capture_output=True,
            text=True,
            timeout=10
        )

        if result.returncode == 0:
            count = int(result.stdout.strip())
            assert count > 0, "Database has no observations"
