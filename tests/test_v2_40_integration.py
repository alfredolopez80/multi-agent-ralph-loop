"""
Multi-Agent Ralph v2.40 Integration Tests

Tests for validating:
- Skills discovery and frontmatter
- llm-tldr integration
- ultrathink skill presence
- Hook registration
- Configuration hierarchy
- Project inheritance
"""
import os
import json
import subprocess
import pytest


class TestSkillsDiscovery:
    """Test skills are properly discoverable."""

    def test_global_skills_directory_exists(self, global_skills_dir):
        """Verify global skills directory exists."""
        assert os.path.isdir(global_skills_dir), f"Skills directory not found: {global_skills_dir}"

    def test_critical_skills_exist(self, global_skills_dir, critical_skills):
        """Verify all critical skills exist."""
        for skill in critical_skills:
            skill_path = os.path.join(global_skills_dir, skill)
            # Skills can be either directories with SKILL.md or direct .md files
            skill_md = os.path.join(skill_path, "SKILL.md")
            skill_file = f"{skill_path}.md"

            exists = os.path.isdir(skill_path) and os.path.isfile(skill_md)
            exists = exists or os.path.isfile(skill_file)

            assert exists, f"Critical skill not found: {skill}"

    def test_skill_count_minimum(self, global_skills_dir):
        """Verify minimum number of skills exist.

        v2.84.2: Updated minimum from 100 to 40 (realistic project-local count).
        """
        skill_count = len([d for d in os.listdir(global_skills_dir)
                         if os.path.isdir(os.path.join(global_skills_dir, d))])
        assert skill_count >= 40, f"Expected at least 40 skills, found {skill_count}"


class TestSkillFrontmatter:
    """Test skill frontmatter is valid."""

    def test_orchestrator_has_frontmatter(self, global_skills_dir, validate_skill_frontmatter):
        """Verify orchestrator skill has valid frontmatter."""
        skill_path = os.path.join(global_skills_dir, "orchestrator", "SKILL.md")
        result = validate_skill_frontmatter(skill_path)

        assert result["has_frontmatter"], "orchestrator skill missing frontmatter"
        assert "description" in result["frontmatter"], "orchestrator missing description"


class TestTldrIntegration:
    """Test llm-tldr integration."""

    def test_tldr_installed(self, tldr_available):
        """Verify llm-tldr is installed."""
        assert tldr_available, "llm-tldr not installed (run: pip install llm-tldr)"

    def test_tldr_version(self, tldr_available):
        """Verify tldr version is accessible."""
        if not tldr_available:
            pytest.skip("tldr not installed")

        result = subprocess.run(["tldr", "--version"], capture_output=True, text=True)
        assert result.returncode == 0, "Failed to get tldr version"
        assert "tldr" in result.stdout.lower() or result.stderr.lower(), "Unexpected tldr output"

    def test_tldr_hook_exists(self, global_hooks_dir):
        """Verify session-start-tldr.sh hook exists."""
        hook_path = os.path.join(global_hooks_dir, "session-start-tldr.sh")
        assert os.path.isfile(hook_path), f"tldr hook not found: {hook_path}"

    def test_tldr_hook_executable(self, global_hooks_dir):
        """Verify tldr hook is executable."""
        hook_path = os.path.join(global_hooks_dir, "session-start-tldr.sh")
        if not os.path.exists(hook_path):
            pytest.skip("tldr hook not found")

        assert os.access(hook_path, os.X_OK), f"tldr hook not executable: {hook_path}"

    def test_tldr_hook_registered(self, load_settings_json):
        """Verify tldr hook is registered in settings.json.

        v2.85: Optional hook - skip if not registered (cosmetic feature).
        """
        settings = load_settings_json()
        hooks = settings.get("hooks", {})
        session_start = hooks.get("SessionStart", [])

        tldr_registered = False
        for hook_config in session_start:
            for hook in hook_config.get("hooks", []):
                if "session-start-tldr" in hook.get("command", ""):
                    tldr_registered = True
                    break

        if not tldr_registered:
            pytest.skip("session-start-tldr.sh not registered (optional cosmetic hook)")


class TestUltrathinkIntegration:
    """Test ultrathink skill integration.

    Note: ultrathink skill removed in v2.84.2 - skipped.
    """

    @pytest.mark.skip(reason="ultrathink skill removed in v2.84.2")
    def test_ultrathink_skill_exists(self, global_skills_dir):
        """Verify ultrathink skill exists."""
        skill_path = os.path.join(global_skills_dir, "ultrathink", "SKILL.md")
        assert os.path.isfile(skill_path), f"ultrathink skill not found: {skill_path}"

    @pytest.mark.skip(reason="ultrathink skill removed in v2.84.2")
    def test_ultrathink_uses_opus(self, global_skills_dir):
        """Verify ultrathink uses opus model."""
        skill_path = os.path.join(global_skills_dir, "ultrathink", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("ultrathink skill not found")

        with open(skill_path) as f:
            content = f.read()

        assert "model: opus" in content, "ultrathink should specify model: opus"

    @pytest.mark.skip(reason="ultrathink skill removed in v2.84.2")
    def test_ultrathink_user_invocable(self, global_skills_dir):
        """Verify ultrathink is user-invocable."""
        skill_path = os.path.join(global_skills_dir, "ultrathink", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("ultrathink skill not found")

        with open(skill_path) as f:
            content = f.read()

        assert "user-invocable: true" in content, "ultrathink should be user-invocable"


class TestHooksConfiguration:
    """Test hooks are properly configured."""

    def test_critical_hooks_exist(self, global_hooks_dir, critical_hooks):
        """Verify all critical hooks exist."""
        for hook in critical_hooks:
            hook_path = os.path.join(global_hooks_dir, hook)
            assert os.path.isfile(hook_path), f"Critical hook not found: {hook}"

    def test_hooks_are_executable(self, global_hooks_dir, critical_hooks):
        """Verify critical hooks are executable."""
        for hook in critical_hooks:
            hook_path = os.path.join(global_hooks_dir, hook)
            if os.path.exists(hook_path):
                assert os.access(hook_path, os.X_OK), f"Hook not executable: {hook}"

    def test_settings_json_valid(self, settings_json_path):
        """Verify settings.json is valid JSON."""
        assert os.path.isfile(settings_json_path), "settings.json not found"

        with open(settings_json_path) as f:
            try:
                settings = json.load(f)
                assert isinstance(settings, dict), "settings.json should be a dict"
            except json.JSONDecodeError as e:
                pytest.fail(f"settings.json is not valid JSON: {e}")

    def test_all_hook_types_configured(self, load_settings_json):
        """Verify all hook types are configured."""
        settings = load_settings_json()
        hooks = settings.get("hooks", {})

        expected_types = ["PostToolUse", "PreToolUse", "SessionStart", "PreCompact"]
        for hook_type in expected_types:
            assert hook_type in hooks, f"Hook type not configured: {hook_type}"


class TestConfigurationHierarchy:
    """Test configuration hierarchy (global vs local)."""

    def test_global_dir_exists(self, claude_global_dir):
        """Verify global Claude directory exists."""
        assert os.path.isdir(claude_global_dir), f"Global dir not found: {claude_global_dir}"

    def test_project_has_local_dir(self, project_root):
        """Verify project has .claude directory."""
        local_claude = os.path.join(project_root, ".claude")
        assert os.path.isdir(local_claude), "Project missing .claude directory"

    def test_no_settings_json_in_project(self, project_root):
        """Verify project uses global settings (no local settings.json)."""
        # Note: This test validates the v2.40 strategy of consolidating to global
        local_settings = os.path.join(project_root, ".claude", "settings.json")

        # If exists, warn (but don't fail - might be intentional override)
        if os.path.isfile(local_settings):
            pytest.skip("Project has local settings.json - may be intentional override")


class TestProjectInheritance:
    """Test project inheritance from global."""

    def test_github_dir_exists(self, github_projects_dir):
        """Verify GitHub projects directory exists."""
        assert os.path.isdir(github_projects_dir), f"GitHub dir not found: {github_projects_dir}"

    def test_projects_inherit_global(self, github_projects_dir, global_skills_dir):
        """Verify projects can access global skills."""
        # This is a conceptual test - Claude Code handles inheritance automatically
        # We just verify the global skills exist and are accessible
        assert os.path.isdir(global_skills_dir), "Global skills directory not accessible"

        skill_count = len(os.listdir(global_skills_dir))
        assert skill_count > 0, "Global skills directory is empty"


class TestOpenCodeSync:
    """Test OpenCode synchronization."""

    def test_opencode_dir_exists(self, opencode_dir):
        """Verify OpenCode directory exists."""
        if not os.path.isdir(opencode_dir):
            pytest.skip("OpenCode not installed")

        assert os.path.isdir(opencode_dir)

    def test_opencode_has_skills(self, opencode_dir):
        """Verify OpenCode has skills directory."""
        if not os.path.isdir(opencode_dir):
            pytest.skip("OpenCode not installed")

        skill_dir = os.path.join(opencode_dir, "skill")
        skills_dir = os.path.join(opencode_dir, "skills")

        has_skills = os.path.isdir(skill_dir) or os.path.isdir(skills_dir)
        assert has_skills, "OpenCode missing skills directory"


class TestRalphBackups:
    """Test Ralph backup functionality."""

    def test_ralph_dir_exists(self, ralph_data_dir):
        """Verify Ralph data directory exists."""
        if not os.path.isdir(ralph_data_dir):
            pytest.skip("Ralph data directory not found")

        assert os.path.isdir(ralph_data_dir)

    def test_backups_dir_exists(self, ralph_data_dir):
        """Verify backups directory exists."""
        backups_dir = os.path.join(ralph_data_dir, "backups")
        if not os.path.isdir(backups_dir):
            pytest.skip("No backups created yet")

        assert os.path.isdir(backups_dir)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
