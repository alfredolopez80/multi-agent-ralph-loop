"""
Tests for Ralph v2.35 Context Engineering - Ledger Manager and Handoff Generator.

These tests validate the core components of the automatic context preservation system.
"""

import json
import os
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

# Add scripts directory to path for imports
# Priority: project-local scripts, then global scripts
PROJECT_ROOT = Path(__file__).parent.parent
PROJECT_SCRIPTS = PROJECT_ROOT / ".claude" / "scripts"
GLOBAL_SCRIPTS = Path.home() / ".claude" / "scripts"

# Use project scripts if available, otherwise global
SCRIPTS_DIR = PROJECT_SCRIPTS if PROJECT_SCRIPTS.exists() else GLOBAL_SCRIPTS
sys.path.insert(0, str(SCRIPTS_DIR))


class TestLedgerManager:
    """Tests for ledger-manager.py - Context preservation across sessions."""

    @pytest.fixture
    def ledger_dir(self, tmp_path):
        """Create a temporary ledger directory."""
        ledger_path = tmp_path / "ledgers"
        ledger_path.mkdir(parents=True)
        return ledger_path

    @pytest.fixture
    def manager(self, ledger_dir):
        """Create a LedgerManager instance with temp directory."""
        # Import the module dynamically
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "ledger_manager",
            SCRIPTS_DIR / "ledger-manager.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.LedgerManager(ledger_dir)

    def test_save_basic_ledger(self, manager, ledger_dir):
        """Test saving a basic ledger with minimal data."""
        path = manager.save(
            session_id="test-session-001",
            goal="Test the ledger system"
        )

        assert path.exists()
        assert "CONTINUITY_RALPH-test-session-001.md" in str(path)

        content = path.read_text()
        assert "# CONTINUITY_RALPH: test-session-001" in content
        assert "Test the ledger system" in content

    def test_save_ledger_with_full_data(self, manager, ledger_dir):
        """Test saving a ledger with all fields populated."""
        path = manager.save(
            session_id="test-full",
            goal="Complete OAuth2 implementation",
            constraints=["No external deps", "Tests required"],
            completed_work=[
                {"file": "src/auth.ts", "lines": "10-50", "description": "Auth module"},
                {"file": "src/config.ts", "description": "Config updates"}
            ],
            pending_work=[
                {"file": "src/routes.ts", "description": "API routes"}
            ],
            decisions=["Use JWT", "Google OAuth first"],
            agents_used=[
                {"agent": "security-auditor", "status": "✅", "action": "0 vulns"}
            ]
        )

        content = path.read_text()
        assert "CURRENT GOAL" in content
        assert "Complete OAuth2 implementation" in content
        assert "CONSTRAINTS" in content
        assert "No external deps" in content
        assert "COMPLETED WORK" in content
        assert "src/auth.ts:10-50" in content
        assert "PENDING WORK" in content
        assert "KEY DECISIONS" in content
        assert "Use JWT" in content
        assert "AGENTS USED" in content
        assert "security-auditor" in content

    def test_load_ledger_by_session_id(self, manager, ledger_dir):
        """Test loading a specific ledger by session ID."""
        manager.save(session_id="load-test", goal="Test loading")

        content = manager.load("load-test")
        assert content is not None
        assert "load-test" in content
        assert "Test loading" in content

    def test_load_latest_ledger(self, manager, ledger_dir):
        """Test loading the most recent ledger when no ID specified."""
        manager.save(session_id="old-session", goal="Old")
        manager.save(session_id="new-session", goal="New")

        content = manager.load()
        # Should return the most recent
        assert "new-session" in content

    def test_load_nonexistent_returns_none(self, manager, ledger_dir):
        """Test that loading a nonexistent ledger returns None."""
        content = manager.load("nonexistent-session")
        assert content is None

    def test_list_ledgers(self, manager, ledger_dir):
        """Test listing available ledgers."""
        manager.save(session_id="session-a", goal="A")
        manager.save(session_id="session-b", goal="B")
        manager.save(session_id="session-c", goal="C")

        ledgers = manager.list_ledgers(limit=10)
        assert len(ledgers) == 3

        # Check metadata fields
        first = ledgers[0]
        assert "session_id" in first
        assert "path" in first
        assert "size" in first
        assert "modified" in first

    def test_list_ledgers_with_limit(self, manager, ledger_dir):
        """Test that list respects the limit parameter."""
        for i in range(5):
            manager.save(session_id=f"session-{i}", goal=f"Goal {i}")

        ledgers = manager.list_ledgers(limit=2)
        assert len(ledgers) == 2

    def test_delete_ledger(self, manager, ledger_dir):
        """Test deleting a ledger."""
        manager.save(session_id="to-delete", goal="Will be deleted")
        assert manager.load("to-delete") is not None

        result = manager.delete("to-delete")
        assert result is True
        assert manager.load("to-delete") is None

    def test_delete_nonexistent_returns_false(self, manager, ledger_dir):
        """Test that deleting a nonexistent ledger returns False."""
        result = manager.delete("nonexistent")
        assert result is False

    def test_get_context_for_injection(self, manager, ledger_dir):
        """Test getting context formatted for injection."""
        manager.save(session_id="inject-test", goal="Injection test")

        context = manager.get_context_for_injection(max_tokens=500)
        assert "inject-test" in context
        assert len(context) <= 500 * 4  # Approximate token to char ratio

    def test_context_truncation(self, manager, ledger_dir):
        """Test that large ledgers are truncated for injection."""
        # Create a ledger with lots of data
        manager.save(
            session_id="large-test",
            goal="A" * 2000,  # Long goal
            custom_sections={"Extra": "B" * 5000}
        )

        context = manager.get_context_for_injection(max_tokens=100)
        assert len(context) <= 100 * 4 + 50  # Allow for truncation message
        assert "[... truncated" in context or len(context) < 100 * 4

    def test_safe_session_id_sanitization(self, manager, ledger_dir):
        """Test that session IDs are sanitized for filesystem safety."""
        # Potentially dangerous session ID
        path = manager.save(
            session_id="test/../../../etc/passwd",
            goal="Should be sanitized"
        )

        # Should not contain path traversal - dangerous characters stripped
        assert ".." not in str(path)
        # Path should be within ledger_dir (no escape)
        assert str(ledger_dir) in str(path)
        # Should NOT be an actual /etc/passwd path
        assert not str(path).startswith("/etc")

    def test_file_permissions(self, manager, ledger_dir):
        """Test that ledger files have secure permissions."""
        path = manager.save(session_id="perm-test", goal="Permission test")

        mode = oct(path.stat().st_mode)[-3:]
        assert mode == "600", f"Expected 600 permissions, got {mode}"


class TestHandoffGenerator:
    """Tests for handoff-generator.py - Context transfer between sessions."""

    @pytest.fixture
    def handoff_dir(self, tmp_path):
        """Create a temporary handoff directory."""
        handoff_path = tmp_path / "handoffs"
        handoff_path.mkdir(parents=True)
        return handoff_path

    @pytest.fixture
    def generator(self, handoff_dir):
        """Create a HandoffGenerator instance with temp directory."""
        import importlib.util
        spec = importlib.util.spec_from_file_location(
            "handoff_generator",
            SCRIPTS_DIR / "handoff-generator.py"
        )
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module.HandoffGenerator(handoff_dir)

    def test_create_basic_handoff(self, generator, handoff_dir):
        """Test creating a basic handoff document."""
        path = generator.create(
            session_id="handoff-test",
            trigger="manual"
        )

        assert path.exists()
        assert "handoff-" in str(path)

        content = path.read_text()
        assert "RALPH HANDOFF" in content
        assert "handoff-test" in content
        assert "manual" in content

    def test_create_handoff_with_changes(self, generator, handoff_dir):
        """Test creating a handoff with recent changes."""
        path = generator.create(
            session_id="changes-test",
            trigger="PreCompact (auto)",
            recent_changes=[
                {"file": "src/auth.ts", "type": "MODIFIED"},
                {"file": "tests/auth.test.ts", "type": "ADDED"}
            ],
            context_summary=["Working on OAuth", "Security audit passed"],
            next_steps=["Add routes", "Write docs"]
        )

        content = path.read_text()
        assert "RECENT CHANGES" in content
        assert "src/auth.ts" in content
        assert "MODIFIED" in content
        assert "CONTEXT SUMMARY" in content
        assert "Working on OAuth" in content
        assert "NEXT STEPS" in content
        assert "Add routes" in content
        assert "RESTORE COMMAND" in content

    def test_load_latest_handoff(self, generator, handoff_dir):
        """Test loading the latest handoff."""
        generator.create(session_id="load-test", trigger="test")

        content = generator.load("load-test")
        assert content is not None
        assert "load-test" in content

    def test_list_handoffs(self, generator, handoff_dir):
        """Test listing available handoffs."""
        generator.create(session_id="list-test-1", trigger="test1")
        generator.create(session_id="list-test-2", trigger="test2")

        handoffs = generator.list_handoffs(limit=10)
        assert len(handoffs) >= 2

    def test_search_handoffs(self, generator, handoff_dir):
        """Test searching handoffs."""
        generator.create(
            session_id="search-test",
            trigger="test",
            context_summary=["Working on OAuth2 authentication"]
        )

        results = generator.search("OAuth2")
        assert len(results) > 0
        assert any("OAuth2" in r.get("snippet", "") for r in results)

    def test_search_no_results(self, generator, handoff_dir):
        """Test search with no matching results."""
        generator.create(session_id="no-match", trigger="test")

        results = generator.search("xyznonexistent123")
        assert len(results) == 0

    def test_cleanup_old_handoffs(self, generator, handoff_dir):
        """Test cleanup of old handoffs."""
        # Create some handoffs
        generator.create(session_id="cleanup-test", trigger="test1")
        generator.create(session_id="cleanup-test", trigger="test2")
        generator.create(session_id="cleanup-test", trigger="test3")

        # Cleanup with high keep_min should not delete
        deleted = generator.cleanup_old(days=0, keep_min=10)
        assert deleted == 0

    def test_get_context_for_injection(self, generator, handoff_dir):
        """Test getting handoff context for injection."""
        generator.create(session_id="inject-test", trigger="test")

        context = generator.get_context_for_injection(max_tokens=300)
        assert "inject-test" in context

    def test_file_permissions(self, generator, handoff_dir):
        """Test that handoff files have secure permissions."""
        path = generator.create(session_id="perm-test", trigger="test")

        mode = oct(path.stat().st_mode)[-3:]
        assert mode == "600", f"Expected 600 permissions, got {mode}"

    def test_session_directory_creation(self, generator, handoff_dir):
        """Test that session directories are created automatically."""
        generator.create(session_id="new-session", trigger="test")

        session_dir = handoff_dir / "new-session"
        assert session_dir.exists()
        assert session_dir.is_dir()


class TestCLIIntegration:
    """Integration tests for CLI commands."""

    def test_ledger_manager_cli_help(self):
        """Test ledger-manager.py --help output."""
        result = subprocess.run(
            ["python3", str(SCRIPTS_DIR / "ledger-manager.py"), "--help"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "Context preservation" in result.stdout

    def test_handoff_generator_cli_help(self):
        """Test handoff-generator.py --help output."""
        result = subprocess.run(
            ["python3", str(SCRIPTS_DIR / "handoff-generator.py"), "--help"],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert "Context transfer" in result.stdout

    def test_ledger_save_via_cli(self, tmp_path):
        """Test saving a ledger via CLI."""
        ledger_dir = tmp_path / "ledgers"
        ledger_dir.mkdir()

        result = subprocess.run(
            [
                "python3", str(SCRIPTS_DIR / "ledger-manager.py"),
                "save",
                "--session", "cli-test",
                "--goal", "CLI test goal",
                "--output", str(ledger_dir / "test.md")
            ],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0
        assert (ledger_dir / "test.md").exists()

    def test_handoff_create_via_cli(self, tmp_path):
        """Test creating a handoff via CLI."""
        handoff_dir = tmp_path / "handoffs"
        handoff_dir.mkdir()

        result = subprocess.run(
            [
                "python3", str(SCRIPTS_DIR / "handoff-generator.py"),
                "create",
                "--session", "cli-test",
                "--trigger", "cli-manual",
                "--output", str(handoff_dir / "test.md")
            ],
            capture_output=True,
            text=True
        )

        assert result.returncode == 0
        assert (handoff_dir / "test.md").exists()


class TestHooksIntegration:
    """Integration tests for SessionStart and PreCompact hooks."""

    @pytest.fixture
    def hooks_dir(self):
        """Return the hooks directory."""
        return Path.home() / ".claude" / "hooks"

    def test_session_start_hook_exists(self, hooks_dir):
        """Test that session-start-restore-context.sh exists and is executable.

        v2.85: session-start-ledger.sh was archived (redundant with session-start-restore-context.sh).
        Tests now validate the replacement hook.
        """
        hook_path = hooks_dir / "session-start-restore-context.sh"
        assert hook_path.exists(), f"Hook not found: {hook_path}"

        mode = hook_path.stat().st_mode
        assert mode & 0o111, "Hook is not executable"

    def test_pre_compact_hook_exists(self, hooks_dir):
        """Test that pre-compact-handoff.sh exists and is executable."""
        hook_path = hooks_dir / "pre-compact-handoff.sh"
        assert hook_path.exists(), f"Hook not found: {hook_path}"

        mode = hook_path.stat().st_mode
        assert mode & 0o111, "Hook is not executable"

    def test_session_start_hook_output_format(self, hooks_dir):
        """Test that SessionStart hook returns valid JSON.

        v2.85: session-start-ledger.sh was archived (redundant with session-start-restore-context.sh).
        Tests now validate the replacement hook.
        """
        hook_path = hooks_dir / "session-start-restore-context.sh"

        result = subprocess.run(
            ["bash", str(hook_path)],
            input='{"source": "startup", "session_id": "test"}',
            capture_output=True,
            text=True
        )

        assert result.returncode == 0

        # Verify JSON output
        output = json.loads(result.stdout)
        assert "hookSpecificOutput" in output
        assert "additionalContext" in output["hookSpecificOutput"]

    def test_pre_compact_hook_output_format(self, hooks_dir):
        """Test that PreCompact hook returns valid JSON."""
        hook_path = hooks_dir / "pre-compact-handoff.sh"

        result = subprocess.run(
            ["bash", str(hook_path)],
            input='{"session_id": "test-compact", "transcript_path": ""}',
            capture_output=True,
            text=True,
            timeout=15
        )

        assert result.returncode == 0

        # Verify JSON output
        output = json.loads(result.stdout)
        assert "continue" in output
        assert output["continue"] is True


class TestFeatureFlags:
    """Tests for feature flag system."""

    @pytest.fixture
    def features_file(self, tmp_path):
        """Create a temporary features file."""
        config_dir = tmp_path / "config"
        config_dir.mkdir()
        features_path = config_dir / "features.json"
        return features_path

    def test_default_features_enabled(self, features_file):
        """Test that default features are enabled."""
        features_file.write_text(json.dumps({
            "RALPH_ENABLE_LEDGER": True,
            "RALPH_ENABLE_HANDOFF": True,
            "RALPH_ENABLE_STATUSLINE": True
        }))

        content = json.loads(features_file.read_text())
        assert content["RALPH_ENABLE_LEDGER"] is True
        assert content["RALPH_ENABLE_HANDOFF"] is True
        assert content["RALPH_ENABLE_STATUSLINE"] is True

    def test_features_can_be_disabled(self, features_file):
        """Test that features can be disabled."""
        features_file.write_text(json.dumps({
            "RALPH_ENABLE_LEDGER": False,
            "RALPH_ENABLE_HANDOFF": True,
            "RALPH_ENABLE_STATUSLINE": True
        }))

        content = json.loads(features_file.read_text())
        assert content["RALPH_ENABLE_LEDGER"] is False


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
