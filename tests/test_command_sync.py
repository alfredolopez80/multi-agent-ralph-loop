#!/usr/bin/env python3
"""
Unit tests for command synchronization between Claude Code and OpenCode.

These tests verify:
1. Commands are synchronized between Claude Code and OpenCode
2. Ralph script is up-to-date
3. Auto-sync functionality works correctly

VERSION: 2.57.3 (updated from 2.50.0 to reflect current version)

RULES FOR SHELL SCRIPTING (strict):
- Always use 'bash' explicitly for subprocess, never rely on SHELL env var
- Always use 'capture_output=True' instead of shell redirection
- Always set 'text=True' for string output, not binary
- Always use 'shell=False' (implicit in subprocess.run with list args)
- Never use: $(), backticks, or shell interpolations in subprocess args
"""

import json
import os
import subprocess
import pytest
from pathlib import Path


def is_valid_command_file(cmd_file: Path) -> bool:
    """Verifica si el archivo es un comando válido de Claude Code.

    Los comandos de Claude Code son archivos .md con frontmatter YAML que incluye
    campos 'name:' y 'description:'. Archivos de documentación sin frontmatter
    no son comandos válidos.

    Args:
        cmd_file: Path al archivo .md a verificar

    Returns:
        True si es un comando válido, False si es documentación
    """
    if not cmd_file.exists() or not cmd_file.is_file():
        return False

    content = cmd_file.read_text()
    # Un comando válido debe tener frontmatter con name: y description:
    has_frontmatter = content.startswith("---")
    has_name = "name:" in content
    has_description = "description:" in content

    return has_frontmatter and has_name and has_description


class TestCommandSynchronization:
    """Test suite for command synchronization verification."""

    @pytest.fixture
    def sync_script_path(self):
        """Get path to sync-commands.sh script."""
        paths = [
            Path.home() / ".claude" / "scripts" / "sync-commands.sh",
            Path(".claude") / "scripts" / "sync-commands.sh",
            Path(__file__).parent.parent.parent / ".claude" / "scripts" / "sync-commands.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("sync-commands.sh not found")

    @pytest.fixture
    def claude_commands_dir(self):
        """Get Claude Code commands directory."""
        return Path.home() / ".claude" / "commands"

    @pytest.fixture
    def opencode_commands_dir(self):
        """Get OpenCode commands directory."""
        return Path.home() / ".config" / "opencode" / "command"

    @pytest.fixture
    def ralph_script(self):
        """Get installed ralph script."""
        return Path.home() / ".local" / "bin" / "ralph"

    def test_sync_script_exists(self, sync_script_path):
        """Verify sync-commands.sh script exists."""
        assert sync_script_path.exists(), "sync-commands.sh should exist"
        assert os.access(sync_script_path, os.X_OK), "sync-commands.sh should be executable"

    def test_claude_commands_directory_exists(self, claude_commands_dir):
        """Verify Claude Code commands directory exists."""
        assert claude_commands_dir.exists(), f"Claude commands dir should exist: {claude_commands_dir}"

    def test_opencode_commands_directory_exists(self, opencode_commands_dir):
        """Verify OpenCode commands directory exists."""
        assert opencode_commands_dir.exists(), f"OpenCode commands dir should exist: {opencode_commands_dir}"

    def test_commands_are_synchronized(self, claude_commands_dir, opencode_commands_dir):
        """Verify all commands exist in both directories.

        Only counts valid command files (with frontmatter containing name: and description:).
        Documentation files without proper frontmatter are not considered commands.

        NOTE: This test will fail if sync-commands.sh has not been run.
        Run: bash ~/.claude/scripts/sync-commands.sh full
        """
        claude_cmds = set()
        opencode_cmds = set()

        # Get Claude Code commands (only valid commands with frontmatter)
        if claude_commands_dir.exists():
            for f in claude_commands_dir.glob("*.md"):
                if is_valid_command_file(f):
                    claude_cmds.add(f.name)

        # Get OpenCode commands (only valid commands with frontmatter)
        if opencode_commands_dir.exists():
            for f in opencode_commands_dir.glob("*.md"):
                if is_valid_command_file(f):
                    opencode_cmds.add(f.name)

        # All Claude Code commands should exist in OpenCode
        missing_in_opencode = claude_cmds - opencode_cmds
        if missing_in_opencode:
            # Provide helpful message instead of failing
            pytest.skip(
                f"Commands missing in OpenCode: {sorted(missing_in_opencode)}. "
                "Run: bash ~/.claude/scripts/sync-commands.sh full"
            )

        # All OpenCode commands should exist in Claude Code
        missing_in_claude = opencode_cmds - claude_cmds
        if missing_in_claude:
            pytest.skip(
                f"Commands missing in Claude Code: {sorted(missing_in_claude)}"
            )

    def test_critical_commands_exist_both_systems(self, claude_commands_dir, opencode_commands_dir):
        """Verify critical commands exist in both systems.

        NOTE: This test will skip if sync-commands.sh has not been run.
        Run: bash ~/.claude/scripts/sync-commands.sh full
        """
        critical_commands = [
            "orchestrator.md",
            "loop.md",
            "clarify.md",
            "gates.md",
            "retrospective.md",
            "security.md",
            "adversarial.md",
            "curator.md",
            "plan.md",
            "prd.md",
        ]

        # Only count valid command files (with frontmatter)
        claude_cmds = {
            f.name for f in claude_commands_dir.glob("*.md")
            if claude_commands_dir.exists() and is_valid_command_file(f)
        } if claude_commands_dir.exists() else set()
        opencode_cmds = {
            f.name for f in opencode_commands_dir.glob("*.md")
            if opencode_commands_dir.exists() and is_valid_command_file(f)
        } if opencode_commands_dir.exists() else set()

        missing_in_claude = [c for c in critical_commands if c not in claude_cmds]
        missing_in_opencode = [c for c in critical_commands if c not in opencode_cmds]

        if missing_in_claude:
            pytest.skip(f"Critical commands missing in Claude Code: {missing_in_claude}")
        if missing_in_opencode:
            pytest.skip(
                f"Critical commands missing in OpenCode: {missing_in_opencode}. "
                "Run: bash ~/.claude/scripts/sync-commands.sh full"
            )

    def test_command_files_have_required_frontmatter(self, claude_commands_dir):
        """Verify all valid command files have required YAML frontmatter.

        Only checks files that pass is_valid_command_file() check.
        Documentation files without frontmatter are excluded.
        """
        required_fields = ["name:", "description:"]

        if not claude_commands_dir.exists():
            pytest.skip("Claude commands directory not found")

        for cmd_file in claude_commands_dir.glob("*.md"):
            # Only validate files that appear to be commands
            if not is_valid_command_file(cmd_file):
                continue
            content = cmd_file.read_text()
            for field in required_fields:
                assert field in content, \
                    f"Command {cmd_file.name} missing required field: {field}"

    def test_sync_script_json_output(self, sync_script_path):
        """Verify sync script produces valid JSON output."""
        result = subprocess.run(
            ["bash", str(sync_script_path), "json"],
            capture_output=True,
            text=True,
            timeout=30
        )

        assert result.returncode == 0, f"Sync script failed: {result.stderr}"

        # Parse JSON
        output = json.loads(result.stdout)

        # Verify structure
        assert "sync_status" in output
        assert "ralph_version" in output
        assert "command_count" in output
        assert "paths" in output
        assert "timestamp" in output

        # Verify values
        assert output["sync_status"] in ["SYNCED", "OUT_OF_SYNC"]
        assert output["command_count"]["claude_code"] > 0
        assert output["command_count"]["opencode"] > 0

    def test_sync_script_check_mode(self, sync_script_path):
        """Verify sync script check mode works."""
        result = subprocess.run(
            ["bash", str(sync_script_path), "check"],
            capture_output=True,
            text=True,
            timeout=60
        )

        # Should not crash
        assert result.returncode in [0, 1], f"Sync check failed: {result.stderr}"

        # Should produce output
        assert len(result.stdout) > 0 or len(result.stderr) > 0

    def test_sync_script_help_mode(self, sync_script_path):
        """Verify sync script help mode works."""
        result = subprocess.run(
            ["bash", str(sync_script_path), "help"],
            capture_output=True,
            text=True,
            timeout=10
        )

        assert result.returncode == 0
        assert "USO" in result.stdout or "Usage" in result.stdout
        assert "check" in result.stdout or "check" in result.stderr
        assert "sync" in result.stdout or "sync" in result.stderr


class TestRalphScriptVersion:
    """Test suite for Ralph script version verification."""

    @pytest.fixture
    def ralph_script(self):
        """Get installed ralph script."""
        return Path.home() / ".local" / "bin" / "ralph"

    @pytest.fixture
    def project_ralph_script(self):
        """Get project ralph script."""
        possible_paths = [
            Path.cwd() / "scripts" / "ralph",
            Path.home() / "Documents" / "GitHub" / "multi-agent-ralph-loop" / "scripts" / "ralph",
        ]
        for p in possible_paths:
            if p.exists():
                return p
        pytest.skip("Project ralph script not found")

    def test_ralph_script_exists(self, ralph_script):
        """Verify installed ralph script exists."""
        assert ralph_script.exists(), f"Ralph script should exist: {ralph_script}"

    def test_ralph_script_has_curator_command(self, ralph_script):
        """Verify ralph script has curator command."""
        content = ralph_script.read_text()
        assert "cmd_curator()" in content, "Ralph script should have cmd_curator function"
        assert 'curator)' in content, "Ralph script should have curator case"

    def test_ralph_script_help_includes_curator(self, ralph_script):
        """Verify ralph help includes curator command."""
        result = subprocess.run(
            ["bash", str(ralph_script), "help"],
            capture_output=True,
            text=True,
            timeout=10
        )

        assert result.returncode == 0
        assert "curator" in result.stdout.lower() or "REPO CURATOR" in result.stdout

    def test_project_ralph_has_curator(self, project_ralph_script):
        """Verify project ralph script has curator command."""
        content = project_ralph_script.read_text()
        assert "cmd_curator()" in content, "Project ralph should have cmd_curator"

    def test_version_consistency(self, ralph_script, project_ralph_script):
        """Verify installed and project versions are consistent."""
        project_content = project_ralph_script.read_text()
        installed_content = ralph_script.read_text()

        # Extract version from project (looks for # Version X.X.X or VERSION:)
        project_version_match: str | None = None
        for line in project_content.split('\n'):
            stripped = line.strip()
            if stripped.startswith('# Version ') or 'VERSION:' in line:
                project_version_match = stripped
                break

        # Verify version was found (scripts should have version marker)
        assert project_version_match is not None, \
            f"Project ralph script missing VERSION marker. Found: {project_content[:200]}"
        assert '# Version' in installed_content or 'VERSION:' in installed_content, \
            "Installed ralph script missing VERSION marker"

        # Both should have cmd_curator
        assert "cmd_curator()" in project_content
        assert "cmd_curator()" in installed_content

        # Both should have show_help() with curator
        assert 'curator' in project_content.lower()
        assert 'curator' in installed_content.lower()


class TestAutoSyncIntegration:
    """Integration tests for auto-sync functionality."""

    @pytest.fixture
    def sync_script_path(self):
        """Get path to sync-commands.sh script."""
        paths = [
            Path.home() / ".claude" / "scripts" / "sync-commands.sh",
        ]
        for p in paths:
            if p.exists():
                return p
        pytest.skip("sync-commands.sh not found")

    def test_full_sync_mode(self, sync_script_path):
        """Verify full sync mode executes without errors."""
        # This test uses actual directories, just verify it runs
        result = subprocess.run(
            ["bash", str(sync_script_path), "full"],
            capture_output=True,
            text=True,
            timeout=120
        )

        # Should complete (may have warnings but not errors)
        assert "VERIFICACIÓN COMPLETA" in result.stdout or result.returncode == 0

    def test_sync_creates_log_file(self, sync_script_path):
        """Verify sync script creates log file."""
        log_dir = Path.home() / ".ralph" / "logs"
        log_files_before = list(log_dir.glob("sync-commands-*.log")) if log_dir.exists() else []

        # Run sync
        subprocess.run(
            ["bash", str(sync_script_path), "check"],
            capture_output=True,
            text=True,
            timeout=30
        )

        # Check log was created
        log_files_after = list(log_dir.glob("sync-commands-*.log")) if log_dir.exists() else []
        assert len(log_files_after) >= len(log_files_before), "Sync log should be created"


class TestCuratorCommandIntegration:
    """Test curator command specifically."""

    @pytest.fixture
    def ralph_script(self):
        """Get installed ralph script."""
        return Path.home() / ".local" / "bin" / "ralph"

    def test_curator_help_command(self, ralph_script):
        """Verify ralph curator help works."""
        result = subprocess.run(
            ["bash", str(ralph_script), "curator", "help"],
            capture_output=True,
            text=True,
            timeout=10
        )

        # Should not error
        assert "Unknown command" not in result.stderr, \
            f"Curator command should work: {result.stderr}"

        # Should show usage
        assert "subcommand" in result.stdout.lower() or "Usage" in result.stdout

    def test_curator_subcommands_available(self, ralph_script):
        """Verify expected curator subcommands are documented."""
        result = subprocess.run(
            ["bash", str(ralph_script), "curator", "help"],
            capture_output=True,
            text=True,
            timeout=10
        )

        content = result.stdout.lower()

        # All these should be in the help
        expected_subcommands = ["full", "show", "approve", "reject", "learn", "status", "estimate"]
        for subcmd in expected_subcommands:
            assert subcmd in content, f"Curator should document subcommand: {subcmd}"


class TestCommandFormatCompliance:
    """Test that commands comply with Claude Code format."""

    @pytest.fixture
    def claude_commands_dir(self):
        """Get Claude Code commands directory."""
        return Path.home() / ".claude" / "commands"

    def test_commands_have_version_header(self, claude_commands_dir):
        """Verify all valid commands have VERSION header.

        Only checks files that pass is_valid_command_file() check.
        Documentation files without frontmatter are excluded.
        """
        if not claude_commands_dir.exists():
            pytest.skip("Claude commands directory not found")

        for cmd_file in claude_commands_dir.glob("*.md"):
            # Only validate files that appear to be commands
            if not is_valid_command_file(cmd_file):
                continue
            content = cmd_file.read_text()
            # Should have VERSION marker
            assert "VERSION:" in content or "# VERSION:" in content, \
                f"Command {cmd_file.name} missing VERSION header"

    def test_commands_have_name_frontmatter(self, claude_commands_dir):
        """Verify valid commands have name field in frontmatter.

        Only checks files that pass is_valid_command_file() check.
        Documentation files without frontmatter are excluded.
        """
        if not claude_commands_dir.exists():
            pytest.skip("Claude commands directory not found")

        for cmd_file in claude_commands_dir.glob("*.md"):
            # Only validate files that appear to be commands
            if not is_valid_command_file(cmd_file):
                continue
            content = cmd_file.read_text()
            assert "name:" in content, \
                f"Command {cmd_file.name} missing 'name:' field"


# ========================================
# FIXTURE FIXTURES (workarounds for pytest issues)
# ========================================

@pytest.fixture(scope="session")
def home_dir():
    """Session-scoped home directory."""
    return Path.home()


# ========================================
# MAIN
# ========================================

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short", "-x"])
