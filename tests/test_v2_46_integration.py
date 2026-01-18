"""
Multi-Agent Ralph v2.46 Integration Tests

Tests for validating RLM-inspired enhancements (arXiv:2512.24601v1):
- 3-Dimension Classification (complexity, info_density, context_requirement)
- Fast-path routing for trivial tasks
- Parallel exploration hook
- Recursive decomposition hook
- Quality-first validation (quality over consistency)
- Updated plan-state schema
- New ralph CLI commands (classify, fast-path)
"""
import os
import json
import subprocess
import pytest
from pathlib import Path


# ============================================================
# v2.46 Hooks Tests
# ============================================================

class TestV246Hooks:
    """Test v2.46 hooks exist, are executable, and have valid syntax."""

    V246_HOOKS = [
        "fast-path-check.sh",
        "parallel-explore.sh",
        "quality-gates-v2.sh",
        "recursive-decompose.sh",
    ]

    def test_all_v246_hooks_exist(self, global_hooks_dir):
        """Verify all v2.46 hooks exist."""
        missing = []
        for hook in self.V246_HOOKS:
            hook_path = os.path.join(global_hooks_dir, hook)
            if not os.path.isfile(hook_path):
                missing.append(hook)

        assert not missing, (
            f"Missing v2.46 hooks: {missing}. "
            "Run the v2.46 implementation to create these hooks."
        )

    def test_all_v246_hooks_are_executable(self, global_hooks_dir):
        """Verify all v2.46 hooks are executable."""
        not_executable = []
        for hook in self.V246_HOOKS:
            hook_path = os.path.join(global_hooks_dir, hook)
            if os.path.isfile(hook_path) and not os.access(hook_path, os.X_OK):
                not_executable.append(hook)

        assert not not_executable, (
            f"Non-executable v2.46 hooks: {not_executable}. "
            "Run: chmod +x ~/.claude/hooks/<hook>"
        )

    def test_all_v246_hooks_have_valid_syntax(self, global_hooks_dir):
        """Verify all v2.46 hooks have valid bash syntax."""
        invalid_syntax = []
        for hook in self.V246_HOOKS:
            hook_path = os.path.join(global_hooks_dir, hook)
            if os.path.isfile(hook_path):
                result = subprocess.run(
                    ["bash", "-n", hook_path],
                    capture_output=True,
                    text=True
                )
                if result.returncode != 0:
                    invalid_syntax.append((hook, result.stderr))

        assert not invalid_syntax, (
            f"v2.46 hooks with syntax errors: {invalid_syntax}"
        )

    def test_fast_path_check_has_keywords(self, global_hooks_dir):
        """Verify fast-path-check.sh contains required keywords."""
        hook_path = os.path.join(global_hooks_dir, "fast-path-check.sh")
        if not os.path.exists(hook_path):
            pytest.skip("fast-path-check.sh not found")

        with open(hook_path) as f:
            content = f.read().lower()

        keywords = ["fast_path", "trivial", "complexity", "task"]
        missing = [kw for kw in keywords if kw not in content]

        assert not missing, f"fast-path-check.sh missing keywords: {missing}"

    def test_quality_gates_v2_has_advisory_consistency(self, global_hooks_dir):
        """Verify quality-gates-v2.sh implements advisory consistency."""
        hook_path = os.path.join(global_hooks_dir, "quality-gates-v2.sh")
        if not os.path.exists(hook_path):
            pytest.skip("quality-gates-v2.sh not found")

        with open(hook_path) as f:
            content = f.read()

        # Should have advisory/warning for consistency, not blocking
        assert "advisory" in content.lower() or "warning" in content.lower(), (
            "quality-gates-v2.sh should implement advisory consistency (quality over consistency)"
        )

    def test_recursive_decompose_has_sub_orchestrator(self, global_hooks_dir):
        """Verify recursive-decompose.sh contains sub-orchestrator logic."""
        hook_path = os.path.join(global_hooks_dir, "recursive-decompose.sh")
        if not os.path.exists(hook_path):
            pytest.skip("recursive-decompose.sh not found")

        with open(hook_path) as f:
            content = f.read().lower()

        keywords = ["recursive", "decomposition", "depth"]
        missing = [kw for kw in keywords if kw not in content]

        assert not missing, f"recursive-decompose.sh missing keywords: {missing}"

    def test_parallel_explore_has_parallel_logic(self, global_hooks_dir):
        """Verify parallel-explore.sh contains parallel execution logic."""
        hook_path = os.path.join(global_hooks_dir, "parallel-explore.sh")
        if not os.path.exists(hook_path):
            pytest.skip("parallel-explore.sh not found")

        with open(hook_path) as f:
            content = f.read().lower()

        keywords = ["parallel", "explore", "search"]
        missing = [kw for kw in keywords if kw not in content]

        assert not missing, f"parallel-explore.sh missing keywords: {missing}"


# ============================================================
# v2.46 Skills Tests
# ============================================================

class TestV246Skills:
    """Test v2.46 skill updates."""

    def test_task_classifier_has_3_dimensions(self, global_skills_dir):
        """Verify task-classifier skill has 3-dimension classification."""
        skill_path = os.path.join(global_skills_dir, "task-classifier", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("task-classifier/SKILL.md not found")

        with open(skill_path) as f:
            content = f.read()

        # Must have all 3 dimensions
        dimensions = ["complexity", "information_density", "context_requirement"]
        missing = [d for d in dimensions if d not in content.lower()]

        assert not missing, (
            f"task-classifier missing 3-dimension classification: {missing}"
        )

    def test_task_classifier_has_workflow_routes(self, global_skills_dir):
        """Verify task-classifier skill defines workflow routes."""
        skill_path = os.path.join(global_skills_dir, "task-classifier", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("task-classifier/SKILL.md not found")

        with open(skill_path) as f:
            content = f.read()

        routes = ["FAST_PATH", "STANDARD", "PARALLEL_CHUNKS", "RECURSIVE_DECOMPOSE"]
        missing = [r for r in routes if r not in content]

        assert not missing, (
            f"task-classifier missing workflow routes: {missing}"
        )

    def test_orchestrator_skill_has_v246_features(self, global_skills_dir):
        """Verify orchestrator skill has v2.46 features."""
        skill_path = os.path.join(global_skills_dir, "orchestrator", "SKILL.md")
        if not os.path.exists(skill_path):
            pytest.skip("orchestrator/SKILL.md not found")

        with open(skill_path) as f:
            content = f.read()

        features = [
            "fast-path",
            "parallel",
            "recursive",
            "quality-first",
        ]
        missing = [f for f in features if f not in content.lower()]

        assert len(missing) <= 1, (
            f"orchestrator skill missing v2.46 features: {missing}"
        )


# ============================================================
# v2.46 Plan-State Schema Tests
# ============================================================

class TestV246PlanStateSchema:
    """Test v2.46 plan-state schema updates."""

    def test_plan_state_schema_exists(self, global_schemas_dir):
        """Verify plan-state v2 schema exists."""
        schema_path = os.path.join(global_schemas_dir, "plan-state-v2.json")

        assert os.path.isfile(schema_path), (
            f"plan-state-v2.json schema not found at {schema_path}"
        )

    def test_plan_state_schema_is_valid_json(self, global_schemas_dir):
        """Verify plan-state v2 schema is valid JSON."""
        schema_path = os.path.join(global_schemas_dir, "plan-state-v2.json")
        if not os.path.exists(schema_path):
            pytest.skip("plan-state-v2.json not found")

        with open(schema_path) as f:
            try:
                schema = json.load(f)
            except json.JSONDecodeError as e:
                pytest.fail(f"plan-state-v2.json is not valid JSON: {e}")

        assert "properties" in schema, "Schema missing 'properties' key"

    def test_plan_state_schema_has_classification(self, global_schemas_dir):
        """Verify plan-state schema has classification with 3 dimensions."""
        schema_path = os.path.join(global_schemas_dir, "plan-state-v2.json")
        if not os.path.exists(schema_path):
            pytest.skip("plan-state-v2.json not found")

        with open(schema_path) as f:
            schema = json.load(f)

        classification = schema.get("properties", {}).get("classification", {})
        classification_props = classification.get("properties", {})

        required_dims = ["complexity", "information_density", "context_requirement", "workflow_route"]
        missing = [d for d in required_dims if d not in classification_props]

        assert not missing, (
            f"plan-state schema classification missing dimensions: {missing}"
        )

    def test_plan_state_schema_has_recursion(self, global_schemas_dir):
        """Verify plan-state schema has recursion tracking."""
        schema_path = os.path.join(global_schemas_dir, "plan-state-v2.json")
        if not os.path.exists(schema_path):
            pytest.skip("plan-state-v2.json not found")

        with open(schema_path) as f:
            schema = json.load(f)

        recursion = schema.get("properties", {}).get("recursion", {})

        assert recursion, "plan-state schema missing 'recursion' object"
        assert "depth" in str(recursion), "recursion missing 'depth' field"
        assert "max_depth" in str(recursion), "recursion missing 'max_depth' field"


# ============================================================
# v2.46 Ralph CLI Tests
# ============================================================

class TestV246RalphCLI:
    """Test v2.46 ralph CLI commands."""

    def test_ralph_version_is_246(self, ralph_script):
        """Verify ralph version is 2.46.0."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "version"],
            capture_output=True,
            text=True,
            timeout=5
        )

        assert "2.46" in result.stdout, (
            f"ralph version should be 2.46.x, got: {result.stdout}"
        )

    def test_ralph_classify_command_exists(self, ralph_script):
        """Verify ralph classify command exists."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "help"],
            capture_output=True,
            text=True,
            timeout=5
        )

        assert "classify" in result.stdout, (
            "ralph help should include 'classify' command"
        )

    def test_ralph_classify_trivial_task(self, ralph_script):
        """Test ralph classify with trivial task returns FAST_PATH."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "classify", "Fix typo in README", "--json"],
            capture_output=True,
            text=True,
            timeout=10
        )

        # Extract JSON from output (may have INFO lines)
        output_lines = result.stdout.split('\n')
        json_lines = [l for l in output_lines if l.strip().startswith('{') or l.strip().startswith('"') or l.strip().startswith('}') or l.strip().startswith(' ')]
        json_str = '\n'.join(json_lines)

        try:
            data = json.loads(json_str)
        except json.JSONDecodeError:
            # Try to find JSON block in output
            import re
            json_match = re.search(r'\{[\s\S]*\}', result.stdout)
            if json_match:
                data = json.loads(json_match.group())
            else:
                pytest.fail(f"Could not parse JSON from classify output: {result.stdout}")

        assert data.get("workflow_route") == "FAST_PATH", (
            f"Trivial task should route to FAST_PATH, got: {data.get('workflow_route')}"
        )

    def test_ralph_classify_complex_task(self, ralph_script):
        """Test ralph classify with complex task returns STANDARD or higher."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "classify", "Implement OAuth authentication with Google, GitHub, Microsoft", "--json"],
            capture_output=True,
            text=True,
            timeout=10
        )

        import re
        json_match = re.search(r'\{[\s\S]*\}', result.stdout)
        if not json_match:
            pytest.fail(f"Could not find JSON in classify output: {result.stdout}")

        data = json.loads(json_match.group())

        # Complex task should NOT be FAST_PATH
        assert data.get("workflow_route") != "FAST_PATH", (
            f"Complex task should not route to FAST_PATH, got: {data.get('workflow_route')}"
        )

    def test_ralph_fast_path_command_exists(self, ralph_script):
        """Verify ralph fast-path command exists."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "help"],
            capture_output=True,
            text=True,
            timeout=5
        )

        assert "fast-path" in result.stdout, (
            "ralph help should include 'fast-path' command"
        )

    def test_ralph_fast_path_trivial_passes(self, ralph_script):
        """Test ralph fast-path with trivial task returns success."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "fast-path", "Fix typo"],
            capture_output=True,
            text=True,
            timeout=10
        )

        # Should return 0 for FAST_PATH eligible task
        assert result.returncode == 0, (
            f"fast-path should return 0 for trivial task, got {result.returncode}"
        )
        assert "FAST_PATH" in result.stdout, (
            "fast-path output should mention FAST_PATH"
        )

    def test_ralph_fast_path_complex_fails(self, ralph_script):
        """Test ralph fast-path with complex task returns failure."""
        if not os.path.exists(ralph_script):
            pytest.skip("ralph script not found")

        result = subprocess.run(
            [ralph_script, "fast-path", "Implement full authentication system with OAuth"],
            capture_output=True,
            text=True,
            timeout=10
        )

        # Should return non-zero for non-FAST_PATH task
        assert result.returncode != 0, (
            f"fast-path should return non-zero for complex task, got {result.returncode}"
        )


# ============================================================
# v2.46 Global Settings Tests
# ============================================================

class TestV246GlobalSettings:
    """Test v2.46 global settings configuration."""

    def test_settings_has_fast_path_hook(self, global_settings):
        """Verify global settings has fast-path-check.sh hook."""
        if not global_settings:
            pytest.skip("Global settings not found")

        hooks = global_settings.get("hooks", {})
        pre_tool_use = hooks.get("PreToolUse", [])

        # Look for fast-path-check.sh in any PreToolUse hook
        has_fast_path = False
        for hook_config in pre_tool_use:
            hook_list = hook_config.get("hooks", [])
            for hook in hook_list:
                command = hook.get("command", "")
                if "fast-path-check.sh" in command:
                    has_fast_path = True
                    break

        assert has_fast_path, (
            "Global settings should have fast-path-check.sh in PreToolUse hooks"
        )

    def test_settings_has_quality_gates_v2(self, global_settings):
        """Verify global settings has quality-gates-v2.sh hook."""
        if not global_settings:
            pytest.skip("Global settings not found")

        hooks = global_settings.get("hooks", {})
        post_tool_use = hooks.get("PostToolUse", [])

        # Look for quality-gates-v2.sh in any PostToolUse hook
        has_quality_v2 = False
        for hook_config in post_tool_use:
            hook_list = hook_config.get("hooks", [])
            for hook in hook_list:
                command = hook.get("command", "")
                if "quality-gates-v2.sh" in command:
                    has_quality_v2 = True
                    break

        assert has_quality_v2, (
            "Global settings should have quality-gates-v2.sh in PostToolUse hooks"
        )


# ============================================================
# v2.46 Documentation Tests
# ============================================================

class TestV246Documentation:
    """Test v2.46 documentation updates."""

    def test_global_claude_md_has_v246(self):
        """Verify global CLAUDE.md mentions v2.46."""
        claude_md = Path.home() / ".claude" / "CLAUDE.md"
        if not claude_md.exists():
            pytest.skip("Global CLAUDE.md not found")

        content = claude_md.read_text()

        assert "2.46" in content or "v2.46" in content, (
            "Global CLAUDE.md should mention v2.46"
        )

    def test_project_claude_md_has_v246(self):
        """Verify project CLAUDE.md mentions v2.46."""
        project_root = Path(__file__).parent.parent
        claude_md = project_root / "CLAUDE.md"
        if not claude_md.exists():
            pytest.skip("Project CLAUDE.md not found")

        content = claude_md.read_text()

        assert "2.46" in content or "v2.46" in content, (
            "Project CLAUDE.md should mention v2.46"
        )

    def test_project_claude_md_has_classification_section(self):
        """Verify project CLAUDE.md has classification section."""
        project_root = Path(__file__).parent.parent
        claude_md = project_root / "CLAUDE.md"
        if not claude_md.exists():
            pytest.skip("Project CLAUDE.md not found")

        content = claude_md.read_text().lower()

        keywords = ["classification", "information density", "context requirement"]
        found = sum(1 for kw in keywords if kw in content)

        assert found >= 2, (
            f"Project CLAUDE.md should have classification section with dimension keywords. Found {found}/3"
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
def global_schemas_dir():
    """Return path to global schemas directory."""
    return os.path.expanduser("~/.claude/schemas")


@pytest.fixture
def global_agents_dir():
    """Return path to global agents directory."""
    return os.path.expanduser("~/.claude/agents")


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


@pytest.fixture
def validate_agent_frontmatter():
    """Return function to validate agent frontmatter."""
    import re

    def _validate(agent_path):
        result = {"has_frontmatter": False, "valid": False, "errors": []}

        if not os.path.exists(agent_path):
            result["errors"].append(f"File not found: {agent_path}")
            return result

        with open(agent_path) as f:
            content = f.read()

        # Check for YAML frontmatter
        if not content.startswith("---"):
            result["errors"].append("Missing opening ---")
            return result

        result["has_frontmatter"] = True

        # Find closing ---
        end_match = re.search(r"\n---\n", content[3:])
        if not end_match:
            result["errors"].append("Missing closing ---")
            return result

        result["valid"] = True
        return result

    return _validate
