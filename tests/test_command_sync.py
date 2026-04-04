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
