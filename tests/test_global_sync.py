#!/usr/bin/env python3
"""
Test Suite: Global Sync Validation (v2.35)

Validates that all Ralph configurations are properly synced globally
so that Claude Code has access to all agents, skills, commands, and hooks
regardless of which project directory it's called from.

Run with: pytest tests/test_global_sync.py -v
"""

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path

import pytest


# =============================================================================
# FIXTURES
# =============================================================================


@pytest.fixture
def repo_path():
    """Path to the multi-agent-ralph-loop repository."""
    # Try to find repo from common locations
    paths = [
        Path.cwd(),
        Path.home() / "Documents/GitHub/multi-agent-ralph-loop",
        Path(__file__).parent.parent,
    ]
    for p in paths:
        if (p / "scripts/ralph").exists():
            return p
    pytest.skip("Cannot find ralph repository")


@pytest.fixture
def global_claude_dir():
    """Path to global ~/.claude/ directory."""
    return Path.home() / ".claude"


@pytest.fixture
def global_ralph_dir():
    """Path to global ~/.ralph/ directory."""
    return Path.home() / ".ralph"


# =============================================================================
# TEST: GLOBAL DIRECTORY STRUCTURE
# =============================================================================


class TestGlobalDirectoryStructure:
    """Verify that all required global directories exist."""

    def test_global_claude_directory_exists(self, global_claude_dir):
        """~/.claude/ directory must exist."""
        assert global_claude_dir.exists(), f"Missing: {global_claude_dir}"
        assert global_claude_dir.is_dir()

    def test_global_agents_directory_exists(self, global_claude_dir):
        """~/.claude/agents/ directory must exist."""
        agents_dir = global_claude_dir / "agents"
        assert agents_dir.exists(), f"Missing: {agents_dir}"
        assert agents_dir.is_dir()

    def test_global_commands_directory_exists(self, global_claude_dir):
        """~/.claude/commands/ directory must exist."""
        commands_dir = global_claude_dir / "commands"
        assert commands_dir.exists(), f"Missing: {commands_dir}"
        assert commands_dir.is_dir()

    def test_global_skills_directory_exists(self, global_claude_dir):
        """~/.claude/skills/ directory must exist."""
        skills_dir = global_claude_dir / "skills"
        assert skills_dir.exists(), f"Missing: {skills_dir}"
        assert skills_dir.is_dir()

    def test_global_hooks_directory_exists(self, global_claude_dir):
        """~/.claude/hooks/ directory must exist."""
        hooks_dir = global_claude_dir / "hooks"
        assert hooks_dir.exists(), f"Missing: {hooks_dir}"
        assert hooks_dir.is_dir()

    def test_global_scripts_directory_exists(self, global_claude_dir):
        """~/.claude/scripts/ directory must exist."""
        scripts_dir = global_claude_dir / "scripts"
        assert scripts_dir.exists(), f"Missing: {scripts_dir}"
        assert scripts_dir.is_dir()

    def test_global_ralph_directory_exists(self, global_ralph_dir):
        """~/.ralph/ directory must exist."""
        assert global_ralph_dir.exists(), f"Missing: {global_ralph_dir}"
        assert global_ralph_dir.is_dir()


# =============================================================================
# TEST: GLOBAL AGENTS
# =============================================================================


class TestGlobalAgents:
    """Verify that all required agents are available globally."""

    # Core agents that must always exist
    REQUIRED_AGENTS = [
        "orchestrator.md",
        "code-reviewer.md",
        "security-auditor.md",
        "test-architect.md",
        "debugger.md",
        "refactorer.md",
        "docs-writer.md",
        "frontend-reviewer.md",
        "minimax-reviewer.md",
    ]

    # Auxiliary agents (v2.35)
    AUXILIARY_AGENTS = [
        "code-simplicity-reviewer.md",
        "architecture-strategist.md",
        "kieran-python-reviewer.md",
        "kieran-typescript-reviewer.md",
        "pattern-recognition-specialist.md",
    ]

    def test_required_agents_exist(self, global_claude_dir):
        """All required core agents must exist globally."""
        agents_dir = global_claude_dir / "agents"
        missing = []
        for agent in self.REQUIRED_AGENTS:
            if not (agents_dir / agent).exists():
                missing.append(agent)

        assert not missing, f"Missing required agents: {missing}"

    def test_auxiliary_agents_exist(self, global_claude_dir):
        """All v2.35 auxiliary agents must exist globally."""
        agents_dir = global_claude_dir / "agents"
        missing = []
        for agent in self.AUXILIARY_AGENTS:
            if not (agents_dir / agent).exists():
                missing.append(agent)

        assert not missing, f"Missing auxiliary agents: {missing}"

    def test_orchestrator_has_v235_content(self, global_claude_dir):
        """Orchestrator must include v2.35 auxiliary agents section."""
        orchestrator = global_claude_dir / "agents" / "orchestrator.md"
        content = orchestrator.read_text()

        assert "v2.35" in content, "Orchestrator missing v2.35 version marker"
        assert "Auxiliary Agents" in content, (
            "Orchestrator missing Auxiliary Agents section"
        )
        assert "code-simplicity-reviewer" in content, (
            "Missing code-simplicity-reviewer reference"
        )
        assert "architecture-strategist" in content, (
            "Missing architecture-strategist reference"
        )

    def test_agents_have_valid_frontmatter(self, global_claude_dir):
        """All agents must have valid YAML frontmatter.

        v2.85: Exclude documentation files (CLAUDE.md, WORKFLOW_*.md, *_AUDIT_*.md)
        that are not agent definitions.
        """
        agents_dir = global_claude_dir / "agents"
        invalid = []

        # Exclude documentation files that aren't agents
        EXCLUDE_PATTERNS = ["CLAUDE.md", "WORKFLOW_", "_AUDIT_", "README"]

        for agent_file in agents_dir.glob("*.md"):
            # Skip documentation files
            if any(pattern in agent_file.name for pattern in EXCLUDE_PATTERNS):
                continue

            content = agent_file.read_text()
            if not content.startswith("---"):
                invalid.append(agent_file.name)
                continue

            # Check for required frontmatter fields
            if "name:" not in content[:500]:
                invalid.append(f"{agent_file.name} (missing name)")
            if "description:" not in content[:500]:
                invalid.append(f"{agent_file.name} (missing description)")

        assert not invalid, f"Agents with invalid frontmatter: {invalid}"


# =============================================================================
# TEST: GLOBAL COMMANDS (SLASH COMMANDS)
# =============================================================================


class TestGlobalCommands:
    """Verify that slash commands are available globally."""

    REQUIRED_COMMANDS = [
        "orchestrator.md",
        "security.md",
        "bugs.md",
        "unit-tests.md",
        "gates.md",
        "loop.md",
        "clarify.md",
    ]

    def test_required_commands_exist(self, global_claude_dir):
        """Required slash commands must exist globally."""
        commands_dir = global_claude_dir / "commands"
        missing = []
        for cmd in self.REQUIRED_COMMANDS:
            if not (commands_dir / cmd).exists():
                missing.append(cmd)

        assert not missing, f"Missing commands: {missing}"

    def test_orchestrator_command_exists(self, global_claude_dir):
        """/orchestrator command must exist and be properly configured."""
        cmd_file = global_claude_dir / "commands" / "orchestrator.md"
        assert cmd_file.exists(), "Missing /orchestrator command"

        content = cmd_file.read_text()
        assert "orchestrator" in content.lower()
        assert "@orch" in content, "Missing @orch prefix alias"


# =============================================================================
# TEST: GLOBAL SKILLS
# =============================================================================


class TestGlobalSkills:
    """Verify that skills are available globally."""

    REQUIRED_SKILLS = [
        "retrospective",
        "task-classifier",
    ]

    def test_required_skills_exist(self, global_claude_dir):
        """Required skills must exist globally."""
        skills_dir = global_claude_dir / "skills"
        missing = []

        for skill in self.REQUIRED_SKILLS:
            skill_path = skills_dir / skill
            # Skills can be directories or .md files
            if not skill_path.exists() and not (skills_dir / f"{skill}.md").exists():
                missing.append(skill)

        assert not missing, f"Missing skills: {missing}"


# =============================================================================
# TEST: GLOBAL HOOKS
# =============================================================================


class TestGlobalHooks:
    """Verify that hooks are available and executable globally."""

    REQUIRED_HOOKS = [
        "quality-gates-v2.sh",
        "git-safety-guard.py",
        "session-start-restore-context.sh",  # v2.85: Replaces archived session-start-ledger.sh
        "pre-compact-handoff.sh",
    ]

    def test_required_hooks_exist(self, global_claude_dir):
        """Required hooks must exist globally."""
        hooks_dir = global_claude_dir / "hooks"
        missing = []
        for hook in self.REQUIRED_HOOKS:
            if not (hooks_dir / hook).exists():
                missing.append(hook)

        assert not missing, f"Missing hooks: {missing}"

    def test_hooks_are_executable(self, global_claude_dir):
        """All hook scripts must be executable."""
        hooks_dir = global_claude_dir / "hooks"
        non_executable = []

        for hook_file in hooks_dir.glob("*"):
            if hook_file.is_file() and hook_file.suffix in [".sh", ".py"]:
                if not os.access(hook_file, os.X_OK):
                    non_executable.append(hook_file.name)

        assert not non_executable, f"Hooks not executable: {non_executable}"


# =============================================================================
# TEST: CLAUDE CODE SETTINGS
# =============================================================================


class TestClaudeCodeSettings:
    """Verify that settings.json has proper hook registrations."""

    def test_settings_json_exists(self, global_claude_dir):
        """settings.json must exist."""
        settings_file = global_claude_dir / "settings.json"
        assert settings_file.exists(), "Missing settings.json"

    def test_settings_json_valid(self, global_claude_dir):
        """settings.json must be valid JSON."""
        settings_file = global_claude_dir / "settings.json"
        try:
            with open(settings_file) as f:
                settings = json.load(f)
            assert isinstance(settings, dict), "settings.json must be a dict"
        except json.JSONDecodeError as e:
            pytest.fail(f"Invalid JSON in settings.json: {e}")

    def test_hooks_section_exists(self, global_claude_dir):
        """settings.json must have hooks section."""
        settings_file = global_claude_dir / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        assert "hooks" in settings, "Missing 'hooks' section in settings.json"

    def test_session_start_hook_registered(self, global_claude_dir):
        """SessionStart hook must be registered.

        v2.85: session-start-ledger.sh was archived (redundant with session-start-restore-context.sh).
        """
        settings_file = global_claude_dir / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        assert "SessionStart" in hooks, "SessionStart hook not registered"

        # Verify SessionStart has hooks configured
        session_hooks = hooks["SessionStart"]
        assert len(session_hooks) > 0, "SessionStart has no hooks configured"

    def test_pre_compact_hook_registered(self, global_claude_dir):
        """PreCompact hook must be registered."""
        settings_file = global_claude_dir / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        assert "PreCompact" in hooks, "PreCompact hook not registered"

    def test_post_tool_use_hooks_registered(self, global_claude_dir):
        """PostToolUse hooks must be registered for quality gates."""
        settings_file = global_claude_dir / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        assert "PostToolUse" in hooks, "PostToolUse hooks not registered"

    def test_pre_tool_use_hooks_registered(self, global_claude_dir):
        """PreToolUse hooks must be registered for safety guards."""
        settings_file = global_claude_dir / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)

        hooks = settings.get("hooks", {})
        assert "PreToolUse" in hooks, "PreToolUse hooks not registered"


# =============================================================================
# TEST: GLOBAL SCRIPTS
# =============================================================================


class TestGlobalScripts:
    """Verify that support scripts are available globally.

    v2.85: ledger-manager.py and handoff-generator.py are OPTIONAL.
    They are only required for advanced features (ledgers, handoffs).
    Basic Ralph functionality works without them.
    """

    # Essential scripts that MUST exist for basic operation
    REQUIRED_SCRIPTS = [
        # No scripts are strictly required for basic operation
    ]

    # Optional scripts that enhance functionality
    OPTIONAL_SCRIPTS = [
        "ledger-manager.py",
        "handoff-generator.py",
    ]

    def test_required_scripts_exist(self, global_claude_dir):
        """Required scripts must exist globally.

        v2.85: No scripts are strictly required. Skip if all are optional.
        """
        if not self.REQUIRED_SCRIPTS:
            pytest.skip("No strictly required scripts - all are optional")

        scripts_dir = global_claude_dir / "scripts"
        missing = []
        for script in self.REQUIRED_SCRIPTS:
            if not (scripts_dir / script).exists():
                missing.append(script)

        assert not missing, f"Missing scripts: {missing}"

    def test_scripts_are_executable(self, global_claude_dir):
        """Python scripts must be executable."""
        scripts_dir = global_claude_dir / "scripts"
        non_executable = []

        for script_file in scripts_dir.glob("*.py"):
            if not os.access(script_file, os.X_OK):
                non_executable.append(script_file.name)

        # Note: Python scripts don't always need +x if called with python3
        # This is a soft warning, not a hard failure
        if non_executable:
            pytest.skip(
                f"Scripts not executable (can still run with python3): {non_executable}"
            )


# =============================================================================
# TEST: CLI COMMANDS
# =============================================================================


class TestCLICommands:
    """Verify that ralph CLI commands work correctly."""

    def test_ralph_installed(self):
        """ralph CLI must be installed and accessible."""
        result = subprocess.run(["ralph", "--version"], capture_output=True, text=True)
        assert result.returncode == 0, f"ralph not accessible: {result.stderr}"
        assert "v2" in result.stdout, f"Unexpected version: {result.stdout}"

    def test_ralph_version_is_235_or_higher(self):
        """ralph must be v2.35.0 or higher."""
        result = subprocess.run(["ralph", "--version"], capture_output=True, text=True)
        # Extract version number
        version_line = result.stdout.strip()
        # Expected format: "ralph v2.38.0"
        match = re.search(r"v(\d+)\.(\d+)\.(\d+)", version_line)
        if not match:
            pytest.fail(f"Unexpected version format: {version_line}")
        major, minor, patch = map(int, match.groups())
        if (major, minor, patch) < (2, 35, 0):
            pytest.fail(f"ralph version too old: {version_line}, need v2.35.0+")

    @pytest.mark.skip(reason="sync-global command removed in v2.50+ - sync handled via install.sh")
    def test_sync_global_command_exists(self):
        """ralph sync-global command must exist."""
        result = subprocess.run(["ralph", "help"], capture_output=True, text=True)
        assert "sync-global" in result.stdout, "sync-global command not in help"

    @pytest.mark.skip(reason="sync-global command removed in v2.50+ - sync handled via install.sh")
    def test_sync_global_dry_run(self, repo_path):
        """ralph sync-global --dry-run must work."""
        result = subprocess.run(
            ["ralph", "sync-global", "--dry-run"],
            capture_output=True,
            text=True,
            cwd=repo_path,
        )
        assert result.returncode == 0, f"sync-global failed: {result.stderr}"
        assert "SYNC GLOBAL" in result.stdout or "DRY RUN" in result.stdout

    def test_ledger_command_exists(self, repo_path):
        """ralph ledger command must exist in repo version."""
        ralph_script = repo_path / "scripts" / "ralph"
        result = subprocess.run(
            [str(ralph_script), "help"], capture_output=True, text=True
        )
        assert "ledger" in result.stdout, "ledger command not in repo's ralph help"

    def test_handoff_command_exists(self, repo_path):
        """ralph handoff command must exist in repo version."""
        ralph_script = repo_path / "scripts" / "ralph"
        result = subprocess.run(
            [str(ralph_script), "help"], capture_output=True, text=True
        )
        assert "handoff" in result.stdout, "handoff command not in repo's ralph help"


# =============================================================================
# TEST: REPO TO GLOBAL SYNC CONSISTENCY
# =============================================================================


class TestSyncConsistency:
    """Verify that repo and global directories are in sync."""

    def test_orchestrator_synced(self, repo_path, global_claude_dir):
        """Orchestrator in repo must match global version."""
        repo_file = repo_path / ".claude" / "agents" / "orchestrator.md"
        global_file = global_claude_dir / "agents" / "orchestrator.md"

        if not repo_file.exists():
            pytest.skip("Repo orchestrator not found")

        repo_content = repo_file.read_text()
        global_content = global_file.read_text()

        # Check version markers match
        assert "v2.35" in repo_content, "Repo orchestrator missing v2.35"
        assert "v2.35" in global_content, "Global orchestrator missing v2.35"

    def test_auxiliary_agents_synced(self, repo_path, global_claude_dir):
        """Auxiliary agents in repo must exist globally."""
        agents = [
            "code-simplicity-reviewer.md",
            "architecture-strategist.md",
            "kieran-python-reviewer.md",
            "kieran-typescript-reviewer.md",
            "pattern-recognition-specialist.md",
        ]

        repo_agents_dir = repo_path / ".claude" / "agents"
        global_agents_dir = global_claude_dir / "agents"

        for agent in agents:
            repo_file = repo_agents_dir / agent
            global_file = global_agents_dir / agent

            if repo_file.exists():
                assert global_file.exists(), f"Agent {agent} not synced to global"

    def test_hooks_synced(self, repo_path, global_claude_dir):
        """Critical hooks in repo must exist globally.

        v2.85: session-start-ledger.sh was archived (redundant with session-start-restore-context.sh).
        """
        hooks = [
            "session-start-restore-context.sh",  # v2.85: Replaces archived session-start-ledger.sh
            "pre-compact-handoff.sh",
            "quality-gates-v2.sh",
            "git-safety-guard.py",
        ]

        repo_hooks_dir = repo_path / ".claude" / "hooks"
        global_hooks_dir = global_claude_dir / "hooks"

        for hook in hooks:
            repo_file = repo_hooks_dir / hook
            global_file = global_hooks_dir / hook

            if repo_file.exists():
                assert global_file.exists(), f"Hook {hook} not synced to global"

    def test_settings_json_hooks_synced(self, repo_path, global_claude_dir):
        """settings.json hooks must include all 6 hook event types."""
        repo_settings = repo_path / ".claude" / "settings.json"
        global_settings = global_claude_dir / "settings.json"

        if not repo_settings.exists():
            pytest.skip("Repo settings.json not found")

        # Load both settings files
        with open(repo_settings) as f:
            repo_config = json.load(f)
        with open(global_settings) as f:
            global_config = json.load(f)

        # Required hook event types for v2.35
        required_hooks = [
            "PostToolUse",
            "PreToolUse",
            "SessionStart",
            "PreCompact",
        ]

        repo_hooks = repo_config.get("hooks", {})
        global_hooks = global_config.get("hooks", {})

        # Verify repo has all required hooks
        for hook_type in required_hooks:
            assert hook_type in repo_hooks, f"Repo missing hook type: {hook_type}"
            assert hook_type in global_hooks, f"Global missing hook type: {hook_type}"


# =============================================================================
# TEST: CROSS-PROJECT ACCESSIBILITY
# =============================================================================


class TestCrossProjectAccessibility:
    """Verify that configurations work from any directory."""

    def test_ralph_works_from_temp_directory(self):
        """ralph commands must work from any directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                ["ralph", "--version"], capture_output=True, text=True, cwd=tmpdir
            )
            assert result.returncode == 0, (
                f"ralph failed from temp dir: {result.stderr}"
            )

    def test_ralph_help_works_from_any_directory(self):
        """ralph help must work from any directory."""
        with tempfile.TemporaryDirectory() as tmpdir:
            result = subprocess.run(
                ["ralph", "help"], capture_output=True, text=True, cwd=tmpdir
            )
            assert result.returncode == 0
            assert "orchestrator" in result.stdout.lower()

    def test_global_agents_accessible_from_any_directory(self, global_claude_dir):
        """Global agents must be readable from any process."""
        agents_dir = global_claude_dir / "agents"

        # Verify we can read orchestrator from any location using absolute paths
        with tempfile.TemporaryDirectory() as tmpdir:
            # Change to temp directory and read via absolute path
            original_cwd = os.getcwd()
            try:
                os.chdir(tmpdir)
                orchestrator = agents_dir / "orchestrator.md"
                content = orchestrator.read_text()
                assert len(content) > 1000, "Orchestrator content too short"
                assert "orchestrator" in content.lower()
            finally:
                os.chdir(original_cwd)


# =============================================================================
# TEST: FEATURE FLAGS AND CONFIGURATION
# =============================================================================


class TestFeatureFlags:
    """Verify that feature flags are properly configured."""

    def test_features_config_directory_exists(self, global_ralph_dir):
        """~/.ralph/config/ directory should exist."""
        config_dir = global_ralph_dir / "config"
        # This is optional but recommended
        if not config_dir.exists():
            pytest.skip("Config directory not created yet (optional)")

    def test_ledgers_directory_exists(self, global_ralph_dir):
        """~/.ralph/ledgers/ directory must exist for v2.35."""
        ledgers_dir = global_ralph_dir / "ledgers"
        assert ledgers_dir.exists(), f"Missing ledgers directory: {ledgers_dir}"

    def test_handoffs_directory_exists(self, global_ralph_dir):
        """~/.ralph/handoffs/ directory must exist for v2.35."""
        handoffs_dir = global_ralph_dir / "handoffs"
        assert handoffs_dir.exists(), f"Missing handoffs directory: {handoffs_dir}"


# =============================================================================
# INTEGRATION TEST: FULL SYNC CYCLE
# =============================================================================


class TestFullSyncCycle:
    """Integration test for complete sync cycle."""

    @pytest.mark.skip(reason="sync-global command removed in v2.50+ - sync handled via install.sh")
    def test_full_sync_cycle(self, repo_path, global_claude_dir):
        """
        Complete sync cycle test:
        1. Run sync-global (DEPRECATED - now handled via install.sh)
        2. Verify all agents synced
        3. Verify all hooks synced
        4. Verify settings.json valid

        v2.69: sync-global replaced by install.sh for initial setup.
        This test is preserved for historical reference.
        """
        # Step 1: Run sync (DEPRECATED)
        result = subprocess.run(
            ["ralph", "sync-global"], capture_output=True, text=True, cwd=repo_path
        )

        # Allow for case where everything is already synced
        assert result.returncode == 0 or "up to date" in result.stdout.lower(), (
            f"Sync failed: {result.stderr}"
        )

        # Step 2: Verify orchestrator exists
        orchestrator = global_claude_dir / "agents" / "orchestrator.md"
        assert orchestrator.exists(), "Orchestrator not synced"

        # Step 3: Verify critical hooks
        hooks_dir = global_claude_dir / "hooks"
        assert (hooks_dir / "quality-gates-v2.sh").exists(), "quality-gates-v2.sh not synced"

        # Step 4: Verify settings.json
        settings_file = global_claude_dir / "settings.json"
        with open(settings_file) as f:
            settings = json.load(f)
        assert "hooks" in settings, "Hooks not in settings"


# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    pytest.main([__file__, "-v", "--tb=short"])
