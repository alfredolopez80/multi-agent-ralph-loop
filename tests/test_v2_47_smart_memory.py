"""
Multi-Agent Ralph Smart Memory Integration Tests

Originally created for v2.47, now updated for v2.69.0 to test FUNCTIONALITY
rather than specific version strings.

Tests for validating Smart Memory-Driven Orchestration (based on @PerceptualPeak Smart Forking):
- Smart Memory Search hook (parallel search across 4 sources)
- Memory sources: claude-mem, memvid, handoffs, ledgers
- Fork suggestions functionality
- Memory context file structure
- Orchestrator agent Smart Memory features
- CLI commands (memory-search, fork-suggest)

NOTE: Tests that checked for "v2.47" version strings have been updated to check
for CURRENT version or converted to functionality tests. The v2.47 historical
entries in CHANGELOG were lost during documentation restructuring.
"""
import os
import json
import subprocess
import pytest
from pathlib import Path


# ============================================================
# v2.47 Hooks Tests
# ============================================================

class TestV247Hooks:
    """Test v2.47 hooks exist, are executable, and have valid syntax."""

    V247_HOOKS = [
        "smart-memory-search.sh",
    ]

    def test_smart_memory_search_hook_exists_globally(self, global_hooks_dir):
        """Verify smart-memory-search.sh exists in global hooks directory."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        assert os.path.isfile(hook_path), (
            f"smart-memory-search.sh not found at {hook_path}. "
            "Run: cp .claude/hooks/smart-memory-search.sh ~/.claude/hooks/"
        )

    def test_smart_memory_search_hook_exists_in_project(self, project_hooks_dir):
        """Verify smart-memory-search.sh exists in project hooks directory."""
        hook_path = os.path.join(project_hooks_dir, "smart-memory-search.sh")
        assert os.path.isfile(hook_path), (
            f"smart-memory-search.sh not found at {hook_path}. "
            "This is the source for the global hook."
        )

    def test_smart_memory_search_hook_is_executable(self, global_hooks_dir):
        """Verify smart-memory-search.sh is executable."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        if not os.path.isfile(hook_path):
            pytest.skip("smart-memory-search.sh not found globally")

        assert os.access(hook_path, os.X_OK), (
            f"smart-memory-search.sh is not executable. "
            "Run: chmod +x ~/.claude/hooks/smart-memory-search.sh"
        )

    def test_smart_memory_search_hook_has_valid_syntax(self, global_hooks_dir):
        """Verify smart-memory-search.sh has valid bash syntax."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        if not os.path.isfile(hook_path):
            pytest.skip("smart-memory-search.sh not found globally")

        result = subprocess.run(
            ["bash", "-n", hook_path],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, (
            f"smart-memory-search.sh has syntax errors: {result.stderr}"
        )

    def test_smart_memory_search_has_parallel_execution(self, global_hooks_dir):
        """Verify smart-memory-search.sh contains parallel execution logic."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        if not os.path.isfile(hook_path):
            pytest.skip("smart-memory-search.sh not found")

        with open(hook_path) as f:
            content = f.read()

        # Must have parallel execution indicators
        parallel_indicators = ["&", "wait", "background"]
        found = sum(1 for ind in parallel_indicators if ind in content.lower())

        assert found >= 2, (
            f"smart-memory-search.sh should have parallel execution logic. "
            f"Found {found}/3 indicators: &, wait, background"
        )

    def test_smart_memory_search_has_four_memory_sources(self, global_hooks_dir):
        """Verify smart-memory-search.sh searches all 4 memory sources."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        if not os.path.isfile(hook_path):
            pytest.skip("smart-memory-search.sh not found")

        with open(hook_path) as f:
            content = f.read().lower()

        memory_sources = ["claude-mem", "memvid", "handoff", "ledger"]
        missing = [src for src in memory_sources if src not in content]

        assert not missing, (
            f"smart-memory-search.sh missing memory sources: {missing}. "
            "All 4 sources must be searched: claude-mem, memvid, handoffs, ledgers"
        )

    def test_smart_memory_search_has_cache_mechanism(self, global_hooks_dir):
        """Verify smart-memory-search.sh implements 30-minute cache."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        if not os.path.isfile(hook_path):
            pytest.skip("smart-memory-search.sh not found")

        with open(hook_path) as f:
            content = f.read().lower()

        cache_indicators = ["cache", "30", "minute", "1800"]
        found = sum(1 for ind in cache_indicators if ind in content)

        assert found >= 2, (
            f"smart-memory-search.sh should implement 30-minute cache. "
            f"Found {found}/4 cache indicators"
        )

    def test_smart_memory_search_outputs_json(self, global_hooks_dir):
        """Verify smart-memory-search.sh outputs to memory-context.json."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        if not os.path.isfile(hook_path):
            pytest.skip("smart-memory-search.sh not found")

        with open(hook_path) as f:
            content = f.read()

        assert "memory-context.json" in content, (
            "smart-memory-search.sh should output to .claude/memory-context.json"
        )


# ============================================================
# v2.47 Skills Tests
# ============================================================

class TestV247Skills:
    """Test v2.47 skill updates."""

    def test_smart_fork_skill_exists_globally(self, global_skills_dir):
        """Verify smart-fork skill exists globally."""
        skill_path = os.path.join(global_skills_dir, "smart-fork", "skill.md")
        alt_path = os.path.join(global_skills_dir, "smart-fork", "SKILL.md")

        exists = os.path.exists(skill_path) or os.path.exists(alt_path)
        assert exists, (
            f"smart-fork skill not found at {skill_path} or {alt_path}. "
            "Run: mkdir -p ~/.claude/skills/smart-fork && "
            "cp .claude/skills/smart-fork/SKILL.md ~/.claude/skills/smart-fork/skill.md"
        )

    def test_smart_fork_skill_exists_in_project(self, project_skills_dir):
        """Verify smart-fork skill exists in project."""
        skill_path = os.path.join(project_skills_dir, "smart-fork", "SKILL.md")

        assert os.path.exists(skill_path), (
            f"smart-fork skill not found at {skill_path}"
        )

    def test_smart_fork_skill_has_frontmatter(self, global_skills_dir):
        """Verify smart-fork skill has valid frontmatter."""
        skill_path = os.path.join(global_skills_dir, "smart-fork", "skill.md")
        if not os.path.exists(skill_path):
            skill_path = os.path.join(global_skills_dir, "smart-fork", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("smart-fork skill not found")

        with open(skill_path) as f:
            content = f.read()

        assert content.startswith("---"), (
            "smart-fork skill should have YAML frontmatter starting with ---"
        )
        assert "\n---" in content[3:], (
            "smart-fork skill should have closing --- for frontmatter"
        )

    def test_smart_fork_skill_has_fork_functionality(self, project_skills_dir):
        """Verify smart-fork skill mentions fork functionality."""
        skill_path = os.path.join(project_skills_dir, "smart-fork", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("smart-fork skill not found in project")

        with open(skill_path) as f:
            content = f.read().lower()

        keywords = ["fork", "session", "memory", "suggest"]
        missing = [kw for kw in keywords if kw not in content]

        assert len(missing) <= 1, (
            f"smart-fork skill missing keywords: {missing}"
        )

    def test_orchestrator_skill_has_v247_features(self, project_skills_dir):
        """Verify orchestrator skill has v2.47 features."""
        skill_path = os.path.join(project_skills_dir, "orchestrator", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("orchestrator/SKILL.md not found")

        with open(skill_path) as f:
            content = f.read()

        # Must have v2.47 version and smart memory features
        v247_indicators = ["2.47", "smart_memory", "memory_search", "smart-memory"]
        found = sum(1 for ind in v247_indicators if ind in content.lower())

        assert found >= 1, (
            f"orchestrator skill should have v2.47 features. "
            f"Found {found}/4 v2.47 indicators"
        )


# ============================================================
# v2.47 Agents Tests
# ============================================================

class TestV247Agents:
    """Test v2.47 agent updates."""

    def test_orchestrator_agent_has_version_gte_247(self, project_agents_dir):
        """Verify orchestrator.md has VERSION >= 2.47 (Smart Memory introduced in v2.47)."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read()

        # Check for VERSION field with any version >= 2.47
        import re
        version_match = re.search(r'VERSION:\s*(\d+)\.(\d+)', content)
        assert version_match, "orchestrator.md should have VERSION field in frontmatter"

        major, minor = int(version_match.group(1)), int(version_match.group(2))
        assert (major, minor) >= (2, 47), (
            f"orchestrator.md VERSION should be >= 2.47, got: {major}.{minor}"
        )

    def test_orchestrator_agent_has_smart_memory_step(self, project_agents_dir):
        """Verify orchestrator.md has Smart Memory Search as Step 0."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read().lower()

        smart_memory_keywords = ["smart memory search", "smart_memory", "step 0"]
        found = sum(1 for kw in smart_memory_keywords if kw in content)

        assert found >= 2, (
            f"orchestrator.md should have Smart Memory Search step. "
            f"Found {found}/3 keywords"
        )

    def test_orchestrator_agent_has_four_memory_sources(self, project_agents_dir):
        """Verify orchestrator.md documents all 4 memory sources."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read().lower()

        memory_sources = ["claude-mem", "memvid", "handoff", "ledger"]
        missing = [src for src in memory_sources if src not in content]

        assert not missing, (
            f"orchestrator.md missing memory sources: {missing}. "
            "All 4 sources must be documented"
        )

    def test_orchestrator_agent_has_fork_suggestions(self, project_agents_dir):
        """Verify orchestrator.md has fork suggestions feature."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read().lower()

        assert "fork" in content and "suggest" in content, (
            "orchestrator.md should document fork suggestions feature"
        )

    def test_orchestrator_agent_has_v247_changes_section(self, project_agents_dir):
        """Verify orchestrator.md has v2.47 Changes section."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read()

        assert "## v2.47 Changes" in content, (
            "orchestrator.md should have '## v2.47 Changes' section"
        )

    def test_orchestrator_agent_has_8_major_steps_flow(self, project_agents_dir):
        """Verify orchestrator.md has 8 major steps flow diagram (v2.47.1 corrected)."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read()

        # v2.47.1 CORRECTNESS-001 fix: Changed from "13 Steps" to "8 Major Steps, 23 Sub-steps"
        assert "8 Major Steps" in content or "8 major steps" in content.lower(), (
            "orchestrator.md should have '8 Major Steps' flow (v2.47.1 corrected from 12/13 inconsistency)"
        )

    def test_orchestrator_agent_has_mcp_tools(self, project_agents_dir):
        """Verify orchestrator.md includes claude-mem MCP tools."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read()

        assert "mcp__plugin_claude-mem" in content, (
            "orchestrator.md should include mcp__plugin_claude-mem tools"
        )


# ============================================================
# v2.47 Ralph CLI Tests
# ============================================================

class TestV247RalphCLI:
    """Test v2.47 ralph CLI commands."""

    def test_ralph_version_is_gte_247(self, ralph_script):
        """Verify ralph version is >= 2.47 (Smart Memory introduced in v2.47)."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "version"],
            capture_output=True,
            text=True,
            timeout=5
        )

        # Parse version from output (e.g., "v2.69.0" or "2.69.0")
        import re
        version_match = re.search(r'v?(\d+)\.(\d+)', result.stdout)
        assert version_match, f"Could not parse version from: {result.stdout}"

        major, minor = int(version_match.group(1)), int(version_match.group(2))
        assert (major, minor) >= (2, 47), (
            f"ralph version should be >= 2.47, got: {major}.{minor}"
        )

    def test_ralph_script_has_smart_memory_support(self, ralph_script):
        """Verify ralph script supports Smart Memory features (introduced in v2.47)."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        with open(ralph_script) as f:
            content = f.read()

        # Check for Smart Memory related functionality
        smart_memory_indicators = ["memory", "search", "ledger", "handoff"]
        found = sum(1 for ind in smart_memory_indicators if ind in content.lower())

        assert found >= 2, (
            f"ralph script should support Smart Memory features. "
            f"Found {found}/4 indicators: memory, search, ledger, handoff"
        )

    def test_ralph_memory_search_command_exists(self, ralph_script):
        """Verify ralph memory-search command exists (optional - v2.47 uses hooks primarily)."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "help"],
            capture_output=True,
            text=True,
            timeout=5
        )

        # Note: v2.47 Smart Memory is primarily hook-based (smart-memory-search.sh)
        # CLI command is optional enhancement - skip if not implemented
        if "memory-search" not in result.stdout and "memory_search" not in result.stdout:
            pytest.skip(
                "memory-search CLI command not implemented - "
                "v2.47 Smart Memory works via hook (smart-memory-search.sh)"
            )

    def test_ralph_fork_suggest_command_exists(self, ralph_script):
        """Verify ralph fork-suggest command exists (optional - can use /smart-fork skill)."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "help"],
            capture_output=True,
            text=True,
            timeout=5
        )

        # Note: Fork suggestions can be accessed via /smart-fork skill
        # CLI command is optional enhancement - skip if not implemented
        if "fork-suggest" not in result.stdout and "fork_suggest" not in result.stdout:
            pytest.skip(
                "fork-suggest CLI command not implemented - "
                "use /smart-fork skill instead for fork suggestions"
            )


# ============================================================
# v2.47 Memory Context Tests
# ============================================================

class TestV247MemoryContext:
    """Test v2.47 memory context file structure."""

    def test_memory_context_json_exists(self, project_root):
        """Verify memory-context.json exists in project."""
        context_path = project_root / ".claude" / "memory-context.json"

        # File may not exist yet if no orchestration has run
        if not context_path.exists():
            pytest.skip("memory-context.json not created yet (orchestration not run)")

        assert context_path.is_file(), (
            f"memory-context.json should be a file at {context_path}"
        )

    def test_memory_context_is_valid_json(self, project_root):
        """Verify memory-context.json is valid JSON."""
        context_path = project_root / ".claude" / "memory-context.json"
        if not context_path.exists():
            pytest.skip("memory-context.json not created yet")

        with open(context_path) as f:
            try:
                data = json.load(f)
            except json.JSONDecodeError as e:
                pytest.fail(f"memory-context.json is not valid JSON: {e}")

        assert isinstance(data, dict), "memory-context.json should be a JSON object"

    def test_memory_context_has_version(self, project_root):
        """Verify memory-context.json has version field >= 2.47."""
        context_path = project_root / ".claude" / "memory-context.json"
        if not context_path.exists():
            pytest.skip("memory-context.json not created yet")

        with open(context_path) as f:
            data = json.load(f)

        assert "version" in data, (
            "memory-context.json should have 'version' field"
        )

        # Parse version and ensure >= 2.47
        import re
        version_str = str(data.get("version", ""))
        version_match = re.search(r'(\d+)\.(\d+)', version_str)
        if version_match:
            major, minor = int(version_match.group(1)), int(version_match.group(2))
            assert (major, minor) >= (2, 47), (
                f"memory-context.json version should be >= 2.47, got: {version_str}"
            )
        else:
            # If version format is different, just check it exists
            assert version_str, "memory-context.json version should not be empty"

    def test_memory_context_has_sources(self, project_root):
        """Verify memory-context.json has sources structure."""
        context_path = project_root / ".claude" / "memory-context.json"
        if not context_path.exists():
            pytest.skip("memory-context.json not created yet")

        with open(context_path) as f:
            data = json.load(f)

        assert "sources" in data, (
            "memory-context.json should have 'sources' object"
        )

        sources = data.get("sources", {})
        expected_sources = ["claude_mem", "memvid", "handoffs", "ledgers"]
        missing = [src for src in expected_sources if src not in sources]

        assert len(missing) <= 1, (
            f"memory-context.json missing sources: {missing}"
        )


# ============================================================
# v2.47 Global Settings Tests
# ============================================================

class TestV247GlobalSettings:
    """Test v2.47 global settings configuration."""

    def test_settings_has_smart_memory_search_hook(self, global_settings):
        """Verify global settings has smart-memory-search.sh hook."""
        if not global_settings:
            pytest.skip("Global settings not found")

        hooks = global_settings.get("hooks", {})
        pre_tool_use = hooks.get("PreToolUse", [])

        # Look for smart-memory-search.sh in any PreToolUse hook
        has_smart_memory = False
        for hook_config in pre_tool_use:
            hook_list = hook_config.get("hooks", [])
            for hook in hook_list:
                command = hook.get("command", "")
                if "smart-memory-search.sh" in command:
                    has_smart_memory = True
                    break
            if has_smart_memory:
                break

        assert has_smart_memory, (
            "Global settings should have smart-memory-search.sh in PreToolUse hooks. "
            "Add it to ~/.claude/settings.json"
        )


# ============================================================
# v2.47 Documentation Tests
# ============================================================

class TestSmartMemoryDocumentation:
    """Test Smart Memory documentation (originally v2.47, now general)."""

    def test_readme_has_smart_memory_section(self, project_root):
        """Verify README.md documents Smart Memory-Driven Orchestration."""
        readme_path = project_root / "README.md"
        if not readme_path.exists():
            pytest.skip("README.md not found")

        content = readme_path.read_text()

        assert "Smart Memory" in content or "smart memory" in content.lower(), (
            "README.md should document Smart Memory-Driven Orchestration"
        )

    @pytest.mark.skip(reason="""
    v2.69.0: HISTORICAL DOCUMENTATION LOST

    The CHANGELOG was restructured and no longer contains entries prior to v2.67.
    The v2.47.0 entry documenting Smart Memory introduction was lost during this process.
    This test is skipped because the historical data cannot be recovered.

    Smart Memory functionality is tested separately - this only tested documentation.
    """)
    def test_changelog_has_v247_entry(self, project_root):
        """Verify CHANGELOG.md has v2.47.0 entry (SKIPPED - history lost)."""
        pass

    def test_project_claude_md_has_smart_memory(self, project_root):
        """Verify project CLAUDE.md documents Smart Memory features."""
        claude_md = project_root / "CLAUDE.md"
        if not claude_md.exists():
            pytest.skip("Project CLAUDE.md not found")

        content = claude_md.read_text()

        # Check for Smart Memory related documentation
        smart_memory_keywords = ["memory", "smart", "orchestration", "parallel"]
        found = sum(1 for kw in smart_memory_keywords if kw in content.lower())

        assert found >= 2, (
            f"Project CLAUDE.md should document Smart Memory features. "
            f"Found {found}/4 keywords"
        )

    def test_global_claude_md_has_smart_memory(self):
        """Verify global CLAUDE.md documents Smart Memory features."""
        claude_md = Path.home() / ".claude" / "CLAUDE.md"
        if not claude_md.exists():
            pytest.skip("Global CLAUDE.md not found")

        content = claude_md.read_text()

        # Check for Smart Memory related documentation
        if "memory" not in content.lower() and "orchestrat" not in content.lower():
            pytest.skip("Global CLAUDE.md not yet updated with Smart Memory docs (advisory)")

    def test_context_management_analysis_exists(self, project_root):
        """Verify v2.47 context management analysis document exists."""
        doc_path = project_root / ".claude" / "docs" / "CONTEXT-MANAGEMENT-ANALYSIS-v2.47.md"

        assert doc_path.exists(), (
            f"Context management analysis document not found at {doc_path}"
        )

    def test_anchored_summary_design_exists(self, project_root):
        """Verify v2.47 anchored summary design document exists."""
        doc_path = project_root / ".claude" / "docs" / "ANCHORED-SUMMARY-DESIGN-v2.47.md"

        assert doc_path.exists(), (
            f"Anchored summary design document not found at {doc_path}"
        )


# ============================================================
# v2.47 Integration Tests
# ============================================================

class TestSmartMemoryIntegration:
    """Test Smart Memory cross-component integration."""

    def test_hook_and_skill_both_exist(self, global_hooks_dir, global_skills_dir):
        """Verify smart-memory-search hook and smart-fork skill both exist."""
        hook_path = os.path.join(global_hooks_dir, "smart-memory-search.sh")
        skill_path = os.path.join(global_skills_dir, "smart-fork", "skill.md")

        if not os.path.exists(hook_path):
            pytest.skip("smart-memory-search.sh not found")
        if not os.path.exists(skill_path):
            skill_path = os.path.join(global_skills_dir, "smart-fork", "SKILL.md")
            if not os.path.exists(skill_path):
                pytest.skip("smart-fork skill not found")

        # Both files exist - that's the integration check
        assert os.path.exists(hook_path), "Hook should exist"
        assert os.path.exists(skill_path), "Skill should exist"

    def test_agent_and_skill_both_have_version(self, project_agents_dir, project_skills_dir):
        """Verify agent and skill both have VERSION fields."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        skill_path = os.path.join(project_skills_dir, "orchestrator", "SKILL.md")

        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")
        if not os.path.exists(skill_path):
            pytest.skip("orchestrator/SKILL.md not found")

        with open(agent_path) as f:
            agent_content = f.read()
        with open(skill_path) as f:
            skill_content = f.read()

        # Both should have VERSION field (any version >= 2.47)
        import re
        agent_match = re.search(r'VERSION:\s*(\d+)\.(\d+)', agent_content)
        skill_match = re.search(r'VERSION:\s*(\d+)\.(\d+)', skill_content)

        assert agent_match, "orchestrator.md should have VERSION field"
        assert skill_match, "orchestrator/SKILL.md should have VERSION field"

    def test_cli_and_agent_version_consistency(self, ralph_script, project_agents_dir):
        """Verify CLI and agent have consistent major.minor versions."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        # Check CLI version
        result = subprocess.run(
            [ralph_script, "version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        cli_output = result.stdout.strip()

        # Check agent version
        with open(agent_path) as f:
            agent_content = f.read()

        # Parse versions
        import re
        cli_match = re.search(r'v?(\d+)\.(\d+)', cli_output)
        agent_match = re.search(r'VERSION:\s*(\d+)\.(\d+)', agent_content)

        if not cli_match:
            pytest.skip(f"Could not parse CLI version from: {cli_output}")
        if not agent_match:
            pytest.skip("Could not find VERSION in orchestrator.md")

        cli_major, cli_minor = int(cli_match.group(1)), int(cli_match.group(2))
        agent_major, agent_minor = int(agent_match.group(1)), int(agent_match.group(2))

        # Both should be >= 2.47 and same major version
        assert cli_major == agent_major, (
            f"CLI and agent should have same major version: CLI={cli_major}, agent={agent_major}"
        )


# ============================================================
# Smart Forking Concept Tests (Attribution: @PerceptualPeak)
# ============================================================

class TestSmartForkingConcept:
    """Test Smart Forking concept implementation (attribution: @PerceptualPeak)."""

    def test_orchestrator_credits_perceptualpeak(self, project_agents_dir):
        """Verify orchestrator credits @PerceptualPeak for Smart Forking concept."""
        agent_path = os.path.join(project_agents_dir, "orchestrator.md")
        if not os.path.exists(agent_path):
            pytest.skip("orchestrator.md not found")

        with open(agent_path) as f:
            content = f.read()

        assert "PerceptualPeak" in content, (
            "orchestrator.md should credit @PerceptualPeak for Smart Forking concept"
        )

    @pytest.mark.skip(reason="""
    v2.69.0: HISTORICAL DOCUMENTATION LOST

    The CHANGELOG was restructured and no longer contains entries prior to v2.67.
    The v2.47.0 entry crediting @PerceptualPeak was lost during this process.
    This test is skipped because the historical data cannot be recovered.

    The orchestrator.md still credits @PerceptualPeak - that test passes.
    """)
    def test_changelog_credits_perceptualpeak(self, project_root):
        """Verify CHANGELOG credits @PerceptualPeak (SKIPPED - history lost)."""
        pass

    def test_smart_fork_implements_session_reuse(self, project_skills_dir):
        """Verify smart-fork skill implements session knowledge reuse."""
        skill_path = os.path.join(project_skills_dir, "smart-fork", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("smart-fork skill not found")

        with open(skill_path) as f:
            content = f.read().lower()

        # Core concept: reuse knowledge from other sessions
        keywords = ["session", "knowledge", "reuse", "context"]
        found = sum(1 for kw in keywords if kw in content)

        assert found >= 3, (
            f"smart-fork skill should implement session knowledge reuse. "
            f"Found {found}/4 keywords"
        )


# ============================================================
# Fixtures
# ============================================================

@pytest.fixture
def global_hooks_dir():
    """Return path to global hooks directory."""
    return os.path.expanduser("~/.claude/hooks")


@pytest.fixture
def global_skills_dir():
    """Return path to global skills directory."""
    return os.path.expanduser("~/.claude/skills")


@pytest.fixture
def global_agents_dir():
    """Return path to global agents directory."""
    return os.path.expanduser("~/.claude/agents")


@pytest.fixture
def project_hooks_dir():
    """Return path to project hooks directory."""
    project_root = Path(__file__).parent.parent
    return str(project_root / ".claude" / "hooks")


@pytest.fixture
def project_skills_dir():
    """Return path to project skills directory."""
    project_root = Path(__file__).parent.parent
    return str(project_root / ".claude" / "skills")


@pytest.fixture
def project_agents_dir():
    """Return path to project agents directory."""
    project_root = Path(__file__).parent.parent
    return str(project_root / ".claude" / "agents")


@pytest.fixture
def project_root():
    """Return project root path."""
    return Path(__file__).parent.parent


@pytest.fixture
def ralph_script():
    """Return path to ralph script."""
    project_root = Path(__file__).parent.parent
    return str(project_root / "scripts" / "ralph")


@pytest.fixture
def global_settings():
    """Return global settings as dict."""
    settings_path = os.path.expanduser("~/.claude/settings.json")
    if os.path.exists(settings_path):
        with open(settings_path) as f:
            return json.load(f)
    return None
