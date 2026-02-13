"""
Multi-Agent Ralph v2.43 Integration Tests

Tests for validating:
- Codex CLI security (no --yolo flags)
- PreToolUse additionalContext hook
- LSP-Explore skill
- Claude-Mem integration hints
- Modernized skill frontmatter (YAML allowed-tools)
- MCP auto:10 configuration
- Worktree dashboard command
"""
import os
import json
import subprocess
import pytest


class TestCodexNoYoloFlags:
    """Test that --yolo is not used in Codex CLI invocations."""

    def test_bugs_md_no_yolo(self, global_commands_dir):
        """Ensure --yolo is not used in bugs.md command."""
        bugs_path = os.path.join(global_commands_dir, "bugs.md")
        if not os.path.exists(bugs_path):
            pytest.skip("bugs.md not found")

        with open(bugs_path) as f:
            content = f.read()

        # --yolo should not appear in codex exec commands
        # Note: codex exec --yolo is the dangerous pattern
        assert "codex exec --yolo" not in content, (
            "bugs.md still uses --yolo flag. "
            "Replace with --full-auto for security."
        )

    def test_security_loop_md_no_yolo(self, global_commands_dir):
        """Ensure --yolo is not used in security-loop.md command."""
        secloop_path = os.path.join(global_commands_dir, "security-loop.md")
        if not os.path.exists(secloop_path):
            pytest.skip("security-loop.md not found")

        with open(secloop_path) as f:
            content = f.read()

        assert "codex exec --yolo" not in content, (
            "security-loop.md still uses --yolo flag. "
            "Replace with --full-auto for security."
        )
        # Also check @secloop examples
        assert "@secloop . --yolo" not in content, (
            "security-loop.md has @secloop --yolo examples. "
            "Replace with --full-auto."
        )

    def test_all_commands_no_codex_yolo(self, global_commands_dir):
        """Scan all command files for --yolo with codex."""
        if not os.path.isdir(global_commands_dir):
            pytest.skip("Commands directory not found")

        violations = []
        for filename in os.listdir(global_commands_dir):
            if not filename.endswith(".md"):
                continue

            filepath = os.path.join(global_commands_dir, filename)
            with open(filepath) as f:
                content = f.read()

            if "codex exec --yolo" in content or "codex --yolo" in content:
                violations.append(filename)

        assert not violations, (
            f"Commands still using --yolo with Codex: {violations}. "
            "Replace with --full-auto for security."
        )


class TestPreToolUseAdditionalContextHook:
    """Test PreToolUse additionalContext hook configuration."""

    def test_inject_session_context_hook_exists(self, global_hooks_dir):
        """Verify inject-session-context.sh hook exists."""
        hook_path = os.path.join(global_hooks_dir, "inject-session-context.sh")
        assert os.path.isfile(hook_path), (
            f"inject-session-context.sh hook not found at {hook_path}. "
            "This hook injects session context before Task tool calls."
        )

    def test_inject_session_context_hook_executable(self, global_hooks_dir):
        """Verify inject-session-context.sh hook is executable."""
        hook_path = os.path.join(global_hooks_dir, "inject-session-context.sh")
        if not os.path.exists(hook_path):
            pytest.skip("inject-session-context.sh not found")

        assert os.access(hook_path, os.X_OK), (
            f"inject-session-context.sh is not executable. "
            f"Run: chmod +x {hook_path}"
        )

    def test_pretooluse_hook_registered_for_task(self, load_settings_json):
        """Verify PreToolUse hook is registered for Task tool in settings.json.

        v2.69.0: Updated to check for context injection hooks (inject-session-context.sh
        or smart-memory-search.sh) rather than the obsolete 'output: additionalContext'
        configuration. These hooks now return additionalContext in their JSON response.
        """
        settings = load_settings_json()
        hooks = settings.get("hooks", {})
        pretooluse = hooks.get("PreToolUse", [])

        # Find Task matcher with context injection hooks (v2.43+ pattern)
        context_hook_found = False
        context_injection_hooks = [
            "inject-session-context.sh",
            "smart-memory-search.sh",
            "procedural-inject.sh"
        ]

        for entry in pretooluse:
            matcher = entry.get("matcher", "")
            if matcher == "Task":
                hook_list = entry.get("hooks", [])
                for hook in hook_list:
                    command = hook.get("command", "")
                    if any(h in command for h in context_injection_hooks):
                        context_hook_found = True
                        break

        assert context_hook_found, (
            "No context injection hook found for PreToolUse:Task. "
            "Hooks like inject-session-context.sh or smart-memory-search.sh should be registered."
        )


class TestMCPAutoConfiguration:
    """Test MCP auto:10 configuration."""

    def test_mcp_tool_search_mode_configured(self, load_settings_json):
        """Verify mcpToolSearchMode is set to auto:10."""
        settings = load_settings_json()
        mode = settings.get("mcpToolSearchMode")

        assert mode is not None, (
            "mcpToolSearchMode not configured in settings.json. "
            "Add: \"mcpToolSearchMode\": \"auto:10\""
        )
        assert mode == "auto:10", (
            f"mcpToolSearchMode is '{mode}', expected 'auto:10' for deferred loading."
        )


class TestLSPExploreSkill:
    """Test LSP-Explore skill exists and is properly configured.

    Note: lsp-explore skill removed in v2.84.2 - tests skipped.
    """

    @pytest.mark.skip(reason="lsp-explore skill removed in v2.84.2")
    def test_lsp_explore_skill_exists(self, global_skills_dir):
        """Verify lsp-explore skill directory exists."""
        skill_path = os.path.join(global_skills_dir, "lsp-explore")
        skill_md = os.path.join(skill_path, "SKILL.md")

        assert os.path.isdir(skill_path), (
            f"lsp-explore skill directory not found at {skill_path}"
        )
        assert os.path.isfile(skill_md), (
            f"lsp-explore/SKILL.md not found at {skill_md}"
        )

    @pytest.mark.skip(reason="lsp-explore skill removed in v2.84.2")
    def test_lsp_explore_has_frontmatter(self, global_skills_dir, validate_skill_frontmatter):
        """Verify lsp-explore skill has valid frontmatter."""
        skill_path = os.path.join(global_skills_dir, "lsp-explore", "SKILL.md")
        result = validate_skill_frontmatter(skill_path)

        assert result["has_frontmatter"], "lsp-explore skill missing frontmatter"
        assert result["valid"], f"lsp-explore frontmatter invalid: {result['errors']}"
        assert "lsp" in result["frontmatter"].get("name", "").lower(), (
            "lsp-explore skill name should contain 'lsp'"
        )


class TestModernizedSkillSystem:
    """Test modernized skill system with YAML allowed-tools."""

    def test_orchestrator_has_yaml_allowed_tools(self, global_skills_dir):
        """Verify orchestrator skill uses YAML list for allowed-tools."""
        skill_path = os.path.join(global_skills_dir, "orchestrator", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("orchestrator skill not found")

        with open(skill_path) as f:
            content = f.read()

        # Check for YAML list format (lines starting with "  - ")
        assert "allowed-tools:" in content, (
            "orchestrator skill missing allowed-tools field"
        )
        # YAML list format uses "  - " for items
        assert "  - Task" in content or "- Task" in content, (
            "orchestrator allowed-tools should use YAML list format, not comma-separated"
        )

    def test_task_classifier_has_frontmatter(self, global_skills_dir, validate_skill_frontmatter):
        """Verify task-classifier skill has proper frontmatter."""
        skill_path = os.path.join(global_skills_dir, "task-classifier", "SKILL.md")
        result = validate_skill_frontmatter(skill_path)

        assert result["has_frontmatter"], "task-classifier skill missing frontmatter"
        assert result["valid"], f"task-classifier frontmatter invalid: {result['errors']}"

    def test_skill_has_agent_field(self, global_skills_dir):
        """Verify orchestrator skill has agent field linking to agent."""
        skill_path = os.path.join(global_skills_dir, "orchestrator", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("orchestrator skill not found")

        with open(skill_path) as f:
            content = f.read()

        assert "agent:" in content, (
            "orchestrator skill missing 'agent:' field in frontmatter. "
            "This field links the skill to its executing agent."
        )


class TestClaudeMemIntegration:
    """Test claude-mem integration in SessionStart hook.

    v2.85: session-start-ledger.sh was archived (redundant with session-start-restore-context.sh).
    Tests now validate the replacement hook.
    """

    def test_session_start_has_claude_mem_hints(self, global_hooks_dir):
        """Verify session-start-restore-context.sh includes claude-mem integration hints."""
        hook_path = os.path.join(global_hooks_dir, "session-start-restore-context.sh")
        if not os.path.exists(hook_path):
            pytest.skip("session-start-restore-context.sh not found")

        with open(hook_path) as f:
            content = f.read()

        # Check for claude-mem related content
        assert "claude-mem" in content.lower() or "claude_mem" in content.lower(), (
            "session-start-restore-context.sh should include claude-mem integration hints. "
            "Add get_claude_mem_hints() function for v2.43."
        )


class TestWorktreeDashboard:
    """Test worktree-dashboard command exists in ralph CLI."""

    def test_ralph_has_worktree_dashboard_command(self, scripts_dir):
        """Verify ralph CLI has worktree-dashboard command."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        assert "cmd_worktree_dashboard" in content, (
            "ralph CLI missing cmd_worktree_dashboard function"
        )
        assert "worktree-dashboard" in content, (
            "ralph CLI missing worktree-dashboard case statement"
        )

    def test_ralph_worktree_dashboard_aliases(self, scripts_dir):
        """Verify worktree-dashboard has multiple aliases."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        # Check for aliases in case statement
        assert "wt-dashboard" in content or "wt-dash" in content, (
            "worktree-dashboard should have short aliases (wt-dashboard, wt-dash)"
        )


class TestGitignoreTldrEntry:
    """Test .tldr/ is handled by ralph tldr warm command."""

    def test_ralph_tldr_warm_adds_gitignore(self, scripts_dir):
        """Verify ralph tldr warm includes .gitignore handling for .tldr/."""
        ralph_script = os.path.join(scripts_dir, "ralph")
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        # Check that tldr warm command handles .gitignore
        assert ".tldr" in content, (
            "ralph script should reference .tldr directory"
        )
        # Check for gitignore handling logic
        assert ".gitignore" in content, (
            "ralph tldr warm should handle .gitignore for .tldr/ directory"
        )


class TestKeybindings:
    """Test keybindings.json exists with orchestration shortcuts.

    Note: keybindings.json is optional user configuration - tests skipped.
    """

    @pytest.mark.skip(reason="keybindings.json is optional user configuration")
    def test_keybindings_file_exists(self, claude_global_dir):
        """Verify keybindings.json exists."""
        keybindings_path = os.path.join(claude_global_dir, "keybindings.json")
        assert os.path.isfile(keybindings_path), (
            f"keybindings.json not found at {keybindings_path}. "
            "Create with orchestration keyboard shortcuts."
        )

    @pytest.mark.skip(reason="keybindings.json is optional user configuration")
    def test_keybindings_has_orchestrator_shortcut(self, claude_global_dir):
        """Verify keybindings.json has /orchestrator shortcut."""
        keybindings_path = os.path.join(claude_global_dir, "keybindings.json")
        if not os.path.exists(keybindings_path):
            pytest.skip("keybindings.json not found")

        with open(keybindings_path) as f:
            keybindings = json.load(f)

        # Check for /orchestrator binding
        has_orch = any("/orchestrator" in str(v) for v in keybindings.values())
        assert has_orch, (
            "keybindings.json should have a shortcut for /orchestrator"
        )
